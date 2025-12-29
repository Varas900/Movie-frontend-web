class StorageService {
	static dynamic _userJson;
	static String? _userToken;

	// Minimal in-memory storage for auth — replace with SharedPreferences for persistence
	static void saveUserToken(String token) {
		_userToken = token;
	}

	static String? getUserToken() => _userToken;

	static void saveUser(dynamic userJson) {
		_userJson = userJson;
	}

	static dynamic getUser() => _userJson;

	static Future<void> clearUser() async {
		_userJson = null;
		_userToken = null;
	}
}
