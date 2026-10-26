import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_root/core/error/failures.dart';
import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/place.dart';
import 'package:my_root/repositories/place_repository.dart';
import 'package:my_root/services/place_service.dart';
import 'package:my_root/ui/widgets/location_search_dialog.dart';

class FakeTestPlaceRepo implements PlaceRepository {
  @override
  final ApiClient client = ApiClient();

  int getPlacesCallCount = 0;
  final List<String?> requestedSearches = [];
  Future<ApiResponse<List<Place>>> Function({
    String? level,
    String? parentId,
    String? search,
    int page,
    int limit,
  })? customGetPlacesHandler;

  final List<Place> allPlaces = [
    const Place(
      id: 'place-jaipur',
      canonicalName: 'Jaipur',
      level: 'CITY_TOWN',
      names: [PlaceName(language: 'en', name: 'Jaipur'), PlaceName(language: 'hi', name: 'जयपुर')],
    ),
    const Place(
      id: 'place-jodhpur',
      canonicalName: 'Jodhpur',
      level: 'CITY_TOWN',
      names: [PlaceName(language: 'en', name: 'Jodhpur')],
    ),
    const Place(
      id: 'place-mandore',
      canonicalName: 'Mandore Village',
      level: 'VILLAGE',
      names: [PlaceName(language: 'en', name: 'Mandore Village')],
    ),
    const Place(
      id: 'place-amer',
      canonicalName: 'Amer Town',
      level: 'CITY_TOWN',
      names: [PlaceName(language: 'en', name: 'Amer Town')],
    ),
  ];

  @override
  Future<ApiResponse<List<Place>>> getPlaces({
    String? level,
    String? parentId,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    getPlacesCallCount++;
    requestedSearches.add(search);
    if (customGetPlacesHandler != null) {
      return customGetPlacesHandler!(
        level: level,
        parentId: parentId,
        search: search,
        page: page,
        limit: limit,
      );
    }
    var result = List<Place>.from(allPlaces);
    if (level != null && level.isNotEmpty) {
      result = result.where((p) => p.level == level).toList();
    }
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      result = result.where((p) {
        if (p.canonicalName.toLowerCase().contains(q)) return true;
        for (final n in p.names) {
          if (n.name.toLowerCase().contains(q)) return true;
        }
        return false;
      }).toList();
    }
    return ApiResponse.success(result.take(limit).toList());
  }

