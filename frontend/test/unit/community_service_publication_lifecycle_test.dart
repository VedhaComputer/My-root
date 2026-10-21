import 'package:flutter_test/flutter_test.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/claim.dart';
import 'package:my_root/models/evidence.dart';
import 'package:my_root/models/place_progress.dart';
import 'package:my_root/repositories/community_repository.dart';
import 'package:my_root/services/community_service.dart';

class MockCommunityRepository implements CommunityRepository {
  bool submitSucceeds = true;
  List<Claim> draftsToReturn = [];
  Map<String, Claim> claimDetailsToReturn = {};

  @override
  Future<ApiResponse<Map<String, dynamic>>> submitClaimForReview(String claimId) async {
    if (submitSucceeds) {
      return const ApiResponse.success({'status': 'submitted'});
    }
    return const ApiResponse.failure(null);
  }

  @override
  Future<ApiResponse<Claim>> getClaimDetail(String claimId) async {
    final claim = claimDetailsToReturn[claimId];
    if (claim != null) {
      return ApiResponse.success(claim);
    }
    return const ApiResponse.failure(null);
  }

  @override
  Future<ApiResponse<List<Claim>>> getRecentClaims({String? category, int limit = 20}) async {
    return const ApiResponse.success([]);
  }

  @override
  Future<ApiResponse<List<Claim>>> getClaimsForPlace({
    required String locationId,
    String? category,
    String? communityTopic,
    String? status,
    int page = 1,
    int limit = 20,
  }) async => const ApiResponse.success([]);

  @override
  Future<ApiResponse<List<Evidence>>> getEvidenceForClaim(String claimId) async =>
      const ApiResponse.success([]);

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
  }) async => throw UnimplementedError();

  @override
  Future<ApiResponse<Evidence>> reviewEvidence({
    required String evidenceId,
    required String decision,
    required String reviewNotes,
  }) async => throw UnimplementedError();

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
  }) async => throw UnimplementedError();

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
  }) async => throw UnimplementedError();

  @override
  Future<ApiResponse<List<Claim>>> getMyDrafts(String userId) async =>
      ApiResponse.success([...draftsToReturn]);

  @override
  Future<ApiResponse<Map<String, dynamic>>> requestClaimCorrection({
    required String claimId,
    required String reason,
  }) async => throw UnimplementedError();

  @override
  Future<ApiResponse<Map<String, dynamic>>> reviewClaim({
    required String claimId,
    required String decisionStatus,
    required String reason,
    String? reviewerNote,
  }) async => throw UnimplementedError();

  @override
  Future<ApiResponse<List<PlaceAttribute>>> getPlaceAttributes({
    required String placeId,
    String? category,
  }) async => const ApiResponse.success([]);

  @override
  Future<ApiResponse<PlaceAttribute>> addPlaceAttribute({
    required String placeId,
    required String category,
    required String key,
    required String value,
    required String sourceDescription,
    String? reportedPeriod,
    String? uncertainty,
  }) async => throw UnimplementedError();

  @override
  Future<ApiResponse<PlaceProgress>> getPlaceProgress(String placeId) async =>
      throw UnimplementedError();

  @override
  Future<ApiResponse<List<Claim>>> getReviewQueue({int page = 1, int limit = 20}) async =>
      const ApiResponse.success([]);

  @override
  Future<ApiResponse<Map<String, dynamic>>> submitHistoryFeedback({
    required String claimId,
    String? previouslyKnown,
    String? agreement,
    String? comment,
    String? knowsAuthor,
  }) async =>
      const ApiResponse.success({'status': 'ok'});
}

