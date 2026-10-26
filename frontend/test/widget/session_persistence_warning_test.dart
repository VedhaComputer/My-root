import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/auth_dtos.dart';
import 'package:my_root/models/user.dart';
import 'package:my_root/models/user_activity.dart';
import 'package:my_root/repositories/auth_repository.dart';
import 'package:my_root/services/auth_service.dart';
import 'package:my_root/services/secure_token_storage.dart';
import 'package:my_root/ui/pages/home/home_page.dart';
import 'package:my_root/ui/widgets/session_persistence_warning_banner.dart';

class _MockAuthRepo implements AuthRepository {
  User user = User(
    id: 'user-warn-1',
    displayName: 'Vikram Singh',
    role: 'CONTRIBUTOR',
    joinedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
  );

  @override
  Future<ApiResponse<AuthTokens>> login(String email, String password) async {
    return ApiResponse.success(
      AuthTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-123',
        user: user,
      ),
    );
  }

  @override
  Future<ApiResponse<RegisterResponse>> register(
      String displayName, String email, String password) async {
    return const ApiResponse.success(RegisterResponse(message: 'Registered'));
  }

  @override
  Future<ApiResponse<AuthTokens>> refreshToken(String refreshToken) async {
    return ApiResponse.success(
      AuthTokens(
        accessToken: 'refreshed-access',
        refreshToken: 'refreshed-refresh',
        user: user,
      ),
    );
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> logout({String? refreshToken}) async {
    return const ApiResponse.success({'status': 'ok'});
  }

  @override
  Future<ApiResponse<User>> getMe() async {
    return ApiResponse.success(user);
  }

  @override
  Future<ApiResponse<User>> updateSelectedPlace(String? placeId) async {
    return ApiResponse.success(user);
  }

  @override
  Future<ApiResponse<User>> updatePlaceRelationship({
    required String placeId,
    String? residenceType,
    required String indigenousClassification,
  }) async {
    return ApiResponse.success(user);
  }

  @override
  Future<ApiResponse<User>> updateMatrbhoomiInterest({
    required String placeId,
    bool? knowsHistory,
    bool? wantsToLearn,
  }) async {
    return ApiResponse.success(user);
  }

  @override
  Future<ApiResponse<UserActivity>> getUserActivity() async {
    return const ApiResponse.success(
      UserActivity(
        summary: UserActivitySummary(
          totalContributions: 0,
          claimsCount: 0,
          evidencesCount: 0,
          placesCount: 0,
          placeAttributesCount: 0,
        ),
        claims: [],
        evidences: [],
        places: [],
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

class _FailingStorage extends FlutterSecureStorage {
  const _FailingStorage();

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
    throw Exception('Secure hardware storage unavailable');
  }
}

class _MockHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = jsonEncode({
      'data': [],
      'summary': {
        'totalContributions': 0,
        'claimsCount': 0,
        'evidencesCount': 0,
        'placesCount': 0,
        'placeAttributesCount': 0,
      },
    });
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

Widget _wrapWithLocalizations(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('hi')],
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionPersistenceWarningBanner Widget Tests', () {
    late _MockAuthRepo mockRepo;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      mockRepo = _MockAuthRepo();
    });

    testWidgets('does not display warning when user is unauthenticated',
        (tester) async {
      final authService = AuthService(repository: mockRepo);

      await tester.pumpWidget(
        _wrapWithLocalizations(
          SessionPersistenceWarningBanner(authService: authService),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('session_persistence_warning_banner')),
          findsNothing);
    });

    testWidgets(
        'does not display warning when authenticated with normal persistent storage',
        (tester) async {
      final authService = AuthService(repository: mockRepo);
      await authService.login('user@example.com', 'password123');
      expect(authService.isAuthenticated, isTrue);
      expect(authService.isSessionPersistent, isTrue);

      await tester.pumpWidget(
        _wrapWithLocalizations(
          SessionPersistenceWarningBanner(authService: authService),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('session_persistence_warning_banner')),
          findsNothing);
    });

    testWidgets(
        'displays clear accessible warning when authenticated but isSessionPersistent is false',
        (tester) async {
      final failingTokenStorage = SecureTokenStorage(
        secureStorage: const _FailingStorage(),
        allowUnencryptedFallback: false,
      );
      final authService = AuthService(
        repository: mockRepo,
        tokenStorage: failingTokenStorage,
      );

      await authService.login('user@example.com', 'password123');
      expect(authService.isAuthenticated, isTrue);
      expect(authService.isSessionPersistent, isFalse);

      await tester.pumpWidget(
        _wrapWithLocalizations(
          SessionPersistenceWarningBanner(authService: authService),
        ),
      );
      await tester.pump();

      // Banner is visible
      expect(find.byKey(const Key('session_persistence_warning_banner')),
          findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('Session Persistence Disabled'), findsOneWidget);
      expect(
        find.textContaining('Secure credential storage is unavailable'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Your session may be lost when the app closes'),
        findsOneWidget,
      );
    });

    testWidgets('dynamically appears and disappears when persistence state changes',
        (tester) async {
      final authService = AuthService(repository: mockRepo);
      // Log in normally (isSessionPersistent == true)
      await authService.login('user@example.com', 'password123');

      await tester.pumpWidget(
        _wrapWithLocalizations(
          SessionPersistenceWarningBanner(authService: authService),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('session_persistence_warning_banner')),
          findsNothing);

      // Now set session with failing token storage / unpersisted session
      final failingTokenStorage = SecureTokenStorage(
        secureStorage: const _FailingStorage(),
        allowUnencryptedFallback: false,
      );
      final failingAuthService = AuthService(
        repository: mockRepo,
        tokenStorage: failingTokenStorage,
      );
      await failingAuthService.setSession(
        AuthTokens(
          accessToken: 'token-unpersisted',
          refreshToken: 'refresh-unpersisted',
          user: mockRepo.user,
        ),
      );

      await tester.pumpWidget(
        _wrapWithLocalizations(
          SessionPersistenceWarningBanner(authService: failingAuthService),
        ),
      );
      await tester.pump();

      // Warning appears
      expect(find.byKey(const Key('session_persistence_warning_banner')),
          findsOneWidget);

      // Restore session to persistent
      final normalTokenStorage = SecureTokenStorage();
      final restoredAuthService = AuthService(
        repository: mockRepo,
        tokenStorage: normalTokenStorage,
      );
      await restoredAuthService.setSession(
        AuthTokens(
          accessToken: 'token-restored',
          refreshToken: 'refresh-restored',
          user: mockRepo.user,
        ),
      );

      await tester.pumpWidget(
        _wrapWithLocalizations(
          SessionPersistenceWarningBanner(authService: restoredAuthService),
        ),
      );
      await tester.pump();

      // Warning disappears
      expect(find.byKey(const Key('session_persistence_warning_banner')),
          findsNothing);
    });

    testWidgets('dismiss button hides warning and reset restores it on session change',
        (tester) async {
      final failingTokenStorage = SecureTokenStorage(
        secureStorage: const _FailingStorage(),
        allowUnencryptedFallback: false,
      );
      final authService = AuthService(
        repository: mockRepo,
        tokenStorage: failingTokenStorage,
      );
      await authService.login('user@example.com', 'password123');

      bool dismissedCallbackFired = false;
      await tester.pumpWidget(
        _wrapWithLocalizations(
          SessionPersistenceWarningBanner(
            authService: authService,
            onDismissed: () => dismissedCallbackFired = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('session_persistence_warning_banner')),
          findsOneWidget);

      // Tap dismiss button
      await tester.tap(find.byKey(const Key('dismiss_persistence_warning_button')));
      await tester.pump();

      expect(dismissedCallbackFired, isTrue);
      expect(find.byKey(const Key('session_persistence_warning_banner')),
          findsNothing);

      // When user logs out and logs in again (new session identity/failure), dismissal is reset
      await authService.logout();
      await tester.pump();
      expect(find.byKey(const Key('session_persistence_warning_banner')),
          findsNothing);

      await authService.login('user@example.com', 'password123');
      await tester.pump();

      // Banner reappears for new login
      expect(find.byKey(const Key('session_persistence_warning_banner')),
          findsOneWidget);
    });

    testWidgets('HomePage displays warning banner when persistence fails and clears on logout',
        (tester) async {
      final failingTokenStorage = SecureTokenStorage(
        secureStorage: const _FailingStorage(),
        allowUnencryptedFallback: false,
      );
      final mockClient = ApiClient(client: _MockHttpClient());
      final authService = AuthService(
        repository: mockRepo,
        tokenStorage: failingTokenStorage,
      );

      await authService.login('user@example.com', 'password123');
      expect(authService.isSessionPersistent, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('hi')],
          home: HomePage(
            authService: authService,
            apiClient: mockClient,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Banner should be visible on HomePage
      expect(find.byKey(const Key('session_persistence_warning_banner')),
          findsOneWidget);
      expect(
        find.textContaining('Secure credential storage is unavailable'),
        findsOneWidget,
      );

      // Calling logout removes warning and clears session
      await authService.logout();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('session_persistence_warning_banner')),
          findsNothing);
    });
  });
}
