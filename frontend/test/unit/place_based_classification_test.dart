import 'package:flutter_test/flutter_test.dart';
import 'package:my_root/models/user.dart';

void main() {
  group('UserPlaceRelationship and Place-Based Classification Unit Tests', () {
    test('UserPlaceRelationship serializes and deserializes correctly', () {
      final now = DateTime.parse('2026-10-24T10:00:00.000Z');
      final rel = UserPlaceRelationship(
        placeId: 'place-jaipur-1',
        residenceType: 'Permanent',
        indigenousClassification: 'Indigenous',
        createdAt: now,
      );

      final json = rel.toJson();
      expect(json['placeId'], 'place-jaipur-1');
      expect(json['residenceType'], 'Permanent');
      expect(json['indigenousClassification'], 'Indigenous');
      expect(json['createdAt'], now.toIso8601String());

      final fromJson = UserPlaceRelationship.fromJson(json);
      expect(fromJson.placeId, rel.placeId);
      expect(fromJson.residenceType, rel.residenceType);
      expect(fromJson.indigenousClassification, rel.indigenousClassification);
      expect(fromJson.createdAt, rel.createdAt);
    });

    test('User.fromJson resolves indigenousClassification for selectedPlaceId dynamically', () {
      final json = {
        'id': 'user-1',
        'displayName': 'Aarav Sharma',
        'role': 'CONTRIBUTOR',
        'joinedAt': '2026-01-01T00:00:00.000Z',
        'selectedPlaceId': 'place-village-1',
        'placeRelationships': [
          {
            'placeId': 'place-village-1',
            'residenceType': 'Permanent',
            'indigenousClassification': 'Indigenous',
            'createdAt': '2026-01-01T00:00:00.000Z',
          },
          {
            'placeId': 'place-city-2',
            'residenceType': 'Temporary',
            'indigenousClassification': 'Non-Indigenous',
            'createdAt': '2026-02-01T00:00:00.000Z',
          },
        ],
      };

      final user = User.fromJson(json);
      expect(user.selectedPlaceId, 'place-village-1');
      expect(user.indigenousClassification, 'Indigenous');
      expect(user.getClassificationForPlace('place-village-1'), 'Indigenous');
      expect(user.getClassificationForPlace('place-city-2'), 'Non-Indigenous');
      expect(user.getRelationshipForPlace('place-village-1')?.residenceType, 'Permanent');
      expect(user.getRelationshipForPlace('place-city-2')?.residenceType, 'Temporary');
      expect(user.getRelationshipForPlace('place-unknown'), isNull);
    });

    test('Switching selectedPlaceId via copyWith updates classification and does NOT retain stale data', () {
      final user = User(
        id: 'user-1',
        displayName: 'Aarav Sharma',
        role: 'CONTRIBUTOR',
        joinedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
        selectedPlaceId: 'place-village-1',
        indigenousClassification: 'Indigenous',
        placeRelationships: [
          UserPlaceRelationship(
            placeId: 'place-village-1',
            residenceType: 'Permanent',
            indigenousClassification: 'Indigenous',
            createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
          ),
          UserPlaceRelationship(
            placeId: 'place-city-2',
            residenceType: 'Temporary',
            indigenousClassification: 'Non-Indigenous',
            createdAt: DateTime.parse('2026-02-01T00:00:00.000Z'),
          ),
          UserPlaceRelationship(
            placeId: 'place-unclassified-3',
            residenceType: 'Temporary',
            indigenousClassification: null,
            createdAt: DateTime.parse('2026-03-01T00:00:00.000Z'),
          ),
        ],
      );

      // Verify initial state
      expect(user.selectedPlaceId, 'place-village-1');
      expect(user.indigenousClassification, 'Indigenous');

      // Switch to place-city-2 -> classification becomes Non-Indigenous
      final switchedUser = user.copyWith(selectedPlaceId: 'place-city-2');
      expect(switchedUser.selectedPlaceId, 'place-city-2');
      expect(switchedUser.indigenousClassification, 'Non-Indigenous');

      // Switch to unclassified place -> classification becomes null (no stale Non-Indigenous retained)
      final unclassifiedUser = switchedUser.copyWith(selectedPlaceId: 'place-unclassified-3');
      expect(unclassifiedUser.selectedPlaceId, 'place-unclassified-3');
      expect(unclassifiedUser.indigenousClassification, isNull);

      // Clear selected place (Guest / View-only mode) -> classification becomes null
      final guestUser = unclassifiedUser.copyWith(clearSelectedPlace: true);
      expect(guestUser.selectedPlaceId, isNull);
      expect(guestUser.indigenousClassification, isNull);
    });

    test('Equal permissions: Indigenous and Non-Indigenous users have identical role authorization', () {
      final indigenousUser = User(
        id: 'u-indigenous',
        displayName: 'Indigenous Contributor',
        role: 'CONTRIBUTOR',
        joinedAt: DateTime.now(),
        selectedPlaceId: 'place-1',
        indigenousClassification: 'Indigenous',
      );

      final nonIndigenousUser = User(
        id: 'u-non-indigenous',
        displayName: 'Non-Indigenous Contributor',
        role: 'CONTRIBUTOR',
        joinedAt: DateTime.now(),
        selectedPlaceId: 'place-1',
        indigenousClassification: 'Non-Indigenous',
      );

      // Role authorization is completely separate from classification
      expect(indigenousUser.isContributor, isTrue);
      expect(nonIndigenousUser.isContributor, isTrue);
      expect(indigenousUser.role, nonIndigenousUser.role);
      expect(indigenousUser.isReviewer, isFalse);
      expect(nonIndigenousUser.isReviewer, isFalse);
      expect(indigenousUser.isAdmin, isFalse);
      expect(nonIndigenousUser.isAdmin, isFalse);
    });

    test('hasClassificationForPlace and hasExplicitClassification validate explicit choice', () {
      final user = User(
        id: 'user-val',
        displayName: 'Validation User',
        role: 'CONTRIBUTOR',
        joinedAt: DateTime.now(),
        placeRelationships: [
          UserPlaceRelationship(
            placeId: 'p-indigenous',
            indigenousClassification: 'Indigenous',
            createdAt: DateTime.now(),
          ),
          UserPlaceRelationship(
            placeId: 'p-non-indigenous',
            indigenousClassification: 'Non-Indigenous',
            createdAt: DateTime.now(),
          ),
          UserPlaceRelationship(
            placeId: 'p-unclassified',
            indigenousClassification: null,
            createdAt: DateTime.now(),
          ),
        ],
      );

      expect(user.hasClassificationForPlace('p-indigenous'), isTrue);
      expect(user.hasClassificationForPlace('p-non-indigenous'), isTrue);
      expect(user.hasClassificationForPlace('p-unclassified'), isFalse);
      expect(user.hasClassificationForPlace('p-unknown'), isFalse);

      expect(user.placeRelationships[0].hasExplicitClassification, isTrue);
      expect(user.placeRelationships[1].hasExplicitClassification, isTrue);
      expect(user.placeRelationships[2].hasExplicitClassification, isFalse);
    });
  });
}
