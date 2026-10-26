import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_root/core/error/failures.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/poll.dart';
import 'package:my_root/repositories/poll_repository.dart';
import 'package:my_root/services/poll_service.dart';
import 'package:my_root/services/secure_token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPollRepository implements PollRepository {
  bool shouldSucceed = true;
  String? failureMessage;

  @override
  ApiClient get client => ApiClient();

  Poll samplePoll = Poll(
    id: 'poll-123',
    personName: 'Rajesh Kumar',
    personRole: 'Sarpanch',
    question: 'Do you approve of Rajesh Kumar as Sarpanch?',
    description: 'Performance review',
    placeId: 'place-vil-1',
    placeName: 'Dhamtan Sahib',
    createdBy: 'user-creator',
    status: 'ACTIVE',
    startTime: DateTime.now().subtract(const Duration(days: 1)),
    endTime: DateTime.now().add(const Duration(days: 7)),
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    updatedAt: DateTime.now(),
    likeCount: 15,
    dislikeCount: 5,
    totalVotes: 20,
    likePercentage: 75.0,
    dislikePercentage: 25.0,
    likeReasons: const [
      PollReasonBreakdown(key: 'work_performance', count: 10, percentage: 66.7),
      PollReasonBreakdown(key: 'public_service', count: 5, percentage: 33.3),
    ],
    dislikeReasons: const [
      PollReasonBreakdown(key: 'lack_responsiveness', count: 5, percentage: 100.0),
    ],
  );

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
    if (!shouldSucceed) {
      return ApiResponse.failure(ServerFailure(message: failureMessage ?? 'Failed to create poll'));
    }
    return ApiResponse.success(samplePoll);
  }

  @override
  Future<ApiResponse<Poll>> getPollById(String id) async {
    if (!shouldSucceed) {
      return ApiResponse.failure(ServerFailure(message: failureMessage ?? 'Poll not found'));
    }
    return ApiResponse.success(samplePoll);
  }

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
    if (!shouldSucceed) {
      return ApiResponse.failure(ServerFailure(message: failureMessage ?? 'Failed to load polls'));
    }
    return ApiResponse.success([samplePoll]);
  }

  @override
  Future<ApiResponse<Poll>> vote({
    required String pollId,
    required String choice,
    required String reasonKey,
    String? explanation,
  }) async {
    if (!shouldSucceed) {
      return ApiResponse.failure(ServerFailure(message: failureMessage ?? 'Failed to cast vote'));
    }
    final updated = samplePoll.copyWith(
      likeCount: choice == 'LIKE' ? samplePoll.likeCount + 1 : samplePoll.likeCount,
      totalVotes: samplePoll.totalVotes + 1,
      userVote: PollVote(
        choice: choice,
        reasonKey: reasonKey,
        explanation: explanation,
        updatedAt: DateTime.now(),
      ),
    );
    return ApiResponse.success(updated);
  }

  @override
  Future<ApiResponse<Poll>> closePoll(String pollId) async {
    if (!shouldSucceed) {
      return ApiResponse.failure(ServerFailure(message: failureMessage ?? 'Failed to close poll'));
    }
    final updated = samplePoll.copyWith(status: 'CLOSED');
    return ApiResponse.success(updated);
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> reportPoll({
    required String pollId,
    required String reason,
    String? details,
  }) async {
    if (!shouldSucceed) {
      return ApiResponse.failure(ServerFailure(message: failureMessage ?? 'Failed to report poll'));
    }
    return const ApiResponse.success({'reported': true});
  }
}

