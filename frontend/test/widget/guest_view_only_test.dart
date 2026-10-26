import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_root/core/error/failures.dart';
import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/auth_dtos.dart';
import 'package:my_root/models/place.dart';
import 'package:my_root/models/user.dart';
import 'package:my_root/models/user_activity.dart';
import 'package:my_root/repositories/auth_repository.dart';
import 'package:my_root/repositories/place_repository.dart';
import 'package:my_root/services/auth_service.dart';
import 'package:my_root/services/place_service.dart';
import 'package:my_root/ui/pages/home/home_page.dart';
import 'package:my_root/ui/widgets/app_header.dart';
import 'package:my_root/ui/widgets/residence_type_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockGuestAuthRepo implements AuthRepository {
  User user;
  int updatePlaceRelationshipCalls = 0;
  int updateSelectedPlaceCalls = 0;
  String? lastResidenceType;
  String? lastIndigenousClassification;

  MockGuestAuthRepo({required this.user});

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
  Future<ApiResponse<User>> updateSelectedPlace(String? placeId) async {
    updateSelectedPlaceCalls++;
    user = user.copyWith(selectedPlaceId: placeId);
    return ApiResponse.success(user);
  }

  @override
  Future<ApiResponse<User>> updatePlaceRelationship({
    required String placeId,
    String? residenceType,
    required String indigenousClassification,
  }) async {
    updatePlaceRelationshipCalls++;
    lastResidenceType = residenceType;
    lastIndigenousClassification = indigenousClassification;
    user = user.copyWith(
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
    );
    return ApiResponse.success(user);
  }

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
  Future<ApiResponse<List<PublicUser>>> getLatestUsers() async => const ApiResponse.success([]);
}

class MockGuestPlaceRepo extends Fake implements PlaceRepository {
  final List<Place> places;
  MockGuestPlaceRepo({this.places = const []});

  @override
  Future<ApiResponse<List<Place>>> getPlaces({
    String? parentId,
    String? level,
    String? search,
    int page = 1,
    int limit = 50,
  }) async =>
      ApiResponse.success(places);

  @override
  Future<ApiResponse<Place>> getPlaceById(String id) async {
    final match = places.where((p) => p.id == id).firstOrNull;
    if (match != null) return ApiResponse.success(match);
    return const ApiResponse.failure(NotFoundFailure(message: 'Place not found'));
  }
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ResidenceTypeDialog Widget Tests', () {
    testWidgets('renders ResidenceTypeDialog and disables confirm until classification selected', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await showDialog<PlaceRelationshipResult>(
                  context: context,
                  builder: (_) => const ResidenceTypeDialog(placeName: 'Mandore'),
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('residence_type_dialog')), findsOneWidget);
      expect(find.text('Select Connection for Mandore'), findsOneWidget);
      expect(find.byKey(const Key('classification_indigenous')), findsOneWidget);
      expect(find.byKey(const Key('classification_non_indigenous')), findsOneWidget);

