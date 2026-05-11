const req = require('../../util/req.js');
const { formatPlayUrl, randDeviceWithId, jsonParse, randUUID } = require('../../util/misc.js');
const dayjs = require('dayjs');
const NodeRSA = require('node-rsa');
const CryptoJS = require('crypto-js');

let url = 'https://api.tyun77.cn';
let device = {};
let timeOffset = 0;
const appVer = '2.2.9';
const rsa = new NodeRSA(
    `-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA7QHUVAUM7yghB0/3qz5C
bWX5YYD0ss+uDtbDz5VkTclop6YnCY+1U4aw4z134ljkp/jL0mWnYioZHTTqxXMf
R5q15FcMZnnn/gMZNj1ZR67/c9ti6WTG0VEr9IdcJgwHwwGak/xQK1Z9htl7TR3Q
WA45MmpCSSgjVvX4bbV43IjdjSZNm8s5efdlLl1Z+7uJTR024xizhK5NH0/uPmR4
O8QEtxO9ha3LMmTYTfERzfNmpfDVdV3Rok4eoTzhHmxgqQ0/S0S+FgjHiwrCTFlv
NCiDhSemnJT+NIzAnMQX4acL5AYNb5PiDD06ZMrtklTua+USY0gSIrG9LctaYvHR
swIDAQAB
-----END PUBLIC KEY-----`,
    'pkcs8-public-pem',
    { encryptionScheme: 'pkcs1' }
);

async function request(reqUrl, ua) {
    let sj = dayjs().unix() - timeOffset;
    let uri = new URL(reqUrl);
    uri.searchParams.append('pcode', '010110010');
    uri.searchParams.append('version', appVer);
    uri.searchParams.append('devid', device.id);
    uri.searchParams.append('package', 'com.sevenVideo.app.android');
    uri.searchParams.append('sys', 'android');
    uri.searchParams.append('sysver', device.release);
    uri.searchParams.append('brand', device.brand);
    uri.searchParams.append('state', 'on');
    uri.searchParams.append('model', (device.model || '').replaceAll(' ', '_'));
    uri.searchParams.append('sj', sj);
    let keys = [];
    for (const k of uri.searchParams.keys()) keys.push(k);
    keys.sort();
    let tkSrc = uri.pathname;
    for (let k of keys) tkSrc += encodeURIComponent(uri.searchParams.get(k));
    tkSrc += sj + 'XSpeUFjJ';
    let tk = CryptoJS.enc.Hex.stringify(CryptoJS.MD5(tkSrc)).toString().toLowerCase();
    let header = { 'User-Agent': ua || 'okhttp/3.12.0', T: sj, TK: tk };
    if (reqUrl.indexOf('getVideoPlayAuth') > 0) {
        header['TK-VToken'] = rsa.encrypt(`{"videoId":"${uri.searchParams.get('videoId')}","timestamp":"${sj}"}`, 'base64');
    } else if (reqUrl.indexOf('parserUrl') > 0) {
        header['TK-VToken'] = rsa.encrypt(`{"url":"${uri.searchParams.get('url')}","timestamp":"${sj}"}`, 'base64');
    }
    let resp = await req.get(uri.toString(), { headers: header });
    let serverTime = resp.headers.date;
    let serverTimeS = dayjs(serverTime).unix();
    timeOffset = dayjs().unix() - serverTimeS;
    return resp.data;
}

async function init(inReq, _outResp) {
    const deviceKey = inReq.server.prefix + '/device';
    device = await inReq.server.db.getObjectDefault(deviceKey, {});
    if (!device.id) {
        device = randDeviceWithId(32);
        device.id = device.id.toLowerCase();
        device.ua = 'Dalvik/2.1.0 (Linux; U; Android ' + device.release + '; ' + device.model + ' Build/' + device.buildId + ')';
        await inReq.server.db.push(deviceKey, device);
    }
    await request(url + '/api.php/provide/getDomain');
    await request(url + '/api.php/provide/config');
    await request(url + '/api.php/provide/checkUpgrade');
    await request(url + '/api.php/provide/channel');
    return {};
}

