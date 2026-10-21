import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/place.dart';
import 'package:my_root/repositories/place_repository.dart';
import 'package:my_root/services/place_service.dart';
import 'package:my_root/ui/widgets/location_search_dialog.dart';

class FakeTestPlaceRepo implements PlaceRepository {
  @override
  final ApiClient client = ApiClient();

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
  });
}
