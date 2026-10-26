import '../core/network/api_client.dart';
import '../models/poll.dart';

abstract class PollRepository {
  Future<ApiResponse<List<Poll>>> getPolls({
    String? personName,
    String? placeId,
    String? targetEntityId,
    String? status,
    String? search,
    int page = 1,
    int limit = 20,
  });

  Future<ApiResponse<Poll>> getPollById(String id);

  Future<ApiResponse<Poll>> createPoll({
    required String personName,
    String? personRole,
    String? placeId,
    String? placeName,
    String? targetEntityId,
    required String question,
    String? description,
    String? photoUrl,
    int? durationDays,
  });

  Future<ApiResponse<Poll>> vote({
    required String pollId,
    required String choice,
    required String reasonKey,
    String? explanation,
  });

  Future<ApiResponse<Poll>> closePoll(String pollId);

  Future<ApiResponse<Map<String, dynamic>>> reportPoll({
    required String pollId,
    required String reason,
    String? details,
  });

  ApiClient get client;
}

class PollRepositoryImpl implements PollRepository {
  final ApiClient _client;

  PollRepositoryImpl({required ApiClient client}) : _client = client;

  @override
  ApiClient get client => _client;

  @override
  Future<ApiResponse<List<Poll>>> getPolls({
    String? personName,
    String? placeId,
    String? targetEntityId,
    String? status,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String>[];
    if (personName != null && personName.isNotEmpty) {
      queryParams.add('personName=${Uri.encodeComponent(personName)}');
    }
    if (placeId != null && placeId.isNotEmpty) {
      queryParams.add('placeId=${Uri.encodeComponent(placeId)}');
    }
    if (targetEntityId != null && targetEntityId.isNotEmpty) {
      queryParams.add('targetEntityId=${Uri.encodeComponent(targetEntityId)}');
    }
    if (status != null && status.isNotEmpty) {
      queryParams.add('status=${Uri.encodeComponent(status)}');
    }
    if (search != null && search.isNotEmpty) {
      queryParams.add('search=${Uri.encodeComponent(search)}');
    }
    queryParams.add('page=$page');
    queryParams.add('limit=$limit');

    final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    final response = await _client.get('/polls$queryString');

    if (response.isSuccess && response.data != null) {
      final list = (response.data!['data'] as List<dynamic>?) ?? [];
      final polls = list
          .map((item) => Poll.fromJson(item as Map<String, dynamic>))
          .toList();
      return ApiResponse.success(polls);
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<Poll>> getPollById(String id) async {
    final response = await _client.get('/polls/$id');
    if (response.isSuccess && response.data != null) {
      final rawData = response.data!['data'] is Map<String, dynamic>
          ? response.data!['data'] as Map<String, dynamic>
          : response.data!;
      return ApiResponse.success(Poll.fromJson(rawData));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<Poll>> createPoll({
    required String personName,
    String? personRole,
    String? placeId,
    String? placeName,
    String? targetEntityId,
    required String question,
    String? description,
    String? photoUrl,
    int? durationDays,
  }) async {
    final body = <String, dynamic>{
      'personName': personName,
      if (personRole != null) 'personRole': personRole,
      if (placeId != null) 'placeId': placeId,
      if (placeName != null) 'placeName': placeName,
      if (targetEntityId != null) 'targetEntityId': targetEntityId,
      'question': question,
      if (description != null) 'description': description,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (durationDays != null) 'durationDays': durationDays,
    };

    final response = await _client.post('/polls', body);
    if (response.isSuccess && response.data != null) {
      final rawData = response.data!['data'] is Map<String, dynamic>
          ? response.data!['data'] as Map<String, dynamic>
          : response.data!;
      return ApiResponse.success(Poll.fromJson(rawData));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<Poll>> vote({
    required String pollId,
    required String choice,
    required String reasonKey,
    String? explanation,
  }) async {
    final body = <String, dynamic>{
      'choice': choice,
      'reasonKey': reasonKey,
      if (explanation != null) 'explanation': explanation,
    };

    final response = await _client.post('/polls/$pollId/vote', body);
    if (response.isSuccess && response.data != null) {
      final rawData = response.data!['data'] is Map<String, dynamic>
          ? response.data!['data'] as Map<String, dynamic>
          : response.data!;
      return ApiResponse.success(Poll.fromJson(rawData));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<Poll>> closePoll(String pollId) async {
    final response = await _client.post('/polls/$pollId/close', {});
    if (response.isSuccess && response.data != null) {
      final rawData = response.data!['data'] is Map<String, dynamic>
          ? response.data!['data'] as Map<String, dynamic>
          : response.data!;
      return ApiResponse.success(Poll.fromJson(rawData));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> reportPoll({
    required String pollId,
    required String reason,
    String? details,
  }) async {
    final body = <String, dynamic>{
      'reason': reason,
      if (details != null) 'details': details,
    };

    final response = await _client.post('/polls/$pollId/report', body);
    if (response.isSuccess && response.data != null) {
      final rawData = response.data!['data'] is Map<String, dynamic>
          ? response.data!['data'] as Map<String, dynamic>
          : response.data!;
      return ApiResponse.success(rawData);
    }
    return ApiResponse.failure(response.failure);
  }
}
