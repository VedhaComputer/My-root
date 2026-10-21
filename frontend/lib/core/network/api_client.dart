import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../error/failures.dart';

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
  String? _accessToken;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  void setAccessToken(String? token) => _accessToken = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<ApiResponse<Map<String, dynamic>>> get(String path) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$path');
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(AppConstants.connectionTimeout);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse.failure(NetworkFailure(message: e.toString()));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> post(
      String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$path');
      final response = await _client
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(AppConstants.connectionTimeout);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse.failure(NetworkFailure(message: e.toString()));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> put(
      String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$path');
      final response = await _client
          .put(uri, headers: _headers, body: jsonEncode(body))
          .timeout(AppConstants.connectionTimeout);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse.failure(NetworkFailure(message: e.toString()));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> patch(
      String path, [Map<String, dynamic>? body]) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$path');
      final response = await _client
          .patch(uri, headers: _headers, body: body != null ? jsonEncode(body) : null)
          .timeout(AppConstants.connectionTimeout);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse.failure(NetworkFailure(message: e.toString()));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> delete(String path) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$path');
      final response = await _client
          .delete(uri, headers: _headers)
          .timeout(AppConstants.connectionTimeout);
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
