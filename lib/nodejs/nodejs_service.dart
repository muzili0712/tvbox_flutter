import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class NodeJSService extends ChangeNotifier {
  static final NodeJSService instance = NodeJSService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  int? _sourceServerPort;
  int? get sourceServerPort => _sourceServerPort;

  String? _currentSpiderKey;
  int? _currentSpiderType;

  Completer<int>? _portCompleter;
  StreamSubscription<dynamic>? _eventSubscription;

  static const MethodChannel _channel = MethodChannel('com.tvbox/nodejs');
  static const EventChannel _eventChannel =
      EventChannel('com.tvbox/nodejs/events');

  NodeJSService._internal();

  void _setupEventListener() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is int) {
          onNodePortReceived(event);
        }
      },
      onError: (dynamic error) {
        print('Event channel error: $error');
      },
    );
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    _setupEventListener();

    try {
      final nativePort = await _channel.invokeMethod('getNativeServerPort');

      _isInitialized = await _channel.invokeMethod('startNodeJS');

      if (!_isInitialized) {
        throw Exception('Node.js failed to start');
      }
    } catch (e) {
      _isInitialized = false;
      return;
    }

    _portCompleter = Completer<int>();

    final timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (_portCompleter != null && !_portCompleter!.isCompleted) {
        _portCompleter!.complete(-1);
      }
    });

    try {
      _sourceServerPort = await _portCompleter!.future;
      timeoutTimer.cancel();
    } catch (e) {
      timeoutTimer.cancel();
    }
    _portCompleter = null;

    notifyListeners();
  }

  void onNodePortReceived(int port) {
    _sourceServerPort = port;
    if (_portCompleter != null && !_portCompleter!.isCompleted) {
      _portCompleter!.complete(port);
    }
  }

  String get _baseUrl {
    if (_sourceServerPort == null || _sourceServerPort! <= 0) {
      throw Exception('Node.js source server port unknown');
    }
    return 'http://127.0.0.1:$_sourceServerPort';
  }

  Future<Map<String, dynamic>> _post(String path,
      [Map<String, dynamic>? body]) async {
    if (!_isInitialized) throw Exception('Node.js service not initialized');

    final uri = Uri.parse('$_baseUrl$path');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('HTTP error ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }

  Future<Map<String, dynamic>> _get(String path) async {
    if (!_isInitialized) throw Exception('Node.js service not initialized');

    final uri = Uri.parse('$_baseUrl$path');
    final response =
        await http.get(uri).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('HTTP error ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }

  String _spiderPath(String key, int type) => '/spider/$key/$type';

  void setCurrentSpider(String key, int type) {
    _currentSpiderKey = key;
    _currentSpiderType = type;
  }

  Future<bool> checkHealth() async {
    try {
      final result = await _get('/check');
      return result['run'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getCatConfig() async {
    try {
      return await _get('/config');
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>> initSpider(String key, int type) async {
    return await _post(_spiderPath(key, type) + '/init');
  }

  Future<Map<String, dynamic>> getHomeContent(
      {String? key, int? type}) async {
    final k = key ?? _currentSpiderKey;
    final t = type ?? _currentSpiderType;
    if (k == null || t == null) throw Exception('No spider selected');
    return await _post(_spiderPath(k, t) + '/home');
  }

  Future<Map<String, dynamic>> getCategoryContent({
    required String categoryId,
    int page = 1,
    Map<String, dynamic>? filters,
    String? key,
    int? type,
  }) async {
    final k = key ?? _currentSpiderKey;
    final t = type ?? _currentSpiderType;
    if (k == null || t == null) throw Exception('No spider selected');
    return await _post(_spiderPath(k, t) + '/category', {
      'id': categoryId,
      'page': page,
      'filters': filters ?? {},
    });
  }

  Future<Map<String, dynamic>> getVideoDetail({
    required String videoId,
    String? key,
    int? type,
  }) async {
    final k = key ?? _currentSpiderKey;
    final t = type ?? _currentSpiderType;
    if (k == null || t == null) throw Exception('No spider selected');
    return await _post(_spiderPath(k, t) + '/detail', {'id': videoId});
  }

  Future<Map<String, dynamic>> getPlayUrl({
    required String flag,
    required String id,
    String? key,
    int? type,
  }) async {
    final k = key ?? _currentSpiderKey;
    final t = type ?? _currentSpiderType;
    if (k == null || t == null) throw Exception('No spider selected');
    return await _post(_spiderPath(k, t) + '/play', {'flag': flag, 'id': id});
  }

  Future<Map<String, dynamic>> search({
    required String keyword,
    String? key,
    int? type,
  }) async {
    final k = key ?? _currentSpiderKey;
    final t = type ?? _currentSpiderType;
    if (k == null || t == null) throw Exception('No spider selected');
    return await _post(_spiderPath(k, t) + '/search', {'wd': keyword});
  }

  Future<Map<String, dynamic>> loadRemoteSource(String url) async {
    return await _post('/source/load', {'url': url});
  }

  Future<Map<String, dynamic>> loadLocalSource(String path) async {
    return await _post('/source/loadPath', {'path': path});
  }

  Future<List<dynamic>> listSources() async {
    final result = await _get('/source/list');
    return result['sources'] as List<dynamic>? ?? [];
  }

  String getWebsiteUrl() {
    if (_sourceServerPort == null || _sourceServerPort! <= 0) return '';
    return 'http://127.0.0.1:$_sourceServerPort/website';
  }

  @override
  void dispose() {
    _channel.invokeMethod('stopNodeJS');
    _eventSubscription?.cancel();
    super.dispose();
  }
}
