import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../models/auth_dtos.dart';
import '../models/user.dart';
import '../models/user_activity.dart';
import '../repositories/auth_repository.dart';
import 'secure_token_storage.dart';

class AuthService extends ChangeNotifier {
  final AuthRepository _repository;
  final SecureTokenStorage _tokenStorage;

  User? _currentUser;
  AuthTokens? _tokens;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isSessionPersistent = true;
  String? _persistenceWarning;
  Future<bool>? _restoreFuture;

  AuthService({
    required AuthRepository repository,
    SharedPreferences? prefs,
    SecureTokenStorage? tokenStorage,
  })  : _repository = repository,
        _tokenStorage = tokenStorage ?? SecureTokenStorage(prefs: prefs);

  AuthRepository get repository => _repository;
  SecureTokenStorage get tokenStorage => _tokenStorage;
  User? get currentUser => _currentUser;
  AuthTokens? get tokens => _tokens;
  bool get isAuthenticated => _tokens != null && _currentUser != null;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isSessionPersistent => _isSessionPersistent;
  String? get persistenceWarning => _persistenceWarning;

  /// Restores session using SecureTokenStorage (migrating from SharedPreferences if needed).
  /// Validates with getMe(), or refreshes if access token expired.
  /// Deduplicates concurrent restoration calls to prevent races.
  Future<bool> restoreSession() {
    if (_restoreFuture != null) {
      return _restoreFuture!;
    }
    _restoreFuture = _performRestoreSession();
    return _restoreFuture!;
  }

  Future<bool> _performRestoreSession() async {
    try {
      final session = await _tokenStorage.loadSession();
      final accessToken = session.accessToken;
      final refreshToken = session.refreshToken;

      if (accessToken == null && refreshToken == null) {
        _isInitialized = true;
        notifyListeners();
        return false;
      }

      if (_repository is AuthRepositoryImpl && accessToken != null) {
        (_repository as AuthRepositoryImpl).client.setAccessToken(accessToken);
      }

      // Validate session with server
      final meResult = await _repository.getMe();
      if (meResult.isSuccess && meResult.data != null) {
        _currentUser = meResult.data!;
        _tokens = AuthTokens(
          accessToken: accessToken ?? '',
          refreshToken: refreshToken ?? '',
          user: _currentUser!,
        );
        try {
          await _tokenStorage.saveSession(
            accessToken: _tokens!.accessToken,
            refreshToken: _tokens!.refreshToken,
            userData: jsonEncode(_currentUser!.toJson()),
          );
        } on SecureStorageUnavailableException catch (e) {
          _isSessionPersistent = false;
          _persistenceWarning = e.message;
          debugPrint('[AuthService] Warning: Session re-save failed: ${e.message}');
        }
        _isInitialized = true;
        notifyListeners();
        return true;
      }

      // If access token is expired/invalid, try refreshToken
      if (refreshToken != null && refreshToken.isNotEmpty) {
        final refreshResult = await _repository.refreshToken(refreshToken);
        if (refreshResult.isSuccess && refreshResult.data != null) {
          final newAccessToken = refreshResult.data!.accessToken;
          final newRefreshToken = refreshResult.data!.refreshToken;

          if (_repository is AuthRepositoryImpl) {
            (_repository as AuthRepositoryImpl).client.setAccessToken(newAccessToken);
          }

          final meAfterRefresh = await _repository.getMe();
          if (meAfterRefresh.isSuccess && meAfterRefresh.data != null) {
            _currentUser = meAfterRefresh.data!;
            _tokens = AuthTokens(
              accessToken: newAccessToken,
              refreshToken: newRefreshToken,
              user: _currentUser!,
            );
            try {
              await _tokenStorage.saveSession(
                accessToken: newAccessToken,
                refreshToken: newRefreshToken,
                userData: jsonEncode(_currentUser!.toJson()),
              );
            } on SecureStorageUnavailableException catch (e) {
              _isSessionPersistent = false;
              _persistenceWarning = e.message;
              debugPrint('[AuthService] Warning: Rotated session re-save failed: ${e.message}');
            }
            _isInitialized = true;
            notifyListeners();
            return true;
          }
        }
      }

      // Stale or expired token
      await _clearStoredSession();
      _isInitialized = true;
      notifyListeners();
      return false;
    } catch (_) {
      await _clearStoredSession();
      _isInitialized = true;
      notifyListeners();
      return false;
    } finally {
      _restoreFuture = null;
    }
  }

  Future<void> _clearStoredSession() async {
    try {
      await _tokenStorage.clearSession();
    } catch (_) {}
    _tokens = null;
    _currentUser = null;
    _isSessionPersistent = true;
    _persistenceWarning = null;
    if (_repository is AuthRepositoryImpl) {
      (_repository as AuthRepositoryImpl).client.setAccessToken(null);
    }
  }

