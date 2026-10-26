// Domain models for Elected Representatives, Constitutional Duties, Legal Powers,
// Citizen Guidance, and Statutory Legal Citations.

enum RepresentativeRole {
  sarpanch,
  wardPanch,
  panchayatSamitiChairperson,
  panchayatSamitiMember,
  zilaParishadChairperson,
  zilaParishadMember,
  municipalCouncillor,
  municipalChairperson,
  mla,
  mp,
}

extension RepresentativeRoleExt on RepresentativeRole {
  String get key {
    switch (this) {
      case RepresentativeRole.sarpanch:
        return 'sarpanch';
      case RepresentativeRole.wardPanch:
        return 'ward_panch';
      case RepresentativeRole.panchayatSamitiChairperson:
        return 'panchayat_samiti_chairperson';
      case RepresentativeRole.panchayatSamitiMember:
        return 'panchayat_samiti';
      case RepresentativeRole.zilaParishadChairperson:
        return 'zila_parishad_chairperson';
      case RepresentativeRole.zilaParishadMember:
        return 'zila_parishad';
      case RepresentativeRole.municipalCouncillor:
        return 'councillor';
      case RepresentativeRole.municipalChairperson:
        return 'mayor';
      case RepresentativeRole.mla:
        return 'mla';
      case RepresentativeRole.mp:
        return 'mp';
    }
  }

  String get titleEn {
    switch (this) {
      case RepresentativeRole.sarpanch:
        return 'Sarpanch (Gram Panchayat Head)';
      case RepresentativeRole.wardPanch:
        return 'Ward Member (Panch)';
      case RepresentativeRole.panchayatSamitiChairperson:
        return 'Panchayat Samiti Chairperson (Block Pramukh)';
      case RepresentativeRole.panchayatSamitiMember:
        return 'Panchayat Samiti Member (BDC / Block Level)';
      case RepresentativeRole.zilaParishadChairperson:
        return 'Zila Parishad Chairperson (Zila Pramukh / President)';
      case RepresentativeRole.zilaParishadMember:
        return 'Zila Parishad Member (District Level)';
      case RepresentativeRole.municipalCouncillor:
        return 'Ward Councillor / Municipal Member';
      case RepresentativeRole.municipalChairperson:
        return 'Municipal Chairperson / Mayor';
      case RepresentativeRole.mla:
        return 'Member of Legislative Assembly (MLA)';
      case RepresentativeRole.mp:
        return 'Member of Parliament (MP)';
    }
  }

  String get titleHi {
    switch (this) {
      case RepresentativeRole.sarpanch:
        return 'सरपंच (ग्राम पंचायत प्रधान)';
      case RepresentativeRole.wardPanch:
        return 'वार्ड पंच (ग्राम पंचायत सदस्य)';
      case RepresentativeRole.panchayatSamitiChairperson:
        return 'पंचायत समिति अध्यक्ष (ब्लॉक प्रमुख)';
      case RepresentativeRole.panchayatSamitiMember:
        return 'पंचायत समिति सदस्य (BDC / ब्लॉक स्तर)';
      case RepresentativeRole.zilaParishadChairperson:
        return 'जिला परिषद अध्यक्ष (जिला प्रमुख)';
      case RepresentativeRole.zilaParishadMember:
        return 'जिला परिषद सदस्य (जिला स्तर)';
      case RepresentativeRole.municipalCouncillor:
        return 'वार्ड पार्षद / नगर पालिका सदस्य';
      case RepresentativeRole.municipalChairperson:
        return 'नगर पालिका अध्यक्ष / मेयर';
      case RepresentativeRole.mla:
        return 'विधायक (विधान सभा सदस्य - MLA)';
      case RepresentativeRole.mp:
        return 'सांसद (संसद सदस्य - MP)';
    }
  }

  String get levelApplicable {
    switch (this) {
      case RepresentativeRole.sarpanch:
      case RepresentativeRole.wardPanch:
        return 'VILLAGE';
      case RepresentativeRole.panchayatSamitiChairperson:
      case RepresentativeRole.panchayatSamitiMember:
        return 'BLOCK';
      case RepresentativeRole.zilaParishadChairperson:
      case RepresentativeRole.zilaParishadMember:
        return 'DISTRICT';
      case RepresentativeRole.municipalCouncillor:
      case RepresentativeRole.municipalChairperson:
        return 'CITY_TOWN';
      case RepresentativeRole.mla:
        return 'STATE_CONSTITUENCY';
      case RepresentativeRole.mp:
        return 'PARLIAMENTARY_CONSTITUENCY';
    }
  }
}

