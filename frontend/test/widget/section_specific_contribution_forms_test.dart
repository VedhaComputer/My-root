import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/auth_dtos.dart';
import 'package:my_root/models/claim.dart';
import 'package:my_root/models/place.dart';
import 'package:my_root/models/place_progress.dart';
import 'package:my_root/models/user.dart';
import 'package:my_root/models/user_activity.dart';
import 'package:my_root/repositories/auth_repository.dart';
import 'package:my_root/repositories/community_repository.dart';
import 'package:my_root/repositories/place_repository.dart';
import 'package:my_root/services/auth_service.dart';
import 'package:my_root/services/community_service.dart';
import 'package:my_root/services/place_service.dart';
import 'package:my_root/ui/pages/home/home_page.dart';
import 'package:my_root/ui/pages/places/section_data_contribution_page.dart';

class MockSectionHttpClient extends http.BaseClient {
  http.Response Function(http.Request request)? handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final httpRequest = request as http.Request;
    final response = handler != null
        ? handler!(httpRequest)
        : http.Response('{"data": []}', 200, headers: {'content-type': 'application/json'});

    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

class MockSectionAuthRepo implements AuthRepository {
  final User user = User(
    id: 'usr-100',
    displayName: 'Aarav Sharma',
    role: 'CONTRIBUTOR',
    joinedAt: DateTime.parse('2025-01-01T00:00:00.000Z'),
    selectedPlaceId: 'place-test-1',
  );

  @override
  Future<ApiResponse<AuthTokens>> login(String email, String password) async =>
      ApiResponse.success(AuthTokens(accessToken: 'a', refreshToken: 'r', user: user));

  @override
  Future<ApiResponse<RegisterResponse>> register(String d, String e, String p) async =>
      const ApiResponse.success(RegisterResponse(message: 'ok'));

  @override
  Future<ApiResponse<AuthTokens>> refreshToken(String r) async =>
      ApiResponse.success(AuthTokens(accessToken: 'a', refreshToken: 'r', user: user));

  @override
  Future<ApiResponse<Map<String, dynamic>>> logout({String? refreshToken}) async =>
      const ApiResponse.success({'message': 'ok'});

  @override
  Future<ApiResponse<User>> getMe() async => ApiResponse.success(user);

  @override
  Future<ApiResponse<User>> updateSelectedPlace(String? placeId) async =>
      ApiResponse.success(user.copyWith(selectedPlaceId: placeId));

  @override
  Future<ApiResponse<User>> updatePlaceRelationship({
    required String placeId,
    String? residenceType,
    required String indigenousClassification,
  }) async =>
      ApiResponse.success(user.copyWith(
        selectedPlaceId: placeId,
        placeRelationships: [
          ...user.placeRelationships.where((r) => r.placeId != placeId),
          UserPlaceRelationship(
            placeId: placeId,
            residenceType: residenceType,
            indigenousClassification: indigenousClassification,
            createdAt: DateTime.now(),
          ),
        ],
      ));

  @override
  Future<ApiResponse<User>> updateMatrbhoomiInterest({
    required String placeId,
    bool? knowsHistory,
    bool? wantsToLearn,
  }) async => ApiResponse.success(user);

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
  Future<ApiResponse<MessageResponse>> resetPassword(String t, String n) async =>
      const ApiResponse.success(MessageResponse(message: 'ok'));

  @override
  Future<ApiResponse<UserActivity>> getUserActivity() async =>
      const ApiResponse.success(UserActivity(
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
      ));

  @override
  Future<ApiResponse<List<PublicUser>>> getLatestUsers() async =>
      const ApiResponse.success([]);
}

class MockSectionPlaceRepo implements PlaceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  final ApiClient client;

  MockSectionPlaceRepo({required this.client});

  final testPlace = const Place(
    id: 'place-test-1',
    canonicalName: 'Mandore Village',
    level: 'VILLAGE',
    names: [PlaceName(language: 'en', name: 'Mandore Village')],
    parentPath: [
      PlacePathItem(id: 'dist-1', canonicalName: 'Jodhpur District', level: 'DISTRICT'),
    ],
  );

