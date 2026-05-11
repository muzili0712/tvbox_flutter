import axios from 'axios';
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import os from 'os';

const spiders = [];
const spiderPrefix = '/spider';

function registerSpider(spider) {
    spiders.push(spider);
}

function clearSpiders() {
    spiders.length = 0;
}

export { registerSpider, clearSpiders, spiders, spiderPrefix };

export default async function router(fastify) {
    function registerSpiderRoutes(fastifyInstance) {
        for (const spider of spiders) {
            const routePath = spiderPrefix + '/' + spider.meta.key + '/' + spider.meta.type;
            fastifyInstance.register(spider.api, { prefix: routePath });
            console.log('Register spider: ' + routePath);
        }
    }

    registerSpiderRoutes(fastify);

    fastify.get('/check', async function (_request, reply) {
        reply.send({ run: !fastify.stop });
    });

    fastify.get('/config', async function (_request, reply) {
        const config = {
            video: { sites: [] },
            read: { sites: [] },
            comic: { sites: [] },
            music: { sites: [] },
            pan: { sites: [] },
            color: fastify.config?.color || [],
        };
        spiders.forEach((spider) => {
            let meta = Object.assign({}, spider.meta);
            meta.api = spiderPrefix + '/' + meta.key + '/' + meta.type;
            meta.key = 'nodejs_' + meta.key;
            const stype = spider.meta.type;
            if (stype < 10) config.video.sites.push(meta);
            else if (stype >= 10 && stype < 20) config.read.sites.push(meta);
            else if (stype >= 20 && stype < 30) config.comic.sites.push(meta);
            else if (stype >= 30 && stype < 40) config.music.sites.push(meta);
            else if (stype >= 40 && stype < 50) config.pan.sites.push(meta);
        });
        reply.send(config);
    });

    fastify.post('/source/load', async function (request, reply) {
        const { url } = request.body || {};
        if (!url) {
            reply.code(400).send({ error: 'url is required' });
            return;
        }
        try {
            const jsResp = await axios.get(url, { timeout: 30000 });
            const jsContent = typeof jsResp.data === 'string' ? jsResp.data : JSON.stringify(jsResp.data);

            let md5Valid = true;
            try {
                const md5Resp = await axios.get(url + '.md5', { timeout: 10000 });
                const expectedMd5 = (md5Resp.data || '').toString().trim();
                if (expectedMd5) {
                    const actualMd5 = crypto.createHash('md5').update(jsContent).digest('hex');
                    if (actualMd5 !== expectedMd5) {
                        md5Valid = false;
                    }
                }
            } catch (e) {}

            if (!md5Valid) {
                reply.code(400).send({ error: 'MD5 verification failed' });
                return;
            }

            const tempDir = path.join(os.tmpdir(), 'tvbox_sources');
            if (!fs.existsSync(tempDir)) {
                fs.mkdirSync(tempDir, { recursive: true });
            }
            const sourceHash = crypto.createHash('md5').update(url).digest('hex').substring(0, 12);
            const tempFile = path.join(tempDir, `source_${sourceHash}.js`);
            fs.writeFileSync(tempFile, jsContent);

            delete require.cache[require.resolve(tempFile)];

            const sourceModule = require(tempFile);

            let config = {};
            try {
                const configUrl = url.replace('/index.js', '/index.config.js');
                const configResp = await axios.get(configUrl, { timeout: 10000 });
                const configPath = path.join(tempDir, `config_${sourceHash}.js`);
                fs.writeFileSync(configPath, typeof configResp.data === 'string' ? configResp.data : JSON.stringify(configResp.data));
                delete require.cache[require.resolve(configPath)];
                const configModule = require(configPath);
                config = configModule.default || configModule;
            } catch (e) {}

            if (sourceModule && typeof sourceModule.start === 'function') {
                await sourceModule.stop?.();
                await sourceModule.start(config);
            }

            reply.send({
                success: true,
                message: 'Source loaded successfully',
                url: url,
                md5Valid: md5Valid
            });
        } catch (e) {
            console.error('Failed to load source:', e);
            reply.code(500).send({ error: e.message });
        }
    });

    fastify.post('/source/loadPath', async function (request, reply) {
        const { path: sourcePath } = request.body || {};
        if (!sourcePath) {
            reply.code(400).send({ error: 'path is required' });
            return;
        }
        try {
            const indexPath = path.join(sourcePath, 'index.js');
            const configPath = path.join(sourcePath, 'index.config.js');

            if (!fs.existsSync(indexPath)) {
                reply.code(400).send({ error: 'index.js not found at path' });
                return;
            }

            delete require.cache[require.resolve(indexPath)];

            const sourceModule = require(indexPath);
            let config = {};
            if (fs.existsSync(configPath)) {
                delete require.cache[require.resolve(configPath)];
                const configModule = require(configPath);
                config = configModule.default || configModule;
            }

            if (sourceModule && typeof sourceModule.start === 'function') {
                await sourceModule.stop?.();
                await sourceModule.start(config);
            }

            reply.send({ success: true, message: 'Source loaded from path' });
        } catch (e) {
            console.error('Failed to load source from path:', e);
            reply.code(500).send({ error: e.message });
        }
    });

    fastify.get('/source/list', async function (request, reply) {
        const sourceList = spiders.map(s => ({
            key: s.meta.key,
            name: s.meta.name,
            type: s.meta.type,
        }));
        reply.send({ sources: sourceList });
    });
}
