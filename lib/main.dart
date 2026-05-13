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
