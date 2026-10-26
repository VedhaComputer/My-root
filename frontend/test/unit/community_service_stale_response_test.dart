import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/claim.dart';
import 'package:my_root/models/place_progress.dart';
import 'package:my_root/repositories/community_repository.dart';
import 'package:my_root/services/community_service.dart';

class MockStaleCommunityRepo implements CommunityRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  Completer<ApiResponse<List<Claim>>>? draftsCompleter;
  Completer<ApiResponse<List<Claim>>>? recentClaimsCompleter;
  Completer<ApiResponse<List<Claim>>>? placeClaimsCompleter;

  @override
  Future<ApiResponse<List<Claim>>> getMyDrafts(String userId) async {
    if (draftsCompleter != null) {
      return draftsCompleter!.future;
    }
    return const ApiResponse.success([]);
  }

  @override
  Future<ApiResponse<List<Claim>>> getRecentClaims({String? category, int limit = 20}) async {
    if (recentClaimsCompleter != null) {
      return recentClaimsCompleter!.future;
    }
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
  }) async {
    if (placeClaimsCompleter != null) {
      return placeClaimsCompleter!.future;
    }
    return const ApiResponse.success([]);
  }

  @override
  Future<ApiResponse<List<PlaceAttribute>>> getPlaceAttributes({
    required String placeId,
    String? category,
  }) async {
    return const ApiResponse.success([]);
  }

  @override
  Future<ApiResponse<PlaceProgress>> getPlaceProgress(String placeId) async {
    return const ApiResponse.success(
      PlaceProgress(
        placeId: 'place-1',
        totalContributions: 0,
        verifiedFactsCount: 0,
        pendingReviewCount: 0,
        folkloreCount: 0,
        opinionsCount: 0,
        biographiesCount: 0,
        facilitiesCount: 0,
        evidenceAttachmentsCount: 0,
        qualityCoverageScore: 0,
        criteriaExplanation: '',
      ),
    );
  }
}

void main() {
  group('CommunityService Stale Response & Session Isolation', () {
    late MockStaleCommunityRepo repo;
    late CommunityService service;

    final testClaim = Claim(
      id: 'claim-1',
      title: const LocalizedContent(original: 'Stale Claim', language: 'en'),
      body: const LocalizedContent(original: 'Stale Body', language: 'en'),
      category: 'HISTORICAL_FACT',
      locationId: 'place-1',
      status: 'PUBLISHED',
      submittedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
      evidenceCount: 0,
      isPublic: true,
      tags: const [],
      submittedBy: 'user-A',
    );

    setUp(() {
      repo = MockStaleCommunityRepo();
      service = CommunityService(repository: repo);
    });

    test('clearCommunityData resets all community collections including myDrafts', () async {
      repo.draftsCompleter = Completer<ApiResponse<List<Claim>>>();
      final fetchFuture = service.fetchMyDrafts('user-A');
      repo.draftsCompleter!.complete(ApiResponse.success([testClaim]));
      await fetchFuture;

      expect(service.myDrafts.length, 1);
      expect(service.myDrafts.first.id, 'claim-1');

      // Logout or session switch
      service.clearCommunityData();

      expect(service.myDrafts, isEmpty);
      expect(service.claims, isEmpty);
      expect(service.recentClaims, isEmpty);
      expect(service.reviewQueue, isEmpty);
      expect(service.attributes, isEmpty);
      expect(service.evidenceList, isEmpty);
      expect(service.progress, isNull);
    });

    test('In-flight fetchMyDrafts is discarded if clearCommunityData is called before response', () async {
      repo.draftsCompleter = Completer<ApiResponse<List<Claim>>>();
      final fetchFuture = service.fetchMyDrafts('user-A');

      // Session switch happens while request is pending
      service.clearCommunityData();

      // Delayed response arrives
      repo.draftsCompleter!.complete(ApiResponse.success([testClaim]));
      await fetchFuture;

      // Stale response must be rejected
      expect(service.myDrafts, isEmpty);
    });

    test('In-flight fetchRecentClaims is discarded if clearCommunityData is called before response', () async {
      repo.recentClaimsCompleter = Completer<ApiResponse<List<Claim>>>();
      final fetchFuture = service.fetchRecentClaims();

      // Session switch happens
      service.clearCommunityData();

      // Delayed response arrives
      repo.recentClaimsCompleter!.complete(ApiResponse.success([testClaim]));
      await fetchFuture;

      // Stale response must be rejected
      expect(service.recentClaims, isEmpty);
    });

    test('In-flight fetchCommunityData is discarded if clearCommunityData is called before response', () async {
      repo.placeClaimsCompleter = Completer<ApiResponse<List<Claim>>>();
      final fetchFuture = service.fetchCommunityData('place-1');

      // Session switch happens
      service.clearCommunityData();

      // Delayed response arrives
      repo.placeClaimsCompleter!.complete(ApiResponse.success([testClaim]));
      await fetchFuture;

      // Stale response must be rejected
      expect(service.claims, isEmpty);
      expect(service.progress, isNull);
    });

    test('Overlapping fetches belonging to the same active session do NOT invalidate one another', () async {
      repo.placeClaimsCompleter = Completer<ApiResponse<List<Claim>>>();
      repo.draftsCompleter = Completer<ApiResponse<List<Claim>>>();

      // Start community data fetch
      final communityFuture = service.fetchCommunityData('place-1');

      // Start drafts fetch concurrently within the same session
      final draftsFuture = service.fetchMyDrafts('user-A');

      // Both complete within the same session
      repo.placeClaimsCompleter!.complete(ApiResponse.success([testClaim]));
      repo.draftsCompleter!.complete(ApiResponse.success([testClaim]));

      await Future.wait([communityFuture, draftsFuture]);

      // Both must succeed and populate their respective collections
      expect(service.claims.length, 1);
      expect(service.myDrafts.length, 1);
    });
  });
}
