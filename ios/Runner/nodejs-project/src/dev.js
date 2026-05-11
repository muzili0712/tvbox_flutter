import { createServer } from 'http';

if (typeof globalThis.catServerFactory === 'undefined') {
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
}

if (typeof globalThis.catDartServerPort === 'undefined') {
    globalThis.catDartServerPort = () => 0;
}

import { start } from './index.js';
import * as config from './index.config.js';

start(config.default);
