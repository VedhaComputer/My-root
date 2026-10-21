import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/core/error/failures.dart';
import 'package:my_root/models/auth_dtos.dart';
import 'package:my_root/models/place.dart';
import 'package:my_root/models/user.dart';
import 'package:my_root/models/user_activity.dart';
import 'package:my_root/repositories/auth_repository.dart';
import 'package:my_root/repositories/place_repository.dart';
import 'package:my_root/services/auth_service.dart';
import 'package:my_root/services/place_service.dart';
import 'package:my_root/ui/widgets/app_header.dart';
import 'package:my_root/ui/widgets/home_features_drawer.dart';
import 'package:my_root/ui/widgets/latest_users_drawer.dart';
import 'package:my_root/ui/widgets/location_search_dialog.dart';

class MockTestHttp extends http.BaseClient {
  http.Response Function(http.Request request)? handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final httpRequest = request as http.Request;
    final res = handler != null
        ? handler!(httpRequest)
        : http.Response('{"data": {}}', 200, headers: {'content-type': 'application/json'});
    return http.StreamedResponse(
      Stream.value(utf8.encode(res.body)),
      res.statusCode,
      headers: res.headers,
    );
  }
}

class MockSidebarsAuthRepo implements AuthRepository {
  ApiResponse<List<PublicUser>> latestUsersResponse =
      const ApiResponse.failure(NotFoundFailure(message: 'Route not found'));

  User testUser = User(
    id: 'user-sidebar-1',
    displayName: 'Aarav Sharma',
    role: 'CONTRIBUTOR',
    joinedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
    selectedPlaceId: 'place-jaipur-1',
  );

  @override
  Future<ApiResponse<AuthTokens>> login(String email, String password) async {
    return ApiResponse.success(
      AuthTokens(accessToken: 'token-1', refreshToken: 'ref-1', user: testUser),
    );
  }

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
  Future<ApiResponse<AuthTokens>> refreshToken(String refreshToken) async {
    return ApiResponse.success(
      AuthTokens(accessToken: 'token-2', refreshToken: 'ref-2', user: testUser),
    );
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> logout({String? refreshToken}) async {
    return const ApiResponse.success({'message': 'Logged out'});
  }

  @override
  Future<ApiResponse<RegisterResponse>> register(
      String displayName, String email, String password) async {
    return const ApiResponse.success(RegisterResponse(message: 'Registered'));
  }

  @override
  Future<ApiResponse<UserActivity>> getUserActivity() async {
    return const ApiResponse.success(UserActivity(
      summary: UserActivitySummary(
          totalContributions: 0,
          claimsCount: 0,
          evidencesCount: 0,
          placesCount: 0,
          placeAttributesCount: 0),
      claims: [],
      evidences: [],
      places: [],
      placeAttributes: [],
    ));
  }

  @override
  Future<ApiResponse<List<PublicUser>>> getLatestUsers() async {
    return latestUsersResponse;
  }
}

class MockSidebarsPlaceRepo implements PlaceRepository {
  @override
  final ApiClient client = ApiClient();

  Map<String, Place> places = {
    'place-jaipur-1': const Place(
      id: 'place-jaipur-1',
      canonicalName: 'Jaipur',
      level: 'CITY_TOWN',
      names: [PlaceName(language: 'en', name: 'Jaipur')],
    ),
    'place-jodhpur-2': const Place(
      id: 'place-jodhpur-2',
      canonicalName: 'Jodhpur',
      level: 'CITY_TOWN',
      names: [PlaceName(language: 'en', name: 'Jodhpur')],
    ),
  };

