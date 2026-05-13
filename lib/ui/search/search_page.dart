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

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      List<VideoItem> allResults = [];
      final provider = Provider.of<SourceProvider>(context, listen: false);

      // 如果是搜索全部或者没有选择特定站点，遍历非豆瓣的站点搜索
      if (_selectedSite == null) {
        log('[搜索] 🔍 搜索全部线路');
        // 筛选出正常的影视站点（排除豆瓣和配置中心）
        final validSites = provider.sites.where((site) {
          final key = site['key'] as String? ?? '';
          return key != 'nodejs_douban' && key != 'nodejs_baseset';
        }).toList();
        
        log('[搜索] 🔍 有效线路数量: ${validSites.length}');
        
        // 最多搜索前5个站点避免耗时太长
        final sitesToSearch = validSites.take(5).toList();
        
        for (final site in sitesToSearch) {
          try {
            final key = (site['key'] as String?)?.replaceFirst('nodejs_', '') ?? '';
            final type = site['type'] as int? ?? 3;
            final api = site['api'] as String? ?? '';
            final siteName = site['name'] as String? ?? key;
            
            log('[搜索] 🔍 搜索 $siteName');
            
            NodeJSService.instance.setCurrentSpider(key, type, apiBase: api);
            await NodeJSService.instance.initSpider();
            
            final result = await NodeJSService.instance.search(keyword: keyword);
            final list = result['list'] as List<dynamic>? ?? [];
            
            log('[搜索] 🔍 $siteName 返回 ${list.length} 条结果');
            
            for (final json in list) {
              final video = VideoItem.fromJson(json as Map<String, dynamic>);
              allResults.add(video);
            }
          } catch (e) {
            log('[搜索] ❌ 搜索失败: $e');
            // 继续搜索下一个站点
            continue;
          }
        }
        
        // 去重（根据名称和id）
        final seen = <String>{};
        allResults = allResults.where((video) {
          final key = '${video.name}_${video.id}';
          if (seen.contains(key)) return false;
          seen.add(key);
          return true;
        }).toList();
        
      } else {
        // 搜索单个站点
        final key = (_selectedSite!['key'] as String?)?.replaceFirst('nodejs_', '') ?? '';
        final type = _selectedSite!['type'] as int? ?? 3;
        final api = _selectedSite!['api'] as String? ?? '';
        NodeJSService.instance.setCurrentSpider(key, type, apiBase: api);
        await NodeJSService.instance.initSpider();

        final result = await NodeJSService.instance.search(keyword: keyword);
        final list = result['list'] as List<dynamic>? ?? [];
        allResults = list
            .map((json) => VideoItem.fromJson(json as Map<String, dynamic>))
            .toList();
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
