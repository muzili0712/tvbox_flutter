import 'package:flutter/material.dart';
import 'package:tvbox_flutter/services/log_service.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/providers/source_provider.dart';
import 'package:tvbox_flutter/ui/widgets/video_card.dart';
import 'package:tvbox_flutter/ui/search/search_page.dart';
import 'package:tvbox_flutter/ui/settings/settings_page.dart';
import 'package:tvbox_flutter/ui/history/history_page.dart';
import 'package:tvbox_flutter/ui/favorite/favorite_page.dart';
import 'package:tvbox_flutter/ui/cloud_drive/cloud_drive_page.dart';
import 'package:tvbox_flutter/ui/live/live_page.dart';
import 'package:tvbox_flutter/ui/widgets/bottom_nav_bar.dart';
import 'package:tvbox_flutter/ui/detail/detail_page.dart';
import 'package:tvbox_flutter/ui/log/log_viewer_page.dart';
import 'package:tvbox_flutter/ui/settings/source_management_page.dart';
import 'package:tvbox_flutter/models/video_item.dart';
import 'package:tvbox_flutter/nodejs/nodejs_service.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return const HomeContent();
      case 1:
        return const LivePage();
      case 2:
        return const CloudDrivePage();
      case 3:
        return const HistoryPage();
      case 4:
        return const FavoritePage();
      default:
        return const SizedBox.shrink();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getPage(_selectedIndex),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
    _loadHomeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    log('[主页] 🏠 开始加载首页数据...');
    setState(() => _isLoading = true);

    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);

    await sourceProvider.ensureLoaded();
    log('[主页] 🏠 ensureLoaded完成: currentSource=${sourceProvider.currentSource?.name ?? "无"}, hasSpiderServer=${NodeJSService.instance.hasSpiderServer}');

    final nodejs = NodeJSService.instance;

    if (sourceProvider.currentSource != null &&
        sourceProvider.currentSource!.sourceType == 'remote' &&
        !nodejs.hasSpiderServer) {
      String loadUrl = sourceProvider.currentSource!.url;
      if (loadUrl.endsWith('.js.md5')) {
        loadUrl = loadUrl.substring(0, loadUrl.length - 4);
      }
      log('[主页] 🏠 Spider未启动，从URL加载: $loadUrl');
      final success = await nodejs.loadSourceFromURL(loadUrl);
      log('[主页] 🏠 loadSourceFromURL结果: $success, spiderPort=${nodejs.spiderPort}');
      if (!success) {
        log('[主页] ❌ 加载源失败，停止加载首页');
        setState(() => _isLoading = false);
        return;
      }
    }

    await sourceProvider.loadHomeContent();
    log('[主页] 🏠 loadHomeContent完成: categories=${sourceProvider.categories.length}');

    if (sourceProvider.categories.isNotEmpty && mounted) {
      setState(() {
        _tabController = TabController(
          length: sourceProvider.categories.length,
          vsync: this,
        );
      });
      log('[主页] ✅ 首页TabBar已更新: ${sourceProvider.categories.length}个分类');
    } else {
      log('[主页] ⚠️ 没有分类数据，首页显示"内容未加载"');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Consumer<SourceProvider>(
          builder: (context, provider, _) {
            if (provider.sites.length > 1) {
              return PopupMenuButton<Map<String, dynamic>>(
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swap_horiz, size: 20),
                    Flexible(
                      child: Text(
                        provider.currentSite?['name'] ?? '',
                        style: TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                onSelected: (site) {
                  provider.setCurrentSite(site).then((_) {
                    if (provider.categories.isNotEmpty) {
                      setState(() {
                        _tabController = TabController(
                          length: provider.categories.length,
                          vsync: this,
                        );
                      });
                    }
                  });
                },
                itemBuilder: (context) => provider.sites.map((site) {
                  final key = site['key'] as String? ?? '';
                  final name = site['name'] as String? ?? key;
                  final isCurrent = provider.currentSite?['key'] == key;
                  return PopupMenuItem<Map<String, dynamic>>(
                    value: site,
                    child: Row(
                      children: [
                        Icon(
                          isCurrent
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isCurrent ? Colors.green : null,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(name)),
                      ],
                    ),
                  );
                }).toList(),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        title: const Text('TVBox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: '查看日志',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const LogViewerPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
        bottom: _isLoading ||
                Provider.of<SourceProvider>(context).categories.isEmpty
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: Provider.of<SourceProvider>(context)
                    .categories
                    .map((category) => Tab(text: category['type_name'] ?? category['name']))
                    .toList(),
              ),
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

    final sourceProvider = Provider.of<SourceProvider>(context);

    if (sourceProvider.sources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.source_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('请添加数据源', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SourceManagementPage()),
                ).then((_) => _loadHomeData());
              },
              child: const Text('添加数据源'),
            ),
          ],
        ),
      );
    }

    if (sourceProvider.categories.isEmpty && !sourceProvider.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.refresh, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('内容未加载', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadHomeData(),
              child: const Text('加载内容'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: sourceProvider.categories.map((category) {
        return _buildCategoryContent(category);
      }).toList(),
    );
  }

  Widget _buildCategoryContent(Map<String, dynamic> category) {
    final typeId = category['type_id']?.toString() ?? '';
    final siteKey = Provider.of<SourceProvider>(context).currentSite?['key'] ?? '';
    return _CategoryContentLoader(
        typeId: typeId,
        typeName: category['type_name'] ?? '',
        siteKey: siteKey);
  }
}

