import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class NodeJSService {
  static const MethodChannel _channel = MethodChannel('com.tvbox/nodejs');
  static const EventChannel _eventChannel = EventChannel('com.tvbox/nodejs/events');

  static final NodeJSService _instance = NodeJSService._internal();
  factory NodeJSService() => _instance;
  NodeJSService._internal();

  static NodeJSService get instance => _instance;

  bool _isInitialized = false;
  bool _isNodeReady = false;
  int _managementPort = 0;
  int _spiderPort = 0;
  int _nativeServerPort = 0;
  String _currentSpiderKey = '';
  int _currentSpiderType = 3;
  String _spiderApiBase = '';
  String _websiteUrl = '';
  Completer<void>? _readyCompleter;
  Completer<void>? _managementPortCompleter;
  Completer<void>? _spiderPortCompleter;
  StreamSubscription? _eventSubscription;

  bool get isInitialized => _isInitialized;
  bool get isNodeReady => _isNodeReady;
  int get managementPort => _managementPort;
  int get spiderPort => _spiderPort;
  bool get hasSpiderServer => _spiderPort > 0;

  String _spiderBaseUrl() => 'http://127.0.0.1:$_spiderPort';
  String _spiderPath() {
    if (_spiderApiBase.isNotEmpty) return _spiderApiBase;
    return '/$_currentSpiderKey/$_currentSpiderType';
  }

  void _setupEventListener() {
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is String) {
          try {
            final data = jsonDecode(event) as Map<String, dynamic>;
            if (data.containsKey('event')) {
              final eventType = data['event'] as String;
              if (eventType == 'ready') {
                _isNodeReady = true;
                _readyCompleter?.complete();
              } else if (eventType == 'message') {
                print('Node.js message: ${data['message']}');
              }
            } else if (data.containsKey('port') && data.containsKey('type')) {
              final port = data['port'] as int;
              final type = data['type'] as String;
              if (type == 'management') {
                _managementPort = port;
                print('Management port received: $port');
                _managementPortCompleter?.complete();
              } else if (type == 'spider') {
                _spiderPort = port;
                print('Spider port received: $port');
                _spiderPortCompleter?.complete();
              }
            }
          } catch (e) {
            print('Event parse error: $e');
          }
        }
      },
      onError: (error) {
        print('Event channel error: $error');
      },
    );
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    _setupEventListener();

    try {
      _readyCompleter = Completer<void>();
      _managementPortCompleter = Completer<void>();

      final result = await _channel.invokeMethod('startNodeJS');
      _isInitialized = result == true;

      if (_isInitialized) {
        final readyTimeout = Timer(const Duration(seconds: 15), () {
          if (_readyCompleter != null && !_readyCompleter!.isCompleted) {
            print('Warning: Node.js ready signal timeout, proceeding anyway');
            _readyCompleter!.complete();
          }
        });

        await _readyCompleter!.future;
        readyTimeout.cancel();

        final mgmtTimeout = Timer(const Duration(seconds: 15), () {
          if (_managementPortCompleter != null && !_managementPortCompleter!.isCompleted) {
            print('Warning: Management port timeout, proceeding anyway');
            _managementPortCompleter!.complete();
          }
        });

        await _managementPortCompleter!.future;
        mgmtTimeout.cancel();
      }
    } catch (e) {
      print('Node.js initialization error: $e');
      _isInitialized = false;
    }
  }

  Future<bool> loadSourceFromURL(String url) async {
    try {
      print('=== loadSourceFromURL called with url: $url ===');
      final result = await _channel.invokeMethod('loadSourceFromURL', {'url': url});
      print('loadSourceFromURL result: $result');
      if (result is Map && result['success'] == true) {
        await waitForSpiderPort();
        return true;
      }
      return false;
    } on PlatformException catch (e) {
      print('PlatformException in loadSourceFromURL: ${e.message}, code: ${e.code}, details: ${e.details}');
      _lastErrorMessage = e.message ?? 'Unknown error';
      return false;
    } catch (e) {
      print('loadSourceFromURL error: $e');
      _lastErrorMessage = e.toString();
      return false;
    }
  }
  
  String? _lastErrorMessage;
  
  String? get lastErrorMessage => _lastErrorMessage;

  Future<void> waitForSpiderPort({Duration timeout = const Duration(seconds: 30)}) async {
    if (_spiderPort > 0) return;

    _spiderPortCompleter = Completer<void>();
    final timer = Timer(timeout, () {
      if (_spiderPortCompleter != null && !_spiderPortCompleter!.isCompleted) {
        print('Warning: Spider port timeout');
        _spiderPortCompleter!.complete();
      }
    });

    await _spiderPortCompleter!.future;
    timer.cancel();
  }

  Future<bool> deleteSource() async {
    try {
      final result = await _channel.invokeMethod('deleteSource');
      _spiderPort = 0;
      _spiderApiBase = '';
      return result == true;
    } catch (e) {
      print('deleteSource error: $e');
      return false;
    }
  }

  Future<String?> getSourcePath() async {
    try {
      final result = await _channel.invokeMethod('getSourcePath');
      return result as String?;
    } catch (e) {
      print('getSourcePath error: $e');
      return null;
    }
  }

  void setCurrentSpider(String key, int type, {String apiBase = ''}) {
    _currentSpiderKey = key;
    _currentSpiderType = type;
    _spiderApiBase = apiBase;
  }

  String get currentSpiderKey => _currentSpiderKey;
  int get currentSpiderType => _currentSpiderType;

  void setWebsiteUrl(String url) {
    _websiteUrl = url;
  }

  String getWebsiteUrl() => _websiteUrl;

  Future<Map<String, dynamic>> getCatConfig() async {
    if (_spiderPort <= 0) return {};
    try {
      final response = await http
          .get(Uri.parse('${_spiderBaseUrl()}/config'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final videoSites = data['video']?['sites'] as List<dynamic>? ?? [];
        if (videoSites.isNotEmpty) {
          final firstSite = videoSites.first as Map<String, dynamic>;
          final api = firstSite['api'] as String? ?? '';
          if (api.isNotEmpty) {
            _spiderApiBase = api;
          }
        }
        return data;
      }
    } catch (e) {
      print('getCatConfig error: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>> getHomeContent() async {
    if (_spiderPort <= 0 || _currentSpiderKey.isEmpty) return {};
    try {
      final url = '${_spiderBaseUrl()}${_spiderPath()}/home';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('getHomeContent error: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>> getCategoryContent({
    required String categoryId,
    int page = 1,
  }) async {
    if (_spiderPort <= 0 || _currentSpiderKey.isEmpty) return {};
    try {
      final url = '${_spiderBaseUrl()}${_spiderPath()}/category?t=${DateTime.now().millisecondsSinceEpoch}&cateId=$categoryId&page=$page';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('getCategoryContent error: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>> getVideoDetail({required String videoId}) async {
    if (_spiderPort <= 0 || _currentSpiderKey.isEmpty) return {};
    try {
      final url = '${_spiderBaseUrl()}${_spiderPath()}/detail?id=$videoId';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('getVideoDetail error: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>> getPlayUrl({
    required String videoId,
    required String flag,
    required String playId,
  }) async {
    if (_spiderPort <= 0 || _currentSpiderKey.isEmpty) return {};
    try {
      final url = '${_spiderBaseUrl()}${_spiderPath()}/play?flag=$flag&id=$videoId&playId=${Uri.encodeComponent(playId)}';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('getPlayUrl error: $e');
    }
    return {};
  }

  Future<String?> getPlayUrlSimple(String playId) async {
    final result = await getPlayUrl(
      videoId: '',
      flag: '',
      playId: playId,
    );
    return result['url'] as String?;
  }

  Future<Map<String, dynamic>> search({required String keyword, int page = 1}) async {
    if (_spiderPort <= 0 || _currentSpiderKey.isEmpty) return {};
    try {
      final url = '${_spiderBaseUrl()}${_spiderPath()}/search?wd=${Uri.encodeComponent(keyword)}&page=$page';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('search error: $e');
    }
    return {};
  }

  Future<List<Map<String, dynamic>>> getLiveChannels() async {
    if (_spiderPort <= 0 || _currentSpiderKey.isEmpty) return [];
    try {
      final url = '${_spiderBaseUrl()}${_spiderPath()}/live';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      print('getLiveChannels error: $e');
    }
    return [];
  }

  Future<String?> getLivePlayUrl(String channelId) async {
    if (_spiderPort <= 0 || _currentSpiderKey.isEmpty) return null;
    try {
      final url = '${_spiderBaseUrl()}${_spiderPath()}/live/play?id=${Uri.encodeComponent(channelId)}';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['url'] as String?;
      }
    } catch (e) {
      print('getLivePlayUrl error: $e');
    }
    return null;
  }

  Future<bool> addCloudDrive(String type, Map<String, dynamic> config) async {
    if (_spiderPort <= 0) return false;
    try {
      final url = '${_spiderBaseUrl()}/cloud/add';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'type': type, 'config': config}),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      print('addCloudDrive error: $e');
    }
    return false;
  }

  Future<String> listCloudDriveFiles(String driveId, String path) async {
    if (_spiderPort <= 0) return '[]';
    try {
      final url = '${_spiderBaseUrl()}/cloud/files?driveId=$driveId&path=${Uri.encodeComponent(path)}';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      print('listCloudDriveFiles error: $e');
    }
    return '[]';
  }

  Future<String?> getCloudDrivePlayUrl(String driveId, String fileId) async {
    if (_spiderPort <= 0) return null;
    try {
      final url = '${_spiderBaseUrl()}/cloud/play?driveId=$driveId&fileId=${Uri.encodeComponent(fileId)}';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['url'] as String?;
      }
    } catch (e) {
      print('getCloudDrivePlayUrl error: $e');
    }
    return null;
  }

  Future<int> getNativeServerPort() async {
    try {
      final result = await _channel.invokeMethod('getNativeServerPort');
      return result as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getManagementPort() async {
    try {
      final result = await _channel.invokeMethod('getManagementPort');
      return result as int? ?? 0;
    } catch (e) {
      return _managementPort;
    }
  }

  Future<int> getSpiderPort() async {
    try {
      final result = await _channel.invokeMethod('getSpiderPort');
      return result as int? ?? 0;
    } catch (e) {
      return _spiderPort;
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopNodeJS');
    } catch (e) {
      print('stopNodeJS error: $e');
    }
    _isInitialized = false;
    _isNodeReady = false;
    _managementPort = 0;
    _spiderPort = 0;
    _nativeServerPort = 0;
    _spiderApiBase = '';
    _eventSubscription?.cancel();
  }
}
