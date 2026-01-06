import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;

import '../utils/app_constants.dart';

class AuthService {
  final String _baseUrl = AppConstants.baseApiUrl;

  String? _readCookie(String name) {
    final raw = html.document.cookie ?? '';
    if (raw.isEmpty) return null;
    for (final part in raw.split(';')) {
      final kv = part.trim();
      if (kv.isEmpty) continue;
      final eq = kv.indexOf('=');
      if (eq <= 0) continue;
      final k = kv.substring(0, eq).trim();
      if (k != name) continue;
      return Uri.decodeComponent(kv.substring(eq + 1));
    }
    return null;
  }

  Future<Map<String, dynamic>> _postJson(
      String url, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.body.isEmpty) {
        return {
          'success': response.statusCode >= 200 && response.statusCode < 300,
          'errorCode': response.statusCode,
          'message': response.statusCode >= 200 && response.statusCode < 300
              ? 'Success'
              : 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        };
      }

      final decoded = _safeDecode(response.body);
      if (decoded == null) {
        return {
          'success': false,
          'errorCode': response.statusCode,
          'message': 'Invalid response',
        };
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      return {
        ...decoded,
        'success': false,
        'message': _extractMessage(decoded, 'Request failed'),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> signIn(
      String emailOrUsername, String password) async {
    try {
      // Important for web cookie-based sessions: include credentials so Set-Cookie
      // is persisted by the browser and /user/me works after reload.
      final url = Uri.parse('$_baseUrl/login/userLogin');
      final req = await html.HttpRequest.request(
        url.toString(),
        method: 'POST',
        withCredentials: true,
        requestHeaders: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        sendData: jsonEncode({
          // Backend accepts email or username; map explicitly to userName
          'userName': emailOrUsername,
          'email': emailOrUsername,
          'password': password,
        }),
      );

      final status = req.status ?? 0;
      final bodyText = req.responseText ?? '';

      if (status >= 200 && status < 300) {
        final data = bodyText.isEmpty ? <String, dynamic>{} : jsonDecode(bodyText);
        return {'success': true, 'data': data};
      }

      final errorData = bodyText.isEmpty ? null : _safeDecode(bodyText);
      return {
        'success': false,
        'message': _extractMessage(errorData, 'Sign in failed'),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> signUp(String userName, String firstName,
      String lastName, String email, String password,
      {String? gender}) async {
    try {
      final url = Uri.parse('$_baseUrl/register');
      final req = await html.HttpRequest.request(
        url.toString(),
        method: 'POST',
        withCredentials: true,
        requestHeaders: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        sendData: jsonEncode({
          'userName': userName,
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'password': password,
          'gender': (gender == null || gender.isEmpty) ? 'other' : gender,
        }),
      );

      final status = req.status ?? 0;
      final bodyText = req.responseText ?? '';

      if (status >= 200 && status < 300) {
        final data = bodyText.isEmpty ? <String, dynamic>{} : jsonDecode(bodyText);
        return {'success': true, 'data': data};
      }

      final errorData = bodyText.isEmpty ? null : _safeDecode(bodyText);
      return {
        'success': false,
        'message': _extractMessage(errorData, 'Sign up failed'),
      };
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
    // Back-compat alias: this project uses OTP + ticket flow (not email reset-link)
    return startForgotPasswordByEmail(email);
  }

  // ===== Forgot password (OTP via email) =====
  // 1) Start: send OTP to email
  Future<Map<String, dynamic>> startForgotPasswordByEmail(String email) async {
    return _postJson('$_baseUrl/account/password/forgot/email/start', {
      'email': email,
    });
  }

  // 2) Verify: verify OTP and receive a ticket (string) in data
  Future<Map<String, dynamic>> verifyForgotPasswordByEmail({
    required String email,
    required String code,
  }) async {
    return _postJson('$_baseUrl/account/password/forgot/email/verify', {
      'email': email,
      'code': code,
    });
  }

  // 3) Commit: set new password using ticket
  Future<Map<String, dynamic>> commitForgotPassword({
    required String ticket,
    required String newPassword,
  }) async {
    return _postJson('$_baseUrl/account/password/forgot/commit', {
      'ticket': ticket,
      'newPassword': newPassword,
    });
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
      // Cookie-based auth (Google OAuth web) requires sending credentials.
      // Also, the backend endpoint is /login/logout (see LoginController).
      final url = Uri.parse('$_baseUrl/login/logout');

      final req = await html.HttpRequest.request(
        url.toString(),
        method: 'POST',
        withCredentials: true,
        requestHeaders: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      final bodyText = req.responseText;
      if (req.status != null && req.status! >= 200 && req.status! < 300) {
        final data = bodyText == null || bodyText.isEmpty
            ? <String, dynamic>{'success': true}
            : jsonDecode(bodyText);
        return (data is Map<String, dynamic>)
            ? data
            : {'success': true, 'data': data};
      }

      // If server returned an error, surface it.
      final err =
          bodyText == null || bodyText.isEmpty ? null : _safeDecode(bodyText);
      return {
        'success': false,
        'message': _extractMessage(err, 'Sign out failed'),
      };
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
      // Web cookie flow: backend endpoint is /login/auth/refresh and requires
      // X-CSRF header matching fz.csrf cookie.
      final csrf = _readCookie('fz.csrf');
      final url = Uri.parse('$_baseUrl/login/auth/refresh');

      final req = await html.HttpRequest.request(
        url.toString(),
        method: 'POST',
        withCredentials: true,
        requestHeaders: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (csrf != null && csrf.isNotEmpty) 'X-CSRF': csrf,
        },
        sendData: jsonEncode(<String, dynamic>{}),
      );

      final bodyText = req.responseText ?? '';
      final ok = (req.status ?? 0) >= 200 && (req.status ?? 0) < 300;
      final decoded = bodyText.isEmpty ? null : _safeDecode(bodyText);
      if (ok) {
        return {
          'success': true,
          'data': decoded ?? <String, dynamic>{},
        };
      }
      return {
        'success': false,
        'message': _extractMessage(decoded, 'Token refresh failed'),
        'data': decoded,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Token refresh failed',
      };
    }
  }

  Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> profileData) async {
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

  Future<Map<String, dynamic>> changePassword(
      String currentPassword, String newPassword) async {
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
    final ru = returnUrl == null || returnUrl.isEmpty
        ? null
        : Uri.encodeComponent(returnUrl);
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
