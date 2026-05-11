import { createServer } from 'http';
import fastify from 'fastify';
import router from './router.js';
import { JsonDB, Config } from 'node-json-db';
import axios from 'axios';
import {getIPAddress} from "./util/network.js";

if (typeof globalThis.catServerFactory === 'undefined') {
    let _nativeServerPort = 0;
    const nativePortIdx = process.argv.indexOf('--native-port');
    if (nativePortIdx !== -1 && process.argv[nativePortIdx + 1]) {
        _nativeServerPort = parseInt(process.argv[nativePortIdx + 1], 10);
    }

    globalThis.catServerFactory = (handle) => {
        const server = createServer((req, res) => {
            handle(req, res);
        });
        server.on('listening', () => {
            const port = server.address().port;
            if (_nativeServerPort > 0) {
                axios.get(`http://127.0.0.1:${_nativeServerPort}/onCatPawOpenPort?port=${port}`).catch(() => {});
            }
            console.log('Server running on port ' + port);
        });
        return server;
    };

    globalThis.catDartServerPort = () => _nativeServerPort;
}

let server = null;

export async function start(config) {
    server = fastify({
        serverFactory: catServerFactory,
        forceCloseConnections: true,
        logger: !!(process.env.NODE_ENV !== 'development'),
        maxParamLength: 10240,
    });
    server.messageToDart = async (data, inReq) => {
        try {
            if (!data.prefix) {
                data.prefix = inReq ? inReq.server.prefix : '';
            }
            console.log(data);
            const port = catDartServerPort();
            if (port == 0) {
                return null;
            }
            const resp = await axios.post(`http://127.0.0.1:${port}/msg`, data);
            return resp.data;
        } catch (error) {
            return null;
        }
    };
    server.address = function () {
        const result = this.server.address();
        result.url = `http://${getIPAddress()}:${result.port}`;
        result.dynamic = 'js2p://_WEB_';
        return result;
    };
    server.addHook('onError', async (_request, _reply, error) => {
        console.error(error);
        if (!error.statusCode) error.statusCode = 500;
        return error;
    });
    server.stop = false;
    server.config = config;
    server.db = new JsonDB(new Config((process.env['NODE_PATH'] || '.') + '/db.json', true, true, '/', true));
    server.register(router);
    server.listen({ port: process.env['DEV_HTTP_PORT'] || 0, host: '0.0.0.0' });
}

export async function stop() {
    if (server) {
        server.close();
        server.stop = true;
    }
    server = null;
}
