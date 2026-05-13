import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:tvbox_flutter/services/log_service.dart';

class HLSQualityOption {
  final String id;
  final String name;
  final String url;
  
  const HLSQualityOption({
    required this.id,
    required this.name,
    required this.url,
  });
  
  bool get isAuto => id == 'auto';
  
  static HLSQualityOption auto(String url) => HLSQualityOption(
    id: 'auto',
    name: '自动',
    url: url,
  );
}

class HLSQualityResolver {
  static Future<List<HLSQualityOption>> resolveQualityOptions(String episodeUrl) async {
    if (episodeUrl.isEmpty) return [];
    
    final trimmedUrl = episodeUrl.trim();
    if (!_looksLikeHLSUrl(trimmedUrl)) return [];
    
    try {
      log('[HLS解析] 🔍 解析HLS清晰度: $trimmedUrl');
      
      final playlist = await _fetchPlaylist(trimmedUrl);
      if (playlist == null || playlist.isEmpty) {
        log('[HLS解析] ⚠️ 获取播放列表失败');
        return [];
      }
      
      final variants = _parseMasterPlaylist(playlist, trimmedUrl);
      if (variants.isEmpty) {
        log('[HLS解析] ⚠️ 未找到变体流');
        return [];
      }
      
      log('[HLS解析] ✅ 找到${variants.length}个清晰度选项');
      
      // 去重
      final seen = <String>{};
      final deduped = variants.where((v) => seen.add(v.url)).toList();
      
      // 排序：高度优先，然后带宽
      deduped.sort((a, b) {
        final aHeight = a.height ?? -1;
        final bHeight = b.height ?? -1;
        if (aHeight != bHeight) return bHeight.compareTo(aHeight);
        final aBandwidth = a.bandwidth ?? -1;
        final bBandwidth = b.bandwidth ?? -1;
        return bBandwidth.compareTo(aBandwidth);
      });
      
      // 构建选项列表
      final options = <HLSQualityOption>[];
      options.add(HLSQualityOption.auto(trimmedUrl));
      
      final displayNameCount = <String, int>{};
      for (var i = 0; i < deduped.length; i++) {
        final variant = deduped[i];
        String baseName;
        if (variant.name != null && variant.name!.isNotEmpty) {
          baseName = variant.name!;
        } else if (variant.height != null) {
          baseName = '${variant.height}p';
        } else if (variant.bandwidth != null && variant.bandwidth! > 0) {
          baseName = '${(variant.bandwidth! / 1000).round()}K';
        } else {
          baseName = '清晰度${i + 1}';
        }
        
        final count = (displayNameCount[baseName] ?? 0) + 1;
        displayNameCount[baseName] = count;
        final finalName = count > 1 ? '$baseName $count' : baseName;
        
        options.add(HLSQualityOption(
          id: variant.url,
          name: finalName,
          url: variant.url,
        ));
      }
      
      return options;
    } catch (e) {
      log('[HLS解析] ❌ 解析失败: $e');
      return [];
    }
  }
  
  static bool _looksLikeHLSUrl(String url) {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('.m3u8')) return true;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final path = uri.path.toLowerCase();
    return path.endsWith('.m3u8') || path.endsWith('.m3u');
  }
  
  static Future<String?> _fetchPlaylist(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      log('[HLS解析] ❌ 网络请求失败: $e');
    }
    return null;
  }
  
  static List<_HLSVariant> _parseMasterPlaylist(String content, String masterUrl) {
    final variants = <_HLSVariant>[];
    
    if (!content.toUpperCase().contains('#EXT-X-STREAM-INF')) {
      return variants;
    }
    
    final lines = content.split('\n');
    var index = 0;
    
    while (index < lines.length) {
      final line = lines[index].trim();
      
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        final attributes = _parseAttributes(line.substring('#EXT-X-STREAM-INF:'.length));
        String? uri;
        
        final nextIndex = index + 1;
        if (nextIndex < lines.length) {
          final nextLine = lines[nextIndex].trim();
          if (!nextLine.startsWith('#')) {
            uri = nextLine;
            index = nextIndex;
          }
        }
        
        if (uri != null && uri.isNotEmpty) {
          final resolvedUrl = _resolveUrl(uri, masterUrl);
          final name = attributes['NAME']?.trim();
          final bandwidth = _parseInt(attributes['BANDWIDTH']);
          
          int? height;
          final resolution = attributes['RESOLUTION'];
          if (resolution != null) {
            final parts = resolution.split('x');
            if (parts.length == 2) {
              height = int.tryParse(parts[1].trim());
            }
          }
          
          variants.add(_HLSVariant(
            url: resolvedUrl,
            name: name,
            height: height,
            bandwidth: bandwidth,
          ));
        }
      }
      
      index++;
    }
    
    return variants;
  }
  
  static Map<String, String> _parseAttributes(String raw) {
    final result = <String, String>{};
    final parts = _splitAttributes(raw);
    
    for (final part in parts) {
      final idx = part.indexOf('=');
      if (idx > 0) {
        var key = part.substring(0, idx).trim();
        var value = part.substring(idx + 1).trim();
        
        if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
          value = value.substring(1, value.length - 1);
        }
        
        result[key] = value;
      }
    }
    
    return result;
  }
  
  static List<String> _splitAttributes(String raw) {
    final parts = <String>[];
    var buffer = StringBuffer();
    var inQuotes = false;
    
    for (var i = 0; i < raw.length; i++) {
      final char = raw[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
        buffer.write(char);
      } else if (char == ',' && !inQuotes) {
        final item = buffer.toString().trim();
        if (item.isNotEmpty) {
          parts.add(item);
        }
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    
    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) {
      parts.add(tail);
    }
    
    return parts;
  }
  
  static String _resolveUrl(String uri, String baseUrl) {
    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      return uri;
    }
    
    final baseUri = Uri.parse(baseUrl);
    if (uri.startsWith('/')) {
      return '${baseUri.scheme}://${baseUri.host}$uri';
    }
    
    return baseUri.resolve(uri).toString();
  }
  
  static int? _parseInt(String? value) {
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value);
  }
}

class _HLSVariant {
  final String url;
  final String? name;
  final int? height;
  final int? bandwidth;
  
  const _HLSVariant({
    required this.url,
    this.name,
    this.height,
    this.bandwidth,
  });
}
