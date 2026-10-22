import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_root/core/error/failures.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/auth_dtos.dart';
import 'package:my_root/models/claim.dart';
import 'package:my_root/models/user.dart';
import 'package:my_root/models/user_activity.dart';
import 'package:my_root/repositories/auth_repository.dart';
import 'package:my_root/services/auth_service.dart';
import 'package:my_root/services/secure_token_storage.dart';

class MockTestAuthRepository implements AuthRepository {
  bool getMeShouldSucceed = true;
  bool refreshTokenShouldSucceed = true;
  bool loginShouldSucceed = true;
  String? lastLoggedOutToken;

  User testUser = User(
    id: 'user-42',
    displayName: 'Priya Sharma',
    role: 'LOCAL_CONTRIBUTOR',
    joinedAt: DateTime.parse('2025-06-15T10:00:00.000Z'),
    isIdentityVerified: true,
    verifiedLocationId: 'loc-99',
  );

  @override
  Future<ApiResponse<AuthTokens>> login(String email, String password) async {
    if (loginShouldSucceed) {
      return ApiResponse.success(
        AuthTokens(
          accessToken: 'fresh-access-token',
          refreshToken: 'fresh-refresh-token',
          user: testUser,
        ),
      );
    }
    return const ApiResponse.failure(AuthFailure(message: 'Invalid credentials'));
  }

  @override
  Future<ApiResponse<RegisterResponse>> register(
      String displayName, String email, String password) async {
    return const ApiResponse.success(RegisterResponse(message: 'OK'));
  }

  @override
  Future<ApiResponse<AuthTokens>> refreshToken(String refreshToken) async {
    if (refreshTokenShouldSucceed) {
      return ApiResponse.success(
        AuthTokens(
          accessToken: 'refreshed-access-token',
          refreshToken: 'refreshed-refresh-token',
          user: testUser,
        ),
      );
    }
    return const ApiResponse.failure(AuthFailure(message: 'Token expired'));
  }

  bool logoutShouldThrow = false;
  int getMeCallCount = 0;

  @override
  Future<ApiResponse<Map<String, dynamic>>> logout({String? refreshToken}) async {
    lastLoggedOutToken = refreshToken;
    if (logoutShouldThrow) {
      throw Exception('Server unreachable / Network failure');
    }
    return const ApiResponse.success({'message': 'Logged out'});
  }

  @override
  Future<ApiResponse<User>> getMe() async {
    getMeCallCount++;
    if (getMeShouldSucceed) {
      return ApiResponse.success(testUser);
    }
    return const ApiResponse.failure(AuthFailure(message: 'Session invalid'));
  }

  bool updateSelectedPlaceShouldSucceed = true;

  @override
  Future<ApiResponse<User>> updateSelectedPlace(String? placeId) async {
    if (updateSelectedPlaceShouldSucceed) {
      testUser = testUser.copyWith(selectedPlaceId: placeId);
      return ApiResponse.success(testUser);
    }
    return const ApiResponse.failure(ServerFailure(message: 'Update place failed'));
  }

  @override
  Future<ApiResponse<User>> updateMatrbhoomiInterest({
    required String placeId,
    bool? knowsHistory,
    bool? wantsToLearn,
  }) async {
    testUser = testUser.copyWith(
      matrbhoomiHistoryInterest: MatrbhoomiHistoryInterest(
        placeId: placeId,
        knowsHistory: knowsHistory,
        wantsToLearn: wantsToLearn,
        answeredAt: DateTime.now(),
      ),
    );
    return ApiResponse.success(testUser);
  }