  @override
  Future<ApiResponse<List<Place>>> getPlaces({String? level, String? parentId, String? search, int page = 1, int limit = 20}) async =>
      ApiResponse.success([testPlace]);

  @override
  Future<ApiResponse<Place>> getPlaceById(String id) async => ApiResponse.success(testPlace);

  @override
  Future<ApiResponse<List<Place>>> getChildren(String parentId) async => const ApiResponse.success([]);
}

class MockSectionCommunityRepo implements CommunityRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final List<PlaceAttribute> submittedAttributes = [];

  @override
  Future<ApiResponse<List<Claim>>> getClaimsForPlace({
    required String locationId,
    String? category,
    String? status,
    String? communityTopic,
    int page = 1,
    int limit = 20,
  }) async =>
      const ApiResponse.success([]);

  @override
  Future<ApiResponse<List<PlaceAttribute>>> getPlaceAttributes({required String placeId, String? category}) async =>
      ApiResponse.success(submittedAttributes);

  @override
  Future<ApiResponse<PlaceAttribute>> addPlaceAttribute({
    required String placeId,
    required String category,
    required String key,
    required String value,
    required String sourceDescription,
    String? reportedPeriod,
    String? uncertainty,
  }) async {
    final attr = PlaceAttribute(
      id: 'attr-${submittedAttributes.length + 1}',
      placeId: placeId,
      category: category,
      key: key,
      value: value,
      sourceDescription: sourceDescription,
      reportedPeriod: reportedPeriod,
      uncertainty: uncertainty,
      createdAt: DateTime.now(),
    );
    submittedAttributes.add(attr);
    return ApiResponse.success(attr);
  }

  @override
  Future<ApiResponse<PlaceProgress>> getPlaceProgress(String placeId) async =>
      const ApiResponse.success(PlaceProgress(
        placeId: 'place-test-1',
        totalContributions: 0,
        verifiedFactsCount: 0,
        pendingReviewCount: 0,
        folkloreCount: 0,
        opinionsCount: 0,
        biographiesCount: 0,
        facilitiesCount: 0,
        evidenceAttachmentsCount: 0,
        qualityCoverageScore: 40,
        criteriaExplanation: '',
      ));
}