class _CategoryContentLoader extends StatefulWidget {
  final String typeId;
  final String typeName;
  final String siteKey;

  const _CategoryContentLoader({
    required this.typeId,
    required this.typeName,
    required this.siteKey,
  });

  @override
  State<_CategoryContentLoader> createState() =>
      _CategoryContentLoaderState();
}

class _CategoryContentLoaderState extends State<_CategoryContentLoader>
    with AutomaticKeepAliveClientMixin {
  List<VideoItem> _videos = [];
  bool _isLoading = true;
  int _currentPage = 1;
  bool _hasMore = true;
  String _lastSiteKey = '';
  String _lastFiltersKey = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _lastSiteKey = widget.siteKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _waitForFiltersAndLoad();
    });
  }

  Future<void> _waitForFiltersAndLoad() async {
    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);
    int waitCount = 0;
    while (waitCount < 20) {
      if (sourceProvider.categories.isNotEmpty && 
          sourceProvider.filters.isNotEmpty && 
          sourceProvider.currentSite?['key'] == 'nodejs_$widget.siteKey') {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 200));
      waitCount++;
    }
    if (mounted) {
      _loadContent();
    }
  }

  @override
  void didUpdateWidget(_CategoryContentLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.siteKey != _lastSiteKey || 
        widget.typeId != oldWidget.typeId ||
        _lastFiltersKey != Provider.of<SourceProvider>(context, listen: false).filters.keys.toString()) {
      _lastSiteKey = widget.siteKey;
      _lastFiltersKey = Provider.of<SourceProvider>(context, listen: false).filters.keys.toString();
      _currentPage = 1;
      _hasMore = true;
      _videos = [];
      _waitForFiltersAndLoad();
    }
  }

  Future<void> _loadContent() async {
    if (!_hasMore) return;

    setState(() => _isLoading = true);

    try {
      log('[分类内容] 📋 加载分类: typeId=${widget.typeId}, typeName=${widget.typeName}, siteKey=${widget.siteKey}, page=$_currentPage');
      await NodeJSService.instance.initSpider();
      
      final sourceProvider = Provider.of<SourceProvider>(context, listen: false);
      
      Map<String, dynamic> filterParams = {};
      List<dynamic>? filters = sourceProvider.filters[widget.typeId] as List<dynamic>?;
      
      log('[分类内容] 🔍 调试 - filters.keys=${sourceProvider.filters.keys.toList()}, typeId=${widget.typeId}, typeIdType=${widget.typeId.runtimeType}');
      
      if (filters != null && filters.isNotEmpty) {
        log('[分类内容] 🔍 当前分类(${widget.typeId})有${filters.length}个filters');
        for (final filter in filters) {
          if (filter is Map<String, dynamic>) {
            final key = filter['key'] as String?;
            final init = filter['init'];
            final values = filter['value'] as List<dynamic>?;
            
            if (key != null) {
              if (init != null && init.toString().isNotEmpty) {
                filterParams[key] = init;
                log('[分类内容] ✅ 使用init值: $key=$init');
              } else if (values != null && values.isNotEmpty) {
                final firstValue = values.first;
                if (firstValue is Map && firstValue['v'] != null) {
                  filterParams[key] = firstValue['v'];
                  log('[分类内容] ✅ 使用第一个可选值: $key=${firstValue['v']}');
                } else if (firstValue is Map && firstValue['value'] != null) {
                  filterParams[key] = firstValue['value'];
                  log('[分类内容] ✅ 使用第一个可选值(value字段): $key=${firstValue['value']}');
                } else {
                  filterParams[key] = firstValue;
                  log('[分类内容] ✅ 使用第一个原始值: $key=$firstValue');
                }
              }
            }
          }
        }
      } else {
        log('[分类内容] ⚠️ 当前分类(${widget.typeId})没有filters');
      }
      
      log('[分类内容] 📋 使用filters: $filterParams');
      
      final result = await NodeJSService.instance.getCategoryContent(
        categoryId: widget.typeId,
        page: _currentPage,
        filters: filterParams,
      );

      final list = result['list'] as List<dynamic>? ?? [];
      final pagecount = result['pagecount'] as int? ?? 1;

      log('[分类内容] 📋 获取到${list.length}个视频, pagecount=$pagecount, currentPage=$_currentPage');

      final newVideos = list
          .map((json) =>
              VideoItem.fromJson(json as Map<String, dynamic>))
          .toList();

      if (newVideos.isNotEmpty) {
        log('[分类内容] 📋 第一个视频: name=${newVideos.first.name}, id=${newVideos.first.id}');
      }

      setState(() {
        if (_currentPage == 1) {
          _videos = newVideos;
        } else {
          _videos.addAll(newVideos);
        }
        _hasMore = _currentPage < pagecount;
        _currentPage++;
        _isLoading = false;
      });
    } catch (e) {
      log('[分类内容] ❌ 加载失败: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading && _videos.isEmpty) {
      return const Center(
        child: SpinKitFadingCircle(color: Colors.blue, size: 50.0),
      );
    }

    if (_videos.isEmpty) {
      return const Center(child: Text('暂无内容'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _videos.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _videos.length) {
          _loadContent();
          return const Center(child: CircularProgressIndicator());
        }

        final video = _videos[index];
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
