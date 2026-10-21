import 'claim.dart';

class UserActivitySummary {
  final int totalContributions;
  final int claimsCount;
  final int evidencesCount;
  final int placesCount;
  final int placeAttributesCount;

  const UserActivitySummary({
    required this.totalContributions,
    required this.claimsCount,
    required this.evidencesCount,
    required this.placesCount,
    required this.placeAttributesCount,
  });

  factory UserActivitySummary.fromJson(Map<String, dynamic> json) {
    final claims = json['claimsCount'] as int? ?? json['totalClaims'] as int? ?? 0;
    final evidences = json['evidencesCount'] as int? ?? json['totalEvidences'] as int? ?? 0;
    final places = json['placesCount'] as int? ?? json['totalPlaces'] as int? ?? 0;
    final attributes = json['placeAttributesCount'] as int? ?? json['totalAttributes'] as int? ?? 0;
    final total = json['totalContributions'] as int? ?? (claims + evidences + places + attributes);

    return UserActivitySummary(
      totalContributions: total,
      claimsCount: claims,
      evidencesCount: evidences,
      placesCount: places,
      placeAttributesCount: attributes,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalContributions': totalContributions,
        'claimsCount': claimsCount,
        'evidencesCount': evidencesCount,
        'placesCount': placesCount,
        'placeAttributesCount': placeAttributesCount,
      };
}

class UserClaimActivity {
  final String id;
  final LocalizedContent title;
  final LocalizedContent? body;
  final String category;
  final String status;
  final DateTime submittedAt;
  final int evidenceCount;
  final String? locationId;

  const UserClaimActivity({
    required this.id,
    required this.title,
    this.body,
    required this.category,
    required this.status,
    required this.submittedAt,
    required this.evidenceCount,
    this.locationId,
  });

  factory UserClaimActivity.fromJson(Map<String, dynamic> json) {
    final rawTitle = json['title'];
    final LocalizedContent parsedTitle;
    if (rawTitle is Map<String, dynamic>) {
      parsedTitle = LocalizedContent.fromJson(rawTitle);
    } else {
      parsedTitle = LocalizedContent(
        original: rawTitle?.toString() ?? '',
        language: 'en',
      );
    }

    final rawBody = json['body'];
    final LocalizedContent? parsedBody;
    if (rawBody is Map<String, dynamic>) {
      parsedBody = LocalizedContent.fromJson(rawBody);
    } else if (rawBody != null && rawBody.toString().isNotEmpty) {
      parsedBody = LocalizedContent(
        original: rawBody.toString(),
        language: 'en',
      );
    } else {
      parsedBody = null;
    }

    final dateStr = json['submittedAt'] as String? ?? json['createdAt'] as String? ?? '';
    final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

    return UserClaimActivity(
      id: json['id'] as String? ?? '',
      title: parsedTitle,
      body: parsedBody,
      category: json['category'] as String? ?? 'HISTORICAL_RECORD',
      status: json['status'] as String? ?? 'submitted',
      submittedAt: parsedDate,
      evidenceCount: json['evidenceCount'] as int? ?? 0,
      locationId: json['locationId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title.toJson(),
        if (body != null) 'body': body!.toJson(),
        'category': category,
        'status': status,
        'submittedAt': submittedAt.toIso8601String(),
        'evidenceCount': evidenceCount,
        if (locationId != null) 'locationId': locationId,
      };
}

class UserEvidenceActivity {
  final String id;
  final String claimId;
  final String sourceType;
  final String status;
  final DateTime submittedAt;
  final String summary;

  const UserEvidenceActivity({
    required this.id,
    required this.claimId,
    required this.sourceType,
    required this.status,
    required this.submittedAt,
    required this.summary,
  });

  factory UserEvidenceActivity.fromJson(Map<String, dynamic> json) {
    final dateStr = json['submittedAt'] as String? ?? json['uploadedAt'] as String? ?? json['createdAt'] as String? ?? '';
    final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

    final summaryStr = json['summary'] as String? ??
        json['title'] as String? ??
        json['description'] as String? ??
        '';

    return UserEvidenceActivity(
      id: json['id'] as String? ?? '',
      claimId: json['claimId'] as String? ?? '',
      sourceType: json['sourceType'] as String? ?? 'OTHER',
      status: json['status'] as String? ?? 'submitted',
      submittedAt: parsedDate,
      summary: summaryStr,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'claimId': claimId,
        'sourceType': sourceType,
        'status': status,
        'submittedAt': submittedAt.toIso8601String(),
        'summary': summary,
      };
}

class UserPlaceActivity {
  final String id;
  final String canonicalName;
  final String level;
  final String status;
  final DateTime createdAt;

  const UserPlaceActivity({
    required this.id,
    required this.canonicalName,
    required this.level,
    required this.status,
    required this.createdAt,
  });

  factory UserPlaceActivity.fromJson(Map<String, dynamic> json) {
    final dateStr = json['createdAt'] as String? ?? '';
    final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

    return UserPlaceActivity(
      id: json['id'] as String? ?? '',
      canonicalName: json['canonicalName'] as String? ?? '',
      level: json['level'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'canonicalName': canonicalName,
        'level': level,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };
}

class UserPlaceAttributeActivity {
  final String id;
  final String placeId;
  final String key;
  final String status;
  final DateTime submittedAt;

  const UserPlaceAttributeActivity({
    required this.id,
    required this.placeId,
    required this.key,
    required this.status,
    required this.submittedAt,
  });

  factory UserPlaceAttributeActivity.fromJson(Map<String, dynamic> json) {
    final dateStr = json['submittedAt'] as String? ?? json['reportedAt'] as String? ?? json['createdAt'] as String? ?? '';
    final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

    return UserPlaceAttributeActivity(
      id: json['id'] as String? ?? '',
      placeId: json['placeId'] as String? ?? '',
      key: json['key'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      submittedAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'placeId': placeId,
        'key': key,
        'status': status,
        'submittedAt': submittedAt.toIso8601String(),
      };
}

class UserActivity {
  final UserActivitySummary summary;
  final List<UserClaimActivity> claims;
  final List<UserEvidenceActivity> evidences;
  final List<UserPlaceActivity> places;
  final List<UserPlaceAttributeActivity> placeAttributes;

  const UserActivity({
    required this.summary,
    required this.claims,
    required this.evidences,
    required this.places,
    required this.placeAttributes,
  });

  factory UserActivity.fromJson(Map<String, dynamic> json) => UserActivity(
        summary: UserActivitySummary.fromJson(
            json['summary'] as Map<String, dynamic>? ?? {}),
        claims: (json['claims'] as List<dynamic>? ?? [])
            .map((c) => UserClaimActivity.fromJson(c as Map<String, dynamic>))
            .toList(),
        evidences: (json['evidences'] as List<dynamic>? ?? [])
            .map((e) => UserEvidenceActivity.fromJson(e as Map<String, dynamic>))
            .toList(),
        places: (json['places'] as List<dynamic>? ?? [])
            .map((p) => UserPlaceActivity.fromJson(p as Map<String, dynamic>))
            .toList(),
        placeAttributes: (json['placeAttributes'] as List<dynamic>? ?? [])
            .map((a) =>
                UserPlaceAttributeActivity.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}
