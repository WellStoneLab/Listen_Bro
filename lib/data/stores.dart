import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_models.dart';

class SettingsStore {
  static const _settingsKey = 'app_settings';
  static const _debugKey = 'debug_overrides';

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return const AppSettings();
    return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<DebugOverrides> loadDebug() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_debugKey);
    if (raw == null) return const DebugOverrides();
    return DebugOverrides.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveDebug(DebugOverrides debug) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_debugKey, jsonEncode(debug.toJson()));
  }
}

class SaveStore {
  static const _saveKey = 'game_save';

  Future<bool> hasSave() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_saveKey);
  }

  Future<GameSaveData?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_saveKey);
    if (raw == null) return null;
    return GameSaveData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(GameSaveData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saveKey, jsonEncode(data.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKey);
  }
}
