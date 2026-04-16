import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/nodejs/nodejs_service.dart';
import 'package:tvbox_flutter/models/live_channel.dart';
import 'package:tvbox_flutter/ui/player/video_player_page.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  List<LiveChannel> _channels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    setState(() => _isLoading = true);
    
    try {
      final channels = await NodeJSService.instance.getLiveChannels();
      setState(() {
        _channels = channels.map((json) => LiveChannel.fromJson(json)).toList();
      });
    } catch (e) {
      print('Load channels error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _playChannel(LiveChannel channel) async {
    final playUrl = await NodeJSService.instance.getLivePlayUrl(channel.id);
    
    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(
          playUrl: playUrl,
          title: channel.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('直播'),
      ),
      body: _isLoading
          ? const Center(
              child: SpinKitFadingCircle(
                color: Colors.blue,
                size: 50.0,
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _channels.length,
              itemBuilder: (context, index) {
                final channel = _channels[index];
                return Card(
                  child: InkWell(
                    onTap: () => _playChannel(channel),
                    child: Column(
                      children: [
                        if (channel.logo != null)
                          Expanded(
                            child: CachedNetworkImage(
                              imageUrl: channel.logo!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            channel.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
