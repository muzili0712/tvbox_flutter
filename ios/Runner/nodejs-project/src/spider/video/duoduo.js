const req = require('../../util/req.js');

async function init(_inReq, _outResp) {
    return {};
}

async function home(_inReq, _outResp) {
    let classes = [
        {'type_id':'1','type_name':'电影'},
        {'type_id':'2','type_name':'剧集'},
        {'type_id':'4','type_name':'动漫'},
        {'type_id':'3','type_name':'综艺'},
        {'type_id':'5','type_name':'短剧'},
        {'type_id':'20','type_name':'纪录片'}
    ];
    return { class: classes, filters: {} };
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
            vod_play_from: 'duoduo',
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
    meta: { key: 'duoduo', name: '多多', type: 3 },
    api: async (fastify) => {
        fastify.post('/init', init);
        fastify.post('/home', home);
        fastify.post('/category', category);
        fastify.post('/detail', detail);
        fastify.post('/play', play);
        fastify.post('/search', search);
    },
};
