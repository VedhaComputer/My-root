import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/claim.dart';
import 'package:my_root/repositories/community_repository.dart';
import 'package:my_root/services/community_service.dart';
import 'package:my_root/ui/card/matrbhoomi_card.dart';

final testClaim = Claim(
  id: 'claim-matr-1',
  title: const LocalizedContent(original: 'Ancient Fort of Mandore', language: 'en'),
  body: const LocalizedContent(
    original: 'The ancient capital of Marwar with heroic heritage dating back to the 6th century.',
    language: 'en',
  ),
  category: 'HISTORICAL_RECORD',
  status: 'verified',
  locationId: 'place-mandore',
  submittedAt: DateTime(2025, 5, 10),
  evidenceCount: 3,
  isPublic: true,
  tags: const ['history', 'heritage'],
  sourceAttribution: 'State Archaeological Archives & Local Elder Memoirs',
  timePeriod: '6th Century CE',
  communityFeedbacks: const [],
);

class MockCommunityRepo implements CommunityRepository {
  String? lastFeedbackClaimId;
  String? lastPreviouslyKnown;
  String? lastAgreement;
  String? lastComment;
  String? lastKnowsAuthor;
  bool feedbackSuccess = true;

  @override
  Future<ApiResponse<Claim>> getClaimDetail(String id) async {
    return ApiResponse.success(testClaim);
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> submitHistoryFeedback({
    required String claimId,
    String? previouslyKnown,
    String? agreement,
    String? comment,
    String? knowsAuthor,
  }) async {
    lastFeedbackClaimId = claimId;
    lastPreviouslyKnown = previouslyKnown;
    lastAgreement = agreement;
    lastComment = comment;
    lastKnowsAuthor = knowsAuthor;

    if (feedbackSuccess) {
      return ApiResponse.success({
        'id': 'fb-1',
        'userId': 'test-user-1',
        'previouslyKnown': previouslyKnown,
        'agreement': agreement,
        'comment': comment,
        'knowsAuthor': knowsAuthor,
      });
    }
    return const ApiResponse.failure(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockCommunityRepo mockRepo;
  late CommunityService service;

  setUp(() {
    mockRepo = MockCommunityRepo();
    service = CommunityService(repository: mockRepo);
  });

  Widget buildTestWidget({required Claim claim, String? currentUserId}) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('hi')],
      home: Scaffold(
        body: SingleChildScrollView(
          child: MatrbhoomiCard(
            claim: claim,
            communityService: service,
            currentUserId: currentUserId,
          ),
        ),
      ),
    );
  }

  testWidgets('renders historical claim details and attribution badge correctly', (tester) async {
    await tester.pumpWidget(buildTestWidget(claim: testClaim));
    await tester.pumpAndSettle();

    expect(find.text('Ancient Fort of Mandore'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Verified Fact'), findsOneWidget);
    expect(find.textContaining('State Archaeological Archives'), findsOneWidget);
    expect(find.textContaining('[6th Century CE]'), findsOneWidget);
    expect(find.text('3 evidence'), findsOneWidget);
    expect(find.text('Share your perspective on this history'), findsOneWidget);
  });

  testWidgets('expands 4-question feedback form, selects answers, and submits successfully', (tester) async {
    await tester.pumpWidget(buildTestWidget(claim: testClaim, currentUserId: 'test-user-1'));
    await tester.pumpAndSettle();

    // Tap to expand feedback form
    await tester.tap(find.text('Share your perspective on this history'));
    await tester.pumpAndSettle();

    // Question 1: Known before
    expect(find.text('Did you already know about this?'), findsOneWidget);
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    // Question 2: Agree
    expect(find.text('Do you agree with this information?'), findsOneWidget);
    await tester.tap(find.text('Agree'));
    await tester.pumpAndSettle();

    // Question 3: Optional comment
    expect(find.text('Would you like to write something about this?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'My grandfather verified this account.');
    await tester.pumpAndSettle();

    // Question 4: Know Author
    expect(find.text('Do you know the author of this information?'), findsOneWidget);
    await tester.tap(find.text('Know by name'));
    await tester.pumpAndSettle();

    // Scroll and tap Submit
    await tester.ensureVisible(find.text('Submit Feedback'));
    await tester.tap(find.text('Submit Feedback'));
    await tester.pumpAndSettle();

    // Verify submission parameters
    expect(mockRepo.lastFeedbackClaimId, 'claim-matr-1');
    expect(mockRepo.lastPreviouslyKnown, 'yes');
    expect(mockRepo.lastAgreement, 'agree');
    expect(mockRepo.lastComment, 'My grandfather verified this account.');
    expect(mockRepo.lastKnowsAuthor, 'by_name');

    // Shows recorded feedback confirmation
    expect(find.text('You have submitted feedback for this record.'), findsOneWidget);
  });

  testWidgets('displays already submitted indicator when user has prior feedback', (tester) async {
    final claimWithFeedback = Claim(
      id: 'claim-matr-2',
      title: const LocalizedContent(original: 'Ancient Well', language: 'en'),
      body: const LocalizedContent(original: 'Heritage stepwell', language: 'en'),
      category: 'HISTORICAL_RECORD',
      status: 'verified',
      locationId: 'place-mandore',
      submittedAt: DateTime(2025, 5, 10),
      evidenceCount: 1,
      isPublic: true,
      tags: const [],
      communityFeedbacks: [
        HistoryFeedback(
          id: 'fb-existing',
          userId: 'test-user-1',
          previouslyKnown: 'yes',
          agreement: 'agree',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ],
    );

    await tester.pumpWidget(buildTestWidget(claim: claimWithFeedback, currentUserId: 'test-user-1'));
    await tester.pumpAndSettle();

    expect(find.text('You have submitted feedback for this record.'), findsOneWidget);
    expect(find.text('Share your perspective on this history'), findsNothing);
  });
}
