import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

// Context Class
class AudioPlayerManager extends ChangeNotifier {
  late PlayerState _state;
  final ap.AudioPlayer audioPlayer = ap.AudioPlayer();
  String? _currentTrack;
  List<String> playlist = [];

  AudioPlayerManager() {
    _state = StoppedState(this);
    audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == ap.PlayerState.completed) {
        stop();
      }
    });
  }

  PlayerState get state => _state;
  String get currentStateName => _state.runtimeType.toString();
  String? get currentTrack => _currentTrack;

  void changeState(PlayerState state) {
    _state = state;
    notifyListeners();
  }

  Future<void> setTrack(String filePath) async {
    _currentTrack = filePath;
    await audioPlayer.setSource(ap.DeviceFileSource(filePath));
    notifyListeners();
  }

  Future<void> pickFiles() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        return;
      }
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result != null) {
      playlist = result.paths.map((path) => path!).toList();
      if (playlist.isNotEmpty) {
        await setTrack(playlist.first);
      }
      notifyListeners();
    }
  }

  void play() {
    _state.play();
  }

  void pause() {
    _state.pause();
  }

  void stop() {
    _state.stop();
  }
}

abstract class PlayerState {
  void play();
  void pause();
  void stop();
}

class PlayingState implements PlayerState {
  final AudioPlayerManager _player;

  PlayingState(this._player);

  @override
  void play() {}

  @override
  void pause() {
    _player.audioPlayer.pause();
    _player.changeState(PausedState(_player));
  }

  @override
  void stop() {
    _player.audioPlayer.stop();
    _player.changeState(StoppedState(_player));
  }
}

class PausedState implements PlayerState {
  final AudioPlayerManager _player;

  PausedState(this._player);

  @override
  void play() {
    _player.audioPlayer.resume();
    _player.changeState(PlayingState(_player));
  }

  @override
  void pause() {}

  @override
  void stop() {
    _player.audioPlayer.stop();
    _player.changeState(StoppedState(_player));
  }
}

class StoppedState implements PlayerState {
  final AudioPlayerManager _player;

  StoppedState(this._player);

  @override
  void play() {
    if (_player.currentTrack != null) {
      _player.audioPlayer.play(ap.DeviceFileSource(_player.currentTrack!));
      _player.changeState(PlayingState(_player));
    }
  }

  @override
  void pause() {}

  @override
  void stop() {}
}
