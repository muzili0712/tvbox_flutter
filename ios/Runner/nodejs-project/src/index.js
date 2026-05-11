const fastify = require('fastify');
const router = require('./router.js');
const { JsonDB, Config } = require('node-json-db');
const axios = require('axios');

let server = null;

async function start(config) {
    server = fastify({
        serverFactory: globalThis.catServerFactory,
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
            const port = globalThis.catDartServerPort();
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

    await server.listen({ port: process.env['DEV_HTTP_PORT'] || 0, host: '127.0.0.1' });

    const address = server.server.address();
    console.log('🚀 Server listening on ' + address.port);

    const nativePort = globalThis.catDartServerPort();
    if (nativePort > 0) {
        try {
            await axios.get(`http://127.0.0.1:${nativePort}/onCatPawOpenPort?port=${address.port}`);
            console.log('📡 Notified native port: ' + nativePort);
        } catch (error) {
            console.log('⚠️ Failed to notify native port: ' + error.message);
        }
    }
}

async function stop() {
    if (server) {
        server.close();
        server.stop = true;
    }
    server = null;
}

module.exports = {
    start,
    stop,
};
