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
    String? personName,
    String? personRole,
    String? placeId,
    String? placeName,
    String? targetEntityId,
    String? question,
    String? description,
    String? photoUrl,
    String? purpose,
    String? category,
    List<Map<String, dynamic>>? people,
    List<Map<String, dynamic>>? questions,
    DateTime? startTime,
    DateTime? endTime,
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
    String? questionId,
    String? personId,
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

  @override
  Future<ApiResponse<Map<String, dynamic>>> uploadPersonPhoto({
    required List<int> fileBytes,
    required String filename,
    String? mimeType,
  }) async {
    if (!shouldSucceed) {
      return ApiResponse.failure(ServerFailure(message: failureMessage ?? 'Failed to upload photo'));
    }
    return const ApiResponse.success({'photoUrl': '/uploads/polls/people/test_photo.jpg'});
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

    test('Poll produces canonical plain share URL without markdown formatting', () {
      final samplePoll = Poll(
        id: '6ae0023783a1ad5dec7bd486',
        personName: 'Ramesh Patel',
        question: 'Should Ramesh Patel lead the committee?',
        status: 'ACTIVE',
        startTime: DateTime.parse('2026-10-01T00:00:00.000Z'),
        createdBy: 'user-creator',
        likeCount: 0,
        dislikeCount: 0,
        totalVotes: 0,
        likePercentage: 0.0,
        dislikePercentage: 0.0,
        likeReasons: const [],
        dislikeReasons: const [],
        createdAt: DateTime.parse('2026-10-01T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-10-01T00:00:00.000Z'),
      );

      final shareUrl = samplePoll.shareUrl;
      expect(shareUrl, 'https://myroot.in/polls/6ae0023783a1ad5dec7bd486');
      expect(shareUrl.contains('['), isFalse);
      expect(shareUrl.contains(']'), isFalse);
      expect(shareUrl.contains('('), isFalse);
      expect(shareUrl.contains(')'), isFalse);

      final enPayload = samplePoll.sharePayload(isHindi: false);
      expect(enPayload, contains('https://myroot.in/polls/6ae0023783a1ad5dec7bd486'));
      expect(enPayload, contains('Live Public Opinion Poll: Should Ramesh Patel lead the committee?'));
      expect(enPayload.contains('[https'), isFalse);
      expect(enPayload.contains(']('), isFalse);

      final hiPayload = samplePoll.sharePayload(isHindi: true);
      expect(hiPayload, contains('https://myroot.in/polls/6ae0023783a1ad5dec7bd486'));
      expect(hiPayload, contains('जनमत सर्वेक्षण: Should Ramesh Patel lead the committee?'));
      expect(hiPayload.contains('[https'), isFalse);
      expect(hiPayload.contains(']('), isFalse);
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

      // Transparency reason support
      final transEn = PollReasonOption.lookupLabel('transparency', true, false);
      final transHi = PollReasonOption.lookupLabel('transparency', true, true);
      expect(transEn, contains('Transparency'));
      expect(transHi, contains('पारदर्शिता'));

      final lackTransEn = PollReasonOption.lookupLabel('lack_transparency', false, false);
      final lackTransHi = PollReasonOption.lookupLabel('lack_transparency', false, true);
      expect(lackTransEn, contains('transparency'));
      expect(lackTransHi, contains('पारदर्शिता'));
    });

    test('Poll.fromJson parses multi-person, multi-question polls with purpose and duration > 3 months', () {
      final json = {
        'id': 'p-multi',
        'purpose': 'Panchayat Elections 2026 Assessment',
        'category': 'GOVERNANCE',
        'personName': 'Candidate 1',
        'question': 'General question?',
        'status': 'ACTIVE',
        'startTime': '2026-01-01T00:00:00.000Z',
        'endTime': '2027-01-01T00:00:00.000Z', // 1 year (365 days)
        'createdBy': 'user-1',
        'people': [
          {
            'id': 'person-1',
            'name': 'Candidate 1',
            'role': 'Sarpanch',
            'designation': 'Village Head',
            'officeContext': 'Current Representative',
            'placeName': 'Amer',
          },
          {
            'id': 'person-2',
            'name': 'Candidate 2',
            'role': 'Ward Member',
            'designation': 'Ward 5 Head',
            'officeContext': 'Contender',
            'placeName': 'Amer',
          },
        ],
        'questions': [
          {
            'id': 'q-1',
            'text': 'Rate Candidate 1 on development work',
            'personId': 'person-1',
            'likeCount': 30,
            'dislikeCount': 10,
            'totalVotes': 40,
            'likePercentage': 75.0,
            'dislikePercentage': 25.0,
            'likeReasons': [
              {'key': 'work_performance', 'count': 30, 'percentage': 100.0},
            ],
            'dislikeReasons': <Map<String, dynamic>>[],
          },
          {
            'id': 'q-2',
            'text': 'Rate Candidate 2 on transparency and integrity',
            'personId': 'person-2',
            'likeCount': 20,
            'dislikeCount': 5,
            'totalVotes': 25,
            'likePercentage': 80.0,
            'dislikePercentage': 20.0,
            'likeReasons': [
              {'key': 'transparency', 'count': 20, 'percentage': 100.0},
            ],
            'dislikeReasons': <Map<String, dynamic>>[],
          },
        ],
        'likeCount': 50,
        'dislikeCount': 15,
        'totalVotes': 65,
        'likePercentage': 76.9,
        'dislikePercentage': 23.1,
        'likeReasons': <Map<String, dynamic>>[],
        'dislikeReasons': <Map<String, dynamic>>[],
      };

      final poll = Poll.fromJson(json);
      expect(poll.isMultiPerson, true);
      expect(poll.isMultiQuestion, true);
      expect(poll.purpose, 'Panchayat Elections 2026 Assessment');
      expect(poll.category, 'GOVERNANCE');
      expect(poll.people.length, 2);
      expect(poll.people[0].name, 'Candidate 1');
      expect(poll.people[0].officeContext, 'Current Representative');
      expect(poll.people[1].name, 'Candidate 2');
      expect(poll.people[1].officeContext, 'Contender');

      expect(poll.questions.length, 2);
      expect(poll.questions[0].totalVotes, 40);
      expect(poll.questions[0].likePercentage, 75.0);
      expect(poll.questions[1].totalVotes, 25);
      expect(poll.questions[1].likePercentage, 80.0);
      expect(poll.questions[1].likeReasons.first.key, 'transparency');

      // Duration is 1 year (365 days) > 3 months
      final durationDays = poll.endTime!.difference(poll.startTime).inDays;
      expect(durationDays, greaterThan(90));
    });

    test('PollPerson.fromJson and toJson serialize/deserialize full profile card fields accurately', () {
      final personJson = {
        'id': 'p-profile-1',
        'name': 'Kamla Devi',
        'role': 'Sarpanch',
        'designation': 'Village Head',
        'officeContext': 'Current Term',
        'placeName': 'Kotputli',
        'photoUrl': 'https://example.com/kamla.jpg',
        'workBackground': 'Agricultural cooperative leadership',
        'publicServiceHistory': 'Built 2 community water tanks and rural girls school',
        'education': 'Bachelor of Arts (B.A.)',
        'achievements': 'State Rural Leadership Award 2024',
        'casteCommunity': 'Yadav',
        'religion': 'Hinduism',
        'bio': 'Committed to village youth education and rural drinking water systems',
        'sourceReference': 'Gram Panchayat Gazette 2021',
        'verificationStatus': 'DOCUMENTED',
      };

      final person = PollPerson.fromJson(personJson);
      expect(person.id, 'p-profile-1');
      expect(person.name, 'Kamla Devi');
      expect(person.role, 'Sarpanch');
      expect(person.designation, 'Village Head');
      expect(person.officeContext, 'Current Term');
      expect(person.placeName, 'Kotputli');
      expect(person.photoUrl, 'https://example.com/kamla.jpg');
      expect(person.workBackground, 'Agricultural cooperative leadership');
      expect(person.publicServiceHistory, 'Built 2 community water tanks and rural girls school');
      expect(person.education, 'Bachelor of Arts (B.A.)');
      expect(person.achievements, 'State Rural Leadership Award 2024');
      expect(person.casteCommunity, 'Yadav');
      expect(person.religion, 'Hinduism');
      expect(person.bio, 'Committed to village youth education and rural drinking water systems');
      expect(person.sourceReference, 'Gram Panchayat Gazette 2021');
      expect(person.verificationStatus, 'DOCUMENTED');

      final serialized = person.toJson();
      expect(serialized['id'], 'p-profile-1');
      expect(serialized['name'], 'Kamla Devi');
      expect(serialized['workBackground'], 'Agricultural cooperative leadership');
      expect(serialized['casteCommunity'], 'Yadav');
      expect(serialized['religion'], 'Hinduism');
      expect(serialized['verificationStatus'], 'DOCUMENTED');
    });

    test('PollPerson handles missing optional profile card fields neutrally without fabrication', () {
      final minimalJson = {
        'id': 'p-min',
        'name': 'Rajesh Rawat',
      };

      final person = PollPerson.fromJson(minimalJson);
      expect(person.id, 'p-min');
      expect(person.name, 'Rajesh Rawat');
      expect(person.role, isNull);
      expect(person.officeContext, isNull);
      expect(person.photoUrl, isNull);
      expect(person.workBackground, isNull);
      expect(person.publicServiceHistory, isNull);
      expect(person.education, isNull);
      expect(person.achievements, isNull);
      // Privacy check: caste and religion must never be inferred or defaulted
      expect(person.casteCommunity, isNull);
      expect(person.religion, isNull);
      expect(person.bio, isNull);
      expect(person.sourceReference, isNull);
      // Neutral default verification status
      expect(person.verificationStatus, 'UNVERIFIED');
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

    test('uploadPersonPhoto returns photoUrl on success', () async {
      final photoUrl = await service.uploadPersonPhoto(
        fileBytes: [1, 2, 3, 4],
        filename: 'avatar.jpg',
        mimeType: 'image/jpeg',
      );
      expect(photoUrl, '/uploads/polls/people/test_photo.jpg');
      expect(service.errorMessage, isNull);
    });

    test('uploadPersonPhoto sets errorMessage and returns null on failure', () async {
      mockRepo.shouldSucceed = false;
      mockRepo.failureMessage = 'File size exceeds 5MB limit';

      final photoUrl = await service.uploadPersonPhoto(
        fileBytes: [1, 2, 3, 4],
        filename: 'avatar.jpg',
      );
      expect(photoUrl, isNull);
      expect(service.errorMessage, 'File size exceeds 5MB limit');
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

    test('uploadMultipart attaches Bearer token and uploads binary bytes', () async {
      SharedPreferences.setMockInitialValues({
        SecureTokenStorage.keyAccessToken: 'persisted-jwt-token-xyz',
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = SecureTokenStorage(prefs: prefs);

      String? capturedAuthHeader;
      final mockHttp = MockClient((request) async {
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(jsonEncode({
          'data': {
            'photoUrl': '/uploads/polls/people/sample.jpg',
            'filename': 'sample.jpg',
          }
        }), 200);
      });

      final client = ApiClient(client: mockHttp, tokenStorage: storage);
      final res = await client.uploadMultipart(
        path: '/polls/upload-photo',
        fieldName: 'photo',
        fileBytes: [0xff, 0xd8, 0xff],
        filename: 'person.jpg',
        mimeType: 'image/jpeg',
      );

      expect(res.isSuccess, isTrue);
      expect(res.data?['data']['photoUrl'], '/uploads/polls/people/sample.jpg');
      expect(capturedAuthHeader, 'Bearer persisted-jwt-token-xyz');
    });
  });
}
