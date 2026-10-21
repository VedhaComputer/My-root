import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_root/services/secure_token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureTokenStorage', () {
    late FlutterSecureStorage secureStorage;
    late SecureTokenStorage tokenStorage;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      secureStorage = const FlutterSecureStorage();
      tokenStorage = SecureTokenStorage(secureStorage: secureStorage);
    });

    test('saveSession stores tokens securely and purges legacy SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SecureTokenStorage.keyAccessToken, 'legacy-access');

      await tokenStorage.saveSession(
        accessToken: 'secure-access-123',
        refreshToken: 'secure-refresh-456',
        userData: '{"id":"u1"}',
      );

      // Verify written to FlutterSecureStorage
      expect(await secureStorage.read(key: SecureTokenStorage.keyAccessToken), equals('secure-access-123'));
      expect(await secureStorage.read(key: SecureTokenStorage.keyRefreshToken), equals('secure-refresh-456'));
      expect(await secureStorage.read(key: SecureTokenStorage.keyUserData), equals('{"id":"u1"}'));

      // Verify removed from legacy SharedPreferences
      expect(prefs.containsKey(SecureTokenStorage.keyAccessToken), isFalse);
    });

    test('loadSession reads directly from FlutterSecureStorage when present', () async {
      await secureStorage.write(key: SecureTokenStorage.keyAccessToken, value: 'token-alpha');
      await secureStorage.write(key: SecureTokenStorage.keyRefreshToken, value: 'token-beta');
      await secureStorage.write(key: SecureTokenStorage.keyUserData, value: '{"name":"Tester"}');

      final session = await tokenStorage.loadSession();

      expect(session.accessToken, equals('token-alpha'));
      expect(session.refreshToken, equals('token-beta'));
      expect(session.userData, equals('{"name":"Tester"}'));
      expect(session.hasTokens, isTrue);
    });

    test('loadSession transparently migrates tokens from SharedPreferences to FlutterSecureStorage', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SecureTokenStorage.keyAccessToken, 'migrated-access');
      await prefs.setString(SecureTokenStorage.keyRefreshToken, 'migrated-refresh');
      await prefs.setString(SecureTokenStorage.keyUserData, '{"email":"test@example.com"}');

      final session = await tokenStorage.loadSession();

      // Successfully returned
      expect(session.accessToken, equals('migrated-access'));
      expect(session.refreshToken, equals('migrated-refresh'));
      expect(session.userData, equals('{"email":"test@example.com"}'));

      // Migrated to FlutterSecureStorage
      expect(await secureStorage.read(key: SecureTokenStorage.keyAccessToken), equals('migrated-access'));
      expect(await secureStorage.read(key: SecureTokenStorage.keyRefreshToken), equals('migrated-refresh'));
      expect(await secureStorage.read(key: SecureTokenStorage.keyUserData), equals('{"email":"test@example.com"}'));

      // Cleaned up from SharedPreferences
      expect(prefs.containsKey(SecureTokenStorage.keyAccessToken), isFalse);
      expect(prefs.containsKey(SecureTokenStorage.keyRefreshToken), isFalse);
      expect(prefs.containsKey(SecureTokenStorage.keyUserData), isFalse);
    });

    test('clearSession purges data from both secure storage and SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SecureTokenStorage.keyAccessToken, 'pref-tok');
      await secureStorage.write(key: SecureTokenStorage.keyAccessToken, value: 'sec-tok');
      await secureStorage.write(key: SecureTokenStorage.keyRefreshToken, value: 'sec-ref');
      await secureStorage.write(key: SecureTokenStorage.keyUserData, value: '{"id":"1"}');

      await tokenStorage.clearSession();

      expect(await secureStorage.read(key: SecureTokenStorage.keyAccessToken), isNull);
      expect(await secureStorage.read(key: SecureTokenStorage.keyRefreshToken), isNull);
      expect(await secureStorage.read(key: SecureTokenStorage.keyUserData), isNull);
      expect(prefs.containsKey(SecureTokenStorage.keyAccessToken), isFalse);
    });

    test('loadSession returns empty session when no tokens exist in either storage', () async {
      final session = await tokenStorage.loadSession();

      expect(session.accessToken, isNull);
      expect(session.refreshToken, isNull);
      expect(session.userData, isNull);
      expect(session.hasTokens, isFalse);
    });

    test('saveSession fails closed with SecureStorageUnavailableException when allowUnencryptedFallback is false', () async {
      final failingTokenStorage = SecureTokenStorage(
        secureStorage: const _FailingSecureStorage(),
        allowUnencryptedFallback: false,
      );

      expect(
        () => failingTokenStorage.saveSession(
          accessToken: 'tok-1',
          refreshToken: 'tok-2',
        ),
        throwsA(isA<SecureStorageUnavailableException>()),
      );
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
    throw Exception('libsecret D-Bus ServiceUnknown');
  }
}
