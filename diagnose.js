const http = require('http');
const https = require('https');
const { exec, spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const SOURCE_URL = process.argv[2] || 'https://9280.kstore.vip/cat/index.js';
const TEST_KEYWORD = process.argv[3] || '\u5e86\u4f59\u5e74';
const MODE = process.argv.find(a => a.startsWith('--mode='))?.split('=')[1] || 'full';
const TARGET_SITE = process.argv.find(a => a.startsWith('--site='))?.split('=')[1] || '';
const DEPTH = parseInt(process.argv.find(a => a.startsWith('--depth='))?.split('=')[1] || '3');

const scriptDir = __dirname;
const nodejsDir = path.join(scriptDir, 'ios', 'Runner', 'nodejs-project');
const nodeModulesDir = path.join(nodejsDir, 'node_modules');

function log(msg, color) {
    const colors = { red: 31, green: 32, yellow: 33, cyan: 36, gray: 90, white: 37, magenta: 35, blue: 34 };
    if (color && colors[color]) {
        console.log('\x1b[' + colors[color] + 'm' + msg + '\x1b[0m');
    } else {
        console.log(msg);
    }
}

function httpRequest(urlStr, method, body) {
    return new Promise((resolve, reject) => {
        const u = new URL(urlStr);
        const bodyStr = body ? JSON.stringify(body) : '';
        const options = {
            hostname: u.hostname, port: u.port, path: u.pathname + u.search,
            method: method || 'GET',
            headers: { 'Content-Type': 'application/json' }
        };
        if (body) options.headers['Content-Length'] = Buffer.byteLength(bodyStr);
        const req = http.request(options, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try { resolve({ status: res.statusCode, data: JSON.parse(data) }); }
                catch (e) { resolve({ status: res.statusCode, data: data }); }
            });
        });
        req.on('error', reject);
        req.setTimeout(20000, () => { req.destroy(); reject(new Error('timeout')); });
        if (body) req.write(bodyStr);
        req.end();
    });
}

function postJson(url, body) { return httpRequest(url, 'POST', body); }
function getJson(url) { return httpRequest(url, 'GET'); }
function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

function padR(str, len) {
    str = String(str);
    let displayLen = 0;
    for (const ch of str) { displayLen += ch.charCodeAt(0) > 0x7F ? 2 : 1; }
    return str + ' '.repeat(Math.max(0, len - displayLen));
}

let serverProc = null;
let sourcePort = 0;
let baseUrl = '';
const reportLines = [];

function rpt(line) { reportLines.push(line); }

