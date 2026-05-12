import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tvbox_flutter/nodejs/nodejs_service.dart';
import 'package:tvbox_flutter/models/source_config.dart';
import 'package:tvbox_flutter/constants/app_constants.dart';
import 'dart:convert';

class SourceProvider extends ChangeNotifier {
  List<SourceConfig> _sources = [];
  SourceConfig? _currentSource;
  List<Map<String, dynamic>> _sites = [];
  Map<String, dynamic>? _currentSite;
  List<dynamic> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<SourceConfig> get sources => _sources;
  SourceConfig? get currentSource => _currentSource;
  List<Map<String, dynamic>> get sites => _sites;
  Map<String, dynamic>? get currentSite => _currentSite;
  List<dynamic> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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
      try {
        _currentSource = _sources.firstWhere(
          (s) => s.id == currentSourceId,
        );
      } catch (e) {
        if (_sources.isNotEmpty) {
          _currentSource = _sources.first;
        }
      }
    } else if (_sources.isNotEmpty) {
      _currentSource = _sources.first;
    }

    notifyListeners();
  }

  Future<bool> addSource(SourceConfig source) async {
    if (source.name.trim().isEmpty) {
      _errorMessage = 'Source name cannot be empty';
      notifyListeners();
      return false;
    }

    if (source.sourceType == 'remote' && source.url.trim().isEmpty) {
      _errorMessage = 'Source URL cannot be empty';
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      final nodejs = NodeJSService.instance;

      if (source.sourceType == 'remote') {
        String url = source.url.trim();
        if (url.endsWith('.js.md5')) {
          url = url.substring(0, url.length - 4);
        }
        final success = await nodejs.loadSourceFromURL(url);
        if (!success) {
          _errorMessage = nodejs.lastErrorMessage ?? 'Failed to load remote source';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      _sources.add(source);
      await _saveSources();

      _currentSource = source;
      await _saveCurrentSource();

      if (nodejs.hasSpiderServer) {
        await loadHomeContent();
      }
    } catch (e) {
      _errorMessage = 'Failed to add source: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> removeSource(String id) async {
    _sources.removeWhere((s) => s.id == id);
    await _saveSources();

    if (_currentSource?.id == id) {
      if (_sources.isNotEmpty) {
        _currentSource = _sources.first;
        await _saveCurrentSource();
        await loadHomeContent();
      } else {
        _currentSource = null;
        await _saveCurrentSource();
        _sites = [];
        _currentSite = null;
        _categories = [];
        await NodeJSService.instance.deleteSource();
      }
    }

    notifyListeners();
  }

  Future<void> setCurrentSource(SourceConfig source) async {
    _currentSource = source;
    await _saveCurrentSource();

    if (source.sourceType == 'remote') {
      final nodejs = NodeJSService.instance;
      if (!nodejs.hasSpiderServer) {
        _isLoading = true;
        notifyListeners();
        final success = await nodejs.loadSourceFromURL(source.url);
        if (success) {
          await loadHomeContent();
        }
        _isLoading = false;
      } else {
        await loadHomeContent();
      }
    }

    notifyListeners();
  }

  Future<void> setCurrentSite(Map<String, dynamic> site) async {
    _currentSite = site;
    final key =
        (site['key'] as String?)?.replaceFirst('nodejs_', '') ?? '';
    final type = site['type'] as int? ?? 3;
    final api = site['api'] as String? ?? '';
    NodeJSService.instance.setCurrentSpider(key, type, apiBase: api);
    await loadHomeContent();
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

    final nodejs = NodeJSService.instance;
    if (!nodejs.hasSpiderServer) return;

    _isLoading = true;
    notifyListeners();

    try {
      final result = await nodejs.getCatConfig();

      final videoSites =
          result['video']?['sites'] as List<dynamic>? ?? [];

      if (videoSites.isNotEmpty) {
        _sites = videoSites.cast<Map<String, dynamic>>();

        if (_currentSite == null ||
            !_sites.any((s) => s['key'] == _currentSite?['key'])) {
          _currentSite = _sites.first;
        }

        final key =
            (_currentSite!['key'] as String?)?.replaceFirst('nodejs_', '') ?? '';
        final type = _currentSite!['type'] as int? ?? 3;
        final api = _currentSite!['api'] as String? ?? '';
        nodejs.setCurrentSpider(key, type, apiBase: api);
      }

      final homeResult = await nodejs.getHomeContent();
      final classData = homeResult['class'];
      if (classData is List) {
        _categories = classData;
      } else {
        _categories = [];
      }
    } catch (e) {
      print('Failed to load home content: $e');
      _categories = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> activateCurrentSource() async {
    if (_currentSource == null) return;
    final nodejs = NodeJSService.instance;

    if (_currentSource!.sourceType == 'remote' && !nodejs.hasSpiderServer) {
      _isLoading = true;
      notifyListeners();

      final success = await nodejs.loadSourceFromURL(_currentSource!.url);
      if (success) {
        await loadHomeContent();
      }

      _isLoading = false;
      notifyListeners();
    } else if (nodejs.hasSpiderServer) {
      await loadHomeContent();
    }
  }
}
