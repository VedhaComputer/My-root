import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
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
  ApiResponse<Map<String, dynamic>>? uploadPhotoOverride;
  int uploadPhotoCalls = 0;

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
    if (createPollOverride != null) {
      return createPollOverride!;
    }
    final resolvedPersonName = personName ??
        (people != null && people.isNotEmpty ? people.first['name'] as String? : 'Test Person') ??
        'Test Person';
    final resolvedQuestion = question ??
        (questions != null && questions.isNotEmpty ? questions.first['text'] as String? : 'Test Question') ??
        'Test Question';

    final created = Poll(
      id: 'poll-created-1',
      purpose: purpose,
      category: category,
      personName: resolvedPersonName,
      personRole: personRole,
      placeId: placeId,
      placeName: placeName,
      targetEntityId: targetEntityId,
      question: resolvedQuestion,
      description: description,
      status: 'ACTIVE',
      startTime: startTime ?? DateTime.now(),
      endTime: endTime ?? DateTime.now().add(Duration(days: durationDays ?? 30)),
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
    String? questionId,
    String? personId,
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

  @override
  Future<ApiResponse<Map<String, dynamic>>> uploadPersonPhoto({
    required List<int> fileBytes,
    required String filename,
    String? mimeType,
  }) async {
    uploadPhotoCalls++;
    if (uploadPhotoOverride != null) {
      return uploadPhotoOverride!;
    }
    return const ApiResponse.success({
      'photoUrl': '/uploads/polls/people/uploaded_person_123.jpg',
      'filename': 'uploaded_person_123.jpg',
      'size': 1024,
      'mimeType': 'image/jpeg',
    });
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
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            copiedText = (methodCall.arguments as Map?)?['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

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
      expect(copiedText, contains('https://myroot.in/polls/${samplePoll.id}'));
      expect(copiedText?.contains(']('), isFalse);
      expect(copiedText?.contains('[https://'), isFalse);
    });

    testWidgets('prominent top Share button is visible and copies link', (tester) async {
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            copiedText = (methodCall.arguments as Map?)?['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

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
      expect(copiedText, contains('https://myroot.in/polls/${samplePoll.id}'));
      expect(copiedText?.contains(']('), isFalse);
      expect(copiedText?.contains('[https://'), isFalse);
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
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            copiedText = (methodCall.arguments as Map?)?['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

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
      expect(copiedText, contains('https://myroot.in/polls/${samplePoll.id}'));
      expect(copiedText?.contains(']('), isFalse);
      expect(copiedText?.contains('[https://'), isFalse);
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

    testWidgets('allows dynamically adding multiple people and questions', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          CreatePollPage(
            initialPersonName: 'Candidate One',
            initialPersonRole: 'Sarpanch',
            pollService: pollService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially 1 person and 1 question
      expect(find.text('Person #1'), findsOneWidget);
      expect(find.text('Question #1 *'), findsOneWidget);

      // Tap + Add Person
      final addPersonBtn = find.text('+ Add Person');
      await tester.ensureVisible(addPersonBtn);
      await tester.tap(addPersonBtn);
      await tester.pumpAndSettle();

      expect(find.text('Person #2'), findsOneWidget);

      // Tap + Add Question
      final addQuestionBtn = find.text('+ Add Question');
      await tester.ensureVisible(addQuestionBtn);
      await tester.tap(addQuestionBtn);
      await tester.pumpAndSettle();

      expect(find.text('Question #2 *'), findsOneWidget);
    });

    testWidgets('allows picking and uploading real person photo with preview, change, and remove actions', (tester) async {
      final repo = FakePollRepository(samplePoll);
      final pollService = PollService(repository: repo);
      final authService = AuthService(repository: MockAuthRepo());

      const validPngBytes = <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ];
      final fakeXFile = XFile.fromData(
        Uint8List.fromList(validPngBytes),
        name: 'mukesh_photo.png',
        path: 'mukesh_photo.png',
        mimeType: 'image/png',
      );

      await tester.pumpWidget(
        buildTestApp(
          CreatePollPage(
            pollService: pollService,
            authService: authService,
            imagePickerOverride: () async => fakeXFile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "Upload Photo" button is visible initially
      final uploadBtn = find.byKey(const ValueKey('upload_photo_button_0'));
      await tester.ensureVisible(uploadBtn);
      expect(uploadBtn, findsOneWidget);
      expect(find.text('Upload Photo'), findsOneWidget);
      expect(find.text('JPG, PNG or WebP (max 5MB)'), findsOneWidget);

      // Tap Upload Photo
      await tester.tap(uploadBtn);
      await tester.pumpAndSettle();

      // Verify repository was called
      expect(repo.uploadPhotoCalls, 1);

      // Verify photo preview is shown, along with filename, change photo, and remove buttons
      expect(find.text('mukesh_photo.png'), findsOneWidget);
      final changeBtn = find.byKey(const ValueKey('change_photo_button_0'));
      final removeBtn = find.byKey(const ValueKey('remove_photo_button_0'));
      expect(changeBtn, findsOneWidget);
      expect(removeBtn, findsOneWidget);

      // Remove photo
      await tester.ensureVisible(removeBtn);
      await tester.tap(removeBtn);
      await tester.pumpAndSettle();

      // Verify returned to Upload Photo button
      expect(find.byKey(const ValueKey('upload_photo_button_0')), findsOneWidget);
      expect(find.text('Upload Photo'), findsOneWidget);
    });

    testWidgets('upload failure displays error message without crashing', (tester) async {
      final repo = FakePollRepository(samplePoll);
      repo.uploadPhotoOverride = const ApiResponse.failure(ServerFailure(message: 'File size exceeds 5MB limit'));
      final pollService = PollService(repository: repo);
      final authService = AuthService(repository: MockAuthRepo());

      const validPngBytes = <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ];
      final fakeXFile = XFile.fromData(
        Uint8List.fromList(validPngBytes),
        name: 'large_image.png',
        mimeType: 'image/png',
      );

      await tester.pumpWidget(
        buildTestApp(
          CreatePollPage(
            pollService: pollService,
            authService: authService,
            imagePickerOverride: () async => fakeXFile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final uploadBtn = find.byKey(const ValueKey('upload_photo_button_0'));
      await tester.ensureVisible(uploadBtn);
      await tester.tap(uploadBtn);
      await tester.pumpAndSettle();

      expect(find.text('File size exceeds 5MB limit'), findsOneWidget);
      expect(find.byKey(const ValueKey('upload_photo_button_0')), findsOneWidget);
    });

    testWidgets('handles platform channel error gracefully with clear restart advice without crashing', (tester) async {
      final repo = FakePollRepository(samplePoll);
      final pollService = PollService(repository: repo);
      final authService = AuthService(repository: MockAuthRepo());

      await tester.pumpWidget(
        buildTestApp(
          CreatePollPage(
            pollService: pollService,
            authService: authService,
            imagePickerOverride: () async {
              throw PlatformException(
                code: 'channel-error',
                message: 'Unable to establish connection on channel: "dev.flutter.pigeon.file_selector_windows.FileSelectorApi.showOpenDialog".',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final uploadBtn = find.byKey(const ValueKey('upload_photo_button_0'));
      await tester.ensureVisible(uploadBtn);
      await tester.tap(uploadBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('Photo picker plugin connection error. Please restart the application to complete native plugin registration.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('upload_photo_button_0')), findsOneWidget);
    });

    testWidgets('multi-person photo upload does not clear or affect other person form fields', (tester) async {
      final repo = FakePollRepository(samplePoll);
      final pollService = PollService(repository: repo);
      final authService = AuthService(repository: MockAuthRepo());

      const validPngBytes = <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ];
      final fakeXFile = XFile.fromData(
        Uint8List.fromList(validPngBytes),
        name: 'second_person.png',
        path: 'second_person.png',
        mimeType: 'image/png',
      );

      await tester.pumpWidget(
        buildTestApp(
          CreatePollPage(
            pollService: pollService,
            authService: authService,
            imagePickerOverride: () async => fakeXFile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fill person 1 name
      final nameFields = find.widgetWithText(TextFormField, 'e.g., Ram Kumar, Sita Devi');
      await tester.enterText(nameFields.first, 'Sita Devi');
      await tester.pump();

      // Add second person
      final addPersonBtn = find.text('+ Add Person');
      await tester.ensureVisible(addPersonBtn);
      await tester.tap(addPersonBtn);
      await tester.pumpAndSettle();

      // Enter name for second person
      final updatedNameFields = find.widgetWithText(TextFormField, 'e.g., Ram Kumar, Sita Devi');
      await tester.enterText(updatedNameFields.last, 'Geeta Devi');
      await tester.pump();

      // Upload photo for person 2 (index 1)
      final uploadBtn1 = find.byKey(const ValueKey('upload_photo_button_1'));
      await tester.ensureVisible(uploadBtn1);
      await tester.tap(uploadBtn1);
      await tester.pumpAndSettle();

      // Check person 2 has photo
      expect(find.text('second_person.png'), findsOneWidget);

      // Verify person 1 name still intact
      expect(find.text('Sita Devi'), findsWidgets);
      expect(find.text('Geeta Devi'), findsWidgets);
      // Person 1 still has upload photo button
      expect(find.byKey(const ValueKey('upload_photo_button_0')), findsOneWidget);
    });

    testWidgets('PollDetailPage renders multi-person cards and multi-question cards with independent actions', (tester) async {
      final multiPoll = Poll(
        id: 'poll-multi-widget',
        purpose: 'Elected Representative Comparison',
        category: 'GOVERNANCE',
        personName: 'Ramesh Kumar',
        question: 'First Question?',
        createdBy: 'user-1',
        status: 'ACTIVE',
        startTime: DateTime.now().subtract(const Duration(days: 2)),
        endTime: DateTime.now().add(const Duration(days: 180)), // 6 months (> 3 months)
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now(),
        likeCount: 20,
        dislikeCount: 5,
        totalVotes: 25,
        likePercentage: 80.0,
        dislikePercentage: 20.0,
        likeReasons: const [],
        dislikeReasons: const [],
        people: const [
          PollPerson(
            id: 'p1',
            name: 'Ramesh Kumar',
            role: 'Sarpanch',
            designation: 'Panchayat President',
            officeContext: 'Current Term 2021-2026',
          ),
          PollPerson(
            id: 'p2',
            name: 'Suresh Sharma',
            role: 'Social Worker',
            designation: 'Citizen Representative',
            officeContext: 'Candidate',
          ),
        ],
        questions: const [
          PollQuestion(
            id: 'q1',
            text: 'Rate Ramesh Kumar on road and school infrastructure',
            personId: 'p1',
            likeCount: 15,
            dislikeCount: 5,
            totalVotes: 20,
            likePercentage: 75.0,
            dislikePercentage: 25.0,
            likeReasons: [],
            dislikeReasons: [],
          ),
          PollQuestion(
            id: 'q2',
            text: 'Rate Suresh Sharma on civic transparency and advocacy',
            personId: 'p2',
            likeCount: 5,
            dislikeCount: 0,
            totalVotes: 5,
            likePercentage: 100.0,
            dislikePercentage: 0.0,
            likeReasons: [],
            dislikeReasons: [],
          ),
        ],
      );

      final multiRepo = FakePollRepository(multiPoll);
      final multiService = PollService(repository: multiRepo);

      await tester.pumpWidget(
        buildTestApp(
          PollDetailPage(
            pollId: multiPoll.id,
            initialPoll: multiPoll,
            pollService: multiService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Purpose banner
      expect(find.textContaining('Elected Representative Comparison'), findsOneWidget);

      // Both evaluated people rendered
      expect(find.text('Ramesh Kumar'), findsWidgets);
      expect(find.text('Suresh Sharma'), findsWidgets);
      expect(find.text('Current Term 2021-2026'), findsOneWidget);

      // Both questions rendered
      expect(find.text('Rate Ramesh Kumar on road and school infrastructure'), findsOneWidget);
      expect(find.text('Rate Suresh Sharma on civic transparency and advocacy'), findsOneWidget);

      // Independent question results and like percentages rendered
      expect(find.textContaining('75.0%'), findsOneWidget);
      expect(find.textContaining('100.0%'), findsOneWidget);
    });

    testWidgets('PollDetailPage renders complete independent profile card with work, public service, education, achievements, and verification', (tester) async {
      final profilePoll = Poll(
        id: 'poll-profile-full',
        personName: 'Vikram Singh',
        personRole: 'Sarpanch',
        placeName: 'Khandela Village',
        question: 'Rate Vikram Singh performance as Sarpanch',
        createdBy: 'user-creator',
        status: 'ACTIVE',
        startTime: DateTime.now().subtract(const Duration(days: 2)),
        endTime: DateTime.now().add(const Duration(days: 30)),
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now(),
        likeCount: 20,
        dislikeCount: 5,
        totalVotes: 25,
        likePercentage: 80.0,
        dislikePercentage: 20.0,
        likeReasons: const [],
        dislikeReasons: const [],
        people: [
          const PollPerson(
            id: 'p-vikram',
            name: 'Vikram Singh',
            role: 'Sarpanch',
            designation: 'Gram Pradhan',
            officeContext: 'Current Term (2021-2026)',
            placeName: 'Khandela Village',
            workBackground: '12 years in agricultural cooperative management',
            publicServiceHistory: 'Built solar street lights and paved village drainage system',
            education: 'M.A. Political Science, Rajasthan University',
            achievements: 'Clean Village Governance Award 2023',
            casteCommunity: 'Rajput',
            religion: 'Hinduism',
            bio: 'Dedicated grassroots representative working on local water security',
            sourceReference: 'State Election Commission Affidavit 2021',
            verificationStatus: 'DOCUMENTED',
          ),
        ],
      );

      final repo = FakePollRepository(profilePoll);
      final service = PollService(repository: repo);

      await tester.pumpWidget(
        buildTestApp(
          PollDetailPage(
            pollId: profilePoll.id,
            initialPoll: profilePoll,
            pollService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Person Profile Card rendered
      expect(find.byKey(const Key('person_profile_card_p-vikram')), findsOneWidget);
      expect(find.text('Vikram Singh'), findsWidgets);
      expect(find.text('Current Term (2021-2026)'), findsOneWidget);
      expect(find.text('Khandela Village'), findsWidgets);

      // Work background & public service rendered
      expect(find.textContaining('12 years in agricultural cooperative management'), findsOneWidget);
      expect(find.textContaining('Built solar street lights and paved village drainage system'), findsOneWidget);

      // Education & Achievements rendered
      expect(find.textContaining('M.A. Political Science, Rajasthan University'), findsOneWidget);
      expect(find.textContaining('Clean Village Governance Award 2023'), findsOneWidget);

      // Bio rendered
      expect(find.textContaining('Dedicated grassroots representative working on local water security'), findsOneWidget);

      // Declared community & religion rendered
      expect(find.textContaining('Rajput'), findsOneWidget);
      expect(find.textContaining('Hinduism'), findsOneWidget);

      // Verification status badge rendered
      expect(find.text('Documented'), findsOneWidget);
    });

    testWidgets('PollDetailPage displays neutral fallback and unverified badge when profile details are omitted', (tester) async {
      final minimalPoll = Poll(
        id: 'poll-profile-min',
        personName: 'Ravi Verma',
        personRole: 'Ward Member',
        question: 'Rate Ravi Verma performance',
        createdBy: 'user-creator',
        status: 'ACTIVE',
        startTime: DateTime.now().subtract(const Duration(days: 1)),
        endTime: DateTime.now().add(const Duration(days: 10)),
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now(),
        likeCount: 0,
        dislikeCount: 0,
        totalVotes: 0,
        likePercentage: 0.0,
        dislikePercentage: 0.0,
        likeReasons: const [],
        dislikeReasons: const [],
        people: [
          const PollPerson(
            id: 'p-ravi',
            name: 'Ravi Verma',
            verificationStatus: 'UNVERIFIED',
          ),
        ],
      );

      final repo = FakePollRepository(minimalPoll);
      final service = PollService(repository: repo);

      await tester.pumpWidget(
        buildTestApp(
          PollDetailPage(
            pollId: minimalPoll.id,
            initialPoll: minimalPoll,
            pollService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('person_profile_card_p-ravi')), findsOneWidget);
      expect(find.text('Ravi Verma'), findsWidgets);

      // Unverified badge rendered, not claiming verified
      expect(find.text('Unverified Details'), findsOneWidget);
      expect(find.text('Verified Profile'), findsNothing);

      // Neutral background fallback
      expect(find.text('Detailed background details not provided.'), findsOneWidget);
    });
  });
}
