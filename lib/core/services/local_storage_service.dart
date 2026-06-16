import 'dart:convert';

import 'shared_preferences_service.dart';

class LocalStorageService {
  final SharedPreferencesService _prefs;

  LocalStorageService(this._prefs);

  // ==================== USER DATA ====================

  Future<void> saveUserId(String userId) async {
    await _prefs.setString('user_id', userId);
  }

  String? getUserId() {
    return _prefs.getString('user_id');
  }

  Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _prefs.setString('user_data', jsonEncode(userData));
  }

  Map<String, dynamic>? getUserData() {
    final data = _prefs.getString('user_data');
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> clearUserData() async {
    await _prefs.remove('user_id');
    await _prefs.remove('user_data');
  }

  // ==================== AUTHENTICATION ====================

  Future<void> saveAuthToken(String token) async {
    await _prefs.setString('auth_token', token);
  }

  String? getAuthToken() {
    return _prefs.getString('auth_token');
  }

  Future<void> clearAuthToken() async {
    await _prefs.remove('auth_token');
  }

  Future<void> setLoggedIn(bool value) async {
    await _prefs.setBool('is_logged_in', value);
  }

  bool isLoggedIn() {
    return _prefs.getBool('is_logged_in') ?? false;
  }

  // ==================== ONBOARDING ====================

  Future<void> setOnboardingCompleted(bool value) async {
    await _prefs.setBool('onboarding_completed', value);
  }

  bool isOnboardingCompleted() {
    return _prefs.getBool('onboarding_completed') ?? false;
  }

  // ==================== LANGUAGE ====================

  Future<void> saveLanguageCode(String languageCode) async {
    await _prefs.setString('language_code', languageCode);
  }

  String? getLanguageCode() {
    return _prefs.getString('language_code');
  }

  // ==================== THEME ====================

  Future<void> saveThemeMode(String themeMode) async {
    await _prefs.setString('theme_mode', themeMode);
  }

  String? getThemeMode() {
    return _prefs.getString('theme_mode');
  }

  // ==================== CACHE ====================

  Future<void> cacheData(String key, Map<String, dynamic> data) async {
    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await _prefs.setString('cache_$key', jsonEncode(cacheData));
  }

  Map<String, dynamic>? getCachedData(String key, {Duration? maxAge}) {
    final cached = _prefs.getString('cache_$key');
    if (cached != null) {
      final cacheData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = cacheData['timestamp'] as int;
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

      if (maxAge != null) {
        if (DateTime.now().difference(cacheTime) > maxAge) {
          // Cache expired
          return null;
        }
      }

      return cacheData['data'] as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> clearCache(String key) async {
    await _prefs.remove('cache_$key');
  }

  Future<void> clearAllCache() async {
    final keys = _prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith('cache_')) {
        await _prefs.remove(key);
      }
    }
  }

  // ==================== POSTS DRAFT ====================

  Future<void> saveDraft(String draftContent) async {
    await _prefs.setString('post_draft', draftContent);
  }

  String? getDraft() {
    return _prefs.getString('post_draft');
  }

  Future<void> clearDraft() async {
    await _prefs.remove('post_draft');
  }

  // ==================== NOTIFICATIONS ====================

  Future<void> saveNotificationSettings(Map<String, bool> settings) async {
    await _prefs.setString('notification_settings', jsonEncode(settings));
  }

  Map<String, bool>? getNotificationSettings() {
    final settings = _prefs.getString('notification_settings');
    if (settings != null) {
      final decoded = jsonDecode(settings) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value as bool));
    }
    return null;
  }

  // ==================== CHAT ====================

  Future<void> saveChatDraft(String chatRoomId, String draftMessage) async {
    await _prefs.setString('chat_draft_$chatRoomId', draftMessage);
  }

  String? getChatDraft(String chatRoomId) {
    return _prefs.getString('chat_draft_$chatRoomId');
  }

  Future<void> clearChatDraft(String chatRoomId) {
    return _prefs.remove('chat_draft_$chatRoomId');
  }

  // ==================== MESSAGE CACHE ====================

  Future<void> cacheMessages(
      String chatRoomId, List<Map<String, dynamic>> messages) async {
    await _prefs.setString('cache_messages_$chatRoomId', jsonEncode(messages));
  }

  List<Map<String, dynamic>>? getCachedMessages(String chatRoomId) {
    final cached = _prefs.getString('cache_messages_$chatRoomId');
    if (cached != null) {
      return (jsonDecode(cached) as List).cast<Map<String, dynamic>>();
    }
    return null;
  }

  // ==================== AI HISTORY ====================

  Future<void> saveAiHistory(
      String userId, List<Map<String, dynamic>> history) async {
    await _prefs.setString('ai_history_$userId', jsonEncode(history));
  }

  List<Map<String, dynamic>>? getAiHistory(String userId) {
    final cached = _prefs.getString('ai_history_$userId');
    if (cached != null) {
      return (jsonDecode(cached) as List).cast<Map<String, dynamic>>();
    }
    return null;
  }

  Future<void> clearAiHistory(String userId) async {
    await _prefs.remove('ai_history_$userId');
  }

  // ==================== RECENT SEARCHES ====================

  Future<void> saveRecentSearch(String query) async {
    final searches = getRecentSearches();
    if (!searches.contains(query)) {
      searches.insert(0, query);
      if (searches.length > 10) {
        searches.removeLast();
      }
      await _prefs.setStringList('recent_searches', searches);
    }
  }

  List<String> getRecentSearches() {
    return _prefs.getStringList('recent_searches') ?? [];
  }

  Future<void> clearRecentSearches() async {
    await _prefs.remove('recent_searches');
  }

  // ==================== DOCTOR CODE ====================

  Future<void> saveDoctorCode(String code) async {
    await _prefs.setString('doctor_code', code);
  }

  String? getDoctorCode() {
    return _prefs.getString('doctor_code');
  }

  Future<void> clearDoctorCode() async {
    await _prefs.remove('doctor_code');
  }

  // ==================== FIRST TIME FLAGS ====================

  Future<void> setFirstTimeFlag(String key, bool value) async {
    await _prefs.setBool('first_time_$key', value);
  }

  bool getFirstTimeFlag(String key) {
    return _prefs.getBool('first_time_$key') ?? true;
  }

  // ==================== CLEAR ALL ====================

  Future<void> clearAll() async {
    // Preserve essential app state that shouldn't be cleared on logout
    final onboardingCompleted = _prefs.getBool('onboarding_completed') ?? false;
    final themeMode = _prefs.getString('theme_mode');
    final language = _prefs.getString('language_code');

    await _prefs.clear();

    // Restore preserved state
    await _prefs.setBool('onboarding_completed', onboardingCompleted);
    if (themeMode != null) await _prefs.setString('theme_mode', themeMode);
    if (language != null) await _prefs.setString('language_code', language);
  }

  // ==================== GENERIC METHODS ====================

  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  String? getString(String key) {
    return _prefs.getString(key);
  }

  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  bool? getBool(String key) {
    return _prefs.getBool(key);
  }

  Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  int? getInt(String key) {
    return _prefs.getInt(key);
  }

  Future<void> setDouble(String key, double value) async {
    await _prefs.setDouble(key, value);
  }

  double? getDouble(String key) {
    return _prefs.getDouble(key);
  }

  Future<void> setStringList(String key, List<String> value) async {
    await _prefs.setStringList(key, value);
  }

  List<String>? getStringList(String key) {
    return _prefs.getStringList(key);
  }

  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  bool containsKey(String key) {
    return _prefs.containsKey(key);
  }

  Set<String> getKeys() {
    return _prefs.getKeys();
  }
}