/// Six structured categories of duties and powers mandated by civic governance
enum DutyCategory {
  publicAssets,
  schemesAndBeneficiaries,
  meetingsAndBudgets,
  socialSectorCoordination,
  welfareAndDisaster,
  legalLimitsAndExclusions,
}

extension DutyCategoryExt on DutyCategory {
  String get titleEn {
    switch (this) {
      case DutyCategory.publicAssets:
        return 'Roads, Drainage, Water, Sanitation & Public Assets';
      case DutyCategory.schemesAndBeneficiaries:
        return 'Government Schemes & Eligible Beneficiary Assistance';
      case DutyCategory.meetingsAndBudgets:
        return 'Meetings, Development Plans, Budgets & Accountability';
      case DutyCategory.socialSectorCoordination:
        return 'Education, Anganwadi, Health, Agriculture & Coordination';
      case DutyCategory.welfareAndDisaster:
        return 'Public Welfare, Community Issues & Disaster Response';
      case DutyCategory.legalLimitsAndExclusions:
        return 'Legal Limits, Approvals & Matters Outside Authority';
    }
  }

  String get titleHi {
    switch (this) {
      case DutyCategory.publicAssets:
        return 'सड़क, जल निकासी, पेयजल, स्वच्छता व सार्वजनिक संपत्तियां';
      case DutyCategory.schemesAndBeneficiaries:
        return 'सरकारी योजनाएं व पात्र लाभार्थी सहायता (मनरेगा, आवास आदि)';
      case DutyCategory.meetingsAndBudgets:
        return 'ग्राम सभा/पंचायत बैठकें, विकास योजनाएं, बजट व जवाबदेही';
      case DutyCategory.socialSectorCoordination:
        return 'शिक्षा, आंगनवाड़ी, स्वास्थ्य, कृषि व विभागीय समन्वय';
      case DutyCategory.welfareAndDisaster:
        return 'जन कल्याण, सामुदायिक समस्याएं व आपदा प्रबंधन';
      case DutyCategory.legalLimitsAndExclusions:
        return 'कानूनी सीमाएं, स्वीकृतियां व अधिकार क्षेत्र से बाहर के कार्य';
    }
  }
}

/// Four clear responsibility classifications to eliminate public confusion
enum ResponsibilityType {
  statutoryDuty,
  collectiveResponsibility,
  requiresApproval,
  departmentalResponsibility,
}

extension ResponsibilityTypeExt on ResponsibilityType {
  String get labelEn {
    switch (this) {
      case ResponsibilityType.statutoryDuty:
        return 'Statutory Duty of Elected Person';
      case ResponsibilityType.collectiveResponsibility:
        return 'Collective Responsibility (Panchayat / Gram Sabha)';
      case ResponsibilityType.requiresApproval:
        return 'Requires Formal Approval / Prescribed Procedure';
      case ResponsibilityType.departmentalResponsibility:
        return 'Line Department Responsibility (PWD, PHED, Discom, etc.)';
    }
  }

  String get labelHi {
    switch (this) {
      case ResponsibilityType.statutoryDuty:
        return 'प्रतिनिधि का वैधानिक दायित्व';
      case ResponsibilityType.collectiveResponsibility:
        return 'सामूहिक दायित्व (पंचायत / ग्राम सभा)';
      case ResponsibilityType.requiresApproval:
        return 'विहित प्रक्रिया / उच्चाधिकारी स्वीकृति आवश्यक';
      case ResponsibilityType.departmentalResponsibility:
        return 'संबंधित सरकारी विभाग का दायित्व';
    }
  }

  String get badgeNameEn {
    switch (this) {
      case ResponsibilityType.statutoryDuty:
        return 'Statutory Duty';
      case ResponsibilityType.collectiveResponsibility:
        return 'Collective Decision';
      case ResponsibilityType.requiresApproval:
        return 'Approval Required';
      case ResponsibilityType.departmentalResponsibility:
        return 'Departmental Task';
    }
  }

