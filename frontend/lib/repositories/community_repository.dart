import '../core/network/api_client.dart';
import '../models/claim.dart';
import '../models/evidence.dart';
import '../models/place_progress.dart';

abstract class CommunityRepository {
  Future<ApiResponse<List<Evidence>>> getEvidenceForClaim(String claimId);

  Future<ApiResponse<Evidence>> submitEvidence({
    required String claimId,
    required String sourceType,
    required String title,
    required String description,
    String? url,
    String? documentRef,
    DateTime? dateOfEvidence,
    String languageOfEvidence = 'en',
  });

  Future<ApiResponse<Evidence>> reviewEvidence({
    required String evidenceId,
    required String decision,
    required String reviewNotes,
  });

  Future<ApiResponse<List<Claim>>> getClaimsForPlace({
    required String locationId,
    String? category,
    String? communityTopic,
    String? status,
    int page = 1,
    int limit = 20,
  });

  Future<ApiResponse<List<Claim>>> getRecentClaims({
    String? category,
    int limit = 20,
  });

  Future<ApiResponse<Claim>> createClaimDraft({
    required String locationId,
    required String title,
    required String body,
    required String category,
    required String language,
    String? communityTopic,
    String? sourceAttribution,
    String? timePeriod,
    bool consentObtained = false,
    String? consentDetails,
    String? userAgreementStatus,
  });

  Future<ApiResponse<Claim>> updateClaimDraft({
    required String claimId,
    String? title,
    String? body,
    String? language,
    String? communityTopic,
    String? sourceAttribution,
    String? timePeriod,
    bool? consentObtained,
    String? consentDetails,
    String? userAgreementStatus,
  });

  Future<ApiResponse<Map<String, dynamic>>> submitClaimForReview(String claimId);

  Future<ApiResponse<List<Claim>>> getMyDrafts(String userId);

  Future<ApiResponse<Claim>> getClaimDetail(String claimId);

  Future<ApiResponse<Map<String, dynamic>>> requestClaimCorrection({
    required String claimId,
    required String reason,
  });

  Future<ApiResponse<Map<String, dynamic>>> reviewClaim({
    required String claimId,
    required String decisionStatus,
    required String reason,
    String? reviewerNote,
  });

  Future<ApiResponse<List<PlaceAttribute>>> getPlaceAttributes({
    required String placeId,
    String? category,
  });

  Future<ApiResponse<PlaceAttribute>> addPlaceAttribute({
    required String placeId,
    required String category,
    required String key,
    required String value,
    required String sourceDescription,
    String? reportedPeriod,
    String? uncertainty,
  });

  Future<ApiResponse<PlaceProgress>> getPlaceProgress(String placeId);

  Future<ApiResponse<List<Claim>>> getReviewQueue({int page = 1, int limit = 20});

  Future<ApiResponse<Map<String, dynamic>>> submitHistoryFeedback({
    required String claimId,
    String? previouslyKnown,
    String? agreement,
    String? comment,
    String? knowsAuthor,
  });
}

class CommunityRepositoryImpl implements CommunityRepository {
  final ApiClient _client;

  CommunityRepositoryImpl({required ApiClient client}) : _client = client;

