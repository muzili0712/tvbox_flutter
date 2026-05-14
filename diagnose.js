const http = require('http');
const https = require('https');
const { exec, spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const SOURCE_URL = process.argv[2] || 'https://9280.kstore.vip/cat/index.js';
const TEST_KEYWORD = process.argv[3] || '\u5e86\u4f59\u5e74';
const SKIP_DETAIL = process.argv.includes('--skip-detail');
const SKIP_SEARCH = process.argv.includes('--skip-search');
const SKIP_CATEGORY = process.argv.includes('--skip-category');

const scriptDir = __dirname;
const nodejsDir = path.join(scriptDir, 'ios', 'Runner', 'nodejs-project');
const nodeModulesDir = path.join(nodejsDir, 'node_modules');

function log(msg, color) {
    const colors = { red: 31, green: 32, yellow: 33, cyan: 36, gray: 90, white: 37 };
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
        if (body) {
            options.headers['Content-Length'] = Buffer.byteLength(bodyStr);
        }
        const req = http.request(options, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try {
                    resolve({ status: res.statusCode, data: JSON.parse(data) });
                } catch (e) {
                    resolve({ status: res.statusCode, data: data });
                }
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

async function main() {
    log('', 'cyan');
    log('=======================================', 'cyan');
    log('  TVBox Source Diagnostic Tool v3.0', 'cyan');
    log('=======================================', 'cyan');
    log('  Source: ' + SOURCE_URL, 'gray');
    log('  Keyword: ' + TEST_KEYWORD, 'gray');
    log('', 'cyan');

    // 1. Check dependencies
    log('[1/5] Checking dependencies...', 'yellow');
    if (!fs.existsSync(nodeModulesDir)) {
        log('  Installing npm dependencies...', 'yellow');
        await new Promise((resolve, reject) => {
            const npm = process.platform === 'win32' ? 'npm.cmd' : 'npm';
            const child = spawn(npm, ['install', '--legacy-peer-deps'], { cwd: nodejsDir, stdio: 'inherit' });
            child.on('close', code => code === 0 ? resolve() : reject(new Error('npm install failed')));
        });
    }
    log('  Dependencies OK', 'green');

    // 2. Download source
    log('', 'cyan');
    log('[2/5] Downloading source...', 'yellow');
    const tempDir = path.join(require('os').tmpdir(), 'tvbox-diag-' + Date.now());
    fs.mkdirSync(tempDir, { recursive: true });
    const indexJsPath = path.join(tempDir, 'index.js');

    try {
        const sourceData = await new Promise((resolve, reject) => {
            const client = SOURCE_URL.startsWith('https') ? https : http;
            client.get(SOURCE_URL, { timeout: 30000 }, (resp) => {
                if (resp.statusCode >= 300 && resp.statusCode < 400 && resp.headers.location) {
                    const redirectUrl = resp.headers.location;
                    const redirectClient = redirectUrl.startsWith('https') ? https : http;
                    redirectClient.get(redirectUrl, { timeout: 30000 }, (r2) => {
                        let d = '';
                        r2.on('data', chunk => d += chunk);
                        r2.on('end', () => resolve(d));
                        r2.on('error', reject);
                    }).on('error', reject);
                } else {
                    let d = '';
                    resp.on('data', chunk => d += chunk);
                    resp.on('end', () => resolve(d));
                    resp.on('error', reject);
                }
            }).on('error', reject);
        });
        fs.writeFileSync(indexJsPath, sourceData);
        log('  Downloaded: ' + (sourceData.length / 1024).toFixed(1) + ' KB', 'green');
    } catch (e) {
        log('  Download failed: ' + e.message, 'red');
        process.exit(1);
    }

    const configJsPath = path.join(tempDir, 'index.config.js');
    fs.writeFileSync(configJsPath, 'module.exports = { sites: { list: [] }, pans: { list: [] }, ali: { token: "" }, quark: { cookie: "" }, uc: { cookie: "", token: "" } };');

    // 3. Start source server directly
    log('', 'cyan');
    log('[3/5] Starting source server...', 'yellow');

    const env = Object.assign({}, process.env);
    env.NODE_PATH = nodeModulesDir;

    const launcherJs = path.join(tempDir, 'launcher.cjs');
    const launcherCode = `
const http = require('http');
let spiderPort = 0;

globalThis.catServerFactory = function(handle) {
    const server = http.createServer((req, res) => {
        handle(req, res);
    });
    server.on('listening', () => {
        spiderPort = server.address().port;
        console.log('SPIDER_PORT:' + spiderPort);
    });
    return server;
};

globalThis.catDartServerPort = function() { return 0; };

const sourceModule = require('./index.js');
const config = require('./index.config.js');
console.log('Source module loaded, starting...');
const result = sourceModule.start(config);
if (result && typeof result.then === 'function') {
    result.catch(e => console.error('Start async error:', e.message));
}
`;
    fs.writeFileSync(launcherJs, launcherCode);

    const serverProc = spawn('node', ['--security-revert=CVE-2023-46809', launcherJs], {
        cwd: tempDir,
        env: env,
        stdio: ['pipe', 'pipe', 'pipe']
    });

    let sourcePort = 0;

    serverProc.stdout.on('data', (data) => {
        const text = data.toString();
        const lines = text.split('\n');
        for (const line of lines) {
            if (line.trim()) log('  [stdout] ' + line.trim(), 'gray');
            const listenMatch = line.match(/Server listening on\s+(.+)/);
            if (listenMatch) {
                const addr = listenMatch[1].trim();
                const portMatch = addr.match(/:(\d+)/);
                if (portMatch) sourcePort = parseInt(portMatch[1]);
            }
            const spiderMatch = line.match(/Spider server running on\s+(\d+)/);
            if (spiderMatch) sourcePort = parseInt(spiderMatch[1]);
            const spiderPortMatch = line.match(/SPIDER_PORT:(\d+)/);
            if (spiderPortMatch) sourcePort = parseInt(spiderPortMatch[1]);
        }
    });

    serverProc.stderr.on('data', (data) => {
        const text = data.toString();
        if (text.includes('DeprecationWarning') || text.includes('ExperimentalWarning')) return;
        log('  [stderr] ' + text.trim(), 'red');
    });

    await sleep(3000);

    if (serverProc.exitCode !== null) {
        log('  Server failed to start!', 'red');
        process.exit(1);
    }

    // Wait for source server to be ready
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

        // Also try port 9988 (default dev port)
        if (sourcePort === 0) {
            try {
                const resp = await getJson('http://127.0.0.1:9988/config');
                if (resp.status === 200 && resp.data && resp.data.video) {
                    sourcePort = 9988;
                    log('  Source server found on default port: 9988', 'green');
                    break;
                }
            } catch (e) {}
        }

        // Try to find port via netstat
        if (sourcePort === 0) {
            try {
                const pid = serverProc.pid;
                const netstat = await new Promise((resolve) => {
                    exec('netstat -ano | findstr ' + pid, (err, stdout) => resolve(stdout || ''));
                });
                const lines = netstat.split('\n');
                for (const line of lines) {
                    const listenMatch = line.match(/\s+0\.0\.0\.0:(\d+)\s+.*LISTENING/);
                    if (listenMatch) {
                        const p = parseInt(listenMatch[1]);
                        try {
                            const resp = await getJson('http://127.0.0.1:' + p + '/config');
                            if (resp.status === 200 && resp.data && resp.data.video) {
                                sourcePort = p;
                                log('  Source server found on port: ' + p, 'green');
                                break;
                            }
                        } catch (e) {}
                    }
                }
            } catch (e) {}
        }

        if (attempt % 3 === 2) {
            log('  Still waiting... (' + (attempt + 1) * 2 + 's)', 'gray');
        }
    }

    if (sourcePort === 0) {
        log('  Source server not started!', 'red');
        serverProc.kill();
        process.exit(1);
    }

    const baseUrl = 'http://127.0.0.1:' + sourcePort;

    // 4. Test sites
    log('', 'cyan');
    log('[4/5] Testing sites...', 'yellow');
    log('', 'cyan');

    let config;
    try {
        const resp = await getJson(baseUrl + '/config');
        config = resp.data;
    } catch (e) {
        log('  Failed to get config: ' + e.message, 'red');
        serverProc.kill();
        process.exit(1);
    }

    const sites = config.video.sites;
    log('  Found ' + sites.length + ' sites', 'green');
    log('', 'cyan');

    const results = [];

    for (const site of sites) {
        const siteKey = site.key;
        const siteName = site.name;
        const siteType = site.type;
        const siteApi = site.api;
        const shortKey = siteKey.replace('nodejs_', '');

        let spiderPath;
        if (siteApi) {
            spiderPath = siteApi;
        } else {
            spiderPath = '/spider/' + shortKey + '/' + siteType;
        }

        let rInit = '-', rHome = '-', rCategory = '-', rSearch = '-', rDetail = '-', rPlay = '-';
        const errors = [];
        const info = [];

        log('  -- ' + siteName + ' --', 'white');
        log('     [' + shortKey + ']', 'gray');

        // Init
        try {
            await postJson(baseUrl + spiderPath + '/init', {});
            rInit = 'OK';
        } catch (e) {
            rInit = 'FAIL';
            errors.push('Init: ' + e.message);
            log('    Init: FAIL', 'red');
            results.push({ name: siteName, key: shortKey, init: rInit, home: rHome, category: rCategory, search: rSearch, detail: rDetail, play: rPlay, errors, info });
            continue;
        }

        // Home
        let homeResult = null;
        try {
            const resp = await postJson(baseUrl + spiderPath + '/home', {});
            homeResult = resp.data;
            if (homeResult && homeResult.class && homeResult.class.length > 0) {
                rHome = 'OK';
                const catNames = homeResult.class.map(c => c.type_name).join(', ');
                info.push('Categories: ' + catNames);
                log('    Home: OK - ' + homeResult.class.length + ' categories', 'green');
            } else {
                rHome = 'EMPTY';
                errors.push('Home: no categories');
                log('    Home: no categories', 'yellow');
            }
        } catch (e) {
            rHome = 'FAIL';
            errors.push('Home: ' + e.message);
            log('    Home: FAIL', 'red');
        }

        // Category
        let catResult = null;
        if (homeResult && homeResult.class && homeResult.class.length > 0 && !SKIP_CATEGORY) {
            const firstCat = homeResult.class[0];
            const catId = firstCat.type_id;
            const catName = firstCat.type_name;

            let filterObj = {};
            if (homeResult.filters) {
                const catIdStr = catId.toString();
                const catFilters = homeResult.filters[catIdStr];
                if (catFilters) {
                    for (const f of catFilters) {
                        if (f.init && f.init.toString() !== '') {
                            filterObj[f.key] = f.init;
                        } else if (f.value && f.value.length > 0) {
                            filterObj[f.key] = f.value[0].v;
                        }
                    }
                }
            }

            try {
                const resp = await postJson(baseUrl + spiderPath + '/category', { id: catId, page: 1, filters: filterObj });
                catResult = resp.data;
                let listCount = (catResult && catResult.list) ? catResult.list.length : 0;

                if (listCount > 0) {
                    rCategory = 'OK(' + listCount + ')';
                    info.push('Category[' + catName + ']: ' + listCount + ' items');
                    log('    Category[' + catName + ']: OK - ' + listCount + ' items', 'green');
                } else {
                    try {
                        const retryResp = await postJson(baseUrl + spiderPath + '/category', { id: catId, page: 1, filters: {} });
                        const retryResult = retryResp.data;
                        let retryCount = (retryResult && retryResult.list) ? retryResult.list.length : 0;
                        if (retryCount > 0) {
                            rCategory = 'OK*(' + retryCount + ')';
                            info.push('Category[' + catName + ']: ' + retryCount + ' items (empty filters)');
                            log('    Category[' + catName + ']: OK (empty filters) - ' + retryCount + ' items', 'green');
                        } else {
                            rCategory = 'EMPTY';
                            const pc = catResult ? catResult.pagecount : '?';
                            errors.push('Category[' + catName + ']: empty list (pagecount=' + pc + ')');
                            log('    Category[' + catName + ']: EMPTY! pagecount=' + pc, 'red');
                        }
                    } catch (e2) {
                        rCategory = 'EMPTY';
                        errors.push('Category[' + catName + ']: retry failed');
                        log('    Category[' + catName + ']: retry failed', 'red');
                    }
                }
            } catch (e) {
                rCategory = 'FAIL';
                errors.push('Category: ' + e.message);
                log('    Category: FAIL', 'red');
            }
        }

        // Search
        let searchResult = null;
        if (!SKIP_SEARCH) {
            try {
                const resp = await postJson(baseUrl + spiderPath + '/search', { wd: TEST_KEYWORD, page: 1 });
                searchResult = resp.data;
                let searchCount = (searchResult && searchResult.list) ? searchResult.list.length : 0;
                if (searchCount > 0) {
                    rSearch = 'OK(' + searchCount + ')';
                    log('    Search: OK - ' + searchCount + ' results', 'green');
                } else {
                    rSearch = 'EMPTY';
                    log('    Search: no results', 'yellow');
                }
            } catch (e) {
                rSearch = 'FAIL';
                errors.push('Search: ' + e.message);
                log('    Search: FAIL', 'red');
            }
        }

        // Detail & Play
        if (!SKIP_DETAIL) {
            let testVideoId = null;
            if (searchResult && searchResult.list && searchResult.list.length > 0) {
                testVideoId = searchResult.list[0].vod_id;
            } else if (catResult && catResult.list && catResult.list.length > 0) {
                testVideoId = catResult.list[0].vod_id;
            }

            if (testVideoId) {
                try {
                    const resp = await postJson(baseUrl + spiderPath + '/detail', { id: testVideoId });
                    const detailResult = resp.data;
                    if (detailResult && detailResult.list && detailResult.list.length > 0) {
                        const detail = detailResult.list[0];
                        let playFrom = 0;
                        if (detail.vod_play_from) {
                            playFrom = detail.vod_play_from.split('$$$').length;
                        }
                        rDetail = 'OK(' + playFrom + ' src)';
                        log('    Detail: OK - ' + playFrom + ' sources', 'green');

                        if (detail.vod_play_url) {
                            const firstEp = detail.vod_play_url.split('#')[0];
                            let epUrl = firstEp;
                            if (firstEp.includes('$$$')) {
                                epUrl = firstEp.split('$$$').pop();
                            }
                            let playFlag = '';
                            if (detail.vod_play_from) {
                                playFlag = detail.vod_play_from.split('$$$')[0];
                            }

                            try {
                                const playResp = await postJson(baseUrl + spiderPath + '/play', { flag: playFlag, id: epUrl });
                                const playResult = playResp.data;
                                if (playResult && (playResult.url || playResult.parse)) {
                                    rPlay = 'OK';
                                    let urlPreview = '';
                                    if (playResult.url) {
                                        urlPreview = playResult.url.substring(0, Math.min(60, playResult.url.length));
                                    }
                                    log('    Play: OK - ' + urlPreview + '...', 'green');
                                } else {
                                    rPlay = 'EMPTY';
                                    log('    Play: no URL', 'yellow');
                                }
                            } catch (e) {
                                rPlay = 'FAIL';
                                errors.push('Play: ' + e.message);
                                log('    Play: FAIL', 'red');
                            }
                        }
                    } else {
                        rDetail = 'EMPTY';
                        log('    Detail: empty', 'yellow');
                    }
                } catch (e) {
                    rDetail = 'FAIL';
                    errors.push('Detail: ' + e.message);
                    log('    Detail: FAIL', 'red');
                }
            } else {
                log('    Detail: skipped (no test ID)', 'gray');
            }
        }

        results.push({ name: siteName, key: shortKey, init: rInit, home: rHome, category: rCategory, search: rSearch, detail: rDetail, play: rPlay, errors, info });
        log('', 'cyan');
    }

    // 5. Report
    log('[5/5] Diagnostic Report', 'yellow');
    log('=======================================', 'cyan');

    const initOK = results.filter(r => r.init === 'OK').length;
    const homeOK = results.filter(r => r.home === 'OK').length;
    const catOK = results.filter(r => r.category.startsWith('OK')).length;
    const searchOK = results.filter(r => r.search.startsWith('OK')).length;
    const detailOK = results.filter(r => r.detail.startsWith('OK')).length;
    const playOK = results.filter(r => r.play === 'OK').length;
    const total = results.length;

    log('', 'cyan');
    log('  Total sites: ' + total, 'white');
    log('  Init:     ' + initOK + ' / ' + total, initOK === total ? 'green' : 'yellow');
    log('  Home:     ' + homeOK + ' / ' + total, homeOK === total ? 'green' : 'yellow');
    log('  Category: ' + catOK + ' / ' + total, catOK === total ? 'green' : 'yellow');
    log('  Search:   ' + searchOK + ' / ' + total, searchOK === total ? 'green' : 'yellow');
    log('  Detail:   ' + detailOK + ' / ' + total, detailOK === total ? 'green' : 'yellow');
    log('  Play:     ' + playOK + ' / ' + total, playOK === total ? 'green' : 'yellow');

    const problemSites = results.filter(r => r.errors.length > 0);
    if (problemSites.length > 0) {
        log('', 'cyan');
        log('  Problem sites:', 'red');
        for (const s of problemSites) {
            log('    ' + s.name + ' [' + s.key + ']', 'yellow');
            for (const e of s.errors) {
                log('      - ' + e, 'gray');
            }
        }
    }

    const emptyCat = results.filter(r => r.category === 'EMPTY');
    if (emptyCat.length > 0) {
        log('', 'cyan');
        log('  Empty category sites:', 'yellow');
        for (const s of emptyCat) {
            log('    ' + s.name + ' [' + s.key + ']', 'gray');
        }
    }

    const reportPath = path.join(scriptDir, 'diagnostic-report.txt');
    const reportLines = [];
    reportLines.push('TVBox Diagnostic Report - ' + new Date().toISOString());
    reportLines.push('Source: ' + SOURCE_URL);
    reportLines.push('='.repeat(80));
    reportLines.push('');
    reportLines.push('Summary: Total=' + total + ' | Init=' + initOK + ' | Home=' + homeOK + ' | Category=' + catOK + ' | Search=' + searchOK + ' | Detail=' + detailOK + ' | Play=' + playOK);
    reportLines.push('');
    const header = padR('Site', 25) + padR('Key', 15) + padR('Init', 8) + padR('Home', 8) + padR('Category', 12) + padR('Search', 12) + padR('Detail', 12) + padR('Play', 8);
    reportLines.push(header);
    reportLines.push('-'.repeat(80));

    for (const r of results) {
        const line = padR(r.name, 25) + padR(r.key, 15) + padR(r.init, 8) + padR(r.home, 8) + padR(r.category, 12) + padR(r.search, 12) + padR(r.detail, 12) + padR(r.play, 8);
        reportLines.push(line);
        for (const e of r.errors) {
            reportLines.push('  ERROR: ' + e);
        }
        for (const i of r.info) {
            reportLines.push('  INFO: ' + i);
        }
    }

    fs.writeFileSync(reportPath, reportLines.join('\n'), 'utf8');
    log('', 'cyan');
    log('  Report saved: ' + reportPath, 'cyan');

    log('', 'cyan');
    log('  Cleaning up...', 'gray');
    serverProc.kill();
    await sleep(500);
    try { fs.rmSync(tempDir, { recursive: true, force: true }); } catch (e) {}

    log('', 'cyan');
    log('=======================================', 'cyan');
    log('  Diagnostic complete!', 'green');
    log('=======================================', 'cyan');
}

function padR(str, len) {
    str = String(str);
    let displayLen = 0;
    for (const ch of str) {
        displayLen += ch.charCodeAt(0) > 0x7F ? 2 : 1;
    }
    const pad = Math.max(0, len - displayLen);
    return str + ' '.repeat(pad);
}

main().catch(e => {
    log('Fatal error: ' + e.message, 'red');
    process.exit(1);
});
