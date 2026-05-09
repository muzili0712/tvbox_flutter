import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/nodejs/nodejs_service.dart';
import 'package:tvbox_flutter/providers/source_provider.dart';
import 'package:tvbox_flutter/providers/player_provider.dart';
import 'package:tvbox_flutter/providers/cloud_drive_provider.dart';
import 'package:tvbox_flutter/providers/history_provider.dart';
import 'package:tvbox_flutter/providers/favorite_provider.dart';
import 'package:tvbox_flutter/ui/home/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀 App starting...');
  
  // 异步初始化 Node.js 服务,不阻塞应用启动
  NodeJSService.instance.initialize().then((_) {
    print('✅ Node.js service initialized successfully');
  }).catchError((e) {
    print('⚠️ Node.js initialization failed, continuing without it: $e');
  });
  
  print('📱 Running app...');
  
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
  
  print('✅ App launched');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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