import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/claim.dart';
import 'package:my_root/models/user.dart';
import 'package:my_root/repositories/auth_repository.dart';
import 'package:my_root/repositories/community_repository.dart';
import 'package:my_root/services/auth_service.dart';
import 'package:my_root/services/community_service.dart';
import 'package:my_root/ui/card/claim_card.dart';
import 'package:my_root/ui/pages/profile/my_drafts_page.dart';

class MockDraftAuthRepo extends Fake implements AuthRepository {
  final User testUser = User(
    id: 'user-draft-1',
    displayName: 'Test Author',
    role: 'CONTRIBUTOR',
    joinedAt: DateTime(2026, 1, 1),
  );

  @override
  Future<ApiResponse<AuthTokens>> login(String email, String password) async {
    return ApiResponse.success(
      AuthTokens(accessToken: 'acc', refreshToken: 'ref', user: testUser),
    );
  }

  @override
  Future<ApiResponse<User>> getMe() async => ApiResponse.success(testUser);
}

class MockDraftCommunityRepo extends Fake implements CommunityRepository {
  List<Claim> draftsToReturn = [];

  @override
  Future<ApiResponse<List<Claim>>> getMyDrafts(String userId) async {
    return ApiResponse.success(draftsToReturn);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MyDraftsPage Lifecycle and Rendering', () {
    testWidgets('renders safely on initial build without setState() or markNeedsBuild() during build exception', (tester) async {
      final authRepo = MockDraftAuthRepo();
      final authService = AuthService(repository: authRepo);
      await authService.login('author@example.com', 'password123');

      final communityRepo = MockDraftCommunityRepo();
      final communityService = CommunityService(repository: communityRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: MyDraftsPage(
            authService: authService,
            communityService: communityService,
          ),
        ),
      );

      // Verify no exceptions were thrown during build
      expect(tester.takeException(), isNull);

      // Process post frame callbacks and async loading
      await tester.pumpAndSettle();

      expect(find.byType(MyDraftsPage), findsOneWidget);
      expect(find.text('No Saved Drafts'), findsOneWidget);
    });

    testWidgets('displays drafts list when drafts are available', (tester) async {
      final authRepo = MockDraftAuthRepo();
      final authService = AuthService(repository: authRepo);
      await authService.login('author@example.com', 'password123');

      final communityRepo = MockDraftCommunityRepo();
      communityRepo.draftsToReturn = [
        Claim(
          id: 'draft-101',
          title: const LocalizedContent(original: 'Old Village Temple Origin', language: 'en'),
          body: const LocalizedContent(original: 'The ancient temple was established over 200 years ago.', language: 'en'),
          category: 'FOLKLORE',
          status: 'draft',
          locationId: 'PL_VIL_06_077_00382_060008',
          submittedAt: DateTime(2026, 3, 1),
          evidenceCount: 0,
          isPublic: true,
          tags: ['temple', 'heritage'],
        ),
      ];

      final communityService = CommunityService(repository: communityRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: MyDraftsPage(
            authService: authService,
            communityService: communityService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ClaimCard), findsOneWidget);
      expect(find.text('Old Village Temple Origin'), findsOneWidget);
    });

    testWidgets('shows unauthenticated notice if user is not logged in', (tester) async {
      final authRepo = MockDraftAuthRepo();
      final authService = AuthService(repository: authRepo);
      final communityRepo = MockDraftCommunityRepo();
      final communityService = CommunityService(repository: communityRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: MyDraftsPage(
            authService: authService,
            communityService: communityService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Authentication Required'), findsOneWidget);
    });
  });
}
