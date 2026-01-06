import 'package:flutter_riverpod/flutter_riverpod.dart';

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

class StorageService {
	static dynamic _userJson;
	static String? _userToken;
	static Set<String> _permissions = <String>{};

	static List<int> _favorites = <int>[];
	static List<int> _recentViews = <int>[];
	static List<int> _watchlist = <int>[];

	// Minimal in-memory storage for auth — replace with SharedPreferences for persistence
	static void saveUserToken(String token) {
		_userToken = token;
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
	}

	static Set<String> getPermissions() => _permissions;

	static Future<void> clearUser() async {
		_userJson = null;
		_userToken = null;
		_permissions = <String>{};
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
