import kunyu77 from './spider/video/kunyu77.js';
import kkys from './spider/video/kkys.js';
import push from './spider/video/push.js';
import alist from './spider/pan/alist.js';
import _13bqg from './spider/book/13bqg.js';
import copymanga from './spider/book/copymanga.js';
import ffm3u8 from './spider/video/ffm3u8.js';
import duoduo from "./spider/video/duoduo.js";
import baseset from "./spider/video/baseset.js";

const spiders = [duoduo, baseset];
const spiderPrefix = '/spider';

export default async function router(fastify) {
    spiders.forEach((spider) => {
        const path = spiderPrefix + '/' + spider.meta.key + '/' + spider.meta.type;
        fastify.register(spider.api, { prefix: path });
        console.log('Register spider: ' + path);
    });
    fastify.get('/check', async function (_request, reply) {
        reply.send({ run: !fastify.stop });
    });
    fastify.get('/config', async function (_request, reply) {
        const config = {
            video: {
                sites: [],
            },
            read: {
                sites: [],
            },
            comic: {
                sites: [],
            },
            music: {
                sites: [],
            },
            pan: {
                sites: [],
            },
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
}
