import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/claim.dart';
import 'package:my_root/models/place.dart';
import 'package:my_root/models/place_progress.dart';
import 'package:my_root/models/user.dart';
import 'package:my_root/repositories/auth_repository.dart';
import 'package:my_root/repositories/community_repository.dart';
import 'package:my_root/repositories/place_repository.dart';
import 'package:my_root/services/auth_service.dart';
import 'package:my_root/services/community_service.dart';
import 'package:my_root/services/place_service.dart';
import 'package:my_root/ui/card/matrbhoomi_card.dart';
import 'package:my_root/ui/pages/places/place_detail_page.dart';
import 'package:my_root/ui/pages/places/progressive_contribution_page.dart';

class FakePlaceRepo extends Fake implements PlaceRepository {
  final Place testPlace;
  FakePlaceRepo(this.testPlace);

  @override
  Future<ApiResponse<Place>> getPlaceById(String id) async => ApiResponse.success(testPlace);

  @override
  Future<ApiResponse<List<Place>>> getChildren(String parentId) async => const ApiResponse.success([]);
}

class FakeCommunityRepo extends Fake implements CommunityRepository {
  List<Claim> claims = [];

  @override
  Future<ApiResponse<List<Claim>>> getClaimsForPlace({
    required String locationId,
    String? category,
    String? communityTopic,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    return ApiResponse.success(claims);
  }

  @override
  Future<ApiResponse<PlaceProgress>> getPlaceProgress(String placeId) async {
    return const ApiResponse.success(PlaceProgress(
      placeId: 'place-jaipur-1',
      totalContributions: 2,
      verifiedFactsCount: 2,
      pendingReviewCount: 0,
      folkloreCount: 0,
      opinionsCount: 0,
      biographiesCount: 0,
      facilitiesCount: 0,
      evidenceAttachmentsCount: 2,
      qualityCoverageScore: 85,
      criteriaExplanation: 'High quality coverage',
    ));
  }

  @override
  Future<ApiResponse<List<PlaceAttribute>>> getPlaceAttributes({
    required String placeId,
    String? category,
  }) async {
    return const ApiResponse.success([]);
  }
}

class FakeAuthRepo extends Fake implements AuthRepository {
  User user;
  String? updatedPlaceId;
  bool? updatedKnowsHistory;
  bool? updatedWantsToLearn;

  FakeAuthRepo(this.user);

  @override
  Future<ApiResponse<User>> getMe() async => ApiResponse.success(user);

