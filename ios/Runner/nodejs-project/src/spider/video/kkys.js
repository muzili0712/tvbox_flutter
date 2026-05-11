const req = require('../../util/req.js');
const CryptoJS = require('crypto-js');
const { randStr } = require('../../util/misc.js');

let url = 'https://api1.baibaipei.com:8899';
let device = {};

async function init(inReq, _outResp) {
    const deviceKey = inReq.server.prefix + '/device';
    device = await inReq.server.db.getObjectDefault(deviceKey, {});
    if (!device.id) {
        device.id = randStr(32).toLowerCase();
        device.ua = 'Mozilla/5.0 (Linux; Android 11; SM-G991B) AppleWebKit/537.36';
        await inReq.server.db.push(deviceKey, device);
    }
    return {};
}

async function home(_inReq, _outResp) {
    return { class: [{ type_id: '1', type_name: '电影' }] };
}

async function category(inReq, _outResp) {
    const tid = inReq.body.id;
    const pg = inReq.body.page || 1;
    return { list: [], page: pg, pagecount: 1, total: 0 };
}

async function detail(inReq, _outResp) {
    const ids = !Array.isArray(inReq.body.id) ? [inReq.body.id] : inReq.body.id;
    const videos = [];
    for (const id of ids) {
        videos.push({
            vod_id: id,
            vod_name: id,
            vod_play_from: 'kkys',
            vod_play_url: id + '$' + id,
        });
    }
    return { list: videos };
}

async function play(inReq, _outResp) {
    const id = inReq.body.id;
    return { parse: 0, url: id };
}

async function search(_inReq, _outResp) {
    return { list: [] };
}

module.exports = {
    meta: { key: 'kkys', name: 'kkys', type: 3 },
    api: async (fastify) => {
        fastify.post('/init', init);
        fastify.post('/home', home);
        fastify.post('/category', category);
        fastify.post('/detail', detail);
        fastify.post('/play', play);
        fastify.post('/search', search);
    },
};
