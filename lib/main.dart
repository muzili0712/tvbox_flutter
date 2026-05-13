import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/nodejs/nodejs_service.dart';
import 'package:tvbox_flutter/providers/source_provider.dart';
import 'package:tvbox_flutter/providers/player_provider.dart';
import 'package:tvbox_flutter/providers/cloud_drive_provider.dart';
import 'package:tvbox_flutter/providers/history_provider.dart';
import 'package:tvbox_flutter/providers/favorite_provider.dart';
import 'package:tvbox_flutter/ui/home/home_page.dart';
import 'package:tvbox_flutter/services/log_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  LogService.instance;
  log('[main] 🚀 应用启动，LogService已初始化');

  await NodeJSService.instance.initialize();
  log('[main] 🚀 NodeJS已初始化');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SourceProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => CloudDriveProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => FavoriteProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    log('[main] 📱 应用生命周期: $state');
    
    // 当应用从后台恢复时
    if (state == AppLifecycleState.resumed) {
      log('[main] ⚡ 应用从后台恢复，重新初始化服务');
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    try {
      // 重新初始化NodeJS服务
      await NodeJSService.instance.initialize();
      log('[main] ✅ NodeJS服务重新初始化完成');
    } catch (e) {
      log('[main] ❌ 重新初始化失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TVBox',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
