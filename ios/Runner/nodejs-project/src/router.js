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
            const path = spiderPrefix + '/' + spider.meta.key + '/' + spider.meta.type;
            fastifyInstance.register(spider.api, { prefix: path });
        }
    }

    registerSpiderRoutes(fastify);

    fastify.get('/config', async function (_request, reply) {
        const config = {
            video: { sites: [] },
            read: { sites: [] },
            comic: { sites: [] },
            music: { sites: [] },
            pan: { sites: [] },
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
}
