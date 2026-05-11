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

async function router(fastify) {
    spiders.forEach((spider) => {
        const path = spiderPrefix + '/' + spider.meta.key + '/' + spider.meta.type;
        fastify.register(spider.api, { prefix: path });
        console.log('Register spider: ' + path);
    });

    fastify.register(async (fastify) => {
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

            reply.send(config);
        });
    });
}

module.exports = router;
