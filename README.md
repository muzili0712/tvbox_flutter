# TVBox Flutter

基于 Flutter + Node.js 的跨平台影视应用，通过嵌入式 Node.js 运行时驱动 TVBox Spider 源，实现 iOS/Android 双端支持。

## 功能特性

### 影视浏览
- 多源线路管理，支持远程/本地配置源
- 一级分类 + 多级筛选器（类型/地区/年份/排序等）
- 分类内容无限滚动加载
- 影视详情页，多播放源切换

### 搜索
- 全线路聚合搜索
- 搜索结果按线路分组展示

### 播放
- VLC 播放器（支持 m3u8/mp4/rtmp 等格式）
- 系统播放器备选
- HLS 多清晰度自动解析
- 弹幕叠加层

### 直播
- 虎牙/斗鱼/B站直播频道
- 频道分类与 EPG 支持

### 云盘
- 夸克/百度/115/天翼/123云盘集成
- 云盘文件浏览与播放
- Cookie 配置管理

### 其他
- 播放历史记录
- 收藏管理
- 应用内日志查看
- Web 配置页面
- TrollStore IPA 构建

## 技术架构

```
┌─────────────────────────────────────┐
│           Flutter UI Layer          │
│  (Provider 状态管理 + Material Design) │
├─────────────────────────────────────┤
│         NodeJS Service Layer        │
│  (HTTP Bridge → Spider Server)      │
├─────────────────────────────────────┤
│      NodeMobile Runtime (iOS)       │
│      nodejs-project (Spider源)      │
└─────────────────────────────────────┘
```

- **Flutter 前端**：Provider 状态管理，Material Design UI
- **Node.js 后端**：嵌入式 NodeMobile 运行时，启动 Spider HTTP 服务器
- **Spider API**：标准 TVBox Spider 协议（init/home/category/detail/play/search）
- **iOS 桥接**：GCDWebServer + NodeJSManager（Objective-C）

## 项目结构

```
lib/
├── constants/          # 常量定义
├── models/             # 数据模型（JSON序列化）
├── nodejs/             # Node.js 服务层
│   └── nodejs_service.dart
├── providers/          # Provider 状态管理
│   ├── source_provider.dart    # 源/线路/分类
│   ├── player_provider.dart    # 播放器
│   ├── live_provider.dart      # 直播
│   ├── cloud_drive_provider.dart
│   ├── favorite_provider.dart
│   └── history_provider.dart
├── services/           # 服务层
│   ├── log_service.dart
│   ├── hls_parser.dart
│   └── network_monitor.dart
├── ui/                 # UI 页面
│   ├── home/           # 首页（分类+筛选器+视频列表）
│   ├── search/         # 搜索页
│   ├── detail/         # 详情页
│   ├── player/         # 播放器（VLC/系统播放器/弹幕）
│   ├── live/           # 直播页
│   ├── cloud_drive/    # 云盘页
│   ├── favorite/       # 收藏页
│   ├── history/        # 历史页
│   ├── settings/       # 设置页
│   └── widgets/        # 通用组件
└── utils/              # 工具类

ios/Runner/
├── NodeJSManager.m     # Node.js 进程管理
├── NodeJSBridge.swift  # Swift 桥接
└── nodejs-project/     # Spider 源项目
    ├── src/            # 源码
    ├── dist/           # 构建产物
    └── package.json

diagnose.js             # V4 诊断脚本（多级分类深度诊断）
```

## 开发环境

- Flutter >= 3.41.6
- Dart >= 3.4.0
- Xcode >= 15.0 (iOS)
- Node.js 18 (iOS 运行时)

## 构建

### iOS

```bash
flutter build ios --release
```

### Android

```bash
flutter build apk --release
```

### TrollStore IPA

项目包含 GitHub Actions 工作流 (`.github/workflows/build_trollstore.yml`)，可自动构建 TrollStore 兼容的 IPA。

## 诊断工具

`diagnose.js` 是独立的 Node.js 诊断脚本，用于测试所有源线路的运行状态：

```bash
node diagnose.js [源地址] [搜索关键词]
```

功能：
- 5 级深度诊断：Init → Home → Category → Detail → Play
- 多级分类内容测试
- 筛选器结构分析
- 搜索功能测试
- 问题站点汇总
- JSON 报告输出

## 关键依赖

| 包 | 用途 |
|---|---|
| flutter_vlc_player | VLC 视频播放 |
| provider | 状态管理 |
| webview_flutter | Web 配置页面 |
| cached_network_image | 图片缓存 |
| shared_preferences | 本地存储 |
| permission_handler | 权限管理 |

## License

MIT
