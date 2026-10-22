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
import 'package:my_root/ui/pages/auth/register_page.dart';

class FakeAuthRepository implements AuthRepository {
  bool loginShouldSucceed = true;
  bool registerShouldSucceed = true;

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
      AuthFailure(message: 'Invalid email or password'),
    );
  }

  @override
  Future<ApiResponse<RegisterResponse>> register(
      String displayName, String email, String password) async {
    if (registerShouldSucceed) {
      return const ApiResponse.success(
        RegisterResponse(message: 'Registration successful. Please verify your email.'),
      );
    }
    return const ApiResponse.failure(
      AuthFailure(message: 'Email already registered'),
    );
  }

  @override
  Future<ApiResponse<AuthTokens>> refreshToken(String refreshToken) async {
    return ApiResponse.success(
      AuthTokens(
        accessToken: 'new-token',
        refreshToken: 'new-refresh',
        user: User(
          id: 'u-1',
          displayName: 'Test',
          role: 'CONTRIBUTOR',
          joinedAt: DateTime.now(),
        ),
      ),
    );
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> logout({String? refreshToken}) async {
    return const ApiResponse.success({'message': 'Logged out'});
  }

  @override
  Future<ApiResponse<User>> getMe() async {
    return ApiResponse.success(
      User(
        id: 'u-1',
        displayName: 'Test',
        role: 'CONTRIBUTOR',
        joinedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<ApiResponse<User>> updateSelectedPlace(String? placeId) async {
    return ApiResponse.success(
      User(
        id: 'u-1',
        displayName: 'Test',
        role: 'CONTRIBUTOR',
        joinedAt: DateTime.now(),
        selectedPlaceId: placeId,
      ),
    );
  }

  @override
  Future<ApiResponse<User>> updateMatrbhoomiInterest({
    required String placeId,
    bool? knowsHistory,
    bool? wantsToLearn,
  }) async {
    return ApiResponse.success(
      User(
        id: 'u-1',
        displayName: 'Test',
        role: 'CONTRIBUTOR',
        joinedAt: DateTime.now(),
        matrbhoomiHistoryInterest: MatrbhoomiHistoryInterest(
          placeId: placeId,
          knowsHistory: knowsHistory,
          wantsToLearn: wantsToLearn,
          answeredAt: DateTime.now(),
        ),
      ),
    );
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
  group('LoginPage Widget Tests', () {
    late FakeAuthRepository fakeRepo;
    late AuthService authService;

    setUp(() {
      fakeRepo = FakeAuthRepository();
      authService = AuthService(repository: fakeRepo);
    });

    testWidgets('renders all input fields and submit button', (tester) async {
      await tester.pumpWidget(
        createTestApp(LoginPage(authService: authService)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Sign In'), findsWidgets);
      expect(find.text("Don't have an account? Register"), findsOneWidget);
    });

    testWidgets('shows validation errors when submitting empty form', (tester) async {
      await tester.pumpWidget(
        createTestApp(LoginPage(authService: authService)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });
  });

  group('RegisterPage Widget Tests', () {
    late FakeAuthRepository fakeRepo;
    late AuthService authService;

    setUp(() {
      fakeRepo = FakeAuthRepository();
      authService = AuthService(repository: fakeRepo);
    });

    testWidgets('renders name, email, password fields and register button',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(RegisterPage(authService: authService)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.text('Register'), findsWidgets);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('shows validation errors on empty submission', (tester) async {
      await tester.pumpWidget(
        createTestApp(RegisterPage(authService: authService)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your display name'), findsOneWidget);
    });
  });
}
