import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_root/models/user.dart';
import 'package:my_root/services/auth_service.dart';
import 'package:my_root/repositories/auth_repository.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/auth_dtos.dart';
import 'package:my_root/models/user_activity.dart';
import 'package:my_root/ui/pages/profile/profile_page.dart';
import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MockAuditAuthRepo implements AuthRepository {
  final User user;
  MockAuditAuthRepo({required this.user});

  @override
  Future<ApiResponse<AuthTokens>> login(String email, String password) async =>
      ApiResponse.success(AuthTokens(accessToken: 'a', refreshToken: 'r', user: user));

  @override
  Future<ApiResponse<RegisterResponse>> register(String d, String e, String p) async =>
      const ApiResponse.success(RegisterResponse(message: 'ok'));

  @override
  Future<ApiResponse<AuthTokens>> refreshToken(String r) async =>
      ApiResponse.success(AuthTokens(accessToken: 'a', refreshToken: 'r', user: user));

  @override
  Future<ApiResponse<Map<String, dynamic>>> logout({String? refreshToken}) async =>
      const ApiResponse.success({'message': 'ok'});

  @override
  Future<ApiResponse<User>> getMe() async => ApiResponse.success(user);

  @override
  Future<ApiResponse<User>> updateSelectedPlace(String? placeId) async =>
      ApiResponse.success(user.copyWith(selectedPlaceId: placeId));

  @override
  Future<ApiResponse<User>> updateMatrbhoomiInterest({
    required String placeId,
    bool? knowsHistory,
    bool? wantsToLearn,
  }) async => ApiResponse.success(user);

  @override
  Future<ApiResponse<MessageResponse>> resendVerificationEmail(String email) async =>
      const ApiResponse.success(MessageResponse(message: 'ok'));

  @override
  Future<ApiResponse<MessageResponse>> verifyEmail(String token) async =>
      const ApiResponse.success(MessageResponse(message: 'ok'));

  @override
  Future<ApiResponse<MessageResponse>> requestPasswordReset(String email) async =>
      const ApiResponse.success(MessageResponse(message: 'ok'));

  @override
  Future<ApiResponse<MessageResponse>> resetPassword(String t, String n) async =>
      const ApiResponse.success(MessageResponse(message: 'ok'));

  @override
  Future<ApiResponse<UserActivity>> getUserActivity() async =>
      const ApiResponse.success(UserActivity(
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
      ));

  @override
  Future<ApiResponse<List<PublicUser>>> getLatestUsers() async =>
      const ApiResponse.success([]);
}

Widget buildTestProfile(AuthService authService) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('hi')],
    home: Scaffold(
      body: ProfilePage(authService: authService),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('Indigenous Classification Audit — Model Parsing', () {
    test('1. Current live API response without indigenousClassification parses to null', () {
      // Exact shape returned by backend GET /api/v1/auth/me or POST /api/v1/auth/login
      final liveApiResponseJson = {
        'id': 'usr-12345',
        'displayName': 'Ramesh Kumar',
        'role': 'CONTRIBUTOR',
        'joinedAt': '2026-03-01T10:00:00.000Z',
        'isIdentityVerified': true,
        'verifiedLocationId': 'loc-999',
        'selectedPlaceId': 'place-001',
      };

      final parsedUser = User.fromJson(liveApiResponseJson);

      expect(parsedUser.id, equals('usr-12345'));
      expect(parsedUser.displayName, equals('Ramesh Kumar'));
      expect(parsedUser.role, equals('CONTRIBUTOR'));
      // Verified: Field is null because the backend API does NOT supply it
      expect(parsedUser.indigenousClassification, isNull);
    });

    test('2. API response with future explicit indigenousClassification parses accurately', () {
      final indigenousJson = {
        'id': 'usr-12345',
        'displayName': 'Ramesh Kumar',
        'role': 'CONTRIBUTOR',
        'indigenousClassification': 'Indigenous',
      };
      final nonIndigenousJson = {
        'id': 'usr-67890',
        'displayName': 'Sunita Sharma',
        'role': 'CONTRIBUTOR',
        'indigenousClassification': 'Non-Indigenous',
      };

      expect(User.fromJson(indigenousJson).indigenousClassification, equals('Indigenous'));
      expect(User.fromJson(nonIndigenousJson).indigenousClassification, equals('Non-Indigenous'));
    });
  });

  group('Indigenous Classification Audit — UI Display & Fallback Isolation', () {
    testWidgets('3. When API does not supply classification, UI does not show fake Indigenous classification and keeps role intact', (tester) async {
      // Simulate live user where API does not provide indigenousClassification
      final liveUser = User(
        id: 'usr-12345',
        displayName: 'Ramesh Kumar',
        role: 'CONTRIBUTOR',
        joinedAt: DateTime.parse('2026-03-01T10:00:00.000Z'),
        isIdentityVerified: true,
        indigenousClassification: null, // As from live backend
      );

      final repo = MockAuditAuthRepo(user: liveUser);
      final authService = AuthService(repository: repo);
      authService.setSession(AuthTokens(accessToken: 'a', refreshToken: 'r', user: liveUser));

      await tester.pumpWidget(buildTestProfile(authService));
      await tester.pumpAndSettle();

      // Verified: "Indigenous" or "Non-Indigenous" text is NOT rendered
      expect(find.text('Indigenous'), findsNothing);
      expect(find.text('Non-Indigenous'), findsNothing);

      // Verified: System authorization role "CONTRIBUTOR" is displayed strictly as the role badge
      expect(find.text('CONTRIBUTOR'), findsOneWidget);
    });

    testWidgets('4. When classification is explicitly present, UI displays it without altering role', (tester) async {
      final classifiedUser = User(
        id: 'usr-12345',
        displayName: 'Ramesh Kumar',
        role: 'CONTRIBUTOR',
        joinedAt: DateTime.parse('2026-03-01T10:00:00.000Z'),
        isIdentityVerified: true,
        indigenousClassification: 'Indigenous',
      );

      final repo = MockAuditAuthRepo(user: classifiedUser);
      final authService = AuthService(repository: repo);
      authService.setSession(AuthTokens(accessToken: 'a', refreshToken: 'r', user: classifiedUser));

      await tester.pumpWidget(buildTestProfile(authService));
      await tester.pumpAndSettle();

      // Classification badge is rendered
      expect(find.text('Indigenous'), findsOneWidget);
      // System authorization role badge is preserved
      expect(find.text('CONTRIBUTOR'), findsOneWidget);
    });
  });
}