  @override
  Future<ApiResponse<List<Place>>> getPlaces({
    String? level,
    String? parentId,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    return ApiResponse.success(places.values.toList());
  }

  @override
  Future<ApiResponse<Place>> getPlaceById(String id) async {
    if (places.containsKey(id)) {
      return ApiResponse.success(places[id]!);
    }
    return const ApiResponse.failure(NotFoundFailure(message: 'Place not found'));
  }

  @override
  Future<ApiResponse<List<Place>>> getChildren(String parentId) async =>
      const ApiResponse.success([]);

  @override
  Future<ApiResponse<Place>> createPlace({
    required String level,
    required String canonicalName,
    required List<PlaceName> names,
    String? parentId,
  }) async =>
      ApiResponse.success(Place(id: 'new', level: level, canonicalName: canonicalName, names: names));

  @override
  Future<ApiResponse<Place>> updatePlace({
    required String id,
    String? level,
    String? canonicalName,
    List<PlaceName>? names,
    String? parentId,
  }) async =>
      ApiResponse.success(Place(id: id, level: level ?? 'CITY_TOWN', canonicalName: canonicalName ?? 'Updated', names: names ?? []));

  @override
  Future<ApiResponse<Map<String, dynamic>>> deletePlace(String id) async =>
      const ApiResponse.success({});
}

Widget createTestWrapper({
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

  group('Global Header (GlobalAppBar) Tests', () {
    late MockSidebarsAuthRepo authRepo;
    late AuthService authService;
    late MockSidebarsPlaceRepo placeRepo;
    late PlaceService placeService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      authRepo = MockSidebarsAuthRepo();
      authService = AuthService(repository: authRepo);
      placeRepo = MockSidebarsPlaceRepo();
      placeService = PlaceService(repository: placeRepo);
    });

    testWidgets('1. Displays resolved selected location name "Jaipur" when place is selected', (tester) async {
      await authService.login('aarav@example.com', 'pass');
      placeService.setSelectedPlace(placeRepo.places['place-jaipur-1']);

      await tester.pumpWidget(
        createTestWrapper(
          child: Scaffold(
            appBar: GlobalAppBar(
              authService: authService,
              placeService: placeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('header_selected_location')), findsOneWidget);
      expect(find.text('Jaipur'), findsOneWidget);
      expect(find.byIcon(Icons.place), findsOneWidget);
    });

    testWidgets('2. Displays "Select Location" fallback when no place is selected', (tester) async {
      authRepo.testUser = authRepo.testUser.copyWith(clearSelectedPlace: true);
      await authService.login('aarav@example.com', 'pass');
      placeService.setSelectedPlace(null);

      await tester.pumpWidget(
        createTestWrapper(
          child: Scaffold(
            appBar: GlobalAppBar(
              authService: authService,
              placeService: placeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('header_location_selector')), findsOneWidget);
      expect(find.text('Places'), findsOneWidget);
      expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    });

    testWidgets('3. Tapping location button opens PlacesPage in selection mode and updates location', (tester) async {
      await authService.login('aarav@example.com', 'pass');
      placeService.setSelectedPlace(placeRepo.places['place-jaipur-1']);

      bool placeChangedNotified = false;

      await tester.pumpWidget(
        createTestWrapper(
          child: Scaffold(
            appBar: GlobalAppBar(
              authService: authService,
              placeService: placeService,
              onPlaceChanged: () {
                placeChangedNotified = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap header location button
      await tester.tap(find.byKey(const Key('header_selected_location')));
      await tester.pumpAndSettle();

      // Opens LocationSearchDialog without full-page navigation
      expect(find.byType(LocationSearchDialog), findsOneWidget);
      expect(find.text('Select Location'), findsOneWidget);

      // Empty query shows prompt and does not dump full list
      expect(find.byKey(const Key('location_search_prompt')), findsOneWidget);
      expect(find.text('Jodhpur'), findsNothing);

      // Type search query
      await tester.enterText(find.byKey(const Key('location_search_input')), 'Jodhpur');
      await tester.pumpAndSettle();

      // Jodhpur matches query; Jaipur is excluded from dialog search results
      expect(find.descendant(of: find.byType(LocationSearchDialog), matching: find.widgetWithText(ListTile, 'Jodhpur')), findsOneWidget);
      expect(find.descendant(of: find.byType(LocationSearchDialog), matching: find.widgetWithText(ListTile, 'Jaipur')), findsNothing);

      // Select Jodhpur
      await tester.tap(find.descendant(of: find.byType(LocationSearchDialog), matching: find.widgetWithText(ListTile, 'Jodhpur')));
      await tester.pumpAndSettle();

      // Returned to previous screen with Jodhpur in header
      expect(find.byType(LocationSearchDialog), findsNothing);
      expect(find.text('Jodhpur'), findsOneWidget);
      expect(placeChangedNotified, isTrue);
    });

    testWidgets('4. Resolves location asynchronously from PlaceService using selectedPlaceId', (tester) async {
      authRepo.testUser = authRepo.testUser.copyWith(selectedPlaceId: 'place-jodhpur-2');
      await authService.login('aarav@example.com', 'pass');
      // Place is NOT yet in placeService.selectedPlace in memory
      expect(placeService.selectedPlace, isNull);

      await tester.pumpWidget(
        createTestWrapper(
          child: Scaffold(
            appBar: GlobalAppBar(
              authService: authService,
              placeService: placeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Correctly resolved to Jodhpur without displaying raw ID 'place-jodhpur-2'
      expect(find.text('Jodhpur'), findsOneWidget);
      expect(find.text('place-jodhpur-2'), findsNothing);
    });
  });

  group('Left Sidebar (HomeFeaturesDrawer) Tests', () {
    testWidgets('1. Exposes all 9 Home Page shortcuts in left drawer and auto-closes on tap', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool exploreTapped = false;
      bool contributeTapped = false;
      String? categoryTapped;
      bool addTapped = false;

      await tester.pumpWidget(
        createTestWrapper(
          child: Scaffold(
            drawer: HomeFeaturesDrawer(
              selectedPlaceName: 'Jaipur',
              onExploreStories: () => exploreTapped = true,
              onContribute: () => contributeTapped = true,
              onCategory: (cat) => categoryTapped = cat,
              onAdd: () => addTapped = true,
            ),
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  key: const Key('open_drawer_btn'),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open left drawer
      await tester.tap(find.byKey(const Key('open_drawer_btn')));
      await tester.pumpAndSettle();

      // Verify all 9 shortcuts are present
      expect(find.byKey(const Key('feature_explore_stories')), findsOneWidget);
      expect(find.byKey(const Key('feature_contribute')), findsOneWidget);
      expect(find.byKey(const Key('feature_historical_record')), findsOneWidget);
      expect(find.byKey(const Key('feature_current_fact')), findsOneWidget);
      expect(find.byKey(const Key('feature_folklore')), findsOneWidget);
      expect(find.byKey(const Key('feature_personal_experience')), findsOneWidget);
      expect(find.byKey(const Key('feature_public_opinion')), findsOneWidget);
      expect(find.byKey(const Key('feature_survey_data')), findsOneWidget);
      expect(find.byKey(const Key('feature_add')), findsOneWidget);

      // Verify active location is visible in drawer header
      expect(find.text('Jaipur'), findsOneWidget);

      // Tap Explore Stories -> must close drawer and trigger callback
      await tester.tap(find.byKey(const Key('feature_explore_stories')));
      await tester.pumpAndSettle();

      expect(exploreTapped, isTrue);
      // Drawer is closed
      expect(find.byType(HomeFeaturesDrawer), findsNothing);

      // Re-open and test Contribute shortcut
      await tester.tap(find.byKey(const Key('open_drawer_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('feature_contribute')));
      await tester.pumpAndSettle();

      expect(contributeTapped, isTrue);
      expect(find.byType(HomeFeaturesDrawer), findsNothing);

      // Re-open and test Category shortcut
      await tester.tap(find.byKey(const Key('open_drawer_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('feature_folklore')));
      await tester.pumpAndSettle();

      expect(categoryTapped, equals('FOLKLORE'));
      expect(find.byType(HomeFeaturesDrawer), findsNothing);

      // Re-open and test Add shortcut
      await tester.tap(find.byKey(const Key('open_drawer_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('feature_add')));
      await tester.pumpAndSettle();

      expect(addTapped, isTrue);
      expect(find.byType(HomeFeaturesDrawer), findsNothing);
    });

    testWidgets('2. Dismisses left drawer via close icon button', (tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          child: Scaffold(
            drawer: HomeFeaturesDrawer(
              onExploreStories: () {},
              onContribute: () {},
              onCategory: (_) {},
              onAdd: () {},
            ),
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeFeaturesDrawer), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(HomeFeaturesDrawer), findsNothing);
    });
  });

  group('Right Sidebar (LatestUsersDrawer) Privacy & State Tests', () {
    late MockSidebarsAuthRepo authRepo;
    late AuthService authService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      authRepo = MockSidebarsAuthRepo();
      authService = AuthService(repository: authRepo);
    });

    testWidgets('1. Displays "Public Directory Unavailable" when backend returns 404 (privacy protected)', (tester) async {
      authRepo.latestUsersResponse =
          const ApiResponse.failure(NotFoundFailure(message: 'Route not found'));

      await tester.pumpWidget(
        createTestWrapper(
          child: Scaffold(
            endDrawer: LatestUsersDrawer(authService: authService),
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                child: const Text('Open Right'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open right drawer
      await tester.tap(find.text('Open Right'));
      await tester.pumpAndSettle();

      expect(find.text('Latest Users'), findsOneWidget);
      expect(find.byKey(const Key('latest_users_unsupported')), findsOneWidget);
      expect(find.text('Public Directory Unavailable'), findsOneWidget);
      expect(
        find.text('A public user directory API is not exposed by the current backend to protect user privacy.'),
        findsOneWidget,
      );
    });

    testWidgets('2. Displays public users safely without leaking email, phone, or IDs', (tester) async {
      final sampleUsers = [
        PublicUser(
          displayName: 'Vikram Singh',
          avatarUrl: null,
          joinedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        PublicUser(
          displayName: 'Ananya Roy',
          avatarUrl: null,
          joinedAt: DateTime.now().subtract(const Duration(days: 45)),
        ),
      ];

      authRepo.latestUsersResponse = ApiResponse.success(sampleUsers);

      await tester.pumpWidget(
        createTestWrapper(
          child: Scaffold(
            endDrawer: LatestUsersDrawer(authService: authService),
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                child: const Text('Open Right'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Right'));
      await tester.pumpAndSettle();

      // Verified users are rendered with public display names and joined date
      expect(find.text('Vikram Singh'), findsOneWidget);
      expect(find.text('Joined 2d ago'), findsOneWidget);
      expect(find.text('Ananya Roy'), findsOneWidget);
      expect(find.text('Joined 1mo ago'), findsOneWidget);

      // STRICT PRIVACY AUDIT: Assert that private fields (emails, phone numbers, IDs) are NEVER rendered
      expect(find.textContaining('@'), findsNothing);
      expect(find.textContaining('phone'), findsNothing);
      expect(find.textContaining('user-sidebar-1'), findsNothing);
      expect(find.textContaining('token'), findsNothing);
      expect(find.textContaining('password'), findsNothing);
    });

    testWidgets('3. Displays empty state message when list is empty', (tester) async {
      authRepo.latestUsersResponse = const ApiResponse.success([]);

      await tester.pumpWidget(
        createTestWrapper(
          child: Scaffold(
            endDrawer: LatestUsersDrawer(authService: authService),
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                child: const Text('Open Right'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Right'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('latest_users_empty')), findsOneWidget);
      expect(find.text('No recent users found.'), findsOneWidget);
    });

    testWidgets('4. Displays error state and allows retry on network failure', (tester) async {
      authRepo.latestUsersResponse =
          const ApiResponse.failure(ServerFailure(message: 'Connection timed out'));

      await tester.pumpWidget(
        createTestWrapper(
          child: Scaffold(
            endDrawer: LatestUsersDrawer(authService: authService),
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                child: const Text('Open Right'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Right'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('latest_users_error')), findsOneWidget);
      expect(find.text('Connection timed out'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Now fix response and tap retry
      authRepo.latestUsersResponse = ApiResponse.success([
        PublicUser(
          displayName: 'Pooja Nair',
          avatarUrl: null,
          joinedAt: DateTime.now(),
        ),
      ]);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Pooja Nair'), findsOneWidget);
    });

    testWidgets('5. Left control opens Functions and right control opens Latest Users', (tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          child: Scaffold(
            appBar: const GlobalAppBar(),
            drawer: HomeFeaturesDrawer(
              onExploreStories: () {},
              onContribute: () {},
              onCategory: (_) {},
              onAdd: () {},
            ),
            endDrawer: LatestUsersDrawer(authService: authService),
            body: const Center(child: Text('Body')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap left control -> opens HomeFeaturesDrawer (Functions)
      final leftControl = find.byKey(const Key('home_features_drawer_button'));
      expect(leftControl, findsOneWidget);
      await tester.tap(leftControl);
      await tester.pumpAndSettle();

      expect(find.byType(HomeFeaturesDrawer), findsOneWidget);
      expect(find.byType(LatestUsersDrawer), findsNothing);

      // Close left drawer
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(HomeFeaturesDrawer), findsNothing);

      // Tap right control -> opens LatestUsersDrawer (Latest Users)
      final rightControl = find.byKey(const Key('latest_users_drawer_button'));
      expect(rightControl, findsOneWidget);
      await tester.tap(rightControl);
      await tester.pumpAndSettle();

      expect(find.byType(LatestUsersDrawer), findsOneWidget);
      expect(find.byType(HomeFeaturesDrawer), findsNothing);
    });
  });
}
