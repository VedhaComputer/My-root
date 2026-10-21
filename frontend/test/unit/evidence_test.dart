import 'package:flutter_test/flutter_test.dart';
import 'package:my_root/models/evidence.dart';

void main() {
  group('Evidence Model', () {
    final sampleEvidenceJson = {
      'id': 'evi-001',
      'claimId': 'claim-123',
      'sourceType': 'DOCUMENT',
      'title': '1923 Land Revenue Settlement Record',
      'description': 'Historical land survey archive page 42 confirming village boundaries.',
      'documentRef': 'ARCH-1923-DOC-42',
      'url': 'https://archives.gov.in/records/1923-42',
      'dateOfEvidence': '1923-05-15T00:00:00.000Z',
      'languageOfEvidence': 'en',
      'uploadedBy': 'user-contributor-1',
      'uploadedAt': '2026-02-01T12:00:00.000Z',
      'status': 'submitted',
    };

    test('parses from standard JSON correctly', () {
      final evidence = Evidence.fromJson(sampleEvidenceJson);

      expect(evidence.id, 'evi-001');
      expect(evidence.claimId, 'claim-123');
      expect(evidence.sourceType, 'DOCUMENT');
      expect(evidence.title, '1923 Land Revenue Settlement Record');
      expect(evidence.documentRef, 'ARCH-1923-DOC-42');
      expect(evidence.url, 'https://archives.gov.in/records/1923-42');
      expect(evidence.dateOfEvidence, DateTime.parse('1923-05-15T00:00:00.000Z'));
      expect(evidence.languageOfEvidence, 'en');
      expect(evidence.uploadedBy, 'user-contributor-1');
      expect(evidence.status, 'submitted');
      expect(evidence.isSubmitted, isTrue);
      expect(evidence.isVerified, isFalse);
      expect(evidence.isDisputed, isFalse);
      expect(evidence.isRejected, isFalse);
    });

    test('parses when claimId and uploadedBy are MongoDB populated objects', () {
      final populatedJson = {
        '_id': 'evi-002',
        'claimId': {'_id': 'claim-populated-999'},
        'sourceType': 'PHOTOGRAPH',
        'title': 'Historical Temple Inscription 1880',
        'description': 'Stone carving photograph depicting founding date.',
        'uploadedBy': {'_id': 'user-populated-888'},
        'uploadedAt': '2026-03-01T08:00:00.000Z',
        'status': 'verified',
        'reviewedBy': {'_id': 'reviewer-777'},
        'reviewedAt': '2026-03-02T10:00:00.000Z',
        'reviewNotes': 'Verified by state epigraphy department reference.',
      };

      final evidence = Evidence.fromJson(populatedJson);

      expect(evidence.id, 'evi-002');
      expect(evidence.claimId, 'claim-populated-999');
      expect(evidence.sourceType, 'PHOTOGRAPH');
      expect(evidence.uploadedBy, 'user-populated-888');
      expect(evidence.status, 'verified');
      expect(evidence.isVerified, isTrue);
      expect(evidence.reviewedBy, 'reviewer-777');
      expect(evidence.reviewedAt, DateTime.parse('2026-03-02T10:00:00.000Z'));
      expect(evidence.reviewNotes, 'Verified by state epigraphy department reference.');
    });

    test('status getters reflect disputed and rejected states correctly', () {
      final disputedJson = {
        ...sampleEvidenceJson,
        'id': 'evi-003',
        'status': 'disputed',
        'reviewNotes': 'Authenticity of document disputed by local gazetteer committee.',
      };
      final disputedEvidence = Evidence.fromJson(disputedJson);
      expect(disputedEvidence.isDisputed, isTrue);
      expect(disputedEvidence.isVerified, isFalse);
      expect(disputedEvidence.isSubmitted, isFalse);

      final rejectedJson = {
        ...sampleEvidenceJson,
        'id': 'evi-004',
        'status': 'rejected',
        'reviewNotes': 'Document pertains to a different district.',
      };
      final rejectedEvidence = Evidence.fromJson(rejectedJson);
      expect(rejectedEvidence.isRejected, isTrue);
      expect(rejectedEvidence.isVerified, isFalse);
      expect(rejectedEvidence.isDisputed, isFalse);
    });

    test('serializes to JSON correctly', () {
      final evidence = Evidence.fromJson(sampleEvidenceJson);
      final json = evidence.toJson();

      expect(json['id'], 'evi-001');
      expect(json['claimId'], 'claim-123');
      expect(json['sourceType'], 'DOCUMENT');
      expect(json['title'], '1923 Land Revenue Settlement Record');
      expect(json['status'], 'submitted');
      expect(json['documentRef'], 'ARCH-1923-DOC-42');
      expect(json['url'], 'https://archives.gov.in/records/1923-42');
    });
  });
}