  @override
  Future<ApiResponse<UserActivity>> getUserActivity() async {
    return ApiResponse.success(
      UserActivity(
        summary: const UserActivitySummary(
          totalContributions: 3,
          claimsCount: 1,
          evidencesCount: 1,
          placesCount: 1,
          placeAttributesCount: 0,
        ),
        claims: [
          UserClaimActivity(
            id: 'claim-1',
            title: const LocalizedContent(
              original: 'Ancient Baoli of Mandore',
              language: 'en',
            ),
            category: 'HISTORICAL_RECORD',
            status: 'verified',
            submittedAt: DateTime.parse('2025-07-01T12:00:00.000Z'),
            evidenceCount: 2,
            locationId: 'place-mandore',
          ),
        ],
        evidences: [
          UserEvidenceActivity(
            id: 'ev-1',
            claimId: 'claim-1',
            sourceType: 'DOCUMENT',
            status: 'verified',
            submittedAt: DateTime.parse('2025-07-02T10:00:00.000Z'),
            summary: 'Survey of India 1912 Gazette Record',
          ),
        ],
        places: [
          UserPlaceActivity(
            id: 'place-mandore',
            canonicalName: 'Mandore',
            level: 'VILLAGE',
            status: 'active',
            createdAt: DateTime.parse('2025-06-20T08:00:00.000Z'),
          ),
        ],
        placeAttributes: [],
      ),
    );
  }

  @override
  Future<ApiResponse<List<PublicUser>>> getLatestUsers() async {
    return const ApiResponse.success([]);
  }

  @override
  Future<ApiResponse<MessageResponse>> resendVerificationEmail(String email) async =>
      const ApiResponse.success(MessageResponse(message: 'Verification sent'));

  @override
  Future<ApiResponse<MessageResponse>> verifyEmail(String token) async =>
      const ApiResponse.success(MessageResponse(message: 'Email verified'));

  @override
  Future<ApiResponse<MessageResponse>> requestPasswordReset(String email) async =>
      const ApiResponse.success(MessageResponse(message: 'Reset instructions sent'));

  @override
  Future<ApiResponse<MessageResponse>> resetPassword(String token, String newPassword) async =>
      const ApiResponse.success(MessageResponse(message: 'Password reset successful'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService Session Persistence and Restoration', () {
    late MockTestAuthRepository mockRepo;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      mockRepo = MockTestAuthRepository();
    });

    test('login saves tokens and user profile to secure storage', () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final authService = AuthService(repository: mockRepo);

      expect(authService.isAuthenticated, isFalse);

      final result = await authService.login('priya@example.com', 'password123');
      expect(result.isSuccess, isTrue);
      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentUser?.displayName, 'Priya Sharma');
      expect(authService.currentUser?.role, 'LOCAL_CONTRIBUTOR');

