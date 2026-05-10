import fastify from 'fastify';
import router from './router.js';
import { JsonDB, Config } from 'node-json-db';
import axios from 'axios';

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
        result.url = `http://${result.address}:${result.port}`;
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
    server.listen({ port: process.env['DEV_HTTP_PORT'] || 0, host: '127.0.0.1' });
}

export async function stop() {
    if (server) {
        server.close();
        server.stop = true;
    }
    server = null;
}
