const kunyu77 = require('./spider/video/kunyu77.js');
const kkys = require('./spider/video/kkys.js');
const push = require('./spider/video/push.js');
const alist = require('./spider/pan/alist.js');
const _13bqg = require('./spider/book/13bqg.js');
const copymanga = require('./spider/book/copymanga.js');
const ffm3u8 = require('./spider/video/ffm3u8.js');
const wogg = require('./spider/video/wogg.js');
const douban = require('./spider/video/douban.js');
const maiyoux = require('./spider/video/maiyoux_node.js');
const tiantian = require('./spider/video/tiantian.js');
const saohuo = require('./spider/video/saohuo.js');

const spiders = [saohuo, tiantian, maiyoux, douban, wogg, kunyu77, kkys, ffm3u8, push, alist, _13bqg, copymanga];
const spiderPrefix = '/spider';

let defaultSpider = null;
let defaultSpiderKey = null;
let defaultSpiderType = null;

async function router(fastify) {
    spiders.forEach((spider) => {
        const path = spiderPrefix + '/' + spider.meta.key + '/' + spider.meta.type;
        fastify.register(spider.api, { prefix: path });
        console.log('Register spider: ' + path);
    });

    fastify.post('/msg', async (request, reply) => {
        try {
            const body = request.body || {};
            const action = body.action;
            const params = body.params || {};

            console.log('[MSG] action:', action, 'params:', JSON.stringify(params));

            switch (action) {
                case 'setDefaultSpider':
                    const key = params.key;
                    const type = parseInt(params.type) || 0;
                    defaultSpiderKey = key;
                    defaultSpiderType = type;
                    defaultSpider = spiders.find(s => s.meta.key === key && s.meta.type === type);
                    return { success: true };

                case 'getConfig':
                    return buildConfig(fastify);

                case 'loadSource':
                    const url = params.url;
                    if (url) {
                        try {
                            const resp = await fetch(url);
                            const text = await resp.text();
                            console.log('[loadSource] loaded:', url);
                            return { success: true, url: url };
                        } catch (e) {
                            return { success: false, error: e.message };
                        }
                    }
                    return { success: false, error: 'no url' };

                case 'getHomeContent':
                    if (defaultSpider) {
                        const result = await defaultSpider.home(params, {});
                        return result;
                    }
                    return buildConfig(fastify);

                case 'getCategoryContent':
                    if (defaultSpider) {
                        const result = await defaultSpider.category({ body: params }, {});
                        return result;
                    }
                    return { list: [], page: 1, pagecount: 1, total: 0 };

                case 'getVideoDetail':
                    if (defaultSpider) {
                        const result = await defaultSpider.detail({ body: params }, {});
                        return result;
                    }
                    return { list: [] };

                case 'getPlayUrl':
                    if (defaultSpider) {
                        const result = await defaultSpider.play({ body: params }, {});
                        return result;
                    }
                    return { parse: 0, url: '' };

                case 'search':
                    if (defaultSpider) {
                        const result = await defaultSpider.search({ body: params }, {});
                        return result;
                    }
                    return { list: [] };

                default:
                    console.log('[MSG] unknown action:', action);
                    return { error: 'unknown action' };
            }
        } catch (error) {
            console.error('[MSG] error:', error);
            return { error: error.message };
        }
    });

    fastify.get('/check', async function (_request, reply) {
        reply.send({ run: !fastify.stop });
    });

    fastify.get('/config', async function (_request, reply) {
        reply.send(buildConfig(fastify));
    });
}

function buildConfig(fastify) {
    const config = {
        video: { sites: [] },
        read: { sites: [] },
        comic: { sites: [] },
        music: { sites: [] },
        pan: { sites: [] },
        color: fastify.config.color || [],
    };

    spiders.forEach((spider) => {
        let meta = Object.assign({}, spider.meta);
        meta.api = spiderPrefix + '/' + meta.key + '/' + meta.type;
        meta.key = 'nodejs_' + meta.key;
        const stype = spider.meta.type;
        if (stype < 10) {
            config.video.sites.push(meta);
        } else if (stype >= 10 && stype < 20) {
            config.read.sites.push(meta);
        } else if (stype >= 20 && stype < 30) {
            config.comic.sites.push(meta);
        } else if (stype >= 30 && stype < 40) {
            config.music.sites.push(meta);
        } else if (stype >= 40 && stype < 50) {
            config.pan.sites.push(meta);
        }
    });

    return config;
}

module.exports = router;