async function startServer() {
    log('', 'cyan');
    log('============================================', 'cyan');
    log('  TVBox Source Diagnostic Tool v4.0', 'cyan');
    log('============================================', 'cyan');
    log('  Source:  ' + SOURCE_URL, 'gray');
    log('  Keyword: ' + TEST_KEYWORD, 'gray');
    log('  Mode:    ' + MODE, 'gray');
    if (TARGET_SITE) log('  Site:    ' + TARGET_SITE, 'gray');
    log('  Depth:   ' + DEPTH, 'gray');
    log('', 'cyan');

    rpt('TVBox Diagnostic Report v4.0 - ' + new Date().toISOString());
    rpt('Source: ' + SOURCE_URL);
    rpt('Mode: ' + MODE + ' | Depth: ' + DEPTH + (TARGET_SITE ? ' | Site: ' + TARGET_SITE : ''));
    rpt('='.repeat(100));

    log('[1/6] Checking dependencies...', 'yellow');
    if (!fs.existsSync(nodeModulesDir)) {
        log('  Installing npm dependencies...', 'yellow');
        await new Promise((resolve, reject) => {
            const npm = process.platform === 'win32' ? 'npm.cmd' : 'npm';
            const child = spawn(npm, ['install', '--legacy-peer-deps'], { cwd: nodejsDir, stdio: 'inherit' });
            child.on('close', code => code === 0 ? resolve() : reject(new Error('npm install failed')));
        });
    }
    log('  Dependencies OK', 'green');

    log('', 'cyan');
    log('[2/6] Downloading source...', 'yellow');
    const tempDir = path.join(require('os').tmpdir(), 'tvbox-diag-' + Date.now());
    fs.mkdirSync(tempDir, { recursive: true });
    const indexJsPath = path.join(tempDir, 'index.js');

    try {
        const sourceData = await new Promise((resolve, reject) => {
            const client = SOURCE_URL.startsWith('https') ? https : http;
            const doReq = (url, cb) => {
                client.get(url, { timeout: 30000 }, (resp) => {
                    if (resp.statusCode >= 300 && resp.statusCode < 400 && resp.headers.location) {
                        doReq(resp.headers.location, cb);
                    } else {
                        let d = ''; resp.on('data', c => d += c); resp.on('end', () => resolve(d)); resp.on('error', reject);
                    }
                }).on('error', reject);
            };
            doReq(SOURCE_URL, null);
        });
        fs.writeFileSync(indexJsPath, sourceData);
        log('  Downloaded: ' + (sourceData.length / 1024).toFixed(1) + ' KB', 'green');
    } catch (e) {
        log('  Download failed: ' + e.message, 'red');
        process.exit(1);
    }

    const configJsPath = path.join(tempDir, 'index.config.js');
    fs.writeFileSync(configJsPath, 'module.exports = { sites: { list: [] }, pans: { list: [] }, ali: { token: "" }, quark: { cookie: "" }, uc: { cookie: "", token: "" } };');

    log('', 'cyan');
    log('[3/6] Starting source server...', 'yellow');

    const env = Object.assign({}, process.env);
    env.NODE_PATH = nodeModulesDir;

    const launcherJs = path.join(tempDir, 'launcher.cjs');
    fs.writeFileSync(launcherJs, `
const http = require('http');
let spiderPort = 0;
globalThis.catServerFactory = function(handle) {
    const server = http.createServer((req, res) => { handle(req, res); });
    server.on('listening', () => { spiderPort = server.address().port; console.log('SPIDER_PORT:' + spiderPort); });
    return server;
};
globalThis.catDartServerPort = function() { return 0; };
const sourceModule = require('./index.js');
const config = require('./index.config.js');
console.log('Source module loaded, starting...');
const result = sourceModule.start(config);
if (result && typeof result.then === 'function') { result.catch(e => console.error('Start async error:', e.message)); }
`);

    serverProc = spawn('node', ['--security-revert=CVE-2023-46809', launcherJs], {
        cwd: tempDir, env: env, stdio: ['pipe', 'pipe', 'pipe']
    });

    serverProc.stdout.on('data', (data) => {
        const text = data.toString();
        for (const line of text.split('\n')) {
            if (line.trim()) log('  [stdout] ' + line.trim(), 'gray');
            const m = line.match(/SPIDER_PORT:(\d+)/);
            if (m) sourcePort = parseInt(m[1]);
        }
    });
    serverProc.stderr.on('data', (data) => {
        const text = data.toString();
        if (!text.includes('DeprecationWarning') && !text.includes('ExperimentalWarning')) {
            log('  [stderr] ' + text.trim(), 'red');
        }
    });

    await sleep(3000);
    if (serverProc.exitCode !== null) { log('  Server failed!', 'red'); process.exit(1); }

    log('  Waiting for source server...', 'gray');
    for (let attempt = 0; attempt < 15; attempt++) {
        await sleep(2000);
        if (sourcePort > 0) {
            try {
                const resp = await getJson('http://127.0.0.1:' + sourcePort + '/config');
                if (resp.status === 200 && resp.data && resp.data.video) {
                    log('  Source server ready on port: ' + sourcePort, 'green');
                    break;
                }
            } catch (e) {}
        }
        if (sourcePort === 0) {
            try {
                const resp = await getJson('http://127.0.0.1:9988/config');
                if (resp.status === 200 && resp.data && resp.data.video) {
                    sourcePort = 9988;
                    log('  Source server found on port: 9988', 'green');
                    break;
                }
            } catch (e) {}
        }
        if (attempt % 3 === 2) log('  Still waiting... (' + (attempt + 1) * 2 + 's)', 'gray');
    }

    if (sourcePort === 0) { log('  Source server not started!', 'red'); serverProc.kill(); process.exit(1); }
    baseUrl = 'http://127.0.0.1:' + sourcePort;
    return tempDir;
}

