import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

class StorageService {
	static SharedPreferences? _prefs;
	static const String _kUserToken = 'auth.userToken';
	static const String _kPermissions = 'auth.permissions';

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
