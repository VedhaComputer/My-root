import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:my_root/core/error/failures.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/user.dart';
import 'package:my_root/repositories/auth_repository.dart';
import 'package:my_root/repositories/place_repository.dart';
import 'package:my_root/services/auth_service.dart';
import 'package:my_root/services/place_service.dart';
import 'package:my_root/ui/widgets/app_header.dart';
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

Widget createTestWrapper({required Widget child}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('hi')],
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Places API Authentication & Token Lifecycle Regression Tests', () {
    late MockHttpClient mockHttp;
    late ApiClient apiClient;
    late AuthRepositoryImpl authRepo;
    late PlaceRepositoryImpl placeRepo;
    late AuthService authService;
    late PlaceService placeService;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      mockHttp = MockHttpClient();
      authRepo = AuthRepositoryImpl(client: ApiClient(client: mockHttp));
      authService = AuthService(repository: authRepo);

      apiClient = ApiClient(
        client: mockHttp,
        tokenProvider: () => authService.tokens?.accessToken,
        onTokenExpired: () async => await authService.refreshToken(),
      );
      placeRepo = PlaceRepositoryImpl(client: apiClient);
      placeService = PlaceService(repository: placeRepo);
    });

    test('1. Unauthenticated / missing token Places search returns 401 AuthFailure', () async {
      mockHttp.handler = (req) {
        if (req.url.path.contains('/places')) {
          final auth = req.headers['Authorization'];
          if (auth == null || !auth.startsWith('Bearer ')) {
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 'UNAUTHENTICATED',
                  'message': 'No token provided',
                }
              }),
              401,
              headers: {'content-type': 'application/json'},
            );
          }
        }
        return http.Response('{"error": "not found"}', 404);
      };

      await placeService.fetchPlaces(search: 'Delhi');
      expect(placeService.places, isEmpty);
      expect(placeService.errorMessage, 'No token provided');
      expect(placeService.isAuthError, isTrue);
      expect(placeService.lastFailure, isA<AuthFailure>());
    });

    test('2. Authenticated Places search transmits Bearer token and populates results with 200', () async {
      String? capturedAuthHeader;

      mockHttp.handler = (req) {
        if (req.url.path.contains('/auth/login')) {
          return http.Response(
            jsonEncode({
              'accessToken': 'valid_jwt_access_token_123',
              'refreshToken': 'valid_jwt_refresh_token_456',
              'user': {
                'id': 'user_abc_001',
                'displayName': 'Authorized Contributor',
                'role': 'CONTRIBUTOR',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (req.url.path.contains('/places')) {
          capturedAuthHeader = req.headers['Authorization'];
          if (capturedAuthHeader == 'Bearer valid_jwt_access_token_123') {
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': 'plc_dl_01',
                    'level': 'CITY_TOWN',
                    'canonicalName': 'Delhi',
                    'names': [
                      {'language': 'en', 'name': 'Delhi'},
                      {'language': 'hi', 'name': 'दिल्ली'}
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
          return http.Response(
            jsonEncode({'error': {'code': 'UNAUTHENTICATED', 'message': 'Invalid token'}}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('{"error": "not found"}', 404);
      };

      // Perform login
      final loginRes = await authService.login('user@myroot.in', 'Password123!');
      expect(loginRes.isSuccess, isTrue);
      expect(authService.isAuthenticated, isTrue);

      // Search places
      await placeService.fetchPlaces(search: 'Delhi');
      expect(capturedAuthHeader, 'Bearer valid_jwt_access_token_123');
      expect(placeService.places, hasLength(1));
      expect(placeService.places.first.canonicalName, 'Delhi');
      expect(placeService.errorMessage, isNull);
      expect(placeService.isAuthError, isFalse);
    });

    test('3. Places search handles 401 by triggering refresh and retrying successfully', () async {
      int placesCallCount = 0;
      final capturedTokens = <String?>[];

      mockHttp.handler = (req) {
        if (req.url.path.contains('/auth/refresh')) {
          return http.Response(
            jsonEncode({
              'accessToken': 'refreshed_jwt_access_token_789',
              'refreshToken': 'valid_jwt_refresh_token_456',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (req.url.path.contains('/auth/me')) {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'user_abc_001',
                'displayName': 'Authorized Contributor',
                'role': 'CONTRIBUTOR',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (req.url.path.contains('/places')) {
          placesCallCount++;
          final token = req.headers['Authorization'];
          capturedTokens.add(token);

          // First call with expired token returns 401
          if (token == 'Bearer expired_token_000') {
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 'UNAUTHENTICATED',
                  'message': 'Token has been revoked or expired',
                }
              }),
              401,
              headers: {'content-type': 'application/json'},
            );
          }

          // Second call with refreshed token returns 200
          if (token == 'Bearer refreshed_jwt_access_token_789') {
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': 'plc_jp_01',
                    'level': 'CITY_TOWN',
                    'canonicalName': 'Jaipur',
                    'names': [
                      {'language': 'en', 'name': 'Jaipur'}
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
        }

        return http.Response('{"error": "not found"}', 404);
      };

      // Set initial session with expired access token
      await authService.setSession(
        AuthTokens(
          accessToken: 'expired_token_000',
          refreshToken: 'valid_jwt_refresh_token_456',
          user: User(
            id: 'user_abc_001',
            displayName: 'Authorized Contributor',
            role: 'CONTRIBUTOR',
            joinedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ),
      );

      // Perform search - ApiClient detects 401, triggers onTokenExpired(), refreshes, and retries!
      await placeService.fetchPlaces(search: 'Jaipur');

      expect(placesCallCount, 2);
      expect(capturedTokens, [
        'Bearer expired_token_000',
        'Bearer refreshed_jwt_access_token_789',
      ]);
      expect(placeService.places, hasLength(1));
      expect(placeService.places.first.canonicalName, 'Jaipur');
      expect(placeService.errorMessage, isNull);
    });

    test('4. Places search handles 401 when refresh fails by setting AuthFailure', () async {
      mockHttp.handler = (req) {
        if (req.url.path.contains('/places')) {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'UNAUTHENTICATED',
                'message': 'Invalid or expired token',
              }
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path.contains('/auth/refresh')) {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'UNAUTHENTICATED',
                'message': 'Refresh token expired',
              }
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"error": "not found"}', 404);
      };

      await authService.setSession(
        AuthTokens(
          accessToken: 'bad_token',
          refreshToken: 'expired_refresh',
          user: User(
            id: 'user_01',
            displayName: 'User',
            role: 'CONTRIBUTOR',
            joinedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ),
      );

      await placeService.fetchPlaces(search: 'Mumbai');
      expect(placeService.places, isEmpty);
      expect(placeService.isAuthError, isTrue);
      expect(placeService.errorMessage, contains('Invalid or expired token'));
    });

    testWidgets('5. GlobalAppBar without placeService resolves authenticated client from authService', (tester) async {
      String? capturedAuthHeader;

      mockHttp.handler = (req) {
        if (req.url.path.contains('/places')) {
          capturedAuthHeader = req.headers['Authorization'];
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'plc_ch_01',
                  'level': 'CITY_TOWN',
                  'canonicalName': 'Chandigarh',
                  'names': [
                    {'language': 'en', 'name': 'Chandigarh'}
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

      final sharedClient = ApiClient(client: mockHttp);
      sharedClient.setAccessToken('shared_auth_jwt_token_999');
      final authRepoWithClient = AuthRepositoryImpl(client: sharedClient);
      final testAuthService = AuthService(repository: authRepoWithClient);
      await testAuthService.setSession(
        AuthTokens(
          accessToken: 'shared_auth_jwt_token_999',
          refreshToken: 'refresh_999',
          user: User(
            id: 'u999',
            displayName: 'Shared User',
            role: 'CONTRIBUTOR',
            joinedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ),
      );

      // Render GlobalAppBar with ONLY authService (placeService omitted)
      await tester.pumpWidget(
        createTestWrapper(
          child: Scaffold(
            appBar: GlobalAppBar(
              authService: testAuthService,
              // placeService intentionally omitted
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap location selector button to open LocationSearchDialog
      final locationButton = find.byKey(const Key('header_location_selector'));
      expect(locationButton, findsOneWidget);
      await tester.tap(locationButton);
      await tester.pumpAndSettle();

      // Verify LocationSearchDialog opened
      expect(find.byKey(const Key('location_search_input')), findsOneWidget);

      // Enter search text
      await tester.enterText(find.byKey(const Key('location_search_input')), 'Chandigarh');
      // Advance debounce timer (350ms)
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Verify Bearer token was sent despite placeService being omitted on GlobalAppBar!
      expect(capturedAuthHeader, 'Bearer shared_auth_jwt_token_999');
      final resultFinder = find.descendant(
        of: find.byKey(const Key('location_search_results_list')),
        matching: find.text('Chandigarh'),
      );
      expect(resultFinder, findsOneWidget);
    });

    testWidgets('6. HomePage synchronizes token across all repository clients', (tester) async {
      final sharedClient = ApiClient(client: mockHttp);
      final authRepo = AuthRepositoryImpl(client: sharedClient);
      final homeAuthService = AuthService(repository: authRepo);

      await tester.pumpWidget(
        createTestWrapper(
          child: HomePage(
            authService: homeAuthService,
            apiClient: sharedClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no token
      expect(sharedClient.accessToken, isNull);

      // User logs in / session set
      await homeAuthService.setSession(
        AuthTokens(
          accessToken: 'synced_session_token_777',
          refreshToken: 'synced_refresh_777',
          user: User(
            id: 'u777',
            displayName: 'Sync User',
            role: 'CONTRIBUTOR',
            joinedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify shared client has the updated token
      expect(sharedClient.accessToken, 'synced_session_token_777');
    });

    test('7. Concurrent 401 responses deduplicate token refresh request to exactly one execution', () async {
      int refreshCallCount = 0;

      mockHttp.handler = (req) {
        if (req.url.path.contains('/auth/refresh')) {
          refreshCallCount++;
          return http.Response(
            jsonEncode({
              'accessToken': 'dedup_access_token',
              'refreshToken': 'dedup_refresh_token',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (req.url.path.contains('/auth/me')) {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'user_dedup_01',
                'displayName': 'Dedup User',
                'role': 'CONTRIBUTOR',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (req.url.path.contains('/places')) {
          final auth = req.headers['Authorization'];
          if (auth == 'Bearer old_expired_token') {
            return http.Response(
              jsonEncode({'error': {'code': 'UNAUTHENTICATED', 'message': 'Token expired'}}),
              401,
              headers: {'content-type': 'application/json'},
            );
          }
          if (auth == 'Bearer dedup_access_token') {
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': 'p1',
                    'level': 'CITY_TOWN',
                    'canonicalName': 'Delhi',
                    'names': [],
                    'parentId': null,
                  }
                ],
                'pagination': {'total': 1, 'page': 1, 'limit': 20},
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        }
        return http.Response('{"error": "not found"}', 404);
      };

      await authService.setSession(
        AuthTokens(
          accessToken: 'old_expired_token',
          refreshToken: 'valid_refresh_token',
          user: User(
            id: 'u1',
            displayName: 'U1',
            role: 'CONTRIBUTOR',
            joinedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ),
      );

      // Fire two concurrent requests that both encounter 401
      final res1Future = placeRepo.getPlaces(search: 'Delhi');
      final res2Future = placeRepo.getPlaces(search: 'Delhi');
      final results = await Future.wait([res1Future, res2Future]);

      expect(results[0].isSuccess, isTrue);
      expect(results[1].isSuccess, isTrue);
      expect(refreshCallCount, equals(1));
    });

    test('8. Unauthenticated 401 does not trigger token refresh', () async {
      int refreshCallCount = 0;
      String? capturedAuthHeader;

      mockHttp.handler = (req) {
        if (req.url.path.contains('/auth/refresh')) {
          refreshCallCount++;
          return http.Response(
            jsonEncode({
              'accessToken': 'never_used',
              'refreshToken': 'never_used',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path.contains('/places')) {
          capturedAuthHeader = req.headers['Authorization'];
          return http.Response(
            jsonEncode({'error': {'code': 'UNAUTHENTICATED', 'message': 'Authentication required'}}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"error": "not found"}', 404);
      };

      // Unauthenticated request (no session, no token)
      final result = await placeRepo.getPlaces(search: 'Pune');
      expect(result.isSuccess, isFalse);
      expect(result.failure, isA<AuthFailure>());
      expect(capturedAuthHeader, isNull);
      expect(refreshCallCount, equals(0));
    });

    test('9. Excluded auth endpoints encountering 401 do not trigger token refresh', () async {
      int refreshCallCount = 0;

      final testClient = ApiClient(
        client: mockHttp,
        accessToken: 'some_token',
        onTokenExpired: () async {
          refreshCallCount++;
          return true;
        },
      );

      mockHttp.handler = (req) {
        return http.Response(
          jsonEncode({'error': {'code': 'UNAUTHENTICATED', 'message': 'Bad credentials'}}),
          401,
          headers: {'content-type': 'application/json'},
        );
      };

      final response = await testClient.post('/auth/login', {'email': 'a@b.com', 'password': 'pw'});
      expect(response.isSuccess, isFalse);
      expect(response.failure, isA<AuthFailure>());
      expect(refreshCallCount, equals(0));
    });

    test('10. Places 401 triggers refresh, updates authService.tokens before getMe, retries with refreshed token, and subsequent search uses refreshed token', () async {
      int placesCallCount = 0;
      final capturedPlacesAuthHeaders = <String?>[];
      String? capturedMeAuthHeader;

      mockHttp.handler = (req) {
        if (req.url.path.contains('/auth/refresh')) {
          return http.Response(
            jsonEncode({
              'accessToken': 'freshly_minted_jwt_333',
              'refreshToken': 'new_refresh_token_444',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (req.url.path.contains('/auth/me')) {
          capturedMeAuthHeader = req.headers['Authorization'];
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'user_abc_001',
                'displayName': 'Authorized Contributor',
                'role': 'CONTRIBUTOR',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (req.url.path.contains('/places')) {
          placesCallCount++;
          final auth = req.headers['Authorization'];
          capturedPlacesAuthHeaders.add(auth);

          if (auth == 'Bearer stale_jwt_access_token_111') {
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 'UNAUTHENTICATED',
                  'message': 'Invalid or expired token',
                }
              }),
              401,
              headers: {'content-type': 'application/json'},
            );
          }

          if (auth == 'Bearer freshly_minted_jwt_333') {
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': 'plc_ud_01',
                    'level': 'CITY_TOWN',
                    'canonicalName': 'Udaipur',
                    'names': [
                      {'language': 'en', 'name': 'Udaipur'}
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
        }

        return http.Response('{"error": "not found"}', 404);
      };

      await authService.setSession(
        AuthTokens(
          accessToken: 'stale_jwt_access_token_111',
          refreshToken: 'valid_refresh_token_222',
          user: User(
            id: 'user_abc_001',
            displayName: 'Authorized Contributor',
            role: 'CONTRIBUTOR',
            joinedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ),
      );

      // First Places search triggers refresh and retries with refreshed token
      await placeService.fetchPlaces(search: 'Udaipur');

      expect(placesCallCount, equals(2));
      expect(capturedPlacesAuthHeaders, [
        'Bearer stale_jwt_access_token_111',
        'Bearer freshly_minted_jwt_333',
      ]);
      expect(capturedMeAuthHeader, equals('Bearer freshly_minted_jwt_333'));
      expect(placeService.places, hasLength(1));
      expect(placeService.places.first.canonicalName, equals('Udaipur'));
      expect(placeService.errorMessage, isNull);

      // Subsequent Places search immediately carries refreshed token on initial try (no refresh)
      await placeService.fetchPlaces(search: 'Udaipur');
      expect(placesCallCount, equals(3));
      expect(capturedPlacesAuthHeaders.last, equals('Bearer freshly_minted_jwt_333'));
    });

    test('11. Standalone ApiClient without tokenProvider syncs refreshed token from storage on retry', () async {
      int placesCallCount = 0;
      final capturedHeaders = <String?>[];

      final standaloneClient = ApiClient(
        client: mockHttp,
        accessToken: 'stale_standalone_token_555',
        onTokenExpired: () async {
          // Simulate authService refreshing session into storage
          return await authService.refreshToken();
        },
      );
      final standalonePlaceRepo = PlaceRepositoryImpl(client: standaloneClient);
      final standalonePlaceService = PlaceService(repository: standalonePlaceRepo);

      mockHttp.handler = (req) {
        if (req.url.path.contains('/auth/refresh')) {
          return http.Response(
            jsonEncode({
              'accessToken': 'refreshed_standalone_token_777',
              'refreshToken': 'new_refresh_token_888',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (req.url.path.contains('/auth/me')) {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'user_abc_001',
                'displayName': 'Authorized Contributor',
                'role': 'CONTRIBUTOR',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (req.url.path.contains('/places')) {
          placesCallCount++;
          final auth = req.headers['Authorization'];
          capturedHeaders.add(auth);

          if (auth == 'Bearer stale_standalone_token_555') {
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 'UNAUTHENTICATED',
                  'message': 'Invalid or expired token',
                }
              }),
              401,
              headers: {'content-type': 'application/json'},
            );
          }

          if (auth == 'Bearer refreshed_standalone_token_777') {
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': 'plc_standalone_01',
                    'level': 'CITY_TOWN',
                    'canonicalName': 'Standalone City',
                    'names': [
                      {'language': 'en', 'name': 'Standalone City'}
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
        }

        return http.Response('{"error": "not found"}', 404);
      };

      await authService.setSession(
        AuthTokens(
          accessToken: 'stale_standalone_token_555',
          refreshToken: 'valid_refresh_token_222',
          user: User(
            id: 'user_abc_001',
            displayName: 'Authorized Contributor',
            role: 'CONTRIBUTOR',
            joinedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ),
      );

      await standalonePlaceService.fetchPlaces(search: 'Standalone City');

      expect(placesCallCount, equals(2));
      expect(capturedHeaders, [
        'Bearer stale_standalone_token_555',
        'Bearer refreshed_standalone_token_777',
      ]);
      expect(standalonePlaceService.places, hasLength(1));
      expect(standalonePlaceService.places.first.canonicalName, equals('Standalone City'));
    });
  });
}
