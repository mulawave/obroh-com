import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}

class ApiService {
  static String get _baseUrl {
    if (Platform.isIOS) return AppConfig.apiBaseUrlIos;
    return AppConfig.apiBaseUrl;
  }

  static Future<Map<String, dynamic>> get(
    String endpoint, {
    String? token,
  }) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl$endpoint'), headers: _headers(token))
          .timeout(AppConfig.httpTimeout);
      return _handleResponse(res);
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Check your connection and retry.',
        408,
      );
    } on SocketException {
      throw ApiException(
        'No internet connection. Please reconnect and retry.',
        0,
      );
    }
  }

  static Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl$endpoint'),
            headers: _headers(token),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConfig.httpTimeout);
      return _handleResponse(res);
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Check your connection and retry.',
        408,
      );
    } on SocketException {
      throw ApiException(
        'No internet connection. Please reconnect and retry.',
        0,
      );
    }
  }

  static Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$_baseUrl$endpoint'),
            headers: _headers(token),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConfig.httpTimeout);
      return _handleResponse(res);
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Check your connection and retry.',
        408,
      );
    } on SocketException {
      throw ApiException(
        'No internet connection. Please reconnect and retry.',
        0,
      );
    }
  }

  static Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_baseUrl$endpoint'),
            headers: _headers(token),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConfig.httpTimeout);
      return _handleResponse(res);
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Check your connection and retry.',
        408,
      );
    } on SocketException {
      throw ApiException(
        'No internet connection. Please reconnect and retry.',
        0,
      );
    }
  }

  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    String? token,
  }) async {
    try {
      final res = await http
          .delete(Uri.parse('$_baseUrl$endpoint'), headers: _headers(token))
          .timeout(AppConfig.httpTimeout);
      return _handleResponse(res);
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Check your connection and retry.',
        408,
      );
    } on SocketException {
      throw ApiException(
        'No internet connection. Please reconnect and retry.',
        0,
      );
    }
  }

  static Future<Map<String, dynamic>> multipartPost(
    String endpoint, {
    required Map<String, String> fields,
    required String fileField,
    required String filePath,
    String? token,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl$endpoint'),
    );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);
    request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
    try {
      final streamedRes = await request.send().timeout(AppConfig.httpTimeout);
      final res = await http.Response.fromStream(streamedRes);
      return _handleResponse(res);
    } on TimeoutException {
      throw ApiException(
        'Upload timed out. Check your connection and retry.',
        408,
      );
    } on SocketException {
      throw ApiException(
        'No internet connection. Please reconnect and retry.',
        0,
      );
    }
  }

  /// Upload multiple files to the same field name (e.g. media[] for timeline posts).
  static Future<Map<String, dynamic>> multipartPostFiles(
    String endpoint, {
    required Map<String, String> fields,
    required String fileField,
    required List<String> filePaths,
    String? token,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl$endpoint'),
    );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);
    for (final path in filePaths) {
      request.files.add(await http.MultipartFile.fromPath(fileField, path));
    }
    try {
      final streamedRes = await request.send().timeout(AppConfig.httpTimeout);
      final res = await http.Response.fromStream(streamedRes);
      return _handleResponse(res);
    } on TimeoutException {
      throw ApiException(
        'Upload timed out. Check your connection and retry.',
        408,
      );
    } on SocketException {
      throw ApiException(
        'No internet connection. Please reconnect and retry.',
        0,
      );
    }
  }

  static Map<String, String> _headers(String? token) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  static Map<String, dynamic> _handleResponse(http.Response res) {
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      } else if (decoded is List) {
        data = {'data': decoded};
      } else {
        data = {'message': 'Unexpected response format'};
      }
    } catch (_) {
      if (res.statusCode == 401 || res.statusCode == 403) {
        throw ApiException(
          'Session expired or access denied. Please sign in again.',
          res.statusCode,
        );
      }
      final fallbackMessage = res.statusCode >= 500
          ? 'Server returned an invalid response'
          : 'Request failed with an invalid response';
      throw ApiException(fallbackMessage, res.statusCode);
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw ApiException(
        data['error']?.toString() ??
            'Session expired or access denied. Please sign in again.',
        res.statusCode,
      );
    }
    final rawMessage =
        data['error']?.toString() ??
        data['message']?.toString() ??
        'Something went wrong';
    final normalizedMessage = rawMessage.trim().toLowerCase();
    final isGenericServerError =
        res.statusCode >= 500 &&
        (normalizedMessage == 'internal server error' ||
            normalizedMessage == 'something went wrong');

    throw ApiException(
      isGenericServerError
          ? 'The server could not process this request right now. Please try again shortly.'
          : rawMessage,
      res.statusCode,
    );
  }

  /// Build a full image URL from a relative path (e.g. /uploads/...)
  static String imageUrl(String? path) {
    if (path == null) return '';

    final trimmed = _normalizeExternalUrl(path.trim());
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    var normalized = trimmed;
    if (normalized.startsWith('/api/uploads/')) {
      normalized = normalized.substring(4);
    } else if (normalized.startsWith('api/uploads/')) {
      normalized = '/${normalized.substring(4)}';
    } else if (normalized.startsWith('uploads/')) {
      normalized = '/$normalized';
    } else if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }

    return Uri.parse(
      '${AppConfig.uploadsBaseUrl}/',
    ).resolve(normalized.replaceFirst(RegExp(r'^/+'), '')).toString();
  }

  static String _normalizeExternalUrl(String value) {
    if (value.startsWith('https://') || value.startsWith('http://')) {
      return value;
    }

    if (value.startsWith('https:/') && !value.startsWith('https://')) {
      final hostAndPath = value
          .substring('https:/'.length)
          .replaceFirst(RegExp(r'^/+'), '');
      return 'https://$hostAndPath';
    }

    if (value.startsWith('http:/') && !value.startsWith('http://')) {
      final hostAndPath = value
          .substring('http:/'.length)
          .replaceFirst(RegExp(r'^/+'), '');
      return 'http://$hostAndPath';
    }

    if (value.startsWith('//')) {
      return 'https:$value';
    }

    return value;
  }
}
