import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:tvbox_flutter/providers/source_provider.dart';
import 'package:tvbox_flutter/models/video_item.dart';
import 'package:tvbox_flutter/nodejs/nodejs_service.dart';
import 'package:tvbox_flutter/ui/detail/detail_page.dart';

class SearchPage extends StatefulWidget {
  final String? initialSearch;
  
  const SearchPage({super.key, this.initialSearch});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isSearching = false;
  Map<String, List<VideoItem>> _resultsBySite = {};
  Map<String, bool> _searchingStatus = {};
  Map<String, int> _resultCount = {};
  String? _selectedSiteKey;
  Timer? _debounceTimer;
  final Set<String> _activeSites = {};

  void log(String message) {
    print('[搜索] $message');
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null) {
      _searchController.text = widget.initialSearch!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(widget.initialSearch!);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer != null) {
      _debounceTimer!.cancel();
    }
    if (query.trim().isEmpty) {
      setState(() {
        _resultsBySite.clear();
        _searchingStatus.clear();
        _resultCount.clear();
        _selectedSiteKey = null;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String keyword) async {
    if (keyword.isEmpty) return;
    
    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);
    final sites = sourceProvider.allSites;
    
    // 筛选出正常的影视站点（排除豆瓣和配置中心）
    final validSites = sites.where((site) {
      final key = site['key']?.toString() ?? '';
      return key.isNotEmpty && 
             key != 'nodejs_douban' && 
             key != 'nodejs_baseset';
    }).toList();

    log('[搜索] 🔍 有效线路数量: ${validSites.length}');
    
    setState(() {
      _isSearching = true;
      _resultsBySite.clear();
      _searchingStatus.clear();
      _resultCount.clear();
      _activeSites.clear();
    });

    for (final site in validSites) {
      final key = site['key']?.toString() ?? '';
      if (key.isEmpty) continue;
      
      setState(() {
        _searchingStatus[key] = true;
        _activeSites.add(key);
      });
      
      // 设置默认选中第一个
      if (_selectedSiteKey == null) {
        setState(() {
          _selectedSiteKey = key;
        });
      }
      
      unawaited(_searchSingleSite(key, keyword, site));
    }
  }

  Future<void> _searchSingleSite(String siteKey, String keyword, Map<String, dynamic> site) async {
    try {
      final nodejsService = NodejsService();
      
      // 临时切换到该站点进行搜索
      await nodejsService.setSpiderBySiteKey(siteKey);
      
      final result = await nodejsService.search(keyword: keyword, page: 1);
      
      if (!mounted) return;
      
      List<VideoItem> items = [];
      if (result['list'] != null && result['list'] is List) {
        items = (result['list'] as List).map((item) {
          return VideoItem.fromJson(item as Map<String, dynamic>);
        }).toList();
      }
      
      log('[搜索] 🔍 ${site['name']} 返回 ${items.length} 条结果');
      
      // 过滤和排序
      items = _filterSearchResults(items, keyword);
      items = _sortByRelevance(items, keyword);
      
      setState(() {
        _resultsBySite[siteKey] = items;
        _resultCount[siteKey] = items.length;
        _searchingStatus[siteKey] = false;
      });
    } catch (e) {
      log('[搜索] ❌ ${site['name']} 搜索失败: $e');
      if (!mounted) return;
      setState(() {
        _searchingStatus[siteKey] = false;
      });
    }
  }

  List<VideoItem> _filterSearchResults(List<VideoItem> videos, String keyword) {
    if (keyword.isEmpty) return videos;
    
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
    final buffer = StringBuffer();
    for (final char in text.runes) {
      final ch = String.fromCharCode(char);
      if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(ch)) {
        buffer.write(ch.toLowerCase());
      }
    }
    return buffer.toString();
  }

  List<VideoItem> _sortByRelevance(List<VideoItem> videos, String keyword) {
    final normalizedKeyword = _normalizeSearchText(keyword);
    
    videos.sort((a, b) {
      final scoreA = _calculateRelevanceScore(a, normalizedKeyword);
      final scoreB = _calculateRelevanceScore(b, normalizedKeyword);
      return scoreB.compareTo(scoreA);
    });
    
    return videos;
  }

  int _calculateRelevanceScore(VideoItem video, String keyword) {
    int score = 0;
    final name = _normalizeSearchText(video.name);
    
    // 名称完全匹配
    if (name == keyword) {
      score += 1000;
    }
    // 名称开头匹配
    else if (name.startsWith(keyword)) {
      score += 500;
    }
    // 名称包含
    else if (name.contains(keyword)) {
      score += 100;
    }
    
    // 多词匹配
    final tokens = keyword.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    for (final token in tokens) {
      if (name.contains(token)) {
        score += 50;
      }
    }
    
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final sourceProvider = Provider.of<SourceProvider>(context, listen: true);
    
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          autofocus: widget.initialSearch == null,
          decoration: InputDecoration(
            hintText: '搜索影片...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _resultsBySite.clear();
                        _searchingStatus.clear();
                        _resultCount.clear();
                        _selectedSiteKey = null;
                      });
                    },
                  )
                : null,
          ),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          onSubmitted: (value) {
            _performSearch(value.trim());
          },
          onChanged: _onSearchChanged,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _performSearch(_searchController.text.trim()),
          ),
        ],
      ),
      body: Row(
        children: [
          // 左侧线路列表
          Container(
            width: 180,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(right: BorderSide(color: Colors.grey[800]!)),
            ),
            child: _buildSiteList(sourceProvider),
          ),
          // 右侧搜索结果
          Expanded(
            child: _buildResultsContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteList(SourceProvider sourceProvider) {
    final sites = sourceProvider.allSites.where((site) {
      final key = site['key']?.toString() ?? '';
      return key.isNotEmpty && 
             key != 'nodejs_douban' && 
             key != 'nodejs_baseset';
    }).toList();
    
    if (sites.isEmpty && _activeSites.isEmpty) {
      return const Center(
        child: Text('暂无线路', style: TextStyle(color: Colors.grey)),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _activeSites.length,
      itemBuilder: (context, index) {
        // 查找对应的站点信息
        final key = _activeSites.elementAt(index);
        final site = sites.firstWhere((s) => s['key'] == key, orElse: () => {'name': key, 'key': key});
        final isSelected = _selectedSiteKey == key;
        final isSearching = _searchingStatus[key] ?? false;
        final count = _resultCount[key] ?? 0;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1) : null,
          ),
          child: ListTile(
            dense: true,
            title: Text(
              site['name']?.toString() ?? key,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[300],
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Row(
              children: [
                if (isSearching)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[400]),
                  ),
                if (isSearching) const SizedBox(width: 6),
                Text(
                  isSearching ? '搜索中...' : '$count 条结果',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
            onTap: () {
              setState(() {
                _selectedSiteKey = key;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildResultsContent() {
    if (_selectedSiteKey == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text('请输入搜索关键词', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }
    
    final results = _resultsBySite[_selectedSiteKey] ?? [];
    final isSearching = _searchingStatus[_selectedSiteKey] ?? false;
    
    if (isSearching && results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text('暂无搜索结果', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        return _buildVideoCard(results[index]);
      },
    );
  }

  Widget _buildVideoCard(VideoItem video) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailPage(videoId: video.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Image.network(
                video.cover,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (video.remark != null && video.remark!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        video.remark!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
