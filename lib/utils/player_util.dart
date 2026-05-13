class PlayerUtil {
  // 格式化时长
  static String formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }
  
  // 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
  
  // 检查是否是直播流
  static bool isLiveStream(String url) {
    return url.contains('.m3u8') || 
           url.contains('.flv') || 
           url.contains('rtmp://') ||
           url.contains('rtsp://');
  }

  // 解析播放URL，处理多种格式
  static ParsedUrlResult parsePlayUrl(String url) {
    if (url.isEmpty) {
      return ParsedUrlResult(url: '', segments: [], isArrayFormat: false);
    }

    // 处理数组格式 [原画, null]
    if (url.startsWith('[') && url.endsWith(']')) {
      try {
        final content = url.substring(1, url.length - 1);
        final parts = content.split(',');
        if (parts.length >= 2) {
          final quality = parts[0].trim().replaceAll('"', '').replaceAll("'", '');
          final actualUrl = parts[1].trim().replaceAll('"', '').replaceAll("'", '');
          if (actualUrl.toLowerCase() != 'null' && actualUrl.isNotEmpty) {
            return ParsedUrlResult(
              url: actualUrl,
              segments: [actualUrl],
              quality: quality,
              isArrayFormat: true,
            );
          }
        }
        return ParsedUrlResult(url: '', segments: [], isArrayFormat: true);
      } catch (e) {
        return ParsedUrlResult(url: url, segments: [url], isArrayFormat: false);
      }
    }

    // 处理多段分片视频格式（用 ||| 和 *** 分隔）
    final segments = <String>[];
    
    if (url.contains('|||')) {
      final parts = url.split('|||');
      for (var part in parts) {
        if (part.contains('***')) {
          final subParts = part.split('***');
          for (var subPart in subParts) {
            final trimmed = subPart.trim();
            if (trimmed.isNotEmpty && isValidUrl(trimmed)) {
              segments.add(trimmed);
            }
          }
        } else {
          final trimmed = part.trim();
          if (trimmed.isNotEmpty && isValidUrl(trimmed)) {
            segments.add(trimmed);
          }
        }
      }
    } else if (url.contains('***')) {
      final parts = url.split('***');
      for (var part in parts) {
        final trimmed = part.trim();
        if (trimmed.isNotEmpty && isValidUrl(trimmed)) {
          segments.add(trimmed);
        }
      }
    } else {
      segments.add(url);
    }

    return ParsedUrlResult(
      url: segments.isNotEmpty ? segments.first : url,
      segments: segments,
      isArrayFormat: false,
    );
  }

  // 检查是否是有效的URL
  static bool isValidUrl(String url) {
    if (url.isEmpty) return false;
    if (url.toLowerCase() == 'null') return false;
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}

class ParsedUrlResult {
  final String url;
  final List<String> segments;
  final String? quality;
  final bool isArrayFormat;

  ParsedUrlResult({
    required this.url,
    required this.segments,
    this.quality,
    required this.isArrayFormat,
  });
}
