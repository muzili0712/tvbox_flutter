# CatPawOpen 集成完成说明

## 已完成的工作

### 1. Node.js 层重构

#### 已迁移的文件
- ✅ `nodejs-project/src/spider/` - 所有 Spider 模块（video, pan）
- ✅ `nodejs-project/src/util/` - 工具模块（ali.js, quark.js, uc.js, pan.js等）
- ✅ `nodejs-project/src/website/` - Web 配置页面（React + Ant Design）
- ✅ `nodejs-project/src/router.js` - Fastify 路由注册
- ✅ `nodejs-project/src/index.config.js` - 默认配置文件

#### 已修改的文件
- ✅ `nodejs-project/src/main.js` - 重写为 catpawopen 架构，保留 Flutter 桥接
- ✅ `nodejs-project/esbuild.js` - 更新依赖和插件配置
- ✅ `nodejs-project/package.json` - 添加 catpawopen 依赖

### 2. Flutter 层适配

#### 已扩展的文件
- ✅ `lib/nodejs/nodejs_service.dart` - 新增 catpawopen API 方法
  - `getCatConfig()` - 获取配置
  - `setDefaultSpider()` - 设置默认 Spider
  - `getWebsiteUrl()` - 获取 Web 配置界面 URL
  - `initCloudDrive()` - 初始化网盘配置
  - `searchVideos()` - 搜索视频
  - `getCategoryContentCatPaw()` - 获取分类内容
  - `getVideoDetailCatPaw()` - 获取视频详情
  - `getPlayUrlCatPaw()` - 获取播放地址

#### 已修改的文件
- ✅ `lib/models/source_config.dart` - 扩展支持 catpawopen 字段
  - `spiderKey` - Spider 标识
  - `spiderType` - Spider 类型
  - `sourceType` - 数据源类型
- ✅ `lib/models/source_config.g.dart` - 手动创建 JSON 序列化代码
- ✅ `lib/providers/source_provider.dart` - 支持多 Spider 管理
  - `loadCatConfig()` - 加载 catpawopen 配置
  - `setDefaultSpider()` - 设置默认 Spider
  - 自动从配置创建数据源

#### 新增的文件
- ✅ `lib/ui/settings/web_config_page.dart` - Web 配置页面（WebView）
- ✅ `pubspec.yaml` - 添加 `webview_flutter: ^4.4.2` 依赖

#### 已更新的文件
- ✅ `lib/ui/settings/settings_page.dart` - 添加"CatPawOpen 配置"入口

## 构建和运行步骤

### 1. 安装 Node.js 依赖

```bash
cd nodejs-project
npm install
```

### 2. 构建 Node.js 项目

```bash
npm run build
```

这将生成 `dist/main.js` 文件。

### 3. 安装 Flutter 依赖

```bash
flutter pub get
```

### 4. 运行应用

```bash
flutter run
```

## iOS 真机测试注意事项

### 1. 确保 NodeMobile.xcframework 正确配置

检查 `ios/Frameworks/NodeMobile.xcframework` 是否存在且包含以下架构：
- `ios-arm64` (真机)
- `ios-arm64_x86_64-simulator` (模拟器)

### 2. 文件权限

iOS Sandbox 限制文件写入路径。确保 `db.json` 存储在合法路径：

在 `AppDelegate.swift` 中设置环境变量：
```swift
let docsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
setenv("NODE_PATH", docsPath, 1)
```

### 3. WebView 配置

在 `Info.plist` 中添加 ATS 例外（如果需要访问外部 API）：
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## 功能验证清单

### 基础功能
- [ ] 应用启动后 Node.js 服务正常初始化
- [ ] 首页能加载视频分类列表
- [ ] 点击分类能显示视频列表
- [ ] 点击视频能显示详情和剧集列表
- [ ] 点击剧集能正常播放视频

### CatPawOpen 特定功能
- [ ] 能通过 Web 配置界面访问 `/website`
- [ ] 能扫码登录阿里云盘
- [ ] 能扫码登录夸克网盘
- [ ] 能扫码登录 UC 网盘
- [ ] 网盘分享链接能解析并播放
- [ ] 配置重启后持久化生效（db.json）

### 网盘功能
- [ ] 阿里云盘原画播放
- [ ] 阿里云盘转码播放（超清/高清/标清）
- [ ] 夸克网盘播放
- [ ] UC 网盘播放
- [ ] Alist 聚合网盘浏览

## 故障排查

### 问题 1: Node.js 服务启动失败

**症状**: 应用启动后提示"Node.js failed to start"

**可能原因**:
- NodeMobile.xcframework 不兼容
- main.js 语法错误
- 依赖缺失

**解决方案**:
1. 检查 Xcode Console 日志
2. 验证 `dist/main.js` 是否正确生成
3. 尝试在桌面 Node.js 环境运行 `node dist/main.js`

### 问题 2: Web 配置页面无法加载

**症状**: WebView 显示空白或错误

**可能原因**:
- Node.js 服务端口未正确获取
- GCDWebServer 未正确处理 `/website/*` 路径

**解决方案**:
1. 检查 `NodeJSService.instance.getWebsiteUrl()` 返回值
2. 验证 GCDWebServer 路由配置
3. 检查 Safari 开发者工具中的 WebView 控制台

### 问题 3: db.json 文件写入失败

**症状**: 配置保存后重启丢失

**可能原因**:
- iOS Sandbox 权限限制
- 文件路径不正确

**解决方案**:
1. 使用 `NSSearchPathForDirectoriesInDomains` 获取 Documents 目录
2. 通过 `NODE_PATH` 环境变量传递路径
3. 检查文件权限

## 后续优化建议

1. **性能优化**
   - 按需加载 Spider 模块（动态 require）
   - 启用 esbuild 的代码分割
   - 压缩图片和静态资源

2. **用户体验**
   - 添加加载动画和进度提示
   - 优化错误处理和用户反馈
   - 支持深色模式

3. **功能增强**
   - 支持更多 Spider 模块（漫画、小说、音乐）
   - 添加下载管理
   - 支持字幕选择

4. **兼容性**
   - 适配 Android 平台
   - 支持 iPad 横竖屏
   - 适配不同屏幕尺寸

## 技术架构说明

### 通信流程

```
Flutter App
    |
    | MethodChannel ('com.tvbox/nodejs')
    |
    v
iOS Native (NodeJSBridge + GCDWebServer)
    |
    | node_start() + HTTP Bridge
    |
    v
Node.js Runtime (NodeMobile.xcframework)
    |
    | Fastify Server
    |
    v
Spider Modules (catpawopen)
    |
    | HTTP Requests
    |
    v
External APIs (视频源、网盘等)
```

### 关键端口

1. **Flutter Local Server Port**: 动态分配，接收 Node.js 回调
2. **Node.js Fastify Port**: 动态分配，提供 Spider API 和 Web 配置界面
3. **GCDWebServer Port**: 动态分配，iOS 端嵌入式 HTTP 服务器

### 数据持久化

- **Flutter 层**: SharedPreferences（数据源列表、当前选择）
- **Node.js 层**: node-json-db（db.json，网盘配置、Spider 状态）

## 联系和支持

如有问题，请参考：
- CatPawOpen 官方文档: https://github.com/WW810713/catpawopen
- TVBox Flutter 项目: https://github.com/JackLeeo/tvbox_flutter
