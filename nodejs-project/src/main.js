const http = require('http');
const axios = require('axios');

let dartServerPort = 0;
let currentSpider = null;

// 提供给源脚本的全局函数
globalThis.catDartServerPort = () => dartServerPort;

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

// 源脚本加载逻辑（需根据实际路径调整）
async function loadSource(scriptPath) {
  if (currentSpider?.stop) await currentSpider.stop();
  delete require.cache[require.resolve(scriptPath)];
  const source = require(scriptPath);
  currentSpider = source;
  await source.start(source.config || {});
  return true;
}

// 启动内嵌 HTTP 服务接收来自 Flutter 的指令
const server = http.createServer(async (req, res) => {
  if (req.method === 'POST' && req.url === '/msg') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', async () => {
      try {
        const msg = JSON.parse(body);
        switch (msg.action) {
          case 'run':
            await loadSource(msg.params.path);
            res.writeHead(200);
            res.end('OK');
            break;
          case 'nativeServerPort':
            dartServerPort = msg.params.port;
            console.log(`📡 Dart server port set to ${dartServerPort}`);
            res.writeHead(200);
            res.end('OK');
            break;
          default:
            res.writeHead(400);
            res.end('Unknown action');
        }
      } catch (e) {
        res.writeHead(500);
        res.end(e.message);
      }
    });
  } else {
    res.writeHead(404);
    res.end();
  }
}).listen(0, '127.0.0.1', () => {
  console.log(`🔌 Node control server on port ${server.address().port}`);
  // 注意：现在无法主动通知 Flutter，需要 Flutter 轮询或通过 node_start 参数传递
});

// 原生通信适配（若 myaddon 不存在，则忽略）
try {
  const addon = process._linkedBinding('myaddon');
  if (addon) {
    addon.registerCallback(async (msg) => {
      // 备用通道
    });
  }
} catch (e) {
  console.warn('myaddon not available, using HTTP bridge');
}
