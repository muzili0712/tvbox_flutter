import * as esbuild from 'esbuild';
import * as fs from 'fs';
import * as path from 'path';
import { createHash } from 'crypto';
import less from 'less';

const isDev = process.env.NODE_ENV === 'development';

// 创建输出目录
const distDir = path.join(process.cwd(), 'dist');
if (!fs.existsSync(distDir)) {
    fs.mkdirSync(distDir, { recursive: true });
}

console.log('🚀 Starting build...');

try {
    // 1. 构建website bundle (React组件)
    console.log('📦 Building website bundle...');
    const websiteBundle = await buildWebsite();

    // 2. 构建主代码并嵌入website
    console.log('🔧 Building main application...');
    await buildMain(websiteBundle);

    // 3. 生成MD5
    const md5 = createHash('md5').update(fs.readFileSync(path.join(distDir, 'index.js'))).digest('hex');
    fs.writeFileSync(path.join(distDir, 'index.js.md5'), md5);
    console.log(`✅ MD5: ${md5}`);

    // 4. 复制配置文件
    console.log('📋 Copying config files...');
    await copyConfig();

    console.log('✅ Build completed successfully!');
} catch (error) {
    console.error('❌ Build failed:', error);
    process.exit(1);
}

async function buildWebsite() {
    console.log('  Building React website bundle...');

    const clientResult = await esbuild.build({
        entryPoints: [path.join(process.cwd(), 'src/website/App.jsx')],
        bundle: true,
        minify: !isDev,
        write: false,
        format: 'cjs',
        target: ['chrome58', 'firefox57', 'safari11'],
        loader: {
            '.jsx': 'jsx',
            '.js': 'jsx',
            '.png': 'dataurl',
            '.jpg': 'dataurl',
            '.jpeg': 'dataurl',
            '.gif': 'dataurl',
            '.svg': 'dataurl',
            '.webp': 'dataurl',
        },
        plugins: [lessPlugin()],
        define: {
            'process.env.NODE_ENV': JSON.stringify(isDev ? 'development' : 'production')
        }
    });

    const clientBundle = clientResult.outputFiles[0].text;

    // 生成可执行的website bundle
    return `
globalThis.websiteBundle = function() {
  const exports = {};
  const module = { exports };
  ${clientBundle}
  return \`
    (function() {
      const exports = {};
      const module = { exports };
      \${${JSON.stringify(clientBundle)}}
      if (typeof module.exports.renderClient === 'function') {
        module.exports.renderClient();
      }
    })();
  \`;
}();\n\n`;
}

async function buildMain(websiteBundle) {
    console.log('  Building main entry point...');

    // 读取源代码
    let mainCode = fs.readFileSync(path.join(process.cwd(), 'src/dev.js'), 'utf8');

    // 在代码末尾嵌入website bundle（在import语句之前）
    mainCode = websiteBundle + mainCode;

    // 打包主代码
    const result = await esbuild.build({
        stdin: {
            contents: mainCode,
            resolveDir: process.cwd(),
            sourcefile: 'dev.js',
        },
        outfile: path.join(distDir, 'index.js'),
        bundle: true,
        minify: !isDev,
        format: 'cjs',
        platform: 'node',
        target: 'node18',
        sourcemap: isDev ? 'inline' : false,
        external: [],
        plugins: [
            {
                name: 'inline-website',
                setup(build) {
                    // 已经在stdin中嵌入了website bundle
                }
            }
        ],
        define: {
            'process.env.NODE_ENV': JSON.stringify(isDev ? 'development' : 'production'),
            'process.env.DEV_HTTP_PORT': JSON.stringify(process.env.DEV_HTTP_PORT || '3006'),
            'process.env.NODE_PATH': JSON.stringify(process.env.NODE_PATH || '.'),
        }
    });

    console.log(`  Output size: ${(result.outputFiles[0].contents.length / 1024).toFixed(2)} KB`);
}

async function copyConfig() {
    // 复制配置文件
    const configFile = path.join(process.cwd(), 'src/index.config.js');
    if (fs.existsSync(configFile)) {
        let configCode = fs.readFileSync(configFile, 'utf8');
        // 打包配置文件
        const result = await esbuild.build({
            entryPoints: [configFile],
            outfile: path.join(distDir, 'index.config.js'),
            bundle: true,
            minify: false,
            format: 'cjs',
            platform: 'node',
            target: 'node18',
        });

        const md5 = createHash('md5').update(fs.readFileSync(path.join(distDir, 'index.config.js'))).digest('hex');
        fs.writeFileSync(path.join(distDir, 'index.config.js.md5'), md5);
        console.log(`  Config MD5: ${md5}`);
    }
}

function lessPlugin() {
    return {
        name: 'less-to-js',
        setup(build) {
            build.onLoad({ filter: /\.less$/ }, async (args) => {
                const source = await fs.promises.readFile(args.path, 'utf8');
                try {
                    const { css } = await less.render(source, {
                        filename: args.path,
                        paths: [path.dirname(args.path)]
                    });
                    const contents = `
                        if (typeof window !== 'undefined') {
                            const style = document.createElement('style');
                            style.textContent = ${JSON.stringify(css)};
                            document.head.appendChild(style);
                        }
                    `;
                    return { contents, loader: 'js' };
                } catch (error) {
                    console.error(`Error processing ${args.path}:`, error);
                    throw error;
                }
            });
        }
    };
}
