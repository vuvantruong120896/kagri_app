import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileProvider extends ChangeNotifier {
  String _displayName = '';
  String _avatarUrl = '';
  static const String _nameKey = 'user_display_name';
  static const String _avatarKey = 'user_avatar_url';

  String get displayName => _displayName;
  String get avatarUrl => _avatarUrl;

  UserProfileProvider() {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _displayName = prefs.getString(_nameKey) ?? '';
    _avatarUrl = prefs.getString(_avatarKey) ?? '';
    notifyListeners();
  }

  Future<void> updateDisplayName(String name) async {
    _displayName = name;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
  }

  Future<void> updateAvatarUrl(String url) async {
    _avatarUrl = url;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarKey, url);
  }

  Future<void> clearProfile() async {
    _displayName = '';
    _avatarUrl = '';
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_nameKey);
    await prefs.remove(_avatarKey);
  }
}
