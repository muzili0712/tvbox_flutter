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

  Future<dynamic> sendRequest(String action, Map<String, dynamic> params) async {
    if (!_isInitialized) {
      throw Exception('Node.js service not initialized');
    }

    final message = jsonEncode({
      'action': action,
      'params': params,
    });

    return await _channel.invokeMethod('sendMessage', message);
  }

  // 数据源API
  Future<void> loadSource(String url) async {
    return sendRequest('loadSource', {'url': url});
  }

  Future<List<dynamic>> getHomeContent() async {
    return sendRequest('getHomeContent', {});
  }

  Future<List<dynamic>> getCategoryContent(String categoryId, int page) async {
    return sendRequest('getCategoryContent', {
      'categoryId': categoryId,
      'page': page,
    });
  }

  Future<Map<String, dynamic>> getVideoDetail(String videoId) async {
    return sendRequest('getVideoDetail', {'videoId': videoId});
  }

  Future<String> getPlayUrl(String playId) async {
    return sendRequest('getPlayUrl', {'playId': playId});
  }

  Future<List<dynamic>> search(String keyword) async {
    return sendRequest('search', {'keyword': keyword});
  }

  // 网盘API
  Future<void> addCloudDrive(String type, Map<String, dynamic> config) async {
    return sendRequest('addCloudDrive', {
      'type': type,
      'config': config,
    });
  }

  Future<List<dynamic>> listCloudDriveFiles(String driveId, String path) async {
    return sendRequest('listCloudDriveFiles', {
      'driveId': driveId,
      'path': path,
    });
  }

  Future<String> getCloudDrivePlayUrl(String driveId, String fileId) async {
    return sendRequest('getCloudDrivePlayUrl', {
      'driveId': driveId,
      'fileId': fileId,
    });
  }

  // 直播API
  Future<List<dynamic>> getLiveChannels() async {
    return sendRequest('getLiveChannels', {});
  }

  Future<String> getLivePlayUrl(String channelId) async {
    return sendRequest('getLivePlayUrl', {'channelId': channelId});
  }
}
