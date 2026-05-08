# CatPawOpen 集成 - 当前状态

## ✅ 已完成的工作

### 1. Node.js 层
- ✅ 复制所有 Spider 模块（duoduo, baseset, ffm3u8, kkys, alist等）
- ✅ 复制工具模块（ali.js, quark.js, uc.js, pan.js等）
- ✅ 复制 Web 配置页面（React + Ant Design）
- ✅ 重写 main.js 采用 Fastify 架构
- ✅ 更新 package.json 添加依赖
- ✅ 更新 esbuild.js 构建配置

### 2. Flutter 层
- ✅ 扩展 NodeJSService 添加 catpawopen API
- ✅ 修改 SourceConfig 模型支持多 Spider
- ✅ 创建 source_config.g.dart
- ✅ 修改 SourceProvider 支持猫爪源管理
- ✅ 创建 WebConfigPage（WebView 配置界面）
- ✅ 更新 SettingsPage 添加入口
- ✅ 添加 webview_flutter 依赖

### 3. JSON 序列化文件
- ✅ source_config.g.dart
- ✅ video_item.g.dart
- ✅ video_detail.g.dart
- ✅ cloud_drive.g.dart
- ✅ live_channel.g.dart

## ⚠️ 需要手动操作的步骤

### 1. 安装 Node.js
当前环境未安装 Node.js，需要：
1. 访问 https://nodejs.org/
2. 下载并安装 LTS 版本
3. 重启终端

### 2. 构建 Node.js 项目
```bash
cd nodejs-project
npm install
npm run build
```

### 3. 安装 Flutter 依赖
```bash
flutter pub get
```

### 4. iOS 配置（如需真机测试）

#### 设置 NODE_PATH 环境变量
在 `ios/Runner/AppDelegate.swift` 的 `application` 方法中添加：
```swift
let docsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
setenv("NODE_PATH", docsPath, 1)
```

#### 配置 ATS（如果需要访问外部 API）
在 `ios/Runner/Info.plist` 中添加：
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## 📋 验证清单

构建完成后，请验证以下功能：

### 基础功能
- [ ] 应用能正常启动
- [ ] Node.js 服务初始化成功（查看控制台日志）
- [ ] 首页能加载分类列表

### CatPawOpen 功能
- [ ] 设置 → CatPawOpen 配置 能打开 WebView
- [ ] Web 配置页面正常显示
- [ ] 能扫码登录阿里云盘
- [ ] 网盘配置保存后重启不丢失

### 播放功能
- [ ] 视频能正常播放
- [ ] 网盘分享链接能解析
- [ ] 多清晰度切换正常

## 🔧 故障排查

### 如果看到 "Node.js failed to start"
1. 检查是否已运行 `npm install` 和 `npm run build`
2. 确认 `nodejs-project/dist/main.js` 文件存在
3. 查看 Xcode Console 或 Android Logcat 的错误日志

### 如果 Web 配置页面空白
1. 检查 `NodeJSService.instance.getWebsiteUrl()` 是否返回有效 URL
2. 确认 Node.js 服务端口已正确获取
3. 查看 WebView 控制台错误信息

### 如果 JSON 序列化错误
运行以下命令重新生成：
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 📝 技术说明

### 架构变化
- **之前**：自定义 Spider 脚本（handleMessage 方式）
- **现在**：Fastify HTTP 服务器 + catpawopen 标准路由

### 通信流程
```
Flutter 
  ↓ MethodChannel
iOS Native (NodeMobile)
  ↓ node_start()
Node.js Runtime
  ↓ Fastify Server
Spider Modules
  ↓ HTTP Requests
External APIs
```

### 关键端口
- Flutter Local Server: 动态分配，接收 Node.js 回调
- Node.js Fastify: 动态分配，提供 Spider API
- GCDWebServer (iOS): 动态分配，嵌入式 HTTP 服务器

## 📚 参考文档
- 详细集成说明：`CATPAWOPEN_INTEGRATION.md`
- CatPawOpen 官方：https://github.com/WW810713/catpawopen
- TVBox Flutter：https://github.com/JackLeeo/tvbox_flutter

---

最后更新：2026-05-08
