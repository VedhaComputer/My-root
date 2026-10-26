import 'package:flutter/material.dart';

class PollReasonBreakdown {
  final String key;
  final int count;
  final double percentage;

  const PollReasonBreakdown({
    required this.key,
    required this.count,
    required this.percentage,
  });

  factory PollReasonBreakdown.fromJson(Map<String, dynamic> json) {
    return PollReasonBreakdown(
      key: json['key'] as String? ?? '',
      count: json['count'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'count': count,
        'percentage': percentage,
      };
}

class PollVote {
  final String choice; // 'LIKE' or 'DISLIKE'
  final String reasonKey;
  final String? explanation;
  final DateTime updatedAt;

  const PollVote({
    required this.choice,
    required this.reasonKey,
    this.explanation,
    required this.updatedAt,
  });

  bool get isLike => choice == 'LIKE';
  bool get isDislike => choice == 'DISLIKE';

  factory PollVote.fromJson(Map<String, dynamic> json) {
    return PollVote(
      choice: json['choice'] as String? ?? 'LIKE',
      reasonKey: json['reasonKey'] as String? ?? 'other',
      explanation: json['explanation'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'choice': choice,
        'reasonKey': reasonKey,
        if (explanation != null) 'explanation': explanation,
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class Poll {
  final String id;
  final String personName;
  final String? personRole;
  final String? placeId;
  final String? placeName;
  final String? targetEntityId;
  final String question;
  final String? description;
  final String? photoUrl;
  final String status; // 'ACTIVE', 'CLOSED', 'REPORTED', 'REMOVED'
  final DateTime startTime;
  final DateTime? endTime;
  final String createdBy;
  final String? creatorName;
  final int likeCount;
  final int dislikeCount;
  final int totalVotes;
  final double likePercentage;
  final double dislikePercentage;
  final List<PollReasonBreakdown> likeReasons;
  final List<PollReasonBreakdown> dislikeReasons;
  final PollVote? userVote;
  final int reportsCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Poll({
    required this.id,
    required this.personName,
    this.personRole,
    this.placeId,
    this.placeName,
    this.targetEntityId,
    required this.question,
    this.description,
    this.photoUrl,
    required this.status,
    required this.startTime,
    this.endTime,
    required this.createdBy,
    this.creatorName,
    required this.likeCount,
    required this.dislikeCount,
    required this.totalVotes,
    required this.likePercentage,
    required this.dislikePercentage,
    required this.likeReasons,
    required this.dislikeReasons,
    this.userVote,
    this.reportsCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'ACTIVE' && (endTime == null || endTime!.isAfter(DateTime.now()));
  bool get isClosed => !isActive;
  bool get hasUserVoted => userVote != null;

  Poll copyWith({
    String? id,
    String? personName,
    String? personRole,
    String? placeId,
    String? placeName,
    String? targetEntityId,
    String? question,
    String? description,
    String? photoUrl,
    String? status,
    DateTime? startTime,
    DateTime? endTime,
    String? createdBy,
    String? creatorName,
    int? likeCount,
    int? dislikeCount,
    int? totalVotes,
    double? likePercentage,
    double? dislikePercentage,
    List<PollReasonBreakdown>? likeReasons,
    List<PollReasonBreakdown>? dislikeReasons,
    PollVote? userVote,
    int? reportsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Poll(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      personRole: personRole ?? this.personRole,
      placeId: placeId ?? this.placeId,
      placeName: placeName ?? this.placeName,
      targetEntityId: targetEntityId ?? this.targetEntityId,
      question: question ?? this.question,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdBy: createdBy ?? this.createdBy,
      creatorName: creatorName ?? this.creatorName,
      likeCount: likeCount ?? this.likeCount,
      dislikeCount: dislikeCount ?? this.dislikeCount,
      totalVotes: totalVotes ?? this.totalVotes,
      likePercentage: likePercentage ?? this.likePercentage,
      dislikePercentage: dislikePercentage ?? this.dislikePercentage,
      likeReasons: likeReasons ?? this.likeReasons,
      dislikeReasons: dislikeReasons ?? this.dislikeReasons,
      userVote: userVote ?? this.userVote,
      reportsCount: reportsCount ?? this.reportsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Poll.fromJson(Map<String, dynamic> json) {
    final rawLikeReasons = json['likeReasons'] as List<dynamic>? ?? [];
    final rawDislikeReasons = json['dislikeReasons'] as List<dynamic>? ?? [];

    return Poll(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      personName: json['personName'] as String? ?? '',
      personRole: json['personRole'] as String?,
      placeId: json['placeId'] as String?,
      placeName: json['placeName'] as String?,
      targetEntityId: json['targetEntityId'] as String?,
      question: json['question'] as String? ?? '',
      description: json['description'] as String?,
      photoUrl: json['photoUrl'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      startTime: DateTime.tryParse(json['startTime'] as String? ?? '') ?? DateTime.now(),
      endTime: json['endTime'] != null ? DateTime.tryParse(json['endTime'] as String) : null,
      createdBy: json['createdBy'] as String? ?? '',
      creatorName: json['creatorName'] as String?,
      likeCount: json['likeCount'] as int? ?? 0,
      dislikeCount: json['dislikeCount'] as int? ?? 0,
      totalVotes: json['totalVotes'] as int? ?? 0,
      likePercentage: (json['likePercentage'] as num?)?.toDouble() ?? 0.0,
      dislikePercentage: (json['dislikePercentage'] as num?)?.toDouble() ?? 0.0,
      likeReasons: rawLikeReasons.map((e) => PollReasonBreakdown.fromJson(e as Map<String, dynamic>)).toList(),
      dislikeReasons: rawDislikeReasons.map((e) => PollReasonBreakdown.fromJson(e as Map<String, dynamic>)).toList(),
      userVote: json['userVote'] != null ? PollVote.fromJson(json['userVote'] as Map<String, dynamic>) : null,
      reportsCount: json['reportsCount'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'personName': personName,
        'personRole': personRole,
        'placeId': placeId,
        'placeName': placeName,
        'targetEntityId': targetEntityId,
        'question': question,
        'description': description,
        'photoUrl': photoUrl,
        'status': status,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'createdBy': createdBy,
        'creatorName': creatorName,
        'likeCount': likeCount,
        'dislikeCount': dislikeCount,
        'totalVotes': totalVotes,
        'likePercentage': likePercentage,
        'dislikePercentage': dislikePercentage,
        'likeReasons': likeReasons.map((e) => e.toJson()).toList(),
        'dislikeReasons': dislikeReasons.map((e) => e.toJson()).toList(),
        if (userVote != null) 'userVote': userVote!.toJson(),
        'reportsCount': reportsCount,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class PollReasonOption {
  final String key;
  final String labelEn;
  final String labelHi;
  final IconData icon;

  const PollReasonOption({
    required this.key,
    required this.labelEn,
    required this.labelHi,
    required this.icon,
  });

  String localized(bool isHindi) => isHindi ? labelHi : labelEn;

  static const List<PollReasonOption> likeReasons = [
    PollReasonOption(
      key: 'work_performance',
      labelEn: 'Work and performance',
      labelHi: 'काम और परफॉर्मेंस',
      icon: Icons.trending_up,
    ),
    PollReasonOption(
      key: 'public_service',
      labelEn: 'Public service and development',
      labelHi: 'जनसेवा और विकास कार्य',
      icon: Icons.construction,
    ),
    PollReasonOption(
      key: 'helping_nature',
      labelEn: 'Helping nature',
      labelHi: 'लोगों की मदद करने का स्वभाव',
      icon: Icons.volunteer_activism,
    ),
    PollReasonOption(
      key: 'behaviour_respect',
      labelEn: 'Behaviour and respect',
      labelHi: 'व्यवहार और सभी का सम्मान',
      icon: Icons.thumb_up_alt_outlined,
    ),
    PollReasonOption(
      key: 'accessibility_responsiveness',
      labelEn: 'Accessibility and responsiveness',
      labelHi: 'उपलब्धता और नियमित संवाद',
      icon: Icons.forum_outlined,
    ),
    PollReasonOption(
      key: 'promises_fulfilled',
      labelEn: 'Promises fulfilled',
      labelHi: 'किए गए वादे पूरे किए',
      icon: Icons.task_alt,
    ),
    PollReasonOption(
      key: 'honesty_trust',
      labelEn: 'Honesty or trust (personal opinion)',
      labelHi: 'ईमानदारी और विश्वास (व्यक्तिगत राय)',
      icon: Icons.verified_user_outlined,
    ),
    PollReasonOption(
      key: 'community_contribution',
      labelEn: 'Community contribution',
      labelHi: 'समाज और समुदाय में योगदान',
      icon: Icons.groups,
    ),
    PollReasonOption(
      key: 'other',
      labelEn: 'Other reason',
      labelHi: 'अन्य सकारात्मक कारण',
      icon: Icons.more_horiz,
    ),
  ];

  static const List<PollReasonOption> dislikeReasons = [
    PollReasonOption(
      key: 'work_dissatisfaction',
      labelEn: 'Work or performance dissatisfaction',
      labelHi: 'काम या परफॉर्मेंस से असंतुष्ट',
      icon: Icons.sentiment_dissatisfied,
    ),
    PollReasonOption(
      key: 'promises_unfulfilled',
      labelEn: 'Promises not fulfilled',
      labelHi: 'किए गए वादे पूरे नहीं किए',
      icon: Icons.cancel_outlined,
    ),
    PollReasonOption(
      key: 'lack_responsiveness',
      labelEn: 'Lack of responsiveness',
      labelHi: 'संवाद या जनसुनवाई की कमी',
      icon: Icons.speaker_notes_off_outlined,
    ),
    PollReasonOption(
      key: 'behaviour_concerns',
      labelEn: 'Behaviour or communication concerns',
      labelHi: 'व्यवहार या संवाद में असंतोष',
      icon: Icons.warning_amber_outlined,
    ),
    PollReasonOption(
      key: 'development_dissatisfaction',
      labelEn: 'Public service or development dissatisfaction',
      labelHi: 'जनसेवा या विकास कार्यों से असंतुष्ट',
      icon: Icons.do_not_disturb_on_outlined,
    ),
    PollReasonOption(
      key: 'lack_accessibility',
      labelEn: 'Lack of accessibility',
      labelHi: 'जनता के लिए अनुपलब्धता',
      icon: Icons.person_off_outlined,
    ),
    PollReasonOption(
      key: 'policy_disagreement',
      labelEn: 'Disagreement with decisions or policies',
      labelHi: 'निर्णयों या नीतियों से असहमति',
      icon: Icons.thumb_down_outlined,
    ),
    PollReasonOption(
      key: 'other',
      labelEn: 'Other reason',
      labelHi: 'अन्य असंतोष का कारण',
      icon: Icons.more_horiz,
    ),
  ];

  static String lookupLabel(String key, bool isLike, bool isHindi) {
    final list = isLike ? likeReasons : dislikeReasons;
    final match = list.where((r) => r.key == key).firstOrNull;
    if (match != null) {
      return match.localized(isHindi);
    }
    return key;
  }
}