async function getConfig() {
    const resp = await getJson(baseUrl + '/config');
    return resp.data;
}

async function testSite(site) {
    const siteKey = site.key;
    const siteName = site.name;
    const siteType = site.type;
    const siteApi = site.api;
    const shortKey = siteKey.replace('nodejs_', '');

    let spiderPath = siteApi || ('/spider/' + shortKey + '/' + siteType);

    log('  -- ' + siteName + ' --', 'white');
    log('     [' + shortKey + '] type=' + siteType + (siteApi ? ' api=' + siteApi : ''), 'gray');

    const result = {
        name: siteName, key: shortKey, type: siteType,
        init: '-', home: '-', search: '-', categories: [], errors: [], info: []
    };

    // Init
    try {
        await postJson(baseUrl + spiderPath + '/init', {});
        result.init = 'OK';
    } catch (e) {
        result.init = 'FAIL';
        result.errors.push('Init: ' + e.message);
        log('    Init: FAIL', 'red');
        return result;
    }

    // Home - Level 1: categories + Level 2: filters
    let homeResult = null;
    try {
        const resp = await postJson(baseUrl + spiderPath + '/home', {});
        homeResult = resp.data;
        if (homeResult && homeResult.class && homeResult.class.length > 0) {
            result.home = 'OK';
            log('    Home: OK - ' + homeResult.class.length + ' categories', 'green');

            for (const cat of homeResult.class) {
                const catId = cat.type_id;
                const catName = cat.type_name;
                const catInfo = {
                    id: catId, name: catName,
                    filters: [],
                    categoryStatus: '-', categoryCount: 0, pagecount: 0,
                    sampleItems: [], detailStatus: '-', playStatus: '-'
                };

                // Level 2: Filters
                if (homeResult.filters) {
                    const catFilters = homeResult.filters[catId.toString()];
                    if (catFilters && catFilters.length > 0) {
                        for (const f of catFilters) {
                            const filterInfo = {
                                key: f.key, name: f.name || f.key, init: f.init || '',
                                values: (f.value || []).map(v => {
                                    if (typeof v === 'object') return { n: v.n || v.name || '', v: v.v || v.value || '' };
                                    return { n: String(v), v: String(v) };
                                })
                            };
                            catInfo.filters.push(filterInfo);
                        }
                    }
                }

                result.categories.push(catInfo);
            }
        } else {
            result.home = 'EMPTY';
            result.errors.push('Home: no categories');
            log('    Home: no categories', 'yellow');
        }
    } catch (e) {
        result.home = 'FAIL';
        result.errors.push('Home: ' + e.message);
        log('    Home: FAIL', 'red');
        return result;
    }

    // Level 3: Category content for each category
    if (DEPTH >= 3 && result.categories.length > 0) {
        for (const catInfo of result.categories) {
            let filterObj = {};
            for (const f of catInfo.filters) {
                if (f.init && f.init.toString() !== '') {
                    filterObj[f.key] = f.init;
                } else if (f.values.length > 0) {
                    filterObj[f.key] = f.values[0].v;
                }
            }

            let catData = null;
            try {
                const resp = await postJson(baseUrl + spiderPath + '/category', {
                    id: catInfo.id, page: 1, filters: filterObj
                });
                catData = resp.data;
            } catch (e) {
                try {
                    const resp = await postJson(baseUrl + spiderPath + '/category', {
                        id: catInfo.id, page: 1, filters: {}
                    });
                    catData = resp.data;
                } catch (e2) {}
            }

            if (catData && catData.list && catData.list.length > 0) {
                catInfo.categoryStatus = 'OK';
                catInfo.categoryCount = catData.list.length;
                catInfo.pagecount = catData.pagecount || 0;
                catInfo.sampleItems = catData.list.slice(0, 3).map(item => ({
                    id: item.vod_id, name: item.vod_name,
                    pic: item.vod_pic ? item.vod_pic.substring(0, 40) + '...' : '',
                    remarks: item.vod_remarks || ''
                }));
                log('    [' + catInfo.name + '] OK - ' + catInfo.categoryCount + ' items' +
                    (catInfo.filters.length > 0 ? ' (filters: ' + catInfo.filters.map(f => f.name).join(', ') + ')' : ''), 'green');
            } else {
                catInfo.categoryStatus = 'EMPTY';
                catInfo.pagecount = catData ? (catData.pagecount || 0) : 0;
                log('    [' + catInfo.name + '] EMPTY' + (catInfo.pagecount > 0 ? ' (pagecount=' + catInfo.pagecount + ')' : ''), 'red');
            }
        }
    }

    // Search
    try {
        const resp = await postJson(baseUrl + spiderPath + '/search', { wd: TEST_KEYWORD, page: 1 });
        const searchData = resp.data;
        let count = (searchData && searchData.list) ? searchData.list.length : 0;
        result.search = count > 0 ? 'OK(' + count + ')' : 'EMPTY';
        if (count > 0) {
            result.info.push('Search: ' + count + ' results, first: ' + searchData.list[0].vod_name);
        }
        log('    Search: ' + result.search, count > 0 ? 'green' : 'yellow');
    } catch (e) {
        result.search = 'FAIL';
        result.errors.push('Search: ' + e.message);
        log('    Search: FAIL', 'red');
    }

    // Level 4: Detail + Level 5: Play
    if (DEPTH >= 4) {
        let testVideoId = null;
        let testVideoName = '';

        for (const catInfo of result.categories) {
            if (catInfo.sampleItems && catInfo.sampleItems.length > 0) {
                testVideoId = catInfo.sampleItems[0].id;
                testVideoName = catInfo.sampleItems[0].name;
                break;
            }
        }

        if (!testVideoId) {
            try {
                const resp = await postJson(baseUrl + spiderPath + '/search', { wd: TEST_KEYWORD, page: 1 });
                if (resp.data && resp.data.list && resp.data.list.length > 0) {
                    testVideoId = resp.data.list[0].vod_id;
                    testVideoName = resp.data.list[0].vod_name;
                }
            } catch (e) {}
        }

        if (testVideoId) {
            log('    Detail: testing "' + testVideoName + '" (id=' + testVideoId + ')...', 'gray');
            try {
                const resp = await postJson(baseUrl + spiderPath + '/detail', { id: testVideoId });
                const detailData = resp.data;
                if (detailData && detailData.list && detailData.list.length > 0) {
                    const detail = detailData.list[0];
                    const playFroms = detail.vod_play_from ? detail.vod_play_from.split('$$$') : [];
                    const playUrls = detail.vod_play_url ? detail.vod_play_url.split('$$$') : [];

                    result.info.push('Detail: ' + detail.vod_name + ' | ' + playFroms.length + ' sources');
                    log('    Detail: OK - ' + detail.vod_name + ' | ' + playFroms.length + ' sources', 'green');

                    for (let i = 0; i < playFroms.length; i++) {
                        const from = playFroms[i];
                        const urls = playUrls[i] || '';
                        const epCount = urls.split('#').filter(u => u).length;
                        log('      Source[' + from + ']: ' + epCount + ' episodes', 'cyan');
                        result.info.push('  Source[' + from + ']: ' + epCount + ' episodes');
                    }

                    // Level 5: Play test
                    if (DEPTH >= 5 && playFroms.length > 0 && playUrls.length > 0) {
                        const firstEp = playUrls[0].split('#')[0];
                        let epUrl = firstEp;
                        if (firstEp.includes('$$$')) epUrl = firstEp.split('$$$').pop();
                        let epName = epUrl;
                        const dollarIdx = epUrl.indexOf('$');
                        if (dollarIdx >= 0) {
                            epName = epUrl.substring(0, dollarIdx);
                            epUrl = epUrl.substring(dollarIdx + 1);
                        }

                        try {
                            const playResp = await postJson(baseUrl + spiderPath + '/play', {
                                flag: playFroms[0], id: epUrl
                            });
                            const playData = playResp.data;
                            if (playData && (playData.url || playData.parse)) {
                                const urlPreview = playData.url ? playData.url.substring(0, 80) : '(parse mode)';
                                log('    Play: OK - ' + urlPreview, 'green');
                                result.info.push('  Play: ' + urlPreview);
                            } else {
                                log('    Play: no URL returned', 'yellow');
                            }
                        } catch (e) {
                            log('    Play: FAIL - ' + e.message, 'red');
                            result.errors.push('Play: ' + e.message);
                        }
                    }
                } else {
                    log('    Detail: empty response', 'yellow');
                }
            } catch (e) {
                log('    Detail: FAIL - ' + e.message, 'red');
                result.errors.push('Detail: ' + e.message);
            }
        } else {
            log('    Detail: no video ID available for testing', 'gray');
        }
    }

    return result;
}

