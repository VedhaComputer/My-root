import '../core/network/api_client.dart';
import '../models/auth_dtos.dart';
import '../models/user.dart';

import '../models/user_activity.dart';

abstract class AuthRepository {
  Future<ApiResponse<AuthTokens>> login(String email, String password);
  Future<ApiResponse<RegisterResponse>> register(
      String displayName, String email, String password);
  Future<ApiResponse<AuthTokens>> refreshToken(String refreshToken);
  Future<ApiResponse<Map<String, dynamic>>> logout({String? refreshToken});
  Future<ApiResponse<User>> getMe();
  Future<ApiResponse<UserActivity>> getUserActivity();
  Future<ApiResponse<User>> updateSelectedPlace(String? placeId);
  Future<ApiResponse<User>> updatePlaceRelationship({
    required String placeId,
    String? residenceType,
    required String indigenousClassification,
  });
  Future<ApiResponse<User>> updateMatrbhoomiInterest({
    required String placeId,
    bool? knowsHistory,
    bool? wantsToLearn,
  });
  Future<ApiResponse<List<PublicUser>>> getLatestUsers();
  Future<ApiResponse<MessageResponse>> resendVerificationEmail(String email);
  Future<ApiResponse<MessageResponse>> verifyEmail(String token);
  Future<ApiResponse<MessageResponse>> requestPasswordReset(String email);
  Future<ApiResponse<MessageResponse>> resetPassword(String token, String newPassword);
}

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _client;

  AuthRepositoryImpl({required ApiClient client}) : _client = client;

  ApiClient get client => _client;

  @override
  Future<ApiResponse<AuthTokens>> login(String email, String password) async {
    final req = LoginRequest(email: email, password: password);
    final response = await _client.post('/auth/login', req.toJson());

    if (response.isSuccess && response.data != null) {
      final tokens = AuthTokens.fromJson(response.data!);
      _client.setAccessToken(tokens.accessToken);
      return ApiResponse.success(tokens);
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<RegisterResponse>> register(
      String displayName, String email, String password) async {
    final req = RegisterRequest(
      displayName: displayName,
      email: email,
      password: password,
    );
    final response = await _client.post('/auth/register', req.toJson());

    if (response.isSuccess && response.data != null) {
      return ApiResponse.success(RegisterResponse.fromJson(response.data!));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<AuthTokens>> refreshToken(String refreshToken) async {
    final req = RefreshTokenRequest(refreshToken: refreshToken);
    final response = await _client.post('/auth/refresh', req.toJson());

    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      // Response returns { accessToken, refreshToken }
      final newAccessToken = data['accessToken'] as String;
      final newRefreshToken = (data['refreshToken'] as String?) ?? refreshToken;

      // Update api client token
      _client.setAccessToken(newAccessToken);

      // Return tokens with placeholder/retained user
      final tokens = AuthTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
        user: User(
          id: '',
          displayName: '',
          role: 'CONTRIBUTOR',
          joinedAt: _dummyDate,
        ),
      );
      return ApiResponse.success(tokens);
    }
    return ApiResponse.failure(response.failure);
  }

  static final DateTime _dummyDate = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<ApiResponse<Map<String, dynamic>>> logout({String? refreshToken}) async {
    final body = refreshToken != null ? {'refreshToken': refreshToken} : <String, dynamic>{};
    final response = await _client.post('/auth/logout', body);
    _client.setAccessToken(null);
    if (response.isSuccess) {
      return ApiResponse.success(response.data);
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<User>> getMe() async {
    final response = await _client.get('/auth/me');
    if (response.isSuccess && response.data != null) {
      final userData = response.data!['data'] as Map<String, dynamic>;
      return ApiResponse.success(User.fromJson(userData));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<UserActivity>> getUserActivity() async {
    final response = await _client.get('/auth/me/activity');
    if (response.isSuccess && response.data != null) {
      final activityData = response.data!['data'] as Map<String, dynamic>;
      return ApiResponse.success(UserActivity.fromJson(activityData));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<User>> updateSelectedPlace(String? placeId) async {
    final response = await _client.patch('/auth/me', {'selectedPlaceId': placeId});
    if (response.isSuccess && response.data != null) {
      final userData = response.data!['data'] as Map<String, dynamic>;
      return ApiResponse.success(User.fromJson(userData));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<User>> updatePlaceRelationship({
    required String placeId,
    String? residenceType,
    required String indigenousClassification,
  }) async {
    final payload = <String, dynamic>{
      'selectedPlaceId': placeId,
      'placeRelationship': {
        'placeId': placeId,
        if (residenceType != null) 'residenceType': residenceType,
        'indigenousClassification': indigenousClassification,
      },
    };
    final response = await _client.patch('/auth/me', payload);
    if (response.isSuccess && response.data != null) {
      final userData = response.data!['data'] as Map<String, dynamic>;
      return ApiResponse.success(User.fromJson(userData));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<User>> updateMatrbhoomiInterest({
    required String placeId,
    bool? knowsHistory,
    bool? wantsToLearn,
  }) async {
    final payload = <String, dynamic>{
      'matrbhoomiHistoryInterest': {
        'placeId': placeId,
        if (knowsHistory != null) 'knowsHistory': knowsHistory,
        if (wantsToLearn != null) 'wantsToLearn': wantsToLearn,
      },
    };
    final response = await _client.patch('/auth/me', payload);
    if (response.isSuccess && response.data != null) {
      final userData = response.data!['data'] as Map<String, dynamic>;
      return ApiResponse.success(User.fromJson(userData));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<List<PublicUser>>> getLatestUsers() async {
    final response = await _client.get('/users/latest');
    if (response.isSuccess && response.data != null) {
      final rawList = response.data!['data'];
      if (rawList is List) {
        final list = rawList
            .map((item) => PublicUser.fromJson(item as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(list);
      }
      return const ApiResponse.success([]);
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<MessageResponse>> resendVerificationEmail(String email) async {
    final req = ResendVerificationRequest(email: email);
    final response = await _client.post('/auth/verify-email/resend', req.toJson());
    if (response.isSuccess && response.data != null) {
      return ApiResponse.success(MessageResponse.fromJson(response.data!));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<MessageResponse>> verifyEmail(String token) async {
    final req = VerifyEmailRequest(token: token);
    final response = await _client.post('/auth/verify-email', req.toJson());
    if (response.isSuccess && response.data != null) {
      return ApiResponse.success(MessageResponse.fromJson(response.data!));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<MessageResponse>> requestPasswordReset(String email) async {
    final req = RequestPasswordResetRequest(email: email);
    final response = await _client.post('/auth/password-reset/request', req.toJson());
    if (response.isSuccess && response.data != null) {
      return ApiResponse.success(MessageResponse.fromJson(response.data!));
    }
    return ApiResponse.failure(response.failure);
  }

  @override
  Future<ApiResponse<MessageResponse>> resetPassword(String token, String newPassword) async {
    final req = ResetPasswordConfirmRequest(token: token, newPassword: newPassword);
    final response = await _client.post('/auth/password-reset/confirm', req.toJson());
    if (response.isSuccess && response.data != null) {
      return ApiResponse.success(MessageResponse.fromJson(response.data!));
    }
    return ApiResponse.failure(response.failure);
  }
}