  @override
  Future<ApiResponse<Place>> getPlaceById(String id) async {
    final p = allPlaces.where((p) => p.id == id).firstOrNull;
    if (p != null) return ApiResponse.success(p);
    return const ApiResponse.failure(null);
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
      throw UnimplementedError();

  @override
  Future<ApiResponse<Place>> updatePlace({
    required String id,
    String? level,
    String? canonicalName,
    List<PlaceName>? names,
    String? parentId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ApiResponse<Map<String, dynamic>>> deletePlace(String id) async =>
      const ApiResponse.success({});
}

void main() {
  group('LocationSearchDialog Widget Tests', () {
    late FakeTestPlaceRepo repo;
    late PlaceService placeService;

    setUp(() {
      repo = FakeTestPlaceRepo();
      placeService = PlaceService(repository: repo);
    });

    Widget buildTestApp({Place? selectedPlace, void Function(Place)? onSelected}) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('hi')],
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () async {
                  final picked = await showDialog<Place>(
                    context: ctx,
                    builder: (_) => LocationSearchDialog(
                      placeService: placeService,
                      currentPlaceId: selectedPlace?.id,
                      currentPlaceName: selectedPlace?.canonicalName,
                    ),
                  );
                  if (picked != null) {
                    onSelected?.call(picked);
                  }
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('1. Empty query does NOT show full unnecessary location list, shows prompt', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Dialog is open as a modal dialog
      expect(find.byType(LocationSearchDialog), findsOneWidget);
      expect(find.text('Select Location'), findsOneWidget);

      // Prompt is visible
      expect(find.byKey(const Key('location_search_prompt')), findsOneWidget);
      expect(find.text('Type to search locations'), findsOneWidget);

      // No places list dumped on screen
      expect(find.text('Jaipur'), findsNothing);
      expect(find.text('Jodhpur'), findsNothing);
      expect(find.text('Mandore Village'), findsNothing);
      expect(find.text('Amer Town'), findsNothing);
    });

    testWidgets('2. Substring matching returns only relevant places and excludes non-matching', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Search for "Mandore"
      await tester.enterText(find.byKey(const Key('location_search_input')), 'Mandore');
      await tester.pumpAndSettle();

      // Mandore matches
      expect(find.text('Mandore Village'), findsOneWidget);

      // Unrelated places are strictly excluded
      expect(find.text('Jaipur'), findsNothing);
      expect(find.text('Jodhpur'), findsNothing);
      expect(find.text('Amer Town'), findsNothing);
    });

    testWidgets('3. Hindi localized name substring match works', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Search by Hindi localized name "जयपुर"
      await tester.enterText(find.byKey(const Key('location_search_input')), 'जयपुर');
      await tester.pumpAndSettle();

      expect(find.text('Jaipur'), findsOneWidget);
      expect(find.text('Jodhpur'), findsNothing);
    });

    testWidgets('4. Shows no-results empty state when query does not match', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('location_search_input')), 'NonExistentCity123');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('location_search_no_results')), findsOneWidget);
      expect(find.text('No locations found matching "NonExistentCity123"'), findsOneWidget);
    });

    testWidgets('5. Selecting a place closes dialog and returns chosen Place', (tester) async {
      Place? chosen;
      await tester.pumpWidget(buildTestApp(onSelected: (p) => chosen = p));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('location_search_input')), 'Jodhpur');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, 'Jodhpur'));
      await tester.pumpAndSettle();

      // Dialog is closed
      expect(find.byType(LocationSearchDialog), findsNothing);
      // Place is returned
      expect(chosen, isNotNull);
      expect(chosen!.canonicalName, equals('Jodhpur'));
      expect(chosen!.id, equals('place-jodhpur'));
    });

    testWidgets('6. Close button dismisses dialog without selection', (tester) async {
      Place? chosen;
      await tester.pumpWidget(buildTestApp(onSelected: (p) => chosen = p));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('location_search_dialog_close')));
      await tester.pumpAndSettle();

      expect(find.byType(LocationSearchDialog), findsNothing);
      expect(chosen, isNull);
    });

    testWidgets('7. Debounce coalesces rapid keystrokes into a single request for the final query', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(repo.getPlacesCallCount, 0);

      // Simulate typing 'n', 'na', 'nar', 'narw', 'narwa', 'narwan', 'narwana' rapidly (< 350ms per key)
      final keystrokes = ['n', 'na', 'nar', 'narw', 'narwa', 'narwan', 'narwana'];
      for (final text in keystrokes) {
        await tester.enterText(find.byKey(const Key('location_search_input')), text);
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Within debounce window: no network requests sent yet
      expect(repo.getPlacesCallCount, 0);

      // Advance clock past the 350ms debounce threshold
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Exactly 1 request dispatched with the final query 'narwana'
      expect(repo.getPlacesCallCount, 1);
      expect(repo.requestedSearches, ['narwana']);
    });

    testWidgets('8. Out-of-order response from earlier query cannot overwrite newer query results', (tester) async {
      final completerJaip = Completer<ApiResponse<List<Place>>>();

      repo.customGetPlacesHandler = ({level, parentId, search, page = 1, limit = 20}) {
        if (search == 'Jaip') {
          return completerJaip.future;
        }
        // For 'Mand', return immediately with Mandore Village
        return Future.value(
          const ApiResponse.success([
            Place(
              id: 'place-mandore',
              canonicalName: 'Mandore Village',
              level: 'VILLAGE',
              names: [PlaceName(language: 'en', name: 'Mandore Village')],
            ),
          ]),
        );
      };

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // User types 'Jaip'
      await tester.enterText(find.byKey(const Key('location_search_input')), 'Jaip');
      // Advance past debounce so 'Jaip' request starts and is held by completer
      await tester.pump(const Duration(milliseconds: 360));
      expect(repo.getPlacesCallCount, 1);
      expect(repo.requestedSearches, ['Jaip']);

      // While 'Jaip' is still in-flight, user changes search to 'Mand'
      await tester.enterText(find.byKey(const Key('location_search_input')), 'Mand');
      await tester.pump(const Duration(milliseconds: 360));
      await tester.pump();

      // 'Mand' completed immediately and is displayed
      expect(repo.getPlacesCallCount, 2);
      expect(find.text('Mandore Village'), findsOneWidget);

      // Now complete the stale 'Jaip' request
      completerJaip.complete(
        const ApiResponse.success([
          Place(
            id: 'place-jaipur',
            canonicalName: 'Jaipur',
            level: 'CITY_TOWN',
            names: [PlaceName(language: 'en', name: 'Jaipur')],
          ),
        ]),
      );

      await tester.pumpAndSettle();

      // Verified: stale response was discarded! 'Mandore Village' is still displayed, NOT 'Jaipur'
      expect(find.text('Mandore Village'), findsOneWidget);
      expect(find.text('Jaipur'), findsNothing);
    });

    testWidgets('9. Clearing query immediately cancels pending debounce timer without firing request', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Type some characters
      await tester.enterText(find.byKey(const Key('location_search_input')), 'Jodhpur');
      await tester.pump(const Duration(milliseconds: 100)); // before debounce fires

      // Clear search
      await tester.tap(find.byKey(const Key('location_search_clear')));
      await tester.pumpAndSettle();

      // Advance time well beyond debounce
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // No request was ever sent
      expect(repo.getPlacesCallCount, 0);
      expect(find.byKey(const Key('location_search_prompt')), findsOneWidget);
    });

    testWidgets('10. Displays error state on service failure and retry button triggers re-search', (tester) async {
      bool shouldFail = true;

      repo.customGetPlacesHandler = ({level, parentId, search, page = 1, limit = 20}) async {
        if (shouldFail) {
          return const ApiResponse.failure(NetworkFailure(message: 'Network error occurred'));
        }
        return const ApiResponse.success([
          Place(
            id: 'place-jaipur',
            canonicalName: 'Jaipur',
            level: 'CITY_TOWN',
            names: [PlaceName(language: 'en', name: 'Jaipur')],
          ),
        ]);
      };

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('location_search_input')), 'Jaipur');
      await tester.pumpAndSettle();

      // Error message is displayed
      expect(find.text('Network error occurred'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Fix condition and tap retry
      shouldFail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Result loaded successfully
      expect(find.widgetWithText(ListTile, 'Jaipur'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });
  });
}