function generateReport(results) {
    rpt('');
    rpt('SUMMARY');
    rpt('='.repeat(100));

    const total = results.length;
    const initOK = results.filter(r => r.init === 'OK').length;
    const homeOK = results.filter(r => r.home === 'OK').length;
    const catOK = results.filter(r => r.categories.some(c => c.categoryStatus === 'OK')).length;
    const searchOK = results.filter(r => r.search.startsWith('OK')).length;

    rpt('Total: ' + total + ' | Init: ' + initOK + ' | Home: ' + homeOK + ' | Category: ' + catOK + ' | Search: ' + searchOK);
    rpt('');

    // Overview table
    rpt(padR('Site', 28) + padR('Key', 16) + padR('Init', 6) + padR('Home', 6) + padR('Cats', 6) + padR('Filters', 8) + padR('CatOK', 6) + padR('Search', 10));
    rpt('-'.repeat(100));

    for (const r of results) {
        const totalFilters = r.categories.reduce((s, c) => s + c.filters.length, 0);
        const catOKCount = r.categories.filter(c => c.categoryStatus === 'OK').length;
        rpt(padR(r.name, 28) + padR(r.key, 16) + padR(r.init, 6) + padR(r.home, 6) +
            padR(String(r.categories.length), 6) + padR(String(totalFilters), 8) +
            padR(catOKCount + '/' + r.categories.length, 6) + padR(r.search, 10));
    }

    // Detailed per-site report
    rpt('');
    rpt('='.repeat(100));
    rpt('DETAILED REPORT');
    rpt('='.repeat(100));

    for (const r of results) {
        rpt('');
        rpt('--- ' + r.name + ' [' + r.key + '] ---');
        rpt('  Init: ' + r.init + ' | Home: ' + r.home + ' | Search: ' + r.search);

        if (r.categories.length > 0) {
            rpt('');
            rpt('  Level 1 - Categories (' + r.categories.length + '):');
            for (const cat of r.categories) {
                rpt('    [' + cat.id + '] ' + cat.name + ' -> ' + cat.categoryStatus +
                    (cat.categoryCount > 0 ? ' (' + cat.categoryCount + ' items, pagecount=' + cat.pagecount + ')' : ''));

                if (cat.filters.length > 0) {
                    rpt('      Level 2 - Filters (' + cat.filters.length + '):');
                    for (const f of cat.filters) {
                        const valPreview = f.values.slice(0, 5).map(v => v.n + '=' + v.v).join(', ') +
                            (f.values.length > 5 ? ' ... (+' + (f.values.length - 5) + ' more)' : '');
                        rpt('        ' + f.name + ' [' + f.key + '] init=' + f.init + ' values=[' + valPreview + ']');
                    }
                }

                if (cat.sampleItems.length > 0) {
                    rpt('      Level 3 - Sample items:');
                    for (const item of cat.sampleItems) {
                        rpt('        ' + item.name + ' (id=' + item.id + ')' + (item.remarks ? ' [' + item.remarks + ']' : ''));
                    }
                }
            }
        }

        for (const e of r.errors) rpt('  ERROR: ' + e);
        for (const i of r.info) rpt('  INFO: ' + i);
    }

    // Problem summary
    const problemSites = results.filter(r => r.errors.length > 0);
    if (problemSites.length > 0) {
        rpt('');
        rpt('='.repeat(100));
        rpt('PROBLEM SITES');
        rpt('='.repeat(100));
        for (const s of problemSites) {
            rpt('  ' + s.name + ' [' + s.key + ']');
            for (const e of s.errors) rpt('    - ' + e);
        }
    }

    // Empty categories
    const emptyCats = results.filter(r => r.categories.some(c => c.categoryStatus === 'EMPTY'));
    if (emptyCats.length > 0) {
        rpt('');
        rpt('EMPTY CATEGORIES');
        rpt('-'.repeat(100));
        for (const s of emptyCats) {
            const empties = s.categories.filter(c => c.categoryStatus === 'EMPTY');
            rpt('  ' + s.name + ' [' + s.key + ']: ' + empties.map(c => c.name + '(pc=' + c.pagecount + ')').join(', '));
        }
    }

    // Filter summary - show all filter structures
    const sitesWithFilters = results.filter(r => r.categories.some(c => c.filters.length > 0));
    if (sitesWithFilters.length > 0) {
        rpt('');
        rpt('='.repeat(100));
        rpt('FILTER STRUCTURE SUMMARY');
        rpt('='.repeat(100));
        for (const s of sitesWithFilters) {
            rpt('');
            rpt('  ' + s.name + ' [' + s.key + ']:');
            for (const cat of s.categories) {
                if (cat.filters.length > 0) {
                    rpt('    [' + cat.name + '] ' + cat.filters.length + ' filters:');
                    for (const f of cat.filters) {
                        const allVals = f.values.map(v => v.n).join(', ');
                        rpt('      ' + f.name + ' [' + f.key + ']: ' + allVals);
                    }
                }
            }
        }
    }
}