void main() {
  group('Poll Models', () {
    test('Poll.fromJson parses fields and computed values correctly', () {
      final json = {
        'id': 'p1',
        'personName': 'Amit Sharma',
        'personRole': 'MLA',
        'question': 'Do you approve of Amit Sharma?',
        'description': 'Public sentiment',
        'placeId': 'PL_1',
        'placeName': 'Karnal',
        'createdBy': 'u1',
        'status': 'ACTIVE',
        'startTime': '2026-10-01T00:00:00.000Z',
        'endTime': '2026-11-01T00:00:00.000Z',
        'createdAt': '2026-10-01T00:00:00.000Z',
        'updatedAt': '2026-10-02T00:00:00.000Z',
        'likeCount': 40,
        'dislikeCount': 10,
        'totalVotes': 50,
        'likePercentage': 80.0,
        'dislikePercentage': 20.0,
        'likeReasons': [
          {'key': 'work_performance', 'count': 20, 'percentage': 50.0},
          {'key': 'public_service', 'count': 20, 'percentage': 50.0},
        ],
        'dislikeReasons': [
          {'key': 'lack_responsiveness', 'count': 10, 'percentage': 100.0},
        ],
        'userVote': {
          'choice': 'LIKE',
          'reasonKey': 'work_performance',
          'explanation': 'Works hard for our constituency',
          'updatedAt': '2026-10-02T00:00:00.000Z',
        },
      };

      final poll = Poll.fromJson(json);
      expect(poll.id, 'p1');
      expect(poll.personName, 'Amit Sharma');
      expect(poll.personRole, 'MLA');
      expect(poll.likeCount, 40);
      expect(poll.dislikeCount, 10);
      expect(poll.totalVotes, 50);
      expect(poll.likePercentage, 80.0);
      expect(poll.dislikePercentage, 20.0);
      expect(poll.userVote, isNotNull);
      expect(poll.userVote!.choice, 'LIKE');
      expect(poll.userVote!.reasonKey, 'work_performance');
      expect(poll.isActive, true);
    });

    test('Poll.fromJson handles zero votes with 0% gracefully', () {
      final json = {
        'id': 'p2',
        'personName': 'Pooja Verma',
        'personRole': 'Panch',
        'question': 'Public opinion on Pooja Verma',
        'createdBy': 'u1',
        'status': 'ACTIVE',
        'startTime': '2026-10-01T00:00:00.000Z',
        'endTime': '2026-12-01T00:00:00.000Z',
        'createdAt': '2026-10-01T00:00:00.000Z',
        'updatedAt': '2026-10-01T00:00:00.000Z',
        'likeCount': 0,
        'dislikeCount': 0,
        'totalVotes': 0,
        'likeReasons': <Map<String, dynamic>>[],
        'dislikeReasons': <Map<String, dynamic>>[],
      };

      final poll = Poll.fromJson(json);
      expect(poll.totalVotes, 0);
      expect(poll.likePercentage, 0.0);
      expect(poll.dislikePercentage, 0.0);
      expect(poll.userVote, isNull);
    });

    test('PollReasonOption localized labels support English and Hindi', () {
      final lookupEn = PollReasonOption.lookupLabel('work_performance', true, false);
      final lookupHi = PollReasonOption.lookupLabel('work_performance', true, true);
      expect(lookupEn, contains('Work'));
      expect(lookupHi, contains('काम'));

      final dislikeEn = PollReasonOption.lookupLabel('lack_responsiveness', false, false);
      final dislikeHi = PollReasonOption.lookupLabel('lack_responsiveness', false, true);
      expect(dislikeEn, contains('responsiveness'));
      expect(dislikeHi, contains('संवाद'));
    });
  });

  group('PollService', () {
    late MockPollRepository mockRepo;
    late PollService service;

    setUp(() {
      mockRepo = MockPollRepository();
      service = PollService(repository: mockRepo);
    });

    test('fetchPolls updates polls list and notifies listeners', () async {
      bool notified = false;
      service.addListener(() => notified = true);

      expect(service.isLoading, false);
      final future = service.fetchPolls();
      expect(service.isLoading, true);

      await future;
      expect(service.isLoading, false);
      expect(service.polls.length, 1);
      expect(service.polls.first.personName, 'Rajesh Kumar');
      expect(notified, true);
    });

    test('fetchPolls sets errorMessage on failure', () async {
      mockRepo.shouldSucceed = false;
      mockRepo.failureMessage = 'Network connection failed';

      await service.fetchPolls();
      expect(service.isLoading, false);
      expect(service.errorMessage, 'Network connection failed');
      expect(service.polls, isEmpty);
    });

    test('fetchPollById updates currentPoll', () async {
      await service.fetchPollById('poll-123');
      expect(service.currentPoll, isNotNull);
      expect(service.currentPoll!.id, 'poll-123');
      expect(service.currentPoll!.personName, 'Rajesh Kumar');
    });

    test('createPoll prepends created poll to state and returns it', () async {
      final result = await service.createPoll(
        personName: 'Rajesh Kumar',
        personRole: 'Sarpanch',
        question: 'Do you approve?',
      );

      expect(result, isNotNull);
      expect(service.polls.length, 1);
      expect(service.polls.first.id, 'poll-123');
    });

    test('castVote updates currentPoll and polls list atomically', () async {
      await service.fetchPolls();
      expect(service.polls.first.likeCount, 15);

      final updated = await service.castVote(
        pollId: 'poll-123',
        choice: 'LIKE',
        reasonKey: 'work_performance',
        explanation: 'Very good road work',
      );

      expect(updated, isNotNull);
      expect(updated!.likeCount, 16);
      expect(updated.userVote?.choice, 'LIKE');
      expect(service.currentPoll?.likeCount, 16);
      expect(service.polls.first.likeCount, 16);
    });

    test('closePoll updates poll status to CLOSED', () async {
      await service.fetchPollById('poll-123');
      expect(service.currentPoll!.status, 'ACTIVE');

      final closed = await service.closePoll('poll-123');
      expect(closed, isNotNull);
      expect(closed!.status, 'CLOSED');
      expect(service.currentPoll!.status, 'CLOSED');
    });

    test('reportPoll returns true on success', () async {
      final reported = await service.reportPoll(
        pollId: 'poll-123',
        reason: 'HATE_SPEECH_OR_DEFAMATION',
        details: 'Violates platform rules',
      );
      expect(reported, true);
    });
  });

  group('ApiClient Token Auto-Resolution and Authorization Header', () {
    test('automatically resolves and attaches Bearer token from SecureTokenStorage when access token is unset', () async {
      SharedPreferences.setMockInitialValues({
        SecureTokenStorage.keyAccessToken: 'persisted-jwt-token-xyz',
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = SecureTokenStorage(prefs: prefs);

      String? capturedAuthHeader;
      final mockHttp = MockClient((request) async {
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(jsonEncode({'data': {'id': 'poll-abc'}}), 200);
      });

      // ApiClient starts with unset token
      final client = ApiClient(client: mockHttp, tokenStorage: storage);
      expect(client.accessToken, isNull);

      final response = await client.post('/polls', {'question': 'Test'});
      expect(response.isSuccess, isTrue);
      expect(capturedAuthHeader, 'Bearer persisted-jwt-token-xyz');
      expect(client.accessToken, 'persisted-jwt-token-xyz');
    });

    test('retains explicitly set token without overwriting if already provided', () async {
      SharedPreferences.setMockInitialValues({
        SecureTokenStorage.keyAccessToken: 'persisted-jwt-token-xyz',
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = SecureTokenStorage(prefs: prefs);

      String? capturedAuthHeader;
      final mockHttp = MockClient((request) async {
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(jsonEncode({'data': {}}), 200);
      });

      final client = ApiClient(client: mockHttp, tokenStorage: storage);
      client.setAccessToken('explicit-active-session-token');

      await client.get('/polls');
      expect(capturedAuthHeader, 'Bearer explicit-active-session-token');
      expect(client.accessToken, 'explicit-active-session-token');
    });
  });
}
