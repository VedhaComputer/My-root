class MatrbhoomiHistoryInterest {
  final String placeId;
  final bool? knowsHistory;
  final bool? wantsToLearn;
  final DateTime answeredAt;

  const MatrbhoomiHistoryInterest({
    required this.placeId,
    this.knowsHistory,
    this.wantsToLearn,
    required this.answeredAt,
  });

  factory MatrbhoomiHistoryInterest.fromJson(Map<String, dynamic> json) =>
      MatrbhoomiHistoryInterest(
        placeId: json['placeId'] as String? ?? '',
        knowsHistory: json['knowsHistory'] as bool?,
        wantsToLearn: json['wantsToLearn'] as bool?,
        answeredAt: DateTime.parse(
          json['answeredAt'] as String? ?? DateTime.now().toIso8601String(),
        ),
      );

  Map<String, dynamic> toJson() => {
        'placeId': placeId,
        'knowsHistory': knowsHistory,
        'wantsToLearn': wantsToLearn,
        'answeredAt': answeredAt.toIso8601String(),
      };
}

class UserPlaceRelationship {
  final String placeId;
  final String? residenceType;
  final String? indigenousClassification; // 'Indigenous' or 'Non-Indigenous'
  final DateTime createdAt;

  const UserPlaceRelationship({
    required this.placeId,
    this.residenceType,
    this.indigenousClassification,
    required this.createdAt,
  });

  bool get hasExplicitClassification =>
      indigenousClassification == 'Indigenous' || indigenousClassification == 'Non-Indigenous';

  factory UserPlaceRelationship.fromJson(Map<String, dynamic> json) =>
      UserPlaceRelationship(
        placeId: json['placeId'] as String? ?? '',
        residenceType: json['residenceType'] as String?,
        indigenousClassification: json['indigenousClassification'] as String?,
        createdAt: DateTime.parse(
          json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
        ),
      );

  Map<String, dynamic> toJson() => {
        'placeId': placeId,
        if (residenceType != null) 'residenceType': residenceType,
        if (indigenousClassification != null)
          'indigenousClassification': indigenousClassification,
        'createdAt': createdAt.toIso8601String(),
      };
}

class User {
  final String id;
  final String displayName;
  final String role;
  final DateTime joinedAt;
  final bool isIdentityVerified;
  final String? verifiedLocationId;
  final String? selectedPlaceId;
  final MatrbhoomiHistoryInterest? matrbhoomiHistoryInterest;
  final List<MatrbhoomiHistoryInterest> matrbhoomiHistoryInterests;
  final List<UserPlaceRelationship> placeRelationships;
  final String? indigenousClassification;
  // NOTE: email, identity documents, and PII are never stored in client model

  const User({
    required this.id,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    this.isIdentityVerified = false,
    this.verifiedLocationId,
    this.selectedPlaceId,
    this.matrbhoomiHistoryInterest,
    this.matrbhoomiHistoryInterests = const [],
    this.placeRelationships = const [],
    this.indigenousClassification,
  });

  bool get isContributor =>
      ['CONTRIBUTOR', 'LOCAL_CONTRIBUTOR', 'REVIEWER', 'MODERATOR', 'ADMIN'].contains(role);
  bool get isReviewer => ['REVIEWER', 'MODERATOR', 'ADMIN'].contains(role);
  bool get isModerator => ['MODERATOR', 'ADMIN'].contains(role);
  bool get isAdmin => role == 'ADMIN';

  UserPlaceRelationship? getRelationshipForPlace(String placeId) {
    for (final rel in placeRelationships) {
      if (rel.placeId == placeId) return rel;
    }
    return null;
  }

  String? getClassificationForPlace(String placeId) {
    return getRelationshipForPlace(placeId)?.indigenousClassification;
  }

  bool hasClassificationForPlace(String placeId) {
    final rel = getRelationshipForPlace(placeId);
    return rel != null && rel.hasExplicitClassification;
  }

  MatrbhoomiHistoryInterest? getInterestForPlace(String placeId) {
    for (final interest in matrbhoomiHistoryInterests) {
      if (interest.placeId == placeId) return interest;
    }
    if (matrbhoomiHistoryInterest?.placeId == placeId) {
      return matrbhoomiHistoryInterest;
    }
    return null;
  }

