const http = require('http');
const axios = require('axios');

// 从环境变量获取 Flutter 端 HTTP 服务端口
const dartServerPort = process.env.DART_SERVER_PORT || 0;
console.log(`📡 Dart server port from env: ${dartServerPort}`);

let currentSpider = null;

// 全局函数：返回 Flutter 端 HTTP 服务端口
globalThis.catDartServerPort = () => dartServerPort;

// 全局函数：创建 HTTP 服务器工厂（供 Fastify 使用）
globalThis.catServerFactory = (handler) => {
  const server = http.createServer(handler);
  server.listen(0, '127.0.0.1', () => {
    const port = server.address().port;
    console.log(`🐱 CatVod server listening on port ${port}`);
    // 通知 Flutter 端服务端口
    axios.get(`http://127.0.0.1:${dartServerPort}/onCatPawOpenPort?port=${port}`)
      .catch(e => console.error('Failed to notify port:', e.message));
  });
  return server;
};

// 启动 Node.js 控制服务器（接收来自 Flutter 的指令）
const controlServer = http.createServer(async (req, res) => {
  if (req.method === 'POST' && req.url === '/msg') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', async () => {
      try {
        const msg = JSON.parse(body);
        switch (msg.action) {
          case 'run':
            await loadSource(msg.params.path);
            res.writeHead(200, { 'Content-Type': 'text/plain' });
            res.end('OK');
            break;
          case 'nativeServerPort':
            // 备用：若环境变量未传递，可通过此消息设置
            res.writeHead(200, { 'Content-Type': 'text/plain' });
            res.end('OK');
            break;
          default:
            // 转发给源脚本处理
            if (currentSpider && currentSpider.handleMessage) {
              const result = await currentSpider.handleMessage(msg);
              res.writeHead(200, { 'Content-Type': 'application/json' });
              res.end(JSON.stringify(result));
            } else {
              res.writeHead(400, { 'Content-Type': 'text/plain' });
              res.end('Unknown action');
            }
        }
      } catch (e) {
        console.error('Control server error:', e);
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end(e.message);
      }
    });
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
  }
}).listen(0, '127.0.0.1', () => {
  console.log(`🔌 Node control server on port ${controlServer.address().port}`);
  // 注意：此处无法主动通知 Flutter 控制端口，但 Flutter 通过发送 /msg 消息即可通信
});

// 加载源脚本
async function loadSource(scriptPath) {
  try {
    if (currentSpider && currentSpider.stop) {
      await currentSpider.stop();
    }
    delete require.cache[require.resolve(scriptPath)];
    const source = require(scriptPath);
    currentSpider = source;
    if (source.start) {
      await source.start(source.config || {});
    }
    console.log('✅ Source script loaded');
    return true;
  } catch (e) {
    console.error('Failed to load source:', e);
    return false;
  }
}

// 尝试使用原生扩展（若不存在则忽略）
try {
  const addon = process._linkedBinding('myaddon');
  if (addon && addon.registerCallback) {
    addon.registerCallback(async (msg) => {
      console.log('Received from native:', msg);
    });
  }
} catch (e) {
  console.log('myaddon not available, using HTTP bridge exclusively');
}

console.log('Node.js runtime initialized with HTTP bridge');
