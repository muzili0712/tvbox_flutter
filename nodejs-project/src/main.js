const fastify = require('fastify');
const router = require('./router.js');
const { JsonDB, Config } = require('node-json-db');
const axios = require('axios');
const website = require('./website/index.js');
const http = require('http');
const path = require('path');

// 从环境变量获取 Flutter 端 HTTP 服务端口
const dartServerPort = process.env.DART_SERVER_PORT || 0;
console.log(`📡 Dart server port from env: ${dartServerPort}`);

let server = null;

// 全局函数：返回 Flutter 端 HTTP 服务端口
globalThis.catDartServerPort = () => dartServerPort;

// 全局函数：创建 HTTP 服务器工厂（供 Fastify 使用）
globalThis.catServerFactory = (handler) => {
  const srv = http.createServer(handler);
  srv.listen(0, '127.0.0.1', () => {
    const port = srv.address().port;
    console.log(`🐱 CatVod server listening on port ${port}`);
    // 通知 Flutter 端服务端口
    if (dartServerPort > 0) {
      axios.get(`http://127.0.0.1:${dartServerPort}/onCatPawOpenPort?port=${port}`)
        .catch(e => console.error('Failed to notify port:', e.message));
    }
  });
  return srv;
};

/**
 * 启动 Fastify 服务（catpawopen 架构）
 */
async function startFastify(config) {
  try {
    server = fastify({
      forceCloseConnections: true,
      logger: false,
      maxParamLength: 10240,
    });

    server.messageToDart = async (data, inReq) => {
      try {
        if (!data.prefix) {
          data.prefix = inReq ? inReq.server.prefix : '';
        }
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

    server.stop = false;
    server.config = config;

    // 数据库路径：优先使用 NODE_PATH 环境变量
    const dbPath = process.env['NODE_PATH'] || path.join(__dirname, '..', 'db.json');
    server.db = new JsonDB(new Config(dbPath, true, true, '/', true));

    // 注册路由
    server.register(router);
    server.register(website, { prefix: '/website' });

    // 监听端口并通知 Flutter
    await server.listen({ port: process.env['DEV_HTTP_PORT'] || 0, host: '127.0.0.1' });
    const address = server.server.address();
    console.log(`✅ Fastify server running on http://127.0.0.1:${address.port}`);

    // 通知 Flutter 端服务端口
    if (dartServerPort > 0) {
      axios.get(`http://127.0.0.1:${dartServerPort}/onCatPawOpenPort?port=${address.port}`)
        .catch(e => console.error('Failed to notify Flutter:', e.message));
    }

    return server;
  } catch (error) {
    console.error('❌ Failed to start Fastify server:', error);
    throw error;
  }
}

/**
 * 停止服务
 */
async function stop() {
  if (server) {
    try {
      await server.close();
      server.stop = true;
    } catch (e) {
      console.error('Error closing server:', e);
    }
  }
  server = null;
}

// 自动启动服务
const config = require('./index.config.js').default || require('./index.config.js');
startFastify(config).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});

// 导出接口供外部调用
module.exports = {
  start: startFastify,
  stop,
};
