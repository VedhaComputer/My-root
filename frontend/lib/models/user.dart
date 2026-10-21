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
  });

  bool get isContributor =>
      ['CONTRIBUTOR', 'LOCAL_CONTRIBUTOR', 'REVIEWER', 'MODERATOR', 'ADMIN'].contains(role);
  bool get isReviewer => ['REVIEWER', 'MODERATOR', 'ADMIN'].contains(role);
  bool get isModerator => ['MODERATOR', 'ADMIN'].contains(role);
  bool get isAdmin => role == 'ADMIN';

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
  }) {
    return User(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      isIdentityVerified: isIdentityVerified ?? this.isIdentityVerified,
      verifiedLocationId: verifiedLocationId ?? this.verifiedLocationId,
      selectedPlaceId: clearSelectedPlace ? null : (selectedPlaceId ?? this.selectedPlaceId),
      matrbhoomiHistoryInterest:
          matrbhoomiHistoryInterest ?? this.matrbhoomiHistoryInterest,
      matrbhoomiHistoryInterests:
          matrbhoomiHistoryInterests ?? this.matrbhoomiHistoryInterests,
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

    return User(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joinedAt'] as String? ?? DateTime.now().toIso8601String()),
      isIdentityVerified: json['isIdentityVerified'] as bool? ?? false,
      verifiedLocationId: json['verifiedLocationId'] as String?,
      selectedPlaceId: json['selectedPlaceId'] as String?,
      matrbhoomiHistoryInterest: singleInterest ?? (listInterests.isNotEmpty ? listInterests.last : null),
      matrbhoomiHistoryInterests: allInterests,
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
        if (matrbhoomiHistoryInterest != null)
          'matrbhoomiHistoryInterest': matrbhoomiHistoryInterest!.toJson(),
        if (matrbhoomiHistoryInterests.isNotEmpty)
          'matrbhoomiHistoryInterests':
              matrbhoomiHistoryInterests.map((i) => i.toJson()).toList(),
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
