import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/auth_dtos.dart';
import 'package:my_root/models/user.dart';
import 'package:my_root/models/user_activity.dart';
import 'package:my_root/repositories/auth_repository.dart';
import 'package:my_root/repositories/community_repository.dart';
import 'package:my_root/repositories/place_repository.dart';
import 'package:my_root/services/auth_service.dart';
import 'package:my_root/services/community_service.dart';
import 'package:my_root/services/place_service.dart';
import 'package:my_root/ui/pages/auth/login_page.dart';
import 'package:my_root/ui/pages/home/home_page.dart';
import 'package:my_root/ui/pages/profile/profile_page.dart';
import 'package:my_root/ui/pages/places/place_detail_page.dart';
import 'package:my_root/ui/widgets/home_features_drawer.dart';

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

class MockAuthRepo implements AuthRepository {
  User user = User(
    id: 'user-auth-101',
    displayName: 'Test Explorer',
    role: 'CONTRIBUTOR',
    joinedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
  );

  @override
  Future<ApiResponse<AuthTokens>> login(String email, String password) async {
    return ApiResponse.success(
      AuthTokens(
        accessToken: 'access-101',
        refreshToken: 'refresh-101',
        user: user,
      ),
    );
  }

  @override
  Future<ApiResponse<User>> getMe() async => ApiResponse.success(user);

  @override
  Future<ApiResponse<User>> updateSelectedPlace(String? placeId) async {
    user = user.copyWith(selectedPlaceId: placeId);
    return ApiResponse.success(user);
  }

  @override
  Future<ApiResponse<User>> updateMatrbhoomiInterest({
    required String placeId,
    bool? knowsHistory,
    bool? wantsToLearn,
  }) async {
    return ApiResponse.success(user);
  }

