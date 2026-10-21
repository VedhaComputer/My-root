class Evidence {
  final String id;
  final String claimId;
  final String sourceType;
  final String title;
  final String description;
  final String? url;
  final String? documentRef;
  final DateTime? dateOfEvidence;
  final String languageOfEvidence;
  final String uploadedBy;
  final DateTime uploadedAt;
  final String status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNotes;

  const Evidence({
    required this.id,
    required this.claimId,
    required this.sourceType,
    required this.title,
    required this.description,
    this.url,
    this.documentRef,
    this.dateOfEvidence,
    this.languageOfEvidence = 'en',
    required this.uploadedBy,
    required this.uploadedAt,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNotes,
  });

  bool get isVerified => status == 'verified';
  bool get isDisputed => status == 'disputed';
  bool get isRejected => status == 'rejected';
  bool get isSubmitted => status == 'submitted';

  factory Evidence.fromJson(Map<String, dynamic> json) => Evidence(
        id: (json['id'] ?? json['_id']) as String? ?? '',
        claimId: (json['claimId'] is Map
                ? json['claimId']['_id']
                : json['claimId']) as String? ??
            '',
        sourceType: json['sourceType'] as String? ?? 'OTHER',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        url: json['url'] as String?,
        documentRef: json['documentRef'] as String?,
        dateOfEvidence: json['dateOfEvidence'] != null
            ? DateTime.tryParse(json['dateOfEvidence'] as String)
            : null,
        languageOfEvidence:
            json['languageOfEvidence'] as String? ?? 'en',
        uploadedBy: (json['uploadedBy'] is Map
                ? json['uploadedBy']['_id']
                : json['uploadedBy']) as String? ??
            '',
        uploadedAt: json['uploadedAt'] != null
            ? DateTime.parse(json['uploadedAt'] as String)
            : DateTime.now(),
        status: json['status'] as String? ?? 'submitted',
        reviewedBy: (json['reviewedBy'] is Map
                ? json['reviewedBy']['_id']
                : json['reviewedBy']) as String?,
        reviewedAt: json['reviewedAt'] != null
            ? DateTime.tryParse(json['reviewedAt'] as String)
            : null,
        reviewNotes: json['reviewNotes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'claimId': claimId,
        'sourceType': sourceType,
        'title': title,
        'description': description,
        if (url != null) 'url': url,
        if (documentRef != null) 'documentRef': documentRef,
        if (dateOfEvidence != null)
          'dateOfEvidence': dateOfEvidence!.toIso8601String(),
        'languageOfEvidence': languageOfEvidence,
        'uploadedBy': uploadedBy,
        'uploadedAt': uploadedAt.toIso8601String(),
        'status': status,
        if (reviewedBy != null) 'reviewedBy': reviewedBy,
        if (reviewedAt != null) 'reviewedAt': reviewedAt!.toIso8601String(),
        if (reviewNotes != null) 'reviewNotes': reviewNotes,
      };
}
