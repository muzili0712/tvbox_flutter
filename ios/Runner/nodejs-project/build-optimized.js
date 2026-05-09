import * as esbuild from 'esbuild';
import * as fs from 'fs';
import * as path from 'path';
import { createHash } from 'crypto';
import less from 'less';

const isDev = process.env.NODE_ENV === 'development';
const distDir = path.join(process.cwd(), 'dist');

console.log('🚀 TVBox Node.js Mobile 构建系统');
console.log('================================\n');

// 确保输出目录存在
if (!fs.existsSync(distDir)) {
    fs.mkdirSync(distDir, { recursive: true });
}

async function build() {
    try {
        // 步骤1: 构建Website Bundle
        console.log('📦 步骤1: 构建React配置界面...');
        const websiteBundle = await buildWebsite();
        console.log('✅ Website bundle 构建完成\n');

        // 步骤2: 构建主程序
        console.log('🔧 步骤2: 构建主程序...');
        await buildMain(websiteBundle);
        console.log('✅ 主程序构建完成\n');

        // 步骤3: 复制配置
        console.log('📋 步骤3: 处理配置文件...');
        await copyConfig();
        console.log('✅ 配置文件处理完成\n');

        // 步骤4: 生成MD5
        console.log('🔐 步骤4: 生成文件校验...');
        const mainMd5 = createHash('md5').update(fs.readFileSync(path.join(distDir, 'index.js'))).digest('hex');
        fs.writeFileSync(path.join(distDir, 'index.js.md5'), mainMd5);
        console.log(`   Main MD5: ${mainMd5}`);

        if (fs.existsSync(path.join(distDir, 'index.config.js'))) {
            const configMd5 = createHash('md5').update(fs.readFileSync(path.join(distDir, 'index.config.js'))).digest('hex');
            fs.writeFileSync(path.join(distDir, 'index.config.js.md5'), configMd5);
            console.log(`   Config MD5: ${configMd5}`);
        }
        console.log('');

        // 步骤5: 显示构建统计
        const outputStats = fs.statSync(path.join(distDir, 'index.js'));
        const sizeKB = (outputStats.size / 1024).toFixed(2);
        console.log('================================');
        console.log(`✅ 构建成功！`);
        console.log(`   输出文件: dist/index.js`);
        console.log(`   文件大小: ${sizeKB} KB`);
        console.log('================================\n');

        return true;
    } catch (error) {
        console.error('\n❌ 构建失败:', error.message);
        if (error.stack) {
            console.error(error.stack);
        }
        process.exit(1);
    }
}

async function buildWebsite() {
    const entryFile = path.join(process.cwd(), 'src/website/App.jsx');

    if (!fs.existsSync(entryFile)) {
        console.log('⚠️  未找到website入口文件，跳过构建');
        return '';
    }

    console.log('   构建React组件...');

    const result = await esbuild.build({
        entryPoints: [entryFile],
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
        plugins: [lessToJsPlugin()],
        define: {
            'process.env.NODE_ENV': JSON.stringify(isDev ? 'development' : 'production'),
            'process.env.REACT_APP_VERSION': JSON.stringify('1.0.0')
        },
        sourcemap: isDev ? 'inline' : false,
        logLevel: 'warning'
    });

    const bundleCode = result.outputFiles[0].text;

    // 包装为可执行代码
    return `
globalThis.websiteBundle = ${JSON.stringify(bundleCode)};
`;
}

async function buildMain(websiteBundle) {
    console.log('   打包主程序...');

    // 读取并准备主入口文件
    const mainFile = path.join(process.cwd(), 'src/dev.js');
    let mainCode = fs.readFileSync(mainFile, 'utf8');

    // 在代码前插入website bundle
    const bundleWrapper = `
globalThis.websiteBundle = ${JSON.stringify(websiteBundle)};
`;
    mainCode = bundleWrapper + mainCode;

    // 构建主程序
    await esbuild.build({
        stdin: {
            contents: mainCode,
            resolveDir: path.join(process.cwd(), 'src'),
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
        define: {
            'process.env.NODE_ENV': JSON.stringify(isDev ? 'development' : 'production'),
            'process.env.DEV_HTTP_PORT': JSON.stringify(process.env.DEV_HTTP_PORT || '3006'),
            'process.env.NODE_PATH': JSON.stringify(process.env.NODE_PATH || '.'),
        },
        logLevel: 'warning',
        banner: {
            js: '// TVBox Node.js Mobile - Built with esbuild\n'
        }
    });
}

async function copyConfig() {
    const configFile = path.join(process.cwd(), 'src/index.config.js');

    if (!fs.existsSync(configFile)) {
        console.log('⚠️  未找到配置文件，跳过');
        return;
    }

    // 简单复制配置文件（config是纯JavaScript对象）
    const configContent = fs.readFileSync(configFile, 'utf8');
    fs.writeFileSync(path.join(distDir, 'index.config.js'), configContent);
    console.log('   配置文件已复制');
}

// 启动构建
build().then(() => {
    console.log('🎉 所有构建任务完成！\n');
}).catch((error) => {
    console.error('❌ 构建过程中出错:', error);
    process.exit(1);
});

// Less 插件
function lessToJsPlugin() {
    return {
        name: 'less-to-js',
        setup(build) {
            build.onLoad({ filter: /\.less$/ }, async (args) => {
                try {
                    const source = await fs.promises.readFile(args.path, 'utf8');
                    const result = await less.render(source, {
                        filename: args.path,
                        paths: [path.dirname(args.path)]
                    });

                    const jsCode = `
                        (function() {
                            if (typeof document !== 'undefined') {
                                var style = document.createElement('style');
                                style.textContent = ${JSON.stringify(result.css)};
                                if (document.head) {
                                    document.head.appendChild(style);
                                }
                            }
                        })();
                    `;

                    return { contents: jsCode, loader: 'js' };
                } catch (error) {
                    console.error(`处理 ${args.path} 时出错:`, error.message);
                    return { contents: '', loader: 'js' };
                }
            });
        }
    };
}
