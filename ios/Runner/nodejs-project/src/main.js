const { createServer } = require('http');
const axios = require('axios');
const { registerSpider, clearSpiders, spiders, spiderPrefix } = require('./router.js');

let addon = null;
let sourceModule = null;
let nativeServerPort = 0;
let managementPort = 0;
let isReady = false;

try {
    addon = process._linkedBinding('myaddon');
} catch (e) {
    addon = null;
}

const nativePortIdx = process.argv.indexOf('--native-port');
if (nativePortIdx !== -1 && process.argv[nativePortIdx + 1]) {
    nativeServerPort = parseInt(process.argv[nativePortIdx + 1], 10);
}

globalThis.catServerFactory = (handle) => {
    let port = 0;
    const server = createServer((req, res) => {
        handle(req, res);
    });
    server.on('listening', () => {
        port = server.address().port;
        if (nativeServerPort > 0) {
            axios.get(`http://127.0.0.1:${nativeServerPort}/onCatPawOpenPort?port=${port}&type=spider`).catch(() => {});
        }
        console.log('Spider server running on ' + port);
    });
    server.on('close', () => {
        console.log('Spider server closed on ' + port);
    });
    return server;
};

globalThis.catDartServerPort = () => nativeServerPort;

function loadScript(path) {
    console.log('=== loadScript called with path:', path);
    const indexJSPath = path + '/index.js';
    const indexConfigJSPath = path + '/index.config.js';
    console.log('Loading index.js from:', indexJSPath);
    
    try {
        delete require.cache[require.resolve(indexJSPath)];
    } catch (e) {
        console.log('No cache to delete for index.js');
    }
    
    try { 
        delete require.cache[require.resolve(indexConfigJSPath)]; 
    } catch (e) {
        console.log('No cache to delete for index.config.js');
    }
    
    try {
        sourceModule = require(indexJSPath);
        console.log('index.js loaded successfully');
    } catch (e) {
        console.error('ERROR loading index.js:', e);
        console.error('Stack:', e.stack);
        throw e;
    }
    
    let config = {};
    try {
        const configModule = require(indexConfigJSPath);
        config = configModule.default || configModule;
        console.log('Config loaded');
    } catch (e) {
        console.log('Config load skipped:', e.message);
    }
    
    try {
        console.log('Calling sourceModule.start(config)...');
        sourceModule.start(config);
        console.log('sourceModule.start(config) completed');
    } catch (e) {
        console.error('ERROR in sourceModule.start(config):', e);
        console.error('Stack:', e.stack);
        throw e;
    }
}

function sendMessageToNative(message) {
    if (addon && addon.sendMessageToNative) {
        try {
            addon.sendMessageToNative(message);
            return;
        } catch (e) {
            console.log('addon.sendMessageToNative failed:', e.message);
        }
    }
    if (nativeServerPort > 0) {
        axios.post(`http://127.0.0.1:${nativeServerPort}/onMessage`, { message: message }).catch(() => {});
    }
}

function handleNativeMessage(msg) {
    try {
        const data = JSON.parse(msg);
        switch (data.action) {
            case 'run':
                try {
                    if (sourceModule && typeof sourceModule.stop === 'function') {
                        sourceModule.stop();
                    }
                } catch (e) {}
                clearSpiders();
                loadScript(data.path);
                break;
            case 'nativeServerPort':
                nativeServerPort = data.port;
                break;
            default:
                break;
        }
    } catch (e) {
        console.log('handleNativeMessage error:', e);
    }
}

if (addon && addon.registerCallback) {
    addon.registerCallback((msg) => {
        console.log('Message from Native:', msg);
        handleNativeMessage(msg);
    });
}

const mgmtServer = createServer((req, res) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }

    const url = new URL(req.url, `http://127.0.0.1`);

    if (req.method === 'GET' && url.pathname === '/check') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ run: true, ready: isReady }));
        return;
    }

    if (req.method === 'GET' && url.pathname === '/source/status') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            sourceLoaded: sourceModule !== null,
            spiderCount: spiders.length,
            ready: isReady,
        }));
        return;
    }

    if (req.method === 'GET' && url.pathname === '/source/list') {
        const sourceList = spiders.map(s => ({
            key: s.meta.key,
            name: s.meta.name,
            type: s.meta.type,
        }));
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ sources: sourceList }));
        return;
    }

    if (req.method === 'POST' && url.pathname === '/command') {
        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', () => {
            try {
                const data = JSON.parse(body);
                handleNativeMessage(JSON.stringify(data));
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ success: true }));
            } catch (e) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: e.message }));
            }
        });
        return;
    }

    if (req.method === 'POST' && url.pathname === '/source/loadPath') {
        console.log('=== /source/loadPath endpoint called ===');
        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', () => {
            try {
                console.log('Request body:', body);
                const data = JSON.parse(body);
                const sourcePath = data.path;
                console.log('sourcePath:', sourcePath);
                
                if (!sourcePath) {
                    console.log('ERROR: path is required');
                    res.writeHead(400, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ error: 'path is required' }));
                    return;
                }
                
                try {
                    if (sourceModule && typeof sourceModule.stop === 'function') {
                        console.log('Stopping existing sourceModule');
                        sourceModule.stop();
                    }
                } catch (e) {
                    console.log('Error stopping sourceModule (non-fatal):', e.message);
                }
                
                console.log('Clearing spiders');
                clearSpiders();
                
                console.log('Calling loadScript');
                loadScript(sourcePath);
                
                console.log('=== Success! Returning 200 ===');
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ success: true, message: 'Source loaded from path' }));
            } catch (e) {
                console.error('=== ERROR in /source/loadPath ===');
                console.error('Error:', e);
                console.error('Stack:', e.stack);
                res.writeHead(500, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: e.message }));
            }
        });
        return;
    }

    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'not found' }));
});

mgmtServer.listen(0, '127.0.0.1', () => {
    managementPort = mgmtServer.address().port;
    if (nativeServerPort > 0) {
        axios.get(`http://127.0.0.1:${nativeServerPort}/onCatPawOpenPort?port=${managementPort}&type=management`).catch(() => {});
    }
    isReady = true;
    sendMessageToNative('ready');
});

process.on('uncaughtException', function (err) {
    console.error('Caught exception:', err);
});
