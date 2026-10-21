import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_root/core/error/failures.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/models/place.dart';
import 'package:my_root/repositories/place_repository.dart';

class MockHttpClient extends http.BaseClient {
  http.Response Function(http.Request request)? handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final httpRequest = request as http.Request;
    final response = handler != null
        ? handler!(httpRequest)
        : http.Response('{"error": {"code": "NOT_FOUND", "message": "Not found"}}', 404);

    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  group('PlaceRepositoryImpl (Unit Tests)', () {
    late MockHttpClient mockHttp;
    late ApiClient apiClient;
    late PlaceRepositoryImpl repository;

    setUp(() {
      mockHttp = MockHttpClient();
      apiClient = ApiClient(client: mockHttp);
      repository = PlaceRepositoryImpl(client: apiClient);
    });

    test('getPlaces returns list of Places on 200 success', () async {
      mockHttp.handler = (req) {
        expect(req.url.path, '/places');
        expect(req.url.queryParameters['level'], 'STATE');
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'state-1',
                'level': 'STATE',
                'canonicalName': 'Rajasthan',
                'names': [{'language': 'en', 'name': 'Rajasthan'}],
                'parentId': 'country-1',
              }
            ],
            'pagination': {'page': 1, 'limit': 20, 'total': 1, 'pages': 1},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      };

      final result = await repository.getPlaces(level: 'STATE');
      expect(result.isSuccess, isTrue);
      expect(result.data, hasLength(1));
      expect(result.data!.first.canonicalName, 'Rajasthan');
      expect(result.data!.first.level, 'STATE');
    });

    test('getPlaceById parses Place with parentPath', () async {
      mockHttp.handler = (req) {
        expect(req.url.path, '/places/dist-1');
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'dist-1',
              'level': 'DISTRICT',
              'canonicalName': 'Jodhpur',
              'names': [{'language': 'en', 'name': 'Jodhpur'}],
              'parentId': 'state-1',
              'parentPath': [
                {'id': 'c-1', 'level': 'COUNTRY', 'canonicalName': 'India'},
                {'id': 'state-1', 'level': 'STATE', 'canonicalName': 'Rajasthan'},
              ],
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      };

      final result = await repository.getPlaceById('dist-1');
      expect(result.isSuccess, isTrue);
      expect(result.data!.canonicalName, 'Jodhpur');
      expect(result.data!.parentPath, hasLength(2));
      expect(result.data!.parentPath![0].canonicalName, 'India');
    });

    test('createPlace returns 409 ConflictFailure on duplicate', () async {
      mockHttp.handler = (req) {
        expect(req.method, 'POST');
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'CONFLICT',
              'message': 'A place with this canonical name already exists at this level',
            }
          }),
          409,
          headers: {'content-type': 'application/json'},
        );
      };

      final result = await repository.createPlace(
        level: 'STATE',
        canonicalName: 'Rajasthan',
        names: [const PlaceName(language: 'en', name: 'Rajasthan')],
        parentId: 'country-1',
      );

      expect(result.isSuccess, isFalse);
      expect(result.failure, isA<ConflictFailure>());
      expect(result.failure!.message, contains('already exists'));
    });

    test('deletePlace returns success on 200', () async {
      mockHttp.handler = (req) {
        expect(req.method, 'DELETE');
        expect(req.url.path, '/places/vil-1');
        return http.Response(
          jsonEncode({'message': 'Place deleted successfully'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      };

      final result = await repository.deletePlace('vil-1');
      expect(result.isSuccess, isTrue);
    });

    test('getChildren returns children list on 200', () async {
      mockHttp.handler = (req) {
        expect(req.url.path, '/places/state-1/children');
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'dist-1',
                'level': 'DISTRICT',
                'canonicalName': 'Jodhpur',
                'names': [{'language': 'en', 'name': 'Jodhpur'}],
                'parentId': 'state-1',
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      };

      final result = await repository.getChildren('state-1');
      expect(result.isSuccess, isTrue);
      expect(result.data, hasLength(1));
      expect(result.data!.first.id, 'dist-1');
    });
  });
}
