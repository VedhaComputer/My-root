import 'package:flutter_test/flutter_test.dart';
import 'package:my_root/core/network/api_client.dart';

void main() {
  group('ApiClient.resolveUri', () {
    test('resolves unprefixed base and unprefixed path to canonical /api/v1', () {
      final uri = ApiClient.resolveUri('http://localhost:3001', '/auth/login');
      expect(uri.toString(), equals('http://localhost:3001/api/v1/auth/login'));
      expect(uri.path, equals('/api/v1/auth/login'));
    });

    test('resolves v1-prefixed base and unprefixed path to canonical /api/v1 without duplication', () {
      final uri = ApiClient.resolveUri('http://localhost:3001/api/v1', '/auth/login');
      expect(uri.toString(), equals('http://localhost:3001/api/v1/auth/login'));
      expect(uri.path, equals('/api/v1/auth/login'));
    });

    test('resolves unprefixed base and v1-prefixed path to canonical /api/v1', () {
      final uri = ApiClient.resolveUri('http://localhost:3001', '/api/v1/auth/login');
      expect(uri.toString(), equals('http://localhost:3001/api/v1/auth/login'));
      expect(uri.path, equals('/api/v1/auth/login'));
    });

    test('resolves v1-prefixed base and v1-prefixed path without double-prefixing', () {
      final uri = ApiClient.resolveUri('http://localhost:3001/api/v1', '/api/v1/auth/login');
      expect(uri.toString(), equals('http://localhost:3001/api/v1/auth/login'));
      expect(uri.path, equals('/api/v1/auth/login'));
    });

    test('handles trailing slashes on base and missing leading slashes on paths', () {
      // Base with trailing slash, path without leading slash
      final u1 = ApiClient.resolveUri('http://localhost:3001/', 'auth/login');
      expect(u1.toString(), equals('http://localhost:3001/api/v1/auth/login'));

      // Base with trailing slash, path with leading slash
      final u2 = ApiClient.resolveUri('http://localhost:3001/', '/auth/login');
      expect(u2.toString(), equals('http://localhost:3001/api/v1/auth/login'));

      // v1-prefixed base with trailing slash, path without leading slash
      final u3 = ApiClient.resolveUri('http://localhost:3001/api/v1/', 'auth/login');
      expect(u3.toString(), equals('http://localhost:3001/api/v1/auth/login'));

      // v1-prefixed base with trailing slash, path with leading slash
      final u4 = ApiClient.resolveUri('http://localhost:3001/api/v1/', '/auth/login');
      expect(u4.toString(), equals('http://localhost:3001/api/v1/auth/login'));

      // Base with trailing slash, v1-path without leading slash
      final u5 = ApiClient.resolveUri('http://localhost:3001/', 'api/v1/auth/login');
      expect(u5.toString(), equals('http://localhost:3001/api/v1/auth/login'));

      // v1-prefixed base with trailing slash, v1-path without leading slash
      final u6 = ApiClient.resolveUri('http://localhost:3001/api/v1/', 'api/v1/auth/login');
      expect(u6.toString(), equals('http://localhost:3001/api/v1/auth/login'));
    });

    test('exact path /api/v1 does not produce /api/v1/api/v1 or trailing slash', () {
      final u1 = ApiClient.resolveUri('http://localhost:3001', '/api/v1');
      expect(u1.toString(), equals('http://localhost:3001/api/v1'));
      expect(u1.path, equals('/api/v1'));

      final u2 = ApiClient.resolveUri('http://localhost:3001/api/v1', '/api/v1');
      expect(u2.toString(), equals('http://localhost:3001/api/v1'));
      expect(u2.path, equals('/api/v1'));

      final u3 = ApiClient.resolveUri('http://localhost:3001/', 'api/v1');
      expect(u3.toString(), equals('http://localhost:3001/api/v1'));
      expect(u3.path, equals('/api/v1'));

      final u4 = ApiClient.resolveUri('http://localhost:3001/api/v1/', 'api/v1');
      expect(u4.toString(), equals('http://localhost:3001/api/v1'));
      expect(u4.path, equals('/api/v1'));
    });

    test('/health remains at the intended root path across all base URL formats', () {
      final u1 = ApiClient.resolveUri('http://localhost:3001', '/health');
      expect(u1.toString(), equals('http://localhost:3001/health'));
      expect(u1.path, equals('/health'));

      final u2 = ApiClient.resolveUri('http://localhost:3001/', 'health');
      expect(u2.toString(), equals('http://localhost:3001/health'));
      expect(u2.path, equals('/health'));

      final u3 = ApiClient.resolveUri('http://localhost:3001/api/v1', '/health');
      expect(u3.toString(), equals('http://localhost:3001/health'));
      expect(u3.path, equals('/health'));

      final u4 = ApiClient.resolveUri('http://localhost:3001/api/v1/', 'health');
      expect(u4.toString(), equals('http://localhost:3001/health'));
      expect(u4.path, equals('/health'));
    });

    test('preserves query strings and does not percent-encode ? as %3F', () {
      final u1 = ApiClient.resolveUri('http://localhost:3001', '/claims?page=1&limit=20');
      expect(u1.toString(), equals('http://localhost:3001/api/v1/claims?page=1&limit=20'));
      expect(u1.path, equals('/api/v1/claims'));
      expect(u1.query, equals('page=1&limit=20'));

      final u2 = ApiClient.resolveUri('http://localhost:3001/api/v1', '/claims?page=1&limit=20');
      expect(u2.toString(), equals('http://localhost:3001/api/v1/claims?page=1&limit=20'));
      expect(u2.path, equals('/api/v1/claims'));
      expect(u2.query, equals('page=1&limit=20'));

      final u3 = ApiClient.resolveUri('http://localhost:3001/api/v1', '/api/v1/claims?page=1&limit=20');
      expect(u3.toString(), equals('http://localhost:3001/api/v1/claims?page=1&limit=20'));
      expect(u3.path, equals('/api/v1/claims'));
      expect(u3.query, equals('page=1&limit=20'));
    });

    test('supports production HTTPS base URLs without double prefixing', () {
      final u1 = ApiClient.resolveUri('https://api.myroot.org', '/auth/login');
      expect(u1.toString(), equals('https://api.myroot.org/api/v1/auth/login'));

      final u2 = ApiClient.resolveUri('https://api.myroot.org/api/v1', '/auth/login');
      expect(u2.toString(), equals('https://api.myroot.org/api/v1/auth/login'));

      final u3 = ApiClient.resolveUri('https://api.myroot.org/api/v1', '/api/v1/auth/login');
      expect(u3.toString(), equals('https://api.myroot.org/api/v1/auth/login'));

      final u4 = ApiClient.resolveUri('https://api.myroot.org/api/v1/', '/health');
      expect(u4.toString(), equals('https://api.myroot.org/health'));
    });
  });
}
