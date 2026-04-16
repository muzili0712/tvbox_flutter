import 'package:flutter/foundation.dart';
import 'package:tvbox_flutter/nodejs/nodejs_service.dart';

enum PlayerType {
  vlc,
  system,
}

class PlayerProvider extends ChangeNotifier {
  static final PlayerProvider instance = PlayerProvider._internal();
  
  PlayerType _defaultPlayer = PlayerType.vlc;
  PlayerType get defaultPlayer => _defaultPlayer;
  
  bool _hardwareAcceleration = true;
  bool get hardwareAcceleration => _hardwareAcceleration;
  
  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;
  
  int _skipIntroStart = 0;
  int get skipIntroStart => _skipIntroStart;
  
  int _skipIntroEnd = 0;
  int get skipIntroEnd => _skipIntroEnd;
  
  PlayerProvider._internal();
  
  void setDefaultPlayer(PlayerType player) {
    _defaultPlayer = player;
    notifyListeners();
  }
  
  void setHardwareAcceleration(bool value) {
    _hardwareAcceleration = value;
    notifyListeners();
  }
  
  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    notifyListeners();
  }
  
  void setSkipIntro(int start, int end) {
    _skipIntroStart = start;
    _skipIntroEnd = end;
    notifyListeners();
  }
  
  Future<String> getPlayUrl(String playId) async {
    return await NodeJSService.instance.getPlayUrl(playId);
  }
  
  Future<String> getCloudDrivePlayUrl(String driveId, String fileId) async {
    return await NodeJSService.instance.getCloudDrivePlayUrl(driveId, fileId);
  }
  
  Future<String> getLivePlayUrl(String channelId) async {
    return await NodeJSService.instance.getLivePlayUrl(channelId);
  }
}
