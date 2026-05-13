import 'dart:async';
import 'package:flutter/services.dart';
import 'package:tvbox_flutter/services/log_service.dart';

enum ConnectionType {
  wifi,
  cellular,
  ethernet,
  unknown,
}

class NetworkMonitor {
  static final NetworkMonitor _instance = NetworkMonitor._internal();
  static NetworkMonitor get instance => _instance;
  
  final _connectionChangeController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectionChanged => _connectionChangeController.stream;
  
  final _connectivityChangeController = StreamController<ConnectionType>.broadcast();
  Stream<ConnectionType> get onConnectivityChanged => _connectivityChangeController.stream;
  
  bool _isConnected = true;
  bool get isConnected => _isConnected;
  
  ConnectionType _connectionType = ConnectionType.unknown;
  ConnectionType get connectionType => _connectionType;
  
  bool _wasDisconnected = false;
  bool get wasDisconnected => _wasDisconnected;
  
  Timer? _periodicCheckTimer;
  
  NetworkMonitor._internal();
  
  Future<void> initialize() async {
    log('[NetworkMonitor] 📡 初始化网络监控');
    
    try {
      const channel = MethodChannel('com.tvbox/network');
      final result = await channel.invokeMethod<bool>('isConnected') ?? false;
      _updateConnectionStatus(result);
    } catch (e) {
      log('[NetworkMonitor] ⚠️ 无法获取初始网络状态: $e');
      _isConnected = true;
    }
    
    _startPeriodicCheck();
  }
  
  void _startPeriodicCheck() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _checkConnection();
    });
  }
  
  Future<void> _checkConnection() async {
    try {
      const channel = MethodChannel('com.tvbox/network');
      final result = await channel.invokeMethod<bool>('isConnected') ?? false;
      _updateConnectionStatus(result);
    } catch (e) {
      // 如果检查失败，假设有连接
      if (!_isConnected) {
        _isConnected = true;
        _connectionChangeController.add(true);
      }
    }
  }
  
  void _updateConnectionStatus(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      _connectionChangeController.add(connected);
      
      if (connected) {
        log('[NetworkMonitor] 📶 网络已连接');
      } else {
        log('[NetworkMonitor] 📶 网络已断开');
        _wasDisconnected = true;
      }
    }
  }
  
  void updateConnectionType(ConnectionType type) {
    if (_connectionType != type) {
      _connectionType = type;
      _connectivityChangeController.add(type);
      log('[NetworkMonitor] 📡 连接类型: $type');
    }
  }
  
  Future<void> checkAndNotify() async {
    await _checkConnection();
  }
  
  void dispose() {
    _periodicCheckTimer?.cancel();
    _connectionChangeController.close();
    _connectivityChangeController.close();
  }
}
