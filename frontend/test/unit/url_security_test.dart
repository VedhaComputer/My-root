import 'package:flutter_test/flutter_test.dart';
import 'package:my_root/core/constants.dart';

void main() {
  group('URL Security and HTTPS Enforcement', () {
    test('allows HTTPS URL in release mode', () {
      const url = 'https://api.myroot.org';
      final sanitized = AppConstants.sanitizeApiUrl(url, isRelease: true);
      expect(sanitized, equals('https://api.myroot.org'));
    });

    test('prohibits HTTP URL in release mode by throwing StateError', () {
      const insecureUrl = 'http://api.myroot.org';
      expect(
        () => AppConstants.sanitizeApiUrl(insecureUrl, isRelease: true),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Insecure HTTP base URL is strictly prohibited in release builds'),
        )),
      );
    });

    test('prohibits non-HTTPS schemes (ftp, javascript, etc.) in release mode', () {
      const ftpUrl = 'ftp://files.myroot.org';
      expect(
        () => AppConstants.sanitizeApiUrl(ftpUrl, isRelease: true),
        throwsA(isA<StateError>()),
      );
    });

    test('allows HTTP URL in non-release mode for local development', () {
      const devUrl = 'http://localhost:3001';
      final result = AppConstants.sanitizeApiUrl(devUrl, isRelease: false);
      expect(result, equals('http://localhost:3001'));
    });

    test('trims whitespace from URLs', () {
      const paddedUrl = '  https://api.myroot.com   ';
      final result = AppConstants.sanitizeApiUrl(paddedUrl, isRelease: true);
      expect(result, equals('https://api.myroot.com'));
    });
  });
}
