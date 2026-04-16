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

  List<SourceConfig> get sources => _sources;
  SourceConfig? get currentSource => _currentSource;
  List<dynamic> get categories => _categories;
  bool get isLoading => _isLoading;

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
      await NodeJSService.instance.loadSource(_currentSource!.url);
      _categories = await NodeJSService.instance.getHomeContent();
    } catch (e) {
      print('Failed to load home content: $e');
      _categories = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
