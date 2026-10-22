import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:my_root/core/constants.dart';
import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:my_root/core/network/api_client.dart';
import 'package:my_root/repositories/community_repository.dart';
import 'package:my_root/services/community_service.dart';
import 'package:my_root/ui/card/claim_card.dart';
import 'package:my_root/ui/pages/claims/category_claims_page.dart';
import 'package:my_root/ui/pages/claims/claim_detail_page.dart';
import 'package:my_root/ui/pages/places/progressive_contribution_page.dart';

class MockCategoryHttpClient extends http.BaseClient {
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
  group('CategoryClaimsPage Widget Tests', () {
    late MockCategoryHttpClient mockHttp;
    late ApiClient apiClient;
    late CommunityService communityService;

    setUp(() {
      mockHttp = MockCategoryHttpClient();
      apiClient = ApiClient(client: mockHttp);
      communityService = CommunityService(
        repository: CommunityRepositoryImpl(client: apiClient),
      );
    });

    Widget buildTestWidget({
      required String category,
      String placeId = 'place-amber-1',
      String placeName = 'Amber Fort',
    }) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('hi')],
        home: CategoryClaimsPage(
          placeId: placeId,
          placeName: placeName,
          category: category,
          communityService: communityService,
        ),
      );
    }

    testWidgets('renders Folklore notice banner prominently for FOLKLORE category', (tester) async {
      mockHttp.handler = (req) {
        return http.Response(
          jsonEncode({'data': [], 'pagination': {'page': 1, 'limit': 20, 'total': 0, 'pages': 0}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      };

      await tester.pumpWidget(buildTestWidget(category: ClaimCategory.folklore));
      await tester.pumpAndSettle();

      expect(find.textContaining('Folklore & Oral Tradition'), findsOneWidget);
      expect(find.textContaining('No Folklore / Proverb records for this location yet.'), findsOneWidget);
      expect(find.text('Contribute Folklore / Proverb'), findsOneWidget);
    });

    testWidgets('renders Public Opinion notice banner prominently for PUBLIC_OPINION category', (tester) async {
      mockHttp.handler = (req) {
        return http.Response(
          jsonEncode({'data': [], 'pagination': {'page': 1, 'limit': 20, 'total': 0, 'pages': 0}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      };

      await tester.pumpWidget(buildTestWidget(category: ClaimCategory.publicOpinion));
      await tester.pumpAndSettle();

      expect(find.textContaining('Community Opinions: Subjective viewpoints'), findsOneWidget);
      expect(find.textContaining('No Public Opinion records for this location yet.'), findsOneWidget);
    });

    testWidgets('displays list of claims for Historical Record category and tapping opens ClaimDetailPage', (tester) async {
      final sampleClaim = {
        'id': 'claim-hist-1',
        'title': {'original': 'Battle of Maonda and Mandholi', 'language': 'en'},
        'body': {'original': 'Historic 18th century armed conflict fought near Jaipur.', 'language': 'en'},
        'category': 'HISTORICAL_RECORD',
        'status': 'verified',
        'locationId': 'place-amber-1',
        'submittedAt': '2026-03-01T00:00:00.000Z',
        'evidenceCount': 3,
        'isPublic': true,
        'tags': ['war', 'rajasthan'],
      };

      mockHttp.handler = (req) {
        if ((req.url.path == '/api/v1/claims/claim-hist-1' || req.url.path == '/claims/claim-hist-1')) {
          return http.Response(
            jsonEncode({'data': sampleClaim}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path.contains('/evidence')) {
          return http.Response(
            jsonEncode({'data': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'data': [sampleClaim],
            'pagination': {'page': 1, 'limit': 20, 'total': 1, 'pages': 1},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      };

      await tester.pumpWidget(buildTestWidget(category: ClaimCategory.historicalRecord));
      await tester.pumpAndSettle();

      expect(find.byType(ClaimCard), findsOneWidget);
      expect(find.text('Battle of Maonda and Mandholi'), findsOneWidget);

      await tester.tap(find.byType(ClaimCard));
      await tester.pumpAndSettle();

      expect(find.byType(ClaimDetailPage), findsOneWidget);
    });

    testWidgets('tapping empty state contribute button navigates to ProgressiveContributionPage with mapped topic', (tester) async {
      mockHttp.handler = (req) {
        return http.Response(
          jsonEncode({'data': [], 'pagination': {'page': 1, 'limit': 20, 'total': 0, 'pages': 0}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      };

      await tester.pumpWidget(buildTestWidget(category: ClaimCategory.folklore));
      await tester.pumpAndSettle();

      final contributeBtn = find.text('Contribute Folklore / Proverb');
      expect(contributeBtn, findsOneWidget);
      await tester.tap(contributeBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ProgressiveContributionPage), findsOneWidget);
      final contribPage = tester.widget<ProgressiveContributionPage>(find.byType(ProgressiveContributionPage));
      expect(contribPage.placeId, equals('place-amber-1'));
      expect(contribPage.initialTopic, equals('culture'));
    });
  });
}
