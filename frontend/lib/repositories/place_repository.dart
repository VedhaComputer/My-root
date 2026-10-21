import '../core/network/api_client.dart';
import '../models/place.dart';

abstract class PlaceRepository {
  Future<ApiResponse<List<Place>>> getPlaces({
    String? level,
    String? parentId,
    String? search,
    int page = 1,
    int limit = 20,
  });

  Future<ApiResponse<Place>> getPlaceById(String id);

  Future<ApiResponse<List<Place>>> getChildren(String parentId);

  Future<ApiResponse<Place>> createPlace({
    required String level,
    required String canonicalName,
    required List<PlaceName> names,
    String? parentId,
  });

  Future<ApiResponse<Place>> updatePlace({
    required String id,
    String? level,
    String? canonicalName,
    List<PlaceName>? names,
    String? parentId,
  });

  ApiClient get client;

  Future<ApiResponse<Map<String, dynamic>>> deletePlace(String id);
}

class PlaceRepositoryImpl implements PlaceRepository {
  final ApiClient _client;

  PlaceRepositoryImpl({required ApiClient client}) : _client = client;

  @override
  ApiClient get client => _client;

  @override
  Future<ApiResponse<List<Place>>> getPlaces({
    String? level,
    String? parentId,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String>[];
    if (level != null && level.isNotEmpty) queryParams.add('level=$level');
    if (parentId != null && parentId.isNotEmpty) queryParams.add('parentId=$parentId');
    if (search != null && search.isNotEmpty) queryParams.add('search=${Uri.encodeComponent(search)}');
    queryParams.add('page=$page');
    queryParams.add('limit=$limit');

    final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    final response = await _client.get('/places$queryString');

    if (response.isSuccess && response.data != null) {
      final list = (response.data!['data'] as List<dynamic>?) ?? [];
      final places = list
          .map((item) => Place.fromJson(item as Map<String, dynamic>))
          .toList();
      return ApiResponse.success(places);
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<Place>> getPlaceById(String id) async {
    final response = await _client.get('/places/$id');
    if (response.isSuccess && response.data != null) {
      final rawData = response.data!['data'] is Map<String, dynamic>
          ? response.data!['data'] as Map<String, dynamic>
          : response.data!;
      return ApiResponse.success(Place.fromJson(rawData));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<List<Place>>> getChildren(String parentId) async {
    final response = await _client.get('/places/$parentId/children');
    if (response.isSuccess && response.data != null) {
      final list = (response.data!['data'] as List<dynamic>?) ?? [];
      final places = list
          .map((item) => Place.fromJson(item as Map<String, dynamic>))
          .toList();
      return ApiResponse.success(places);
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<Place>> createPlace({
    required String level,
    required String canonicalName,
    required List<PlaceName> names,
    String? parentId,
  }) async {
    final body = {
      'level': level,
      'canonicalName': canonicalName.trim(),
      'names': names.map((n) => n.toJson()).toList(),
      if (parentId != null && parentId.isNotEmpty) 'parentId': parentId,
    };

    final response = await _client.post('/places', body);
    if (response.isSuccess && response.data != null) {
      final rawData = response.data!['data'] is Map<String, dynamic>
          ? response.data!['data'] as Map<String, dynamic>
          : response.data!;
      return ApiResponse.success(Place.fromJson(rawData));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<Place>> updatePlace({
    required String id,
    String? level,
    String? canonicalName,
    List<PlaceName>? names,
    String? parentId,
  }) async {
    final body = <String, dynamic>{};
    if (level != null) body['level'] = level;
    if (canonicalName != null) body['canonicalName'] = canonicalName.trim();
    if (names != null) body['names'] = names.map((n) => n.toJson()).toList();
    if (parentId != null) body['parentId'] = parentId;

    final response = await _client.put('/places/$id', body);
    if (response.isSuccess && response.data != null) {
      final rawData = response.data!['data'] is Map<String, dynamic>
          ? response.data!['data'] as Map<String, dynamic>
          : response.data!;
      return ApiResponse.success(Place.fromJson(rawData));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> deletePlace(String id) async {
    final response = await _client.delete('/places/$id');
    if (response.isSuccess) {
      return ApiResponse.success(response.data);
    }
    return ApiResponse.failure(response.failure);
  }
}
