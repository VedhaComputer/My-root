class LocalizedContent {
  final String original;
  final String language;
  const LocalizedContent({required this.original, required this.language});

  factory LocalizedContent.fromJson(Map<String, dynamic> json) => LocalizedContent(
        original: json['original'] as String,
        language: json['language'] as String,
      );

  Map<String, dynamic> toJson() => {'original': original, 'language': language};
}

class ClaimReview {
  final String id;
  final String? reviewerId;
  final String decisionStatus;
  final String reason;
  final DateTime timestamp;
  final String? reviewerNote;

  const ClaimReview({
    required this.id,
    this.reviewerId,
    required this.decisionStatus,
    required this.reason,
    required this.timestamp,
    this.reviewerNote,
  });

  factory ClaimReview.fromJson(Map<String, dynamic> json) => ClaimReview(
        id: json['id'] as String? ?? '',
        reviewerId: json['reviewerId'] as String?,
        decisionStatus: json['decisionStatus'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        timestamp: DateTime.parse(
            json['timestamp'] as String? ?? DateTime.now().toIso8601String()),
        reviewerNote: json['reviewerNote'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (reviewerId != null) 'reviewerId': reviewerId,
        'decisionStatus': decisionStatus,
        'reason': reason,
        'timestamp': timestamp.toIso8601String(),
        if (reviewerNote != null) 'reviewerNote': reviewerNote,
      };
}

class HistoryFeedback {
  final String id;
  final String userId;
  final String? previouslyKnown;
  final String? agreement;
  final String? comment;
  final String? knowsAuthor;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HistoryFeedback({
    required this.id,
    required this.userId,
    this.previouslyKnown,
    this.agreement,
    this.comment,
    this.knowsAuthor,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HistoryFeedback.fromJson(Map<String, dynamic> json) => HistoryFeedback(
        id: json['id'] as String? ?? json['_id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        previouslyKnown: json['previouslyKnown'] as String?,
        agreement: json['agreement'] as String?,
        comment: json['comment'] as String?,
        knowsAuthor: json['knowsAuthor'] as String?,
        createdAt: DateTime.parse(
          json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
        ),
        updatedAt: DateTime.parse(
          json['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        if (previouslyKnown != null) 'previouslyKnown': previouslyKnown,
        if (agreement != null) 'agreement': agreement,
        if (comment != null) 'comment': comment,
        if (knowsAuthor != null) 'knowsAuthor': knowsAuthor,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class Claim {
  final String id;
  final LocalizedContent title;
  final LocalizedContent body;
  final String category;
  final String status;
  final String locationId;
  final DateTime submittedAt;
  final String? submittedBy;
  final int evidenceCount;
  final bool isPublic;
  final List<String> tags;
  final String? communityTopic;
  final String? sourceAttribution;
  final String? timePeriod;
  final bool consentObtained;
  final String? consentDetails;
  final String? consentState;
  final String? userAgreementStatus;
  final ClaimReview? latestReview;
  final List<HistoryFeedback> communityFeedbacks;

  const Claim({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.status,
    required this.locationId,
    required this.submittedAt,
    this.submittedBy,
    required this.evidenceCount,
    required this.isPublic,
    required this.tags,
    this.communityTopic,
    this.sourceAttribution,
    this.timePeriod,
    this.consentObtained = false,
    this.consentDetails,
    this.consentState,
    this.userAgreementStatus,
    this.latestReview,
    this.communityFeedbacks = const [],
  });

  bool get isVerified => status == 'verified';
  bool get isDisputed => status == 'disputed';
  bool get isUnderReview => status == 'under_review' || status == 'submitted';
  bool get isFolklore => category == 'FOLKLORE';
  bool get isHistorical => category == 'HISTORICAL_RECORD';
  bool get isOpinion => category == 'PUBLIC_OPINION';
  bool get isDraft => status == 'draft';

  factory Claim.fromJson(Map<String, dynamic> json) => Claim(
        id: json['id'] as String,
        title: LocalizedContent.fromJson(json['title'] as Map<String, dynamic>),
        body: LocalizedContent.fromJson(json['body'] as Map<String, dynamic>),
        category: json['category'] as String,
        status: json['status'] as String,
        locationId: json['locationId'] as String? ?? '',
        submittedAt: DateTime.parse(json['submittedAt'] as String),
        submittedBy: json['submittedBy'] as String?,
        evidenceCount: json['evidenceCount'] as int? ?? 0,
        isPublic: json['isPublic'] as bool? ?? true,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        communityTopic: json['communityTopic'] as String?,
        sourceAttribution: json['sourceAttribution'] as String?,
        timePeriod: json['timePeriod'] as String?,
        consentObtained: json['consentObtained'] as bool? ?? false,
        consentDetails: json['consentDetails'] as String?,
        consentState: json['consentState'] as String?,
        userAgreementStatus: json['userAgreementStatus'] as String?,
        latestReview: json['latestReview'] != null
            ? ClaimReview.fromJson(json['latestReview'] as Map<String, dynamic>)
            : null,
        communityFeedbacks: (json['communityFeedbacks'] as List<dynamic>? ?? [])
            .map((f) => HistoryFeedback.fromJson(f as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title.toJson(),
        'body': body.toJson(),
        'category': category,
        'status': status,
        'locationId': locationId,
        'submittedAt': submittedAt.toIso8601String(),
        if (submittedBy != null) 'submittedBy': submittedBy,
        'evidenceCount': evidenceCount,
        'isPublic': isPublic,
        'tags': tags,
        if (communityTopic != null) 'communityTopic': communityTopic,
        if (sourceAttribution != null) 'sourceAttribution': sourceAttribution,
        if (timePeriod != null) 'timePeriod': timePeriod,
        'consentObtained': consentObtained,
        if (consentDetails != null) 'consentDetails': consentDetails,
        if (consentState != null) 'consentState': consentState,
        if (userAgreementStatus != null) 'userAgreementStatus': userAgreementStatus,
        if (latestReview != null) 'latestReview': latestReview!.toJson(),
        'communityFeedbacks': communityFeedbacks.map((f) => f.toJson()).toList(),
      };
}