  String get badgeNameHi {
    switch (this) {
      case ResponsibilityType.statutoryDuty:
        return 'वैधानिक दायित्व';
      case ResponsibilityType.collectiveResponsibility:
        return 'सामूहिक निर्णय';
      case ResponsibilityType.requiresApproval:
        return 'स्वीकृति आवश्यक';
      case ResponsibilityType.departmentalResponsibility:
        return 'विभागीय कार्य';
    }
  }
}

/// A specific duty item within a category
class DutyItem {
  final String titleEn;
  final String titleHi;
  final String descriptionEn;
  final String descriptionHi;
  final ResponsibilityType responsibilityType;
  final String? procedureOrApprovalEn;
  final String? procedureOrApprovalHi;
  final String? lineDepartmentEn;
  final String? lineDepartmentHi;
  final String? statutoryCitation;
  final String? limitationEn;
  final String? limitationHi;
  final String? jurisdictionScopeEn;
  final String? jurisdictionScopeHi;
  final String? verificationStatusEn;
  final String? verificationStatusHi;

  const DutyItem({
    required this.titleEn,
    required this.titleHi,
    required this.descriptionEn,
    required this.descriptionHi,
    required this.responsibilityType,
    this.procedureOrApprovalEn,
    this.procedureOrApprovalHi,
    this.lineDepartmentEn,
    this.lineDepartmentHi,
    this.statutoryCitation,
    this.limitationEn,
    this.limitationHi,
    this.jurisdictionScopeEn,
    this.jurisdictionScopeHi,
    this.verificationStatusEn,
    this.verificationStatusHi,
  });
}

/// Grouping of duties by category
class DutyCategorySection {
  final DutyCategory category;
  final String? customTitleEn;
  final String? customTitleHi;
  final List<DutyItem> items;

  const DutyCategorySection({
    required this.category,
    this.customTitleEn,
    this.customTitleHi,
    required this.items,
  });
}

/// Direct citizen FAQ answering everyday practical questions
class CitizenQaItem {
  final String questionEn;
  final String questionHi;
  final String answerEn;
  final String answerHi;

  const CitizenQaItem({
    required this.questionEn,
    required this.questionHi,
    required this.answerEn,
    required this.answerHi,
  });
}

/// Legal source citation grounding duties in statutory law
class LegalSourceReference {
  final String sourceTitle;
  final String relevantSections;
  final String jurisdictionState;
  final String sourceUrl;
  final String lastVerifiedDate;
  final bool isStateSpecific;
  final String officialGuidanceNoteEn;
  final String officialGuidanceNoteHi;

  const LegalSourceReference({
    required this.sourceTitle,
    required this.relevantSections,
    required this.jurisdictionState,
    required this.sourceUrl,
    required this.lastVerifiedDate,
    required this.isStateSpecific,
    required this.officialGuidanceNoteEn,
    required this.officialGuidanceNoteHi,
  });
}

/// Reusable profile for an elected post containing all statutory duties, Q&A, and limits
class RepresentativeRoleProfile {
  final RepresentativeRole role;
  final String titleEn;
  final String titleHi;
  final String governingBodyEn;
  final String governingBodyHi;
  final String constitutionalPostSummaryEn;
  final String constitutionalPostSummaryHi;
  final LegalSourceReference legalReference;
  final List<DutyCategorySection> categories;
  final List<CitizenQaItem> citizenQa;
  final List<String> legalLimitationsEn;
  final List<String> legalLimitationsHi;
  final String grievanceEscalationEn;
  final String grievanceEscalationHi;

  const RepresentativeRoleProfile({
    required this.role,
    required this.titleEn,
    required this.titleHi,
    required this.governingBodyEn,
    required this.governingBodyHi,
    required this.constitutionalPostSummaryEn,
    required this.constitutionalPostSummaryHi,
    required this.legalReference,
    required this.categories,
    required this.citizenQa,
    required this.legalLimitationsEn,
    required this.legalLimitationsHi,
    required this.grievanceEscalationEn,
    required this.grievanceEscalationHi,
  });
}
