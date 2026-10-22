import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/auth_dtos.dart';
import 'package:my_root/models/place.dart';
import 'package:my_root/models/user.dart';
import 'package:my_root/models/user_activity.dart';
import 'package:my_root/repositories/auth_repository.dart';
import 'package:my_root/services/auth_service.dart';
import 'package:my_root/ui/card/place_status_card.dart';
import 'package:my_root/ui/pages/home/home_page.dart';

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

class MockLocationHomeAuthRepo implements AuthRepository {
  User testUser = User(
    id: 'user-loc-1',
    displayName: 'Aditi Verma',
    role: 'CONTRIBUTOR',
    joinedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
    selectedPlaceId: 'place-village-1',
  );

  @override
  Future<ApiResponse<AuthTokens>> login(String email, String password) async =>
      ApiResponse.success(AuthTokens(accessToken: 'acc', refreshToken: 'ref', user: testUser));

  @override
  Future<ApiResponse<User>> getMe() async => ApiResponse.success(testUser);

  @override
  Future<ApiResponse<User>> updateSelectedPlace(String? placeId) async {
    testUser = testUser.copyWith(selectedPlaceId: placeId);
    return ApiResponse.success(testUser);
  }

  @override
  Future<ApiResponse<User>> updateMatrbhoomiInterest({
    required String placeId,
    bool? knowsHistory,
    bool? wantsToLearn,
  }) async => ApiResponse.success(testUser);

  @override
  Future<ApiResponse<AuthTokens>> refreshToken(String refreshToken) async =>
      ApiResponse.success(AuthTokens(accessToken: 'acc2', refreshToken: 'ref2', user: testUser));

  @override
  Future<ApiResponse<Map<String, dynamic>>> logout({String? refreshToken}) async =>
      const ApiResponse.success({'message': 'Logged out'});

  @override
  Future<ApiResponse<RegisterResponse>> register(String displayName, String email, String password) async =>
      const ApiResponse.success(RegisterResponse(message: 'Registered'));

  @override
  Future<ApiResponse<UserActivity>> getUserActivity() async =>
      const ApiResponse.success(UserActivity(
        summary: UserActivitySummary(totalContributions: 0, claimsCount: 0, evidencesCount: 0, placesCount: 0, placeAttributesCount: 0),
        claims: [],
        evidences: [],
        places: [],
        placeAttributes: [],
      ));

  @override
  Future<ApiResponse<List<PublicUser>>> getLatestUsers() async => const ApiResponse.success([]);

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

