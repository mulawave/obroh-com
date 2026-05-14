import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'fcm_service.dart';

class AuthService extends ChangeNotifier {
  User? _user;
  String? _token;
  bool _loading = true;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  User? get user => _user;
  String? get token => _token;
  bool get loading => _loading;
  bool get isAuthenticated => _token != null && _user != null;

  Future<void> init() async {
    _token = await _storage.read(key: 'auth_token');
    if (_token != null) {
      try {
        await refreshUser();
        // Register FCM token for existing session
        await FcmService.handleCurrentToken();
        await FcmService.setupTokenRefreshCallback();
      } catch (_) {
        await logout();
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final res = await ApiService.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    _token = res['token'] as String;
    _user = User.fromJson(res['user'] as Map<String, dynamic>);
    await _storage.write(key: 'auth_token', value: _token);
    // Register FCM token
    await FcmService.handleCurrentToken();
    await FcmService.setupTokenRefreshCallback();
    notifyListeners();
  }

  Future<String> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
    String? location,
  }) async {
    final res = await ApiService.post('/auth/register', body: {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (location != null && location.isNotEmpty) 'location': location,
    });
    return res['message'] as String? ?? 'Registration successful';
  }

  Future<void> refreshUser() async {
    final res = await ApiService.get('/auth/me', token: _token);
    _user = User.fromJson(res['user'] as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> logout() async {
    // Unregister FCM token
    final token = await FcmService.getCurrentToken();
    if (token != null) {
      await FcmService.unregisterToken(token);
    }
    _token = null;
    _user = null;
    await _storage.delete(key: 'auth_token');
    notifyListeners();
  }
}