  Future<ApiResponse<AuthTokens>> login(String email, String password) async {
    _restoreFuture = null;
    _isLoading = true;
    notifyListeners();

    final result = await _repository.login(email, password);
    _isLoading = false;

    if (result.isSuccess && result.data != null) {
      _tokens = result.data;
      _currentUser = result.data!.user;
      _isSessionPersistent = true;
      _persistenceWarning = null;

      try {
        await _tokenStorage.saveSession(
          accessToken: _tokens!.accessToken,
          refreshToken: _tokens!.refreshToken,
          userData: jsonEncode(_currentUser!.toJson()),
        );
      } on SecureStorageUnavailableException catch (e) {
        _isSessionPersistent = false;
        _persistenceWarning = e.message;
        debugPrint('[AuthService] Warning: Session persistence unavailable: ${e.message}');
      }
    }
    notifyListeners();
    return result;
  }

  Future<ApiResponse<RegisterResponse>> register(
      String displayName, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    final result = await _repository.register(displayName, email, password);
    _isLoading = false;
    notifyListeners();
    return result;
  }

  Future<void> logout() async {
    _restoreFuture = null;
    final currentRefreshToken = _tokens?.refreshToken;
    try {
      await _repository.logout(refreshToken: currentRefreshToken);
    } catch (_) {
      // Best-effort server revocation when server is unreachable
    } finally {
      await _clearStoredSession();
      notifyListeners();
    }
  }

  Future<void> setSession(AuthTokens tokens) async {
    _restoreFuture = null;
    _tokens = tokens;
    _currentUser = tokens.user;
    _isInitialized = true;
    _isSessionPersistent = true;
    _persistenceWarning = null;
    if (_repository is AuthRepositoryImpl) {
      (_repository as AuthRepositoryImpl).client.setAccessToken(tokens.accessToken);
    }
    try {
      await _tokenStorage.saveSession(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        userData: jsonEncode(tokens.user.toJson()),
      );
    } on SecureStorageUnavailableException catch (e) {
      _isSessionPersistent = false;
      _persistenceWarning = e.message;
      debugPrint('[AuthService] Warning: setSession persistence unavailable: ${e.message}');
    } catch (e) {
      debugPrint('[AuthService] Warning: setSession storage error: $e');
    }
    notifyListeners();
  }

  Future<ApiResponse<UserActivity>> getUserActivity() async {
    return _repository.getUserActivity();
  }

  Future<ApiResponse<User>> updateSelectedPlace(String? placeId) async {
    final result = await _repository.updateSelectedPlace(placeId);
    if (result.isSuccess && result.data != null) {
      _currentUser = result.data;
      if (_tokens != null && _currentUser != null) {
        _tokens = AuthTokens(
          accessToken: _tokens!.accessToken,
          refreshToken: _tokens!.refreshToken,
          user: _currentUser!,
        );
      }
      try {
        if (_tokens != null && _currentUser != null) {
          await _tokenStorage.saveSession(
            accessToken: _tokens!.accessToken,
            refreshToken: _tokens!.refreshToken,
            userData: jsonEncode(_currentUser!.toJson()),
          );
        }
      } on SecureStorageUnavailableException catch (e) {
        _isSessionPersistent = false;
        _persistenceWarning = e.message;
      }
      notifyListeners();
    }
    return result;
  }

  Future<ApiResponse<User>> updateMatrbhoomiInterest({
    required String placeId,
    bool? knowsHistory,
    bool? wantsToLearn,
  }) async {
    final result = await _repository.updateMatrbhoomiInterest(
      placeId: placeId,
      knowsHistory: knowsHistory,
      wantsToLearn: wantsToLearn,
    );
    if (result.isSuccess && result.data != null) {
      _currentUser = result.data;
      if (_tokens != null && _currentUser != null) {
        _tokens = AuthTokens(
          accessToken: _tokens!.accessToken,
          refreshToken: _tokens!.refreshToken,
          user: _currentUser!,
        );
      }
      try {
        if (_tokens != null && _currentUser != null) {
          await _tokenStorage.saveSession(
            accessToken: _tokens!.accessToken,
            refreshToken: _tokens!.refreshToken,
            userData: jsonEncode(_currentUser!.toJson()),
          );
        }
      } on SecureStorageUnavailableException catch (e) {
        _isSessionPersistent = false;
        _persistenceWarning = e.message;
      }
      notifyListeners();
    }
    return result;
  }

  Future<ApiResponse<List<PublicUser>>> getLatestUsers() async {
    return _repository.getLatestUsers();
  }
}
