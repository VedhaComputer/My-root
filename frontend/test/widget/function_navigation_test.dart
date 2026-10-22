import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_root/core/constants.dart';
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
import 'package:my_root/ui/pages/claims/category_claims_page.dart';
import 'package:my_root/ui/pages/home/home_page.dart';
import 'package:my_root/ui/pages/places/place_detail_page.dart';
import 'package:my_root/ui/pages/places/places_page.dart';
import 'package:my_root/ui/pages/places/progressive_contribution_page.dart';
import 'package:my_root/ui/pages/profile/profile_page.dart';
import 'package:my_root/ui/widgets/home_features_drawer.dart';
import 'package:my_root/ui/widgets/location_search_dialog.dart';

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

class MockAuthRepo extends AuthRepositoryImpl {
  MockAuthRepo({required super.client});

  User user = User(
    id: 'user-nav-1',
    displayName: 'Navigation Tester',
    role: 'CONTRIBUTOR',
    joinedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
  );

  @override
  Future<ApiResponse<AuthTokens>> login(String email, String password) async =>
      ApiResponse.success(AuthTokens(accessToken: 'acc', refreshToken: 'ref', user: user));

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
  }) async => ApiResponse.success(user);

  @override
  Future<ApiResponse<AuthTokens>> refreshToken(String refreshToken) async =>
      ApiResponse.success(AuthTokens(accessToken: 'acc-2', refreshToken: 'ref-2', user: user));

  @override
  Future<ApiResponse<Map<String, dynamic>>> logout({String? refreshToken}) async =>
      const ApiResponse.success({'message': 'Logged out'});

  @override
  Future<ApiResponse<RegisterResponse>> register(
      String displayName, String email, String password) async =>
      const ApiResponse.success(RegisterResponse(message: 'ok'));

  @override
  Future<ApiResponse<MessageResponse>> resendVerificationEmail(String email) async =>
      const ApiResponse.success(MessageResponse(message: 'ok'));

  @override
  Future<ApiResponse<MessageResponse>> verifyEmail(String token) async =>
      const ApiResponse.success(MessageResponse(message: 'ok'));

  @override
  Future<ApiResponse<MessageResponse>> requestPasswordReset(String email) async =>
      const ApiResponse.success(MessageResponse(message: 'ok'));

  @override
  Future<ApiResponse<MessageResponse>> resetPassword(String token, String newPassword) async =>
      const ApiResponse.success(MessageResponse(message: 'ok'));

  @override
  Future<ApiResponse<UserActivity>> getUserActivity() async => const ApiResponse.success(
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

  @override
  Future<ApiResponse<List<PublicUser>>> getLatestUsers() async =>
      const ApiResponse.success([]);
}

