import 'package:flutter/foundation.dart';
import '../models/claim.dart';
import '../models/evidence.dart';
import '../models/place_progress.dart';
import '../repositories/community_repository.dart';

class CommunityService extends ChangeNotifier {
  final CommunityRepository _repository;

  List<Claim> _claims = [];
  List<Claim> _recentClaims = [];
  List<Claim> _reviewQueue = [];
  List<PlaceAttribute> _attributes = [];
  List<Evidence> _evidenceList = [];
  PlaceProgress? _progress;
  bool _isLoading = false;
  String? _errorMessage;
  int _sessionGeneration = 0;
  int _communityDataGeneration = 0;
  int _recentClaimsGeneration = 0;
  int _draftsGeneration = 0;
  int _reviewQueueGeneration = 0;
  int _evidenceGeneration = 0;

  CommunityService({required CommunityRepository repository}) : _repository = repository;

  CommunityRepository get repository => _repository;
  List<Claim> get claims => _claims;
  List<Claim> get recentClaims => _recentClaims;
  List<Claim> get reviewQueue => _reviewQueue;
  List<PlaceAttribute> get attributes => _attributes;
  List<Evidence> get evidenceList => _evidenceList;
  PlaceProgress? get progress => _progress;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearCommunityData({bool notify = true}) {
    _sessionGeneration++;
    _claims = [];
    _recentClaims = [];
    _reviewQueue = [];
    _attributes = [];
    _evidenceList = [];
    _myDrafts = [];
    _progress = null;
    _errorMessage = null;
    _isLoading = false;
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> fetchCommunityData(String placeId) async {
    final session = _sessionGeneration;
    final opGen = ++_communityDataGeneration;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final results = await Future.wait([
      _repository.getClaimsForPlace(locationId: placeId),
      _repository.getPlaceAttributes(placeId: placeId),
      _repository.getPlaceProgress(placeId),
    ]);

    if (session != _sessionGeneration || opGen != _communityDataGeneration) {
      return;
    }

    final claimsRes = results[0] as dynamic;
    final attrsRes = results[1] as dynamic;
    final progressRes = results[2] as dynamic;

    if (claimsRes.isSuccess && claimsRes.data != null) {
      _claims = List<Claim>.from(claimsRes.data!);
    }
    if (attrsRes.isSuccess && attrsRes.data != null) {
      _attributes = List<PlaceAttribute>.from(attrsRes.data!);
    }
    if (progressRes.isSuccess && progressRes.data != null) {
      _progress = progressRes.data!;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<PlaceAttribute?> addPlaceAttribute({
    required String placeId,
    required String category,
    required String key,
    required String value,
    required String sourceDescription,
    String? reportedPeriod,
    String? uncertainty,
  }) async {
    final session = _sessionGeneration;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _repository.addPlaceAttribute(
      placeId: placeId,
      category: category,
      key: key,
      value: value,
      sourceDescription: sourceDescription,
      reportedPeriod: reportedPeriod,
      uncertainty: uncertainty,
    );

    if (session != _sessionGeneration) {
      return null;
    }

    _isLoading = false;
    if (res.isSuccess && res.data != null) {
      _attributes.insert(0, res.data!);
      notifyListeners();
      return res.data;
    } else {
      _errorMessage = res.failure?.message ?? 'Failed to add place attribute';
      notifyListeners();
      return null;
    }
  }

  Future<List<Claim>> fetchClaimsForCategory({
    required String placeId,
    required String category,
  }) async {
    final res = await _repository.getClaimsForPlace(
      locationId: placeId,
      category: category,
    );
    if (res.isSuccess && res.data != null) {
      return res.data!;
    }
    return [];
  }

  Future<void> fetchRecentClaims({String? category, int limit = 20}) async {
    final session = _sessionGeneration;
    final opGen = ++_recentClaimsGeneration;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _repository.getRecentClaims(category: category, limit: limit);
    if (session != _sessionGeneration || opGen != _recentClaimsGeneration) {
      return;
    }
    _isLoading = false;
    if (res.isSuccess && res.data != null) {
      _recentClaims = res.data!;
    } else {
      _errorMessage = res.failure?.message ?? 'Failed to load recent claims';
    }
    notifyListeners();
  }

  Future<Claim?> saveProgressiveAnswer({
    required String locationId,
    required String topic,
    required String question,
    required String answer,
    String? userChoice, // Optional: for response mode ('agreed', 'correction', 'different_account', 'dont_know')
    String? source,
    String? period,
    bool consent = false,
    String? consentNotes,
    String language = 'en',
    String? existingDraftId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Map topic to architecture's 4 information classes
    String category = 'CURRENT_FACT';
    if (topic == 'culture' || topic == 'folklore') {
      category = 'FOLKLORE';
    } else if (topic == 'history') {
      category = 'HISTORICAL_RECORD';
    } else if (topic == 'opinion') {
      category = 'PUBLIC_OPINION';
    } else if (topic == 'biography') {
      category = 'PERSONAL_EXPERIENCE';
    }

    if (existingDraftId != null) {
      final res = await _repository.updateClaimDraft(
        claimId: existingDraftId,
        title: question,
        body: answer,
        language: language,
        communityTopic: topic,
        sourceAttribution: source,
        timePeriod: period,
        consentObtained: consent,
        consentDetails: consentNotes,
        userAgreementStatus: userChoice,
      );
      _isLoading = false;
      if (!res.isSuccess) {
        _errorMessage = res.failure?.message ?? 'Failed to update draft';
      }
      notifyListeners();
      return res.data;
    } else {
      final res = await _repository.createClaimDraft(
        locationId: locationId,
        title: question,
        body: answer,
        category: category,
        language: language,
        communityTopic: topic,
        sourceAttribution: source,
        timePeriod: period,
        consentObtained: consent,
        consentDetails: consentNotes,
        userAgreementStatus: userChoice,
      );
      _isLoading = false;
      if (res.isSuccess && res.data != null) {
        _claims.insert(0, res.data!);
      } else {
        _errorMessage = res.failure?.message ?? 'Failed to create draft';
      }
      notifyListeners();
      return res.data;
    }
  }

  Future<bool> submitDraftForReview(String claimId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    final res = await _repository.submitClaimForReview(claimId);
    _isLoading = false;
    if (res.isSuccess) {
      // 1. Capture local reference before purging myDrafts
      final local = _claims.where((c) => c.id == claimId).firstOrNull ??
          _myDrafts.where((c) => c.id == claimId).firstOrNull;

      // 2. Purge from myDrafts since it is no longer in draft status
      _myDrafts.removeWhere((c) => c.id == claimId);

      // 3. Refresh authoritative claim from server or fallback to updated local copy
      final freshClaim = await fetchClaimDetail(claimId);

      Claim? updatedClaim = freshClaim;
      if (updatedClaim == null && local != null) {
        updatedClaim = Claim(
          id: local.id,
          title: local.title,
          body: local.body,
          category: local.category,
          status: 'submitted',
          locationId: local.locationId,
          submittedAt: local.submittedAt,
          evidenceCount: local.evidenceCount,
          isPublic: local.isPublic,
          tags: local.tags,
          communityTopic: local.communityTopic,
          sourceAttribution: local.sourceAttribution,
          timePeriod: local.timePeriod,
          consentObtained: local.consentObtained,
          consentDetails: local.consentDetails,
          consentState: local.consentState,
          userAgreementStatus: local.userAgreementStatus,
        );
      }

      if (updatedClaim != null) {
        // Update or insert in place claims list
        final cIndex = _claims.indexWhere((c) => c.id == claimId);
        if (cIndex >= 0) {
          _claims[cIndex] = updatedClaim;
        } else {
          _claims.insert(0, updatedClaim);
        }

        // 3. Enforce public feed eligibility matching backend publicOnly rule
        final isPubliclyEligible = updatedClaim.isPublic &&
            updatedClaim.status != 'draft' &&
            !((updatedClaim.communityTopic == 'biography' || updatedClaim.category == 'PERSONAL_EXPERIENCE') &&
                updatedClaim.consentState != 'consent_verified');

        if (isPubliclyEligible) {
          final existingIndex = _recentClaims.indexWhere((c) => c.id == claimId);
          if (existingIndex >= 0) {
            _recentClaims[existingIndex] = updatedClaim;
          } else {
            _recentClaims.insert(0, updatedClaim);
          }
        } else {
          _recentClaims.removeWhere((c) => c.id == claimId);
        }
      }

      notifyListeners();
      return true;
    }
    _errorMessage = res.failure?.message ?? 'Failed to submit claim for review';
    notifyListeners();
    return false;
  }

  List<Claim> _myDrafts = [];

  List<Claim> get myDrafts => _myDrafts;

  Future<void> fetchMyDrafts(String userId) async {
    final session = _sessionGeneration;
    final opGen = ++_draftsGeneration;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _repository.getMyDrafts(userId);
    if (session != _sessionGeneration || opGen != _draftsGeneration) {
      return;
    }
    _isLoading = false;
    if (res.isSuccess && res.data != null) {
      _myDrafts = res.data!;
    } else {
      _errorMessage = res.failure?.message ?? 'Failed to load drafts';
    }
    notifyListeners();
  }

  Future<void> fetchReviewQueue({int page = 1, int limit = 20}) async {
    final session = _sessionGeneration;
    final opGen = ++_reviewQueueGeneration;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _repository.getReviewQueue(page: page, limit: limit);
    if (session != _sessionGeneration || opGen != _reviewQueueGeneration) {
      return;
    }
    _isLoading = false;
    if (res.isSuccess && res.data != null) {
      _reviewQueue = res.data!;
    } else {
      _errorMessage = res.failure?.message ?? 'Failed to load review queue';
    }
    notifyListeners();
  }

  Future<bool> submitCorrectionRequest(String claimId, String reason) async {
    _isLoading = true;
    notifyListeners();
    final res = await _repository.requestClaimCorrection(claimId: claimId, reason: reason);
    _isLoading = false;
    notifyListeners();
    return res.isSuccess;
  }

  Future<bool> reviewClaim({
    required String claimId,
    required String decisionStatus,
    required String reason,
    String? reviewerNote,
  }) async {
    final session = _sessionGeneration;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _repository.reviewClaim(
      claimId: claimId,
      decisionStatus: decisionStatus,
      reason: reason,
      reviewerNote: reviewerNote,
    );

    if (session != _sessionGeneration) {
      return false;
    }

    _isLoading = false;
    if (res.isSuccess) {
      _reviewQueue.removeWhere((c) => c.id == claimId);
      _claims = _claims.map((c) {
        if (c.id == claimId) {
          return Claim(
            id: c.id,
            title: c.title,
            body: c.body,
            category: c.category,
            status: decisionStatus,
            locationId: c.locationId,
            submittedAt: c.submittedAt,
            submittedBy: c.submittedBy,
            evidenceCount: c.evidenceCount,
            isPublic: c.isPublic,
            tags: c.tags,
            communityTopic: c.communityTopic,
            sourceAttribution: c.sourceAttribution,
            timePeriod: c.timePeriod,
            consentObtained: c.consentObtained,
            consentDetails: c.consentDetails,
            consentState: c.consentState,
            userAgreementStatus: c.userAgreementStatus,
            latestReview: ClaimReview(
              id: 'review-local',
              decisionStatus: decisionStatus,
              reason: reason,
              timestamp: DateTime.now(),
              reviewerNote: reviewerNote,
            ),
          );
        }
        return c;
      }).toList();
      notifyListeners();
      return true;
    } else {
      _errorMessage = res.failure?.message ?? 'Failed to submit review';
      notifyListeners();
      return false;
    }
  }

  Future<Claim?> fetchClaimDetail(String claimId) async {
    final res = await _repository.getClaimDetail(claimId);
    if (res.isSuccess && res.data != null) {
      return res.data;
    }
    return null;
  }

  Future<bool> fetchEvidenceForClaim(String claimId) async {
    final session = _sessionGeneration;
    final opGen = ++_evidenceGeneration;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _repository.getEvidenceForClaim(claimId);
    if (session != _sessionGeneration || opGen != _evidenceGeneration) {
      return false;
    }
    _isLoading = false;
    if (res.isSuccess && res.data != null) {
      _evidenceList = res.data!;
      notifyListeners();
      return true;
    } else {
      _errorMessage = res.failure?.message ?? 'Failed to load evidence';
      notifyListeners();
      return false;
    }
  }

  Future<Evidence?> submitEvidence({
    required String claimId,
    required String sourceType,
    required String title,
    required String description,
    String? url,
    String? documentRef,
    DateTime? dateOfEvidence,
    String languageOfEvidence = 'en',
  }) async {
    final session = _sessionGeneration;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _repository.submitEvidence(
      claimId: claimId,
      sourceType: sourceType,
      title: title,
      description: description,
      url: url,
      documentRef: documentRef,
      dateOfEvidence: dateOfEvidence,
      languageOfEvidence: languageOfEvidence,
    );

    if (session != _sessionGeneration) {
      return null;
    }

    _isLoading = false;
    if (res.isSuccess && res.data != null) {
      _evidenceList = [res.data!, ..._evidenceList];
      _claims = _claims.map((c) {
        if (c.id == claimId) {
          return Claim(
            id: c.id,
            title: c.title,
            body: c.body,
            category: c.category,
            status: c.status,
            locationId: c.locationId,
            submittedAt: c.submittedAt,
            submittedBy: c.submittedBy,
            evidenceCount: c.evidenceCount + 1,
            isPublic: c.isPublic,
            tags: c.tags,
            communityTopic: c.communityTopic,
            sourceAttribution: c.sourceAttribution,
            timePeriod: c.timePeriod,
            consentObtained: c.consentObtained,
            consentDetails: c.consentDetails,
            consentState: c.consentState,
            userAgreementStatus: c.userAgreementStatus,
            latestReview: c.latestReview,
          );
        }
        return c;
      }).toList();
      notifyListeners();
      return res.data;
    } else {
      _errorMessage = res.failure?.message ?? 'Failed to submit evidence';
      notifyListeners();
      return null;
    }
  }

  Future<bool> reviewEvidence({
    required String evidenceId,
    required String decision,
    required String reviewNotes,
  }) async {
    final session = _sessionGeneration;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _repository.reviewEvidence(
      evidenceId: evidenceId,
      decision: decision,
      reviewNotes: reviewNotes,
    );

    if (session != _sessionGeneration) {
      return false;
    }

    _isLoading = false;
    if (res.isSuccess && res.data != null) {
      _evidenceList = _evidenceList.map((e) {
        if (e.id == evidenceId) {
          return res.data!;
        }
        return e;
      }).toList();
      notifyListeners();
      return true;
    } else {
      _errorMessage = res.failure?.message ?? 'Failed to submit evidence review';
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitHistoryFeedback({
    required String claimId,
    String? previouslyKnown,
    String? agreement,
    String? comment,
    String? knowsAuthor,
  }) async {
    final res = await _repository.submitHistoryFeedback(
      claimId: claimId,
      previouslyKnown: previouslyKnown,
      agreement: agreement,
      comment: comment,
      knowsAuthor: knowsAuthor,
    );
    if (res.isSuccess) {
      await fetchClaimDetail(claimId);
      notifyListeners();
      return true;
    } else {
      _errorMessage = res.failure?.message ?? 'Failed to submit feedback';
      notifyListeners();
      return false;
    }
  }
}