async function home(_inReq, _outResp) {
    let data = (await request(url + '/api.php/provide/filter')).data;
    let classes = [];
    let filterObj = {};
    for (const key in data) {
        classes.push({ type_id: key, type_name: data[key][0].cat });
    }
    return { class: classes, filters: filterObj };
}

async function category(inReq, _outResp) {
    const tid = inReq.body.id;
    const pg = inReq.body.page || 1;
    const extend = inReq.body.filters || {};
    let reqUrl = url + '/api.php/provide/searchFilter?type_id=' + tid + '&pagenum=' + pg + '&pagesize=24';
    reqUrl += '&year=' + (extend.year || '') + '&category=' + (extend.category || '') + '&area=' + (extend.area || '');
    let data = (await request(reqUrl)).data;
    let videos = [];
    for (const vod of (data.result || [])) {
        videos.push({ vod_id: vod.id, vod_name: vod.title, vod_pic: vod.videoCover, vod_remarks: vod.msg });
    }
    return { page: parseInt(data.page || pg), pagecount: data.pagesize || 1, limit: 24, total: data.total || 0, list: videos };
}

async function detail(inReq, _outResp) {
    const ids = !Array.isArray(inReq.body.id) ? [inReq.body.id] : inReq.body.id;
    const videos = [];
    for (const id of ids) {
        let data = (await request(url + '/api.php/provide/videoDetail?ids=' + id)).data;
        let vod = {
            vod_id: data.id, vod_name: data.videoName, vod_pic: data.videoCover,
            type_name: data.subCategory, vod_year: data.year, vod_area: data.area,
            vod_remarks: data.msg, vod_actor: data.actor, vod_director: data.director,
            vod_content: (data.brief || '').trim(),
        };
        let episodes = ((await request(url + '/api.php/provide/videoPlaylist?ids=' + id)).data || {}).episodes || [];
        let playlist = {};
        for (const episode of episodes) {
            for (const playurl of (episode.playurls || [])) {
                let from = playurl.playfrom;
                let t = formatPlayUrl(vod.vod_name, playurl.title);
                if (t.length == 0) t = (playurl.title || '').trim();
                if (!playlist.hasOwnProperty(from)) playlist[from] = [];
                playlist[from].push(t + '$' + playurl.playurl);
            }
        }
        vod.vod_play_from = Object.keys(playlist).join('$$$');
        vod.vod_play_url = Object.values(playlist).map(arr => arr.join('#')).join('$$$');
        videos.push(vod);
    }
    return { list: videos };
}

async function play(inReq, _outResp) {
    const flag = inReq.body.flag;
    const id = inReq.body.id;
    let data = (await request(url + '/api.php/provide/parserUrl?url=' + id + '&retryNum=0')).data;
    let playHeader = data.playHeader;
    let jxUrl = data.url;
    let result = { parse: 0, url: jxUrl };
    if (playHeader) result.header = playHeader;
    return result;
}

async function search(inReq, _outResp) {
    const pg = inReq.body.page || 1;
    const wd = inReq.body.wd;
    let data = await request(url + '/api.php/provide/searchVideo?searchName=' + wd + '&pg=' + pg, 'okhttp/3.12.0');
    let videos = [];
    for (const vod of (data.data || [])) {
        videos.push({ vod_id: vod.id, vod_name: vod.videoName, vod_pic: vod.videoCover, vod_remarks: vod.msg });
    }
    return { page: pg, pagecount: data.pages || 1, list: videos };
}

module.exports = {
    meta: { key: 'kunyu77', name: '琨娱七七', type: 3 },
    api: async (fastify) => {
        fastify.post('/init', init);
        fastify.post('/home', home);
        fastify.post('/category', category);
        fastify.post('/detail', detail);
        fastify.post('/play', play);
        fastify.post('/search', search);
    },
};
