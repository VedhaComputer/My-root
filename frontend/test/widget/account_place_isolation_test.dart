import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/place.dart';
import 'package:my_root/models/user.dart';
import 'package:my_root/repositories/auth_repository.dart';
import 'package:my_root/repositories/community_repository.dart';
import 'package:my_root/repositories/place_repository.dart';
import 'package:my_root/services/auth_service.dart';
import 'package:my_root/services/community_service.dart';
import 'package:my_root/services/place_service.dart';
import 'package:my_root/ui/pages/home/home_page.dart';

class MockIsolationHttpClient extends http.BaseClient {
  FutureOr<http.Response> Function(http.Request request)? handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final httpRequest = request as http.Request;
    final response = handler != null
        ? await handler!(httpRequest)
        : http.Response('{"error": {"code": "NOT_FOUND", "message": "Not found"}}', 404);

    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

class MockIsolationAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  User? user;

  @override
  Future<ApiResponse<AuthTokens>> login(String email, String password) async {
    return ApiResponse.success(
      AuthTokens(accessToken: 'acc-token', refreshToken: 'ref-token', user: user!),
    );
  }

  @override
  Future<ApiResponse<User>> getMe() async {
    return ApiResponse.success(user!);
  }

  @override
  Future<ApiResponse<User>> updateSelectedPlace(String? placeId) async {
    user = user?.copyWith(selectedPlaceId: placeId);
    return ApiResponse.success(user!);
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> logout({String? refreshToken}) async {
    return const ApiResponse.success({});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const placeA = Place(
    id: 'place-A',
    canonicalName: 'Place Alpha',
    level: 'CITY_TOWN',
    names: [PlaceName(language: 'en', name: 'Place Alpha')],
  );

  const placeB = Place(
    id: 'place-B',
    canonicalName: 'Place Beta',
    level: 'VILLAGE',
    names: [PlaceName(language: 'en', name: 'Place Beta')],
  );

  final userA = User(
    id: 'user-A',
    displayName: 'User Alpha',
    role: 'CONTRIBUTOR',
    joinedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
    selectedPlaceId: 'place-A',
  );

  final userB = User(
    id: 'user-B',
    displayName: 'User Beta',
    role: 'CONTRIBUTOR',
    joinedAt: DateTime.parse('2026-02-01T00:00:00.000Z'),
    selectedPlaceId: null,
  );

  late MockIsolationHttpClient mockHttp;
  late ApiClient apiClient;
  late MockIsolationAuthRepo authRepo;
  late AuthService authService;
  late PlaceService placeService;
  late CommunityService communityService;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    mockHttp = MockIsolationHttpClient();
    apiClient = ApiClient(client: mockHttp);
    authRepo = MockIsolationAuthRepo();
    authService = AuthService(repository: authRepo);
    placeService = PlaceService(repository: PlaceRepositoryImpl(client: apiClient));
    communityService = CommunityService(repository: CommunityRepositoryImpl(client: apiClient));

    mockHttp.handler = (req) {
      if (req.url.path.endsWith('/places/place-A')) {
        return http.Response(
          jsonEncode({'data': placeA.toJson()}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (req.url.path.endsWith('/places/place-B')) {
        return http.Response(
          jsonEncode({'data': placeB.toJson()}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (req.url.path.endsWith('/places')) {
        return http.Response(
          jsonEncode({'data': [placeA.toJson(), placeB.toJson()], 'pagination': {'total': 2}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (req.url.path.contains('/claims')) {
        return http.Response(
          jsonEncode({'data': [], 'pagination': {'total': 0}}),
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
      if (req.url.path.contains('/progress')) {
        return http.Response(
          jsonEncode({'data': {'placeId': req.url.pathSegments.last, 'claimsCount': 0}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"error": "not found"}', 404);
    };
  });

  Widget buildApp() {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomePage(
        authService: authService,
        placeService: placeService,
        communityService: communityService,
        apiClient: apiClient,
      ),
    );
  }

  group('Cross-Account Place Isolation & Leakage Prevention', () {
    testWidgets('1. Account A selects Place A -> Logout -> Account B (no place) does NOT see Place A', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Step 1: User A logs in and has Place A
      authRepo.user = userA;
      await authService.setSession(
        AuthTokens(accessToken: 'token-A', refreshToken: 'ref-A', user: userA),
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Verify User A sees Place Alpha in the GlobalAppBar
      expect(find.byKey(const Key('header_selected_location')), findsOneWidget);
      expect(find.text('Place Alpha'), findsWidgets);

      // Step 2: User A logs out
      await authService.logout();
      await tester.pumpAndSettle();

      // State is unauthenticated and header shows Select Location
      expect(find.byKey(const Key('header_location_selector')), findsOneWidget);
      expect(find.byKey(const Key('header_selected_location')), findsNothing);

      // Step 3: User B logs in (new account with no selection)
      authRepo.user = userB;
      await authService.setSession(
        AuthTokens(accessToken: 'token-B', refreshToken: 'ref-B', user: userB),
      );
      await tester.pumpAndSettle();

      // CRITICAL ASSERTION: User B MUST NOT inherit User A's Place Alpha!
      expect(find.text('Place Alpha'), findsNothing);
      expect(find.byKey(const Key('header_selected_location')), findsNothing);
      expect(find.byKey(const Key('header_location_selector')), findsOneWidget);

      // HomePage displays the unauthenticated or no-place home state
      final homeState = tester.state<HomePageState>(find.byType(HomePage));
      expect(homeState.currentSelectedPlaceForTesting, isNull);
    });

    testWidgets('2. Account B selects Place B, and re-logging in as Account A restores Place A', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // User B logs in with no initial place
      authRepo.user = userB;
      await authService.setSession(
        AuthTokens(accessToken: 'token-B', refreshToken: 'ref-B', user: userB),
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('header_location_selector')), findsOneWidget);

      // User B selects Place B via placeService and simulates SharedPreferences user cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_place_id_${userB.id}', 'place-B');
      await prefs.setString('selected_place_name_${userB.id}', 'Place Beta');
      authRepo.user = userB.copyWith(selectedPlaceId: 'place-B');
      await authService.updateSelectedPlace('place-B');
      placeService.setSelectedPlace(placeB, userId: userB.id);

      await tester.pumpAndSettle();

      // User B now sees Place Beta
      expect(find.text('Place Beta'), findsWidgets);
      expect(find.text('Place Alpha'), findsNothing);

      // User B logs out
      await authService.logout();
      await tester.pumpAndSettle();

      // User A logs back in (User A originally had Place A)
      authRepo.user = userA;
      await authService.setSession(
        AuthTokens(accessToken: 'token-A', refreshToken: 'ref-A', user: userA),
      );
      await tester.pumpAndSettle();

      // User A sees Place Alpha, NOT User B's Place Beta
      expect(find.text('Place Alpha'), findsWidgets);
      expect(find.text('Place Beta'), findsNothing);
    });

    testWidgets('3. In-flight delayed resolution from User A is discarded on account switch to User B', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final delayedPlaceACompleter = Completer<http.Response>();

      // Intercept place-A requests to simulate slow network
      mockHttp.handler = (req) {
        if (req.url.path.endsWith('/places/place-A')) {
          return delayedPlaceACompleter.future;
        }
        if (req.url.path.endsWith('/places/place-B')) {
          return http.Response(
            jsonEncode({'data': placeB.toJson()}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path.contains('/claims')) {
          return http.Response(jsonEncode({'data': [], 'pagination': {'total': 0}}), 200, headers: {'content-type': 'application/json'});
        }
        if (req.url.path.contains('/progress')) {
          return http.Response(
            jsonEncode({'data': {'placeId': 'place-A', 'claimsCount': 0}}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path.contains('/attributes')) {
          return http.Response(jsonEncode({'data': []}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{"error": "not found"}', 404);
      };

      authRepo.user = userA;
      await authService.setSession(
        AuthTokens(accessToken: 'token-A', refreshToken: 'ref-A', user: userA),
      );

      await tester.pumpWidget(buildApp());
      await tester.pump(); // Starts loading Place A for User A, currently paused

      // Account switch occurs while User A's place resolution is in flight!
      authRepo.user = userB;
      await authService.setSession(
        AuthTokens(accessToken: 'token-B', refreshToken: 'ref-B', user: userB),
      );
      await tester.pump();

      // Now the delayed response for Place A finally completes
      delayedPlaceACompleter.complete(
        http.Response(
          jsonEncode({'data': placeA.toJson()}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await tester.pumpAndSettle();

      // The late response from User A's session must NOT leak into User B's UI!
      expect(find.text('Place Alpha'), findsNothing);
      expect(find.byKey(const Key('header_location_selector')), findsOneWidget);
    });

    testWidgets('4. Guest selection in SharedPreferences does NOT leak into User B with no place, and User B logout preserves isolation', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Guest has legacy unscoped selected_place_id = 'place-A'
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_place_id', 'place-A');
      await prefs.setString('selected_place_name', 'Place Alpha');

      // User B logs in (has no selected place)
      authRepo.user = userB;
      await authService.setSession(
        AuthTokens(accessToken: 'token-B', refreshToken: 'ref-B', user: userB),
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // User B MUST NOT see guest's Place Alpha or inherit it
      expect(find.byKey(const Key('header_location_selector')), findsOneWidget);
      expect(find.byKey(const Key('header_selected_location')), findsNothing);
      expect(find.text('Place Alpha'), findsNothing);

      // Verify user-scoped prefs for User B was NOT polluted
      expect(prefs.getString('selected_place_id_${userB.id}'), isNull);

      // User B logs out -> returns to guest session
      await authService.logout();
      await tester.pumpAndSettle();

      // Guest retains their own previous selection or shows clean prompt
      // and does NOT see any authenticated data
      expect(authService.isAuthenticated, isFalse);
    });
  });
}
