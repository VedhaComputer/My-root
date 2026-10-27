import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_root/core/error/failures.dart';
import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/auth_dtos.dart';
import 'package:my_root/models/user.dart';
import 'package:my_root/models/user_activity.dart';
import 'package:my_root/repositories/auth_repository.dart';
import 'package:my_root/services/auth_service.dart';
import 'package:my_root/ui/pages/auth/login_page.dart';
import 'package:my_root/ui/pages/auth/password_reset_page.dart';
import 'package:my_root/ui/pages/auth/verify_email_page.dart';

class MockRecoveryAuthRepo implements AuthRepository {
  bool verifyEmailShouldSucceed = true;
  bool resendEmailShouldSucceed = true;
  bool requestResetShouldSucceed = true;
  bool resetPasswordShouldSucceed = true;
  bool loginShouldSucceed = false;

  String? lastVerifyToken;
  String? lastResendEmail;
  String? lastResetRequestEmail;
  String? lastResetToken;
  String? lastResetPassword;

  @override
  Future<ApiResponse<MessageResponse>> verifyEmail(String token) async {
    lastVerifyToken = token;
    if (verifyEmailShouldSucceed) {
      return const ApiResponse.success(
        MessageResponse(message: 'Email verified successfully'),
      );
    }
    return const ApiResponse.failure(
      ValidationFailure(message: 'Invalid or expired verification token'),
    );
  }

  @override
  Future<ApiResponse<MessageResponse>> resendVerificationEmail(String email) async {
    lastResendEmail = email;
    if (resendEmailShouldSucceed) {
      return const ApiResponse.success(
        MessageResponse(
          message:
              'If an unverified account exists with this email, verification instructions have been sent.',
        ),
      );
    }
    return const ApiResponse.failure(
      ServerFailure(message: 'Failed to send verification email'),
    );
  }

  @override
  Future<ApiResponse<MessageResponse>> requestPasswordReset(String email) async {
    lastResetRequestEmail = email;
    if (requestResetShouldSucceed) {
      return const ApiResponse.success(
        MessageResponse(
          message:
              'If an account exists with this email, password reset instructions have been sent.',
        ),
      );
    }
    return const ApiResponse.failure(
      ServerFailure(message: 'Failed to process password reset request'),
    );
  }

  @override
  Future<ApiResponse<MessageResponse>> resetPassword(
      String token, String newPassword) async {
    lastResetToken = token;
    lastResetPassword = newPassword;
    if (resetPasswordShouldSucceed) {
      return const ApiResponse.success(
        MessageResponse(
          message: 'Password reset successful. Please log in with your new password.',
        ),
      );
    }
    return const ApiResponse.failure(
      ValidationFailure(message: 'Invalid or expired password reset token'),
    );
  }

  @override
  Future<ApiResponse<AuthTokens>> login(String email, String password) async {
    if (loginShouldSucceed) {
      return ApiResponse.success(
        AuthTokens(
          accessToken: 'token-123',
          refreshToken: 'refresh-123',
          user: User(
            id: 'u-1',
            displayName: 'Test User',
            role: 'CONTRIBUTOR',
            joinedAt: DateTime.now(),
          ),
        ),
      );
    }
    return const ApiResponse.failure(
      AuthFailure(message: 'Account is not verified. Please verify your email first.'),
    );
  }

  @override
  Future<ApiResponse<RegisterResponse>> register(
          String displayName, String email, String password) async =>
      const ApiResponse.success(RegisterResponse(message: 'Registered'));

  @override
  Future<ApiResponse<AuthTokens>> refreshToken(String refreshToken) async =>
      ApiResponse.success(
        AuthTokens(
          accessToken: 'new-acc',
          refreshToken: 'new-ref',
          user: User(
            id: 'u-1',
            displayName: 'Test User',
            role: 'CONTRIBUTOR',
            joinedAt: DateTime.now(),
          ),
        ),
      );

  @override
  Future<ApiResponse<Map<String, dynamic>>> logout({String? refreshToken}) async =>
      const ApiResponse.success({'message': 'Logged out'});

  @override
  Future<ApiResponse<User>> getMe() async => ApiResponse.success(
        User(
          id: 'u-1',
          displayName: 'Test User',
          role: 'CONTRIBUTOR',
          joinedAt: DateTime.now(),
        ),
      );

  @override
  Future<ApiResponse<User>> updateSelectedPlace(String? placeId) async =>
      ApiResponse.success(
        User(
          id: 'u-1',
          displayName: 'Test User',
          role: 'CONTRIBUTOR',
          joinedAt: DateTime.now(),
        ),
      );

  @override
  Future<ApiResponse<User>> updatePlaceRelationship({
    required String placeId,
    String? residenceType,
    required String indigenousClassification,
  }) async =>
      ApiResponse.success(
        User(
          id: 'u-1',
          displayName: 'Test User',
          role: 'CONTRIBUTOR',
          joinedAt: DateTime.now(),
        ),
      );

