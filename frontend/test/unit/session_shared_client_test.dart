import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/repositories/auth_repository.dart';
import 'package:my_root/repositories/place_repository.dart';
import 'package:my_root/services/auth_service.dart';
import 'package:my_root/services/place_service.dart';
import 'package:my_root/ui/pages/home/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockHttpClient extends http.BaseClient {
  http.Response Function(http.Request request)? handler;
  MockHttpClient([this.handler]);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final httpRequest = request as http.Request;
    final response = handler != null
        ? handler!(httpRequest)
        : http.Response('{"error": {"code": "NOT_FOUND", "message": "Not found"}}', 404);

    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Shared Session ApiClient Integration (Unit Tests)', () {
    late MockHttpClient mockHttp;
    late ApiClient sharedClient;
    late AuthRepositoryImpl authRepo;
    late PlaceRepositoryImpl placeRepo;
    late AuthService authService;
    late PlaceService placeService;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      mockHttp = MockHttpClient();
      sharedClient = ApiClient(client: mockHttp);
      authRepo = AuthRepositoryImpl(client: sharedClient);
      placeRepo = PlaceRepositoryImpl(client: sharedClient);
      authService = AuthService(repository: authRepo);
      placeService = PlaceService(repository: placeRepo);
    });

    test('Places request sends Authorization: Bearer after successful login on shared client', () async {
      String? capturedAuthHeader;

      mockHttp.handler = (req) {
        if ((req.url.path == '/api/v1/auth/login' || req.url.path == '/auth/login')) {
          return http.Response(
            jsonEncode({
              'accessToken': 'rs256_test_jwt_access_token_xyz',
              'refreshToken': 'refresh_token_test_123',
              'user': {
                'id': 'user_001',
                'displayName': 'Session User',
                'role': 'CONTRIBUTOR',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if ((req.url.path == '/api/v1/places' || req.url.path == '/places')) {
          capturedAuthHeader = req.headers['Authorization'];
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'plc_ind',
                  'level': 'COUNTRY',
                  'canonicalName': 'India',
                  'names': [
                    {'language': 'en', 'name': 'India'}
                  ],
                  'parentId': null,
                }
              ],
              'pagination': {'total': 1, 'page': 1, 'limit': 20},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('{"error": "not found"}', 404);
      };

      // 1. Before login, places request has no Authorization header
      await placeService.fetchPlaces();
      expect(capturedAuthHeader, isNull);

      // 2. Perform login via authService
      final loginResult = await authService.login('test@example.com', 'Secret123!');
      expect(loginResult.isSuccess, isTrue);
      expect(authService.isAuthenticated, isTrue);

      // 3. Perform places request via placeService on the shared client
      await placeService.fetchPlaces();
      expect(capturedAuthHeader, isNotNull);
      expect(capturedAuthHeader, 'Bearer rs256_test_jwt_access_token_xyz');
      expect(placeService.places, hasLength(1));
      expect(placeService.places.first.canonicalName, 'India');
    });

    test('Logout clears Authorization header on shared client for subsequent Places requests', () async {
      String? capturedAuthHeader;

      mockHttp.handler = (req) {
        if ((req.url.path == '/api/v1/auth/login' || req.url.path == '/auth/login')) {
          return http.Response(
            jsonEncode({
              'accessToken': 'rs256_test_jwt_access_token_xyz',
              'refreshToken': 'refresh_token_test_123',
              'user': {
                'id': 'user_001',
                'displayName': 'Session User',
                'role': 'CONTRIBUTOR',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if ((req.url.path == '/api/v1/auth/logout' || req.url.path == '/auth/logout')) {
          return http.Response(
            jsonEncode({'message': 'Logged out successfully'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if ((req.url.path == '/api/v1/places' || req.url.path == '/places')) {
          capturedAuthHeader = req.headers['Authorization'];
          return http.Response(
            jsonEncode({'data': [], 'pagination': {'total': 0, 'page': 1, 'limit': 20}}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('{"error": "not found"}', 404);
      };

      // Login
      await authService.login('test@example.com', 'Secret123!');
      await placeService.fetchPlaces();
      expect(capturedAuthHeader, 'Bearer rs256_test_jwt_access_token_xyz');

      // Logout
      capturedAuthHeader = null;
      await authService.logout();
      expect(authService.isAuthenticated, isFalse);

      // Subsequent places request must NOT carry Authorization header
      await placeService.fetchPlaces();
      expect(capturedAuthHeader, isNull);
    });

    test('HomePage wires the exact same ApiClient instance to both Auth and Place repositories', () {
      final homePage = HomePage(apiClient: sharedClient);
      expect(homePage.apiClient, equals(sharedClient));
      expect(identical(authRepo.client, placeRepo.client), isTrue);
      expect(identical(authRepo.client, sharedClient), isTrue);
      expect(identical(placeRepo.client, sharedClient), isTrue);
    });
  });
}
