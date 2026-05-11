import { createServer } from 'http';
import Fastify from 'fastify';
import axios from 'axios';
import { registerSpider, clearSpiders, spiders, spiderPrefix } from './router.js';

let sourceModule = null;
let nativeServerPort = 0;
let managementPort = 0;

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
    });
    server.on('close', () => {
        console.log('Spider server closed on ' + port);
    });
    return server;
};

globalThis.catDartServerPort = () => nativeServerPort;

function loadScript(path) {
    try {
        const indexJSPath = path + '/index.js';
        const indexConfigJSPath = path + '/index.config.js';
        delete require.cache[require.resolve(indexJSPath)];
        try { delete require.cache[require.resolve(indexConfigJSPath)]; } catch(e) {}
        sourceModule = require(indexJSPath);
        const config = require(indexConfigJSPath);
        sourceModule.start(config.default || config);
    } catch (e) {
        console.log('loadScript error:', e);
    }
}

const managementServer = Fastify({ logger: false });

managementServer.get('/check', async () => {
    return { run: true, management: true };
});

managementServer.post('/command', async (request) => {
    const data = request.body || {};
    switch (data.action) {
        case 'run':
            await sourceModule?.stop?.();
            loadScript(data.path);
            return { success: true };
        case 'nativeServerPort':
            nativeServerPort = data.port;
            return { success: true };
        default:
            return { error: 'unknown action' };
    }
});

managementServer.post('/source/loadPath', async (request) => {
    const { path: sourcePath } = request.body || {};
    if (!sourcePath) {
        return { error: 'path is required' };
    }
    try {
        await sourceModule?.stop?.();
        loadScript(sourcePath);
        return { success: true, message: 'Source loaded from path' };
    } catch (e) {
        return { error: e.message };
    }
});

managementServer.get('/source/list', async () => {
    const sourceList = spiders.map(s => ({
        key: s.meta.key,
        name: s.meta.name,
        type: s.meta.type,
    }));
    return { sources: sourceList };
});

managementServer.get('/source/status', async () => {
    return {
        sourceLoaded: sourceModule !== null,
        spiderCount: spiders.length,
    };
});

managementServer.listen({ port: 0, host: '127.0.0.1' }, (err) => {
    if (err) {
        console.log('Management server error:', err);
        return;
    }
    managementPort = managementServer.server.address().port;
    if (nativeServerPort > 0) {
        axios.get(`http://127.0.0.1:${nativeServerPort}/onCatPawOpenPort?port=${managementPort}&type=management`).catch(() => {});
    }
});

process.on('uncaughtException', function (err) {
    console.error('Caught exception:', err);
});
