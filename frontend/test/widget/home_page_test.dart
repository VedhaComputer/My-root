import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_root/app/app.dart';
import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/auth_dtos.dart';
import 'package:my_root/models/user.dart';
import 'package:my_root/models/user_activity.dart';
import 'package:my_root/repositories/auth_repository.dart';
import 'package:my_root/services/auth_service.dart';
import 'package:my_root/ui/card/claim_card.dart';
import 'package:my_root/ui/card/community_progress_card.dart';
import 'package:my_root/ui/pages/claims/claim_detail_page.dart';
import 'package:my_root/ui/pages/auth/login_page.dart';
import 'package:my_root/ui/pages/home/home_page.dart';
import 'package:my_root/ui/pages/places/places_page.dart';
import 'package:my_root/ui/pages/places/place_detail_page.dart';
import 'package:my_root/ui/pages/places/progressive_contribution_page.dart';
import 'package:my_root/ui/pages/claims/category_claims_page.dart';
import 'package:my_root/ui/widgets/home_features_drawer.dart';
import 'package:my_root/ui/widgets/location_search_dialog.dart';
import 'package:my_root/core/constants.dart';

class MockHttpClient extends http.BaseClient {
  http.Response Function(http.Request request)? handler;

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

class MockHomeAuthRepo implements AuthRepository {
  User testUser = User(
    id: 'user-home-1',
    displayName: 'Aarav Sharma',
    role: 'CONTRIBUTOR',
    joinedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
  );

  @override
  Future<ApiResponse<AuthTokens>> login(String email, String password) async {
    return ApiResponse.success(
      AuthTokens(accessToken: 'acc-token', refreshToken: 'ref-token', user: testUser),
    );
  }

  @override
  Future<ApiResponse<User>> getMe() async {
    return ApiResponse.success(testUser);
  }

  @override
  Future<ApiResponse<User>> updateSelectedPlace(String? placeId) async {
    return ApiResponse.success(testUser.copyWith(selectedPlaceId: placeId));
  }

  @override
  Future<ApiResponse<User>> updateMatrbhoomiInterest({
    required String placeId,
    bool? knowsHistory,
    bool? wantsToLearn,
  }) async {
    testUser = testUser.copyWith(
      matrbhoomiHistoryInterest: MatrbhoomiHistoryInterest(
        placeId: placeId,
        knowsHistory: knowsHistory,
        wantsToLearn: wantsToLearn,
        answeredAt: DateTime.now(),
      ),
    );
    return ApiResponse.success(testUser);
  }

  @override
  Future<ApiResponse<AuthTokens>> refreshToken(String refreshToken) async {
    return ApiResponse.success(
      AuthTokens(accessToken: 'acc-token-2', refreshToken: 'ref-token-2', user: testUser),
    );
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> logout({String? refreshToken}) async {
    return const ApiResponse.success({'message': 'Logged out'});
  }

  @override
  Future<ApiResponse<RegisterResponse>> register(String displayName, String email, String password) async {
    return const ApiResponse.success(RegisterResponse(message: 'Registered'));
  }

  @override
  Future<ApiResponse<UserActivity>> getUserActivity() async {
    return const ApiResponse.success(UserActivity(
      summary: UserActivitySummary(totalContributions: 0, claimsCount: 0, evidencesCount: 0, placesCount: 0, placeAttributesCount: 0),
      claims: [],
      evidences: [],
      places: [],
      placeAttributes: [],
    ));
  }

  @override
  Future<ApiResponse<List<PublicUser>>> getLatestUsers() async {
    return const ApiResponse.success([]);
  }

  @override
  Future<ApiResponse<MessageResponse>> resendVerificationEmail(String email) async =>
      const ApiResponse.success(MessageResponse(message: 'Verification sent'));

  @override
  Future<ApiResponse<MessageResponse>> verifyEmail(String token) async =>
      const ApiResponse.success(MessageResponse(message: 'Email verified'));

  @override
  Future<ApiResponse<MessageResponse>> requestPasswordReset(String email) async =>
      const ApiResponse.success(MessageResponse(message: 'Reset instructions sent'));

  @override
  Future<ApiResponse<MessageResponse>> resetPassword(String token, String newPassword) async =>
      const ApiResponse.success(MessageResponse(message: 'Password reset successful'));
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('MyRootApp', () {
    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(const MyRootApp());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('shows loading splash screen while session restoration is pending', (tester) async {
      final authRepo = MockHomeAuthRepo();
      final authService = AuthService(repository: authRepo);
      // Not yet initialized
      await tester.pumpWidget(MyRootApp(authService: authService));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('My Root'), findsWidgets);
    });

    testWidgets('routes to HomePage when session is restored as authenticated', (tester) async {
      final authRepo = MockHomeAuthRepo();
      final authService = AuthService(repository: authRepo);
      authService.setSession(
        AuthTokens(
          accessToken: 'acc',
          refreshToken: 'ref',
          user: User(id: 'u1', displayName: 'Aarav Sharma', role: 'CONTRIBUTOR', joinedAt: DateTime(2026, 1, 1)),
        ),
      );

      await tester.pumpWidget(MyRootApp(authService: authService));
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Welcome, Aarav Sharma'), findsOneWidget);
    });

    testWidgets('routes to LoginPage when session is unauthenticated after initialization', (tester) async {
      final authRepo = MockHomeAuthRepo();
      final authService = AuthService(repository: authRepo);
      await authService.restoreSession();

      await tester.pumpWidget(MyRootApp(authService: authService));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
    });
  });

