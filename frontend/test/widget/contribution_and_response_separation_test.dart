import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/claim.dart';
import 'package:my_root/models/user.dart';
import 'package:my_root/repositories/auth_repository.dart';
import 'package:my_root/repositories/community_repository.dart';
import 'package:my_root/services/auth_service.dart';
import 'package:my_root/services/community_service.dart';
import 'package:my_root/ui/pages/claims/claim_detail_page.dart';
import 'package:my_root/ui/pages/places/progressive_contribution_page.dart';

class MockSeparationHttpClient extends http.BaseClient {
  http.Response Function(http.Request request)? handler;
  final List<Map<String, dynamic>> recordedPayloads = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request) {
      if (request.body.isNotEmpty) {
        try {
          recordedPayloads.add(jsonDecode(request.body) as Map<String, dynamic>);
        } catch (_) {}
      }
      if (handler != null) {
        final res = handler!(request);
        return http.StreamedResponse(
          Stream.value(utf8.encode(res.body)),
          res.statusCode,
          headers: res.headers,
        );
      }
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'data': {}}))),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Requirement 4: Fresh Writing vs Responding Separation', () {
    late MockSeparationHttpClient mockHttp;
    late ApiClient apiClient;
    late CommunityRepository communityRepo;
    late CommunityService communityService;
    late AuthRepository authRepo;
    late AuthService authService;

    final testClaim = Claim(
      id: 'claim-existing-101',
      title: const LocalizedContent(original: 'Ancient Stepwell Heritage', language: 'en'),
      body: const LocalizedContent(
        original: 'A historic 16th-century stone stepwell served as the principal water reservoir.',
        language: 'en',
      ),
      category: 'HISTORICAL_RECORD',
      status: 'verified',
      locationId: 'place-mandore-1',
      submittedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
      evidenceCount: 2,
      isPublic: true,
      tags: ['stepwell', 'heritage'],
    );

    setUp(() {
      mockHttp = MockSeparationHttpClient();
      apiClient = ApiClient(client: mockHttp);
      communityRepo = CommunityRepositoryImpl(client: apiClient);
      communityService = CommunityService(repository: communityRepo);
      authRepo = AuthRepositoryImpl(client: apiClient);
      authService = AuthService(repository: authRepo);

      authService.setSession(
        AuthTokens(
          accessToken: 'test-token',
          refreshToken: 'test-refresh',
          user: User(
            id: 'user-writer-1',
            displayName: 'Active Contributor',
            role: 'CONTRIBUTOR',
            joinedAt: DateTime.parse('2025-01-01T00:00:00.000Z'),
            isIdentityVerified: true,
          ),
        ),
      );
    });

    Widget createTestApp(Widget child) {
      return MaterialApp(
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

    testWidgets('Fresh writing: ProgressiveContributionPage does NOT display response prompts or response chips',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          ProgressiveContributionPage(
            placeId: 'place-mandore-1',
            placeName: 'Mandore Village',
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fresh writing must NOT show "How would you like to respond?"
      expect(find.text('How would you like to respond?'), findsNothing);

      // Fresh writing must NOT show any of the 4 response ChoiceChips
      expect(find.byKey(const Key('chip_response_agree')), findsNothing);
      expect(find.byKey(const Key('chip_response_correction')), findsNothing);
      expect(find.byKey(const Key('chip_response_different_account')), findsNothing);
      expect(find.byKey(const Key('chip_response_dont_know')), findsNothing);
      expect(find.text('Agree & Expand'), findsNothing);
      expect(find.text('Suggest Correction'), findsNothing);
      expect(find.text('Different Account'), findsNothing);
      expect(find.text('I do not know / Want to learn'), findsNothing);

      // Fresh writing directly displays the writing field for new information
      expect(find.text('Your Knowledge / Information'), findsOneWidget);
      expect(find.byKey(const Key('contribution_answer_field')), findsOneWidget);
      expect(find.text('Save Draft'), findsOneWidget);
      expect(find.text('Submit for Review'), findsOneWidget);
    });

    testWidgets('Fresh writing submission does NOT include userAgreementStatus in creation payload',
        (tester) async {
      mockHttp.handler = (req) {
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'claim-draft-new',
              'title': {'original': 'Topic Question', 'language': 'en'},
              'body': {'original': 'Fresh unique community oral history shared by residents.', 'language': 'en'},
              'category': 'HISTORICAL_RECORD',
              'status': 'draft',
              'locationId': 'place-mandore-1',
              'submittedAt': DateTime.now().toIso8601String(),
              'evidenceCount': 0,
              'isPublic': false,
              'tags': [],
            }
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      };

      await tester.pumpWidget(
        createTestApp(
          ProgressiveContributionPage(
            placeId: 'place-mandore-1',
            placeName: 'Mandore Village',
            communityService: communityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter description text
      await tester.enterText(
        find.byKey(const Key('contribution_answer_field')),
        'Fresh unique community oral history shared by residents.',
      );
      await tester.pumpAndSettle();

      // Tap Save Draft
      await tester.tap(find.text('Save Draft'));
      await tester.pumpAndSettle();

      expect(mockHttp.recordedPayloads.isNotEmpty, isTrue);
      final lastPayload = mockHttp.recordedPayloads.last;

      // In fresh writing mode, userAgreementStatus is omitted
      expect(lastPayload.containsKey('userAgreementStatus'), isFalse);
    });

    testWidgets('Response mode in ProgressiveContributionPage displays existing record and 4 response chips',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          ProgressiveContributionPage(
            placeId: 'place-mandore-1',
            placeName: 'Mandore Village',
            communityService: communityService,
            targetClaim: testClaim,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Responding mode MUST show existing record and response options
      expect(find.text('Existing Community Record'), findsOneWidget);
      expect(find.text('Ancient Stepwell Heritage'), findsOneWidget);
      expect(find.text('How would you like to respond?'), findsOneWidget);

      // The 4 response options must be offered
      expect(find.byKey(const Key('chip_response_agree')), findsOneWidget);
      expect(find.byKey(const Key('chip_response_correction')), findsOneWidget);
      expect(find.byKey(const Key('chip_response_different_account')), findsOneWidget);
      expect(find.byKey(const Key('chip_response_dont_know')), findsOneWidget);

      // Tap "Suggest Correction"
      await tester.tap(find.byKey(const Key('chip_response_correction')));
      await tester.pumpAndSettle();

      final correctionChip = tester.widget<ChoiceChip>(find.byKey(const Key('chip_response_correction')));
      expect(correctionChip.selected, isTrue);
    });

    testWidgets('ClaimDetailPage provides "Respond to this Description" button opening response flow with 4 options',
        (tester) async {
      mockHttp.handler = (req) {
        if (req.url.path.contains('evidence')) {
          return http.Response(
            jsonEncode({'data': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.method == 'GET' && req.url.path.contains(testClaim.id)) {
          return http.Response(
            jsonEncode({
              'data': {
                'id': testClaim.id,
                'title': {'original': testClaim.title.original, 'language': 'en'},
                'body': {'original': testClaim.body.original, 'language': 'en'},
                'category': testClaim.category,
                'status': testClaim.status,
                'locationId': testClaim.locationId,
                'submittedAt': testClaim.submittedAt.toIso8601String(),
                'evidenceCount': testClaim.evidenceCount,
                'isPublic': testClaim.isPublic,
                'tags': testClaim.tags,
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'claim-resp-1',
              'title': {'original': 'Response Recorded', 'language': 'en'},
              'body': {'original': 'Added additional corroboration details.', 'language': 'en'},
              'category': 'HISTORICAL_RECORD',
              'status': 'draft',
              'locationId': 'place-mandore-1',
              'submittedAt': DateTime.now().toIso8601String(),
              'evidenceCount': 0,
              'isPublic': false,
              'tags': [],
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      };

      await tester.pumpWidget(
        createTestApp(
          ClaimDetailPage(
            claim: testClaim,
            communityService: communityService,
            authService: authService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "Respond to this Description" button is present
      final respondBtn = find.byKey(const Key('btn_respond_to_claim'));
      expect(respondBtn, findsOneWidget);
      expect(find.text('Respond to this Description'), findsOneWidget);

      // Tap button to open response sheet
      await tester.ensureVisible(respondBtn);
      await tester.tap(respondBtn);
      await tester.pumpAndSettle();

      // Verify Response Modal Sheet appears with target description context
      expect(find.text('Respond to Description'), findsOneWidget);
      expect(find.text('Responding to: "Ancient Stepwell Heritage"'), findsOneWidget);
      expect(find.text('How would you like to respond?'), findsOneWidget);

      // Verify 4 response chips in modal
      expect(find.byKey(const Key('chip_response_agree')), findsOneWidget);
      expect(find.byKey(const Key('chip_response_correction')), findsOneWidget);
      expect(find.byKey(const Key('chip_response_different_account')), findsOneWidget);
      expect(find.byKey(const Key('chip_response_dont_know')), findsOneWidget);

      // Enter response and submit
      await tester.enterText(
        find.byKey(const Key('field_response_text')),
        'Corroborating record: Construction date inscription confirmed by copper plate charter.',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_submit_response')));
      await tester.pumpAndSettle();

      // Assert submitted payload has userAgreementStatus: 'agreed'
      expect(mockHttp.recordedPayloads.isNotEmpty, isTrue);
      final lastPayload = mockHttp.recordedPayloads.last;
      expect(lastPayload['userAgreementStatus'], equals('agreed'));
    });
  });
}
