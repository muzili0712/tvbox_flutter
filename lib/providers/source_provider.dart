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

  Map<String, dynamic>? _catConfig;

  List<SourceConfig> get sources => _sources;
  SourceConfig? get currentSource => _currentSource;
  List<dynamic> get categories => _categories;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get catConfig => _catConfig;

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
        orElse: () =>
            _sources.isNotEmpty ? _sources.first : SourceConfig.empty(),
      );
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
      await _activateSource(source);
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
    await _activateSource(source);
    notifyListeners();
  }

  Future<void> _activateSource(SourceConfig source) async {
    final nodejs = NodeJSService.instance;

    if (source.sourceType == 'remote') {
      try {
        await nodejs.loadRemoteSource(source.url);
      } catch (e) {
        print('Failed to load remote source: $e');
      }
    } else if (source.sourceType == 'local') {
      try {
        await nodejs.loadLocalSource(source.url);
      } catch (e) {
        print('Failed to load local source: $e');
      }
    }

    if (source.spiderKey != null && source.spiderType != null) {
      nodejs.setCurrentSpider(source.spiderKey!, source.spiderType!);
    }
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
      await _activateSource(_currentSource!);

      final nodejs = NodeJSService.instance;
      final result = await nodejs.getHomeContent();

      if (result is Map<String, dynamic>) {
        final classData = result['class'];
        if (classData is List) {
          _categories = classData;
        } else {
          _categories = [];
        }
      } else if (result is List) {
        _categories = result;
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

  Future<void> loadCatConfig() async {
    try {
      _catConfig = await NodeJSService.instance.getCatConfig();

      if (_catConfig != null && _catConfig!['video'] != null) {
        final videoSites =
            _catConfig!['video']['sites'] as List<dynamic>? ?? [];

        for (final site in videoSites) {
          final key = site['key'] as String?;
          final name = site['name'] as String?;
          final type = site['type'] as int?;

          if (key != null && name != null) {
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
}
