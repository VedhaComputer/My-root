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
import 'package:my_root/ui/pages/claims/category_claims_page.dart';
import 'package:my_root/ui/pages/home/home_page.dart';
import 'package:my_root/ui/pages/places/place_detail_page.dart';
import 'package:my_root/ui/pages/places/progressive_contribution_page.dart';
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

class MockAuthRepo implements AuthRepository {
  User user = User(
    id: 'user-null-safety',
    displayName: 'Null Safety User',
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
      if (req.url.path.contains('/progress')) {
        return http.Response(
          jsonEncode({
            'data': {
              'placeId': 'place-jaipur-1',
              'placeName': 'Jaipur',
              'level': 'CITY_TOWN',
              'coverageScore': 50,
              'completionPercentage': 50.0,
              'totalAttributes': 10,
              'filledAttributes': 5,
              'totalClaims': 2,
              'verifiedClaims': 1,
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (req.url.path.contains('/attributes')) {
        return http.Response(
          jsonEncode({'data': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (req.url.path.contains('/claims')) {
        return http.Response(
          jsonEncode({'data': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (req.url.path.endsWith('/place-jaipur-1')) {
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'place-jaipur-1',
              'level': 'CITY_TOWN',
              'canonicalName': 'Jaipur',
              'names': [
                {'language': 'en', 'name': 'Jaipur'},
              ],
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (req.url.path.contains('/places')) {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'place-jaipur-1',
                'level': 'CITY_TOWN',
                'canonicalName': 'Jaipur',
                'names': [
                  {'language': 'en', 'name': 'Jaipur'},
                ],
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(jsonEncode({'data': []}), 200, headers: {'content-type': 'application/json'});
    };

    apiClient = ApiClient(client: mockHttp);
    mockAuthRepo = MockAuthRepo();
    authService = AuthService(repository: mockAuthRepo);
    placeService = PlaceService(repository: PlaceRepositoryImpl(client: apiClient));
    communityService = CommunityService(repository: CommunityRepositoryImpl(client: apiClient));
  });

  group('HomePage Null Check Safety Tests', () {
    testWidgets('1. Category claims view does not crash when place is null or not yet loaded', (tester) async {
      // User with selected place ID, but place object is not yet loaded in memory
      mockAuthRepo.user = mockAuthRepo.user.copyWith(selectedPlaceId: 'place-jaipur-1');
      authService.setSession(
        AuthTokens(
          accessToken: 'acc-1',
          refreshToken: 'ref-1',
          user: mockAuthRepo.user,
        ),
      );

      // Launch HomePage directly with categoryClaims view while place is initially null
      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
            initialActiveView: HomeActiveView.categoryClaims,
            initialCategory: ClaimCategory.historicalRecord,
          ),
        ),
      );

      // First frame: place is null and location is loading -> must not throw Null check operator used on null value
      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Settle async place resolution
      await tester.pumpAndSettle();

      // Resolved frame: CategoryClaimsPage renders cleanly with populated place
      expect(tester.takeException(), isNull);
      expect(find.byType(CategoryClaimsPage), findsOneWidget);
      final categoryPage = tester.widget<CategoryClaimsPage>(find.byType(CategoryClaimsPage));
      expect(categoryPage.placeId, equals('place-jaipur-1'));
      expect(categoryPage.placeName, equals('Jaipur'));
    });

    testWidgets('2. Fallback card is displayed when categoryClaims view is requested but no place is configured', (tester) async {
      // User without any place ID
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

      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
            initialActiveView: HomeActiveView.categoryClaims,
            initialCategory: ClaimCategory.folklore,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verified: No crash, renders fallback card indicating no location selected
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('home_no_location_card')), findsOneWidget);
      expect(find.text('No Location Selected'), findsOneWidget);

      // Fallback card displays explanatory message directing user to header selector
      expect(find.text('Please select a location using the location selector in the top header to view or contribute community knowledge.'), findsOneWidget);

      // Explicit trigger: tap single location selector in the Global Header
      final headerLocationBtn = find.byKey(const Key('header_location_selector'));
      expect(headerLocationBtn, findsOneWidget);
      await tester.tap(headerLocationBtn);
      await tester.pumpAndSettle();

      // LocationSearchDialog appears
      expect(find.byType(LocationSearchDialog), findsOneWidget);

      // Search and pick Jaipur
      await tester.enterText(find.byKey(const Key('location_search_input')), 'Jaipur');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Jaipur'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Jaipur'));
      await tester.pumpAndSettle();

      // Successfully updates location and returns central content to location Home view
      expect(find.text('Jaipur'), findsWidgets);
    });

    testWidgets('3. ExploreStories view does not crash when place is null or not yet available', (tester) async {
      mockAuthRepo.user = mockAuthRepo.user.copyWith(selectedPlaceId: 'place-jaipur-1');
      authService.setSession(
        AuthTokens(
          accessToken: 'acc-1',
          refreshToken: 'ref-1',
          user: mockAuthRepo.user,
        ),
      );

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

      // Frame 1: must not crash
      expect(tester.takeException(), isNull);

      // Settle
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(PlaceDetailPage), findsOneWidget);
    });

    testWidgets('4. Contribute view does not crash when place is null or not yet available', (tester) async {
      mockAuthRepo.user = mockAuthRepo.user.copyWith(selectedPlaceId: 'place-jaipur-1');
      authService.setSession(
        AuthTokens(
          accessToken: 'acc-1',
          refreshToken: 'ref-1',
          user: mockAuthRepo.user,
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
            initialActiveView: HomeActiveView.contribute,
          ),
        ),
      );

      // Frame 1: must not crash
      expect(tester.takeException(), isNull);

      // Settle
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ProgressiveContributionPage), findsOneWidget);
    });

    testWidgets('5. Add view does not crash when place is null or not yet available', (tester) async {
      mockAuthRepo.user = mockAuthRepo.user.copyWith(selectedPlaceId: 'place-jaipur-1');
      authService.setSession(
        AuthTokens(
          accessToken: 'acc-1',
          refreshToken: 'ref-1',
          user: mockAuthRepo.user,
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
            communityService: communityService,
            initialActiveView: HomeActiveView.add,
          ),
        ),
      );

      // Frame 1: must not crash
      expect(tester.takeException(), isNull);

      // Settle
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ProgressiveContributionPage), findsOneWidget);
    });
  });
}
