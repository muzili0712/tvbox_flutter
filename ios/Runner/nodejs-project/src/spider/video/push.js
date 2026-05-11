const req = require('../../util/req.js');

async function init(_inReq, _outResp) {
    return {};
}

async function support(_inReq, _outResp) {
    return 'true';
}

async function detail(inReq, _outResp) {
    const ids = !Array.isArray(inReq.body.id) ? [inReq.body.id] : inReq.body.id;
    const videos = [];
    for (const id of ids) {
        videos.push({
            vod_id: id,
            vod_content: '',
            vod_name: id,
            vod_pic: 'https://pic.rmb.bdstatic.com/bjh/1d0b02d0f57f0a42201f92caba5107ed.jpeg',
            vod_play_from: '推送',
            vod_play_url: '测试$' + id,
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

async function home(_inReq, _outResp) {
    return { class: [] };
}

async function category(_inReq, _outResp) {
    return { list: [], page: 1, pagecount: 1 };
}

module.exports = {
    meta: { key: 'push', name: '推送', type: 3 },
    api: async (fastify) => {
        fastify.post('/init', init);
        fastify.post('/home', home);
        fastify.post('/category', category);
        fastify.post('/detail', detail);
        fastify.post('/play', play);
        fastify.post('/search', search);
    },
};