  @override
  Future<ApiResponse<User>> updateMatrbhoomiInterest({
    required String placeId,
    bool? knowsHistory,
    bool? wantsToLearn,
  }) async =>
      ApiResponse.success(
        User(
          id: 'u-1',
          displayName: 'Test User',
          role: 'CONTRIBUTOR',
          joinedAt: DateTime.now(),
        ),
      );

  @override
  Future<ApiResponse<UserActivity>> getUserActivity() async =>
      const ApiResponse.success(
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

  @override
  Future<ApiResponse<List<PublicUser>>> getLatestUsers() async =>
      const ApiResponse.success([]);
}

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

void main() {
  group('VerifyEmailPage Widget Tests', () {
    late MockRecoveryAuthRepo repo;
    late AuthService authService;

    setUp(() {
      repo = MockRecoveryAuthRepo();
      authService = AuthService(repository: repo);
    });

    testWidgets('renders all fields, headers, and action buttons', (tester) async {
      await tester.pumpWidget(
        createTestApp(VerifyEmailPage(authService: authService)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verify Email'), findsWidgets);
      expect(find.byType(TextFormField), findsNWidgets(2)); // token + email
      expect(find.widgetWithText(FilledButton, 'Verify Email'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Send Verification Link'), findsOneWidget);
    });

    testWidgets('validates empty token submission', (tester) async {
      await tester.pumpWidget(
        createTestApp(VerifyEmailPage(authService: authService)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Verify Email'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter the token from your email'), findsOneWidget);
      expect(repo.lastVerifyToken, isNull);
    });

    testWidgets('submits token successfully and renders success banner', (tester) async {
      bool successCallbackCalled = false;
      await tester.pumpWidget(
        createTestApp(
          VerifyEmailPage(
            authService: authService,
            onVerificationSuccess: () => successCallbackCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Verification Token'),
        'valid-token-xyz',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Verify Email'));
      await tester.pumpAndSettle();

      expect(repo.lastVerifyToken, 'valid-token-xyz');
      expect(find.text('Email verified successfully'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
      expect(successCallbackCalled, isTrue);
    });

    testWidgets('extracts clean token when full verification URL is pasted into token field',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          VerifyEmailPage(authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Verification Token'),
        'http://localhost:3000/verify-email?token=extracted-from-full-url-12345',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Verify Email'));
      await tester.pumpAndSettle();

      expect(repo.lastVerifyToken, 'extracted-from-full-url-12345');
      expect(find.text('Email verified successfully'), findsOneWidget);
    });

    testWidgets('extracts clean token when Flutter hash-route URL is pasted into token field',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          VerifyEmailPage(authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Verification Token'),
        'http://localhost:3000/#/verify-email?token=extracted-from-hash-url-67890',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Verify Email'));
      await tester.pumpAndSettle();

      expect(repo.lastVerifyToken, 'extracted-from-hash-url-67890');
      expect(find.text('Email verified successfully'), findsOneWidget);
    });

    testWidgets('auto-extracts and verifies when initialToken contains full verification URL',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          VerifyEmailPage(
            authService: authService,
            initialToken: 'http://localhost:3000/verify-email?token=auto-extracted-token-999',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.lastVerifyToken, 'auto-extracted-token-999');
      expect(find.text('Email verified successfully'), findsOneWidget);
    });

    testWidgets('auto-extracts and verifies when initialToken contains Flutter hash-route URL',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          VerifyEmailPage(
            authService: authService,
            initialToken: 'http://localhost:3000/#/verify-email?token=auto-extracted-hash-token-777',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.lastVerifyToken, 'auto-extracted-hash-token-777');
      expect(find.text('Email verified successfully'), findsOneWidget);
    });

    testWidgets('extracts clean token when console log line with label is pasted into token field',
        (tester) async {
      const hexToken = '0475de0b5e127768a8bed06d7eb999114aac90d7dd15cb0a9a0fdd83e07830ac';
      await tester.pumpWidget(
        createTestApp(
          VerifyEmailPage(authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Verification Token'),
        '[ConsoleMailer] [DEV ONLY] Verification token for raj04846@gmail.com: $hexToken',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Verify Email'));
      await tester.pumpAndSettle();

      expect(repo.lastVerifyToken, hexToken);
      expect(find.text('Email verified successfully'), findsOneWidget);
    });

    testWidgets('displays error message on token verification failure', (tester) async {
      repo.verifyEmailShouldSucceed = false;

      await tester.pumpWidget(
        createTestApp(VerifyEmailPage(authService: authService)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Verification Token'),
        'invalid-token',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Verify Email'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid or expired verification token'), findsOneWidget);
    });

    testWidgets('validates invalid email on resend request', (tester) async {
      await tester.pumpWidget(
        createTestApp(VerifyEmailPage(authService: authService)),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Send Verification Link'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Send Verification Link'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(repo.lastResendEmail, isNull);
    });

    testWidgets('submits resend request and renders anti-enumeration banner', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          VerifyEmailPage(
            authService: authService,
            initialEmail: 'user@example.com',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Send Verification Link'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Send Verification Link'));
      await tester.pumpAndSettle();

      expect(repo.lastResendEmail, 'user@example.com');
      expect(
        find.text(
            'If an unverified account exists with this email, verification instructions have been sent.'),
        findsOneWidget,
      );
    });
  });

  group('PasswordResetPage Widget Tests', () {
    late MockRecoveryAuthRepo repo;
    late AuthService authService;

    setUp(() {
      repo = MockRecoveryAuthRepo();
      authService = AuthService(repository: repo);
    });

    testWidgets('renders request and confirm forms', (tester) async {
      await tester.pumpWidget(
        createTestApp(PasswordResetPage(authService: authService)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsWidgets);
      expect(find.byType(TextFormField), findsNWidgets(3)); // email, token, new password
      expect(find.widgetWithText(FilledButton, 'Send Reset Link'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Set New Password'), findsOneWidget);
    });

    testWidgets('validates email on request reset', (tester) async {
      await tester.pumpWidget(
        createTestApp(PasswordResetPage(authService: authService)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(repo.lastResetRequestEmail, isNull);
    });

    testWidgets('submits reset request and displays anti-enumeration banner', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          PasswordResetPage(
            authService: authService,
            initialEmail: 'forgot@example.com',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Send Reset Link'));
      await tester.pumpAndSettle();

      expect(repo.lastResetRequestEmail, 'forgot@example.com');
      expect(
        find.text(
            'If an account exists with this email, password reset instructions have been sent.'),
        findsOneWidget,
      );
    });

    testWidgets('validates empty token and short password on confirm reset', (tester) async {
      await tester.pumpWidget(
        createTestApp(PasswordResetPage(authService: authService)),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Set New Password'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Set New Password'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter the token from your email'), findsOneWidget);
      expect(find.text('Password must be at least 8 characters'), findsOneWidget);
      expect(repo.lastResetToken, isNull);
    });

    testWidgets('toggles new password visibility icon and obscureText', (tester) async {
      await tester.pumpWidget(
        createTestApp(PasswordResetPage(authService: authService)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('submits confirm reset successfully and renders success banner', (tester) async {
      bool successCallbackCalled = false;
      await tester.pumpWidget(
        createTestApp(
          PasswordResetPage(
            authService: authService,
            onResetSuccess: () => successCallbackCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Reset Token'),
        'reset-token-777',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Password'),
        'SuperSecurePassword!9',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Set New Password'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Set New Password'));
      await tester.pumpAndSettle();

      expect(repo.lastResetToken, 'reset-token-777');
      expect(repo.lastResetPassword, 'SuperSecurePassword!9');
      expect(
        find.text('Password reset successful. Please log in with your new password.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
      expect(successCallbackCalled, isTrue);
    });

    testWidgets('displays error message on password reset confirm failure', (tester) async {
      repo.resetPasswordShouldSucceed = false;

      await tester.pumpWidget(
        createTestApp(PasswordResetPage(authService: authService)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Reset Token'),
        'bad-token',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Password'),
        'SuperSecurePassword!9',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Set New Password'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Set New Password'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid or expired password reset token'), findsOneWidget);
    });
  });

  group('LoginPage Recovery Navigation Tests', () {
    late MockRecoveryAuthRepo repo;
    late AuthService authService;

    setUp(() {
      repo = MockRecoveryAuthRepo();
      authService = AuthService(repository: repo);
    });

    testWidgets('navigates from LoginPage to PasswordResetPage on Forgot Password tap',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(LoginPage(authService: authService)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Forgot password?'), findsOneWidget);
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      expect(find.byType(PasswordResetPage), findsOneWidget);
    });

    testWidgets('navigates from LoginPage to VerifyEmailPage on Verify Email link tap',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(LoginPage(authService: authService)),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(TextButton, 'Verify Email'));
      await tester.tap(find.widgetWithText(TextButton, 'Verify Email'));
      await tester.pumpAndSettle();

      expect(find.byType(VerifyEmailPage), findsOneWidget);
    });

    testWidgets('displays recovery link in error container when login fails',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(LoginPage(authService: authService)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'),
        'unverified@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'Password123!',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(
        find.text('Account is not verified. Please verify your email first.'),
        findsOneWidget,
      );
      expect(
        find.text('Need to verify an unverified or legacy account?'),
        findsOneWidget,
      );

      await tester.tap(
        find.text('Need to verify an unverified or legacy account?'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VerifyEmailPage), findsOneWidget);
      expect(find.text('unverified@example.com'), findsOneWidget);
    });
  });
}
