import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class NodeJSService extends ChangeNotifier {
  static final NodeJSService instance = NodeJSService._internal();
  static const MethodChannel _channel = MethodChannel('com.tvbox/nodejs');
  static const EventChannel _eventChannel = EventChannel('com.tvbox/nodejs/events');

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  int? _sourceServerPort;
  int? get sourceServerPort => _sourceServerPort;

  int? _nativeServerPort;
  int? get nativeServerPort => _nativeServerPort;

  Completer<int>? _portCompleter;
  StreamSubscription<dynamic>? _eventSubscription;

  NodeJSService._internal();

  void _setupEventListener() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is int) {
          onNodePortReceived(event);
        }
      },
      onError: (dynamic error) {
        print('❌ Event channel error: $error');
      },
    );
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    print('🚀 Starting Node.js initialization...');

    _setupEventListener();

    try {
      _nativeServerPort = await _channel.invokeMethod('getNativeServerPort');
      print('📡 Native server port: $_nativeServerPort');
      
      _isInitialized = await _channel.invokeMethod('startNodeJS');
      
      if (!_isInitialized) {
        throw Exception('Node.js failed to start');
      }
      print('✅ Node.js process started successfully');
    } catch (e) {
      print('❌ Failed to initialize Node.js: $e');
      _isInitialized = false;
      return;
    }

    _portCompleter = Completer<int>();
    
    final timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (_portCompleter != null && !_portCompleter!.isCompleted) {
        print('⚠️ Timeout waiting for Node.js source server port');
        _portCompleter!.complete(-1);
      }
    });
    
    try {
      _sourceServerPort = await _portCompleter!.future;
      timeoutTimer.cancel();
      
      if (_sourceServerPort != null && _sourceServerPort! > 0) {
        print('✅ Node.js source server ready on port $_sourceServerPort');
      } else {
        print('⚠️ Node.js source server port not received');
      }
    } catch (e) {
      print('❌ Node.js source server port error: $e');
      timeoutTimer.cancel();
    }
    _portCompleter = null;

    notifyListeners();
  }

  void onNodePortReceived(int port) {
    print('📡 Received Node.js port from iOS: $port');
    _sourceServerPort = port;
    if (_portCompleter != null && !_portCompleter!.isCompleted) {
      _portCompleter!.complete(port);
    }
  }

  Future<dynamic> sendRequest(String action, Map<String, dynamic> params) async {
    if (!_isInitialized) {
      throw Exception('Node.js service not initialized');
    }

    if (_sourceServerPort == null || _sourceServerPort! <= 0) {
      throw Exception('Node.js source server port unknown');
    }

    final message = jsonEncode({
      'action': action,
      'params': params,
    });

    try {
      final client = HttpClient();
      final request = await client.post('127.0.0.1', _sourceServerPort!, '/msg');
      request.headers.contentType = ContentType.json;
      request.write(message);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('HTTP error ${response.statusCode}');
      }
      final responseBody = await response.transform(utf8.decoder).join();
      if (responseBody.isNotEmpty) {
        return jsonDecode(responseBody);
      }
      return null;
    } catch (e) {
      print('❌ sendRequest failed: $e');
      rethrow;
    }
  }

  Future<void> loadSource(String url) async {
    await sendRequest('loadSource', {'url': url});
  }

  Future<dynamic> getHomeContent() async {
    final result = await sendRequest('getHomeContent', {});
    return result;
  }

  Future<List<dynamic>> getCategoryContent(String categoryId, int page) async {
    final result = await sendRequest('getCategoryContent', {
      'categoryId': categoryId,
      'page': page,
    });
    return result as List<dynamic>;
  }

  Future<Map<String, dynamic>> getVideoDetail(String videoId) async {
    final result = await sendRequest('getVideoDetail', {'videoId': videoId});
    return result as Map<String, dynamic>;
  }

  Future<String> getPlayUrl(String playId) async {
    final result = await sendRequest('getPlayUrl', {'playId': playId});
    return result as String;
  }

  Future<List<dynamic>> search(String keyword) async {
    final result = await sendRequest('search', {'keyword': keyword});
    return result as List<dynamic>;
  }

  Future<void> addCloudDrive(String type, Map<String, dynamic> config) async {
    await sendRequest('addCloudDrive', {
      'type': type,
      'config': config,
    });
  }

  Future<List<dynamic>> listCloudDriveFiles(String driveId, String path) async {
    final result = await sendRequest('listCloudDriveFiles', {
      'driveId': driveId,
      'path': path,
    });
    return result as List<dynamic>;
  }

  Future<String> getCloudDrivePlayUrl(String driveId, String fileId) async {
    final result = await sendRequest('getCloudDrivePlayUrl', {
      'driveId': driveId,
      'fileId': fileId,
    });
    return result as String;
  }

  Future<List<dynamic>> getLiveChannels() async {
    final result = await sendRequest('getLiveChannels', {});
    return result as List<dynamic>;
  }

  Future<String> getLivePlayUrl(String channelId) async {
    final result = await sendRequest('getLivePlayUrl', {'channelId': channelId});
    return result as String;
  }

  Future<Map<String, dynamic>> getCatConfig() async {
    try {
      final result = await sendRequest('getConfig', {});
      return result as Map<String, dynamic>;
    } catch (e) {
      print('❌ getCatConfig failed: $e');
      return {};
    }
  }

  Future<void> setDefaultSpider(String spiderKey, int spiderType) async {
    try {
      await sendRequest('setDefaultSpider', {
        'key': spiderKey,
        'type': spiderType,
      });
    } catch (e) {
      print('❌ setDefaultSpider failed: $e');
      rethrow;
    }
  }

  String getWebsiteUrl() {
    if (_sourceServerPort == null || _sourceServerPort! <= 0) return '';
    return 'http://127.0.0.1:$_sourceServerPort/website';
  }

  Future<void> initCloudDrive(String type, Map<String, dynamic> config) async {
    try {
      await sendRequest('initCloudDrive', {
        'type': type,
        'config': config,
      });
    } catch (e) {
      print('❌ initCloudDrive failed: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> searchVideos(String keyword, {int page = 1}) async {
    try {
      final result = await sendRequest('search', {
        'wd': keyword,
        'page': page,
      });
      return result as Map<String, dynamic>;
    } catch (e) {
      print('❌ searchVideos failed: $e');
      return {'list': []};
    }
  }

  Future<Map<String, dynamic>> getCategoryContentCatPaw(
    String categoryId, 
    int page, 
    [Map<String, dynamic>? filters]
  ) async {
    try {
      final result = await sendRequest('getCategoryContent', {
        'id': categoryId,
        'page': page,
        'filters': filters ?? {},
      });
      return result as Map<String, dynamic>;
    } catch (e) {
      print('❌ getCategoryContentCatPaw failed: $e');
      return {'list': [], 'page': page, 'pagecount': 0, 'total': 0};
    }
  }

  Future<Map<String, dynamic>> getVideoDetailCatPaw(String videoId) async {
    try {
      final result = await sendRequest('getVideoDetail', {'id': videoId});
      return result as Map<String, dynamic>;
    } catch (e) {
      print('❌ getVideoDetailCatPaw failed: $e');
      return {'list': []};
    }
  }

  Future<Map<String, dynamic>> getPlayUrlCatPaw(String flag, String playId) async {
    try {
      final result = await sendRequest('getPlayUrl', {
        'flag': flag,
        'id': playId,
      });
      return result as Map<String, dynamic>;
    } catch (e) {
      print('❌ getPlayUrlCatPaw failed: $e');
      return {'parse': 0, 'url': ''};
    }
  }

  @override
  void dispose() {
    _channel.invokeMethod('stopNodeJS');
    _eventSubscription?.cancel();
    super.dispose();
  }
}
