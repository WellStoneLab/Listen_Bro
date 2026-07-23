import 'package:audioplayers/audioplayers.dart';

import '../models/game_models.dart';

class AudioService {
  final AudioPlayer _sePlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();
  AppSettings _settings = const AppSettings();
  String? _currentBgmPath;
  int _sePlayToken = 0;

  Future<void> init(AppSettings settings) async {
    _settings = settings;
    await _sePlayer.setReleaseMode(ReleaseMode.stop);
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> applySettings(AppSettings settings) async {
    _settings = settings;
    final musicVol = _settings.musicVolume.clamp(0.0, 1.0);
    await _bgmPlayer.setVolume(musicVol);
    if (musicVol <= 0) {
      if (_bgmPlayer.state == PlayerState.playing) {
        await _bgmPlayer.pause();
      }
      return;
    }
    if (_currentBgmPath != null && _bgmPlayer.state != PlayerState.playing) {
      await playBgm(_currentBgmPath!);
    }
  }

  Future<void> playBgm(String assetPath) async {
    final path = _normalize(assetPath);
    final vol = _settings.musicVolume.clamp(0.0, 1.0);
    if (_currentBgmPath == path && _bgmPlayer.state == PlayerState.playing) {
      await _bgmPlayer.setVolume(vol);
      return;
    }
    _currentBgmPath = path;
    try {
      await _bgmPlayer.stop();
      if (vol <= 0) return;
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(vol);
      await _bgmPlayer.play(AssetSource(path));
    } catch (_) {}
  }

  Future<void> stopBgm() async {
    _currentBgmPath = null;
    try {
      await _bgmPlayer.stop();
    } catch (_) {}
  }

  Future<void> playSe(String assetPath) async {
    final vol = _settings.soundVolume.clamp(0.0, 1.0);
    if (vol <= 0) return;
    try {
      final path = _normalize(assetPath);
      await _sePlayer.stop();
      await _sePlayer.setVolume(vol);
      await _sePlayer.play(AssetSource(path));
    } catch (_) {}
  }

  /// Plays SE then stops after [duration] (e.g. shake for 2 seconds).
  Future<void> playSeFor(String assetPath, Duration duration) async {
    final token = ++_sePlayToken;
    await playSe(assetPath);
    await Future<void>.delayed(duration);
    if (token != _sePlayToken) return;
    await stopSe();
  }

  Future<void> stopSe() async {
    try {
      await _sePlayer.stop();
    } catch (_) {}
  }

  String _normalize(String assetPath) {
    var path = assetPath;
    if (path.startsWith('assets/')) {
      path = path.substring('assets/'.length);
    }
    return path;
  }

  Future<void> dispose() async {
    await _sePlayer.dispose();
    await _bgmPlayer.dispose();
  }
}
