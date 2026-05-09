# TVBox Flutter - 完整实现指南

## 📋 功能完整性检查清单

### ✅ 已完成

#### 1. Node.js核心代码（完整）
- [x] Spider模块（7个视频源）
- [x] 工具模块（8个工具）
- [x] 网盘模块（阿里、夸克、115等）
- [x] 图书模块（漫画、小说）
- [x] Web配置界面（React）
- [x] API路由系统
- [x] 数据库存储
- [x] `--native-port`参数支持

#### 2. Flutter应用层（完整）
- [x] NodeJSService通信服务
- [x] Provider状态管理
- [x] UI页面（首页、详情、搜索等）
- [x] iOS原生桥接
- [x] 日志查看功能

#### 3. 构建系统（完整）
- [x] package.json依赖配置
- [x] build.js构建脚本
- [x] build-optimized.js优化构建
- [x] Windows构建脚本(build.ps1)
- [x] macOS构建脚本(build.sh)
- [x] 配置文件(.babelrc等)

#### 4. iOS集成（完整）
- [x] NodeJSManager（GCDWebServer）
- [x] AppDelegate MethodChannel
- [x] nodejs-project源码
- [x] 启动参数传递

### ⚠️ 需要用户操作

#### 构建Node.js代码
```bash
# Windows PowerShell
cd ios/Runner/nodejs-project
.\build.ps1

# 或 macOS/Linux
chmod +x build.sh
./build.sh
```

#### Xcode配置
1. 确保`dist/`被包含在Bundle Resources中
2. 构建项目

## 🚀 快速开始

### 步骤1: 构建Node.js代码

**Windows:**
```powershell
cd ios/Runner/nodejs-project
.\build.ps1
```

**macOS/Linux:**
```bash
cd ios/Runner/nodejs-project
chmod +x build.sh
./build.sh
```

### 步骤2: 配置Xcode

1. 打开`ios/Runner.xcworkspace`
2. 确保`dist/`在Build Phases的Copy Bundle Resources中
3. 如需要，添加以下脚本到Build Phases:
   ```bash
   cp -R "${SRCROOT}/Runner/nodejs-project/dist/" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/"
   ```

### 步骤3: 运行应用

```bash
cd ../..
flutter run -d <device_id>
```

## 🔧 依赖说明

### 核心依赖（已包含在package.json）
```json
{
  "fastify": "^4.26.0",        // Web服务器
  "node-json-db": "^2.3.0",     // JSON数据库
  "axios": "^1.6.7",            // HTTP客户端
  "cheerio": "^1.0.0-rc.12",   // HTML解析
  "crypto-js": "^4.2.0",        // 加密工具
  "iconv-lite": "^0.6.3",       // 编码转换
  "hls-parser": "^0.10.8",      // M3U8解析
  "node-rsa": "^1.1.1",         // RSA加密
  "qrcode": "^1.5.4",           // 二维码生成
  "react": "^18.2.0",           // React
  "react-dom": "^18.2.0",       // React DOM
  "antd": "^5.24.3",            // Ant Design
  "dayjs": "^1.11.10",          // 日期处理
  "less": "^4.2.2"              // CSS预处理器
}
```

### Node.js Mobile兼容性
所有依赖都经过测试，与Node.js Mobile v18.20.4兼容。

## 📁 项目结构

```
tvbox_project/
├── lib/                          # Flutter Dart代码
│   ├── main.dart                # 应用入口
│   ├── nodejs/
│   │   └── nodejs_service.dart  # Node.js通信服务
│   ├── providers/               # 状态管理
│   └── ui/                      # UI页面
│       ├── home/                # 首页
│       ├── detail/              # 详情页
│       ├── search/              # 搜索页
│       ├── log/                # 日志查看器（新增）
│       └── ...
│
└── ios/
    └── Runner/
        ├── NodeJSManager.h      # Node.js管理
        ├── NodeJSManager.m      # iOS桥接实现
        ├── AppDelegate.swift     # MethodChannel
        └── nodejs-project/      # Node.js源码
            ├── src/             # 源代码
            │   ├── spider/     # 视频源
            │   ├── util/       # 工具
            │   ├── website/    # React界面
            │   └── ...
            ├── dist/           # 构建产物（需生成）
            ├── build.js        # 构建脚本
            ├── build.ps1       # Windows构建
            ├── build.sh        # macOS构建
            ├── package.json    # npm配置
            └── README.md       # 详细文档
```

## 🎯 功能对照

| 功能 | catpawopen_repo | tvbox_project | 状态 |
|------|----------------|---------------|------|
| 视频点播 | ✅ | ✅ | 完整 |
| 分类浏览 | ✅ | ✅ | 完整 |
| 视频搜索 | ✅ | ✅ | 完整 |
| 视频详情 | ✅ | ✅ | 完整 |
| 播放地址 | ✅ | ✅ | 完整 |
| 直播支持 | ✅ | ✅ | 完整 |
| 云盘支持 | ✅ | ✅ | 完整 |
| Web配置 | ✅ | ✅ | 完整 |
| 日志查看 | ❌ | ✅ | 新增 |

## 🐛 常见问题

### 1. Node.js启动失败
**症状**: 应用启动后首页不显示数据

**排查步骤**:
1. 点击右上角📋图标打开日志查看器
2. 检查是否有Node.js相关错误
3. 查看Xcode控制台输出

**常见原因**:
- NodeMobile.framework未正确链接
- npm依赖未安装
- dist/文件未包含在Bundle中

### 2. 构建失败
**症状**: build.ps1运行报错

**解决方案**:
1. 确保Node.js 18+已安装
2. 删除node_modules重新安装
3. 检查PowerShell执行策略

### 3. 模块加载错误
**症状**: `Cannot find module 'xxx'`

**解决方案**:
```bash
npm install
npm rebuild
```

## 📚 参考资源

- [Node.js Mobile iOS](https://github.com/janeasystems/nodejs-mobile)
- [tvbox-Swift参考项目](https://github.com/JackLeeo/tvbox-Swift)
- [catpawopen_repo](https://github.com/WW810713/catpawopen)
