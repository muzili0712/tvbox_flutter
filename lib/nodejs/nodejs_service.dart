import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class NodeJSService extends ChangeNotifier {
  static final NodeJSService instance = NodeJSService._internal();
  static const MethodChannel _channel = MethodChannel('com.tvbox/nodejs');
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  NodeJSService._internal();
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _isInitialized = await _channel.invokeMethod('startNodeJS');
      notifyListeners();
      print('Node.js service initialized: $_isInitialized');
    } catch (e) {
      print('Failed to initialize Node.js: $e');
      _isInitialized = false;
    }
  }
  
  // 原项目的run动作：加载本地Spider脚本
  Future<void> runScript(String path) async {
    if (!_isInitialized) {
      throw Exception('Node.js service not initialized');
    }
    await _channel.invokeMethod('runScript', path);
  }
  
  // 原项目的nativeServerPort
  Future<void> setNativeServerPort(int port) async {
    if (!_isInitialized) return;
    await _channel.invokeMethod('setNativeServerPort', port);
  }
}
