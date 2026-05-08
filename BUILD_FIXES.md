# 编译错误修复说明

## 已修复的错误

### 1. source_provider.dart 类型错误
- ✅ 修复了第 123 行的类型转换问题
- 原来：`_categories = result['class'] as List<dynamic>? ?? [];`
- 修改为：先检查类型再赋值

### 2. nodejs_service.dart 错误
- ✅ 修复了 catchError 必须返回值的问题
- ✅ 添加了 dispose() 方法中的 super.dispose() 调用

## 需要运行的命令

以下错误需要通过运行 `flutter pub get` 来解决：

### webview_flutter 相关错误
```
lib/ui/settings/web_config_page.dart:
- uri_does_not_exist: package:webview_flutter/webview_flutter.dart
- undefined_class: WebViewController, HttpResponseError, WebResourceError
- undefined_method: WebViewController(), NavigationDelegate(), WebViewWidget()
- undefined_identifier: JavaScriptMode
```

**解决方法**：
```bash
cd tvbox_project
flutter pub get
```

### print 警告（可选修复）
代码中使用了 `print()` 语句，这在生产代码中不推荐，但不影响运行。如果想消除警告，可以：

1. 忽略这些警告（在 analysis_options.yaml 中配置）
2. 使用 logging 包替代 print

## 完整构建步骤

1. **安装 Node.js**（如果尚未安装）
   - 访问 https://nodejs.org/
   - 下载并安装 LTS 版本

2. **构建 Node.js 项目**
   ```bash
   cd nodejs-project
   npm install
   npm run build
   ```

3. **安装 Flutter 依赖**
   ```bash
   cd ..
   flutter pub get
   ```

4. **运行应用**
   ```bash
   flutter run
   ```

## iOS 真机测试额外配置

如果需要在一台 iOS 设备上测试，还需要：

### 1. 设置 NODE_PATH 环境变量

编辑 `ios/Runner/AppDelegate.swift`，在 `application` 方法开头添加：

```swift
override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    // 设置 Node.js 数据库路径
    let docsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    setenv("NODE_PATH", docsPath, 1)
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}
```

### 2. 配置 ATS（如果需要访问外部 API）

编辑 `ios/Runner/Info.plist`，添加：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## 验证构建

构建成功后，验证以下功能：

1. ✅ 应用能正常启动
2. ✅ 控制台显示 "Node.js service initialized"
3. ✅ 首页能加载分类列表
4. ✅ 设置 → CatPawOpen 配置 能打开
5. ✅ Web 配置页面正常显示

## 常见问题

### Q: flutter pub get 失败
**A**: 检查网络连接，或使用国内镜像：
```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
flutter pub get
```

### Q: npm install 失败
**A**: 尝试清除缓存后重试：
```bash
npm cache clean --force
npm install
```

### Q: 构建成功但运行时报错
**A**: 查看控制台日志，常见原因：
- Node.js 服务启动失败
- 端口冲突
- 文件权限问题

---

最后更新：2026-05-08