  @override
  Future<ApiResponse<User>> updateMatrbhoomiInterest({
    required String placeId,
    bool? knowsHistory,
    bool? wantsToLearn,
  }) async {
    updatedPlaceId = placeId;
    updatedKnowsHistory = knowsHistory;
    updatedWantsToLearn = wantsToLearn;
    user = user.copyWith(
      matrbhoomiHistoryInterest: MatrbhoomiHistoryInterest(
        placeId: placeId,
        knowsHistory: knowsHistory,
        wantsToLearn: wantsToLearn,
        answeredAt: DateTime.now(),
      ),
    );
    return ApiResponse.success(user);
  }
}

void main() {
  late Place testPlace;
  late FakePlaceRepo placeRepo;
  late FakeCommunityRepo communityRepo;
  late FakeAuthRepo authRepo;
  late PlaceService placeService;
  late CommunityService communityService;
  late AuthService authService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    testPlace = const Place(
      id: 'place-jaipur-1',
      level: 'DISTRICT',
      canonicalName: 'Jaipur',
      names: [PlaceName(language: 'hi', name: 'जयपुर')],
    );

    placeRepo = FakePlaceRepo(testPlace);
    communityRepo = FakeCommunityRepo();
    authRepo = FakeAuthRepo(
      User(
        id: 'user-flow-1',
        displayName: 'Dev Contributor',
        role: 'CONTRIBUTOR',
        joinedAt: DateTime.now(),
        selectedPlaceId: 'place-jaipur-1',
      ),
    );

    placeService = PlaceService(repository: placeRepo);
    communityService = CommunityService(repository: communityRepo);
    authService = AuthService(repository: authRepo);
    authService.setSession(
      AuthTokens(
        accessToken: 'mock-token',
        refreshToken: 'mock-refresh',
        user: authRepo.user,
      ),
    );
  });

  Widget buildTestWidget() {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('hi')],
      home: PlaceDetailPage(
        placeId: testPlace.id,
        initialPlace: testPlace,
        placeService: placeService,
        communityService: communityService,
        authService: authService,
      ),
    );
  }

  testWidgets('displays Question 1 on initial load and allows YES -> Contribute flow', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Verify Question 1 banner is displayed
    expect(find.text('Matrbhoomi History'), findsOneWidget);
    expect(
      find.text('Do you know about the glorious history of your homeland?'),
      findsOneWidget,
    );
    expect(find.text('Yes, I know'), findsOneWidget);
    expect(find.text('No, I want to learn'), findsOneWidget);

    // Tap YES
    await tester.tap(find.text('Yes, I know'));
    await tester.pumpAndSettle();

    // Verifies preference persisted to auth service
    expect(authRepo.updatedPlaceId, 'place-jaipur-1');
    expect(authRepo.updatedKnowsHistory, isTrue);

    // Verify opportunity to contribute is shown
    expect(
      find.text('Contribute to the glorious history, traditions, personalities, and historical events of your homeland.'),
      findsOneWidget,
    );
    expect(find.text('Contribute History'), findsOneWidget);

    // Tap Contribute History -> navigates to ProgressiveContributionPage
    await tester.tap(find.text('Contribute History'));
    await tester.pumpAndSettle();

    expect(find.byType(ProgressiveContributionPage), findsOneWidget);
  });

  testWidgets('NO branch prompts Question 2 and dismissing closes with zero pressure', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Tap "No, I want to learn"
    await tester.tap(find.text('No, I want to learn'));
    await tester.pumpAndSettle();

    // Verify Question 2 is shown
    expect(
      find.text('Would you like to learn about the glorious history of your homeland?'),
      findsOneWidget,
    );
    expect(find.text('Yes, show history'), findsOneWidget);
    expect(find.text('No, not now'), findsOneWidget);

    // Tap "No, not now" -> dismisses politely
    await tester.tap(find.text('No, not now'));
    await tester.pumpAndSettle();

    expect(find.text('Would you like to learn about the glorious history of your homeland?'), findsNothing);
    expect(authRepo.updatedKnowsHistory, isFalse);
    expect(authRepo.updatedWantsToLearn, isFalse);
  });

  testWidgets('NO -> Learn YES shows approved history or clear empty state when none exist', (tester) async {
    communityRepo.claims = []; // No approved claims

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Tap "No, I want to learn"
    await tester.tap(find.text('No, I want to learn'));
    await tester.pumpAndSettle();

    // Tap "Yes, show history"
    await tester.tap(find.text('Yes, show history'));
    await tester.pumpAndSettle();

    // Empty state without fake/dummy data
    expect(
      find.text('No approved historical records are available for this place yet.'),
      findsOneWidget,
    );
    expect(authRepo.updatedKnowsHistory, isFalse);
    expect(authRepo.updatedWantsToLearn, isTrue);
  });

  testWidgets('renders approved history with MatrbhoomiCard when available', (tester) async {
    communityRepo.claims = [
      Claim(
        id: 'claim-hist-1',
        title: const LocalizedContent(original: 'Hawa Mahal Heritage', language: 'en'),
        body: const LocalizedContent(original: 'Built by Maharaja Sawai Pratap Singh in 1799.', language: 'en'),
        category: 'HISTORICAL_RECORD',
        status: 'verified',
        locationId: 'place-jaipur-1',
        submittedAt: DateTime(2025, 4, 1),
        evidenceCount: 2,
        isPublic: true,
        tags: const ['history'],
        sourceAttribution: 'City Palace Records',
        timePeriod: '1799 CE',
      ),
    ];

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Verified history rendered with MatrbhoomiCard
    expect(find.byType(MatrbhoomiCard), findsOneWidget);
    expect(find.text('Hawa Mahal Heritage'), findsOneWidget);
  });

  testWidgets('does not show prompt again when user preference already persisted', (tester) async {
    SharedPreferences.setMockInitialValues({
      'matrbhoomi_prompt_place-jaipur-1': true,
    });

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Question 1 banner should NOT appear
    expect(
      find.text('Do you know about the glorious history of your homeland?'),
      findsNothing,
    );
  });

  testWidgets('does not show prompt again when user-scoped preference is persisted', (tester) async {
    SharedPreferences.setMockInitialValues({
      'matrbhoomi_prompt_user-flow-1_place-jaipur-1': true,
    });

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(
      find.text('Do you know about the glorious history of your homeland?'),
      findsNothing,
    );
  });

  testWidgets('does NOT show Matrbhoomi prompt during general browsing of an unrelated place', (tester) async {
    // User selected place is place-jaipur-1, but user is viewing an unrelated place (place-delhi-2)
    const unrelatedPlace = Place(
      id: 'place-delhi-2',
      level: 'DISTRICT',
      canonicalName: 'Delhi',
      names: [PlaceName(language: 'hi', name: 'दिल्ली')],
    );
    final unrelatedPlaceRepo = FakePlaceRepo(unrelatedPlace);
    final unrelatedPlaceService = PlaceService(repository: unrelatedPlaceRepo);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('hi')],
        home: PlaceDetailPage(
          placeId: unrelatedPlace.id,
          initialPlace: unrelatedPlace,
          placeService: unrelatedPlaceService,
          communityService: communityService,
          authService: authService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The prompt must NOT appear for unrelated places during general browsing!
    expect(
      find.text('Do you know about the glorious history of your homeland?'),
      findsNothing,
    );
  });

  testWidgets('hides folklore and opinions when exploring approved-only history', (tester) async {
    communityRepo.claims = [
      Claim(
        id: 'claim-hist-1',
        title: const LocalizedContent(original: 'Verified Heritage', language: 'en'),
        body: const LocalizedContent(original: 'Ancient royal library.', language: 'en'),
        category: 'HISTORICAL_RECORD',
        status: 'verified',
        locationId: 'place-jaipur-1',
        submittedAt: DateTime(2025, 4, 1),
        evidenceCount: 2,
        isPublic: true,
        tags: const ['history'],
      ),
      Claim(
        id: 'claim-folk-2',
        title: const LocalizedContent(original: 'Ghost of Fort', language: 'en'),
        body: const LocalizedContent(original: 'Local myth of hidden treasure.', language: 'en'),
        category: 'FOLKLORE',
        status: 'unverified',
        locationId: 'place-jaipur-1',
        submittedAt: DateTime(2025, 4, 1),
        evidenceCount: 0,
        isPublic: true,
        tags: const ['folklore'],
      ),
    ];

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Tap "No, I want to learn" -> "Yes, show history"
    await tester.tap(find.text('No, I want to learn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, show history'));
    await tester.pumpAndSettle();

    // Approved history section is shown
    expect(find.text('Verified Heritage'), findsOneWidget);
    // Unapproved folklore is suppressed from approved history view
    expect(find.text('Ghost of Fort'), findsNothing);
  });
}
