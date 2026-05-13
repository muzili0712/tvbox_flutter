import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/nodejs/nodejs_service.dart';
import 'package:tvbox_flutter/ui/widgets/video_card.dart';
import 'package:tvbox_flutter/models/video_item.dart';
import 'package:tvbox_flutter/ui/detail/detail_page.dart';
import 'package:tvbox_flutter/providers/source_provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:tvbox_flutter/services/log_service.dart';

class SearchPage extends StatefulWidget {
  final String? initialSearch;
  
  const SearchPage({super.key, this.initialSearch});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  List<VideoItem> _results = [];
  bool _isLoading = false;
  Map<String, dynamic>? _selectedSite;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 默认设置为搜索全部
      setState(() {
        _selectedSite = null;
      });
      
      // 如果有初始搜索词，自动执行搜索
      if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
        _controller.text = widget.initialSearch!;
        _search();
      }
    });
  }

  Future<List<VideoItem>> _searchSingleSite(
      Map<String, dynamic> site, String keyword) async {
    try {
      final key = (site['key'] as String?)?.replaceFirst('nodejs_', '') ?? '';
      final type = site['type'] as int? ?? 3;
      final api = site['api'] as String? ?? '';
      final siteName = site['name'] as String? ?? key;
      
      log('[搜索] 🔍 开始搜索 $siteName');
      
      NodeJSService.instance.setCurrentSpider(key, type, apiBase: api);
      await NodeJSService.instance.initSpider();
      
      final result = await NodeJSService.instance.search(keyword: keyword);
      final list = result['list'] as List<dynamic>? ?? [];
      
      log('[搜索] 🔍 $siteName 返回 ${list.length} 条结果');
      
      final videos = list
          .map((json) => VideoItem.fromJson(json as Map<String, dynamic>))
          .toList();
      
      // 本地关键词过滤
      return _filterSearchResults(videos, keyword);
    } catch (e) {
      log('[搜索] ❌ $e');
      return [];
    }
  }
  
  List<VideoItem> _filterSearchResults(List<VideoItem> videos, String keyword) {
    if (keyword.isEmpty) return videos;
    
    // 分词处理
    final tokens = _normalizeSearchText(keyword)
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    
    if (tokens.isEmpty) return videos;
    
    return videos.where((video) {
      final searchableText = _normalizeSearchText([
        video.name,
        video.remark ?? '',
        video.actor ?? '',
        video.director ?? '',
        video.area ?? '',
        video.year ?? '',
      ].join(' '));
      
      return tokens.every((token) => searchableText.contains(token));
    }).toList();
  }
  
  String _normalizeSearchText(String text) {
    // 去除空白字符、标点符号等，统一转为小写
    final buffer = StringBuffer();
    for (final char in text.runes) {
      final ch = String.fromCharCode(char);
      // 只保留字母、数字和中文
      if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(ch)) {
        buffer.write(ch.toLowerCase());
      }
    }
    return buffer.toString();
  }

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      List<VideoItem> allResults = [];
      final provider = Provider.of<SourceProvider>(context, listen: false);

      if (_selectedSite == null) {
        log('[搜索] 🔍 并发搜索全部线路');
        
        // 筛选出正常的影视站点（排除豆瓣和配置中心）
        final validSites = provider.sites.where((site) {
          final key = site['key'] as String? ?? '';
          return key != 'nodejs_douban' && key != 'nodejs_baseset';
        }).toList();
        
        log('[搜索] 🔍 有效线路数量: ${validSites.length}');
        
        // 搜索前20个站点
        final sitesToSearch = validSites.take(20).toList();
        
        // 并发搜索所有站点
        final futures = sitesToSearch
            .map((site) => _searchSingleSite(site, keyword))
            .toList();
        
        final results = await Future.wait(futures);
        
        // 合并所有结果
        for (final videos in results) {
          allResults.addAll(videos);
        }
        
        // 去重处理 - 基于视频名称和封面进行去重
        final seen = <String>{};
        final uniqueResults = <VideoItem>[];
        for (final video in allResults) {
          // 使用名称+封面的组合作为去重键
          final key = '${video.name.toLowerCase()}|${video.cover}';
          if (!seen.contains(key)) {
            seen.add(key);
            uniqueResults.add(video);
          }
        }
        allResults = uniqueResults;
        
        log('[搜索] 🔍 去重后结果数: ${allResults.length}');
        
      } else {
        // 搜索单个站点
        allResults = await _searchSingleSite(_selectedSite!, keyword);
      }

      log('[搜索] 🔍 共找到 ${allResults.length} 条结果');
      
      setState(() {
        _results = allResults;
      });
    } catch (e) {
      log('[搜索] ❌ 搜索错误: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Consumer<SourceProvider>(
          builder: (context, provider, _) {
            if (provider.sites.isEmpty) {
              return const SizedBox.shrink();
            }
            return PopupMenuButton<Map<String, dynamic>>(
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, size: 20),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _selectedSite?['name'] ?? '全部线路',
                      style: TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              tooltip: '选择搜索线路',
              onSelected: (site) {
                setState(() {
                  _selectedSite = site;
                });
                if (_controller.text.trim().isNotEmpty) {
                  _search();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<Map<String, dynamic>>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(
                        _selectedSite == null ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: _selectedSite == null ? Colors.green : null,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text('搜索全部（前5条线路）'),
                    ],
                  ),
                ),
                ...provider.sites.map((site) {
                  final key = site['key'] as String? ?? '';
                  final name = site['name'] as String? ?? key;
                  final isCurrent = _selectedSite?['key'] == key;
                  return PopupMenuItem<Map<String, dynamic>>(
                    value: site,
                    child: Row(
                      children: [
                        Icon(
                          isCurrent ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isCurrent ? Colors.green : null,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(name)),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
        title: TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: '搜索影视...',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _search,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: SpinKitFadingCircle(
          color: Colors.blue,
          size: 50.0,
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text('输入关键词开始搜索'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final video = _results[index];
        return VideoCard(
          video: video,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailPage(videoId: video.id),
              ),
            );
          },
        );
      },
    );
  }
}
