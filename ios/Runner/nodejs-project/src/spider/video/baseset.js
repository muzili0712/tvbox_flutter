const CryptoJS = require('crypto-js');

function base64Decode(text) {
    return CryptoJS.enc.Utf8.stringify(CryptoJS.enc.Base64.parse(text));
}

function base64Encode(text) {
    return CryptoJS.enc.Base64.stringify(CryptoJS.enc.Utf8.parse(text));
}

async function init(inReq, outResp) {
    return {};
}

async function home(e, t) {
    return { class: [{ type_id: 'setting', type_name: '配置' }] };
}

async function category(e, t) {
    return { list: [], page: 1, pagecount: 1 };
}

async function detail(e, t) {
    return { list: [] };
}

async function play(e, t) {
    return {};
}

async function search(e, t) {
    return { list: [] };
}

module.exports = {
    meta: { key: 'baseset', name: '基础配置', type: 3 },
    api: async (fastify) => {
        fastify.post('/init', init);
        fastify.post('/home', home);
        fastify.post('/category', category);
        fastify.post('/detail', detail);
        fastify.post('/play', play);
        fastify.post('/search', search);
    },
};
