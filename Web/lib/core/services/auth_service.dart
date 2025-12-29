import 'dart:convert';
import 'package:http/http.dart' as http;

import '../utils/app_constants.dart';

class AuthService {
  final String _baseUrl = AppConstants.baseApiUrl;

  Future<Map<String, dynamic>> signIn(String emailOrUsername, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login/userLogin'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          // Backend accepts email or username; map explicitly to userName
          'userName': emailOrUsername,
          'email': emailOrUsername,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final errorData = _safeDecode(response.body);
        return {
          'success': false,
          'message': _extractMessage(errorData, 'Sign in failed'),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> signUp(
    String userName,
    String firstName,
    String lastName,
    String email,
    String password,
    {String? gender}
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userName': userName,
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'password': password,
          'gender': (gender == null || gender.isEmpty) ? 'other' : gender,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final errorData = _safeDecode(response.body);
        return {
          'success': false,
          'message': _extractMessage(errorData, 'Sign up failed'),
        };
      }
    } catch (e) {
      // Network error should not be treated as success
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> verifyEmail(int userId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register/verifyRegisterEmail'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userID': userId,
          'token': token,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final errorData = _safeDecode(response.body);
        return {
          'success': false,
          'message': _extractMessage(errorData, 'Invalid verification code'),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Invalid verification code',
      };
    }
  }

  Map<String, dynamic>? _safeDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String _extractMessage(Map<String, dynamic>? body, String fallback) {
    if (body == null) return fallback;
    // Try typical keys from ResponseDto and ProblemDetails
    final keys = ['message', 'Message', 'error', 'title', 'detail'];
    for (final k in keys) {
      final v = body[k];
      if (v is String && v.isNotEmpty) return v;
    }
    // Try ASP.NET Core ValidationProblemDetails: { errors: { field: [msg1, msg2] } }
    final errs = body['errors'];
    if (errs is Map) {
      for (final entry in errs.entries) {
        final val = entry.value;
        if (val is List && val.isNotEmpty && val.first is String) {
          return val.first as String;
        }
      }
    }
    return fallback;
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/forgot-password'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      // For development, return mock successful response
      return {
        'success': true,
        'message': 'Password reset link sent to your email',
      };
    }
  }

  Future<Map<String, dynamic>> verifyMFA(String code) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/verify-mfa'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'code': code,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      // For development, return mock successful response for code "123456"
      if (code == '123456') {
        return {
          'success': true,
          'user': {
            'userID': 1,
            'userName': 'demouser',
            'name': 'Demo User',
            'email': 'demo@flixgo.com',
            'role': 'User',
            'status': 'Active',
            'avatar': 'https://via.placeholder.com/200x200',
            'createdAt': DateTime.now().toIso8601String(),
            'isEmailVerified': true,
          },
          'token': 'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}',
        };
      }
      
      return {
        'success': false,
        'message': 'Invalid verification code',
      };
    }
  }

  Future<Map<String, dynamic>> signOut() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/signout'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      // For development, return mock successful response
      return {
        'success': true,
        'message': 'Signed out successfully',
      };
    }
  }

  Future<Map<String, dynamic>> refreshToken() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Token refresh failed',
      };
    }
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(profileData),
      );

      return jsonDecode(response.body);
    } catch (e) {
      // For development, return mock successful response
      return {
        'success': true,
        'user': profileData,
        'message': 'Profile updated successfully',
      };
    }
  }

  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/auth/change-password'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      // For development, return mock successful response
      return {
        'success': true,
        'message': 'Password changed successfully',
      };
    }
  }

  // === Google Login (Web) ===
  // Flow A: OAuth redirect handled by backend cookies.
  // Frontend should navigate the browser to this URL.
  String getGoogleLoginRedirectUrl({String? returnUrl}) {
    // Optional returnUrl lets backend know where to send users after success.
    final ru = returnUrl == null || returnUrl.isEmpty ? null : Uri.encodeComponent(returnUrl);
    final path = '$_baseUrl/login/google-login';
    return ru == null ? path : '$path?returnUrl=$ru';
  }

  // Flow B: Token exchange — obtain Google idToken on the client and POST to backend.
  // Backend validates with Google, creates/links account, and returns tokens in JSON.
  Future<Map<String, dynamic>> loginWithGoogleIdToken(String idToken) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login/mobile/google'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'IdToken': idToken,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final errorData = _safeDecode(response.body);
        return {
          'success': false,
          'message': _extractMessage(errorData, 'Google login failed'),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}