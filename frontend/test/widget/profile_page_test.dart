import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_root/core/error/failures.dart';
import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/auth_dtos.dart';
import 'package:my_root/models/claim.dart';
import 'package:my_root/models/place.dart';
import 'package:my_root/models/user.dart';
import 'package:my_root/models/user_activity.dart';
import 'package:my_root/repositories/auth_repository.dart';
import 'package:my_root/repositories/place_repository.dart';
import 'package:my_root/services/auth_service.dart';
import 'package:my_root/services/place_service.dart';
import 'package:my_root/ui/card/place_card.dart';
import 'package:my_root/ui/pages/places/place_detail_page.dart';
import 'package:my_root/ui/pages/places/places_page.dart';
import 'package:my_root/ui/pages/profile/profile_page.dart';

class MockProfileAuthRepo implements AuthRepository {
  bool activityShouldSucceed = true;
  bool returnEmptyActivity = false;
  bool wasLogoutCalled = false;

  final User user = User(
    id: 'usr-999',
    displayName: 'Dr. Rajesh Verma',
    role: 'REVIEWER',
    joinedAt: DateTime.parse('2024-03-10T09:30:00.000Z'),
    isIdentityVerified: true,
    verifiedLocationId: 'loc-delhi',
  );

  @override
  Future<ApiResponse<AuthTokens>> login(String email, String password) async {
    return ApiResponse.success(
      AuthTokens(accessToken: 'acc-1', refreshToken: 'ref-1', user: user),
    );
  }

  @override
  Future<ApiResponse<RegisterResponse>> register(
      String displayName, String email, String password) async {
    return const ApiResponse.success(RegisterResponse(message: 'OK'));
  }