Widget createTestApp(Widget child) {
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
      if (req.url.path.contains('/claims')) {
        return http.Response(jsonEncode({'data': []}), 200, headers: {'content-type': 'application/json'});
      }
      if (req.url.path.endsWith('/places')) {
        final placeJson = {
          'id': 'place-jaipur-1',
          'level': 'CITY_TOWN',
          'canonicalName': 'Jaipur',
          'names': [
            {'language': 'en', 'name': 'Jaipur'},
          ],
        };
        return http.Response(
          jsonEncode({
            'data': [placeJson],
            'places': [placeJson],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (req.url.path.contains('/places/')) {
        final placeJson = {
          'id': 'place-jaipur-1',
          'level': 'CITY_TOWN',
          'canonicalName': 'Jaipur',
          'names': [
            {'language': 'en', 'name': 'Jaipur'},
          ],
        };
        return http.Response(
          jsonEncode({
            'data': placeJson,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(jsonEncode({'data': []}), 200, headers: {'content-type': 'application/json'});
    };

    apiClient = ApiClient(client: mockHttp);
    mockAuthRepo = MockAuthRepo(client: apiClient);
    authService = AuthService(repository: mockAuthRepo);
    placeService = PlaceService(repository: PlaceRepositoryImpl(client: apiClient));
    communityService = CommunityService(repository: CommunityRepositoryImpl(client: apiClient));
  });

  Future<void> openDrawerAndTap(WidgetTester tester, Key itemKey) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold).first);
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();
    expect(find.byType(HomeFeaturesDrawer), findsOneWidget);

    final item = find.byKey(itemKey);
    expect(item, findsOneWidget);
    await tester.ensureVisible(item);
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  group('Function Navigation Destination Tests (Location Configured)', () {
    setUp(() {
      mockAuthRepo.user = mockAuthRepo.user.copyWith(selectedPlaceId: 'place-jaipur-1');
      authService.setSession(
        AuthTokens(
          accessToken: 'acc-1',
          refreshToken: 'ref-1',
          user: mockAuthRepo.user,
        ),
      );
    });

    testWidgets('1. Home opens Home view (locationHome) and retains selected place', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
            initialActiveView: HomeActiveView.exploreStories,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PlaceDetailPage), findsOneWidget);

      await openDrawerAndTap(tester, const Key('feature_home'));

      expect(find.byType(PlaceDetailPage), findsNothing);
      expect(find.byType(LocationSearchDialog), findsNothing);
      expect(find.byKey(const Key('home_no_location_card')), findsNothing);
      expect(find.text('Jaipur'), findsWidgets);
    });

    testWidgets('1b. After login, Home opens directly and previously selected place remains selected', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          LoginPage(
            authService: authService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), 'tester@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Navigates directly to HomePage
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(ProfilePage), findsNothing);
      // Previously selected place remains selected
      expect(find.text('Jaipur'), findsWidgets);
      expect(find.byKey(const Key('home_no_location_card')), findsNothing);
    });

    testWidgets('2. Profile is removed from drawer; opens ProfilePage in-place via header menu', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Profile is removed from sidebar drawer
      final drawerBtn = find.byKey(const Key('home_features_drawer_button'));
      await tester.tap(drawerBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feature_profile')), findsNothing);
      // Close drawer by tapping outside
      await tester.tapAt(const Offset(700, 300));
      await tester.pumpAndSettle();

      // Open Profile in-place via Global Header avatar menu
      final avatarBtn = find.byKey(const Key('header_user_avatar'));
      expect(avatarBtn, findsOneWidget);
      await tester.tap(avatarBtn);
      await tester.pumpAndSettle();
      await tester.tap(find.text('User Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(find.byType(LocationSearchDialog), findsNothing);
    });

    testWidgets('2b. LatestUsersDrawer does not contain duplicate location selector', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open LatestUsersDrawer via end drawer button
      final drawerBtn = find.byKey(const Key('latest_users_drawer_button'));
      expect(drawerBtn, findsOneWidget);
      await tester.tap(drawerBtn);
      await tester.pumpAndSettle();

      // Verified: Home link is present, but duplicate Places / Localities selector is removed
      expect(find.widgetWithText(ListTile, 'Home'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Places'), findsNothing);
      expect(find.byType(LocationSearchDialog), findsNothing);
    });

    testWidgets('2c. Profile does not duplicate Global Header location selector or display Selected Place card', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          ProfilePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified: Profile does not display duplicate Selected Place card
      expect(find.text('Selected Place'), findsNothing);
      expect(find.text('No Location Selected'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(find.byType(LocationSearchDialog), findsNothing);
    });

    testWidgets('3. Explore Stories opens PlaceDetailPage with real content and no fallback card', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openDrawerAndTap(tester, const Key('feature_explore_stories'));

      expect(find.byType(PlaceDetailPage), findsOneWidget);
      expect(find.byKey(const Key('home_no_location_card')), findsNothing);
      expect(find.byType(LocationSearchDialog), findsNothing);
      expect(find.byType(PlacesPage), findsNothing);
      expect(find.text('Explore Stories'), findsWidgets);
    });

    testWidgets('4. Contribute opens ProgressiveContributionPage with real wizard and no fallback card', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openDrawerAndTap(tester, const Key('feature_contribute'));

      expect(find.byType(ProgressiveContributionPage), findsOneWidget);
      expect(find.byKey(const Key('home_no_location_card')), findsNothing);
      expect(find.byType(LocationSearchDialog), findsNothing);
    });

    testWidgets('5. Historical Record opens CategoryClaimsPage with historicalRecord and no fallback card', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openDrawerAndTap(tester, const Key('feature_historical_record'));

      expect(find.byType(CategoryClaimsPage), findsOneWidget);
      final page = tester.widget<CategoryClaimsPage>(find.byType(CategoryClaimsPage));
      expect(page.category, equals(ClaimCategory.historicalRecord));
      expect(find.byKey(const Key('home_no_location_card')), findsNothing);
      expect(find.byType(LocationSearchDialog), findsNothing);
    });

    testWidgets('6. Current Fact opens CategoryClaimsPage with currentFact and no fallback card', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openDrawerAndTap(tester, const Key('feature_current_fact'));

      expect(find.byType(CategoryClaimsPage), findsOneWidget);
      final page = tester.widget<CategoryClaimsPage>(find.byType(CategoryClaimsPage));
      expect(page.category, equals(ClaimCategory.currentFact));
      expect(find.byKey(const Key('home_no_location_card')), findsNothing);
      expect(find.byType(LocationSearchDialog), findsNothing);
    });

    testWidgets('7. Folklore opens CategoryClaimsPage with folklore and no fallback card', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openDrawerAndTap(tester, const Key('feature_folklore'));

      expect(find.byType(CategoryClaimsPage), findsOneWidget);
      final page = tester.widget<CategoryClaimsPage>(find.byType(CategoryClaimsPage));
      expect(page.category, equals(ClaimCategory.folklore));
      expect(find.byKey(const Key('home_no_location_card')), findsNothing);
      expect(find.byType(LocationSearchDialog), findsNothing);
    });

    testWidgets('8. Personal Experience opens CategoryClaimsPage with personalExperience and no fallback card', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openDrawerAndTap(tester, const Key('feature_personal_experience'));

      expect(find.byType(CategoryClaimsPage), findsOneWidget);
      final page = tester.widget<CategoryClaimsPage>(find.byType(CategoryClaimsPage));
      expect(page.category, equals(ClaimCategory.personalExperience));
      expect(find.byKey(const Key('home_no_location_card')), findsNothing);
      expect(find.byType(LocationSearchDialog), findsNothing);
    });

    testWidgets('9. Public Opinion opens CategoryClaimsPage with publicOpinion and no fallback card', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openDrawerAndTap(tester, const Key('feature_public_opinion'));

      expect(find.byType(CategoryClaimsPage), findsOneWidget);
      final page = tester.widget<CategoryClaimsPage>(find.byType(CategoryClaimsPage));
      expect(page.category, equals(ClaimCategory.publicOpinion));
      expect(find.byKey(const Key('home_no_location_card')), findsNothing);
      expect(find.byType(LocationSearchDialog), findsNothing);
    });

    testWidgets('10. Survey Data opens CategoryClaimsPage with surveyData and no fallback card', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openDrawerAndTap(tester, const Key('feature_survey_data'));

      expect(find.byType(CategoryClaimsPage), findsOneWidget);
      final page = tester.widget<CategoryClaimsPage>(find.byType(CategoryClaimsPage));
      expect(page.category, equals(ClaimCategory.surveyData));
      expect(find.byKey(const Key('home_no_location_card')), findsNothing);
      expect(find.byType(LocationSearchDialog), findsNothing);
    });

    testWidgets('11. Add opens ProgressiveContributionPage with real wizard and no fallback card', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openDrawerAndTap(tester, const Key('feature_add'));

      expect(find.byType(ProgressiveContributionPage), findsOneWidget);
      expect(find.byKey(const Key('home_no_location_card')), findsNothing);
      expect(find.byType(LocationSearchDialog), findsNothing);
    });

    testWidgets('12. Explicit trigger: Tapping header location button opens LocationSearchDialog', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final headerLocationBtn = find.byKey(const Key('header_selected_location'));
      expect(headerLocationBtn, findsOneWidget);
      await tester.tap(headerLocationBtn);
      await tester.pumpAndSettle();

      expect(find.byType(LocationSearchDialog), findsOneWidget);
    });
  });

  group('Function Navigation When Location Unselected / Missing', () {
    setUp(() {
      mockAuthRepo.user = mockAuthRepo.user.copyWith(
        selectedPlaceId: null,
        verifiedLocationId: null,
      );
      authService.setSession(
        AuthTokens(
          accessToken: 'acc-1',
          refreshToken: 'ref-1',
          user: mockAuthRepo.user,
        ),
      );
    });

    testWidgets('13. Missing location does not pop up Place Pops for Explore Stories', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openDrawerAndTap(tester, const Key('feature_explore_stories'));

      // Does NOT pop up LocationSearchDialog
      expect(find.byType(LocationSearchDialog), findsNothing);
      expect(find.byType(PlacesPage), findsNothing);
      // Renders in-place fallback card safely
      expect(find.byKey(const Key('home_no_location_card')), findsOneWidget);
    });

    testWidgets('14. Missing location does not pop up Place Pops for Categories', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openDrawerAndTap(tester, const Key('feature_folklore'));

      // Does NOT pop up LocationSearchDialog
      expect(find.byType(LocationSearchDialog), findsNothing);
      expect(find.byType(PlacesPage), findsNothing);
      expect(find.byKey(const Key('home_no_location_card')), findsOneWidget);
    });

    testWidgets('15. Selecting function remains stable after async location loading completes', (tester) async {
      // User with place ID configured
      mockAuthRepo.user = mockAuthRepo.user.copyWith(selectedPlaceId: 'place-jaipur-1');
      authService.setSession(
        AuthTokens(
          accessToken: 'acc-1',
          refreshToken: 'ref-1',
          user: mockAuthRepo.user,
        ),
      );

      // Launch with initialActiveView before async location load completes
      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
            initialActiveView: HomeActiveView.exploreStories,
          ),
        ),
      );

      // Verify no exception on frame 1
      expect(tester.takeException(), isNull);

      // Settle async location resolution
      await tester.pumpAndSettle();

      // Active view remained stable and resolved into PlaceDetailPage
      expect(find.byType(PlaceDetailPage), findsOneWidget);
      expect(find.byType(LocationSearchDialog), findsNothing);
    });
  });
}
