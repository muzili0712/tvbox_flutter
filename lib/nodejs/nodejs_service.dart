import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class NodeJSService extends ChangeNotifier {
  static final NodeJSService instance = NodeJSService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  int? _managementPort;
  int? _spiderPort;
  int? get managementPort => _managementPort;
  int? get spiderPort => _spiderPort;

  String? _currentSpiderKey;
  int? _currentSpiderType;

  Completer<void>? _managementPortCompleter;
  Completer<void>? _spiderPortCompleter;
  StreamSubscription<dynamic>? _eventSubscription;

  static const MethodChannel _channel = MethodChannel('com.tvbox/nodejs');
  static const EventChannel _eventChannel =
      EventChannel('com.tvbox/nodejs/events');

  NodeJSService._internal();

  void _setupEventListener() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is String) {
          try {
            final data = jsonDecode(event) as Map<String, dynamic>;
            final port = data['port'] as int;
            final type = data['type'] as String;
            _onPortReceived(port, type);
          } catch (e) {
            print('Event parse error: $e');
          }
        } else if (event is int) {
          _onPortReceived(event, 'spider');
        }
      },
      onError: (dynamic error) {
        print('Event channel error: $error');
      },
    );
  }

  void _onPortReceived(int port, String type) {
    if (type == 'management') {
      _managementPort = port;
      if (_managementPortCompleter != null &&
          !_managementPortCompleter!.isCompleted) {
        _managementPortCompleter!.complete();
      }
    } else if (type == 'spider') {
      _spiderPort = port;
      if (_spiderPortCompleter != null && !_spiderPortCompleter!.isCompleted) {
        _spiderPortCompleter!.complete();
      }
    }
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    _setupEventListener();

    try {
      _isInitialized = await _channel.invokeMethod('startNodeJS') ?? false;
      if (!_isInitialized) {
        throw Exception('Node.js failed to start');
      }
    } catch (e) {
      _isInitialized = false;
      return;
    }

    _managementPortCompleter = Completer<void>();
    final mgmtTimeout = Timer(const Duration(seconds: 15), () {
      if (_managementPortCompleter != null &&
          !_managementPortCompleter!.isCompleted) {
        _managementPortCompleter!.complete();
      }
    });
    await _managementPortCompleter!.future;
    mgmtTimeout.cancel();
    _managementPortCompleter = null;

    notifyListeners();
  }

  Future<bool> waitForSpiderPort(
      {Duration timeout = const Duration(seconds: 30)}) async {
    if (_spiderPort != null && _spiderPort! > 0) return true;

    _spiderPortCompleter = Completer<void>();
    final timer = Timer(timeout, () {
      if (_spiderPortCompleter != null &&
          !_spiderPortCompleter!.isCompleted) {
        _spiderPortCompleter!.complete();
      }
    });
    await _spiderPortCompleter!.future;
    timer.cancel();
    _spiderPortCompleter = null;

    return _spiderPort != null && _spiderPort! > 0;
  }

  String get _spiderBaseUrl {
    if (_spiderPort == null || _spiderPort! <= 0) {
      throw Exception('Spider server port unknown');
    }
    return 'http://127.0.0.1:$_spiderPort';
  }

  String get _managementBaseUrl {
    if (_managementPort == null || _managementPort! <= 0) {
      throw Exception('Management server port unknown');
    }
    return 'http://127.0.0.1:$_managementPort';
  }

  Future<Map<String, dynamic>> _post(String baseUrl, String path,
      [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$baseUrl$path');
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

  Future<Map<String, dynamic>> _get(String baseUrl, String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
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
      final result = await _get(_managementBaseUrl, '/check');
      return result['run'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getCatConfig() async {
    try {
      return await _get(_spiderBaseUrl, '/config');
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>> initSpider(String key, int type) async {
    return await _post(_spiderBaseUrl, _spiderPath(key, type) + '/init');
  }

  Future<Map<String, dynamic>> getHomeContent(
      {String? key, int? type}) async {
    final k = key ?? _currentSpiderKey;
    final t = type ?? _currentSpiderType;
    if (k == null || t == null) throw Exception('No spider selected');
    return await _post(_spiderBaseUrl, _spiderPath(k, t) + '/home');
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
    return await _post(_spiderBaseUrl, _spiderPath(k, t) + '/category', {
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
    return await _post(
        _spiderBaseUrl, _spiderPath(k, t) + '/detail', {'id': videoId});
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
    return await _post(
        _spiderBaseUrl, _spiderPath(k, t) + '/play', {'flag': flag, 'id': id});
  }

  Future<Map<String, dynamic>> search({
    required String keyword,
    String? key,
    int? type,
  }) async {
    final k = key ?? _currentSpiderKey;
    final t = type ?? _currentSpiderType;
    if (k == null || t == null) throw Exception('No spider selected');
    return await _post(
        _spiderBaseUrl, _spiderPath(k, t) + '/search', {'wd': keyword});
  }

  Future<String> getPlayUrlSimple(String playId) async {
    final k = _currentSpiderKey;
    final t = _currentSpiderType;
    if (k == null || t == null) throw Exception('No spider selected');
    final result = await _post(
        _spiderBaseUrl, _spiderPath(k, t) + '/play', {'flag': '', 'id': playId});
    return result['url']?.toString() ?? result['parse']?.toString() ?? '';
  }

  Future<String> getCloudDrivePlayUrl(String driveId, String fileId) async {
    final k = _currentSpiderKey;
    final t = _currentSpiderType;
    if (k == null || t == null) throw Exception('No spider selected');
    final result = await _post(
        _spiderBaseUrl, _spiderPath(k, t) + '/play', {'flag': driveId, 'id': fileId});
    return result['url']?.toString() ?? result['parse']?.toString() ?? '';
  }

  Future<String> getLivePlayUrl(String channelId) async {
    final k = _currentSpiderKey;
    final t = _currentSpiderType;
    if (k == null || t == null) throw Exception('No spider selected');
    final result = await _post(
        _spiderBaseUrl, _spiderPath(k, t) + '/play', {'flag': 'live', 'id': channelId});
    return result['url']?.toString() ?? result['parse']?.toString() ?? '';
  }

  Future<void> addCloudDrive(String type, Map<String, dynamic> config) async {
    await _post(_spiderBaseUrl, '/cloud/add', {'type': type, 'config': config});
  }

  Future<List<Map<String, dynamic>>> listCloudDriveFiles(
      String driveId, String path) async {
    final result = await _post(
        _spiderBaseUrl, '/cloud/files', {'driveId': driveId, 'path': path});
    final list = result['files'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getLiveChannels() async {
    try {
      final result = await _get(_spiderBaseUrl, '/live/channels');
      final list = result['channels'] as List<dynamic>? ?? [];
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<bool> loadSourceFromURL(String url) async {
    try {
      final result =
          await _channel.invokeMethod('loadSourceFromURL', {'url': url});
      if (result is Map && result['success'] == true) {
        await waitForSpiderPort();
        return true;
      }
      return false;
    } catch (e) {
      print('loadSourceFromURL error: $e');
      return false;
    }
  }

  Future<bool> deleteSource() async {
    try {
      final result = await _channel.invokeMethod('deleteSource');
      _spiderPort = null;
      notifyListeners();
      return result == true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getSourceStatus() async {
    try {
      return await _get(_managementBaseUrl, '/source/status');
    } catch (e) {
      return {};
    }
  }

  String getWebsiteUrl() {
    if (_spiderPort == null || _spiderPort! <= 0) return '';
    return 'http://127.0.0.1:$_spiderPort/website';
  }

  bool get hasSpiderServer => _spiderPort != null && _spiderPort! > 0;

  @override
  void dispose() {
    _channel.invokeMethod('stopNodeJS');
    _eventSubscription?.cancel();
    super.dispose();
  }
}