  @override
  Future<ApiResponse<AuthTokens>> refreshToken(String refreshToken) async {
    return ApiResponse.success(
      AuthTokens(accessToken: 'acc-2', refreshToken: 'ref-2', user: user),
    );
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> logout({String? refreshToken}) async {
    wasLogoutCalled = true;
    return const ApiResponse.success({'message': 'Logged out'});
  }

  @override
  Future<ApiResponse<User>> getMe() async {
    return ApiResponse.success(user);
  }

  bool updateSelectedPlaceShouldSucceed = true;
  String? lastUpdatedSelectedPlaceId;

  @override
  Future<ApiResponse<User>> updateSelectedPlace(String? placeId) async {
    if (!updateSelectedPlaceShouldSucceed) {
      return const ApiResponse.failure(
        ServerFailure(message: 'Failed to update selected place on server'),
      );
    }
    lastUpdatedSelectedPlaceId = placeId;
    return ApiResponse.success(user.copyWith(selectedPlaceId: placeId));
  }

  @override
  Future<ApiResponse<User>> updateMatrbhoomiInterest({
    required String placeId,
    bool? knowsHistory,
    bool? wantsToLearn,
  }) async {
    return ApiResponse.success(
      user.copyWith(
        matrbhoomiHistoryInterest: MatrbhoomiHistoryInterest(
          placeId: placeId,
          knowsHistory: knowsHistory,
          wantsToLearn: wantsToLearn,
          answeredAt: DateTime.now(),
        ),
      ),
    );
  }

  @override
  Future<ApiResponse<UserActivity>> getUserActivity() async {
    if (!activityShouldSucceed) {
      return const ApiResponse.failure(
        ServerFailure(message: 'Unable to reach activity server'),
      );
    }

    if (returnEmptyActivity) {
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

    return ApiResponse.success(
      UserActivity(
        summary: const UserActivitySummary(
          totalContributions: 4,
          claimsCount: 2,
          evidencesCount: 1,
          placesCount: 1,
          placeAttributesCount: 0,
        ),
        claims: [
          UserClaimActivity(
            id: 'c-101',
            title: const LocalizedContent(
              original: 'Origins of the Stepwell',
              language: 'en',
            ),
            category: 'HISTORICAL_RECORD',
            status: 'verified',
            submittedAt: DateTime.parse('2025-01-15T10:00:00.000Z'),
            evidenceCount: 3,
            locationId: 'loc-delhi',
          ),
          UserClaimActivity(
            id: 'c-102',
            title: const LocalizedContent(
              original: 'Local Ghost Tree Legend',
              language: 'en',
            ),
            category: 'FOLKLORE',
            status: 'submitted',
            submittedAt: DateTime.parse('2025-02-01T14:30:00.000Z'),
            evidenceCount: 0,
          ),
        ],
        evidences: [
          UserEvidenceActivity(
            id: 'ev-201',
            claimId: 'c-101',
            sourceType: 'DOCUMENT',
            status: 'verified',
            submittedAt: DateTime.parse('2025-01-16T11:00:00.000Z'),
            summary: 'Archaeological Survey of India Bulletin 1984',
          ),
        ],
        places: [
          UserPlaceActivity(
            id: 'loc-delhi',
            canonicalName: 'Old Delhi Baoli',
            level: 'VILLAGE',
            status: 'active',
            createdAt: DateTime.parse('2024-11-20T08:00:00.000Z'),
          ),
        ],
        placeAttributes: [],
      ),
    );
  }

  @override
  Future<ApiResponse<List<PublicUser>>> getLatestUsers() async {
    return const ApiResponse.success([]);
  }
}

class MockProfilePlaceRepo implements PlaceRepository {
  @override
  final ApiClient client = ApiClient();

  List<Place> placesList = [];
  Map<String, Place> placesMap = {};

  @override
  Future<ApiResponse<List<Place>>> getPlaces({
    String? level,
    String? parentId,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    return ApiResponse.success(placesList);
  }

  @override
  Future<ApiResponse<Place>> getPlaceById(String id) async {
    if (placesMap.containsKey(id)) {
      return ApiResponse.success(placesMap[id]!);
    }
    return const ApiResponse.failure(NotFoundFailure(message: 'Not found'));
  }

  @override
  Future<ApiResponse<List<Place>>> getChildren(String parentId) async {
    return const ApiResponse.success([]);
  }

  @override
  Future<ApiResponse<Place>> createPlace({
    required String level,
    required String canonicalName,
    required List<PlaceName> names,
    String? parentId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ApiResponse<Place>> updatePlace({
    required String id,
    String? level,
    String? canonicalName,
    List<PlaceName>? names,
    String? parentId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> deletePlace(String id) async {
    return const ApiResponse.success({'message': 'Deleted'});
  }
}

Widget createTestProfileApp({
  required AuthService authService,
  PlaceService? placeService,
  Place? initialSelectedPlace,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('hi')],
    home: ProfilePage(
      authService: authService,
      placeService: placeService,
      initialSelectedPlace: initialSelectedPlace,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfilePage Widget Tests', () {
    late MockProfileAuthRepo mockRepo;
    late AuthService authService;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      mockRepo = MockProfileAuthRepo();
      authService = AuthService(repository: mockRepo);
      authService.setSession(
        AuthTokens(
          accessToken: 'test-token',
          refreshToken: 'test-refresh',
          user: mockRepo.user,
        ),
      );
    });

    testWidgets('displays authenticated user real profile fields correctly',
        (tester) async {
      await tester.pumpWidget(createTestProfileApp(authService: authService));
      await tester.pumpAndSettle();

      // Real user fields
      expect(find.text('Dr. Rajesh Verma'), findsOneWidget);
      expect(find.text('ID: usr-999'), findsOneWidget);
      expect(find.text('REVIEWER'), findsOneWidget);
      expect(find.text('Identity Verified'), findsOneWidget);
      expect(find.textContaining('Member Since: 10/3/2024'), findsOneWidget);
      expect(find.text('Location Verified'), findsOneWidget);
    });

    testWidgets('displays user activity summary stats and claims',
        (tester) async {
      await tester.pumpWidget(createTestProfileApp(authService: authService));
      await tester.pumpAndSettle();

      // Summary counts
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('4'), findsWidgets); // Total contributions
      expect(find.text('Stories'), findsOneWidget);
      expect(find.text('2'), findsWidgets); // Stories count

      // User claims list
      expect(find.text('Origins of the Stepwell'), findsOneWidget);
      expect(find.text('Local Ghost Tree Legend'), findsOneWidget);
      expect(find.text('VERIFIED'), findsOneWidget);
      expect(find.text('SUBMITTED'), findsOneWidget);
    });

    testWidgets('switching tabs displays evidence and place contributions',
        (tester) async {
      await tester.pumpWidget(createTestProfileApp(authService: authService));
      await tester.pumpAndSettle();

      // Tap Evidence tab
      final evidenceTab = find.textContaining('Evidence (1)');
      expect(evidenceTab, findsOneWidget);
      await tester.ensureVisible(evidenceTab);
      await tester.tap(evidenceTab);
      await tester.pumpAndSettle();

      expect(
        find.text('Archaeological Survey of India Bulletin 1984'),
        findsOneWidget,
      );
      expect(find.text('DOCUMENT'), findsOneWidget);

      // Tap Places tab
      final placesTab = find.textContaining('Places & Features (1)');
      expect(placesTab, findsOneWidget);
      await tester.ensureVisible(placesTab);
      await tester.tap(placesTab);
      await tester.pumpAndSettle();

      expect(find.text('Old Delhi Baoli'), findsOneWidget);
      expect(find.textContaining('Level: VILLAGE'), findsOneWidget);
    });

    testWidgets('displays empty state when user has no contributions',
        (tester) async {
      mockRepo.returnEmptyActivity = true;
      await tester.pumpWidget(createTestProfileApp(authService: authService));
      await tester.pumpAndSettle();

      expect(find.text('No Stories Submitted'), findsOneWidget);
    });

    testWidgets('displays error state with retry button on activity fetch failure',
        (tester) async {
      mockRepo.activityShouldSucceed = false;
      await tester.pumpWidget(createTestProfileApp(authService: authService));
      await tester.pumpAndSettle();

      expect(find.text('Unable to reach activity server'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Recover and tap Retry
      mockRepo.activityShouldSucceed = true;
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Origins of the Stepwell'), findsOneWidget);
    });

    testWidgets('logout button opens confirmation dialog and clears session',
        (tester) async {
      await tester.pumpWidget(createTestProfileApp(authService: authService));
      await tester.pumpAndSettle();

      // Tap logout icon in AppBar
      final logoutIcon = find.byIcon(Icons.logout);
      expect(logoutIcon, findsOneWidget);
      await tester.tap(logoutIcon);
      await tester.pumpAndSettle();

      expect(find.text('Confirm Sign Out'), findsOneWidget);

      // Tap Sign Out button in dialog
      final confirmBtn = find.widgetWithText(FilledButton, 'Sign Out');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(mockRepo.wasLogoutCalled, isTrue);
      expect(authService.isAuthenticated, isFalse);
    });

    testWidgets(
        'renders Choose Your Place shortcut and navigates to PlacesPage',
        (tester) async {
      final mockPlaceRepo = MockProfilePlaceRepo();
      final placeService = PlaceService(repository: mockPlaceRepo);

      await tester.pumpWidget(
        createTestProfileApp(
          authService: authService,
          placeService: placeService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose Your Place'), findsOneWidget);
      expect(
        find.text(
          'Select your village, town, or district to add local information',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Choose Your Place'));
      await tester.pumpAndSettle();

      expect(find.byType(PlacesPage), findsOneWidget);
    });

    testWidgets(
        'empty places tab displays Select a Place to Contribute button and navigates to PlacesPage',
        (tester) async {
      mockRepo.returnEmptyActivity = true;
      final mockPlaceRepo = MockProfilePlaceRepo();
      final placeService = PlaceService(repository: mockPlaceRepo);

      await tester.pumpWidget(
        createTestProfileApp(
          authService: authService,
          placeService: placeService,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Places & Features tab (index 2)
      final placesTab = find.textContaining('Places & Features');
      expect(placesTab, findsOneWidget);
      await tester.ensureVisible(placesTab);
      await tester.tap(placesTab);
      await tester.pumpAndSettle();

      expect(find.text('No Place Contributions'), findsOneWidget);
      final contributeBtn =
          find.widgetWithText(FilledButton, 'Select a Place to Contribute');
      expect(contributeBtn, findsOneWidget);

      await tester.ensureVisible(contributeBtn);
      await tester.tap(contributeBtn);
      await tester.pumpAndSettle();

      expect(find.byType(PlacesPage), findsOneWidget);
    });

    testWidgets(
        'when no place is selected: shows Choose Your Place, hides Edit, and shows contribute action',
        (tester) async {
      final mockPlaceRepo = MockProfilePlaceRepo();
      final placeService = PlaceService(repository: mockPlaceRepo);

      await tester.pumpWidget(
        createTestProfileApp(
          authService: authService,
          placeService: placeService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose Your Place'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('इस स्थान के बारे में योगदान दें'), findsOneWidget);
    });

    testWidgets(
        'when place is selected: displays place name, location details, hides Choose Your Place, shows Edit',
        (tester) async {
      final mockPlaceRepo = MockProfilePlaceRepo();
      final placeService = PlaceService(repository: mockPlaceRepo);
      const testPlace = Place(
        id: 'plc-mandore',
        level: 'VILLAGE',
        canonicalName: 'Mandore Village',
        names: [
          PlaceName(language: 'en', name: 'Mandore Village'),
          PlaceName(language: 'hi', name: 'मांडोर गाँव'),
        ],
        parentPath: [
          PlacePathItem(id: 'plc-india', level: 'COUNTRY', canonicalName: 'India'),
          PlacePathItem(id: 'plc-raj', level: 'STATE', canonicalName: 'Rajasthan'),
        ],
      );

      await tester.pumpWidget(
        createTestProfileApp(
          authService: authService,
          placeService: placeService,
          initialSelectedPlace: testPlace,
        ),
      );
      await tester.pumpAndSettle();

      // Displays Selected Place card
      expect(find.text('Selected Place'), findsOneWidget);
      expect(find.text('Mandore Village'), findsOneWidget);
      expect(find.text('VILLAGE'), findsOneWidget);
      expect(find.text('ID: plc-mandore'), findsOneWidget);
      expect(find.text('India > Rajasthan'), findsOneWidget);

      // Choose Your Place is hidden, Edit is shown
      expect(find.text('Choose Your Place'), findsNothing);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('इस स्थान के बारे में योगदान दें'), findsOneWidget);
    });

    testWidgets(
        'Edit flow: tapping Edit opens Place selection and selecting a new Place updates selected place',
        (tester) async {
      final mockPlaceRepo = MockProfilePlaceRepo();
      const initialPlace = Place(
        id: 'plc-1',
        level: 'VILLAGE',
        canonicalName: 'Mandore Village',
        names: [PlaceName(language: 'en', name: 'Mandore Village')],
      );
      const newPlace = Place(
        id: 'plc-2',
        level: 'CITY_TOWN',
        canonicalName: 'Jodhpur City',
        names: [PlaceName(language: 'en', name: 'Jodhpur City')],
      );
      mockPlaceRepo.placesList = [newPlace];
      mockPlaceRepo.placesMap = {'plc-1': initialPlace, 'plc-2': newPlace};
      final placeService = PlaceService(repository: mockPlaceRepo);

      await tester.pumpWidget(
        createTestProfileApp(
          authService: authService,
          placeService: placeService,
          initialSelectedPlace: initialPlace,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mandore Village'), findsOneWidget);

      // Tap Edit
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.byType(PlacesPage), findsOneWidget);
      expect(find.text('Jodhpur City'), findsOneWidget);

      // Select new place
      await tester.tap(find.byType(PlaceCard));
      await tester.pumpAndSettle();

      // Verify Profile now displays new place details
      expect(find.text('Jodhpur City'), findsOneWidget);
      expect(find.text('CITY_TOWN'), findsOneWidget);
      expect(find.text('ID: plc-2'), findsOneWidget);
      expect(find.text('Mandore Village'), findsNothing);
    });

    testWidgets(
        'contribution option navigates to selected place detail and contribution flow',
        (tester) async {
      final mockPlaceRepo = MockProfilePlaceRepo();
      const testPlace = Place(
        id: 'plc-1',
        level: 'VILLAGE',
        canonicalName: 'Mandore Village',
        names: [PlaceName(language: 'en', name: 'Mandore Village')],
      );
      final placeService = PlaceService(repository: mockPlaceRepo);

      await tester.pumpWidget(
        createTestProfileApp(
          authService: authService,
          placeService: placeService,
          initialSelectedPlace: testPlace,
        ),
      );
      await tester.pumpAndSettle();

      final contributeOption = find.text('इस स्थान के बारे में योगदान दें');
      expect(contributeOption, findsOneWidget);

      await tester.tap(contributeOption);
      await tester.pumpAndSettle();

      // Navigated to PlaceDetailPage
      expect(find.byType(PlaceDetailPage), findsOneWidget);
      expect(find.text('Mandore Village'), findsWidgets);
      expect(find.text('Contribute Local Knowledge'), findsOneWidget);
    });

    testWidgets(
        'changing selected Place preserves historical activity contributions immutable',
        (tester) async {
      final mockPlaceRepo = MockProfilePlaceRepo();
      const initialPlace = Place(
        id: 'plc-1',
        level: 'VILLAGE',
        canonicalName: 'Mandore Village',
        names: [PlaceName(language: 'en', name: 'Mandore Village')],
      );
      const newPlace = Place(
        id: 'plc-2',
        level: 'CITY_TOWN',
        canonicalName: 'Jodhpur City',
        names: [PlaceName(language: 'en', name: 'Jodhpur City')],
      );
      mockPlaceRepo.placesList = [newPlace];
      mockPlaceRepo.placesMap = {'plc-1': initialPlace, 'plc-2': newPlace};
      final placeService = PlaceService(repository: mockPlaceRepo);

      await tester.pumpWidget(
        createTestProfileApp(
          authService: authService,
          placeService: placeService,
          initialSelectedPlace: initialPlace,
        ),
      );
      await tester.pumpAndSettle();

      // Historical claims are present
      expect(find.text('Origins of the Stepwell'), findsOneWidget);
      expect(find.text('Local Ghost Tree Legend'), findsOneWidget);

      // Change place via Edit
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PlaceCard));
      await tester.pumpAndSettle();

      // Selected place updated to Jodhpur City
      expect(find.text('Jodhpur City'), findsOneWidget);

      // Verify past activity contributions still intact with their original historical data
      expect(find.text('Origins of the Stepwell'), findsOneWidget);
      expect(find.text('Local Ghost Tree Legend'), findsOneWidget);
      expect(find.text('VERIFIED'), findsOneWidget);
    });

    testWidgets(
        'persistence/reload: loads selected place from SharedPreferences on Profile launch without initialSelectedPlace',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'selected_place_id_usr-999': 'plc-persisted',
      });
      final mockPlaceRepo = MockProfilePlaceRepo();
      const persistedPlace = Place(
        id: 'plc-persisted',
        level: 'VILLAGE',
        canonicalName: 'Persisted Heritage Village',
        names: [PlaceName(language: 'en', name: 'Persisted Heritage Village')],
      );
      mockPlaceRepo.placesMap = {'plc-persisted': persistedPlace};
      final placeService = PlaceService(repository: mockPlaceRepo);

      await tester.pumpWidget(
        createTestProfileApp(
          authService: authService,
          placeService: placeService,
        ),
      );
      await tester.pumpAndSettle();

      // Assert place name appears
      expect(find.text('Persisted Heritage Village'), findsOneWidget);
      // Assert Choose Your Place does not appear
      expect(find.text('Choose Your Place'), findsNothing);
      // Assert Edit is available
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets(
        'user-isolation: User B with separate ID does not see User A selected place and shows Choose Your Place',
        (tester) async {
      // Setup preferences with User A's selection
      SharedPreferences.setMockInitialValues({
        'selected_place_id_user-A': 'plc-user-A',
      });

      final mockPlaceRepo = MockProfilePlaceRepo();
      const placeA = Place(
        id: 'plc-user-A',
        level: 'VILLAGE',
        canonicalName: 'Place of User A',
        names: [PlaceName(language: 'en', name: 'Place of User A')],
      );
      mockPlaceRepo.placesMap = {'plc-user-A': placeA};
      final placeService = PlaceService(repository: mockPlaceRepo);

      // Create User B with separate ID and verifiedLocationId: null
      final userB = User(
        id: 'user-B',
        displayName: 'User B',
        role: 'CONTRIBUTOR',
        joinedAt: DateTime.parse('2025-01-01T00:00:00.000Z'),
        isIdentityVerified: false,
        verifiedLocationId: null,
      );

      final mockRepoB = MockProfileAuthRepo();
      final authServiceB = AuthService(repository: mockRepoB);
      authServiceB.setSession(
        AuthTokens(
          accessToken: 'token-B',
          refreshToken: 'refresh-B',
          user: userB,
        ),
      );

      await tester.pumpWidget(
        createTestProfileApp(
          authService: authServiceB,
          placeService: placeService,
        ),
      );
      await tester.pumpAndSettle();

      // Assert User A's place is NOT visible to User B
      expect(find.text('Place of User A'), findsNothing);
      expect(find.text('Selected Place'), findsNothing);

      // Assert User B sees Choose Your Place state
      expect(find.text('Choose Your Place'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets(
        'verified-location badge integrity: changing local selected Place leaves user.verifiedLocationId and Location Verified badge intact',
        (tester) async {
      final mockPlaceRepo = MockProfilePlaceRepo();
      const verifiedPlace = Place(
        id: 'loc-delhi',
        level: 'DISTRICT',
        canonicalName: 'Old Delhi District',
        names: [PlaceName(language: 'en', name: 'Old Delhi District')],
      );
      const newPlace = Place(
        id: 'plc-jaipur',
        level: 'CITY_TOWN',
        canonicalName: 'Jaipur City',
        names: [PlaceName(language: 'en', name: 'Jaipur City')],
      );
      mockPlaceRepo.placesList = [newPlace];
      mockPlaceRepo.placesMap = {
        'loc-delhi': verifiedPlace,
        'plc-jaipur': newPlace,
      };
      final placeService = PlaceService(repository: mockPlaceRepo);

      // User has verifiedLocationId: 'loc-delhi'
      expect(authService.currentUser?.verifiedLocationId, equals('loc-delhi'));

      await tester.pumpWidget(
        createTestProfileApp(
          authService: authService,
          placeService: placeService,
          initialSelectedPlace: verifiedPlace,
        ),
      );
      await tester.pumpAndSettle();

      // Initial state: Selected Place is Old Delhi District
      expect(find.text('Old Delhi District'), findsOneWidget);
      // Location Verified badge is rendered on User Identity Card
      expect(find.text('Location Verified'), findsOneWidget);

      // User edits selected place to Jaipur City
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PlaceCard));
      await tester.pumpAndSettle();

      // Selected place updated to Jaipur City
      expect(find.text('Jaipur City'), findsOneWidget);

      // Assert badge integrity:
      // 1. The official "Location Verified" badge still renders on User Identity Card
      expect(find.text('Location Verified'), findsOneWidget);
      // 2. The underlying User object's verifiedLocationId is NOT mutated by local selection
      expect(authService.currentUser?.verifiedLocationId, equals('loc-delhi'));
      expect(authService.currentUser?.verifiedLocationId, isNot(equals('plc-jaipur')));
    });

    testWidgets(
        'server-authoritative reload: loads selected place from user.selectedPlaceId on Profile launch without SharedPreferences',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final customUser = User(
        id: 'usr-server-persisted',
        displayName: 'Server User',
        role: 'CONTRIBUTOR',
        joinedAt: DateTime.parse('2024-03-10T09:30:00.000Z'),
        isIdentityVerified: false,
        selectedPlaceId: 'plc-server-1',
      );
      final customAuthRepo = MockProfileAuthRepo();
      final customAuthService = AuthService(repository: customAuthRepo);
      customAuthService.setSession(
        AuthTokens(accessToken: 'token-s', refreshToken: 'ref-s', user: customUser),
      );

      final mockPlaceRepo = MockProfilePlaceRepo();
      const serverPlace = Place(
        id: 'plc-server-1',
        level: 'VILLAGE',
        canonicalName: 'Mandore Server Village',
        names: [PlaceName(language: 'en', name: 'Mandore Server Village')],
      );
      mockPlaceRepo.placesMap = {'plc-server-1': serverPlace};
      final placeService = PlaceService(repository: mockPlaceRepo);

      await tester.pumpWidget(
        createTestProfileApp(
          authService: customAuthService,
          placeService: placeService,
        ),
      );
      await tester.pumpAndSettle();

      // Assert place name resolved from server user.selectedPlaceId
      expect(find.text('Mandore Server Village'), findsOneWidget);
      expect(find.text('Choose Your Place'), findsNothing);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets(
        'server persistence failure: when backend update fails, shows error snackbar and does not falsely confirm selection',
        (tester) async {
      final mockAuthRepo = MockProfileAuthRepo();
      mockAuthRepo.updateSelectedPlaceShouldSucceed = false;
      final testAuthService = AuthService(repository: mockAuthRepo);
      testAuthService.setSession(
        AuthTokens(accessToken: 'acc-1', refreshToken: 'ref-1', user: mockAuthRepo.user),
      );

      final mockPlaceRepo = MockProfilePlaceRepo();
      const initialPlace = Place(
        id: 'plc-initial',
        level: 'VILLAGE',
        canonicalName: 'Initial Village',
        names: [PlaceName(language: 'en', name: 'Initial Village')],
      );
      const newPlace = Place(
        id: 'plc-failed-target',
        level: 'CITY_TOWN',
        canonicalName: 'Target City',
        names: [PlaceName(language: 'en', name: 'Target City')],
      );
      mockPlaceRepo.placesList = [newPlace];
      mockPlaceRepo.placesMap = {
        'plc-initial': initialPlace,
        'plc-failed-target': newPlace,
      };
      final placeService = PlaceService(repository: mockPlaceRepo);

      await tester.pumpWidget(
        createTestProfileApp(
          authService: testAuthService,
          placeService: placeService,
          initialSelectedPlace: initialPlace,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Initial Village'), findsOneWidget);

      // Tap Edit and choose new place
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PlaceCard));
      await tester.pumpAndSettle();

      // Because server update failed:
      // 1. Error snackbar is shown
      expect(find.text('Failed to update selected place on server'), findsOneWidget);
      // 2. Selected place in ProfilePage remains 'Initial Village', NOT 'Target City'
      expect(find.text('Initial Village'), findsOneWidget);
      expect(find.text('Target City'), findsNothing);
    });
  });
}
