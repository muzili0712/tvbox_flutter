import { createServer } from 'http';

globalThis.catServerFactory = (handle) => {
    let port = 0;
    const server = createServer((req, res) => {
        handle(req, res);
    });
    server.on('listening', () => {
        port = server.address().port;
        console.log('Run on ' + port);
    });
    server.on('close', () => {
        console.log('Close on ' + port);
    });
    return server;
};

// 处理命令行参数，获取 native-port
let nativePort = 0;
const args = process.argv;
for (let i = 0; i < args.length; i++) {
    if (args[i] === '--native-port' && i + 1 < args.length) {
        nativePort = parseInt(args[i + 1], 10);
        break;
    }
}

globalThis.catDartServerPort = () => {
    return nativePort;
};

if (nativePort > 0) {
    console.log('📡 Native port configured: ' + nativePort);
}

// website bundle 会在构建时由 build.js 嵌入
if (typeof globalThis.websiteBundle === 'string') {
    try {
        eval(globalThis.websiteBundle);
    } catch (e) {
        console.log('Website bundle not available (this is normal for production)');
    }
}

import { start } from './index.js';

import * as config from './index.config.js';

start(config.default);