Widget createTestApp({
  required AuthService authService,
  required PlaceService placeService,
  required CommunityService communityService,
  required ApiClient apiClient,
}) {
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
      placeService: placeService,
      communityService: communityService,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSectionHttpClient mockHttp;
  late ApiClient apiClient;
  late MockSectionAuthRepo authRepo;
  late MockSectionPlaceRepo placeRepo;
  late MockSectionCommunityRepo communityRepo;
  late AuthService authService;
  late PlaceService placeService;
  late CommunityService communityService;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({'selected_place_id': 'place-test-1'});
    mockHttp = MockSectionHttpClient();
    apiClient = ApiClient(client: mockHttp);
    authRepo = MockSectionAuthRepo();
    placeRepo = MockSectionPlaceRepo(client: apiClient);
    communityRepo = MockSectionCommunityRepo();

    authService = AuthService(repository: authRepo);
    placeService = PlaceService(repository: placeRepo);
    communityService = CommunityService(repository: communityRepo);

    authService.setSession(
      AuthTokens(accessToken: 'token', refreshToken: 'ref', user: authRepo.user),
    );
    placeService.setSelectedPlace(placeRepo.testPlace);
  });

  group('Section-Specific Data Contribution Forms — Button to Form Mapping', () {
    testWidgets('1. Demographic & Population Statistics button opens correct form with location and section context', (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp(
        authService: authService,
        placeService: placeService,
        communityService: communityService,
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      // Find the "Contribute Data" button for Demographic & Population Statistics
      final btn = find.byKey(const Key('contribute_demographics_button'));
      expect(btn, findsOneWidget);
      expect(find.descendant(of: btn, matching: find.text('Contribute Data')), findsOneWidget);

      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      // Verify SectionDataContributionPage is embedded in central content
      expect(find.byType(SectionDataContributionPage), findsOneWidget);
      expect(find.text('Demographic & Population Statistics'), findsWidgets);
      // Verify redundant Location Card is absent
      expect(find.byKey(const Key('form_location_context')), findsNothing);
      expect(find.textContaining('Location: Mandore Village'), findsNothing);

      // Verify return to Home button restores central content
      final returnBtn = find.byKey(const Key('return_to_home_button'));
      await tester.ensureVisible(returnBtn);
      await tester.tap(returnBtn);
      await tester.pumpAndSettle();

      expect(find.byType(SectionDataContributionPage), findsNothing);
      expect(find.byKey(const Key('contribute_demographics_button')), findsOneWidget);
    });

    testWidgets('2. Religion & Caste Demographic button opens form with Privacy Safeguard banner and without redundant Location Card', (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp(
        authService: authService,
        placeService: placeService,
        communityService: communityService,
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      final btn = find.byKey(const Key('contribute_religion_caste_button'));
      expect(btn, findsOneWidget);
      expect(find.descendant(of: btn, matching: find.text('Contribute Data')), findsOneWidget);

      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.byType(SectionDataContributionPage), findsOneWidget);
      expect(find.text('Religion & Caste Demographics'), findsWidgets);
      // Verify redundant Location Card is absent
      expect(find.byKey(const Key('form_location_context')), findsNothing);
      expect(find.textContaining('Location: Mandore Village'), findsNothing);

      // Verify privacy safeguard notice is rendered
      expect(find.textContaining('Privacy Safeguard: Only credible aggregate community/religion proportions'), findsOneWidget);

      // Return to Home
      final returnBtn = find.byKey(const Key('return_to_home_button'));
      await tester.ensureVisible(returnBtn);
      await tester.tap(returnBtn);
      await tester.pumpAndSettle();
      expect(find.byType(SectionDataContributionPage), findsNothing);
    });

    testWidgets('3. Occupation, Agriculture & Employment button opens form without redundant Location Card', (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp(
        authService: authService,
        placeService: placeService,
        communityService: communityService,
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      final btn = find.byKey(const Key('contribute_occupation_economy_button'));
      expect(btn, findsOneWidget);
      expect(find.descendant(of: btn, matching: find.text('Contribute Data')), findsOneWidget);

      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.byType(SectionDataContributionPage), findsOneWidget);
      expect(find.text('Occupations, Agriculture & Employment'), findsWidgets);
      // Verify redundant Location Card is absent
      expect(find.byKey(const Key('form_location_context')), findsNothing);
      expect(find.textContaining('Location: Mandore Village'), findsNothing);

      final returnBtn = find.byKey(const Key('return_to_home_button'));
      await tester.ensureVisible(returnBtn);
      await tester.tap(returnBtn);
      await tester.pumpAndSettle();
      expect(find.byType(SectionDataContributionPage), findsNothing);
    });

    testWidgets('4. Voter & Electoral Information button opens form with electoral indicators and without redundant Location Card', (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp(
        authService: authService,
        placeService: placeService,
        communityService: communityService,
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      final btn = find.byKey(const Key('contribute_voter_electoral_button'));
      expect(btn, findsOneWidget);
      expect(find.descendant(of: btn, matching: find.text('Contribute Data')), findsOneWidget);

      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.byType(SectionDataContributionPage), findsOneWidget);
      expect(find.text('Voter & Electoral Information'), findsWidgets);
      // Verify redundant Location Card is absent
      expect(find.byKey(const Key('form_location_context')), findsNothing);
      expect(find.textContaining('Location: Mandore Village'), findsNothing);
      expect(find.textContaining('Electoral Transparency: Only official aggregate voter statistics'), findsOneWidget);

      final returnBtn = find.byKey(const Key('return_to_home_button'));
      await tester.ensureVisible(returnBtn);
      await tester.tap(returnBtn);
      await tester.pumpAndSettle();
      expect(find.byType(SectionDataContributionPage), findsNothing);
    });

    testWidgets('5. Public Facilities & Development Records button opens form without redundant Location Card', (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp(
        authService: authService,
        placeService: placeService,
        communityService: communityService,
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      final btn = find.byKey(const Key('contribute_public_facilities_button'));
      expect(btn, findsOneWidget);
      expect(find.descendant(of: btn, matching: find.text('Contribute Data')), findsOneWidget);

      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.byType(SectionDataContributionPage), findsOneWidget);
      expect(find.text('Public Facilities & Development Records'), findsWidgets);
      // Verify redundant Location Card is absent
      expect(find.byKey(const Key('form_location_context')), findsNothing);
      expect(find.textContaining('Location: Mandore Village'), findsNothing);

      final returnBtn = find.byKey(const Key('return_to_home_button'));
      await tester.ensureVisible(returnBtn);
      await tester.tap(returnBtn);
      await tester.pumpAndSettle();
      expect(find.byType(SectionDataContributionPage), findsNothing);
    });
  });

  group('Section-Specific Data Contribution Forms — Form Validation and Submission', () {
    testWidgets('6. Form requires source citation and value, and validates appropriately', (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp(
        authService: authService,
        placeService: placeService,
        communityService: communityService,
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      final btn = find.byKey(const Key('contribute_demographics_button'));
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      // Submit empty form -> shows validation errors
      final submitBtn = find.byKey(const Key('submit_section_contribution_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter the data value'), findsOneWidget);
      expect(find.text('Official citation or source is required (at least 3 characters)'), findsOneWidget);

      // Check "unknown" checkbox -> disables value field and auto-fills unavailable indicator
      final checkbox = find.byKey(const Key('checkbox_unknown_data'));
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      // Enter valid citation
      final srcField = find.byKey(const Key('field_attribute_source'));
      await tester.ensureVisible(srcField);
      await tester.enterText(srcField, 'Census of India 2011');
      await tester.pumpAndSettle();

      // Submit valid unknown data record
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verified: submission was recorded with active place ID and returned to Home
      expect(communityRepo.submittedAttributes.length, equals(1));
      expect(communityRepo.submittedAttributes.first.placeId, equals('place-test-1'));
      expect(communityRepo.submittedAttributes.first.category, equals('population'));
      expect(communityRepo.submittedAttributes.first.sourceDescription, equals('Census of India 2011'));
      expect(find.byType(SectionDataContributionPage), findsNothing);
    });

    testWidgets('7. Submitting valid demographic record updates attributes and returns to Home with immediate display', (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp(
        authService: authService,
        placeService: placeService,
        communityService: communityService,
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      final btn = find.byKey(const Key('contribute_demographics_button'));
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      final valField = find.byKey(const Key('field_attribute_value'));
      await tester.ensureVisible(valField);
      await tester.enterText(valField, '4,850 residents');

      final srcField = find.byKey(const Key('field_attribute_source'));
      await tester.ensureVisible(srcField);
      await tester.enterText(srcField, 'Census of India 2011 Directorate');

      final periodField = find.byKey(const Key('field_attribute_period'));
      await tester.ensureVisible(periodField);
      await tester.enterText(periodField, '2011');
      await tester.pumpAndSettle();

      final submitBtn = find.byKey(const Key('submit_section_contribution_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verified: Attribute is stored in repository with active place ID and displayed on Home Page
      expect(communityRepo.submittedAttributes.length, equals(1));
      expect(communityRepo.submittedAttributes.first.placeId, equals('place-test-1'));
      expect(communityRepo.submittedAttributes.first.key, equals('Total Population'));
      expect(communityRepo.submittedAttributes.first.value, equals('4,850 residents'));

      expect(find.byType(SectionDataContributionPage), findsNothing);
      expect(find.text('4,850 residents'), findsOneWidget);
      expect(find.text('Total Population'), findsOneWidget);
    });
  });
}