  User copyWith({
    String? id,
    String? displayName,
    String? role,
    DateTime? joinedAt,
    bool? isIdentityVerified,
    String? verifiedLocationId,
    String? selectedPlaceId,
    bool clearSelectedPlace = false,
    MatrbhoomiHistoryInterest? matrbhoomiHistoryInterest,
    List<MatrbhoomiHistoryInterest>? matrbhoomiHistoryInterests,
    List<UserPlaceRelationship>? placeRelationships,
    String? indigenousClassification,
    bool clearIndigenousClassification = false,
  }) {
    final nextSelectedPlaceId = clearSelectedPlace ? null : (selectedPlaceId ?? this.selectedPlaceId);
    final nextPlaceRels = placeRelationships ?? this.placeRelationships;

    String? nextClassification;
    if (clearIndigenousClassification) {
      nextClassification = null;
    } else if (indigenousClassification != null) {
      nextClassification = indigenousClassification;
    } else if (nextSelectedPlaceId == null) {
      nextClassification = null;
    } else if (selectedPlaceId != null && selectedPlaceId != this.selectedPlaceId) {
      final match = nextPlaceRels.where((r) => r.placeId == nextSelectedPlaceId).firstOrNull;
      nextClassification = match?.indigenousClassification;
    } else {
      nextClassification = this.indigenousClassification;
    }

    return User(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      isIdentityVerified: isIdentityVerified ?? this.isIdentityVerified,
      verifiedLocationId: verifiedLocationId ?? this.verifiedLocationId,
      selectedPlaceId: nextSelectedPlaceId,
      matrbhoomiHistoryInterest:
          matrbhoomiHistoryInterest ?? this.matrbhoomiHistoryInterest,
      matrbhoomiHistoryInterests:
          matrbhoomiHistoryInterests ?? this.matrbhoomiHistoryInterests,
      placeRelationships: nextPlaceRels,
      indigenousClassification: nextClassification,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final listInterests = (json['matrbhoomiHistoryInterests'] as List<dynamic>?)
            ?.map((i) => MatrbhoomiHistoryInterest.fromJson(i as Map<String, dynamic>))
            .toList() ??
        [];
    final singleInterest = json['matrbhoomiHistoryInterest'] != null
        ? MatrbhoomiHistoryInterest.fromJson(
            json['matrbhoomiHistoryInterest'] as Map<String, dynamic>)
        : null;

    final allInterests = [...listInterests];
    if (singleInterest != null &&
        !allInterests.any((i) => i.placeId == singleInterest.placeId)) {
      allInterests.add(singleInterest);
    }

    final rawPlaceRels = json['placeRelationships'] as List<dynamic>?;
    final placeRels = rawPlaceRels
            ?.map((r) => UserPlaceRelationship.fromJson(r as Map<String, dynamic>))
            .toList() ??
        [];

    final selectedPlaceId = json['selectedPlaceId'] as String?;
    String? resolvedClassification = json['indigenousClassification'] as String?;
    if (resolvedClassification == null && selectedPlaceId != null) {
      for (final rel in placeRels) {
        if (rel.placeId == selectedPlaceId) {
          resolvedClassification = rel.indigenousClassification;
          break;
        }
      }
    }

    return User(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joinedAt'] as String? ?? DateTime.now().toIso8601String()),
      isIdentityVerified: json['isIdentityVerified'] as bool? ?? false,
      verifiedLocationId: json['verifiedLocationId'] as String?,
      selectedPlaceId: selectedPlaceId,
      matrbhoomiHistoryInterest: singleInterest ?? (listInterests.isNotEmpty ? listInterests.last : null),
      matrbhoomiHistoryInterests: allInterests,
      placeRelationships: placeRels,
      indigenousClassification: resolvedClassification,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'role': role,
        'joinedAt': joinedAt.toIso8601String(),
        'isIdentityVerified': isIdentityVerified,
        if (verifiedLocationId != null) 'verifiedLocationId': verifiedLocationId,
        if (selectedPlaceId != null) 'selectedPlaceId': selectedPlaceId,
        if (indigenousClassification != null)
          'indigenousClassification': indigenousClassification,
        if (matrbhoomiHistoryInterest != null)
          'matrbhoomiHistoryInterest': matrbhoomiHistoryInterest!.toJson(),
        if (matrbhoomiHistoryInterests.isNotEmpty)
          'matrbhoomiHistoryInterests':
              matrbhoomiHistoryInterests.map((i) => i.toJson()).toList(),
        if (placeRelationships.isNotEmpty)
          'placeRelationships':
              placeRelationships.map((r) => r.toJson()).toList(),
      };
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final User user;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        user: User.fromJson(json['user'] as Map<String, dynamic>),
      );
}

class PublicUser {
  final String displayName;
  final String? avatarUrl;
  final DateTime? joinedAt;

  const PublicUser({
    required this.displayName,
    this.avatarUrl,
    this.joinedAt,
  });

  factory PublicUser.fromJson(Map<String, dynamic> json) => PublicUser(
        displayName: json['displayName'] as String? ?? 'User',
        avatarUrl: json['avatarUrl'] as String?,
        joinedAt: json['joinedAt'] != null
            ? DateTime.tryParse(json['joinedAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (joinedAt != null) 'joinedAt': joinedAt!.toIso8601String(),
      };
}
