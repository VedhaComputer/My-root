import 'package:flutter/material.dart';
import '../core/constants.dart';

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
  final String? questionId;
  final String? personId;
  final DateTime updatedAt;

  const PollVote({
    required this.choice,
    required this.reasonKey,
    this.explanation,
    this.questionId,
    this.personId,
    required this.updatedAt,
  });

  bool get isLike => choice == 'LIKE';
  bool get isDislike => choice == 'DISLIKE';

  factory PollVote.fromJson(Map<String, dynamic> json) {
    return PollVote(
      choice: json['choice'] as String? ?? 'LIKE',
      reasonKey: json['reasonKey'] as String? ?? 'other',
      explanation: json['explanation'] as String?,
      questionId: json['questionId'] as String?,
      personId: json['personId'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'choice': choice,
        'reasonKey': reasonKey,
        if (explanation != null) 'explanation': explanation,
        if (questionId != null) 'questionId': questionId,
        if (personId != null) 'personId': personId,
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class PollPerson {
  final String id;
  final String name;
  final String? role;
  final String? designation;
  final String? officeContext;
  final String? placeId;
  final String? placeName;
  final String? targetEntityId;
  final String? photoUrl;
  final String? workBackground;
  final String? publicServiceHistory;
  final String? education;
  final String? achievements;
  final String? casteCommunity;
  final String? religion;
  final String? bio;
  final String? sourceReference;
  final String verificationStatus;

  const PollPerson({
    required this.id,
    required this.name,
    this.role,
    this.designation,
    this.officeContext,
    this.placeId,
    this.placeName,
    this.targetEntityId,
    this.photoUrl,
    this.workBackground,
    this.publicServiceHistory,
    this.education,
    this.achievements,
    this.casteCommunity,
    this.religion,
    this.bio,
    this.sourceReference,
    this.verificationStatus = 'UNVERIFIED',
  });

  factory PollPerson.fromJson(Map<String, dynamic> json) {
    return PollPerson(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String?,
      designation: json['designation'] as String? ?? json['role'] as String?,
      officeContext: json['officeContext'] as String?,
      placeId: json['placeId'] as String?,
      placeName: json['placeName'] as String?,
      targetEntityId: json['targetEntityId'] as String?,
      photoUrl: json['photoUrl'] as String?,
      workBackground: json['workBackground'] as String?,
      publicServiceHistory: json['publicServiceHistory'] as String?,
      education: json['education'] as String?,
      achievements: json['achievements'] as String?,
      casteCommunity: json['casteCommunity'] as String?,
      religion: json['religion'] as String?,
      bio: json['bio'] as String?,
      sourceReference: json['sourceReference'] as String?,
      verificationStatus: json['verificationStatus'] as String? ?? 'UNVERIFIED',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (role != null) 'role': role,
        if (designation != null) 'designation': designation,
        if (officeContext != null) 'officeContext': officeContext,
        if (placeId != null) 'placeId': placeId,
        if (placeName != null) 'placeName': placeName,
        if (targetEntityId != null) 'targetEntityId': targetEntityId,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (workBackground != null) 'workBackground': workBackground,
        if (publicServiceHistory != null) 'publicServiceHistory': publicServiceHistory,
        if (education != null) 'education': education,
        if (achievements != null) 'achievements': achievements,
        if (casteCommunity != null) 'casteCommunity': casteCommunity,
        if (religion != null) 'religion': religion,
        if (bio != null) 'bio': bio,
        if (sourceReference != null) 'sourceReference': sourceReference,
        'verificationStatus': verificationStatus,
      };
}

class PollQuestion {
  final String id;
  final String text;
  final String? personId;
  final String questionType;
  final List<Map<String, dynamic>> options;
  final int likeCount;
  final int dislikeCount;
  final int totalVotes;
  final double likePercentage;
  final double dislikePercentage;
  final List<PollReasonBreakdown> likeReasons;
  final List<PollReasonBreakdown> dislikeReasons;
  final PollVote? userVote;

  const PollQuestion({
    required this.id,
    required this.text,
    this.personId,
    this.questionType = 'LIKE_DISLIKE',
    this.options = const [],
    required this.likeCount,
    required this.dislikeCount,
    required this.totalVotes,
    required this.likePercentage,
    required this.dislikePercentage,
    required this.likeReasons,
    required this.dislikeReasons,
    this.userVote,
  });

  bool get hasUserVoted => userVote != null;

  factory PollQuestion.fromJson(Map<String, dynamic> json) {
    final rawLikeReasons = json['likeReasons'] as List<dynamic>? ?? [];
    final rawDislikeReasons = json['dislikeReasons'] as List<dynamic>? ?? [];
    final rawOptions = json['options'] as List<dynamic>? ?? [];

    return PollQuestion(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      personId: json['personId'] as String?,
      questionType: json['questionType'] as String? ?? 'LIKE_DISLIKE',
      options: rawOptions.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      likeCount: json['likeCount'] as int? ?? 0,
      dislikeCount: json['dislikeCount'] as int? ?? 0,
      totalVotes: json['totalVotes'] as int? ?? 0,
      likePercentage: (json['likePercentage'] as num?)?.toDouble() ?? 0.0,
      dislikePercentage: (json['dislikePercentage'] as num?)?.toDouble() ?? 0.0,
      likeReasons: rawLikeReasons
          .map((e) => PollReasonBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
      dislikeReasons: rawDislikeReasons
          .map((e) => PollReasonBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
      userVote: json['userVote'] != null
          ? PollVote.fromJson(json['userVote'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        if (personId != null) 'personId': personId,
        'questionType': questionType,
        'options': options,
        'likeCount': likeCount,
        'dislikeCount': dislikeCount,
        'totalVotes': totalVotes,
        'likePercentage': likePercentage,
        'dislikePercentage': dislikePercentage,
        'likeReasons': likeReasons.map((e) => e.toJson()).toList(),
        'dislikeReasons': dislikeReasons.map((e) => e.toJson()).toList(),
        if (userVote != null) 'userVote': userVote!.toJson(),
      };
}

class Poll {
  final String id;
  final String? purpose;
  final String? category;
  final List<PollPerson> people;
  final List<PollQuestion> questions;

  // Legacy / top-level fields
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
  final Map<String, PollVote> userVotes;
  final int reportsCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Poll({
    required this.id,
    this.purpose,
    this.category,
    this.people = const [],
    this.questions = const [],
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
    this.userVotes = const {},
    this.reportsCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'ACTIVE' && (endTime == null || endTime!.isAfter(DateTime.now()));
  bool get isClosed => !isActive;
  bool get hasUserVoted => userVote != null || userVotes.isNotEmpty;
  bool get isMultiPerson => people.length > 1;
  bool get isMultiQuestion => questions.length > 1;

  String get shareUrl => '${AppConstants.shareBaseUrl}/polls/$id';

  String sharePayload({bool isHindi = false}) {
    final url = shareUrl;
    return isHindi
        ? 'जनमत सर्वेक्षण: $question\nअपना मत दर्ज करें और लाइव परिणाम देखें: $url'
        : 'Live Public Opinion Poll: $question\nCast your opinion and view live results: $url';
  }

  Poll copyWith({
    String? id,
    String? purpose,
    String? category,
    List<PollPerson>? people,
    List<PollQuestion>? questions,
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
    Map<String, PollVote>? userVotes,
    int? reportsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Poll(
      id: id ?? this.id,
      purpose: purpose ?? this.purpose,
      category: category ?? this.category,
      people: people ?? this.people,
      questions: questions ?? this.questions,
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
      userVotes: userVotes ?? this.userVotes,
      reportsCount: reportsCount ?? this.reportsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Poll.fromJson(Map<String, dynamic> json) {
    final rawLikeReasons = json['likeReasons'] as List<dynamic>? ?? [];
    final rawDislikeReasons = json['dislikeReasons'] as List<dynamic>? ?? [];
    final rawPeople = json['people'] as List<dynamic>? ?? [];
    final rawQuestions = json['questions'] as List<dynamic>? ?? [];
    final rawUserVotes = json['userVotes'] as Map<String, dynamic>? ?? {};

    final personName = json['personName'] as String? ?? '';
    final personRole = json['personRole'] as String?;
    final placeId = json['placeId'] as String?;
    final placeName = json['placeName'] as String?;
    final targetEntityId = json['targetEntityId'] as String?;
    final question = json['question'] as String? ?? '';
    final description = json['description'] as String?;
    final photoUrl = json['photoUrl'] as String?;

    final parsedPeople = rawPeople.isNotEmpty
        ? rawPeople.map((e) => PollPerson.fromJson(e as Map<String, dynamic>)).toList()
        : [
            PollPerson(
              id: 'p0',
              name: personName,
              role: personRole,
              designation: personRole,
              placeId: placeId,
              placeName: placeName,
              targetEntityId: targetEntityId,
              photoUrl: photoUrl,
            ),
          ];

    final parsedLikeReasons = rawLikeReasons
        .map((e) => PollReasonBreakdown.fromJson(e as Map<String, dynamic>))
        .toList();
    final parsedDislikeReasons = rawDislikeReasons
        .map((e) => PollReasonBreakdown.fromJson(e as Map<String, dynamic>))
        .toList();

    final userVoteObj = json['userVote'] != null
        ? PollVote.fromJson(json['userVote'] as Map<String, dynamic>)
        : null;

    final parsedUserVotes = <String, PollVote>{};
    rawUserVotes.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        parsedUserVotes[key] = PollVote.fromJson(val);
      }
    });

    final parsedQuestions = rawQuestions.isNotEmpty
        ? rawQuestions.map((e) => PollQuestion.fromJson(e as Map<String, dynamic>)).toList()
        : [
            PollQuestion(
              id: 'q0',
              text: question,
              personId: parsedPeople.isNotEmpty ? parsedPeople[0].id : null,
              questionType: 'LIKE_DISLIKE',
              likeCount: json['likeCount'] as int? ?? 0,
              dislikeCount: json['dislikeCount'] as int? ?? 0,
              totalVotes: json['totalVotes'] as int? ?? 0,
              likePercentage: (json['likePercentage'] as num?)?.toDouble() ?? 0.0,
              dislikePercentage: (json['dislikePercentage'] as num?)?.toDouble() ?? 0.0,
              likeReasons: parsedLikeReasons,
              dislikeReasons: parsedDislikeReasons,
              userVote: userVoteObj,
            ),
          ];

    return Poll(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      purpose: json['purpose'] as String?,
      category: json['category'] as String?,
      people: parsedPeople,
      questions: parsedQuestions,
      personName: personName,
      personRole: personRole,
      placeId: placeId,
      placeName: placeName,
      targetEntityId: targetEntityId,
      question: question,
      description: description,
      photoUrl: photoUrl,
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
      likeReasons: parsedLikeReasons,
      dislikeReasons: parsedDislikeReasons,
      userVote: userVoteObj,
      userVotes: parsedUserVotes,
      reportsCount: json['reportsCount'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (purpose != null) 'purpose': purpose,
        if (category != null) 'category': category,
        'people': people.map((e) => e.toJson()).toList(),
        'questions': questions.map((e) => e.toJson()).toList(),
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
        'userVotes': userVotes.map((k, v) => MapEntry(k, v.toJson())),
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
      key: 'transparency',
      labelEn: 'Transparency and accountability',
      labelHi: 'पारदर्शिता और जवाबदेही',
      icon: Icons.visibility_outlined,
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
      key: 'lack_transparency',
      labelEn: 'Lack of transparency or accountability',
      labelHi: 'पारदर्शिता या जवाबदेही की कमी',
      icon: Icons.visibility_off_outlined,
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
