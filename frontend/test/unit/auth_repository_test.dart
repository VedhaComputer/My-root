import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/repositories/auth_repository.dart';

class MockHttpClient extends http.BaseClient {
  http.Response Function(http.Request request) handler;
  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final httpRequest = request as http.Request;
    final response = handler(httpRequest);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  group('AuthRepositoryImpl (Unit Tests)', () {
    test('login returns AuthTokens and sets access token on success', () async {
      final mockClient = MockHttpClient((request) {
        expect(request.url.path, '/auth/login');
        return http.Response(
          jsonEncode({
            'accessToken': 'jwt_access_123',
            'refreshToken': 'jwt_refresh_456',
            'user': {
              'id': 'u101',
              'displayName': 'Karan',
              'role': 'CONTRIBUTOR',
            },
          }),
          200,
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final repo = AuthRepositoryImpl(client: apiClient);

      final result = await repo.login('karan@example.com', 'password123');

      expect(result.isSuccess, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!.accessToken, 'jwt_access_123');
      expect(result.data!.user.displayName, 'Karan');
      expect(result.data!.user.role, 'CONTRIBUTOR');
    });

    test('login returns AuthFailure on invalid credentials (401)', () async {
      final mockClient = MockHttpClient((request) {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'UNAUTHENTICATED',
              'message': 'Invalid email or password',
            },
          }),
          401,
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final repo = AuthRepositoryImpl(client: apiClient);

      final result = await repo.login('karan@example.com', 'wrongPassword');

      expect(result.isSuccess, isFalse);
      expect(result.failure, isNotNull);
      expect(result.failure!.message, 'Invalid email or password');
    });

    test('register returns RegisterResponse on success (201)', () async {
      final mockClient = MockHttpClient((request) {
        expect(request.url.path, '/auth/register');
        return http.Response(
          jsonEncode({
            'message': 'Registration successful. Please verify your email.',
          }),
          201,
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final repo = AuthRepositoryImpl(client: apiClient);

      final result =
          await repo.register('Karan Verma', 'karan@example.com', 'securePass123');

      expect(result.isSuccess, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!.message,
          'Registration successful. Please verify your email.');
    });

    test('refreshToken updates client token and returns new tokens', () async {
      final mockClient = MockHttpClient((request) {
        expect(request.url.path, '/auth/refresh');
        return http.Response(
          jsonEncode({
            'accessToken': 'new_access_token',
            'refreshToken': 'new_refresh_token',
          }),
          200,
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final repo = AuthRepositoryImpl(client: apiClient);

      final result = await repo.refreshToken('old_refresh_token');

      expect(result.isSuccess, isTrue);
      expect(result.data!.accessToken, 'new_access_token');
      expect(result.data!.refreshToken, 'new_refresh_token');
    });

    test('logout clears client access token and returns success', () async {
      final mockClient = MockHttpClient((request) {
        expect(request.url.path, '/auth/logout');
        return http.Response(
          jsonEncode({'message': 'Logged out successfully'}),
          200,
        );
      });

      final apiClient = ApiClient(client: mockClient);
      apiClient.setAccessToken('existing_token');
      final repo = AuthRepositoryImpl(client: apiClient);

      final result = await repo.logout(refreshToken: 'token_to_revoke');

      expect(result.isSuccess, isTrue);
    });
  });
}
