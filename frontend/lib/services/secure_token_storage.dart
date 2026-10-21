import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoredSession {
  final String? accessToken;
  final String? refreshToken;
  final String? userData;

  const StoredSession({
    this.accessToken,
    this.refreshToken,
    this.userData,
  });

  bool get hasTokens =>
      (accessToken != null && accessToken!.isNotEmpty) ||
      (refreshToken != null && refreshToken!.isNotEmpty);
}

class SecureStorageUnavailableException implements Exception {
  final String message;
  const SecureStorageUnavailableException([
    this.message =
        'Secure storage (keyring/libsecret) is unavailable on this platform. '
        'Credentials cannot be stored unencrypted.',
  ]);

  @override
  String toString() => 'SecureStorageUnavailableException: $message';
}

class SecureTokenStorage {
  static const String keyAccessToken = 'auth_access_token';
  static const String keyRefreshToken = 'auth_refresh_token';
  static const String keyUserData = 'auth_user_data';

  final FlutterSecureStorage _secureStorage;
  final SharedPreferences? _prefs;
  final bool allowUnencryptedFallback;

  SecureTokenStorage({
    FlutterSecureStorage? secureStorage,
    SharedPreferences? prefs,
    this.allowUnencryptedFallback = kDebugMode,
  })  : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
              mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
              wOptions: WindowsOptions(),
              lOptions: LinuxOptions(),
            ),
        _prefs = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Transparently loads tokens:
  /// 1. Reads from FlutterSecureStorage first.
  /// 2. If absent from SecureStorage, checks legacy SharedPreferences.
  /// 3. If found in SharedPreferences, migrates to FlutterSecureStorage and deletes from SharedPreferences.
  /// 4. Gracefully handles platform exceptions (e.g. Linux libsecret missing or web issues).
  Future<StoredSession> loadSession() async {
    String? accessToken;
    String? refreshToken;
    String? userData;

    // 1. Attempt reading from SecureStorage
    try {
      accessToken = await _secureStorage.read(key: keyAccessToken);
      refreshToken = await _secureStorage.read(key: keyRefreshToken);
      userData = await _secureStorage.read(key: keyUserData);
    } catch (e) {
      debugPrint('[SecureTokenStorage] Warning: Failed to read from secure storage: $e');
    }

    // 2. If tokens already exist in SecureStorage, return them
    if (accessToken != null || refreshToken != null) {
      // Also ensure legacy SharedPreferences are cleaned up if leftover
      try {
        final prefs = await _getPrefs();
        if (prefs.containsKey(keyAccessToken) || prefs.containsKey(keyRefreshToken)) {
          await prefs.remove(keyAccessToken);
          await prefs.remove(keyRefreshToken);
          await prefs.remove(keyUserData);
        }
      } catch (_) {}

      return StoredSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        userData: userData,
      );
    }

    // 3. Fallback / Migration: Check legacy SharedPreferences
    try {
      final prefs = await _getPrefs();
      final legacyAccess = prefs.getString(keyAccessToken);
      final legacyRefresh = prefs.getString(keyRefreshToken);
      final legacyUser = prefs.getString(keyUserData);

      if (legacyAccess != null || legacyRefresh != null) {
        // Migrate to secure storage
        try {
          if (legacyAccess != null) {
            await _secureStorage.write(key: keyAccessToken, value: legacyAccess);
          }
          if (legacyRefresh != null) {
            await _secureStorage.write(key: keyRefreshToken, value: legacyRefresh);
          }
          if (legacyUser != null) {
            await _secureStorage.write(key: keyUserData, value: legacyUser);
          }
        } catch (e) {
          debugPrint('[SecureTokenStorage] Warning: Migration write failed: $e');
        }

        // Delete from legacy SharedPreferences immediately
        await prefs.remove(keyAccessToken);
        await prefs.remove(keyRefreshToken);
        await prefs.remove(keyUserData);

        return StoredSession(
          accessToken: legacyAccess,
          refreshToken: legacyRefresh,
          userData: legacyUser,
        );
      }
    } catch (e) {
      debugPrint('[SecureTokenStorage] Warning: Failed to check legacy prefs: $e');
    }

    return const StoredSession();
  }

  /// Saves session securely. Deletes legacy SharedPreferences.
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    String? userData,
  }) async {
    try {
      await _secureStorage.write(key: keyAccessToken, value: accessToken);
      await _secureStorage.write(key: keyRefreshToken, value: refreshToken);
      if (userData != null) {
        await _secureStorage.write(key: keyUserData, value: userData);
      } else {
        await _secureStorage.delete(key: keyUserData);
      }
    } catch (e) {
      debugPrint('[SecureTokenStorage] Warning: Secure write failed: $e');
      if (!allowUnencryptedFallback) {
        throw const SecureStorageUnavailableException(
          'Hardware/OS secure storage (e.g. libsecret/gnome-keyring on Linux) is unavailable. '
          'Saving credentials in unencrypted storage is prohibited in release mode.',
        );
      }
      // If secure storage fails (e.g. missing desktop keyring in debug/test mode), fallback to prefs
      try {
        final prefs = await _getPrefs();
        await prefs.setString(keyAccessToken, accessToken);
        await prefs.setString(keyRefreshToken, refreshToken);
        if (userData != null) {
          await prefs.setString(keyUserData, userData);
        }
        return;
      } catch (_) {}
    }

    // Always clear legacy prefs when secure write succeeded
    try {
      final prefs = await _getPrefs();
      await prefs.remove(keyAccessToken);
      await prefs.remove(keyRefreshToken);
      await prefs.remove(keyUserData);
    } catch (_) {}
  }

  /// Clears session from BOTH SecureStorage and SharedPreferences.
  Future<void> clearSession() async {
    try {
      await _secureStorage.delete(key: keyAccessToken);
      await _secureStorage.delete(key: keyRefreshToken);
      await _secureStorage.delete(key: keyUserData);
    } catch (e) {
      debugPrint('[SecureTokenStorage] Warning: Secure clear failed: $e');
    }

    try {
      final prefs = await _getPrefs();
      await prefs.remove(keyAccessToken);
      await prefs.remove(keyRefreshToken);
      await prefs.remove(keyUserData);
    } catch (_) {}
  }
}