void main() {
  group('CommunityService Publication Lifecycle & Feed Eligibility', () {
    late MockCommunityRepository mockRepo;
    late CommunityService service;

    setUp(() {
      mockRepo = MockCommunityRepository();
      service = CommunityService(repository: mockRepo);
    });

    Claim createClaim({
      required String id,
      required String status,
      required bool isPublic,
      String category = 'HISTORICAL_RECORD',
      String? communityTopic,
      String? consentState,
    }) {
      return Claim(
        id: id,
        title: const LocalizedContent(original: 'Claim Title', language: 'en'),
        body: const LocalizedContent(original: 'Claim Body', language: 'en'),
        category: category,
        status: status,
        locationId: 'loc-1',
        submittedAt: DateTime.now(),
        evidenceCount: 0,
        isPublic: isPublic,
        tags: const [],
        communityTopic: communityTopic,
        consentState: consentState,
      );
    }

    test('submitDraftForReview updates claim from server response, purges myDrafts, and inserts into recentClaims', () async {
      final draft = createClaim(
        id: 'claim-1',
        status: 'draft',
        isPublic: true,
        category: 'HISTORICAL_RECORD',
      );
      final serverSubmittedClaim = createClaim(
        id: 'claim-1',
        status: 'submitted',
        isPublic: true,
        category: 'HISTORICAL_RECORD',
      );

      mockRepo.draftsToReturn = [draft];
      mockRepo.claimDetailsToReturn['claim-1'] = serverSubmittedClaim;
      await service.fetchMyDrafts('user-1');

      expect(service.myDrafts.any((c) => c.id == 'claim-1'), isTrue);

      final ok = await service.submitDraftForReview('claim-1');
      expect(ok, isTrue);

      // 1. Purged from myDrafts
      expect(service.myDrafts.any((c) => c.id == 'claim-1'), isFalse);

      // 2. Updated in claims list with server submitted status
      final inClaims = service.claims.firstWhere((c) => c.id == 'claim-1');
      expect(inClaims.status, 'submitted');

      // 3. Inserted into recentClaims for public Home Page feed
      expect(service.recentClaims.any((c) => c.id == 'claim-1'), isTrue);
      expect(service.recentClaims.firstWhere((c) => c.id == 'claim-1').status, 'submitted');
    });

    test('submitDraftForReview on failed submission does not purge myDrafts and does not add to recentClaims', () async {
      final draft = createClaim(
        id: 'claim-fail-1',
        status: 'draft',
        isPublic: true,
      );

      mockRepo.draftsToReturn = [draft];
      mockRepo.submitSucceeds = false; // Simulated network or server failure
      await service.fetchMyDrafts('user-1');

      final ok = await service.submitDraftForReview('claim-fail-1');
      expect(ok, isFalse);

      // Draft remains intact in myDrafts
      expect(service.myDrafts.any((c) => c.id == 'claim-fail-1'), isTrue);
      // Not inserted into recentClaims
      expect(service.recentClaims.any((c) => c.id == 'claim-fail-1'), isFalse);
    });

    test('submitDraftForReview strictly excludes living-person biography pending consent verification from recentClaims', () async {
      final unconsentedBio = createClaim(
        id: 'claim-bio-1',
        status: 'draft',
        isPublic: true,
        category: 'PERSONAL_EXPERIENCE',
        communityTopic: 'biography',
        consentState: 'pending_verification',
      );
      final serverBioSubmitted = createClaim(
        id: 'claim-bio-1',
        status: 'submitted',
        isPublic: true,
        category: 'PERSONAL_EXPERIENCE',
        communityTopic: 'biography',
        consentState: 'pending_verification',
      );

      mockRepo.draftsToReturn = [unconsentedBio];
      mockRepo.claimDetailsToReturn['claim-bio-1'] = serverBioSubmitted;
      await service.fetchMyDrafts('user-1');

      final ok = await service.submitDraftForReview('claim-bio-1');
      expect(ok, isTrue);

      // Purged from drafts
      expect(service.myDrafts.any((c) => c.id == 'claim-bio-1'), isFalse);
      // Privacy invariant: Must NOT be present in recent public claims feed!
      expect(service.recentClaims.any((c) => c.id == 'claim-bio-1'), isFalse);
    });

    test('submitDraftForReview strictly excludes private claims (isPublic: false) from recentClaims', () async {
      final privateDraft = createClaim(
        id: 'claim-private-1',
        status: 'draft',
        isPublic: false,
        category: 'FOLKLORE',
      );
      final serverPrivateSubmitted = createClaim(
        id: 'claim-private-1',
        status: 'submitted',
        isPublic: false,
        category: 'FOLKLORE',
      );

      mockRepo.draftsToReturn = [privateDraft];
      mockRepo.claimDetailsToReturn['claim-private-1'] = serverPrivateSubmitted;
      await service.fetchMyDrafts('user-1');

      final ok = await service.submitDraftForReview('claim-private-1');
      expect(ok, isTrue);
      expect(service.recentClaims.any((c) => c.id == 'claim-private-1'), isFalse);
    });

    test('submitDraftForReview fallbacks to local copy with updated status when getClaimDetail fails', () async {
      final draft = createClaim(
        id: 'claim-local-1',
        status: 'draft',
        isPublic: true,
        category: 'CURRENT_FACT',
      );

      mockRepo.draftsToReturn = [draft];
      // Do not populate mockRepo.claimDetailsToReturn, triggering fallback
      await service.fetchMyDrafts('user-1');

      final ok = await service.submitDraftForReview('claim-local-1');
      expect(ok, isTrue);

      expect(service.myDrafts.any((c) => c.id == 'claim-local-1'), isFalse);
      expect(service.recentClaims.any((c) => c.id == 'claim-local-1'), isTrue);
      expect(service.recentClaims.firstWhere((c) => c.id == 'claim-local-1').status, 'submitted');
    });
  });
}