  group('Location-Centric Home Content Tests', () {
    late MockHttpClient mockHttp;
    late ApiClient apiClient;

    void configureMockHttp({
      Place? place,
      List<dynamic>? attributes,
      List<dynamic>? claims,
    }) {
      mockHttp.handler = (req) {
        if (req.url.path.endsWith('/progress')) {
          return http.Response(
            jsonEncode({
              'data': {
                'placeId': place?.id ?? 'place-village-1',
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
        if (req.url.path.endsWith('/children')) {
          return http.Response(
            jsonEncode({'data': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path.endsWith('/attributes')) {
          return http.Response(
            jsonEncode({'data': attributes ?? []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path.contains('/claims')) {
          final claimList = claims ?? [];
          return http.Response(
            jsonEncode({
              'data': claimList,
              'pagination': {'page': 1, 'limit': 10, 'total': claimList.length, 'pages': 1},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path.contains('/places/')) {
          return http.Response(
            jsonEncode({
              'data': place?.toJson() ?? {
                'id': 'place-village-1',
                'canonicalName': 'Sundarpur',
                'level': 'VILLAGE',
                'names': [{'language': 'en', 'name': 'Sundarpur'}],
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"data": []}', 200, headers: {'content-type': 'application/json'});
      };
    }

    setUp(() {
      mockHttp = MockHttpClient();
      apiClient = ApiClient(client: mockHttp);
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

    testWidgets('1. Content displays all 5 sections in strict A -> B -> C -> D -> E order', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authRepo = MockLocationHomeAuthRepo();
      final authService = AuthService(repository: authRepo);
      authService.setSession(
        AuthTokens(accessToken: 'acc', refreshToken: 'ref', user: authRepo.testUser),
      );

      configureMockHttp(
        place: const Place(
          id: 'place-village-1',
          canonicalName: 'Sundarpur',
          level: 'VILLAGE',
          names: [PlaceName(language: 'en', name: 'Sundarpur')],
          parentPath: [
            PlacePathItem(id: 'place-dist', level: 'DISTRICT', canonicalName: 'Varanasi District'),
            PlacePathItem(id: 'place-state', level: 'STATE', canonicalName: 'Uttar Pradesh'),
          ],
        ),
        attributes: [
          {
            'id': 'attr-1',
            'placeId': 'place-village-1',
            'category': 'population',
            'key': 'total_population',
            'value': '4,520 Residents',
            'sourceDescription': 'Census of India',
            'reportedPeriod': '2011',
            'uncertainty': null,
            'createdAt': '2026-01-01T00:00:00.000Z',
          },
          {
            'id': 'attr-2',
            'placeId': 'place-village-1',
            'category': 'facility',
            'key': 'primary_health_centre',
            'value': 'Sundarpur Sub-centre with 4 beds',
            'sourceDescription': 'District Health Department',
            'reportedPeriod': '2023',
            'uncertainty': null,
            'createdAt': '2026-01-01T00:00:00.000Z',
          },
        ],
        claims: [
          {
            'id': 'claim-h1',
            'title': {'original': 'Settlement of Sundarpur', 'language': 'en'},
            'body': {'original': 'Founded in the 17th century near the river.', 'language': 'en'},
            'category': 'HISTORICAL_RECORD',
            'status': 'verified',
            'locationId': 'place-village-1',
            'submittedAt': '2026-01-01T00:00:00.000Z',
            'evidenceCount': 3,
            'isPublic': true,
            'tags': ['history', 'origin'],
          },
          {
            'id': 'claim-f1',
            'title': {'original': 'Proverb of the Banyan Well', 'language': 'en'},
            'body': {'original': 'Traditional proverb regarding seasonal monsoon rain.', 'language': 'en'},
            'category': 'FOLKLORE',
            'status': 'unverified',
            'locationId': 'place-village-1',
            'submittedAt': '2026-01-02T00:00:00.000Z',
            'evidenceCount': 0,
            'isPublic': true,
            'tags': ['proverb'],
          },
          {
            'id': 'claim-c1',
            'title': {'original': 'Local Pottery Artisan Workshop', 'language': 'en'},
            'body': {'original': 'Community artisan group producing terracotta vessels.', 'language': 'en'},
            'category': 'CURRENT_FACT',
            'status': 'verified',
            'locationId': 'place-village-1',
            'submittedAt': '2026-01-03T00:00:00.000Z',
            'evidenceCount': 1,
            'isPublic': true,
            'tags': ['artisans'],
          },
        ],
      );

      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      // Find all 5 section headers by their keys
      final secA = find.byKey(const Key('section_current_status'));
      final secB = find.byKey(const Key('section_local_history'));
      final secC = find.byKey(const Key('section_folklore_traditions'));
      final secD = find.byKey(const Key('section_development_facilities'));
      final secE = find.byKey(const Key('section_community_knowledge'));

      expect(secA, findsOneWidget);
      expect(secB, findsOneWidget);
      expect(secC, findsOneWidget);
      expect(secD, findsOneWidget);
      expect(secE, findsOneWidget);

      // Verify strict vertical order: A is above B, B above C, C above D, D above E
      final posA = tester.getTopLeft(secA).dy;
      final posB = tester.getTopLeft(secB).dy;
      final posC = tester.getTopLeft(secC).dy;
      final posD = tester.getTopLeft(secD).dy;
      final posE = tester.getTopLeft(secE).dy;

      expect(posA, lessThan(posB), reason: 'Section A must appear before Section B');
      expect(posB, lessThan(posC), reason: 'Section B must appear before Section C');
      expect(posC, lessThan(posD), reason: 'Section C must appear before Section D');
      expect(posD, lessThan(posE), reason: 'Section D must appear before Section E');
    });

    testWidgets('2. Village structure displays only rural offices (Sarpanch, Ward Member, MLA, MP) and excludes urban offices', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authRepo = MockLocationHomeAuthRepo();
      final authService = AuthService(repository: authRepo);
      authService.setSession(
        AuthTokens(accessToken: 'acc', refreshToken: 'ref', user: authRepo.testUser),
      );

      configureMockHttp(
        place: const Place(
          id: 'place-village-1',
          canonicalName: 'Sundarpur',
          level: 'VILLAGE',
          names: [PlaceName(language: 'en', name: 'Sundarpur')],
        ),
      );

      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      // Applicable rural offices must be listed
      expect(find.textContaining('Sarpanch (Gram Panchayat Head)'), findsOneWidget);
      expect(find.textContaining('Ward Member (Panch)'), findsOneWidget);
      expect(find.textContaining('Member of Legislative Assembly (MLA)'), findsOneWidget);
      expect(find.textContaining('Member of Parliament (MP)'), findsOneWidget);

      // Urban offices must NOT be shown for a village
      expect(find.textContaining('Municipal Chairperson / Mayor'), findsNothing);
      expect(find.textContaining('Ward Councillor / Municipal Member'), findsNothing);
    });

    testWidgets('3. City structure displays only urban offices (Mayor, Councillor, MLA, MP) and excludes Sarpanch', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authRepo = MockLocationHomeAuthRepo();
      authRepo.testUser = authRepo.testUser.copyWith(selectedPlaceId: 'place-city-1');
      final authService = AuthService(repository: authRepo);
      authService.setSession(
        AuthTokens(accessToken: 'acc', refreshToken: 'ref', user: authRepo.testUser),
      );

      configureMockHttp(
        place: const Place(
          id: 'place-city-1',
          canonicalName: 'Varanasi',
          level: 'CITY_TOWN',
          names: [PlaceName(language: 'en', name: 'Varanasi')],
        ),
      );

      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      // Applicable urban offices must be listed
      expect(find.textContaining('Municipal Chairperson / Mayor'), findsOneWidget);
      expect(find.textContaining('Ward Councillor / Municipal Member'), findsOneWidget);
      expect(find.textContaining('Member of Legislative Assembly (MLA)'), findsOneWidget);
      expect(find.textContaining('Member of Parliament (MP)'), findsOneWidget);

      // Rural offices must NOT be shown for an urban city
      expect(find.textContaining('Sarpanch (Gram Panchayat Head)'), findsNothing);
      expect(find.textContaining('Ward Member (Panch)'), findsNothing);
    });

    testWidgets('4. Displays source citation and reference period/year for attributes', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authRepo = MockLocationHomeAuthRepo();
      final authService = AuthService(repository: authRepo);
      authService.setSession(
        AuthTokens(accessToken: 'acc', refreshToken: 'ref', user: authRepo.testUser),
      );

      configureMockHttp(
        place: const Place(
          id: 'place-village-1',
          canonicalName: 'Sundarpur',
          level: 'VILLAGE',
          names: [PlaceName(language: 'en', name: 'Sundarpur')],
        ),
        attributes: [
          {
            'id': 'attr-demo-1',
            'placeId': 'place-village-1',
            'category': 'population',
            'key': 'total_population',
            'value': '3,850',
            'sourceDescription': 'Census of India 2011 Village Directory',
            'reportedPeriod': '2011',
            'uncertainty': null,
            'createdAt': '2026-01-01T00:00:00.000Z',
          },
        ],
      );

      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      expect(find.text('3,850'), findsOneWidget);
      expect(find.text('Verified Record'), findsWidgets);
      expect(find.textContaining('Source: Census of India 2011 Village Directory'), findsOneWidget);
      expect(find.textContaining('Period / Year: 2011'), findsOneWidget);
    });

    testWidgets('5. Displays honest unavailable states when data is missing with citation requirement', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authRepo = MockLocationHomeAuthRepo();
      final authService = AuthService(repository: authRepo);
      authService.setSession(
        AuthTokens(accessToken: 'acc', refreshToken: 'ref', user: authRepo.testUser),
      );

      configureMockHttp(
        place: const Place(
          id: 'place-village-1',
          canonicalName: 'Sundarpur',
          level: 'VILLAGE',
          names: [PlaceName(language: 'en', name: 'Sundarpur')],
        ),
        attributes: [],
        claims: [],
      );

      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      // Honest unavailable cards are displayed
      expect(find.text('Religion & Caste Demographics'), findsOneWidget);
      expect(find.textContaining('Aggregate religion and caste statistics are not recorded'), findsOneWidget);
      expect(find.textContaining('Requires verifiable government survey or official census gazette'), findsOneWidget);

      expect(find.text('Occupations, Agriculture & Employment'), findsOneWidget);
      expect(find.text('Voter & Electoral Information'), findsOneWidget);
      expect(find.text('Documented Local History'), findsOneWidget);
      expect(find.text('Oral Traditions & Folklore'), findsOneWidget);
      expect(find.text('Public Facilities & Development Records'), findsOneWidget);
      expect(find.text('Community Knowledge & Observations'), findsOneWidget);
    });

    testWidgets('6. Oral Traditions & Folklore notice card is displayed in Section C', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authRepo = MockLocationHomeAuthRepo();
      final authService = AuthService(repository: authRepo);
      authService.setSession(
        AuthTokens(accessToken: 'acc', refreshToken: 'ref', user: authRepo.testUser),
      );

      configureMockHttp(
        place: const Place(
          id: 'place-village-1',
          canonicalName: 'Sundarpur',
          level: 'VILLAGE',
          names: [PlaceName(language: 'en', name: 'Sundarpur')],
        ),
      );

      await tester.pumpWidget(buildTestWidget(authService: authService));
      await tester.pumpAndSettle();

      expect(find.byType(OralTraditionsNoticeCard), findsOneWidget);
      expect(find.text('Generational Oral Traditions & Heritage'), findsOneWidget);
      expect(find.textContaining('preserved as cultural inheritance passed between generations'), findsOneWidget);
      expect(find.textContaining('not presented as independently verified historical facts'), findsOneWidget);
    });
  });
}
