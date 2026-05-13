import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tvbox_flutter/services/log_service.dart';

class HLSQualityOption {
  final String url;
  final String name;
  final int? height;
  final int? bandwidth;

  HLSQualityOption({
    required this.url,
    required this.name,
    this.height,
    this.bandwidth,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HLSQualityOption &&
          runtimeType == other.runtimeType &&
          url == other.url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() {
    return '$name (${height ?? 'unknown'}p, ${_formatBandwidth(bandwidth)})';
  }

  String _formatBandwidth(int? bw) {
    if (bw == null) return 'unknown';
    if (bw >= 1000000) {
      return '${(bw / 1000000).toStringAsFixed(1)}Mbps';
    }
    return '${(bw / 1000).toStringAsFixed(0)}Kbps';
  }
}

class HLSParser {
  static bool looksLikeHLSURL(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.endsWith('.m3u8') ||
        lowerUrl.contains('.m3u8?') ||
        lowerUrl.contains('/m3u8/');
  }

  static Future<List<HLSQualityOption>> resolveQualityOptions(
      String episodeUrl) async {
    log('[HLS解析器] 🔍 开始解析: $episodeUrl');
    
    if (!looksLikeHLSURL(episodeUrl)) {
      log('[HLS解析器] ⚠️ 不是HLS URL，跳过解析');
      return [];
    }

    try {
      final response = await http.get(Uri.parse(episodeUrl)).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode != 200) {
        log('[HLS解析器] ❌ HTTP请求失败: ${response.statusCode}');
        return [];
      }

      final playlist = response.body;
      final options = parseMasterPlaylist(playlist, episodeUrl);

      log('[HLS解析器] ✅ 解析完成，找到${options.length}个清晰度选项');
      for (final option in options) {
        log('[HLS解析器]   - $option');
      }

      return options;
    } catch (e) {
      log('[HLS解析器] ❌ 解析失败: $e');
      return [];
    }
  }

  static List<HLSQualityOption> parseMasterPlaylist(String content, String masterUrl) {
    final lines = LineSplitter.split(content).toList();
    final variants = <HLSQualityOption>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        final attributes = _parseAttributes(line.substring('#EXT-X-STREAM-INF:'.length));
        
        if (i + 1 < lines.length) {
          final uri = lines[i + 1].trim();
          if (uri.isNotEmpty && !uri.startsWith('#')) {
            final resolvedUrl = _resolveUrl(masterUrl, uri);
            final name = attributes['NAME'] ?? _generateName(attributes);
            final height = _parseHeight(attributes['RESOLUTION']);
            final bandwidth = int.tryParse(attributes['BANDWIDTH'] ?? '');

            variants.add(HLSQualityOption(
              url: resolvedUrl,
              name: name,
              height: height,
              bandwidth: bandwidth,
            ));
          }
        }
      }
    }

    return _deduplicateAndSort(variants);
  }

  static Map<String, String> _parseAttributes(String raw) {
    final attributes = <String, String>{};
    final regex = RegExp(r'([A-Za-z_-]+)=(?:"([^"]*)"|([^,]*))');
    final matches = regex.allMatches(raw);

    for (final match in matches) {
      final key = match.group(1)?.toUpperCase() ?? '';
      final value = match.group(2) ?? match.group(3) ?? '';
      if (key.isNotEmpty) {
        attributes[key] = value;
      }
    }

    return attributes;
  }

  static String _resolveUrl(String baseUrl, String relativeUrl) {
    if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }

    final baseUri = Uri.parse(baseUrl);
    final basePath = baseUri.path;
    final baseDir = basePath.contains('/') 
        ? basePath.substring(0, basePath.lastIndexOf('/') + 1) 
        : '/';

    return '${baseUri.scheme}://${baseUri.authority}$baseDir$relativeUrl';
  }

  static String _generateName(Map<String, String> attributes) {
    final resolution = attributes['RESOLUTION'];
    if (resolution != null) {
      final height = _parseHeight(resolution);
      if (height != null) {
        return '${height}P';
      }
    }
    final bandwidth = attributes['BANDWIDTH'];
    if (bandwidth != null) {
      final bw = int.tryParse(bandwidth);
      if (bw != null) {
        if (bw >= 1000000) {
          return '${(bw / 1000000).toStringAsFixed(1)}Mbps';
        }
        return '${(bw / 1000).toStringAsFixed(0)}Kbps';
      }
    }
    return '未知';
  }

  static int? _parseHeight(String? resolution) {
    if (resolution == null) return null;
    final parts = resolution.split('x');
    if (parts.length == 2) {
      return int.tryParse(parts[1]);
    }
    return null;
  }

  static List<HLSQualityOption> _deduplicateAndSort(List<HLSQualityOption> options) {
    final unique = <String, HLSQualityOption>{};
    for (final option in options) {
      unique[option.url] = option;
    }

    final sorted = unique.values.toList();
    sorted.sort((a, b) {
      final aHeight = a.height ?? 0;
      final bHeight = b.height ?? 0;
      return bHeight.compareTo(aHeight);
    });

    return sorted;
  }
}