  group('HomePage', () {
    late MockHttpClient mockHttp;
    late ApiClient apiClient;

    setUp(() {
      mockHttp = MockHttpClient();
      apiClient = ApiClient(client: mockHttp);
    });

    Widget buildTestWidget({AuthService? authService}) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('hi')],
        home: HomePage(
          apiClient: apiClient,
          authService: authService,
        ),
      );
    }

    testWidgets('shows app title and categories', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.text('My Root'), findsWidgets);
      expect(find.text('Browse by Category'), findsOneWidget);
    });

    testWidgets('displays prompt to sign in to explore village knowledge when unauthenticated', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Village Knowledge & Recent Stories'), findsOneWidget);
      expect(find.text('Sign in to explore village knowledge'), findsOneWidget);
      expect(find.text('Connect with your community to view verified records, folklore, and local stories.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign In'), findsWidgets);
    });

    testWidgets('displays public village claims on home page when authenticated', (tester) async {
      final authRepo = MockHomeAuthRepo();
      final authService = AuthService(repository: authRepo);
      await authService.login('aarav@example.com', 'password123');

      mockHttp.handler = (req) {
        if ((req.url.path == '/api/v1/claims' || req.url.path == '/claims')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'claim-v1',
                  'title': {'original': 'Ancient Banyan Story', 'language': 'en'},
                  'body': {'original': 'Historic tree of the village', 'language': 'en'},
                  'category': 'FOLKLORE',
                  'status': 'verified',
                  'locationId': 'place-v1',
                  'submittedAt': '2026-03-01T00:00:00.000Z',
                  'evidenceCount': 2,
                  'isPublic': true,
                  'tags': ['heritage'],
                }
              ],
              'pagination': {'page': 1, 'limit': 10, 'total': 1, 'pages': 1},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"data": {}}', 200, headers: {'content-type': 'application/json'});
      };

      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      expect(find.text('Village Knowledge & Recent Stories'), findsOneWidget);
      expect(find.byType(ClaimCard), findsOneWidget);
      expect(find.text('Ancient Banyan Story'), findsOneWidget);
      expect(find.text('Historic tree of the village'), findsOneWidget);
    });

    testWidgets('displays empty state when authenticated but no public village stories exist', (tester) async {
      final authRepo = MockHomeAuthRepo();
      final authService = AuthService(repository: authRepo);
      await authService.login('aarav@example.com', 'password123');

      mockHttp.handler = (req) {
        if ((req.url.path == '/api/v1/claims' || req.url.path == '/claims')) {
          return http.Response(
            jsonEncode({
              'data': [],
              'pagination': {'page': 1, 'limit': 10, 'total': 0, 'pages': 0},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"data": {}}', 200, headers: {'content-type': 'application/json'});
      };

      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      expect(find.text('Village Knowledge & Recent Stories'), findsOneWidget);
      expect(find.text('No public village stories yet'), findsOneWidget);
      expect(find.text('Be the first to preserve and share local history and community knowledge.'), findsOneWidget);
    });

    testWidgets('tapping claim card navigates to ClaimDetailPage', (tester) async {
      final authRepo = MockHomeAuthRepo();
      final authService = AuthService(repository: authRepo);
      await authService.login('aarav@example.com', 'password123');

      mockHttp.handler = (req) {
        if ((req.url.path == '/api/v1/claims/claim-v1' || req.url.path == '/claims/claim-v1')) {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'claim-v1',
                'title': {'original': 'Ancient Banyan Story', 'language': 'en'},
                'body': {'original': 'Historic tree of the village', 'language': 'en'},
                'category': 'FOLKLORE',
                'status': 'verified',
                'locationId': 'place-v1',
                'submittedAt': '2026-03-01T00:00:00.000Z',
                'evidenceCount': 0,
                'isPublic': true,
                'tags': [],
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if ((req.url.path == '/api/v1/claims' || req.url.path == '/claims')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'claim-v1',
                  'title': {'original': 'Ancient Banyan Story', 'language': 'en'},
                  'body': {'original': 'Historic tree of the village', 'language': 'en'},
                  'category': 'FOLKLORE',
                  'status': 'verified',
                  'locationId': 'place-v1',
                  'submittedAt': '2026-03-01T00:00:00.000Z',
                  'evidenceCount': 0,
                  'isPublic': true,
                  'tags': [],
                }
              ],
              'pagination': {'page': 1, 'limit': 10, 'total': 1, 'pages': 1},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path.contains('/evidence')) {
          return http.Response(
            jsonEncode({'data': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"data": {}}', 200, headers: {'content-type': 'application/json'});
      };

      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      expect(find.byType(ClaimCard), findsOneWidget);
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ClaimCard));
      await tester.pumpAndSettle();

      expect(find.byType(ClaimDetailPage), findsOneWidget);
    });

    testWidgets('tapping clearly visible Add action opens Add flow without redirecting to LocationSearchDialog', (tester) async {
      mockHttp.handler = (req) {
        if ((req.url.path == '/api/v1/places' || req.url.path == '/places')) {
          return http.Response(
            jsonEncode({'data': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"data": {}}', 200, headers: {'content-type': 'application/json'});
      };

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final addAction = find.widgetWithText(FloatingActionButton, 'Add');
      expect(addAction, findsOneWidget);
      expect(find.text('Add'), findsOneWidget);

      await tester.tap(addAction);
      await tester.pumpAndSettle();

      // Does not redirect to LocationSearchDialog or PlacesPage
      expect(find.byType(LocationSearchDialog), findsNothing);
      expect(find.byType(PlacesPage), findsNothing);
      expect(find.byKey(const Key('home_no_location_card')), findsOneWidget);
      expect(find.text('No Location Selected'), findsOneWidget);
    });

    testWidgets('shows Welcome, {displayName} when authenticated and no role badge in header', (tester) async {
      final authRepo = MockHomeAuthRepo();
      final authService = AuthService(repository: authRepo);
      await authService.login('aarav@example.com', 'password123');

      mockHttp.handler = (req) => http.Response('{"data": []}', 200, headers: {'content-type': 'application/json'});

      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      expect(find.text('Welcome, Aarav Sharma'), findsOneWidget);
      expect(find.text('CONTRIBUTOR'), findsNothing);
    });

    testWidgets('shows Welcome, User fallback when displayName is empty', (tester) async {
      final authRepo = MockHomeAuthRepo();
      authRepo.testUser = User(
        id: 'user-home-empty',
        displayName: '   ',
        role: 'CONTRIBUTOR',
        joinedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
      );
      final authService = AuthService(repository: authRepo);
      await authService.login('empty@example.com', 'password123');

      mockHttp.handler = (req) => http.Response('{"data": []}', 200, headers: {'content-type': 'application/json'});

      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      expect(find.text('Welcome, User'), findsOneWidget);
    });

    testWidgets('opening account menu shows My Profile, My Drafts, and Sign Out', (tester) async {
      final authRepo = MockHomeAuthRepo();
      final authService = AuthService(repository: authRepo);
      await authService.login('aarav@example.com', 'password123');

      mockHttp.handler = (req) => http.Response('{"data": []}', 200, headers: {'content-type': 'application/json'});

      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Welcome, Aarav Sharma'));
      await tester.pumpAndSettle();

      expect(find.text('User Profile'), findsOneWidget);
      expect(find.text('My Drafts'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('signing out via account menu terminates session cleanly', (tester) async {
      final authRepo = MockHomeAuthRepo();
      final authService = AuthService(repository: authRepo);
      await authService.login('aarav@example.com', 'password123');

      mockHttp.handler = (req) => http.Response('{"data": []}', 200, headers: {'content-type': 'application/json'});

      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      expect(authService.isAuthenticated, isTrue);

      await tester.tap(find.text('Welcome, Aarav Sharma'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Sign Out'), findsOneWidget);
      final confirmBtn = find.widgetWithText(FilledButton, 'Sign Out');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(authService.isAuthenticated, isFalse);
      expect(find.text('Welcome, Aarav Sharma'), findsNothing);
    });
  });

  group('HomePage Selected Location Preservation (All 9 Actions)', () {
    late MockHttpClient mockHttp;
    late ApiClient apiClient;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockHttp = MockHttpClient();
      apiClient = ApiClient(client: mockHttp);
      mockHttp.handler = (req) {
        if (req.url.path.endsWith('/progress')) {
          return http.Response(
            jsonEncode({
              'data': {
                'placeId': 'place-jaipur-1',
                'totalContributions': 0,
                'verifiedFactsCount': 0,
                'pendingReviewCount': 0,
                'folkloreCount': 0,
                'opinionsCount': 0,
                'biographiesCount': 0,
                'facilitiesCount': 0,
                'evidenceAttachmentsCount': 0,
                'qualityCoverageScore': 0,
                'criteriaExplanation': '',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path.endsWith('/children') || req.url.path.endsWith('/attributes')) {
          return http.Response(
            jsonEncode({'data': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if ((req.url.path == '/api/v1/places/place-jaipur-1' || req.url.path == '/places/place-jaipur-1')) {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'place-jaipur-1',
                'canonicalName': 'Jaipur',
                'level': 'CITY_TOWN',
                'names': [{'language': 'en', 'name': 'Jaipur'}],
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if ((req.url.path == '/api/v1/places/place-mandore-village' || req.url.path == '/places/place-mandore-village')) {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'place-mandore-village',
                'canonicalName': 'Mandore Village',
                'level': 'VILLAGE',
                'names': [{'language': 'en', 'name': 'Mandore Village'}],
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if ((req.url.path == '/api/v1/places' || req.url.path == '/places')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'place-jaipur-1',
                  'canonicalName': 'Jaipur',
                  'level': 'CITY_TOWN',
                  'names': [{'language': 'en', 'name': 'Jaipur'}],
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path.contains('/claims')) {
          return http.Response(
            jsonEncode({'data': [], 'pagination': {'page': 1, 'limit': 10, 'total': 0, 'pages': 0}}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"data": []}', 200, headers: {'content-type': 'application/json'});
      };
    });

    Widget buildTestWidget({required AuthService authService}) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('hi')],
        home: HomePage(
          apiClient: apiClient,
          authService: authService,
        ),
      );
    }

    AuthService createAuthServiceWithLocation({String placeId = 'place-jaipur-1'}) {
      final authRepo = MockHomeAuthRepo();
      authRepo.testUser = authRepo.testUser.copyWith(selectedPlaceId: placeId);
      final authService = AuthService(repository: authRepo);
      authService.setSession(
        AuthTokens(
          accessToken: 'test-acc',
          refreshToken: 'test-ref',
          user: authRepo.testUser,
        ),
      );
      return authService;
    }

    Future<void> openLeftDrawerAndTap(WidgetTester tester, Key featureKey) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();
      final item = find.byKey(featureKey);
      expect(item, findsOneWidget);
      await tester.ensureVisible(item);
      await tester.tap(item);
      await tester.pumpAndSettle();
    }

    testWidgets('1. Explore Stories preserves selected location and renders PlaceDetailPage in-place', (tester) async {
      final authService = createAuthServiceWithLocation();
      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      expect(find.text('Jaipur'), findsOneWidget);
      // Community Knowledge Score card is absent on HomePage
      expect(find.text('Community Knowledge Score'), findsNothing);
      expect(find.byType(CommunityProgressCard), findsNothing);

      await openLeftDrawerAndTap(tester, const Key('feature_explore_stories'));

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(PlaceDetailPage), findsOneWidget);
      final page = tester.widget<PlaceDetailPage>(find.byType(PlaceDetailPage));
      expect(page.placeId, equals('place-jaipur-1'));
      expect(find.byKey(const Key('header_selected_location')), findsOneWidget);
      expect(find.text('Jaipur'), findsOneWidget);
      expect(find.text('Explore Stories'), findsOneWidget);

      // Community Knowledge Score card and top overview banner card are removed from Explore Stories
      expect(find.byType(CommunityProgressCard), findsNothing);
      expect(find.text('Community Knowledge Score'), findsNothing);
      expect(find.text('Contribute Local Knowledge'), findsNothing);

      final returnBtn = find.byKey(const Key('return_to_home_button'));
      expect(returnBtn, findsOneWidget);
      await tester.tap(returnBtn);
      await tester.pumpAndSettle();

      expect(find.byType(PlaceDetailPage), findsNothing);
      expect(find.text('Jaipur'), findsOneWidget);

      // Absent again once returned to HomePage
      expect(find.text('Community Knowledge Score'), findsNothing);
      expect(find.byType(CommunityProgressCard), findsNothing);
    });

    testWidgets('2. Contribute preserves selected location and renders ProgressiveContributionPage in-place', (tester) async {
      final authService = createAuthServiceWithLocation();
      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      await openLeftDrawerAndTap(tester, const Key('feature_contribute'));

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(ProgressiveContributionPage), findsOneWidget);
      final page = tester.widget<ProgressiveContributionPage>(find.byType(ProgressiveContributionPage));
      expect(page.placeId, equals('place-jaipur-1'));
      expect(find.byKey(const Key('header_selected_location')), findsOneWidget);
      expect(find.text('Jaipur'), findsOneWidget);
      expect(find.text('Contribute'), findsOneWidget);

      final returnBtn = find.byKey(const Key('return_to_home_button'));
      expect(returnBtn, findsOneWidget);
      await tester.tap(returnBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ProgressiveContributionPage), findsNothing);
      expect(find.text('Jaipur'), findsOneWidget);
    });

    testWidgets('3. Historical Record category card preserves selected location and renders CategoryClaimsPage in-place', (tester) async {
      final authService = createAuthServiceWithLocation();
      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      await openLeftDrawerAndTap(tester, const Key('feature_historical_record'));

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(CategoryClaimsPage), findsOneWidget);
      final page = tester.widget<CategoryClaimsPage>(find.byType(CategoryClaimsPage));
      expect(page.placeId, equals('place-jaipur-1'));
      expect(page.category, equals(ClaimCategory.historicalRecord));
      expect(find.byKey(const Key('header_selected_location')), findsOneWidget);
      expect(find.text('Jaipur'), findsOneWidget);
      expect(find.text('Historical Record'), findsOneWidget);

      final returnBtn = find.byKey(const Key('return_to_home_button'));
      expect(returnBtn, findsOneWidget);
      await tester.tap(returnBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CategoryClaimsPage), findsNothing);
      expect(find.text('Jaipur'), findsOneWidget);
    });

    testWidgets('4. Current Fact category card preserves selected location and renders CategoryClaimsPage in-place', (tester) async {
      final authService = createAuthServiceWithLocation();
      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      await openLeftDrawerAndTap(tester, const Key('feature_current_fact'));

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(CategoryClaimsPage), findsOneWidget);
      final page = tester.widget<CategoryClaimsPage>(find.byType(CategoryClaimsPage));
      expect(page.placeId, equals('place-jaipur-1'));
      expect(page.category, equals(ClaimCategory.currentFact));
      expect(find.byKey(const Key('header_selected_location')), findsOneWidget);
      expect(find.text('Jaipur'), findsOneWidget);
      expect(find.text('Current Fact'), findsOneWidget);

      final returnBtn = find.byKey(const Key('return_to_home_button'));
      expect(returnBtn, findsOneWidget);
      await tester.tap(returnBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CategoryClaimsPage), findsNothing);
      expect(find.text('Jaipur'), findsOneWidget);
    });

    testWidgets('5. Folklore / Proverb category card preserves selected location and renders CategoryClaimsPage in-place', (tester) async {
      final authService = createAuthServiceWithLocation();
      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      await openLeftDrawerAndTap(tester, const Key('feature_folklore'));

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(CategoryClaimsPage), findsOneWidget);
      final page = tester.widget<CategoryClaimsPage>(find.byType(CategoryClaimsPage));
      expect(page.placeId, equals('place-jaipur-1'));
      expect(page.category, equals(ClaimCategory.folklore));
      expect(find.byKey(const Key('header_selected_location')), findsOneWidget);
      expect(find.text('Jaipur'), findsOneWidget);
      expect(find.text('Folklore / Proverb'), findsOneWidget);

      final returnBtn = find.byKey(const Key('return_to_home_button'));
      expect(returnBtn, findsOneWidget);
      await tester.tap(returnBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CategoryClaimsPage), findsNothing);
      expect(find.text('Jaipur'), findsOneWidget);
    });

    testWidgets('6. Personal Experience category card preserves selected location and renders CategoryClaimsPage in-place', (tester) async {
      final authService = createAuthServiceWithLocation();
      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      await openLeftDrawerAndTap(tester, const Key('feature_personal_experience'));

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(CategoryClaimsPage), findsOneWidget);
      final page = tester.widget<CategoryClaimsPage>(find.byType(CategoryClaimsPage));
      expect(page.placeId, equals('place-jaipur-1'));
      expect(page.category, equals(ClaimCategory.personalExperience));
      expect(find.byKey(const Key('header_selected_location')), findsOneWidget);
      expect(find.text('Jaipur'), findsOneWidget);
      expect(find.text('Personal Experience'), findsOneWidget);

      final returnBtn = find.byKey(const Key('return_to_home_button'));
      expect(returnBtn, findsOneWidget);
      await tester.tap(returnBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CategoryClaimsPage), findsNothing);
      expect(find.text('Jaipur'), findsOneWidget);
    });

    testWidgets('7. Public Opinion category card preserves selected location and renders CategoryClaimsPage in-place', (tester) async {
      final authService = createAuthServiceWithLocation();
      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      await openLeftDrawerAndTap(tester, const Key('feature_public_opinion'));

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(CategoryClaimsPage), findsOneWidget);
      final page = tester.widget<CategoryClaimsPage>(find.byType(CategoryClaimsPage));
      expect(page.placeId, equals('place-jaipur-1'));
      expect(page.category, equals(ClaimCategory.publicOpinion));
      expect(find.byKey(const Key('header_selected_location')), findsOneWidget);
      expect(find.text('Jaipur'), findsOneWidget);
      expect(find.text('Public Opinion'), findsOneWidget);

      final returnBtn = find.byKey(const Key('return_to_home_button'));
      expect(returnBtn, findsOneWidget);
      await tester.tap(returnBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CategoryClaimsPage), findsNothing);
      expect(find.text('Jaipur'), findsOneWidget);
    });

    testWidgets('8. Survey Data category card preserves selected location and renders CategoryClaimsPage in-place', (tester) async {
      final authService = createAuthServiceWithLocation();
      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      await openLeftDrawerAndTap(tester, const Key('feature_survey_data'));

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(CategoryClaimsPage), findsOneWidget);
      final page = tester.widget<CategoryClaimsPage>(find.byType(CategoryClaimsPage));
      expect(page.placeId, equals('place-jaipur-1'));
      expect(page.category, equals(ClaimCategory.surveyData));
      expect(find.byKey(const Key('header_selected_location')), findsOneWidget);
      expect(find.text('Jaipur'), findsOneWidget);
      expect(find.text('Survey Data'), findsOneWidget);

      final returnBtn = find.byKey(const Key('return_to_home_button'));
      expect(returnBtn, findsOneWidget);
      await tester.tap(returnBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CategoryClaimsPage), findsNothing);
      expect(find.text('Jaipur'), findsOneWidget);
    });

    testWidgets('9. Add FloatingActionButton preserves selected location and renders ProgressiveContributionPage in-place', (tester) async {
      final authService = createAuthServiceWithLocation();
      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      final fab = find.widgetWithText(FloatingActionButton, 'Add');
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(ProgressiveContributionPage), findsOneWidget);
      final page = tester.widget<ProgressiveContributionPage>(find.byType(ProgressiveContributionPage));
      expect(page.placeId, equals('place-jaipur-1'));
      expect(find.byKey(const Key('header_selected_location')), findsOneWidget);
      expect(find.text('Jaipur'), findsOneWidget);
      expect(find.text('Contribute'), findsOneWidget);

      final returnBtn = find.byKey(const Key('return_to_home_button'));
      expect(returnBtn, findsOneWidget);
      await tester.tap(returnBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ProgressiveContributionPage), findsNothing);
      expect(find.text('Jaipur'), findsOneWidget);
    });

    testWidgets('10. Semantic Disambiguation: Ensure semantically different actions cannot resolve to the same destination', (tester) async {
      final authService = createAuthServiceWithLocation();
      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      // Open Explore Stories -> renders PlaceDetailPage in-place
      await openLeftDrawerAndTap(tester, const Key('feature_explore_stories'));
      expect(find.byType(PlaceDetailPage), findsOneWidget);
      expect(find.byType(ProgressiveContributionPage), findsNothing);
      expect(find.byType(CategoryClaimsPage), findsNothing);

      // Return to Location Home via in-content return button
      await tester.tap(find.byKey(const Key('return_to_home_button')));
      await tester.pumpAndSettle();

      // Open Contribute -> renders ProgressiveContributionPage in-place
      await openLeftDrawerAndTap(tester, const Key('feature_contribute'));
      expect(find.byType(ProgressiveContributionPage), findsOneWidget);
      expect(find.byType(PlaceDetailPage), findsNothing);
      expect(find.byType(CategoryClaimsPage), findsNothing);

      // Return to Location Home
      await tester.tap(find.byKey(const Key('return_to_home_button')));
      await tester.pumpAndSettle();

      // Open Historical Record -> renders CategoryClaimsPage in-place
      await openLeftDrawerAndTap(tester, const Key('feature_historical_record'));
      expect(find.byType(CategoryClaimsPage), findsOneWidget);
      expect(find.byType(PlaceDetailPage), findsNothing);
      expect(find.byType(ProgressiveContributionPage), findsNothing);
      final histPage = tester.widget<CategoryClaimsPage>(find.byType(CategoryClaimsPage));
      expect(histPage.category, equals(ClaimCategory.historicalRecord));

      // Return to Location Home
      await tester.tap(find.byKey(const Key('return_to_home_button')));
      await tester.pumpAndSettle();

      // Open Folklore -> renders CategoryClaimsPage with folklore
      await openLeftDrawerAndTap(tester, const Key('feature_folklore'));
      expect(find.byType(CategoryClaimsPage), findsOneWidget);
      final folkPage = tester.widget<CategoryClaimsPage>(find.byType(CategoryClaimsPage));
      expect(folkPage.category, equals(ClaimCategory.folklore));
      expect(folkPage.category, isNot(equals(histPage.category)));
    });

    testWidgets('11. Missing location does not redirect to Place Pops; opens destination fallback and only explicit trigger opens search dialog', (tester) async {
      final authRepo = MockHomeAuthRepo();
      authRepo.testUser = User(
        id: 'user-missing',
        displayName: 'Missing Place User',
        role: 'CONTRIBUTOR',
        joinedAt: DateTime(2026, 1, 1),
        selectedPlaceId: null,
        verifiedLocationId: null,
      );
      final authService = AuthService(repository: authRepo);
      authService.setSession(
        AuthTokens(
          accessToken: 'test-acc',
          refreshToken: 'test-ref',
          user: authRepo.testUser,
        ),
      );

      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      // Click Folklore category without selected location
      final card = find.text('Folklore / Proverb');
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();

      // Missing place data does not open LocationSearchDialog ("Place Pops")
      expect(find.byType(LocationSearchDialog), findsNothing);
      expect(find.byKey(const Key('home_no_location_card')), findsOneWidget);
      expect(find.text('No Location Selected'), findsOneWidget);
      expect(find.text('Please select a location using the location selector in the top header to view or contribute community knowledge.'), findsOneWidget);

      // Explicit trigger: tap single location selector in the Global Header
      final headerLocationBtn = find.byKey(const Key('header_location_selector'));
      expect(headerLocationBtn, findsOneWidget);
      await tester.tap(headerLocationBtn);
      await tester.pumpAndSettle();

      // Only explicit trigger opens LocationSearchDialog
      expect(find.byType(LocationSearchDialog), findsOneWidget);
      expect(find.byKey(const Key('location_search_prompt')), findsOneWidget);

      // Search for Jaipur
      await tester.enterText(find.byKey(const Key('location_search_input')), 'Jaipur');
      await tester.pumpAndSettle();

      // Select place from list
      expect(find.widgetWithText(ListTile, 'Jaipur'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Jaipur'));
      await tester.pumpAndSettle();

      // Dialog is dismissed and changing location returns central content to location Home view
      expect(find.byType(LocationSearchDialog), findsNothing);
      expect(find.text('Jaipur'), findsWidgets);
    });

    testWidgets('12. Location-Context Home displays location data and excludes category grid when location selected', (tester) async {
      final authService = createAuthServiceWithLocation();
      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      expect(find.text('Jaipur'), findsOneWidget);
      expect(find.byKey(const Key('header_selected_location')), findsOneWidget);
      expect(find.text('City / Town'), findsNothing);
      expect(find.text('Village'), findsNothing);
      expect(find.text('Community Knowledge Scope'), findsNothing);
      expect(find.text('Community Knowledge Score'), findsNothing);
      expect(find.byType(CommunityProgressCard), findsNothing);
      expect(find.text('Change Location'), findsNothing);
      expect(find.text('Browse by Category'), findsNothing);
      expect(find.text('Welcome to My Root'), findsNothing);
    });

    testWidgets('13. Enforce exactly one selected location display in Global Header across all in-place Function views', (tester) async {
      final authService = createAuthServiceWithLocation();
      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      // 1. Home content: Jaipur appears once in header only
      expect(find.text('Jaipur'), findsOneWidget);
      expect(find.byKey(const Key('header_selected_location')), findsOneWidget);

      // 2. Explore Stories view: Jaipur appears once in header only
      await openLeftDrawerAndTap(tester, const Key('feature_explore_stories'));
      expect(find.text('Jaipur'), findsOneWidget);
      expect(find.byKey(const Key('header_selected_location')), findsOneWidget);
      expect(find.text('Explore Stories'), findsOneWidget);
      await tester.tap(find.byKey(const Key('return_to_home_button')));
      await tester.pumpAndSettle();

      // 3. Contribute view: Jaipur appears once in header only
      await openLeftDrawerAndTap(tester, const Key('feature_contribute'));
      expect(find.text('Jaipur'), findsOneWidget);
      expect(find.byKey(const Key('header_selected_location')), findsOneWidget);
      expect(find.text('Contribute'), findsOneWidget);
      await tester.tap(find.byKey(const Key('return_to_home_button')));
      await tester.pumpAndSettle();

      // 4. Category view: Jaipur appears once in header only
      await openLeftDrawerAndTap(tester, const Key('feature_historical_record'));
      expect(find.text('Jaipur'), findsOneWidget);
      expect(find.byKey(const Key('header_selected_location')), findsOneWidget);
      expect(find.text('Historical Record'), findsOneWidget);
      await tester.tap(find.byKey(const Key('return_to_home_button')));
      await tester.pumpAndSettle();
    });

    testWidgets('14. Left drawer personalizes header with authenticated user profile and retains all 9 actions', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authService = createAuthServiceWithLocation();
      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      // Open left drawer
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Verify personalized header in HomeFeaturesDrawer
      expect(find.text('Features & Actions'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(HomeFeaturesDrawer),
          matching: find.text('Aarav Sharma'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(HomeFeaturesDrawer),
          matching: find.text('CONTRIBUTOR'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(HomeFeaturesDrawer),
          matching: find.text('A'),
        ),
        findsOneWidget,
      );

      // Verify all 9 feature actions remain present and accessible
      expect(find.byKey(const Key('feature_explore_stories')), findsOneWidget);
      expect(find.byKey(const Key('feature_contribute')), findsOneWidget);
      expect(find.byKey(const Key('feature_historical_record')), findsOneWidget);
      expect(find.byKey(const Key('feature_current_fact')), findsOneWidget);
      expect(find.byKey(const Key('feature_folklore')), findsOneWidget);
      expect(find.byKey(const Key('feature_personal_experience')), findsOneWidget);
      expect(find.byKey(const Key('feature_public_opinion')), findsOneWidget);
      expect(find.byKey(const Key('feature_survey_data')), findsOneWidget);
      expect(find.byKey(const Key('feature_add')), findsOneWidget);
    });

    testWidgets('15. Redundant Village tab and unused Scope UI are absent, Community Knowledge Score is removed from Home Page, Global Header shows user profile and location selector', (tester) async {
      final authService = createAuthServiceWithLocation(placeId: 'place-mandore-village');
      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      // 1. Proves redundant Home 'Village' tab/badge is absent
      expect(find.text('Village'), findsNothing);

      // 2. Proves unused 'Community Knowledge Scope' section is absent
      expect(find.text('Community Knowledge Scope'), findsNothing);

      // 3. Proves Community Knowledge Score card is absent from Home Page
      expect(find.text('Community Knowledge Score'), findsNothing);
      expect(find.byType(CommunityProgressCard), findsNothing);

      // 4. Proves selected location selector works and displays location in Global Header
      expect(find.byKey(const Key('header_selected_location')), findsOneWidget);
      expect(find.text('Mandore Village'), findsOneWidget);

      // 5. Proves Global Header displays user's real name and avatar fallback
      expect(find.byKey(const Key('header_user_display_name')), findsOneWidget);
      expect(find.text('Welcome, Aarav Sharma'), findsOneWidget);
      expect(find.byKey(const Key('header_user_avatar')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('header_user_avatar')),
          matching: find.text('A'),
        ),
        findsOneWidget,
      );
    });
  });
}
