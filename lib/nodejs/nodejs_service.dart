import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:tvbox_flutter/services/log_service.dart';

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
                log('Node.js message: ${data['message']}');
              }
            } else if (data.containsKey('port') && data.containsKey('type')) {
              final port = data['port'] as int;
              final type = data['type'] as String;
              if (type == 'management') {
                _managementPort = port;
                log('Management port received: $port');
                _managementPortCompleter?.complete();
              } else if (type == 'spider') {
                _spiderPort = port;
                log('Spider port received: $port');
                _spiderPortCompleter?.complete();
              }
            }
          } catch (e) {
            log('Event parse error: $e');
          }
        }
      },
      onError: (error) {
        log('Event channel error: $error');
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
            log('Warning: Node.js ready signal timeout, proceeding anyway');
            _readyCompleter!.complete();
          }
        });

        await _readyCompleter!.future;
        readyTimeout.cancel();

        final mgmtTimeout = Timer(const Duration(seconds: 15), () {
          if (_managementPortCompleter != null && !_managementPortCompleter!.isCompleted) {
            log('Warning: Management port timeout, proceeding anyway');
            _managementPortCompleter!.complete();
          }
        });

        await _managementPortCompleter!.future;
        mgmtTimeout.cancel();
      }
    } catch (e) {
      log('Node.js initialization error: $e');
      _isInitialized = false;
    }
  }

  Future<bool> loadSourceFromURL(String url) async {
    try {
      log('=== loadSourceFromURL called with url: $url ===');
      final result = await _channel.invokeMethod('loadSourceFromURL', {'url': url});
      log('loadSourceFromURL result: $result');
      if (result is Map && result['success'] == true) {
        await waitForSpiderPort();
        return true;
      }
      return false;
    } on PlatformException catch (e) {
      log('PlatformException in loadSourceFromURL: ${e.message}, code: ${e.code}, details: ${e.details}');
      _lastErrorMessage = e.message ?? 'Unknown error';
      return false;
    } catch (e) {
      log('loadSourceFromURL error: $e');
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
        log('Warning: Spider port timeout');
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
      log('deleteSource error: $e');
      return false;
    }
  }

  Future<String?> getSourcePath() async {
    try {
      final result = await _channel.invokeMethod('getSourcePath');
      return result as String?;
    } catch (e) {
      log('getSourcePath error: $e');
      return null;
    }
  }

  Future<void> initSpider() async {
    if (_spiderPort <= 0 || (_spiderApiBase.isEmpty && _currentSpiderKey.isEmpty)) {
      return;
    }
    try {
      final url = '${_spiderBaseUrl()}${_spiderPath()}/init';
      log('[initSpider] POST $url');
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 10));
      log('[initSpider] status=${response.statusCode} body=${response.body}');
    } catch (e) {
      log('[initSpider] error: $e');
    }
  }

  void setCurrentSpider(String key, int type, {String apiBase = ''}) {
    _currentSpiderKey = key;
    _currentSpiderType = type;
    _spiderApiBase = apiBase;
    log('[ setCurrentSpider] 🔧 设置Spider: key=$key, type=$type, apiBase=$apiBase, spiderPath=${_spiderPath()}');
  }

  String get currentSpiderKey => _currentSpiderKey;
  int get currentSpiderType => _currentSpiderType;

  void setWebsiteUrl(String url) {
    _websiteUrl = url;
  }

  String getWebsiteUrl() => _websiteUrl;

  Future<Map<String, dynamic>> getCatConfig() async {
    if (_spiderPort <= 0) {
      log('[getCatConfig] FAIL: spiderPort=$_spiderPort');
      return {};
    }
    try {
      final url = '${_spiderBaseUrl()}/config';
      log('[getCatConfig] GET $url');
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      log('[getCatConfig] status=${response.statusCode} body=${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final videoSites = data['video']?['sites'] as List<dynamic>? ?? [];
        if (videoSites.isNotEmpty) {
          final firstSite = videoSites.first as Map<String, dynamic>;
          final api = firstSite['api'] as String? ?? '';
          log('[getCatConfig] firstSite: key=${firstSite['key']}, name=${firstSite['name']}, api=$api');
          if (api.isNotEmpty) {
            _spiderApiBase = api;
          }
        }
        return data;
      }
    } catch (e) {
      log('[getCatConfig] error: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>> diagnoseSpider() async {
    final result = <String, dynamic>{};
    result['spiderPort'] = _spiderPort;
    result['spiderApiBase'] = _spiderApiBase;
    result['currentSpiderKey'] = _currentSpiderKey;
    result['currentSpiderType'] = _currentSpiderType;

    if (_spiderPort <= 0) {
      result['error'] = 'spiderPort is 0';
      return Map<String, dynamic>.from(result);
    }

    final getPaths = <String>[];
    getPaths.add('/config');
    getPaths.add('/check');
    getPaths.add('/init');
    getPaths.add('/home');
    getPaths.add('/category');
    getPaths.add('/detail');
    getPaths.add('/search');
    getPaths.add('/play');
    getPaths.add('/live');
    getPaths.add('/website/config');
    getPaths.add('/website/home');
    getPaths.add('/website/category');
    if (_spiderApiBase.isNotEmpty) {
      getPaths.add('$_spiderApiBase/home');
      getPaths.add('$_spiderApiBase/category');
      getPaths.add('$_spiderApiBase/detail');
      getPaths.add('$_spiderApiBase/search');
      getPaths.add('$_spiderApiBase/init');
    }
    if (_currentSpiderKey.isNotEmpty) {
      getPaths.add('/$_currentSpiderKey/$_currentSpiderType/home');
      getPaths.add('/$_currentSpiderKey/$_currentSpiderType/category');
    }

    final queryParamPaths = <String>[
      '/?action=home',
      '/?action=config',
      '/?do=home',
      '/?m=home',
      '/api/home',
      '/api/config',
      '/api/v1/home',
      '/api/v1/config',
      '/spider/home',
      '/spider/config',
    ];

    result['=== GET Requests ==='] = null;
    for (final path in getPaths) {
      try {
        final url = 'http://127.0.0.1:$_spiderPort$path';
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        result['GET $path'] = <String, dynamic>{
          'status': response.statusCode,
          'body': response.body.length > 200 ? response.body.substring(0, 200) : response.body,
        };
      } catch (e) {
        result['GET $path'] = <String, dynamic>{'error': e.toString()};
      }
    }

    result['=== Query Parameter Paths ==='] = null;
    for (final path in queryParamPaths) {
      try {
        final url = 'http://127.0.0.1:$_spiderPort$path';
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        result['GET $path'] = <String, dynamic>{
          'status': response.statusCode,
          'body': response.body.length > 200 ? response.body.substring(0, 200) : response.body,
        };
      } catch (e) {
        result['GET $path'] = <String, dynamic>{'error': e.toString()};
      }
    }

    final postTests = <Map<String, dynamic>>[
      {'path': '/home', 'body': <String, dynamic>{}},
      {'path': '/init', 'body': <String, dynamic>{}},
      {'path': '/category', 'body': <String, dynamic>{'id': 'test', 'page': 1}},
      {'path': '/detail', 'body': <String, dynamic>{'id': 'test'}},
      {'path': '/search', 'body': <String, dynamic>{'wd': 'test', 'page': 1}},
      {'path': '/play', 'body': <String, dynamic>{'flag': 'test', 'id': 'test'}},
    ];

    result['=== POST Requests (root) ==='] = null;
    for (final test in postTests) {
      final path = test['path'] as String;
      final body = test['body'] as Map<String, dynamic>;
      try {
        final url = 'http://127.0.0.1:$_spiderPort$path';
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 5));
        result['POST $path'] = <String, dynamic>{
          'status': response.statusCode,
          'body': response.body.length > 200 ? response.body.substring(0, 200) : response.body,
        };
      } catch (e) {
        result['POST $path'] = <String, dynamic>{'error': e.toString()};
      }
    }

    if (_spiderApiBase.isNotEmpty) {
      result['=== POST Requests (with prefix) ==='] = null;
      for (final test in postTests) {
        final path = test['path'] as String;
        final body = test['body'] as Map<String, dynamic>;
        final fullPath = '$_spiderApiBase$path';
        try {
          final url = 'http://127.0.0.1:$_spiderPort$fullPath';
          final response = await http.post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          ).timeout(const Duration(seconds: 5));
          result['POST $fullPath'] = <String, dynamic>{
            'status': response.statusCode,
            'body': response.body.length > 200 ? response.body.substring(0, 200) : response.body,
          };
        } catch (e) {
          result['POST $fullPath'] = <String, dynamic>{'error': e.toString()};
        }
      }
      
      // 测试完整流程：搜索 -> 详情 -> 播放
      result['=== Full Workflow Test ==='] = null;
      try {
        final fullBase = '$_spiderApiBase';
        
        // 1. 初始化
        final initUrl = 'http://127.0.0.1:$_spiderPort$fullBase/init';
        await http.post(
          Uri.parse(initUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({}),
        ).timeout(const Duration(seconds: 5));
        
        // 2. 搜索
        final searchUrl = 'http://127.0.0.1:$_spiderPort$fullBase/search';
        final searchResp = await http.post(
          Uri.parse(searchUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'wd': '电影', 'page': 1}),
        ).timeout(const Duration(seconds: 5));
        result['[Step1] Search'] = {
          'status': searchResp.statusCode,
          'body': searchResp.body.length > 300 ? searchResp.body.substring(0, 300) : searchResp.body,
        };
        
        if (searchResp.statusCode == 200) {
          final searchData = jsonDecode(searchResp.body);
          final list = searchData['list'] as List? ?? [];
          
          if (list.isNotEmpty) {
            final vodId = list[0]['vod_id']?.toString() ?? '';
            result['[Step1a] Got vod_id'] = vodId;
            
            // 3. 获取详情
            final detailUrl = 'http://127.0.0.1:$_spiderPort$fullBase/detail';
            final detailResp = await http.post(
              Uri.parse(detailUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'id': vodId}),
            ).timeout(const Duration(seconds: 5));
            result['[Step2] Detail'] = {
              'status': detailResp.statusCode,
              'body': detailResp.body.length > 500 ? detailResp.body.substring(0, 500) : detailResp.body,
            };
            
            if (detailResp.statusCode == 200) {
              final detailData = jsonDecode(detailResp.body);
              final detailList = detailData['list'] as List? ?? [];
              
              if (detailList.isNotEmpty) {
                final vod = detailList[0];
                final vodPlayFrom = vod['vod_play_from']?.toString() ?? '';
                final vodPlayUrl = vod['vod_play_url']?.toString() ?? '';
                
                result['[Step2a] vod_play_from'] = vodPlayFrom;
                result['[Step2b] vod_play_url'] = vodPlayUrl.length > 200 ? '${vodPlayUrl.substring(0, 200)}...' : vodPlayUrl;
                
                // 4. 获取播放地址
                if (vodPlayFrom.isNotEmpty && vodPlayUrl.isNotEmpty) {
                  final froms = vodPlayFrom.split('\$\$\$');
                  final urls = vodPlayUrl.split('\$\$\$');
                  
                  if (froms.isNotEmpty && urls.isNotEmpty) {
                    final flag = froms[0];
                    final firstSource = urls[0].split('#')[0];
                    final parts = firstSource.split('\$');
                    
                    String? playId;
                    if (parts.length >= 2) {
                      playId = parts[1];
                    } else {
                      playId = firstSource;
                    }
                    
                    result['[Step3] Play Input'] = {'flag': flag, 'id': playId};
                    
                    final playUrl = 'http://127.0.0.1:$_spiderPort$fullBase/play';
                    final playResp = await http.post(
                      Uri.parse(playUrl),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({'flag': flag, 'id': playId}),
                    ).timeout(const Duration(seconds: 5));
                    result['[Step3] Play Response'] = {
                      'status': playResp.statusCode,
                      'body': playResp.body.length > 200 ? playResp.body.substring(0, 200) : playResp.body,
                    };
                  }
                }
              }
            }
          }
        }
      } catch (e, stackTrace) {
        result['Workflow Test Error'] = {'error': e.toString(), 'stack': stackTrace.toString()};
      }
    }

    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> getHomeContent() async {
    if (_spiderPort <= 0 || (_spiderApiBase.isEmpty && _currentSpiderKey.isEmpty)) {
      log('[getHomeContent] FAIL: spiderPort=$_spiderPort, apiBase=$_spiderApiBase, key=$_currentSpiderKey');
      return {};
    }
    try {
      final url = '${_spiderBaseUrl()}${_spiderPath()}/home';
      log('[getHomeContent] POST $url');
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 15));
      log('[getHomeContent] status=${response.statusCode} body=${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      log('[getHomeContent] error: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>> getCategoryContent({
    required String categoryId,
    int page = 1,
    Map<String, dynamic> filters = const {},
  }) async {
    if (_spiderPort <= 0 || (_spiderApiBase.isEmpty && _currentSpiderKey.isEmpty)) {
      log('[ getCategoryContent] ❌ 前置条件不满足: spiderPort=$_spiderPort, apiBase=$_spiderApiBase, key=$_currentSpiderKey');
      return {};
    }
    
    // 重试机制
    for (int retry = 0; retry < 3; retry++) {
      try {
        final url = '${_spiderBaseUrl()}${_spiderPath()}/category';
        log('[ getCategoryContent] 📡 POST $url body={"id":"$categoryId","page":$page, "filters":$filters}${retry > 0 ? ' (重试 $retry)' : ''}');
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': categoryId,
            'page': page,
            'filters': filters,
          }),
        ).timeout(const Duration(seconds: 15));
        log('[ getCategoryContent] 📡 响应: status=${response.statusCode} body=${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
        break;
      } on TimeoutException catch (e) {
        log('[ getCategoryContent] ⏱️ 超时 (尝试 ${retry + 1}/3): $e');
        if (retry < 2) {
          await Future.delayed(Duration(seconds: 1 + retry));
          continue;
        }
        log('[ getCategoryContent] ❌ 重试次数用尽');
      } catch (e) {
        log('[ getCategoryContent] ❌ 错误: $e');
        break;
      }
    }
    return {};
  }

  Future<Map<String, dynamic>> getVideoDetail({required String videoId}) async {
    if (_spiderPort <= 0 || (_spiderApiBase.isEmpty && _currentSpiderKey.isEmpty)) {
      log('[ getVideoDetail] ❌ 前置条件不满足: spiderPort=$_spiderPort, apiBase=$_spiderApiBase, key=$_currentSpiderKey');
      return {};
    }
    try {
      final url = '${_spiderBaseUrl()}${_spiderPath()}/detail';
      log('[ getVideoDetail] 📡 POST $url body={"id":"$videoId"}');
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': videoId}),
      ).timeout(const Duration(seconds: 15));
      log('[ getVideoDetail] 📡 响应: status=${response.statusCode} body=${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      log('[ getVideoDetail] ❌ 错误: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>> getPlayUrl({
    required String videoId,
    required String flag,
    required String playId,
  }) async {
    if (_spiderPort <= 0 || (_spiderApiBase.isEmpty && _currentSpiderKey.isEmpty)) {
      log('[ getPlayUrl] ❌ 前置条件不满足: spiderPort=$_spiderPort, apiBase=$_spiderApiBase, key=$_currentSpiderKey');
      return {};
    }
    try {
      final url = '${_spiderBaseUrl()}${_spiderPath()}/play';
      log('[ getPlayUrl] 🎬 POST $url body={"flag":"$flag","id":"$playId"}');
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'flag': flag,
          'id': playId,
        }),
      ).timeout(const Duration(seconds: 15));
      log('[ getPlayUrl] 🎬 响应: status=${response.statusCode} body=${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      log('[ getPlayUrl] ❌ 错误: $e');
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
    if (_spiderPort <= 0 || (_spiderApiBase.isEmpty && _currentSpiderKey.isEmpty)) {
      log('[ search] ❌ 前置条件不满足: spiderPort=$_spiderPort, apiBase=$_spiderApiBase, key=$_currentSpiderKey');
      return {};
    }
    
    // 重试机制
    for (int retry = 0; retry < 3; retry++) {
      try {
        final url = '${_spiderBaseUrl()}${_spiderPath()}/search';
        log('[ search] 🔍 POST $url body={"wd":"$keyword","page":$page}${retry > 0 ? ' (重试 $retry)' : ''}');
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'wd': keyword,
            'page': page,
          }),
        ).timeout(const Duration(seconds: 15));
        log('[ search] 🔍 响应: status=${response.statusCode} body=${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
        break;
      } on TimeoutException catch (e) {
        log('[ search] ⏱️ 超时 (尝试 ${retry + 1}/3): $e');
        if (retry < 2) {
          await Future.delayed(Duration(seconds: 1 + retry));
          continue;
        }
        log('[ search] ❌ 重试次数用尽');
      } catch (e) {
        log('[ search] ❌ 错误: $e');
        break;
      }
    }
    return {};
  }

  Future<List<Map<String, dynamic>>> getLiveChannels() async {
    if (_spiderPort <= 0 || (_spiderApiBase.isEmpty && _currentSpiderKey.isEmpty)) return [];
    try {
      final url = '${_spiderBaseUrl()}${_spiderPath()}/live';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      log('getLiveChannels error: $e');
    }
    return [];
  }

  Future<String?> getLivePlayUrl(String channelId) async {
    if (_spiderPort <= 0 || (_spiderApiBase.isEmpty && _currentSpiderKey.isEmpty)) return null;
    try {
      final url = '${_spiderBaseUrl()}${_spiderPath()}/live/play';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': channelId}),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['url'] as String?;
      }
    } catch (e) {
      log('getLivePlayUrl error: $e');
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
      log('addCloudDrive error: $e');
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
      log('listCloudDriveFiles error: $e');
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
      log('getCloudDrivePlayUrl error: $e');
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
      log('stopNodeJS error: $e');
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
