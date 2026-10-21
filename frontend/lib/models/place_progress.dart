class PlaceProgress {
  final String placeId;
  final int totalContributions;
  final int verifiedFactsCount;
  final int pendingReviewCount;
  final int folkloreCount;
  final int opinionsCount;
  final int biographiesCount;
  final int facilitiesCount;
  final int evidenceAttachmentsCount;
  final int qualityCoverageScore;
  final String criteriaExplanation;

  const PlaceProgress({
    required this.placeId,
    required this.totalContributions,
    required this.verifiedFactsCount,
    required this.pendingReviewCount,
    required this.folkloreCount,
    required this.opinionsCount,
    required this.biographiesCount,
    required this.facilitiesCount,
    required this.evidenceAttachmentsCount,
    required this.qualityCoverageScore,
    required this.criteriaExplanation,
  });

  factory PlaceProgress.fromJson(Map<String, dynamic> json) => PlaceProgress(
        placeId: json['placeId'] as String? ?? '',
        totalContributions: json['totalContributions'] as int? ?? 0,
        verifiedFactsCount: json['verifiedFactsCount'] as int? ?? 0,
        pendingReviewCount: json['pendingReviewCount'] as int? ?? 0,
        folkloreCount: json['folkloreCount'] as int? ?? 0,
        opinionsCount: json['opinionsCount'] as int? ?? 0,
        biographiesCount: json['biographiesCount'] as int? ?? 0,
        facilitiesCount: json['facilitiesCount'] as int? ?? 0,
        evidenceAttachmentsCount: json['evidenceAttachmentsCount'] as int? ?? 0,
        qualityCoverageScore: json['qualityCoverageScore'] as int? ?? 0,
        criteriaExplanation: json['criteriaExplanation'] as String? ?? '',
      );
}

class PlaceAttribute {
  final String id;
  final String placeId;
  final String category;
  final String key;
  final String value;
  final String sourceDescription;
  final String? reportedPeriod;
  final DateTime? reportedDate;
  final String? uncertainty;
  final DateTime createdAt;

  const PlaceAttribute({
    required this.id,
    required this.placeId,
    required this.category,
    required this.key,
    required this.value,
    required this.sourceDescription,
    this.reportedPeriod,
    this.reportedDate,
    this.uncertainty,
    required this.createdAt,
  });

  factory PlaceAttribute.fromJson(Map<String, dynamic> json) => PlaceAttribute(
        id: (json['_id'] ?? json['id']) as String? ?? '',
        placeId: json['placeId'] as String? ?? '',
        category: json['category'] as String? ?? '',
        key: json['key'] as String? ?? '',
        value: json['value'] as String? ?? '',
        sourceDescription: json['sourceDescription'] as String? ?? '',
        reportedPeriod: json['reportedPeriod'] as String?,
        reportedDate: json['reportedDate'] != null ? DateTime.tryParse(json['reportedDate'] as String) : null,
        uncertainty: json['uncertainty'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}
