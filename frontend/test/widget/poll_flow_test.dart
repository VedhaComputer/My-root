import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_root/core/error/failures.dart';
import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/poll.dart';
import 'package:my_root/repositories/auth_repository.dart';
import 'package:my_root/repositories/poll_repository.dart';
import 'package:my_root/services/auth_service.dart';
import 'package:my_root/services/poll_service.dart';
import 'package:my_root/ui/pages/polls/create_poll_page.dart';
import 'package:my_root/ui/pages/polls/poll_detail_page.dart';
import 'package:my_root/ui/pages/polls/polls_list_page.dart';

class FakePollRepository implements PollRepository {
  Poll poll;
  bool castVoteCalled = false;
  ApiResponse<Poll>? createPollOverride;

  FakePollRepository(this.poll);

  @override
  ApiClient get client => ApiClient();

  @override
  Future<ApiResponse<Poll>> getPollById(String id) async {
    return ApiResponse.success(poll);
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
    return ApiResponse.success([poll]);
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
    if (createPollOverride != null) {
      return createPollOverride!;
    }
    final created = Poll(
      id: 'poll-created-1',
      personName: personName,
      personRole: personRole,
      placeId: placeId,
      placeName: placeName,
      targetEntityId: targetEntityId,
      question: question,
      description: description,
      status: 'ACTIVE',
      startTime: DateTime.now(),
      endTime: DateTime.now().add(Duration(days: durationDays ?? 30)),
      createdBy: 'user-1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      likeCount: 0,
      dislikeCount: 0,
      totalVotes: 0,
      likePercentage: 0.0,
      dislikePercentage: 0.0,
      likeReasons: const [],
      dislikeReasons: const [],
    );
    return ApiResponse.success(created);
  }

  @override
  Future<ApiResponse<Poll>> vote({
    required String pollId,
    required String choice,
    required String reasonKey,
    String? explanation,
  }) async {
    castVoteCalled = true;
    poll = poll.copyWith(
      likeCount: choice == 'LIKE' ? poll.likeCount + 1 : poll.likeCount,
      dislikeCount: choice == 'DISLIKE' ? poll.dislikeCount + 1 : poll.dislikeCount,
      totalVotes: poll.totalVotes + 1,
      userVote: PollVote(
        choice: choice,
        reasonKey: reasonKey,
        explanation: explanation,
        updatedAt: DateTime.now(),
      ),
    );
    return ApiResponse.success(poll);
  }

  @override
  Future<ApiResponse<Poll>> closePoll(String pollId) async {
    poll = poll.copyWith(status: 'CLOSED');
    return ApiResponse.success(poll);
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> reportPoll({
    required String pollId,
    required String reason,
    String? details,
  }) async {
    return const ApiResponse.success({'reported': true});
  }
}

class MockAuthRepo implements AuthRepository {
  ApiClient get client => ApiClient();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAuthService extends AuthService {
  MockAuthService({required super.repository});
}

Widget buildTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
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
  late Poll samplePoll;
  late FakePollRepository fakeRepo;
  late PollService pollService;

  setUp(() {
    samplePoll = Poll(
      id: 'poll-test-1',
      personName: 'Sunita Devi',
      personRole: 'Panchayat Samiti Member',
      question: 'Do you approve of Sunita Devi?',
      description: 'Public opinion on leadership and work in the ward.',
      placeId: 'place-1',
      placeName: 'Dhamtan Sahib',
      createdBy: 'user-1',
      status: 'ACTIVE',
      startTime: DateTime.now().subtract(const Duration(days: 2)),
      endTime: DateTime.now().add(const Duration(days: 10)),
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now(),
      likeCount: 40,
      dislikeCount: 10,
      totalVotes: 50,
      likePercentage: 80.0,
      dislikePercentage: 20.0,
      likeReasons: const [
        PollReasonBreakdown(key: 'work_performance', count: 25, percentage: 62.5),
        PollReasonBreakdown(key: 'public_service', count: 15, percentage: 37.5),
      ],
      dislikeReasons: const [
        PollReasonBreakdown(key: 'lack_responsiveness', count: 10, percentage: 100.0),
      ],
    );
    fakeRepo = FakePollRepository(samplePoll);
    pollService = PollService(repository: fakeRepo);
  });

