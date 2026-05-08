import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tvbox_flutter/nodejs/nodejs_service.dart';
import 'package:tvbox_flutter/models/source_config.dart';
import 'package:tvbox_flutter/constants/app_constants.dart';
import 'dart:convert';

class SourceProvider extends ChangeNotifier {
  List<SourceConfig> _sources = [];
  SourceConfig? _currentSource;
  List<dynamic> _categories = [];
  bool _isLoading = false;
  
  // CatPawOpen 相关状态
  Map<String, dynamic>? _catConfig;  // 存储 catpawopen 配置
  String? _defaultSpiderKey;         // 默认 Spider key
  int? _defaultSpiderType;           // 默认 Spider type

  List<SourceConfig> get sources => _sources;
  SourceConfig? get currentSource => _currentSource;
  List<dynamic> get categories => _categories;
  bool get isLoading => _isLoading;
  
  Map<String, dynamic>? get catConfig => _catConfig;
  String? get defaultSpiderKey => _defaultSpiderKey;
  int? get defaultSpiderType => _defaultSpiderType;

  SourceProvider() {
    _loadSources();
  }

  Future<void> _loadSources() async {
    final prefs = await SharedPreferences.getInstance();
    final sourcesJson = prefs.getStringList(AppConstants.keySources) ?? [];
    
    _sources = sourcesJson
        .map((json) => SourceConfig.fromJson(jsonDecode(json)))
        .toList();
    
    final currentSourceId = prefs.getString(AppConstants.keyCurrentSource);
    if (currentSourceId != null) {
      _currentSource = _sources.firstWhere(
        (s) => s.id == currentSourceId,
        orElse: () => _sources.isNotEmpty ? _sources.first : SourceConfig.empty(),
      );
      // 如果返回的是 empty 占位，且实际来源列表不为空，则取第一个
      if (_currentSource!.id.isEmpty && _sources.isNotEmpty) {
        _currentSource = _sources.first;
      }
    } else if (_sources.isNotEmpty) {
      _currentSource = _sources.first;
    }
    
    notifyListeners();
  }

  Future<void> addSource(SourceConfig source) async {
    _sources.add(source);
    await _saveSources();
    
    if (_currentSource == null) {
      _currentSource = source;
      await _saveCurrentSource();
    }
    
    notifyListeners();
  }

  Future<void> removeSource(String id) async {
    _sources.removeWhere((s) => s.id == id);
    await _saveSources();
    
    if (_currentSource?.id == id) {
      _currentSource = _sources.isNotEmpty ? _sources.first : null;
      await _saveCurrentSource();
    }
    
    notifyListeners();
  }

  Future<void> setCurrentSource(SourceConfig source) async {
    _currentSource = source;
    await _saveCurrentSource();
    await loadHomeContent();
    notifyListeners();
  }

  Future<void> _saveSources() async {
    final prefs = await SharedPreferences.getInstance();
    final sourcesJson = _sources.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(AppConstants.keySources, sourcesJson);
  }

  Future<void> _saveCurrentSource() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentSource != null) {
      await prefs.setString(AppConstants.keyCurrentSource, _currentSource!.id);
    } else {
      await prefs.remove(AppConstants.keyCurrentSource);
    }
  }

  Future<void> loadHomeContent() async {
    if (_currentSource == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // CatPawOpen 数据源处理
      if (_currentSource!.sourceType == 'catpawopen' || _currentSource!.spiderKey != null) {
        // 设置默认 Spider
        final spiderKey = _currentSource!.spiderKey ?? 'baseset';
        final spiderType = _currentSource!.spiderType ?? 3;
        
        await NodeJSService.instance.setDefaultSpider(spiderKey, spiderType);
        
        // 获取首页内容（catpawopen 格式返回的是 Map，需要提取 list）
        final result = await NodeJSService.instance.getHomeContent();
        
        // catpawopen 的 home 接口返回格式: { class: [...], filters: {...} }
        if (result is Map<String, dynamic>) {
          final classData = result['class'];
          _categories = classData is List ? classData : [];
        } else if (result is List) {
          _categories = result;
        } else {
          _categories = [];
        }
      } else {
        // 兼容旧版 Spider
        await NodeJSService.instance.loadSource(_currentSource!.url);
        _categories = await NodeJSService.instance.getHomeContent();
      }
    } catch (e) {
      print('Failed to load home content: $e');
      _categories = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// 加载 CatPawOpen 配置
  Future<void> loadCatConfig() async {
    try {
      _catConfig = await NodeJSService.instance.getCatConfig();
      
      // 如果有视频站点，自动添加为数据源
      if (_catConfig != null && _catConfig!['video'] != null) {
        final videoSites = _catConfig!['video']['sites'] as List<dynamic>? ?? [];
        
        for (final site in videoSites) {
          final key = site['key'] as String?;
          final name = site['name'] as String?;
          final type = site['type'] as int?;
          
          if (key != null && name != null) {
            // 检查是否已存在
            final exists = _sources.any((s) => s.spiderKey == key);
            if (!exists) {
              final source = SourceConfig.catPawOpen(
                id: 'catpaw_$key',
                name: name,
                spiderKey: key,
                spiderType: type ?? 3,
              );
              _sources.add(source);
            }
          }
        }
        
        await _saveSources();
      }
      
      notifyListeners();
    } catch (e) {
      print('Failed to load cat config: $e');
    }
  }
  
  /// 设置默认 Spider
  void setDefaultSpider(String key, int type) {
    _defaultSpiderKey = key;
    _defaultSpiderType = type;
    notifyListeners();
  }
}
