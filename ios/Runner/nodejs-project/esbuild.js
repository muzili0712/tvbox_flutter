import * as esbuild from 'esbuild';
import fs from 'fs';
import { createHash } from 'crypto';

esbuild.build({
    entryPoints: ['src/dev.js'],
    outfile: 'dist/index.js',
    bundle: true,
    minify: false,
    write: true,
    format: 'esm',
    platform: 'node',
    target: 'node18',
    sourcemap: process.env.NODE_ENV === 'development' ? 'inline' : false,
    plugins: [genMd5()],
}).catch(() => {
    esbuild.build({
        entryPoints: ['src/dev.js'],
        outfile: 'dist/index.js',
        bundle: true,
        minify: false,
        write: true,
        format: 'cjs',
        platform: 'node',
        target: 'node18',
        sourcemap: false,
        plugins: [genMd5()],
    });
});

function genMd5() {
    return {
        name: 'gen-output-file-md5',
        setup(build) {
            build.onEnd(async (_) => {
                try {
                    const md5 = createHash('md5').update(fs.readFileSync('dist/index.js')).digest('hex');
                    fs.writeFileSync('dist/index.js.md5', md5);
                } catch (e) {
                    console.log('MD5 generation skipped');
                }
            });
        },
    };
}
