import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_root/app/app.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/repositories/auth_repository.dart';
import 'package:my_root/services/auth_service.dart';
import 'package:my_root/ui/pages/auth/login_page.dart';
import 'package:my_root/ui/pages/home/home_page.dart';
import 'package:my_root/ui/pages/polls/poll_detail_page.dart';

class MockAuthRepo implements AuthRepository {
  ApiClient get client => ApiClient();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthService extends AuthService {
  bool _mockAuthenticated = false;
  final bool _mockInitialized;

  FakeAuthService({bool authenticated = false, bool initialized = true})
      : _mockAuthenticated = authenticated,
        _mockInitialized = initialized,
        super(repository: MockAuthRepo());

  @override
  bool get isAuthenticated => _mockAuthenticated;

  @override
  bool get isInitialized => _mockInitialized;

  void setAuthenticated(bool value) {
    _mockAuthenticated = value;
    notifyListeners();
  }
}

void main() {
  const testPollId = '6ae01a9a957af1ad782cab84';

  late ApiClient mockApiClient;

  setUp(() {
    final mockHttp = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'data': {
            'id': testPollId,
            'personName': 'Ramesh Patel',
            'personRole': 'MLA',
            'question': 'Do you approve of Ramesh Patel?',
            'status': 'ACTIVE',
            'startTime': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
            'endTime': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
            'createdAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
            'createdBy': 'user-creator',
            'likeCount': 10,
            'dislikeCount': 2,
            'totalVotes': 12,
            'likePercentage': 83.3,
            'dislikePercentage': 16.7,
            'likeReasons': <Map<String, dynamic>>[],
            'dislikeReasons': <Map<String, dynamic>>[],
          }
        }),
        200,
      );
    });
    mockApiClient = ApiClient(client: mockHttp);
  });

  Widget buildApp(String? initialRoute, FakeAuthService authService) {
    return MyRootApp(
      initialRoute: initialRoute,
      authService: authService,
      apiClient: mockApiClient,
    );
  }

  group('Web Deep Link Routing and Authentication Policy Tests', () {
    testWidgets('authenticated user: direct navigation to /polls/:id mounts PollDetailPage with correct pollId', (tester) async {
      final authService = FakeAuthService(authenticated: true);

      await tester.pumpWidget(buildApp('/polls/$testPollId', authService));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final pollDetailFinder = find.byType(PollDetailPage);
      expect(pollDetailFinder, findsOneWidget);

      final pollDetailWidget = tester.widget<PollDetailPage>(pollDetailFinder);
      expect(pollDetailWidget.pollId, equals(testPollId));
    });

    testWidgets('authenticated user: trailing slash and query parameters preserve pollId on direct navigation', (tester) async {
      final authService = FakeAuthService(authenticated: true);

      await tester.pumpWidget(buildApp('/polls/$testPollId?utm_source=whatsapp', authService));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final pollDetailFinder = find.byType(PollDetailPage);
      expect(pollDetailFinder, findsOneWidget);

      final pollDetailWidget = tester.widget<PollDetailPage>(pollDetailFinder);
      expect(pollDetailWidget.pollId, equals(testPollId));
    });

    testWidgets('authenticated user: hash route fallback /#/polls/:id parses and preserves pollId', (tester) async {
      final authService = FakeAuthService(authenticated: true);

      await tester.pumpWidget(buildApp('/#/polls/$testPollId', authService));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final pollDetailFinder = find.byType(PollDetailPage);
      expect(pollDetailFinder, findsOneWidget);

      final pollDetailWidget = tester.widget<PollDetailPage>(pollDetailFinder);
      expect(pollDetailWidget.pollId, equals(testPollId));
    });

    testWidgets('unauthenticated visitor: direct navigation to /polls/:id strictly enforces login policy without exposing poll data', (tester) async {
      final unauthService = FakeAuthService(authenticated: false);

      await tester.pumpWidget(buildApp('/polls/$testPollId', unauthService));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Policy check: Poll data MUST NOT be displayed to unauthenticated visitors
      expect(find.byType(PollDetailPage), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('unauthenticated visitor: logging in preserves deep link and routes directly to target poll', (tester) async {
      final authService = FakeAuthService(authenticated: false);

      await tester.pumpWidget(buildApp('/polls/$testPollId', authService));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Initially blocked at login
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(PollDetailPage), findsNothing);

      // User completes login authentication
      authService.setAuthenticated(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Deep link must NOT be lost: lands directly on the target poll, NOT on HomePage
      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(HomePage), findsNothing);

      final pollDetailFinder = find.byType(PollDetailPage);
      expect(pollDetailFinder, findsOneWidget);

      final pollDetailWidget = tester.widget<PollDetailPage>(pollDetailFinder);
      expect(pollDetailWidget.pollId, equals(testPollId));
    });

    testWidgets('unauthenticated visitor to root: logging in lands on HomePage (no stale targetPollId)', (tester) async {
      final authService = FakeAuthService(authenticated: false);

      await tester.pumpWidget(buildApp('/', authService));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(LoginPage), findsOneWidget);

      authService.setAuthenticated(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(PollDetailPage), findsNothing);
    });
  });
}
