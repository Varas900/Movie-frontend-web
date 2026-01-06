import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

class StorageService {
	static SharedPreferences? _prefs;
	static const String _kUserToken = 'auth.userToken';
	static const String _kPermissions = 'auth.permissions';
	static const String _kLanguage = 'app.languageCode';
	static const String _kThemeMode = 'app.themeMode';
	static const String _kVideoQuality = 'player.videoQuality';
	static const String _kAutoPlay = 'player.autoPlay';
	static const String _kSubtitlesEnabled = 'player.subtitlesEnabled';

	static dynamic _userJson;
	static String? _userToken;
	static Set<String> _permissions = <String>{};

	static List<int> _favorites = <int>[];
	static List<int> _recentViews = <int>[];
	static List<int> _watchlist = <int>[];

	static Future<void> init() async {
		_prefs ??= await SharedPreferences.getInstance();
		_userToken = _prefs!.getString(_kUserToken);
		final perms = _prefs!.getStringList(_kPermissions);
		if (perms != null) {
			_permissions = perms
					.map((e) => e.trim())
					.where((e) => e.isNotEmpty)
					.toSet();
		}
	}

	static String getLanguage() {
		final code = _prefs?.getString(_kLanguage);
		return (code == null || code.isEmpty) ? 'en' : code;
	}

	static void saveLanguage(String languageCode) {
		_prefs?.setString(_kLanguage, languageCode);
	}

	static String? getThemeMode() {
		final mode = _prefs?.getString(_kThemeMode);
		return (mode == null || mode.isEmpty) ? null : mode;
	}

	static void saveThemeMode(String themeMode) {
		_prefs?.setString(_kThemeMode, themeMode);
	}

	static double getWatchProgress(int movieId) {
		final v = _prefs?.getDouble('player.watchProgress.$movieId');
		return v ?? 0.0;
	}

	static Future<void> saveWatchProgress(int movieId, double progress) async {
		final prefs = _prefs ?? await SharedPreferences.getInstance();
		_prefs = prefs;
		await prefs.setDouble('player.watchProgress.$movieId', progress);
	}

	static Future<void> markAsWatched(int movieId) async {
		final prefs = _prefs ?? await SharedPreferences.getInstance();
		_prefs = prefs;
		await prefs.setBool('player.watched.$movieId', true);
	}

	static String getVideoQuality() {
		final q = _prefs?.getString(_kVideoQuality);
		return (q == null || q.isEmpty) ? 'auto' : q;
	}

	static bool getAutoPlay() {
		return _prefs?.getBool(_kAutoPlay) ?? true;
	}

	static bool getSubtitlesEnabled() {
		return _prefs?.getBool(_kSubtitlesEnabled) ?? true;
	}

	static Future<void> saveVideoQuality(String quality) async {
		final prefs = _prefs ?? await SharedPreferences.getInstance();
		_prefs = prefs;
		await prefs.setString(_kVideoQuality, quality);
	}

	static Future<void> saveAutoPlay(bool autoPlay) async {
		final prefs = _prefs ?? await SharedPreferences.getInstance();
		_prefs = prefs;
		await prefs.setBool(_kAutoPlay, autoPlay);
	}

	static Future<void> saveSubtitlesEnabled(bool enabled) async {
		final prefs = _prefs ?? await SharedPreferences.getInstance();
		_prefs = prefs;
		await prefs.setBool(_kSubtitlesEnabled, enabled);
	}

	// Minimal storage for auth. Token is persisted; userJson remains in-memory.
	static void saveUserToken(String token) {
		_userToken = token;
		_prefs?.setString(_kUserToken, token);
	}

	static String? getUserToken() => _userToken;

	static void saveUser(dynamic userJson) {
		_userJson = userJson;
	}

	static dynamic getUser() => _userJson;

	static void savePermissions(Iterable<String> permissions) {
		_permissions = permissions
				.map((e) => e.trim())
				.where((e) => e.isNotEmpty)
				.toSet();
		_prefs?.setStringList(_kPermissions, _permissions.toList(growable: false));
	}

	static Set<String> getPermissions() => _permissions;

	static Future<void> clearUser() async {
		_userJson = null;
		_userToken = null;
		_permissions = <String>{};
		final prefs = _prefs ?? await SharedPreferences.getInstance();
		_prefs = prefs;
		await prefs.remove(_kUserToken);
		await prefs.remove(_kPermissions);
	}

	Future<List<int>> getFavorites() async => List<int>.from(_favorites);

	Future<void> saveFavorites(List<int> favorites) async {
		_favorites = List<int>.from(favorites);
	}

	Future<List<int>> getRecentViews() async => List<int>.from(_recentViews);

	Future<void> saveRecentViews(List<int> recentViews) async {
		_recentViews = List<int>.from(recentViews);
	}

	Future<List<int>> getWatchlist() async => List<int>.from(_watchlist);

	Future<void> saveWatchlist(List<int> watchlist) async {
		_watchlist = List<int>.from(watchlist);
	}
}
