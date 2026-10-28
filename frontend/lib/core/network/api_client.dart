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
  final String? Function()? _tokenProvider;
  final Future<bool> Function()? _onTokenExpired;

  ApiClient({
    http.Client? client,
    SecureTokenStorage? tokenStorage,
    String? accessToken,
    String? Function()? tokenProvider,
    Future<bool> Function()? onTokenExpired,
  })  : _client = client ?? http.Client(),
        _tokenStorage = tokenStorage ?? SecureTokenStorage(),
        _accessToken = accessToken,
        _tokenProvider = tokenProvider,
        _onTokenExpired = onTokenExpired;

  void setAccessToken(String? token) => _accessToken = token;
  String? get accessToken {
    final providedToken = _tokenProvider?.call();
    return (providedToken != null && providedToken.isNotEmpty)
        ? providedToken
        : _accessToken;
  }

  Future<void> _syncRefreshedToken() async {
    final fresh = _tokenProvider?.call();
    if (fresh != null && fresh.isNotEmpty) {
      _accessToken = fresh;
      return;
    }
    final storage = _tokenStorage;
    if (storage != null) {
      try {
        final session = await storage.loadSession();
        if (session.accessToken != null && session.accessToken!.isNotEmpty) {
          _accessToken = session.accessToken;
        }
      } catch (_) {}
    }
  }

  Future<Map<String, String>> _resolveHeaders() async {
    final providedToken = _tokenProvider?.call();
    String? token = (providedToken != null && providedToken.isNotEmpty)
        ? providedToken
        : _accessToken;
    final storage = _tokenStorage;
    if (_tokenProvider == null && (token == null || token.isEmpty) && storage != null) {
      try {
        final session = await storage.loadSession();
        if (session.accessToken != null && session.accessToken!.isNotEmpty) {
          token = session.accessToken;
          _accessToken = token;
        }
      } catch (e) {
        debugPrint('[ApiClient] Failed to auto-restore token from storage: $e');
      }
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  Map<String, String> get headers {
    final providedToken = _tokenProvider?.call();
    final token = (providedToken != null && providedToken.isNotEmpty)
        ? providedToken
        : _accessToken;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

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

  static bool _isRefreshEligible(String path, Map<String, String> headers) {
    if (!headers.containsKey('Authorization')) return false;
    final cleanPath = path.toLowerCase();
    if (cleanPath.contains('/auth/login') ||
        cleanPath.contains('/auth/refresh') ||
        cleanPath.contains('/auth/logout') ||
        cleanPath.contains('/auth/password-reset') ||
        cleanPath.contains('/auth/verify-email') ||
        cleanPath.contains('/auth/register')) {
      return false;
    }
    return true;
  }

  Future<ApiResponse<Map<String, dynamic>>> get(String path) async {
    try {
      final uri = resolveUri(AppConstants.baseUrl, path);
      final headers = await _resolveHeaders();
      final response = await _client
          .get(uri, headers: headers)
          .timeout(AppConstants.connectionTimeout);

      if (response.statusCode == 401 &&
          _onTokenExpired != null &&
          _isRefreshEligible(path, headers)) {
        bool refreshed = false;
        try {
          refreshed = await _onTokenExpired!();
        } catch (_) {
          refreshed = false;
        }
        if (refreshed) {
          await _syncRefreshedToken();
          final retryHeaders = await _resolveHeaders();
          final retryResponse = await _client
              .get(uri, headers: retryHeaders)
              .timeout(AppConstants.connectionTimeout);
          return _handleResponse(retryResponse);
        }
      }

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

      if (response.statusCode == 401 &&
          _onTokenExpired != null &&
          _isRefreshEligible(path, headers)) {
        bool refreshed = false;
        try {
          refreshed = await _onTokenExpired!();
        } catch (_) {
          refreshed = false;
        }
        if (refreshed) {
          await _syncRefreshedToken();
          final retryHeaders = await _resolveHeaders();
          final retryResponse = await _client
              .post(uri, headers: retryHeaders, body: jsonEncode(body))
              .timeout(AppConstants.connectionTimeout);
          return _handleResponse(retryResponse);
        }
      }

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

      if (response.statusCode == 401 &&
          _onTokenExpired != null &&
          _isRefreshEligible(path, headers)) {
        bool refreshed = false;
        try {
          refreshed = await _onTokenExpired!();
        } catch (_) {
          refreshed = false;
        }
        if (refreshed) {
          await _syncRefreshedToken();
          final retryHeaders = await _resolveHeaders();
          final retryResponse = await _client
              .put(uri, headers: retryHeaders, body: jsonEncode(body))
              .timeout(AppConstants.connectionTimeout);
          return _handleResponse(retryResponse);
        }
      }

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

      if (response.statusCode == 401 &&
          _onTokenExpired != null &&
          _isRefreshEligible(path, headers)) {
        bool refreshed = false;
        try {
          refreshed = await _onTokenExpired!();
        } catch (_) {
          refreshed = false;
        }
        if (refreshed) {
          await _syncRefreshedToken();
          final retryHeaders = await _resolveHeaders();
          final retryResponse = await _client
              .patch(uri, headers: retryHeaders, body: body != null ? jsonEncode(body) : null)
              .timeout(AppConstants.connectionTimeout);
          return _handleResponse(retryResponse);
        }
      }

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

      if (response.statusCode == 401 &&
          _onTokenExpired != null &&
          _isRefreshEligible(path, headers)) {
        bool refreshed = false;
        try {
          refreshed = await _onTokenExpired!();
        } catch (_) {
          refreshed = false;
        }
        if (refreshed) {
          await _syncRefreshedToken();
          final retryHeaders = await _resolveHeaders();
          final retryResponse = await _client
              .delete(uri, headers: retryHeaders)
              .timeout(AppConstants.connectionTimeout);
          return _handleResponse(retryResponse);
        }
      }

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

      if (response.statusCode == 401 &&
          _onTokenExpired != null &&
          _isRefreshEligible(path, headers)) {
        bool refreshed = false;
        try {
          refreshed = await _onTokenExpired!();
        } catch (_) {
          refreshed = false;
        }
        if (refreshed) {
          await _syncRefreshedToken();
          final retryHeaders = await _resolveHeaders();
          final retryRequest = http.MultipartRequest('POST', uri);
          if (retryHeaders.containsKey('Authorization')) {
            retryRequest.headers['Authorization'] = retryHeaders['Authorization']!;
          }
          retryRequest.headers['Accept'] = 'application/json';
          if (extraFields != null) {
            retryRequest.fields.addAll(extraFields);
          }
          retryRequest.files.add(http.MultipartFile.fromBytes(
            fieldName,
            fileBytes,
            filename: filename,
            contentType: contentType,
          ));
          final retryStreamedResponse = await _client
              .send(retryRequest)
              .timeout(AppConstants.connectionTimeout);
          final retryResponse = await http.Response.fromStream(retryStreamedResponse);
          return _handleResponse(retryResponse);
        }
      }

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
