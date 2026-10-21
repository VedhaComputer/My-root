import 'package:flutter_test/flutter_test.dart';
import 'package:my_root/models/claim.dart';
import 'package:my_root/models/user.dart';
import 'package:my_root/models/place.dart';

void main() {
  group('Claim model', () {
    final sampleJson = {
      'id': 'claim-001',
      'title': {'original': 'Test Title', 'language': 'en'},
      'body': {'original': 'Test body content', 'language': 'en'},
      'category': 'FOLKLORE',
      'status': 'unverified',
      'locationId': 'place-001',
      'submittedAt': '2026-01-01T00:00:00.000Z',
      'evidenceCount': 2,
      'isPublic': true,
      'tags': ['village', 'tradition'],
    };

    test('parses from JSON', () {
      final claim = Claim.fromJson(sampleJson);
      expect(claim.id, 'claim-001');
      expect(claim.title.original, 'Test Title');
      expect(claim.category, 'FOLKLORE');
      expect(claim.status, 'unverified');
      expect(claim.evidenceCount, 2);
      expect(claim.tags, ['village', 'tradition']);
    });

    test('isFolklore is true for FOLKLORE category', () {
      final claim = Claim.fromJson(sampleJson);
      expect(claim.isFolklore, isTrue);
      expect(claim.isHistorical, isFalse);
    });

    test('isVerified is false for unverified status', () {
      final claim = Claim.fromJson(sampleJson);
      expect(claim.isVerified, isFalse);
    });

    test('isVerified is true for verified status', () {
      final json = {...sampleJson, 'status': 'verified', 'category': 'HISTORICAL_RECORD'};
      final claim = Claim.fromJson(json);
      expect(claim.isVerified, isTrue);
      expect(claim.isHistorical, isTrue);
    });

    test('parses with latestReview and submittedBy', () {
      final jsonWithReview = {
        ...sampleJson,
        'submittedBy': 'user-123',
        'latestReview': {
          'id': 'rev-001',
          'reviewerId': 'reviewer-456',
          'decisionStatus': 'verified',
          'reason': 'Corroborated by archaeological records and official survey data.',
          'timestamp': '2026-01-02T10:00:00.000Z',
          'reviewerNote': 'Clean documentary match',
        },
      };
      final claim = Claim.fromJson(jsonWithReview);
      expect(claim.submittedBy, 'user-123');
      expect(claim.latestReview, isNotNull);
      expect(claim.latestReview!.id, 'rev-001');
      expect(claim.latestReview!.reviewerId, 'reviewer-456');
      expect(claim.latestReview!.decisionStatus, 'verified');
      expect(claim.latestReview!.reason, contains('archaeological records'));
      expect(claim.latestReview!.reviewerNote, 'Clean documentary match');
    });
  });

  group('User model', () {
    test('parses from JSON and role checks work', () {
      final user = User.fromJson({
        'id': 'user-001',
        'displayName': 'Test User',
        'role': 'REVIEWER',
        'joinedAt': '2026-01-01T00:00:00.000Z',
      });
      expect(user.isReviewer, isTrue);
      expect(user.isModerator, isFalse);
      expect(user.isAdmin, isFalse);
      expect(user.isContributor, isTrue);
    });

    test('ADMIN has all permissions', () {
      final admin = User.fromJson({
        'id': 'admin-001',
        'displayName': 'Admin',
        'role': 'ADMIN',
        'joinedAt': '2026-01-01T00:00:00.000Z',
      });
      expect(admin.isAdmin, isTrue);
      expect(admin.isModerator, isTrue);
      expect(admin.isReviewer, isTrue);
      expect(admin.isContributor, isTrue);
    });

    test('parses selectedPlaceId from JSON and serializes to JSON', () {
      final user = User.fromJson({
        'id': 'u-place-1',
        'displayName': 'Ramesh',
        'role': 'CONTRIBUTOR',
        'joinedAt': '2026-01-01T00:00:00.000Z',
        'isIdentityVerified': true,
        'verifiedLocationId': 'loc-delhi-01',
        'selectedPlaceId': 'plc-mandore-01',
      });
      expect(user.selectedPlaceId, equals('plc-mandore-01'));
      expect(user.verifiedLocationId, equals('loc-delhi-01'));

      final json = user.toJson();
      expect(json['selectedPlaceId'], equals('plc-mandore-01'));
      expect(json['verifiedLocationId'], equals('loc-delhi-01'));

      final updated = user.copyWith(selectedPlaceId: 'plc-jaipur-02');
      expect(updated.selectedPlaceId, equals('plc-jaipur-02'));
      expect(updated.verifiedLocationId, equals('loc-delhi-01')); // untouched
    });

    test('parses matrbhoomiHistoryInterests list and getInterestForPlace works', () {
      final user = User.fromJson({
        'id': 'u-matrbhoomi-1',
        'displayName': 'Ramesh',
        'role': 'CONTRIBUTOR',
        'joinedAt': '2026-01-01T00:00:00.000Z',
        'matrbhoomiHistoryInterests': [
          {
            'placeId': 'plc-mandore-01',
            'knowsHistory': true,
            'wantsToLearn': false,
            'answeredAt': '2026-01-01T10:00:00.000Z',
          },
          {
            'placeId': 'plc-jaipur-02',
            'knowsHistory': false,
            'wantsToLearn': true,
            'answeredAt': '2026-01-02T10:00:00.000Z',
          },
        ],
      });

      expect(user.matrbhoomiHistoryInterests.length, 2);
      final int1 = user.getInterestForPlace('plc-mandore-01');
      expect(int1, isNotNull);
      expect(int1!.knowsHistory, isTrue);
      expect(int1.wantsToLearn, isFalse);

      final int2 = user.getInterestForPlace('plc-jaipur-02');
      expect(int2, isNotNull);
      expect(int2!.knowsHistory, isFalse);
      expect(int2.wantsToLearn, isTrue);

      final int3 = user.getInterestForPlace('plc-unknown');
      expect(int3, isNull);
    });
  });

  group('Place model', () {
    test('parses from JSON', () {
      final place = Place.fromJson({
        'id': 'place-001',
        'level': 'VILLAGE',
        'names': [
          {'language': 'en', 'name': 'Mandore'},
          {'language': 'hi', 'name': 'मांडोर'},
        ],
        'canonicalName': 'Mandore',
        'parentId': 'place-002',
      });
      expect(place.level, 'VILLAGE');
      expect(place.nameForLanguage('hi'), 'मांडोर');
      expect(place.nameForLanguage('en'), 'Mandore');
      expect(place.nameForLanguage('fr'), 'Mandore'); // Falls back to canonicalName
    });
  });
}