  group('PollDetailPage Widget Tests', () {
    testWidgets('renders disclaimer banner, person info, and live results', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          PollDetailPage(
            pollId: 'poll-test-1',
            initialPoll: samplePoll,
            pollService: pollService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Disclaimer banner
      expect(
        find.textContaining('This poll reflects individual voter opinions and public sentiment.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('It is not an official election, scientific survey, or verified finding of fact.'),
        findsOneWidget,
      );

      // Person Name and Role
      expect(find.text('Sunita Devi'), findsOneWidget);
      expect(find.textContaining('Panchayat Samiti Member'), findsOneWidget);

      // Results display (80% and 20%)
      expect(find.text('80.0% (40)'), findsOneWidget);
      expect(find.text('20.0% (10)'), findsOneWidget);
      expect(find.textContaining('Total votes: 50'), findsOneWidget);

      // Reason breakdown tabs
      expect(find.textContaining('Like Reasons'), findsWidgets);
      expect(find.textContaining('Dislike Reasons'), findsWidgets);

      // Cast opinion section exists
      expect(find.text('Cast Your Opinion'), findsOneWidget);
      expect(find.text('Like'), findsOneWidget);
      expect(find.text('Dislike'), findsOneWidget);
    });

    testWidgets('tapping Like opens reason voting sheet and allows voting', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestApp(
          PollDetailPage(
            pollId: 'poll-test-1',
            initialPoll: samplePoll,
            pollService: pollService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Like" button
      final likeButton = find.widgetWithText(FilledButton, 'Like');
      await tester.tap(likeButton);
      await tester.pumpAndSettle();

      // In bottom sheet: title and reasons list
      expect(find.text('Why do you Like this person?'), findsOneWidget);
      expect(find.textContaining('Work and performance'), findsWidgets);

      // Tap Submit Opinion button
      final submitButton = find.text('Submit Your Opinion');
      expect(submitButton, findsOneWidget);
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Vote was cast
      expect(fakeRepo.castVoteCalled, isTrue);
    });

    testWidgets('tapping Share button copies link using AppConstants.shareBaseUrl and shows SnackBar', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          PollDetailPage(
            pollId: 'poll-test-1',
            initialPoll: samplePoll,
            pollService: pollService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap share icon in AppBar
      final shareIcon = find.byIcon(Icons.share_outlined);
      expect(shareIcon, findsOneWidget);
      await tester.tap(shareIcon);
      await tester.pumpAndSettle();

      // SnackBar shows link copied
      expect(find.textContaining('copied to clipboard'), findsOneWidget);
    });

    testWidgets('prominent top Share button is visible and copies link', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          PollDetailPage(
            pollId: 'poll-test-1',
            initialPoll: samplePoll,
            pollService: pollService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final topShareButton = find.byKey(const Key('poll_detail_top_share_button'));
      expect(topShareButton, findsOneWidget);
      expect(find.text('Share This Poll'), findsOneWidget);

      await tester.tap(topShareButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('copied to clipboard'), findsOneWidget);
    });

    testWidgets('closed poll renders closed badge without active voting action', (tester) async {
      final closedPoll = samplePoll.copyWith(
        status: 'CLOSED',
        endTime: DateTime.now().subtract(const Duration(hours: 1)),
      );
      fakeRepo.poll = closedPoll;

      await tester.pumpWidget(
        buildTestApp(
          PollDetailPage(
            pollId: 'poll-test-1',
            initialPoll: closedPoll,
            pollService: pollService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify status is CLOSED
      expect(find.text('CLOSED'), findsOneWidget);

      // Verify closed banner
      expect(find.textContaining('This public opinion poll is now closed'), findsOneWidget);

      // Verify voting card is NOT present
      expect(find.text('Cast Your Opinion'), findsNothing);
    });
  });

  group('PollsListPage Widget Tests', () {
    testWidgets('renders list with search bar, filter chips, and poll cards', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          PollsListPage(
            pollService: pollService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Search bar
      expect(find.byType(TextField), findsOneWidget);

      // Filter chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Live / Active'), findsOneWidget);
      expect(find.text('Closed'), findsOneWidget);

      // Poll card rendered
      expect(find.text('Sunita Devi'), findsOneWidget);
      expect(find.textContaining('Panchayat Samiti Member'), findsOneWidget);
      expect(find.textContaining('80%'), findsWidgets);

      // FAB for creating new poll
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('renders prominent labeled Share button on each card and copies share link', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          PollsListPage(
            pollService: pollService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardShareBtn = find.byKey(Key('poll_share_btn_${samplePoll.id}'));
      expect(cardShareBtn, findsOneWidget);
      expect(find.text('Share'), findsOneWidget);

      await tester.tap(cardShareBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('copied to clipboard'), findsOneWidget);
    });
  });

  group('CreatePollPage Widget Tests', () {
    testWidgets('renders neutral disclaimer, guidelines, and input fields', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          CreatePollPage(
            initialPersonName: 'Kavita Singh',
            initialPersonRole: 'Ward Member',
            pollService: pollService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Disclaimer banner
      expect(find.textContaining('Fairness Rule:'), findsOneWidget);
      expect(find.textContaining('Please keep the wording neutral'), findsOneWidget);

      // Pre-filled values
      expect(find.text('Kavita Singh'), findsOneWidget);
      expect(find.text('Ward Member'), findsOneWidget);

      // Create button
      expect(find.text('Start Public Opinion Poll'), findsOneWidget);
    });

    testWidgets('unauthenticated or expired session shows truthful error and re-auth button', (tester) async {
      final mockAuth = MockAuthService(repository: MockAuthRepo());
      fakeRepo.createPollOverride = const ApiResponse.failure(
        AuthFailure(message: 'No token provided', code: 'UNAUTHORIZED'),
      );

      await tester.pumpWidget(
        buildTestApp(
          CreatePollPage(
            initialPersonName: 'Kavita Singh',
            initialPersonRole: 'Ward Member',
            pollService: pollService,
            authService: mockAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final submitBtn = find.text('Start Public Opinion Poll');
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Truthful error message rendered
      expect(
        find.textContaining('Your login session has expired or is missing. Please log in to publish this poll.'),
        findsOneWidget,
      );

      // Re-authentication login button is rendered
      expect(find.byKey(const Key('poll_reauth_button')), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
    });
  });
}
