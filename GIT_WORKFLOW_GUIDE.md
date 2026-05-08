# Git 推送和 GitHub Actions 工作流指南

## 已完成的工作流配置

您的项目已经配置了完整的 CI/CD 工作流（`.github/workflows/build_trollstore.yml`），它会自动：

1. ✅ 设置 Flutter 3.41.6 环境
2. ✅ 设置 Node.js 18 环境
3. ✅ 下载并配置 NodeMobile.xcframework
4. ✅ 构建 Node.js 项目（npm install && npm run build）
5. ✅ 安装 Flutter 依赖（flutter pub get）
6. ✅ 生成 JSON 序列化代码（build_runner）
7. ✅ 构建 iOS TrollStore IPA
8. ✅ 上传构建产物到 GitHub Artifacts

## 已更新的内容

### 1. AppDelegate.swift
添加了 NODE_PATH 环境变量设置，确保 db.json 存储在正确的路径：

```swift
// 设置 Node.js 数据库路径为 Documents 目录
let docsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
setenv("NODE_PATH", docsPath, 1)
```

### 2. 工作流文件
更新了 build_runner 步骤，允许有警告的情况下继续构建。

## 推送到 GitHub 的步骤

### 第一步：初始化 Git 仓库（如果尚未初始化）

```bash
cd tvbox_project
git init
```

### 第二步：添加所有更改

```bash
git add .
```

### 第三步：提交更改

```bash
git commit -m "feat: 集成 CatPawOpen 支持

- 迁移 catpawopen Spider 模块和工具类
- 重写 Node.js 层采用 Fastify 架构
- 扩展 Flutter 层支持多 Spider 管理
- 添加 Web 配置界面（WebView）
- 更新 iOS AppDelegate 设置 NODE_PATH
- 添加 webview_flutter 依赖
- 创建所有必需的 .g.dart 文件"
```

### 第四步：添加远程仓库

```bash
# 替换为您的 GitHub 仓库地址
git remote add origin https://github.com/JackLeeo/tvbox_flutter.git
```

### 第五步：推送到 GitHub

```bash
# 推送到 main 分支
git push -u origin main

# 或者如果您想创建新分支
git checkout -b catpawopen-integration
git push -u origin catpawopen-integration
```

## GitHub Actions 自动构建

推送后，GitHub Actions 会自动触发构建流程：

### 查看构建状态

1. 访问您的 GitHub 仓库
2. 点击 "Actions" 标签
3. 查看最新的工作流运行状态

### 构建成功

如果构建成功，您可以：
1. 在 Actions 页面找到 "tvbox-Flutter-TrollStore"  artifact
2. 下载 IPA 文件
3. 使用 TrollStore 安装到 iOS 设备

### 构建失败

如果构建失败：
1. 点击失败的工作流
2. 查看详细日志
3. 根据错误信息修复问题
4. 重新提交并推送

## 常见问题

### Q1: Git 推送时提示认证失败
**解决方案**：
```bash
# 使用 Personal Access Token
git remote set-url origin https://YOUR_TOKEN@github.com/JackLeeo/tvbox_flutter.git

# 或使用 SSH
git remote set-url origin git@github.com:JackLeeo/tvbox_flutter.git
```

### Q2: GitHub Actions 构建失败 - Node.js 依赖问题
**解决方案**：检查 `nodejs-project/package.json` 是否包含所有必需的依赖

### Q3: GitHub Actions 构建失败 - Flutter 依赖问题
**解决方案**：确保 `pubspec.yaml` 格式正确，所有依赖版本兼容

### Q4: 构建成功但 IPA 无法安装
**可能原因**：
- TrollStore 版本不兼容
- IPA 签名问题
- 设备不支持

## 手动触发构建

如果需要手动触发构建，可以：

### 方法 1：创建空提交
```bash
git commit --allow-empty -m "ci: trigger rebuild"
git push
```

### 方法 2：使用 GitHub CLI
```bash
gh workflow run build_trollstore.yml
```

### 方法 3：在 GitHub 网页上
1. 进入 Actions 标签
2. 选择 "Build TrollStore TVBox" 工作流
3. 点击 "Run workflow" 按钮

## 优化建议

### 1. 缓存优化
工作流已经启用了 Flutter 缓存，可以考虑添加 Node.js 缓存：

```yaml
- name: Cache Node.js modules
  uses: actions/cache@v3
  with:
    path: nodejs-project/node_modules
    key: ${{ runner.os }}-node-${{ hashFiles('nodejs-project/package-lock.json') }}
```

### 2. 条件构建
只在特定文件变化时触发构建：

```yaml
on:
  push:
    branches: [ main ]
    paths:
      - 'lib/**'
      - 'nodejs-project/**'
      - 'ios/**'
      - 'pubspec.yaml'
```

### 3. 添加 Android 构建
如果需要同时构建 Android APK，可以添加新的 job。

## 版本发布

要创建正式版本：

### 1. 更新版本号
编辑 `pubspec.yaml`：
```yaml
version: 1.5.0+2  # major.minor.patch+build_number
```

### 2. 创建 Git Tag
```bash
git tag v1.5.0
git push origin v1.5.0
```

### 3. 创建 GitHub Release
1. 进入仓库的 Releases 页面
2. 点击 "Create a new release"
3. 选择对应的 tag
4. 上传构建的 IPA 文件
5. 编写发布说明

## 监控和维护

### 定期检查
- 每周检查一次依赖更新
- 每月更新 Flutter 和 Node.js 版本
- 及时修复安全漏洞

### 依赖更新
```bash
# 更新 Flutter 依赖
flutter pub upgrade

# 更新 Node.js 依赖
cd nodejs-project
npm update

# 检查过期依赖
npm outdated
```

---

最后更新：2026-05-08