async function main() {
    const tempDir = await startServer();

    log('', 'cyan');
    log('[4/6] Getting config...', 'yellow');
    let config;
    try {
        config = await getConfig();
    } catch (e) {
        log('  Failed: ' + e.message, 'red');
        serverProc.kill();
        process.exit(1);
    }

    const sites = config.video.sites;
    log('  Found ' + sites.length + ' sites', 'green');

    let targetSites = sites;
    if (TARGET_SITE) {
        targetSites = sites.filter(s => {
            const key = s.key.replace('nodejs_', '');
            return key === TARGET_SITE || s.name.includes(TARGET_SITE) || s.key.includes(TARGET_SITE);
        });
        if (targetSites.length === 0) {
            log('  Site "' + TARGET_SITE + '" not found!', 'red');
            log('  Available: ' + sites.map(s => s.key.replace('nodejs_', '')).join(', '), 'gray');
            serverProc.kill();
            process.exit(1);
        }
        log('  Targeting ' + targetSites.length + ' site(s)', 'yellow');
    }

    log('', 'cyan');
    log('[5/6] Testing ' + targetSites.length + ' site(s) (depth=' + DEPTH + ')...', 'yellow');
    log('', 'cyan');

    const results = [];
    for (const site of targetSites) {
        const result = await testSite(site);
        results.push(result);
        log('', 'cyan');
    }

    log('[6/6] Generating report...', 'yellow');
    generateReport(results);

    const reportPath = path.join(scriptDir, 'diagnostic-report.txt');
    fs.writeFileSync(reportPath, reportLines.join('\n'), 'utf8');
    log('  Report saved: ' + reportPath, 'cyan');

    log('', 'cyan');
    log('  Cleaning up...', 'gray');
    serverProc.kill();
    await sleep(500);
    try { fs.rmSync(tempDir, { recursive: true, force: true }); } catch (e) {}

    log('', 'cyan');
    log('============================================', 'cyan');
    log('  Diagnostic complete!', 'green');
    log('============================================', 'cyan');
}

main().catch(e => {
    log('Fatal error: ' + e.message, 'red');
    if (serverProc) serverProc.kill();
    process.exit(1);
});