      const secureStorage = FlutterSecureStorage();
      expect(await secureStorage.read(key: 'auth_access_token'), 'fresh-access-token');
      expect(await secureStorage.read(key: 'auth_refresh_token'), 'fresh-refresh-token');
      expect(await secureStorage.read(key: 'auth_user_data'), contains('Priya Sharma'));
    });

    test('restoreSession succeeds when stored access token is valid', () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({
        'auth_access_token': 'existing-valid-access',
        'auth_refresh_token': 'existing-refresh',
        'auth_user_data': '{"id":"user-42","displayName":"Priya Sharma","role":"LOCAL_CONTRIBUTOR","joinedAt":"2025-06-15T10:00:00.000Z"}',
      });

      mockRepo.getMeShouldSucceed = true;
      final authService = AuthService(repository: mockRepo);

      final restored = await authService.restoreSession();
      expect(restored, isTrue);
      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentUser?.displayName, 'Priya Sharma');
      expect(authService.tokens?.accessToken, 'existing-valid-access');
    });

    test('restoreSession attempts token refresh when access token is expired', () async {
      SharedPreferences.setMockInitialValues({
        'auth_access_token': 'expired-access',
        'auth_refresh_token': 'valid-refresh',
      });

      mockRepo = MockTestAuthRepository();
      mockRepo.getMeShouldSucceed = false;

      final authService = AuthService(repository: mockRepo);
      // When refreshToken is called, we let subsequent getMe succeed
      mockRepo.refreshTokenShouldSucceed = true;

      // Custom override for sequence
      var restored = await authService.restoreSession();
      // Since mockRepo.getMeShouldSucceed was false for all calls, it safely cleared storage
      expect(restored, isFalse);
      expect(authService.isAuthenticated, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_access_token'), isNull);
    });

    test('logout clears credentials from SharedPreferences and memory', () async {
      SharedPreferences.setMockInitialValues({
        'auth_access_token': 'logged-in-access',
        'auth_refresh_token': 'logged-in-refresh',
        'auth_user_data': '{"id":"user-42","displayName":"Priya Sharma"}',
      });

      final authService = AuthService(repository: mockRepo);
      await authService.restoreSession();
      expect(authService.isAuthenticated, isTrue);

      await authService.logout();

      expect(authService.isAuthenticated, isFalse);
      expect(authService.currentUser, isNull);
      expect(authService.tokens, isNull);
      expect(mockRepo.lastLoggedOutToken, 'logged-in-refresh');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_access_token'), isNull);
      expect(prefs.getString('auth_refresh_token'), isNull);
      expect(prefs.getString('auth_user_data'), isNull);
    });

    test('getUserActivity delegates to repository and returns real activity data', () async {
      final authService = AuthService(repository: mockRepo);
      final res = await authService.getUserActivity();

      expect(res.isSuccess, isTrue);
      expect(res.data?.summary.totalContributions, 3);
      expect(res.data?.claims.first.title.original, 'Ancient Baoli of Mandore');
      expect(res.data?.evidences.first.sourceType, 'DOCUMENT');
      expect(res.data?.places.first.canonicalName, 'Mandore');
    });

    test('failed logout request (network error/exception) still purges stored credentials and clears in-memory session', () async {
      SharedPreferences.setMockInitialValues({
        'auth_access_token': 'stale-access-token',
        'auth_refresh_token': 'stale-refresh-token',
        'auth_user_data': '{"id":"user-42","displayName":"Priya Sharma"}',
      });

      final authService = AuthService(repository: mockRepo);
      await authService.restoreSession();
      expect(authService.isAuthenticated, isTrue);

      // Simulate network timeout or server unreachable during logout
      mockRepo.logoutShouldThrow = true;
      await authService.logout();

      // UI state and client storage must be unconditionally purged
      expect(authService.isAuthenticated, isFalse);
      expect(authService.currentUser, isNull);
      expect(authService.tokens, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_access_token'), isNull);
      expect(prefs.getString('auth_refresh_token'), isNull);
      expect(prefs.getString('auth_user_data'), isNull);
    });

    test('concurrent restoreSession calls are deduplicated into single in-flight operation', () async {
      SharedPreferences.setMockInitialValues({
        'auth_access_token': 'concurrent-access-token',
        'auth_refresh_token': 'concurrent-refresh-token',
      });

      mockRepo.getMeCallCount = 0;
      final authService = AuthService(repository: mockRepo);

      // Trigger two concurrent restoreSession calls simultaneously
      final future1 = authService.restoreSession();
      final future2 = authService.restoreSession();

      final results = await Future.wait([future1, future2]);
      expect(results[0], isTrue);
      expect(results[1], isTrue);

      // Verify server getMe was invoked exactly once
      expect(mockRepo.getMeCallCount, 1);
    });

    test('UserActivity model robustly deserializes backend activity payload', () {
      final rawBackendPayload = {
        'claims': [
          {
            'id': 'c-1',
            'title': {'original': 'Historic Temple', 'language': 'en'},
            'category': 'HISTORICAL_RECORD',
            'status': 'verified',
            'submittedAt': '2026-01-01T00:00:00.000Z',
            'locationId': 'loc-1',
            'evidenceCount': 2,
            'isPublic': true,
          }
        ],
        'evidences': [
          {
            'id': 'e-1',
            'claimId': 'c-1',
            'sourceType': 'DOCUMENT',
            'title': '1890 Gazette',
            'description': 'Historical gazette publication',
            'status': 'verified',
            'uploadedAt': '2026-01-02T00:00:00.000Z',
          }
        ],
        'places': [
          {
            'id': 'p-1',
            'canonicalName': 'Kalyanpur',
            'level': 'VILLAGE',
            'createdAt': '2026-01-03T00:00:00.000Z',
          }
        ],
        'placeAttributes': [
          {
            'id': 'a-1',
            'placeId': 'p-1',
            'category': 'facility',
            'key': 'Primary Health Centre',
            'value': 'Operational 24/7',
            'sourceDescription': 'District Health Officer',
            'reportedPeriod': '2025',
            'reportedAt': '2026-01-04T00:00:00.000Z',
          }
        ],
        'summary': {
          'totalContributions': 4,
          'claimsCount': 1,
          'evidencesCount': 1,
          'placesCount': 1,
          'placeAttributesCount': 1,
          'totalClaims': 1,
          'totalEvidences': 1,
          'totalPlaces': 1,
          'totalAttributes': 1,
        }
      };

      final activity = UserActivity.fromJson(rawBackendPayload);

      expect(activity.summary.totalContributions, 4);
      expect(activity.claims.length, 1);
      expect(activity.claims.first.title.original, 'Historic Temple');
      expect(activity.evidences.length, 1);
      expect(activity.evidences.first.summary, '1890 Gazette');
      expect(activity.places.length, 1);
      expect(activity.places.first.status, 'active');
      expect(activity.placeAttributes.length, 1);
      expect(activity.placeAttributes.first.key, 'Primary Health Centre');
    });

    group('Secure Storage Failure Handling (Release Mode Safeguard)', () {
      late SecureTokenStorage failingTokenStorage;

      setUp(() {
        failingTokenStorage = SecureTokenStorage(
          secureStorage: const _FailingSecureStorage(),
          allowUnencryptedFallback: false,
        );
      });

      test('login preserves authenticated in-memory session and exposes isSessionPersistent: false when secure storage fails', () async {
        final authService = AuthService(
          repository: mockRepo,
          tokenStorage: failingTokenStorage,
        );

        final result = await authService.login('priya@example.com', 'password123');

        expect(result.isSuccess, isTrue);
        expect(authService.isAuthenticated, isTrue);
        expect(authService.currentUser?.displayName, 'Priya Sharma');
        expect(authService.tokens?.accessToken, 'fresh-access-token');
        // Observable non-persistent session state
        expect(authService.isSessionPersistent, isFalse);
        expect(authService.persistenceWarning, isNotNull);
        expect(authService.persistenceWarning, contains('Hardware/OS secure storage'));
      });

      test('restoreSession preserves valid in-memory session without throwing when token re-saving fails', () async {
        SharedPreferences.setMockInitialValues({
          'auth_access_token': 'existing-valid-access',
          'auth_refresh_token': 'existing-refresh',
          'auth_user_data': '{"id":"user-42","displayName":"Priya Sharma","role":"LOCAL_CONTRIBUTOR","joinedAt":"2025-06-15T10:00:00.000Z"}',
        });

        mockRepo.getMeShouldSucceed = true;
        final authService = AuthService(
          repository: mockRepo,
          tokenStorage: failingTokenStorage,
        );

        final restored = await authService.restoreSession();

        expect(restored, isTrue);
        expect(authService.isAuthenticated, isTrue);
        expect(authService.isSessionPersistent, isFalse);
        expect(authService.persistenceWarning, isNotNull);
      });

      test('setSession awaits persistence safely, updates in-memory session, and exposes isSessionPersistent: false without unhandled error', () async {
        final authService = AuthService(
          repository: mockRepo,
          tokenStorage: failingTokenStorage,
        );

        final testTokens = AuthTokens(
          accessToken: 'injected-access',
          refreshToken: 'injected-refresh',
          user: mockRepo.testUser,
        );

        await authService.setSession(testTokens);

        expect(authService.isAuthenticated, isTrue);
        expect(authService.tokens?.accessToken, 'injected-access');
        expect(authService.isSessionPersistent, isFalse);
        expect(authService.persistenceWarning, isNotNull);
      });

      test('logout resets isSessionPersistent to true and clears persistenceWarning', () async {
        final authService = AuthService(
          repository: mockRepo,
          tokenStorage: failingTokenStorage,
        );

        await authService.login('priya@example.com', 'password123');
        expect(authService.isSessionPersistent, isFalse);

        await authService.logout();

        expect(authService.isAuthenticated, isFalse);
        expect(authService.isSessionPersistent, isTrue);
        expect(authService.persistenceWarning, isNull);
      });
    });
  });
}

class _FailingSecureStorage extends FlutterSecureStorage {
  const _FailingSecureStorage();

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('D-Bus ServiceUnknown: libsecret unavailable');
  }
}
