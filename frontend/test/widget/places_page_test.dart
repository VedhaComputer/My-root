import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_root/core/error/failures.dart';
import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/claim.dart';
import 'package:my_root/models/place.dart';
import 'package:my_root/repositories/community_repository.dart';
import 'package:my_root/repositories/place_repository.dart';
import 'package:my_root/services/community_service.dart';
import 'package:my_root/services/place_service.dart';
import 'package:my_root/ui/card/place_card.dart';
import 'package:my_root/ui/pages/places/place_detail_page.dart';
import 'package:my_root/ui/pages/places/places_page.dart';

class FakePlaceRepository implements PlaceRepository {
  bool shouldSucceed = true;
  @override
  final ApiClient client = ApiClient();
  List<Place> fakePlaces = [
    const Place(
      id: 'c-1',
      level: 'COUNTRY',
      canonicalName: 'India',
      names: [PlaceName(language: 'en', name: 'India'), PlaceName(language: 'hi', name: 'भारत')],
      parentId: null,
      parentPath: [],
    ),
    const Place(
      id: 's-1',
      level: 'STATE',
      canonicalName: 'Rajasthan',
      names: [PlaceName(language: 'en', name: 'Rajasthan'), PlaceName(language: 'hi', name: 'राजस्थान')],
      parentId: 'c-1',
      parentPath: [
        PlacePathItem(id: 'c-1', level: 'COUNTRY', canonicalName: 'India'),
      ],
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
    if (!shouldSucceed) {
      return const ApiResponse.failure(ServerFailure(message: 'Database query failed'));
    }
    var result = fakePlaces;
    if (level != null && level.isNotEmpty) {
      result = result.where((p) => p.level == level).toList();
    }
    return ApiResponse.success(result);
  }

  @override
  Future<ApiResponse<Place>> getPlaceById(String id) async {
    if (!shouldSucceed) {
      return const ApiResponse.failure(NotFoundFailure(message: 'Place not found'));
    }
    final place = fakePlaces.firstWhere(
      (p) => p.id == id,
      orElse: () => fakePlaces.first,
    );
    return ApiResponse.success(place);
  }

  @override
  Future<ApiResponse<List<Place>>> getChildren(String parentId) async {
    final children = fakePlaces.where((p) => p.parentId == parentId).toList();
    return ApiResponse.success(children);
  }

  @override
  Future<ApiResponse<Place>> createPlace({
    required String level,
    required String canonicalName,
    required List<PlaceName> names,
    String? parentId,
  }) async {
    final newPlace = Place(
      id: 'new-1',
      level: level,
      canonicalName: canonicalName,
      names: names,
      parentId: parentId,
    );
    fakePlaces.add(newPlace);
    return ApiResponse.success(newPlace);
  }

  @override
  Future<ApiResponse<Place>> updatePlace({
    required String id,
    String? level,
    String? canonicalName,
    List<PlaceName>? names,
    String? parentId,
  }) async {
    final place = fakePlaces.first;
    return ApiResponse.success(place);
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> deletePlace(String id) async {
    fakePlaces.removeWhere((p) => p.id == id);
    return const ApiResponse.success({'message': 'Deleted'});
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
  group('PlacesPage Widget Tests', () {
    late FakePlaceRepository fakeRepo;
    late PlaceService placeService;

    setUp(() {
      fakeRepo = FakePlaceRepository();
      placeService = PlaceService(repository: fakeRepo);
    });

    testWidgets('renders search field, filter chips, and PlaceCards', (tester) async {
      await tester.pumpWidget(
        createTestApp(PlacesPage(placeService: placeService)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Places'), findsOneWidget);
      expect(find.byType(FilterChip), findsWidgets);
      expect(find.byType(PlaceCard), findsNWidgets(2));
      expect(find.text('India'), findsWidgets);
      expect(find.text('Rajasthan'), findsOneWidget);
    });

    testWidgets('shows empty state when no places match', (tester) async {
      fakeRepo.fakePlaces = [];

      await tester.pumpWidget(
        createTestApp(PlacesPage(placeService: placeService)),
      );
      await tester.pumpAndSettle();

      expect(find.text('No places found'), findsOneWidget);
      expect(find.byType(PlaceCard), findsNothing);
    });

    testWidgets('shows error state with retry button on failure', (tester) async {
      fakeRepo.shouldSucceed = false;

      await tester.pumpWidget(
        createTestApp(PlacesPage(placeService: placeService)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Database query failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('PlaceDetailPage Widget Tests', () {
    late FakePlaceRepository fakeRepo;
    late PlaceService placeService;

    setUp(() {
      fakeRepo = FakePlaceRepository();
      placeService = PlaceService(repository: fakeRepo);
    });

    testWidgets('renders place overview, hierarchy breadcrumbs, and localized names',
        (tester) async {
      final samplePlace = fakeRepo.fakePlaces[1]; // Rajasthan

      await tester.pumpWidget(
        createTestApp(
          PlaceDetailPage(
            placeId: samplePlace.id,
            initialPlace: samplePlace,
            placeService: placeService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rajasthan'), findsWidgets);
      expect(find.text('Hierarchy'), findsOneWidget);
      expect(find.text('India (COUNTRY)'), findsOneWidget);
      expect(find.text('Localized Names'), findsOneWidget);
    });

    testWidgets('renders empty hierarchy message for top-level Country',
        (tester) async {
      final countryPlace = fakeRepo.fakePlaces[0]; // India

      await tester.pumpWidget(
        createTestApp(
          PlaceDetailPage(
            placeId: countryPlace.id,
            initialPlace: countryPlace,
            placeService: placeService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Top-level Country node'),
        findsOneWidget,
      );
    });

    testWidgets('renders empty sub-places message when no child places exist',
        (tester) async {
      final samplePlace = fakeRepo.fakePlaces[1]; // Rajasthan

      await tester.pumpWidget(
        createTestApp(
          PlaceDetailPage(
            placeId: samplePlace.id,
            initialPlace: samplePlace,
            placeService: placeService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No sub-places found under this location'),
        findsOneWidget,
      );
    });

    testWidgets(
        'semantically separates verified facts, folklore with notice, and opinions with notice',
        (tester) async {
      final samplePlace = fakeRepo.fakePlaces[1];

      final fakeCommunity = FakeTestCommunityService(
        initialClaims: [
          Claim(
            id: 'c-fact',
            title: const LocalizedContent(original: 'Thar Desert Formation', language: 'en'),
            body: const LocalizedContent(original: 'Geological history of Thar.', language: 'en'),
            category: 'HISTORICAL_RECORD',
            status: 'verified',
            locationId: samplePlace.id,
            submittedAt: DateTime.now(),
            evidenceCount: 3,
            isPublic: true,
            tags: [],
          ),
          Claim(
            id: 'c-folk',
            title: const LocalizedContent(original: 'Legend of the Desert Spirit', language: 'en'),
            body: const LocalizedContent(original: 'Oral folklore passed down for generations.', language: 'en'),
            category: 'FOLKLORE',
            status: 'verified',
            locationId: samplePlace.id,
            submittedAt: DateTime.now(),
            evidenceCount: 1,
            isPublic: true,
            tags: [],
          ),
          Claim(
            id: 'c-opinion',
            title: const LocalizedContent(original: 'Best Season to Visit Jodhpur', language: 'en'),
            body: const LocalizedContent(original: 'In my view, November is the best time.', language: 'en'),
            category: 'PUBLIC_OPINION',
            status: 'unverified',
            locationId: samplePlace.id,
            submittedAt: DateTime.now(),
            evidenceCount: 0,
            isPublic: true,
            tags: [],
          ),
        ],
      );

      await tester.pumpWidget(
        createTestApp(
          PlaceDetailPage(
            placeId: samplePlace.id,
            initialPlace: samplePlace,
            placeService: placeService,
            communityService: fakeCommunity,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verified History & Facts
      expect(find.text('Verified History & Facts'), findsOneWidget);
      expect(find.text('Thar Desert Formation'), findsOneWidget);

      // 2. Folklore & Oral Traditions with prominent disclaimer
      expect(find.text('Folklore & Oral Traditions'), findsOneWidget);
      expect(find.text('Legend of the Desert Spirit'), findsOneWidget);
      expect(
        find.textContaining('Folklore & Oral Tradition: Community-shared folklore is not independently verified'),
        findsOneWidget,
      );

      // 3. Public & Community Opinions with opinion disclaimer
      expect(find.text('Public & Community Opinions'), findsOneWidget);
      expect(find.text('Best Season to Visit Jodhpur'), findsOneWidget);
      expect(
        find.textContaining('Community Opinions: Subjective viewpoints submitted by local contributors'),
        findsOneWidget,
      );
    });

    testWidgets(
        'verified personal experience claim is placed under opinions and never presented as verified history',
        (tester) async {
      final samplePlace = fakeRepo.fakePlaces[1];

      final fakeCommunity = FakeTestCommunityService(
        initialClaims: [
          Claim(
            id: 'c-exp',
            title: const LocalizedContent(original: 'My Childhood Near Mandore Fort', language: 'en'),
            body: const LocalizedContent(original: 'Personal memories of growing up here.', language: 'en'),
            category: 'PERSONAL_EXPERIENCE',
            status: 'verified', // Marked verified, but category is personal experience
            locationId: samplePlace.id,
            submittedAt: DateTime.now(),
            evidenceCount: 1,
            isPublic: true,
            tags: [],
          ),
        ],
      );

      await tester.pumpWidget(
        createTestApp(
          PlaceDetailPage(
            placeId: samplePlace.id,
            initialPlace: samplePlace,
            placeService: placeService,
            communityService: fakeCommunity,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must NOT be in Verified History & Facts
      expect(find.text('No verified historical records or facts for this location yet.'), findsOneWidget);

      // Must be categorized under Public & Community Opinions with opinion disclaimer
      expect(find.text('Public & Community Opinions'), findsOneWidget);
      expect(find.text('My Childhood Near Mandore Fort'), findsOneWidget);
      expect(
        find.textContaining('Community Opinions: Subjective viewpoints submitted by local contributors'),
        findsOneWidget,
      );
    });
  });
}

class FakeTestCommunityService extends CommunityService {
  final List<Claim> initialClaims;

  FakeTestCommunityService({required this.initialClaims})
      : super(repository: CommunityRepositoryImpl(client: ApiClient()));

  @override
  List<Claim> get claims => initialClaims;

  @override
  Future<void> fetchCommunityData(String placeId) async {
    // Keep initialized claims
    notifyListeners();
  }
}
