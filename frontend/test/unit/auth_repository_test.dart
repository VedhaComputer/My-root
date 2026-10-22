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
        expect(request.url.path, '/api/v1/auth/login');
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
        expect(request.url.path, '/api/v1/auth/register');
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
        expect(request.url.path, '/api/v1/auth/refresh');
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
        expect(request.url.path, '/api/v1/auth/logout');
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

    test('resendVerificationEmail posts email and returns MessageResponse', () async {
      final mockClient = MockHttpClient((request) {
        expect(request.url.path, '/api/v1/auth/verify-email/resend');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'test@example.com');
        return http.Response(
          jsonEncode({
            'message':
                'If an unverified account exists with this email, verification instructions have been sent.',
          }),
          200,
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final repo = AuthRepositoryImpl(client: apiClient);

      final result = await repo.resendVerificationEmail('test@example.com');

      expect(result.isSuccess, isTrue);
      expect(result.data!.message, contains('verification instructions'));
    });

    test('verifyEmail posts token and returns MessageResponse', () async {
      final mockClient = MockHttpClient((request) {
        expect(request.url.path, '/api/v1/auth/verify-email');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['token'], 'valid-token-123');
        return http.Response(
          jsonEncode({
            'message': 'Email verified successfully',
          }),
          200,
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final repo = AuthRepositoryImpl(client: apiClient);

      final result = await repo.verifyEmail('valid-token-123');

      expect(result.isSuccess, isTrue);
      expect(result.data!.message, 'Email verified successfully');
    });

    test('requestPasswordReset posts email and returns MessageResponse', () async {
      final mockClient = MockHttpClient((request) {
        expect(request.url.path, '/api/v1/auth/password-reset/request');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'user@example.com');
        return http.Response(
          jsonEncode({
            'message':
                'If an account exists with this email, password reset instructions have been sent.',
          }),
          200,
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final repo = AuthRepositoryImpl(client: apiClient);

      final result = await repo.requestPasswordReset('user@example.com');

      expect(result.isSuccess, isTrue);
      expect(result.data!.message, contains('password reset instructions'));
    });

    test('resetPassword posts token and newPassword and returns MessageResponse', () async {
      final mockClient = MockHttpClient((request) {
        expect(request.url.path, '/api/v1/auth/password-reset/confirm');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['token'], 'reset-token-456');
        expect(body['newPassword'], 'BrandNewPass123!');
        return http.Response(
          jsonEncode({
            'message':
                'Password reset successful. Please log in with your new password.',
          }),
          200,
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final repo = AuthRepositoryImpl(client: apiClient);

      final result = await repo.resetPassword('reset-token-456', 'BrandNewPass123!');

      expect(result.isSuccess, isTrue);
      expect(result.data!.message, contains('Password reset successful'));
    });
  });
}