  @override
  Future<ApiResponse<List<Claim>>> getReviewQueue({int page = 1, int limit = 20}) async {
    final response = await _client.get('/claims/review-queue?page=$page&limit=$limit');
    if (response.isSuccess && response.data != null) {
      final list = (response.data!['data'] as List<dynamic>?) ?? [];
      final claims = list.map((item) => Claim.fromJson(item as Map<String, dynamic>)).toList();
      return ApiResponse.success(claims);
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<List<Claim>>> getClaimsForPlace({
    required String locationId,
    String? category,
    String? communityTopic,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String>['locationId=$locationId', 'page=$page', 'limit=$limit'];
    if (category != null && category.isNotEmpty) queryParams.add('category=$category');
    if (communityTopic != null && communityTopic.isNotEmpty) queryParams.add('communityTopic=$communityTopic');
    if (status != null && status.isNotEmpty) queryParams.add('status=$status');

    final response = await _client.get('/claims?${queryParams.join('&')}');
    if (response.isSuccess && response.data != null) {
      final list = (response.data!['data'] as List<dynamic>?) ?? [];
      final claims = list.map((item) => Claim.fromJson(item as Map<String, dynamic>)).toList();
      return ApiResponse.success(claims);
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<List<Claim>>> getRecentClaims({
    String? category,
    int limit = 20,
  }) async {
    final queryParams = <String>['page=1', 'limit=$limit'];
    if (category != null && category.isNotEmpty) queryParams.add('category=$category');

    final response = await _client.get('/claims?${queryParams.join('&')}');
    if (response.isSuccess && response.data != null) {
      final list = (response.data!['data'] as List<dynamic>?) ?? [];
      final claims = list.map((item) => Claim.fromJson(item as Map<String, dynamic>)).toList();
      return ApiResponse.success(claims);
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<Claim>> createClaimDraft({
    required String locationId,
    required String title,
    required String body,
    required String category,
    required String language,
    String? communityTopic,
    String? sourceAttribution,
    String? timePeriod,
    bool consentObtained = false,
    String? consentDetails,
    String? userAgreementStatus,
  }) async {
    final payload = {
      'locationId': locationId,
      'title': {'original': title.trim(), 'language': language},
      'body': {'original': body.trim(), 'language': language},
      'category': category,
      if (communityTopic != null) 'communityTopic': communityTopic,
      if (sourceAttribution != null) 'sourceAttribution': sourceAttribution,
      if (timePeriod != null) 'timePeriod': timePeriod,
      'consentObtained': consentObtained,
      if (consentDetails != null) 'consentDetails': consentDetails,
      if (userAgreementStatus != null) 'userAgreementStatus': userAgreementStatus,
    };

    final response = await _client.post('/claims', payload);
    if (response.isSuccess && response.data != null) {
      final raw = response.data!['data'] is Map<String, dynamic>
          ? response.data!['data'] as Map<String, dynamic>
          : response.data!;
      return ApiResponse.success(Claim.fromJson(raw));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<Claim>> updateClaimDraft({
    required String claimId,
    String? title,
    String? body,
    String? language,
    String? communityTopic,
    String? sourceAttribution,
    String? timePeriod,
    bool? consentObtained,
    String? consentDetails,
    String? userAgreementStatus,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null && language != null) {
      payload['title'] = {'original': title.trim(), 'language': language};
    }
    if (body != null && language != null) {
      payload['body'] = {'original': body.trim(), 'language': language};
    }
    if (communityTopic != null) payload['communityTopic'] = communityTopic;
    if (sourceAttribution != null) payload['sourceAttribution'] = sourceAttribution;
    if (timePeriod != null) payload['timePeriod'] = timePeriod;
    if (consentObtained != null) payload['consentObtained'] = consentObtained;
    if (consentDetails != null) payload['consentDetails'] = consentDetails;
    if (userAgreementStatus != null) payload['userAgreementStatus'] = userAgreementStatus;

    final response = await _client.patch('/claims/$claimId', payload);
    if (response.isSuccess && response.data != null) {
      final raw = response.data!['data'] is Map<String, dynamic>
          ? response.data!['data'] as Map<String, dynamic>
          : response.data!;
      return ApiResponse.success(Claim.fromJson(raw));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> submitClaimForReview(String claimId) async {
    return await _client.patch('/claims/$claimId/submit');
  }

  @override
  Future<ApiResponse<List<Claim>>> getMyDrafts(String userId) async {
    final response = await _client.get('/claims?status=draft&submittedBy=$userId');
    if (response.isSuccess && response.data != null) {
      final list = (response.data!['data'] as List<dynamic>?) ?? [];
      final claims = list.map((item) => Claim.fromJson(item as Map<String, dynamic>)).toList();
      return ApiResponse.success(claims);
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<Claim>> getClaimDetail(String claimId) async {
    final response = await _client.get('/claims/$claimId');
    if (response.isSuccess && response.data != null) {
      final raw = response.data!['data'] is Map<String, dynamic>
          ? response.data!['data'] as Map<String, dynamic>
          : response.data!;
      return ApiResponse.success(Claim.fromJson(raw));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> requestClaimCorrection({
    required String claimId,
    required String reason,
  }) async {
    final payload = {
      'reason': reason.trim(),
    };
    return await _client.post('/claims/$claimId/correction', payload);
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> reviewClaim({
    required String claimId,
    required String decisionStatus,
    required String reason,
    String? reviewerNote,
  }) async {
    final payload = {
      'decisionStatus': decisionStatus,
      'reason': reason.trim(),
      if (reviewerNote != null && reviewerNote.isNotEmpty)
        'reviewerNote': reviewerNote.trim(),
    };
    return await _client.post('/claims/$claimId/review', payload);
  }

  @override
  Future<ApiResponse<List<PlaceAttribute>>> getPlaceAttributes({
    required String placeId,
    String? category,
  }) async {
    final q = category != null ? '?category=$category' : '';
    final response = await _client.get('/places/$placeId/attributes$q');
    if (response.isSuccess && response.data != null) {
      final list = (response.data!['data'] as List<dynamic>?) ?? [];
      final attrs = list.map((i) => PlaceAttribute.fromJson(i as Map<String, dynamic>)).toList();
      return ApiResponse.success(attrs);
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<PlaceAttribute>> addPlaceAttribute({
    required String placeId,
    required String category,
    required String key,
    required String value,
    required String sourceDescription,
    String? reportedPeriod,
    String? uncertainty,
  }) async {
    final payload = {
      'category': category,
      'key': key.trim(),
      'value': value.trim(),
      'sourceDescription': sourceDescription.trim(),
      if (reportedPeriod != null) 'reportedPeriod': reportedPeriod.trim(),
      if (uncertainty != null) 'uncertainty': uncertainty.trim(),
    };
    final response = await _client.post('/places/$placeId/attributes', payload);
    if (response.isSuccess && response.data != null) {
      final raw = response.data!['data'] as Map<String, dynamic>;
      return ApiResponse.success(PlaceAttribute.fromJson(raw));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<PlaceProgress>> getPlaceProgress(String placeId) async {
    final response = await _client.get('/places/$placeId/progress');
    if (response.isSuccess && response.data != null) {
      final raw = response.data!['data'] as Map<String, dynamic>;
      return ApiResponse.success(PlaceProgress.fromJson(raw));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<List<Evidence>>> getEvidenceForClaim(String claimId) async {
    final response = await _client.get('/evidence/claim/$claimId');
    if (response.isSuccess && response.data != null) {
      final list = (response.data!['data'] as List<dynamic>?) ?? [];
      final evidenceList = list
          .map((item) => Evidence.fromJson(item as Map<String, dynamic>))
          .toList();
      return ApiResponse.success(evidenceList);
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<Evidence>> submitEvidence({
    required String claimId,
    required String sourceType,
    required String title,
    required String description,
    String? url,
    String? documentRef,
    DateTime? dateOfEvidence,
    String languageOfEvidence = 'en',
  }) async {
    final payload = {
      'claimId': claimId,
      'sourceType': sourceType,
      'title': title.trim(),
      'description': description.trim(),
      if (url != null && url.isNotEmpty) 'url': url.trim(),
      if (documentRef != null && documentRef.isNotEmpty) 'documentRef': documentRef.trim(),
      if (dateOfEvidence != null) 'dateOfEvidence': dateOfEvidence.toIso8601String(),
      'languageOfEvidence': languageOfEvidence,
    };
    final response = await _client.post('/evidence', payload);
    if (response.isSuccess && response.data != null) {
      final raw = response.data!['data'] is Map<String, dynamic>
          ? response.data!['data'] as Map<String, dynamic>
          : response.data!;
      return ApiResponse.success(Evidence.fromJson(raw));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<Evidence>> reviewEvidence({
    required String evidenceId,
    required String decision,
    required String reviewNotes,
  }) async {
    final payload = {
      'decision': decision,
      'reviewNotes': reviewNotes.trim(),
    };
    final response = await _client.patch('/evidence/$evidenceId/review', payload);
    if (response.isSuccess && response.data != null) {
      final raw = response.data!['data'] is Map<String, dynamic>
          ? response.data!['data'] as Map<String, dynamic>
          : response.data!;
      return ApiResponse.success(Evidence.fromJson(raw));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> submitHistoryFeedback({
    required String claimId,
    String? previouslyKnown,
    String? agreement,
    String? comment,
    String? knowsAuthor,
  }) async {
    final payload = <String, dynamic>{};
    if (previouslyKnown != null) payload['previouslyKnown'] = previouslyKnown;
    if (agreement != null) payload['agreement'] = agreement;
    if (comment != null) payload['comment'] = comment;
    if (knowsAuthor != null) payload['knowsAuthor'] = knowsAuthor;

    final response = await _client.post('/claims/$claimId/feedback', payload);
    if (response.isSuccess && response.data != null) {
      final raw = response.data!['data'] is Map<String, dynamic>
          ? response.data!['data'] as Map<String, dynamic>
          : response.data!;
      return ApiResponse.success(raw);
    }
    return ApiResponse.failure(response.failure);
  }
}

