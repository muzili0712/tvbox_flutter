import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class NodeJSService extends ChangeNotifier {
  static final NodeJSService instance = NodeJSService._internal();
  static const MethodChannel _channel = MethodChannel('com.tvbox/nodejs');

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Node.js 源服务的端口（Fastify 服务端口）
  int? _sourceServerPort;
  int? get sourceServerPort => _sourceServerPort;

  // Node.js 控制服务的端口（接收来自 Flutter 指令的端口）
  int? _controlServerPort;

  // 本地 HTTP 服务器（用于接收 Node.js 的回调，即 catDartServerPort）
  HttpServer? _localHttpServer;
  int get localServerPort => _localHttpServer?.port ?? 0;

  // 等待 Node.js 源服务端口就绪的 Completer
  Completer<int>? _portCompleter;

  NodeJSService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. 启动本地 HTTP 服务器，用于接收 Node.js 的回调
    await _startLocalHttpServer();

    // 2. 通过 MethodChannel 通知原生端启动 Node.js 运行时
    try {
      _isInitialized = await _channel.invokeMethod('startNodeJS');
      if (!_isInitialized) {
        throw Exception('Node.js failed to start');
      }
      print('✅ Node.js service initialized via native bridge');
    } catch (e) {
      print('❌ Failed to initialize Node.js: $e');
      _isInitialized = false;
      return;
    }

    // 3. 等待 Node.js 源服务端口就绪（通过 /onCatPawOpenPort 回调设置）
    _portCompleter = Completer<int>();
    // 超时处理
    _portCompleter!.future.timeout(const Duration(seconds: 10), onTimeout: () {
      if (!_portCompleter!.isCompleted) {
        _portCompleter!.completeError('Timeout waiting for Node.js source server port');
      }
      return Future.value(-1);
    }).catchError((e) {
      print('⚠️ Port wait error: $e');
      return -1;
    });

    try {
      _sourceServerPort = await _portCompleter!.future;
      if (_sourceServerPort != null && _sourceServerPort! > 0) {
        print('✅ Node.js source server ready on port $_sourceServerPort');
      }
    } catch (e) {
      print('❌ Node.js source server port not received: $e');
    }
    _portCompleter = null;

    notifyListeners();
  }

  /// 启动本地 HTTP 服务器，监听 Node.js 的回调请求
  Future<void> _startLocalHttpServer() async {
    _localHttpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    print('📡 Local HTTP server started on port ${_localHttpServer!.port}');

    _localHttpServer!.listen((HttpRequest request) {
      final path = request.uri.path;
      if (path == '/onCatPawOpenPort') {
        final portStr = request.uri.queryParameters['port'];
        if (portStr != null) {
          final port = int.tryParse(portStr);
          if (port != null) {
            _sourceServerPort = port;
            print('🐱 Received source server port: $port');
            if (_portCompleter != null && !_portCompleter!.isCompleted) {
              _portCompleter!.complete(port);
            }
          }
        }
        request.response.statusCode = 200;
        request.response.write('OK');
        request.response.close();
      } else if (path == '/msg') {
        // 接收来自 Node.js 的主动消息（如事件推送）
        request.listen((List<int> data) {
          final body = utf8.decode(data);
          print('📨 Message from Node.js: $body');
          // 可通过 Notification 或回调传递到 UI 层
        }, onDone: () {
          request.response.statusCode = 200;
          request.response.write('OK');
          request.response.close();
        }, onError: (e) {
          request.response.statusCode = 500;
          request.response.close();
        });
      } else {
        request.response.statusCode = 404;
        request.response.close();
      }
    });
  }

  /// 发送请求到 Node.js 控制服务（或源服务），支持回调
  Future<dynamic> sendRequest(String action, Map<String, dynamic> params) async {
    if (!_isInitialized) {
      throw Exception('Node.js service not initialized');
    }

    // 确保源服务端口已知
    if (_sourceServerPort == null) {
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

  // ========== 以下为业务 API，保持不变 ==========

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

  // ========== CatPawOpen 专用 API ==========

  /// 获取 catpawopen 配置（包含所有可用 Spider）
  Future<Map<String, dynamic>> getCatConfig() async {
    try {
      final result = await sendRequest('getConfig', {});
      return result as Map<String, dynamic>;
    } catch (e) {
      print('❌ getCatConfig failed: $e');
      return {};
    }
  }

  /// 选择默认 Spider
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

  /// 获取 Web 配置界面 URL
  String getWebsiteUrl() {
    if (_sourceServerPort == null || _sourceServerPort! <= 0) return '';
    return 'http://127.0.0.1:$_sourceServerPort/website';
  }

  /// 初始化网盘配置
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

  /// 搜索视频（catpawopen 格式）
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

  /// 获取分类内容（catpawopen 格式）
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

  /// 获取视频详情（catpawopen 格式）
  Future<Map<String, dynamic>> getVideoDetailCatPaw(String videoId) async {
    try {
      final result = await sendRequest('getVideoDetail', {'id': videoId});
      return result as Map<String, dynamic>;
    } catch (e) {
      print('❌ getVideoDetailCatPaw failed: $e');
      return {'list': []};
    }
  }

  /// 获取播放地址（catpawopen 格式）
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
    _localHttpServer?.close();
    _channel.invokeMethod('stopNodeJS');
    super.dispose();
  }
}
