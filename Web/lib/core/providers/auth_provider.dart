import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';

// Authentication State
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    required this.isAuthenticated,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authService) : super(const AuthState(isAuthenticated: false)) {
    _initializeAuth();
  }

  final AuthService _authService;

  Future<void> _initializeAuth() async {
    final user = StorageService.getUser();
    final token = StorageService.getUserToken();
    
    if (user != null && token != null) {
      state = AuthState(user: user, isAuthenticated: true);
    }
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await _authService.signIn(email, password);
      if (result['success'] == true) {
        final res = result['data'];
        final dynamic inner = res is Map<String, dynamic>
            ? (res['data'] ?? res['Data'] ?? res)
            : res;
        if (inner is! Map<String, dynamic>) {
          state = state.copyWith(isLoading: false, error: 'Invalid login response');
          return false;
        }
        final token = inner['token'] as String?;
        final userMap = {
          'userID': inner['userID'],
          'userName': inner['userName'],
          'email': inner['email'],
          'isEmailVerified': inner['isEmailVerified'],
          'role': 'User',
          'status': 'Active',
          'name': inner['userName'] ?? '',
          'createdAt': DateTime.now().toIso8601String(),
        };
        final user = User.fromJson(userMap);

        StorageService.saveUser(user);
        if (token != null) StorageService.saveUserToken(token);
        
        state = AuthState(user: user, isAuthenticated: true);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result['message'] ?? 'Sign in failed',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<int?> signUp(String userName, String firstName, String lastName, String email, String password, {String? gender}) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await _authService.signUp(userName, firstName, lastName, email, password, gender: gender);
      state = state.copyWith(isLoading: false);
      if (result['success'] == true) {
        final res = result['data'];
        // Try to pick RegisterResponse.userID from typical shapes: { data: { data: { userID } } } or { Data: { userID } }
        final dynamic inner = res is Map<String, dynamic>
            ? (res['data'] ?? res['Data'] ?? res)
            : res;
        final userId = (inner is Map<String, dynamic>) ? inner['userID'] as int? : null;
        return userId;
      }
      state = state.copyWith(error: result['message'] ?? 'Sign up failed');
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  Future<bool> verifyEmail(int userId, String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _authService.verifyEmail(userId, code);
      state = state.copyWith(isLoading: false);
      if (result['success'] == true) {
        // After email verification, user should sign in manually
        return true;
      }
      state = state.copyWith(error: result['message'] ?? 'Email verification failed');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await _authService.forgotPassword(email);
      state = state.copyWith(isLoading: false);
      return result['success'] == true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> verifyMFA(String code) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await _authService.verifyMFA(code);
      if (result['success'] == true) {
        final user = User.fromJson(result['user']);
        final token = result['token'] as String;
        
        await StorageService.saveUser(user);
        await StorageService.saveUserToken(token);
        
        state = AuthState(user: user, isAuthenticated: true);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result['message'] ?? 'MFA verification failed',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    
    try {
      await _authService.signOut();
      await StorageService.clearUser();
      state = const AuthState(isAuthenticated: false);
    } catch (e) {
      // Even if server sign out fails, clear local data
      await StorageService.clearUser();
      state = const AuthState(isAuthenticated: false);
    }
  }

  void updateUser(User user) {
    if (state.isAuthenticated) {
      state = state.copyWith(user: user);
      StorageService.saveUser(user);
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  // Authenticate using user JSON fetched via cookie-based flow (web OAuth)
  void authenticateFromUserJson(Map<String, dynamic> inner) {
    final user = User.fromJson({
      'userID': inner['userID'] ?? inner['UserID'] ?? inner['id'],
      'userName': inner['userName'] ?? inner['UserName'] ?? inner['name'],
      'email': inner['email'] ?? inner['Email'],
      'name': inner['name'] ?? inner['FullName'] ?? (inner['userName'] ?? ''),
      'role': inner['role'] ?? 'User',
      'status': inner['status'] ?? 'Active',
      'createdAt': inner['createdAt'] ?? DateTime.now().toIso8601String(),
      'isEmailVerified': inner['isEmailVerified'] ?? true,
      'avatar': inner['avatar'] ?? inner['Avatar'],
    });
    StorageService.saveUser(user);
    state = AuthState(user: user, isAuthenticated: true);
  }
}

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Auth State Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.read(authServiceProvider);
  return AuthNotifier(authService);
});

// Helper providers
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final isLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoading;
});

final authErrorProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).error;
});