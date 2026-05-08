const esbuild = require('esbuild');
const fs = require('fs');
const path = require('path');
const {createHash} = require('crypto');

esbuild.build({
  entryPoints: ['src/main.js'],
  outfile: 'dist/main.js',
  bundle: true,
  minify: true,
  write: true,
  format: 'cjs',
  platform: 'node',
  target: 'node18',
  sourcemap: false,
  external: [
    'axios', 'fs', 'path', 'http', 'https', 'url', 'querystring', 'crypto', 
    'buffer', 'stream', 'util', 'events', 'zlib', 'fastify', 'node-json-db',
    '@fastify/cors', '@fastify/static', 'cheerio', 'dayjs', 'iconv-lite',
    'hls-parser', 'crypto-js', 'node-rsa'
  ],
  plugins: [addWebsite(), genMd5()],
});

function addWebsite() {
  return {
    name: 'inject-website-bundle',
    setup(build) {
      build.onResolve({ filter: /websiteBundle/ }, () => {
        return { path: path.join(__dirname, 'website-bundle-placeholder'), namespace: 'website-bundle' };
      });
      
      build.onLoad({ filter: /website-bundle-placeholder/ }, () => {
        // Read the website bundle from the appropriate location
        const websiteIndexPath = path.join(__dirname, 'src', 'website', 'index.js');
        if (fs.existsSync(websiteIndexPath)) {
          const websiteCode = fs.readFileSync(websiteIndexPath, 'utf8');
          // This is a simplified approach - in a real implementation you'd want to properly bundle the React app
          return {
            contents: `globalThis.websiteBundle = \`${websiteCode.replace(/`/g, '\\`')}\`;`,
            loader: 'js'
          };
        }
        return { contents: 'globalThis.websiteBundle = "";', loader: 'js' };
      });
    },
  };
}

function genMd5() {
  return {
    name: 'gen-output-file-md5',
    setup(build) {
      build.onEnd(async _ => {
        const md5 = createHash('md5')
          .update(fs.readFileSync('dist/main.js'))
          .digest('hex');
        fs.writeFileSync('dist/main.js.md5', md5);
      });
    },
  };
}
