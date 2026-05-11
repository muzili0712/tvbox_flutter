const req = require('../../util/req.js');

let url = '';
let categories = [];

async function request(reqUrl) {
    let res = await req(reqUrl, { method: 'get' });
    return res.data;
}

async function init(inReq, _outResp) {
    url = inReq.server.config.ffm3u8 ? inReq.server.config.ffm3u8.url : '';
    categories = inReq.server.config.ffm3u8 ? (inReq.server.config.ffm3u8.categories || []) : [];
    return {};
}

async function home(_inReq, _outResp) {
    if (!url) return { class: [] };
    try {
        const data = await request(url);
        let classes = [];
        for (const cls of (data.class || [])) {
            const n = (cls.type_name || '').toString().trim();
            if (categories.length > 0 && categories.indexOf(n) < 0) continue;
            classes.push({ type_id: (cls.type_id || '').toString(), type_name: n });
        }
        return { class: classes };
    } catch (e) {
        return { class: [] };
    }
}

async function category(inReq, _outResp) {
    const tid = inReq.body.id;
    const pg = inReq.body.page || 1;
    const extend = inReq.body.filters || {};
    if (!url) return { list: [], page: 1, pagecount: 1 };
    try {
        const data = await request(url + '?type=' + tid + '&page=' + pg);
        let videos = [];
        for (const v of (data.list || [])) {
            videos.push({
                vod_id: v.vod_id || v.id,
                vod_name: v.vod_name || v.title,
                vod_pic: v.vod_pic || v.pic,
                vod_remarks: v.vod_remarks || v.remarks || '',
            });
        }
        return { list: videos, page: parseInt(data.page || pg), pagecount: parseInt(data.pagecount || pg) };
    } catch (e) {
        return { list: [], page: 1, pagecount: 1 };
    }
}

async function detail(inReq, _outResp) {
    const ids = !Array.isArray(inReq.body.id) ? [inReq.body.id] : inReq.body.id;
    const videos = [];
    for (const id of ids) {
        videos.push({
            vod_id: id,
            vod_name: id,
            vod_play_from: 'ffm3u8',
            vod_play_url: id + '$' + id,
        });
    }
    return { list: videos };
}

async function play(inReq, _outResp) {
    const id = inReq.body.id;
    return { parse: 0, url: id };
}

async function search(inReq, _outResp) {
    return { list: [] };
}

module.exports = {
    meta: { key: 'ffm3u8', name: 'FFm3u8', type: 3 },
    api: async (fastify) => {
        fastify.post('/init', init);
        fastify.post('/home', home);
        fastify.post('/category', category);
        fastify.post('/detail', detail);
        fastify.post('/play', play);
        fastify.post('/search', search);
    },
};
