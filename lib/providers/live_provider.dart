import 'package:flutter/foundation.dart';
import 'package:tvbox_flutter/nodejs/nodejs_service.dart';
import 'package:tvbox_flutter/models/live_channel.dart';

class LiveProvider extends ChangeNotifier {
  List<LiveChannel> _channels = [];
  bool _isLoading = false;

  List<LiveChannel> get channels => _channels;
  bool get isLoading => _isLoading;

  LiveProvider() {
    loadChannels();
  }

  Future<void> loadChannels() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await NodeJSService.instance.getLiveChannels();
      _channels = data.map((json) => LiveChannel.fromJson(json)).toList();
    } catch (e) {
      print('Failed to load live channels: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> getPlayUrl(String channelId) async {
    return await NodeJSService.instance.getLivePlayUrl(channelId);
  }
}