      // Confirm button is disabled when nothing selected
      final confirmBtn = tester.widget<FilledButton>(find.byKey(const Key('residence_type_confirm')));
      expect(confirmBtn.onPressed, isNull);
    });

    testWidgets('can select explicit Indigenous classification and confirm', (tester) async {
      PlaceRelationshipResult? result;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<PlaceRelationshipResult>(
                  context: context,
                  builder: (_) => const ResidenceTypeDialog(placeName: 'Jodhpur'),
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('classification_indigenous')));
      await tester.tap(find.byKey(const Key('classification_indigenous')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('residence_type_confirm')));
      await tester.tap(find.byKey(const Key('residence_type_confirm')));
      await tester.pumpAndSettle();

      expect(result?.indigenousClassification, 'Indigenous');
    });

    testWidgets('can select Non-Indigenous classification explicitly', (tester) async {
      PlaceRelationshipResult? result;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<PlaceRelationshipResult>(
                  context: context,
                  builder: (_) => const ResidenceTypeDialog(placeName: 'Jaipur'),
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('classification_non_indigenous')));
      await tester.tap(find.byKey(const Key('classification_non_indigenous')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('residence_type_confirm')));
      await tester.tap(find.byKey(const Key('residence_type_confirm')));
      await tester.pumpAndSettle();

      expect(result?.indigenousClassification, 'Non-Indigenous');
    });

    testWidgets('cancelling returns null', (tester) async {
      PlaceRelationshipResult? result;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<PlaceRelationshipResult>(
                  context: context,
                  builder: (_) => const ResidenceTypeDialog(placeName: 'Jodhpur'),
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('residence_type_cancel')));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });

  group('Guest View-Only Access on HomePage', () {
    testWidgets('FAB is hidden and Contribute shows no-location prompt when no place is selected', (tester) async {
      final userWithoutPlace = User(
        id: 'guest-user',
        displayName: 'Guest Contributor',
        role: 'CONTRIBUTOR',
        joinedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
        selectedPlaceId: null, // No location selected!
      );

      final authRepo = MockGuestAuthRepo(user: userWithoutPlace);
      final authService = AuthService(repository: authRepo);
      await authService.setSession(
        AuthTokens(accessToken: 'a', refreshToken: 'r', user: userWithoutPlace),
      );

      final placeRepo = MockGuestPlaceRepo(places: []);
      final placeService = PlaceService(repository: placeRepo);

      await tester.pumpWidget(
        createTestApp(
          HomePage(
            authService: authService,
            placeService: placeService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify FloatingActionButton is NOT rendered in Guest View-only mode
      expect(find.byKey(const Key('home_fab_add')), findsNothing);

      // 2. Click Contribute in Hero section
      final contributeBtn = find.widgetWithText(OutlinedButton, 'Contribute');
      expect(contributeBtn, findsOneWidget);
      await tester.tap(contributeBtn);
      await tester.pumpAndSettle();

      // 3. Verify user is presented with the clear No Location Selected explanation
      expect(find.byKey(const Key('home_no_location_card')), findsOneWidget);
      expect(find.text('No Location Selected'), findsOneWidget);
      expect(
        find.text('Please select a location using the location selector in the top header to view or contribute community knowledge.'),
        findsOneWidget,
      );
    });

    testWidgets('GlobalAppBar prompts ResidenceTypeDialog when selecting a place for the first time', (tester) async {
      const testPlace = Place(
        id: 'place-new-1',
        canonicalName: 'Mandore Village',
        level: 'VILLAGE',
        names: [PlaceName(language: 'en', name: 'Mandore Village')],
      );

      final userWithoutPlace = User(
        id: 'user-header-1',
        displayName: 'Header User',
        role: 'CONTRIBUTOR',
        joinedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
        selectedPlaceId: null,
        placeRelationships: [], // No existing relationships
      );

      final authRepo = MockGuestAuthRepo(user: userWithoutPlace);
      final authService = AuthService(repository: authRepo);
      await authService.setSession(
        AuthTokens(accessToken: 'a', refreshToken: 'r', user: userWithoutPlace),
      );

      final placeRepo = MockGuestPlaceRepo(places: [testPlace]);
      final placeService = PlaceService(repository: placeRepo);

      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            appBar: GlobalAppBar(
              authService: authService,
              placeService: placeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap location selector in header
      await tester.tap(find.byKey(const Key('header_location_selector')));
      await tester.pumpAndSettle();

      // Enter search text to display results
      await tester.enterText(find.byKey(const Key('location_search_input')), 'Mandore');
      await tester.pumpAndSettle();

      // Tap the place item in search dialog
      await tester.tap(find.byKey(Key('location_item_${testPlace.id}')));
      await tester.pumpAndSettle();

      // ResidenceTypeDialog should now be displayed!
      expect(find.byKey(const Key('residence_type_dialog')), findsOneWidget);
      expect(find.text('Select Connection for Mandore Village'), findsOneWidget);

      // Select explicit 'Indigenous' classification, then confirm
      await tester.ensureVisible(find.byKey(const Key('classification_indigenous')));
      await tester.tap(find.byKey(const Key('classification_indigenous')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('residence_type_confirm')));
      await tester.tap(find.byKey(const Key('residence_type_confirm')));
      await tester.pumpAndSettle();

      // Verify updatePlaceRelationship was called with Indigenous
      expect(authRepo.updatePlaceRelationshipCalls, 1);
      expect(authRepo.lastIndigenousClassification, 'Indigenous');
      expect(authService.currentUser?.selectedPlaceId, 'place-new-1');
      expect(authService.currentUser?.getRelationshipForPlace('place-new-1')?.indigenousClassification, 'Indigenous');
    });

    testWidgets('GlobalAppBar skips ResidenceTypeDialog when selecting an existing relationship place', (tester) async {
      const existingPlace = Place(
        id: 'place-existing-1',
        canonicalName: 'Jodhpur City',
        level: 'CITY_TOWN',
        names: [PlaceName(language: 'en', name: 'Jodhpur City')],
      );

      final userWithExisting = User(
        id: 'user-header-2',
        displayName: 'Header User 2',
        role: 'CONTRIBUTOR',
        joinedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
        selectedPlaceId: 'place-other',
        placeRelationships: [
          UserPlaceRelationship(
            placeId: 'place-existing-1',
            residenceType: 'Permanent',
            indigenousClassification: 'Indigenous',
            createdAt: DateTime.now(),
          ),
        ],
      );

      final authRepo = MockGuestAuthRepo(user: userWithExisting);
      final authService = AuthService(repository: authRepo);
      await authService.setSession(
        AuthTokens(accessToken: 'a', refreshToken: 'r', user: userWithExisting),
      );

      final placeRepo = MockGuestPlaceRepo(places: [existingPlace]);
      final placeService = PlaceService(repository: placeRepo);

      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            appBar: GlobalAppBar(
              authService: authService,
              placeService: placeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap location selector in header
      await tester.tap(find.byKey(const Key('header_location_selector')));
      await tester.pumpAndSettle();

      // Enter search text to display results
      await tester.enterText(find.byKey(const Key('location_search_input')), 'Jodhpur');
      await tester.pumpAndSettle();

      // Tap the place item in search dialog
      await tester.tap(find.byKey(Key('location_item_${existingPlace.id}')));
      await tester.pumpAndSettle();

      // ResidenceTypeDialog should NOT be displayed!
      expect(find.byKey(const Key('residence_type_dialog')), findsNothing);

      // updateSelectedPlace was called directly, updatePlaceRelationship was NOT called
      expect(authRepo.updateSelectedPlaceCalls, 1);
      expect(authRepo.updatePlaceRelationshipCalls, 0);
      expect(authService.currentUser?.selectedPlaceId, 'place-existing-1');
      expect(authService.currentUser?.indigenousClassification, 'Indigenous');
    });
  });
}
