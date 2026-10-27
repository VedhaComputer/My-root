import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../constants.dart';
import '../error/failures.dart';
import '../../services/secure_token_storage.dart';

class ApiResponse<T> {
  final T? data;
  final Failure? failure;
  final bool isSuccess;

  const ApiResponse.success(this.data)
      : failure = null,
        isSuccess = true;
  const ApiResponse.failure(this.failure)
      : data = null,
        isSuccess = false;
}

class ApiClient {
  final http.Client _client;
  final SecureTokenStorage? _tokenStorage;
  String? _accessToken;

  ApiClient({
    http.Client? client,
    SecureTokenStorage? tokenStorage,
    String? accessToken,
  })  : _client = client ?? http.Client(),
        _tokenStorage = tokenStorage ?? SecureTokenStorage(),
        _accessToken = accessToken;

  void setAccessToken(String? token) => _accessToken = token;
  String? get accessToken => _accessToken;

  Future<Map<String, String>> _resolveHeaders() async {
    final storage = _tokenStorage;
    if ((_accessToken == null || _accessToken!.isEmpty) && storage != null) {
      try {
        final session = await storage.loadSession();
        if (session.accessToken != null && session.accessToken!.isNotEmpty) {
          _accessToken = session.accessToken;
        }
      } catch (e) {
        debugPrint('[ApiClient] Failed to auto-restore token from storage: $e');
      }
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (_accessToken != null && _accessToken!.isNotEmpty)
        'Authorization': 'Bearer $_accessToken',
    };
  }

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_accessToken != null && _accessToken!.isNotEmpty)
          'Authorization': 'Bearer $_accessToken',
      };

  /// Resolves the request URI ensuring canonical `/api/v1` routing without double-prefixing.
  static Uri resolveUri(String baseUrl, String path) {
    var base = baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    var p = path.trim();
    if (!p.startsWith('/')) {
      p = '/$p';
    }

    final baseUri = Uri.parse(base);
    final basePath = baseUri.path;
    final baseEndsWithV1 = basePath.endsWith('/api/v1') || basePath == '/api/v1';

    // Root-level endpoints (like /health) always route to the server root, stripping any /api/v1 from base
    if (p == '/health' || p.startsWith('/health/') || p.startsWith('/health?')) {
      final rootBase = baseEndsWithV1 ? base.substring(0, base.length - 7) : base;
      return Uri.parse('$rootBase$p');
    }

    final pathStartsWithV1 = p.startsWith('/api/v1/') || p == '/api/v1' || p.startsWith('/api/v1?');

    if (baseEndsWithV1 && pathStartsWithV1) {
      // Both base and path contain /api/v1 -> remove /api/v1 from path to avoid double prefixing
      final afterV1 = p.substring(7); // starts with '', '/', or '?'
      final cleanPath = afterV1.isEmpty
          ? ''
          : (afterV1.startsWith('/') || afterV1.startsWith('?') ? afterV1 : '/$afterV1');
      return Uri.parse('$base$cleanPath');
    } else if (!baseEndsWithV1 && !pathStartsWithV1) {
      // Neither has /api/v1 -> route to canonical /api/v1
      return Uri.parse('$base/api/v1$p');
    } else {
      // Exactly one already has /api/v1 -> simple concatenation
      return Uri.parse('$base$p');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> get(String path) async {
    try {
      final uri = resolveUri(AppConstants.baseUrl, path);
      final headers = await _resolveHeaders();
      final response = await _client
          .get(uri, headers: headers)
          .timeout(AppConstants.connectionTimeout);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse.failure(NetworkFailure(message: e.toString()));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> post(
      String path, Map<String, dynamic> body) async {
    try {
      final uri = resolveUri(AppConstants.baseUrl, path);
      final headers = await _resolveHeaders();
      final response = await _client
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(AppConstants.connectionTimeout);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse.failure(NetworkFailure(message: e.toString()));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> put(
      String path, Map<String, dynamic> body) async {
    try {
      final uri = resolveUri(AppConstants.baseUrl, path);
      final headers = await _resolveHeaders();
      final response = await _client
          .put(uri, headers: headers, body: jsonEncode(body))
          .timeout(AppConstants.connectionTimeout);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse.failure(NetworkFailure(message: e.toString()));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> patch(
      String path, [Map<String, dynamic>? body]) async {
    try {
      final uri = resolveUri(AppConstants.baseUrl, path);
      final headers = await _resolveHeaders();
      final response = await _client
          .patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(AppConstants.connectionTimeout);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse.failure(NetworkFailure(message: e.toString()));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> delete(String path) async {
    try {
      final uri = resolveUri(AppConstants.baseUrl, path);
      final headers = await _resolveHeaders();
      final response = await _client
          .delete(uri, headers: headers)
          .timeout(AppConstants.connectionTimeout);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse.failure(NetworkFailure(message: e.toString()));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> uploadMultipart({
    required String path,
    required String fieldName,
    required List<int> fileBytes,
    required String filename,
    String? mimeType,
    Map<String, String>? extraFields,
  }) async {
    try {
      final uri = resolveUri(AppConstants.baseUrl, path);
      final headers = await _resolveHeaders();
      final request = http.MultipartRequest('POST', uri);

      if (headers.containsKey('Authorization')) {
        request.headers['Authorization'] = headers['Authorization']!;
      }
      request.headers['Accept'] = 'application/json';

      if (extraFields != null) {
        request.fields.addAll(extraFields);
      }

      MediaType? contentType;
      if (mimeType != null && mimeType.contains('/')) {
        final parts = mimeType.split('/');
        contentType = MediaType(parts[0], parts[1]);
      }

      request.files.add(http.MultipartFile.fromBytes(
        fieldName,
        fileBytes,
        filename: filename,
        contentType: contentType,
      ));

      final streamedResponse = await _client
          .send(request)
          .timeout(AppConstants.connectionTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse.failure(NetworkFailure(message: e.toString()));
    }
  }

  ApiResponse<Map<String, dynamic>> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponse.success(body);
    }
    final error = body['error'] as Map<String, dynamic>? ?? {};
    final code = error['code'] as String? ?? 'UNKNOWN';
    final message = error['message'] as String? ?? 'Unknown error';
    return switch (response.statusCode) {
      401 => ApiResponse.failure(AuthFailure(message: message, code: code)),
      403 => ApiResponse.failure(AuthFailure(message: message, code: code)),
      404 => ApiResponse.failure(NotFoundFailure(message: message)),
      409 => ApiResponse.failure(ConflictFailure(message: message, code: code)),
      422 => ApiResponse.failure(BusinessRuleFailure(message: message)),
      _ => ApiResponse.failure(ServerFailure(message: message, code: code)),
    };
  }
}
