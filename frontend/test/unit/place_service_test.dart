import 'package:flutter_test/flutter_test.dart';
import 'package:my_root/core/error/failures.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/place.dart';
import 'package:my_root/repositories/place_repository.dart';
import 'package:my_root/services/place_service.dart';

class MockTestPlaceRepository implements PlaceRepository {
  int getPlaceByIdCallCount = 0;
  bool shouldSucceed = true;

  @override
  ApiClient get client => ApiClient();

  final testPlace = const Place(
    id: 'PL_VIL_06_077_00382_060008',
    canonicalName: 'Mandore Village',
    level: 'VILLAGE',
    names: [PlaceName(name: 'Mandore Village', language: 'en')],
  );

  @override
  Future<ApiResponse<Place>> getPlaceById(String id) async {
    getPlaceByIdCallCount++;
    // Simulate slight asynchronous delay
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldSucceed) {
      return ApiResponse.success(testPlace);
    }
    return const ApiResponse.failure(ServerFailure(message: 'Place not found'));
  }

  @override
  Future<ApiResponse<List<Place>>> getPlaces({
    String? level,
    String? parentId,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    return ApiResponse.success([testPlace]);
  }

  @override
  Future<ApiResponse<List<Place>>> getChildren(String id) async {
    return const ApiResponse.success([]);
  }

  @override
  Future<ApiResponse<Place>> createPlace({
    required String level,
    required String canonicalName,
    required List<PlaceName> names,
    String? parentId,
  }) async {
    return ApiResponse.success(testPlace);
  }

  @override
  Future<ApiResponse<Place>> updatePlace({
    required String id,
    String? level,
    String? canonicalName,
    List<PlaceName>? names,
    String? parentId,
  }) async {
    return ApiResponse.success(testPlace);
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> deletePlace(String id) async {
    return const ApiResponse.success({'message': 'deleted'});
  }
}

void main() {
  group('PlaceService (Unit Tests)', () {
    late MockTestPlaceRepository mockRepo;
    late PlaceService placeService;

    setUp(() {
      mockRepo = MockTestPlaceRepository();
      placeService = PlaceService(repository: mockRepo);
    });

    test('resolveSelectedPlace fetches and populates selectedPlace', () async {
      expect(placeService.selectedPlace, isNull);

      final result = await placeService.resolveSelectedPlace('PL_VIL_06_077_00382_060008');

      expect(result, isNotNull);
      expect(result?.id, 'PL_VIL_06_077_00382_060008');
      expect(placeService.selectedPlace?.canonicalName, 'Mandore Village');
      expect(mockRepo.getPlaceByIdCallCount, 1);
    });

    test('resolveSelectedPlace deduplicates concurrent in-flight requests into a single network call', () async {
      mockRepo.getPlaceByIdCallCount = 0;

      // Simulate simultaneous calls from HomePage and AppHeader on mount
      final future1 = placeService.resolveSelectedPlace('PL_VIL_06_077_00382_060008');
      final future2 = placeService.resolveSelectedPlace('PL_VIL_06_077_00382_060008');

      final results = await Future.wait([future1, future2]);

      expect(results[0]?.id, 'PL_VIL_06_077_00382_060008');
      expect(results[1]?.id, 'PL_VIL_06_077_00382_060008');
      expect(identical(results[0], results[1]), isTrue);
      // Exactly ONE getPlaceById call issued to repository
      expect(mockRepo.getPlaceByIdCallCount, 1);
    });

    test('resolveSelectedPlace immediately returns cached place in memory when ID already matches', () async {
      // First resolution
      await placeService.resolveSelectedPlace('PL_VIL_06_077_00382_060008');
      expect(mockRepo.getPlaceByIdCallCount, 1);

      // Subsequent resolution for the same placeId
      final cached = await placeService.resolveSelectedPlace('PL_VIL_06_077_00382_060008');
      expect(cached?.id, 'PL_VIL_06_077_00382_060008');
      // No extra network calls
      expect(mockRepo.getPlaceByIdCallCount, 1);
    });

    test('resolveSelectedPlace safely resets in-flight state on network failure allowing retry', () async {
      mockRepo.shouldSucceed = false;

      final failedResult = await placeService.resolveSelectedPlace('PL_VIL_06_077_00382_060008');
      expect(failedResult, isNull);
      expect(placeService.selectedPlace, isNull);
      expect(mockRepo.getPlaceByIdCallCount, 1);

      // Now server recovers
      mockRepo.shouldSucceed = true;
      final retryResult = await placeService.resolveSelectedPlace('PL_VIL_06_077_00382_060008');
      expect(retryResult?.id, 'PL_VIL_06_077_00382_060008');
      expect(mockRepo.getPlaceByIdCallCount, 2);
    });

    test('setSelectedPlace resets in-flight state and updates selectedPlace', () {
      placeService.setSelectedPlace(mockRepo.testPlace);
      expect(placeService.selectedPlace?.id, 'PL_VIL_06_077_00382_060008');

      placeService.setSelectedPlace(null);
      expect(placeService.selectedPlace, isNull);
    });
  });
}