  @override
  Future<ApiResponse<AuthTokens>> refreshToken(String refreshToken) async {
    return ApiResponse.success(
      AuthTokens(
        accessToken: 'access-102',
        refreshToken: 'refresh-102',
        user: user,
      ),
    );
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> logout({String? refreshToken}) async {
    return const ApiResponse.success({'message': 'Logged out'});
  }

  @override
  Future<ApiResponse<RegisterResponse>> register(
      String displayName, String email, String password) async {
    return const ApiResponse.success(RegisterResponse(message: 'ok'));
  }

  @override
  Future<ApiResponse<MessageResponse>> resendVerificationEmail(String email) async {
    return const ApiResponse.success(MessageResponse(message: 'ok'));
  }

  @override
  Future<ApiResponse<MessageResponse>> verifyEmail(String token) async {
    return const ApiResponse.success(MessageResponse(message: 'ok'));
  }

  @override
  Future<ApiResponse<MessageResponse>> requestPasswordReset(String email) async {
    return const ApiResponse.success(MessageResponse(message: 'ok'));
  }

  @override
  Future<ApiResponse<MessageResponse>> resetPassword(String token, String newPassword) async {
    return const ApiResponse.success(MessageResponse(message: 'ok'));
  }

  @override
  Future<ApiResponse<UserActivity>> getUserActivity() async {
    return const ApiResponse.success(
      UserActivity(
        summary: UserActivitySummary(
          totalContributions: 0,
          claimsCount: 0,
          evidencesCount: 0,
          placesCount: 0,
          placeAttributesCount: 0,
        ),
        claims: [],
        evidences: [],
        places: [],
        placeAttributes: [],
      ),
    );
  }

  @override
  Future<ApiResponse<List<PublicUser>>> getLatestUsers() async {
    return const ApiResponse.success([]);
  }
}

Widget createTestApp({
  required Widget child,
}) {
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

  late MockHttpClient mockHttp;
  late ApiClient apiClient;
  late MockAuthRepo mockAuthRepo;
  late AuthService authService;
  late PlaceService placeService;
  late CommunityService communityService;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    mockHttp = MockHttpClient();
    mockHttp.handler = (req) {
      if (req.url.path.contains('/children')) {
        return http.Response(jsonEncode({'data': []}), 200, headers: {'content-type': 'application/json'});
      }
      if (req.url.path.contains('/attributes')) {
        return http.Response(jsonEncode({'data': []}), 200, headers: {'content-type': 'application/json'});
      }
      if (req.url.path.contains('/progress')) {
        return http.Response(jsonEncode({'data': {}}), 200, headers: {'content-type': 'application/json'});
      }
      if (req.url.path.contains('/places')) {
        final placeJson = {
          'id': 'place-test-1',
          'level': 'CITY_TOWN',
          'canonicalName': 'Jaipur',
          'names': [
            {'language': 'en', 'name': 'Jaipur'},
          ],
        };
        return http.Response(
          jsonEncode({
            'data': placeJson,
            'places': [placeJson],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (req.url.path.contains('/claims')) {
        return http.Response(
          jsonEncode({'claims': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"status": "ok"}', 200, headers: {'content-type': 'application/json'});
    };

    apiClient = ApiClient(client: mockHttp);
    mockAuthRepo = MockAuthRepo();
    authService = AuthService(repository: mockAuthRepo);
    placeService = PlaceService(repository: PlaceRepositoryImpl(client: apiClient));
    communityService = CommunityService(repository: CommunityRepositoryImpl(client: apiClient));
  });

  group('Post-Login Navigation and Shared Sidebar', () {
    testWidgets('1. Successful login navigates directly to HomePage instead of ProfilePage', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: LoginPage(authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
      expect(find.byType(ProfilePage), findsNothing);

      // Fill in credentials using TextFormField
      expect(find.byType(TextFormField), findsNWidgets(2));
      await tester.enterText(find.byType(TextFormField).at(0), 'explorer@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'validpassword123');

      // Submit login form
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Verified: Destination is HomePage, NOT ProfilePage
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(ProfilePage), findsNothing);
    });

    testWidgets('2. Sidebar is accessible on HomePage with Home, Profile, and all implemented features', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      authService.setSession(
        AuthTokens(
          accessToken: 'acc-1',
          refreshToken: 'ref-1',
          user: mockAuthRepo.user,
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          child: HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open left sidebar via menu button
      final drawerBtn = find.byKey(const Key('home_features_drawer_button'));
      expect(drawerBtn, findsOneWidget);
      await tester.tap(drawerBtn);
      await tester.pumpAndSettle();

      // Verify sidebar drawer is visible
      expect(find.byType(HomeFeaturesDrawer), findsOneWidget);

      // Verify Home navigation item is present, and Profile item is removed from sidebar (Requirement 1)
      expect(find.byKey(const Key('feature_home')), findsOneWidget);
      expect(find.byKey(const Key('feature_profile')), findsNothing);

      // Verify all 9 functional/category items remain present
      expect(find.byKey(const Key('feature_explore_stories')), findsOneWidget);
      expect(find.byKey(const Key('feature_contribute')), findsOneWidget);
      expect(find.byKey(const Key('feature_historical_record')), findsOneWidget);
      expect(find.byKey(const Key('feature_current_fact')), findsOneWidget);
      expect(find.byKey(const Key('feature_folklore')), findsOneWidget);
      expect(find.byKey(const Key('feature_personal_experience')), findsOneWidget);
      expect(find.byKey(const Key('feature_public_opinion')), findsOneWidget);
      expect(find.byKey(const Key('feature_survey_data')), findsOneWidget);
      expect(find.byKey(const Key('feature_add')), findsOneWidget);

      // Verify active item highlight on HomePage: Home is selected
      final homeTile = tester.widget<ListTile>(find.byKey(const Key('feature_home')));
      expect(homeTile.selected, isTrue);
    });

    testWidgets('3. Sidebar is accessible on ProfilePage without Profile tile and Home not highlighted', (tester) async {
      authService.setSession(
        AuthTokens(
          accessToken: 'acc-1',
          refreshToken: 'ref-1',
          user: mockAuthRepo.user,
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          child: ProfilePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open left sidebar via menu button on ProfilePage
      final drawerBtn = find.byKey(const Key('home_features_drawer_button'));
      expect(drawerBtn, findsOneWidget);
      await tester.tap(drawerBtn);
      await tester.pumpAndSettle();

      // Verify sidebar drawer is visible on ProfilePage
      expect(find.byType(HomeFeaturesDrawer), findsOneWidget);
      expect(find.byKey(const Key('feature_home')), findsOneWidget);
      expect(find.byKey(const Key('feature_profile')), findsNothing);

      // Verify Home is not highlighted on ProfilePage
      final homeTile = tester.widget<ListTile>(find.byKey(const Key('feature_home')));
      expect(homeTile.selected, isFalse);
    });

    testWidgets('4. Bidirectional navigation: HomePage -> ProfilePage via header -> HomePage via sidebar', (tester) async {
      authService.setSession(
        AuthTokens(
          accessToken: 'acc-1',
          refreshToken: 'ref-1',
          user: mockAuthRepo.user,
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          child: HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Open Profile via Header Avatar menu
      final avatarBtn = find.byKey(const Key('header_user_avatar'));
      expect(avatarBtn, findsOneWidget);
      await tester.tap(avatarBtn);
      await tester.pumpAndSettle();
      await tester.tap(find.text('User Profile'));
      await tester.pumpAndSettle();

      // Verified: Navigated to ProfilePage in-place
      expect(find.byType(ProfilePage), findsOneWidget);

      // 2. Open drawer on ProfilePage
      await tester.tap(find.byKey(const Key('home_features_drawer_button')));
      await tester.pumpAndSettle();

      // 3. Tap Home in drawer
      await tester.tap(find.byKey(const Key('feature_home')));
      await tester.pumpAndSettle();

      // Verified: Successfully returned to HomePage
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('5. Bidirectional navigation: ProfilePage back button returns to HomePage', (tester) async {
      authService.setSession(
        AuthTokens(
          accessToken: 'acc-1',
          refreshToken: 'ref-1',
          user: mockAuthRepo.user,
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          child: HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate HomePage -> ProfilePage via Header Avatar menu
      final avatarBtn = find.byKey(const Key('header_user_avatar'));
      expect(avatarBtn, findsOneWidget);
      await tester.tap(avatarBtn);
      await tester.pumpAndSettle();
      await tester.tap(find.text('User Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(ProfilePage), findsOneWidget);

      // Verify back button is present in ProfilePage AppBar
      final backBtn = find.byKey(const Key('profile_back_button'));
      expect(backBtn, findsOneWidget);

      // Tap back button
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // Verified: Returned to HomePage
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('6. Navigating from ProfilePage drawer features opens HomePage in requested view', (tester) async {
      mockAuthRepo.user = mockAuthRepo.user.copyWith(selectedPlaceId: 'place-test-1');
      authService.setSession(
        AuthTokens(
          accessToken: 'acc-1',
          refreshToken: 'ref-1',
          user: mockAuthRepo.user,
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          child: HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open ProfilePage via Header Avatar menu
      final avatarBtn = find.byKey(const Key('header_user_avatar'));
      expect(avatarBtn, findsOneWidget);
      await tester.tap(avatarBtn);
      await tester.pumpAndSettle();
      await tester.tap(find.text('User Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(ProfilePage), findsOneWidget);

      // Open drawer on ProfilePage and tap Explore Stories
      await tester.tap(find.byKey(const Key('home_features_drawer_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('feature_explore_stories')));
      await tester.pumpAndSettle();

      // Verified: Lands on HomePage in Explore Stories view
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(PlaceDetailPage), findsOneWidget);
      expect(find.text('Explore Stories'), findsWidgets);
    });

    testWidgets('7. Logout from ProfilePage clears authenticated session', (tester) async {
      authService.setSession(
        AuthTokens(
          accessToken: 'acc-1',
          refreshToken: 'ref-1',
          user: mockAuthRepo.user,
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          child: ProfilePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap logout in AppBar
      final logoutBtn = find.byIcon(Icons.logout);
      expect(logoutBtn, findsOneWidget);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Confirm Sign Out'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
      await tester.pumpAndSettle();

      // Verified: Session is cleared and user is redirected to unauthenticated state
      expect(authService.isAuthenticated, isFalse);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('8. Route guard: Unauthenticated user on ProfilePage sees guard message without sidebar', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: ProfilePage(
            authService: authService, // Unauthenticated
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Shows guard text
      expect(find.text('No authenticated session found.'), findsOneWidget);
      // Drawer button is not rendered when unauthenticated
      expect(find.byKey(const Key('home_features_drawer_button')), findsNothing);
    });
  });
}
