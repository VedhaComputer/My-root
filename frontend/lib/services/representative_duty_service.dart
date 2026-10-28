import '../models/place.dart';
import '../models/representative_duty.dart';

class RepresentativeDutyService {
  static const String haryanaActPdfUrl =
      'https://www.haryanadp.gov.in/wp-content/uploads/2024/12/Haryana-Panchayati-Raj-Act-1994-English-1.pdf';
  static const String rajasthanActUrl = 'https://panchayat.rajasthan.gov.in';
  static const String moprUrl = 'https://panchayat.gov.in';

  /// Resolves the canonical state/UT code from a Place's hierarchy, canonical name, or ID.
  /// Returns canonical identifier (e.g., 'haryana', 'rajasthan', 'uttar_pradesh') or null if unknown/unsupported.
  static String? resolveStateIdentifier(Place place) {
    if (place.parentPath != null) {
      for (final p in place.parentPath!) {
        if (p.level.toUpperCase() == 'STATE') {
          final id = _normalizeStateIdentifier(p.id, p.canonicalName);
          if (id != null) return id;
        }
      }
    }
    if (place.level.toUpperCase() == 'STATE') {
      final id = _normalizeStateIdentifier(place.id, place.canonicalName);
      if (id != null) return id;
    }
    if (place.parentPath != null) {
      for (final p in place.parentPath!) {
        final id = _normalizeStateIdentifier(p.id, p.canonicalName);
        if (id != null) return id;
      }
    }
    return _normalizeStateIdentifier(place.id, place.canonicalName);
  }

  static String? _normalizeStateIdentifier(String id, String canonicalName) {
    final combined = '${id.toLowerCase()} ${canonicalName.toLowerCase()}';
    if (combined.contains('haryana')) return 'haryana';
    if (combined.contains('rajasthan')) return 'rajasthan';
    if (combined.contains('uttar pradesh') || id.toLowerCase().endsWith('-up') || id.toLowerCase().contains('state-up')) {
      return 'uttar_pradesh';
    }
    if (combined.contains('punjab')) return 'punjab';
    if (combined.contains('madhya pradesh') || id.toLowerCase().endsWith('-mp')) {
      return 'madhya_pradesh';
    }
    if (combined.contains('bihar')) return 'bihar';
    if (combined.contains('maharashtra')) return 'maharashtra';
    if (combined.contains('gujarat')) return 'gujarat';
    return null;
  }

  /// Determines if a place is located within Haryana based on its canonical hierarchy
  static bool isHaryanaPlace(Place place) {
    return resolveStateIdentifier(place) == 'haryana';
  }

  /// Extracts the state name for jurisdiction context
  static String extractStateName(Place place) {
    if (place.level.toUpperCase() == 'STATE') return place.canonicalName;
    if (place.parentPath != null) {
      for (final p in place.parentPath!) {
        if (p.level.toUpperCase() == 'STATE') return p.canonicalName;
      }
    }
    final resolved = resolveStateIdentifier(place);
    if (resolved == 'haryana') return 'Haryana';
    if (resolved == 'rajasthan') return 'Rajasthan';
    if (resolved == 'uttar_pradesh') return 'Uttar Pradesh';
    if (resolved == 'punjab') return 'Punjab';
    if (resolved == 'madhya_pradesh') return 'Madhya Pradesh';
    if (resolved == 'bihar') return 'Bihar';
    if (resolved == 'maharashtra') return 'Maharashtra';
    if (resolved == 'gujarat') return 'Gujarat';
    return 'General Jurisdiction';
  }

  /// Returns the applicable representative roles for a given place based on administrative level
  static List<RepresentativeRole> getApplicableRoles(String placeLevel) {
    final upper = placeLevel.toUpperCase();
    if (upper == 'VILLAGE') {
      return const [
        RepresentativeRole.sarpanch,
        RepresentativeRole.wardPanch,
        RepresentativeRole.panchayatSamitiChairperson,
        RepresentativeRole.panchayatSamitiMember,
        RepresentativeRole.zilaParishadChairperson,
        RepresentativeRole.zilaParishadMember,
        RepresentativeRole.mla,
        RepresentativeRole.mp,
      ];
    } else if (upper == 'CITY_TOWN') {
      return const [
        RepresentativeRole.municipalChairperson,
        RepresentativeRole.municipalCouncillor,
        RepresentativeRole.mayor,
        RepresentativeRole.deputyMayor,
        RepresentativeRole.municipalViceChairperson,
        RepresentativeRole.municipalCommitteeMember,
        RepresentativeRole.municipalCommissioner,
        RepresentativeRole.executiveOfficer,
        RepresentativeRole.municipalSecretary,
        RepresentativeRole.mla,
        RepresentativeRole.mp,
      ];
    } else if (upper == 'SUB_DISTRICT' || upper == 'TEHSIL' || upper == 'BLOCK') {
      return const [
        RepresentativeRole.panchayatSamitiChairperson,
        RepresentativeRole.panchayatSamitiMember,
        RepresentativeRole.zilaParishadChairperson,
        RepresentativeRole.zilaParishadMember,
        RepresentativeRole.mla,
        RepresentativeRole.mp,
      ];
    } else if (upper == 'DISTRICT') {
      return const [
        RepresentativeRole.zilaParishadChairperson,
        RepresentativeRole.zilaParishadMember,
        RepresentativeRole.mla,
        RepresentativeRole.mp,
      ];
    } else {
      return const [
        RepresentativeRole.mla,
        RepresentativeRole.mp,
      ];
    }
  }

  /// Retrieves the detailed statutory role profile
  static RepresentativeRoleProfile getProfile(
    RepresentativeRole role, {
    bool? isHaryana,
    Place? place,
    String? stateIdentifier,
  }) {
    final String? effectiveState = stateIdentifier ??
        (place != null ? resolveStateIdentifier(place) : (isHaryana == true ? 'haryana' : null));
    final bool haryanaFlag = effectiveState == 'haryana';

    switch (role) {
      case RepresentativeRole.sarpanch:
        return _buildSarpanchProfile(haryanaFlag);
      case RepresentativeRole.wardPanch:
        return _buildWardPanchProfile(haryanaFlag);
      case RepresentativeRole.panchayatSamitiChairperson:
        return _buildPanchayatSamitiChairpersonProfile(haryanaFlag);
      case RepresentativeRole.panchayatSamitiMember:
        return _buildPanchayatSamitiMemberProfile(haryanaFlag);
      case RepresentativeRole.zilaParishadChairperson:
        return _buildZilaParishadChairpersonProfile(effectiveState);
      case RepresentativeRole.zilaParishadMember:
        return _buildZilaParishadMemberProfile(effectiveState);
      case RepresentativeRole.municipalCouncillor:
        return _buildMunicipalCouncillorProfile(haryanaFlag);
      case RepresentativeRole.municipalChairperson:
        return _buildMunicipalChairpersonProfile(haryanaFlag);
      case RepresentativeRole.mayor:
        return _buildMayorProfile(effectiveState);
      case RepresentativeRole.deputyMayor:
        return _buildDeputyMayorProfile(effectiveState);
      case RepresentativeRole.municipalViceChairperson:
        return _buildMunicipalViceChairpersonProfile(haryanaFlag);
      case RepresentativeRole.municipalCommitteeMember:
        return _buildMunicipalCommitteeMemberProfile(haryanaFlag);
      case RepresentativeRole.municipalCommissioner:
        return _buildMunicipalCommissionerProfile(effectiveState);
      case RepresentativeRole.executiveOfficer:
        return _buildExecutiveOfficerProfile(haryanaFlag);
      case RepresentativeRole.municipalSecretary:
        return _buildMunicipalSecretaryProfile(haryanaFlag);
      case RepresentativeRole.mla:
        return _buildMlaProfile(effectiveState);
      case RepresentativeRole.mp:
        return _buildMpProfile(effectiveState, place: place);
    }
  }

  // =========================================================================
  // SARPANCH (Gram Panchayat Executive Head)
  // =========================================================================
  static RepresentativeRoleProfile _buildSarpanchProfile(bool isHaryana) {
    return RepresentativeRoleProfile(
      role: RepresentativeRole.sarpanch,
      titleEn: 'Sarpanch (Gram Panchayat Head)',
      titleHi: 'सरपंच (ग्राम पंचायत प्रधान)',
      governingBodyEn: 'Gram Panchayat',
      governingBodyHi: 'ग्राम पंचायत',
      constitutionalPostSummaryEn:
          'Executive head of the Gram Panchayat responsible for convening Gram Sabha and Gram Panchayat meetings, maintaining village records, supervising village public works, and jointly operating the Gram Fund with the Gram Sachiv under statutory rules.',
      constitutionalPostSummaryHi:
          'ग्राम पंचायत के कार्यकारी प्रमुख, जिनका दायित्व ग्राम सभा व ग्राम पंचायत की बैठकें बुलाना, गांव के रिकॉर्ड सुरक्षित रखना, सार्वजनिक कार्यों की देखरेख करना और ग्राम सचिव के साथ मिलकर विहित नियमों के तहत ग्राम निधि का संचालन करना है।',
      legalReference: LegalSourceReference(
        sourceTitle: isHaryana
            ? 'The Haryana Panchayati Raj Act, 1994 (Haryana Act No. 11 of 1994)'
            : 'General Model Guidance (Constitution 73rd Amendment & Model Panchayati Raj Framework)',
        relevantSections: isHaryana
            ? 'Sections 11 (Gram Sabha), 13 (GP Meetings), 19 (Duties of Sarpanch), 21 (Functions), 24 (Encroachments), 39 (Gram Fund)'
            : 'Article 243G & Eleventh Schedule (State-specific statute governs executive thresholds)',
        jurisdictionState: isHaryana ? 'Haryana' : 'General / Model Framework',
        sourceUrl: isHaryana ? haryanaActPdfUrl : moprUrl,
        lastVerifiedDate: '2026-10-26',
        isStateSpecific: isHaryana,
        officialGuidanceNoteEn: isHaryana
            ? 'Official statutory provisions under Haryana Department of Development and Panchayats.'
            : 'General Model Guidance. Consult the respective State Panchayati Raj Act for local financial powers.',
        officialGuidanceNoteHi: isHaryana
            ? 'हरियाणा विकास एवं पंचायत विभाग के अंतर्गत आधिकारिक वैधानिक प्रावधान।'
            : 'सामान्य मॉडल मार्गदर्शन। वित्तीय शक्तियों के लिए संबंधित राज्य के पंचायती राज अधिनियम का संदर्भ लें।',
      ),
      citizenQa: const [
        CitizenQaItem(
          questionEn: 'What can this representative do? (What can a Sarpanch do for the village?)',
          questionHi: 'सरपंच गांव के लिए क्या-क्या कर सकते हैं?',
          answerEn:
              'A Sarpanch convenes Gram Sabha meetings to pass village development plans, proposes works for streets, drains, drinking water pipelines, and streetlights, mobilizes residents for MGNREGA employment, and reports encroachment on community land.',
          answerHi:
              'सरपंच ग्राम सभा की बैठक बुलाकर गांव की विकास योजनाएं पारित करवा सकते हैं, गली-नाली, पेयजल, स्ट्रीट लाइट के कार्य प्रस्तावित कर सकते हैं, मनरेगा में रोजगार व परिसंपत्ति निर्माण की देखरेख कर सकते हैं और शामलात भूमि से अवैध कब्जा हटाने की कार्यवाही शुरू कर सकते हैं।',
        ),
        CitizenQaItem(
          questionEn: 'What is the Sarpanch personally responsible for?',
          questionHi: 'सरपंच की व्यक्तिगत जिम्मेदारी क्या है?',
          answerEn:
              'Convening mandatory Gram Sabha and Panchayat meetings, ensuring Gram Panchayat registers and asset records are safely preserved, co-signing development expenditures with the Gram Sachiv strictly per sanctioned resolutions, and reporting epidemics or disasters to block authorities.',
          answerHi:
              'अनिवार्य ग्राम सभा व पंचायत बैठकें आयोजित करना, पंचायत रिकॉर्ड व संपत्ति पंजिकाओं की सुरक्षा सुनिश्चित करना, स्वीकृत प्रस्तावों के अनुसार ग्राम सचिव के साथ संयुक्त रूप से विकास कार्यों के भुगतान पर हस्ताक्षर करना और आपदा या महामारी की सूचना तुरंत उच्चाधिकारियों को देना।',
        ),
        CitizenQaItem(
          questionEn: 'Which works require higher approval or Gram Sabha sanction?',
          questionHi: 'किस काम में किसकी मंजूरी चाहिए?',
          answerEn:
              'Development plans and beneficiary selection (PM Awas, pensions) require approval of the Gram Sabha. Works exceeding local financial thresholds require technical sanction from the Panchayati Raj Engineering Wing and administrative approval from the BDPO or Deputy Commissioner. The Sarpanch cannot unilaterally sanction unbudgeted projects.',
          answerHi:
              'वार्षिक विकास योजना व पात्र लाभार्थियों की सूची (पीएम आवास, पेंशन आदि) को ग्राम सभा की मंजूरी अनिवार्य है। निर्धारित वित्तीय सीमा से अधिक के कार्यों के लिए पंचायती राज इंजीनियरिंग विंग से तकनीकी मंजूरी व बीडीपीओ/उपायुक्त से प्रशासनिक स्वीकृति जरूरी होती है। सरपंच अकेले किसी गैर-स्वीकृत कार्य पर पैसा खर्च नहीं कर सकते।',
        ),
        CitizenQaItem(
          questionEn: 'Which works belong to other government departments?',
          questionHi: 'ये काम किस विभाग का है?',
          answerEn:
              'Main highways and PWD roads belong to Public Works Department (PWD); major drinking water tubewells and sewer networks belong to Public Health Engineering Department (PHED); electricity transformers belong to Power Discom; ration distribution belongs to Food & Civil Supplies; law and order belongs to State Police.',
          answerHi:
              'मुख्य सड़कें लोक निर्माण विभाग (PWD) के अधीन हैं; बड़ी पेयजल योजनाएं जनस्वास्थ्य अभियांत्रिकी (PHED) के पास हैं; ट्रांसफार्मर व बिजली आपूर्ति बिजली निगम (Discom) के पास है; राशन कार्ड व अनाज वितरण खाद्य एवं आपूर्ति विभाग के पास है; और कानून-व्यवस्था पुलिस प्रशासन का काम है।',
        ),
        CitizenQaItem(
          questionEn: 'Where can citizens raise a concern or grievance?',
          questionHi: 'शिकायत कहाँ और कैसे करें?',
          answerEn:
              'First raise the issue in the open Gram Sabha meeting or submit a written representation to the Gram Sachiv/Sarpanch. If unresolved or in cases of irregularities, escalate to the Block Development & Panchayat Officer (BDPO), the Additional Deputy Commissioner (ADC), or submit via CM Window Haryana (cmwindow.haryana.gov.in) / State Grievance Portal.',
          answerHi:
              'सबसे पहले खुली ग्राम सभा बैठक में मुद्दा उठाएं या ग्राम सचिव/सरपंच को लिखित प्रतिवेदन दें। यदि समाधान न हो या वित्तीय अनियमितता हो, तो खंड विकास एवं पंचायत अधिकारी (BDPO), अतिरिक्त उपायुक्त (ADC) से संपर्क करें या हरियाणा सीएम विंडो (cmwindow.haryana.gov.in) पर ऑनलाइन शिकायत दर्ज करें।',
        ),
      ],
      legalLimitationsEn: const [
        'Cannot unilaterally expend Gram Panchayat funds or withdraw money without a formal resolution passed by the Gram Panchayat and co-signature of the Gram Sachiv (Sec. 39).',
        'Cannot issue character certificates or residential certificates contrary to official revenue records or beyond prescribed statutory powers.',
        'Does not hold power to sanction government pensions or ration cards; these require verification and sanction by the Social Welfare and Food & Civil Supplies departments.',
        'Has no judicial or police power to adjudicate criminal cases or detain any citizen.',
        'Cannot sell, lease, or transfer Gram Panchayat or Shamlat Deh land without prior statutory sanction of the State Government.',
      ],
      legalLimitationsHi: const [
        'ग्राम पंचायत के विधिवत पारित प्रस्ताव और ग्राम सचिव के संयुक्त हस्ताक्षर के बिना ग्राम निधि से अकेले राशि खर्च करने का कोई अधिकार नहीं है (धारा 39)।',
        'सरकारी राजस्व रिकॉर्ड के विपरीत या विहित कानूनी अधिकार से बाहर प्रमाण पत्र जारी करने का कोई अधिकार नहीं है।',
        'वृद्धावस्था/दिव्यांग पेंशन या राशन कार्ड स्वीकृत करने का व्यक्तिगत अधिकार नहीं है; यह संबंधित विभागों (समाज कल्याण/खाद्य आपूर्ति) का कार्य है।',
        'किसी भी प्रकार के आपराधिक मामलों में फैसला सुनाने या दंड देने का कोई न्यायिक या पुलिस अधिकार नहीं है।',
        'राज्य सरकार की पूर्व अनुमति के बिना ग्राम पंचायत या शामलात देह भूमि को बेचने, पट्टे पर देने या अंतरित करने का अधिकार नहीं है।',
      ],
      grievanceEscalationEn:
          'Informal: Written request to Sarpanch / Gram Sachiv (Panchayat Secretary) -> Gram Sabha Discussion.\nFormal Regulatory: Block Development & Panchayat Officer (BDPO) -> CEO, Zila Parishad / Additional Deputy Commissioner (ADC) -> Deputy Commissioner.\nState Vigilance / Integrity: CM Window Haryana (cmwindow.haryana.gov.in), Lokayukta Haryana.',
      grievanceEscalationHi:
          'स्थानीय स्तर: सरपंच / ग्राम सचिव को लिखित आवेदन -> ग्राम सभा में चर्चा।\nप्रशासनिक स्तर: खंड विकास एवं पंचायत अधिकारी (BDPO) -> मुख्य कार्यकारी अधिकारी (CEO) जिला परिषद / अतिरिक्त उपायुक्त (ADC) -> उपायुक्त।\nराज्य स्तर: सीएम विंडो हरियाणा पोर्टल (cmwindow.haryana.gov.in), लोकायुक्त हरियाणा।',
      categories: const [
        DutyCategorySection(
          category: DutyCategory.publicAssets,
          items: [
            DutyItem(
              titleEn: 'Village Internal Streets and Drainage Construction',
              titleHi: 'गांव की आंतरिक गलियों व नालियों का निर्माण व मरम्मत',
              descriptionEn:
                  'Supervise paving of village streets, open drain cleaning, and construction of culverts using Gram Panchayat funds.',
              descriptionHi:
                  'ग्राम पंचायत निधि से गांव की गलियों को पक्का करना, नालियों की सफाई व पुलियों के निर्माण की देखरेख करना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              additionalResponsibilityTypes: [ResponsibilityType.requiresApproval],
              procedureOrApprovalEn: 'Gram Panchayat resolution + Technical sanction from Panchayati Raj JE/SDO.',
              procedureOrApprovalHi: 'ग्राम पंचायत का प्रस्ताव + कनिष्ठ अभियंता (JE) से तकनीकी स्वीकृति।',
              representativeRoleEn: 'Inspects site needs, tables resolution in Panchayat meeting, and co-signs payment voucher with Gram Sachiv only after measurement.',
              representativeRoleHi: 'मौके की जरूरत देखकर पंचायत बैठक में प्रस्ताव रखते हैं, काम पूरा होने और जेई द्वारा माप दर्ज करने के बाद ही ग्राम सचिव के साथ संयुक्त भुगतान वाउचर पर हस्ताक्षर करते हैं।',
              activitiesIncludedEn: 'Paving earthen streets with CC/interlocking paver blocks, constructing covered roadside drains, building small culverts, and clearing wastewater blockages.',
              activitiesIncludedHi: 'कच्ची गलियों में सीसी या इंटरलॉकिंग पेवर ब्लॉक बिछाना, ढकी हुई नालियां बनाना, छोटी पुलियों का निर्माण और गंदे पानी की निकासी व्यवस्था दुरुस्त करना।',
              intendedResultEn: 'All-weather clean streets without waterlogging, reduced vector diseases, and safe pedestrian and vehicular movement inside the village.',
              intendedResultHi: 'जलभराव मुक्त पक्की गलियां, कीचड़ और मच्छरों से राहत तथा ग्रामीणों के आवागमन के लिए सुरक्षित व स्वच्छ रास्ते।',
              practicalProcessEn:
                  'Gram Sabha proposal -> Gram Panchayat formal resolution -> Panchayati Raj Engineering Wing technical sanction -> Execution via quotation or e-tendering pursuant to state procurement rules (financial threshold verification pending) -> Measurement Book (MB) verification by JE/SDO.',
              practicalProcessHi:
                  'ग्राम सभा प्रस्ताव -> ग्राम पंचायत का विधिवत संकल्प -> पंचायती राज इंजीनियरिंग विंग से तकनीकी मंजूरी -> राज्य खरीद नियमों अनुसार कोटेशन या ई-टेंडर द्वारा कार्य (वित्तीय सीमा सत्यापन लंबित) -> कनिष्ठ अभियंता (JE) द्वारा माप पुस्तिका (MB) में अंकन।',
              verificationEvidenceEn: 'Gram Sabha proceedings register, e-GramSwaraj portal work code, Measurement Book (MB) entry signed by JE/SDO, and public asset register.',
              verificationEvidenceHi: 'ग्राम सभा कार्यवाही रजिस्टर, ई-ग्रामस्वराज पोर्टल वर्क कोड, कनिष्ठ अभियंता (JE) द्वारा हस्ताक्षरित माप पुस्तिका (MB) प्रविष्टि और पंचायत संपत्ति रजिस्टर।',
              statutoryCitation:
                  'Haryana Panchayati Raj Act 1994, Sec 21(XVIII) (Rural Sanitation - Roads & Drains) & Sec 39 (Gram Fund); Construction/Tendering governed by PR Engineering Rules & State Procurement Guidelines',
            ),
            DutyItem(
              titleEn: 'Maintenance of Village Drinking Water Taps and Public Handpumps',
              titleHi: 'सार्वजनिक पेयजल नलों व हैंडपंपों का रखरखाव',
              descriptionEn:
                  'Ensure cleanliness around public water points, repair community handpumps, and report pipe leakages to the Public Health Engineering Department (PHED).',
              descriptionHi:
                  'सार्वजनिक नलों के आसपास स्वच्छता, हैंडपंपों की मरम्मत व लीकेज की सूचना जनस्वास्थ्य विभाग को देना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              additionalResponsibilityTypes: [ResponsibilityType.departmentalResponsibility],
              procedureOrApprovalEn: 'Village maintenance budget up to prescribed financial limits.',
              procedureOrApprovalHi: 'पंचायत के निर्धारित रखरखाव बजट के अंतर्गत।',
              lineDepartmentEn: 'Public Health Engineering Department (PHED) handles major borewells and treatment plants.',
              lineDepartmentHi: 'बड़ी पेयजल पाइपलाइन व बूस्टर स्टेशन का कार्य जनस्वास्थ्य विभाग (PHED) का है।',
              representativeRoleEn: 'Identifies non-functional public taps and handpumps, authorizes village maintenance fund repairs, and reports borewell or major supply failures to PHED SDO/JE.',
              representativeRoleHi: 'खराब हैंडपंपों व नलों की पहचान करते हैं, पंचायत के स्थानीय रखरखाव फंड से मरम्मत कराते हैं और बड़ी खराबी पर जनस्वास्थ्य विभाग (PHED) को लिखित सूचना देते हैं।',
              activitiesIncludedEn: 'Replacing damaged washers and pipes of handpumps, repairing tap platforms to avoid stagnant water, and coordinating chlorination with health teams.',
              activitiesIncludedHi: 'हैंडपंपों की वॉशर व पाइप बदलना, नल के चबूतरे की मरम्मत ताकि पानी जमा न हो, और स्वास्थ्य विभाग के साथ मिलकर क्लोरीन की गोलियां डलवाना।',
              intendedResultEn: 'Uninterrupted supply of clean potable drinking water to all mohallas and prevention of water-borne contamination.',
              intendedResultHi: 'सभी मोहल्लों में स्वच्छ पेयजल की निरंतर उपलब्धता और दूषित पानी से फैलने वाली बीमारियों की रोकथाम।',
              practicalProcessEn: 'Ward Panch / citizen report -> Sarpanch spot check -> Local plumber work order or PHED escalation -> Quality check by Village Water and Sanitation Committee.',
              practicalProcessHi: 'वार्ड पंच/नागरिक सूचना -> सरपंच द्वारा स्थल निरीक्षण -> स्थानीय मरम्मत या पीएचईडी को शिकायत दर्ज -> ग्राम जल एवं स्वच्छता समिति द्वारा जांच।',
              verificationEvidenceEn: 'Panchayat expenditure cash book, PHED complaint acknowledgment number, and village water and sanitation committee (VWSC) inspection record.',
              verificationEvidenceHi: 'पंचायत रोकड़ बही (Cash Book), जनस्वास्थ्य विभाग (PHED) शिकायत पावती नंबर और ग्राम जल एवं स्वच्छता समिति का निरीक्षण रिकॉर्ड।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994, Sec 21(VIII) (Drinking Water)',
            ),
            DutyItem(
              titleEn: 'Village Sanitation and Pond (Johad) Renovation',
              titleHi: 'गांव की स्वच्छता और जोहड़ (तालाब) का जीर्णोद्धार',
              descriptionEn:
                  'Arrange solid and liquid waste management, deploy village safai karamcharis, and protect village ponds from wastewater pollution.',
              descriptionHi:
                  'ठोस व तरल कचरा प्रबंधन की व्यवस्था, सफाई कर्मचारियों की तैनाती व गांव के जोहड़ों को गंदे पानी से बचाना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              additionalResponsibilityTypes: [ResponsibilityType.requiresApproval],
              procedureOrApprovalEn: 'Village sanitation action plan approved by Gram Sabha.',
              procedureOrApprovalHi: 'ग्राम सभा द्वारा स्वीकृत स्वच्छता कार्ययोजना।',
              lineDepartmentEn: 'Haryana Pond and Waste Water Management Authority (HPWWMA).',
              lineDepartmentHi: 'हरियाणा तालाब एवं अपशिष्ट जल प्रबंधन प्राधिकरण (HPWWMA)।',
              representativeRoleEn: 'Supervises village sweepers (safai karamcharis), ensures community waste disposal pits are cleared, and mobilizes rejuvenation of ponds under Amrit Sarovar / HPWWMA guidelines.',
              representativeRoleHi: 'गांव के सफाई कर्मचारियों के कार्यों की निगरानी करते हैं, कचरा निस्तारण गड्ढों की सफाई सुनिश्चित करते हैं और अमृत सरोवर/तालाब प्राधिकरण योजना में जोहड़ पुनरुद्धार का नेतृत्व करते हैं।',
              activitiesIncludedEn: 'Door-to-door dry/wet waste segregation, cleaning common street drains, desilting polluted ponds, constructing wastewater treatment soak pits.',
              activitiesIncludedHi: 'घर-घर सूखा व गीला कचरा एकत्रण, नालियों की नियमित सफाई, जोहड़ों से गाद (desilting) निकालना और गंदा पानी रोकने के लिए सोक पिट बनाना।',
              intendedResultEn: 'Open-defecation-free and litter-free village, restored groundwater recharge ponds, and pleasant living conditions.',
              intendedResultHi: 'कचरामुक्त व स्वच्छ गांव, जोहड़ों के पुनर्जीवन से भूजल स्तर में सुधार और गंदगी जनित बीमारियों का खात्मा।',
              practicalProcessEn: 'Gram Sabha approval of Solid Liquid Waste Management (SLWM) plan -> Swachh Bharat Mission (Grameen) fund allocation -> Execution -> Third-party ODF-Plus verification.',
              practicalProcessHi: 'ग्राम सभा द्वारा ठोस एवं तरल अपशिष्ट प्रबंधन योजना पारित -> स्वच्छ भारत मिशन अनुदान आवंटन -> क्रियान्वयन -> ओडीएफ प्लस सत्यापन।',
              verificationEvidenceEn: 'Swachh Bharat Mission (Gramin) portal status, Amrit Sarovar project ID, and safai karamchari monthly attendance register.',
              verificationEvidenceHi: 'स्वच्छ भारत मिशन (ग्रामीण) पोर्टल स्टेटस, अमृत सरोवर प्रोजेक्ट आईडी और सफाई कर्मचारी मासिक उपस्थिति रजिस्टर।',
              statutoryCitation:
                  'Haryana Panchayati Raj Act 1994, Sec 21(XVIII) (Rural Sanitation), Sec 21(VIII) & HPWWMA Act 2018',
            ),
            DutyItem(
              titleEn: 'Installation and Maintenance of Streetlights',
              titleHi: 'गांव में स्ट्रीट लाइट लगवाना और रखरखाव',
              descriptionEn:
                  'Ensure public pathways, chaupals, and intersections are illuminated using solar or electric streetlights.',
              descriptionHi:
                  'सार्वजनिक रास्तों, चौपालों और मुख्य चौराहों पर स्ट्रीट लाइट लगवाना व चालू रखना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              additionalResponsibilityTypes: [ResponsibilityType.departmentalResponsibility],
              procedureOrApprovalEn: 'Panchayat resolution + coordination with electricity distribution utility (Discom).',
              procedureOrApprovalHi: 'पंचायत प्रस्ताव + बिजली निगम (Discom) के साथ समन्वय।',
              representativeRoleEn: 'Allocates lights to dark spots, enters annual maintenance contract (AMC) or coordinates with Discom for power point clearance.',
              representativeRoleHi: 'अंधेरे वाले रास्तों व चौराहों पर लाइट लगवाने का स्थान तय करते हैं, पंचायत फंड से रखरखाव कराते हैं और बिजली निगम से समन्वय करते हैं।',
              activitiesIncludedEn: 'Purchasing energy-efficient LED/solar luminaires through approved portals, installing timers, and replacing fused fixtures.',
              activitiesIncludedHi: 'मान्यता प्राप्त पोर्टल से एलईडी/सोलर लाइट खरीदना, पोल पर लगवाना, टाइमर सेट करना और खराब लाइटों को तुरंत बदलवाना।',
              intendedResultEn: 'Safe illumination at night, enhanced women security in alleys, and energy-conserving street lighting.',
              intendedResultHi: 'रात में रोशनी से सुरक्षित आवागमन, महिलाओं व बुजुर्गों की सुरक्षा और सौर ऊर्जा से बिजली बचत।',
              practicalProcessEn: 'Panchayat survey -> Gram Panchayat resolution -> GeM portal purchase -> Installation by certified electrician -> Discom load sync.',
              practicalProcessHi: 'पंचायत सर्वेक्षण -> ग्राम पंचायत प्रस्ताव -> GeM पोर्टल से क्रय -> प्रमाणित इलेक्ट्रीशियन द्वारा स्थापना -> बिजली निगम समन्वय।',
              verificationEvidenceEn: 'GeM purchase bill, Panchayat stock register, and electricity bill or AMC service log.',
              verificationEvidenceHi: 'GeM खरीद बिल, पंचायत स्टॉक रजिस्टर और बिजली निगम बिल या मेंटेनेंस सर्विस लॉग।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994, Sec 21(X) (Rural Electrification & Street Lighting)',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.schemesAndBeneficiaries,
          items: [
            DutyItem(
              titleEn: 'MGNREGA Work Identification and Execution',
              titleHi: 'मनरेगा कार्यों की पहचान व क्रियान्वयन',
              descriptionEn:
                  'Receive job card applications, propose local water conservation and earthen road works in Gram Sabha, and supervise execution without contractor involvement.',
              descriptionHi:
                  'जॉब कार्ड आवेदन स्वीकार करना, जल संरक्षण व कच्चे रास्तों के कार्य ग्राम सभा में रखना और बिना ठेकेदार के काम कराना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              additionalResponsibilityTypes: [ResponsibilityType.statutoryDuty],
              procedureOrApprovalEn: 'Annual MGNREGA plan must be passed in Gram Sabha + Administrative Sanction by PO/BDPO.',
              procedureOrApprovalHi: 'ग्राम सभा में वार्षिक कार्ययोजना पारित + कार्यक्रम अधिकारी (बीडीपीओ) से स्वीकृति।',
              lineDepartmentEn: 'Rural Development Department / MGNREGA Division.',
              lineDepartmentHi: 'ग्रामीण विकास विभाग / मनरेगा विंग।',
              representativeRoleEn: 'Mobilizes job-card households, places labor shelf-of-works before Gram Sabha, and ensures transparent master roll recording without illegal machinery.',
              representativeRoleHi: 'जॉब कार्ड धारकों को काम उपलब्ध कराते हैं, ग्राम सभा में कार्यों की कार्ययोजना रखते हैं और मशीनों के बजाय मजदूरों से काम कराना सुनिश्चित करते हैं।',
              activitiesIncludedEn: 'Desilting canals/ponds, planting trees on community land, leveling farm tracks, and constructing rural compost pits.',
              activitiesIncludedHi: 'तालाबों की खुदाई, शामलात भूमि पर पौधारोपण, खेत-खलिहान के कच्चे रास्तों को ठीक करना और कंपोस्ट गड्ढे बनाना।',
              intendedResultEn: 'Guaranteed 100 days wage employment for rural households and creation of productive water/soil assets.',
              intendedResultHi: 'ग्रामीण परिवारों को 100 दिन का कानूनी रोजगार, समय पर मजदूरी और गांव में स्थायी जल व कृषि परिसंपत्तियों का निर्माण।',
              practicalProcessEn: 'Gram Sabha annual shelf of works -> Labor budget entry on nrega.nic.in -> Work order by Programme Officer (BDPO) -> E-muster roll generation -> DBT payment.',
              practicalProcessHi: 'ग्राम सभा में शेल्फ ऑफ प्रोजेक्ट्स -> nrega.nic.in पर लेबर बजट प्रविष्टि -> कार्यक्रम अधिकारी से वर्क ऑर्डर -> ई-मस्टर रोल से हाजिरी -> सीधे बैंक खाते में भुगतान।',
              verificationEvidenceEn: 'nrega.nic.in online e-Muster roll, job card attendance record, and social audit report.',
              verificationEvidenceHi: 'nrega.nic.in ई-मस्टर रोल, जॉब कार्ड उपस्थिति प्रविष्टि और ग्राम सभा की सोशल ऑडिट रिपोर्ट।',
              statutoryCitation: 'MGNREGA Act 2005, Sec 16 & Haryana Panchayati Raj Act 1994, Sec 21',
            ),
            DutyItem(
              titleEn: 'Verification of Beneficiary Lists for Rural Housing (PMAY-G)',
              titleHi: 'प्रधानमंत्री ग्रामीण आवास योजना में पात्र परिवारों की पुष्टि',
              descriptionEn:
                  'Facilitate open Gram Sabha reading of socio-economic survey lists to identify homeless or kutcha house families; ensure ineligible persons are excluded.',
              descriptionHi:
                  'ग्राम सभा में सामाजिक-आर्थिक सर्वेक्षण सूची पढ़कर सुनाना व पात्र बेघर परिवारों के नाम अनुमोदित करना।',
              responsibilityType: ResponsibilityType.requiresApproval,
              additionalResponsibilityTypes: [ResponsibilityType.collectiveResponsibility],
              procedureOrApprovalEn: 'Gram Sabha resolution verifying eligibility + Block/District Level Committee approval.',
              procedureOrApprovalHi: 'ग्राम सभा का सर्वसम्मत सत्यापन प्रस्ताव + ब्लॉक/जिला स्तरीय समिति की अंतिम स्वीकृति।',
              lineDepartmentEn: 'Department of Rural Development & Panchayats.',
              lineDepartmentHi: 'विकास एवं पंचायत विभाग।',
              representativeRoleEn: 'Facilitates open Gram Sabha verification of Awas+ priority lists and signs Gram Sabha endorsement; does not personally approve or reject beneficiaries.',
              representativeRoleHi: 'ग्राम सभा में आवास प्लस सूची का वाचन कराकर पारदर्शिता सुनिश्चित करते हैं; अकेले किसी का नाम जोड़ने या काटने का अधिकार नहीं है।',
              activitiesIncludedEn: 'Field verification of kutcha houses, geo-tagging with Gram Sachiv/surveyor, and recording Gram Sabha objections.',
              activitiesIncludedHi: 'कच्चे मकानों का भौतिक सत्यापन, ग्राम सचिव/सर्वेक्षक के साथ जियो-टैगिंग और ग्राम सभा में आई आपत्तियों का पंजीकरण।',
              intendedResultEn: 'Pucca disaster-resilient houses for genuine poor families without extortion or favoritism.',
              intendedResultHi: 'वास्तविक जरूरतमंद व बेघर परिवारों को पक्का व सुरक्षित मकान मिलना और अपात्रों का बाहर होना।',
              practicalProcessEn: 'SECC / Awas Plus survey list read in Gram Sabha -> Gram Sabha pass resolution -> BDPO scrutiny -> District approval -> Direct DBT installment dispatch.',
              practicalProcessHi: 'ग्राम सभा में आवास प्लस सूची का वाचन -> सर्वसम्मत अनुमोदन प्रस्ताव -> बीडीपीओ स्क्रूटनी -> जिला परिषद स्वीकृति -> सीधे लाभार्थी खाते में किस्तें।',
              verificationEvidenceEn: 'AwaasSoft portal beneficiary record, Gram Sabha resolution copy, and geo-tagged stage-wise photos.',
              verificationEvidenceHi: 'आवास-सॉफ्ट पोर्टल रजिस्ट्रेशन, ग्राम सभा प्रस्ताव की प्रति और भू-टैग की गई चरणबद्ध तस्वीरें।',
              statutoryCitation: 'PMAY-G Operational Guidelines & Haryana Panchayati Raj Act 1994, Sec 21',
            ),
            DutyItem(
              titleEn: 'Assistance in Social Security Pensions (Old Age, Widow, Disability)',
              titleHi: 'सामाजिक सुरक्षा पेंशन में नागरिकों की सहायता',
              descriptionEn:
                  'Help elderly, widowed, and disabled citizens submit applications for social pensions and report deceased beneficiaries to stop illegal disbursement.',
              descriptionHi:
                  'बुजुर्गों, विधवाओं व दिव्यांगों को पेंशन आवेदन में मदद करना और मृत व्यक्तियों के नाम कटवाने की रिपोर्ट भेजना।',
              responsibilityType: ResponsibilityType.departmentalResponsibility,
              procedureOrApprovalEn: 'Sanction and disbursement are strictly by District Social Welfare Officer; Sarpanch only facilitates.',
              procedureOrApprovalHi: 'स्वीकृति व भुगतान केवल जिला समाज कल्याण अधिकारी द्वारा होता है; सरपंच केवल सहायता कर सकते हैं।',
              lineDepartmentEn: 'Department of Social Justice and Empowerment, Haryana.',
              lineDepartmentHi: 'सामाजिक न्याय एवं अधिकारिता विभाग, हरियाणा।',
              representativeRoleEn: 'Helps eligible elderly and persons with disabilities fill online Parivar Pehchan Patra (PPP) forms; verifies local residency when requested by welfare inspector.',
              representativeRoleHi: 'बुजुर्गों व दिव्यांगों को पीपीपी पोर्टल पर आवेदन करने में मदद करते हैं और समाज कल्याण विभाग द्वारा मांगे जाने पर स्थानीय निवास की पुष्टि करते हैं।',
              activitiesIncludedEn: 'Organizing pension facilitation camps, checking age proof records, and updating death entries so benefits are stopped honestly.',
              activitiesIncludedHi: 'पेंशन सहायता शिविर लगवाना, आयु संबंधी दस्तावेजों की जांच में मदद और मृतक पेंशनरों के नाम हटाने की सूचना देना।',
              intendedResultEn: 'Timely financial security for vulnerable elders, widows, and divyang citizens directly into their bank accounts.',
              intendedResultHi: 'असहाय बुजुर्गों, विधवाओं व दिव्यांगजनों को बिना बिचौलियों के समय पर सामाजिक पेंशन मिलना।',
              practicalProcessEn: 'Application on citizen portal / PPP -> Social Welfare Dept document verification -> District Social Welfare Officer sanction -> Monthly DBT transfer.',
              practicalProcessHi: 'पीपीपी/सरल हरियाणा पर आवेदन -> समाज कल्याण विभाग द्वारा सत्यापन -> जिला समाज कल्याण अधिकारी की मंजूरी -> मासिक प्रत्यक्ष बैंक अंतरण।',
              verificationEvidenceEn: 'District Social Welfare Department sanction list, PPP pension verification status, and Gram Panchayat birth/death register.',
              verificationEvidenceHi: 'जिला समाज कल्याण विभाग की पेंशन स्वीकृति सूची, पीपीपी पोर्टल स्टेटस और पंचायत जन्म-मृत्यु रजिस्टर।',
              statutoryCitation: 'Haryana Social Security Rules & Sec 21',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.meetingsAndBudgets,
          items: [
            DutyItem(
              titleEn: 'Convene Mandatory Bi-Annual Gram Sabha General Meetings',
              titleHi: 'वर्ष में कम से कम दो अनिवार्य ग्राम सभा बैठकें बुलाना',
              descriptionEn:
                  'Statutory obligation of Sarpanch to convene Sawani (May-June) and Hari (November-December) general meetings of all adult voters.',
              descriptionHi:
                  'सावनी (मई-जून) और हाड़ी (नवंबर-दिसंबर) की दो आम बैठकें बुलाने का सरपंच का वैधानिक दायित्व।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              procedureOrApprovalEn: 'Notice must be served at least 15 days in advance by beating of drum and notice board display.',
              procedureOrApprovalHi: 'कम से कम 15 दिन पूर्व मुनादी व नोटिस बोर्ड द्वारा गांव में सूचना देना अनिवार्य।',
              representativeRoleEn: 'Personally responsible for fixing meeting dates, issuing 15-day prior public notice via drum beating and notice board, and chairing the open session.',
              representativeRoleHi: 'बैठक की तिथि तय करने, 15 दिन पूर्व मुनादी व नोटिस बोर्ड पर एजेंडा जारी करने और खुली सभा की अध्यक्षता करने का व्यक्तिगत दायित्व।',
              activitiesIncludedEn: 'Reading out previous audited accounts, debating upcoming development priorities, recording citizen objections, and recording minutes on e-GramSwaraj.',
              activitiesIncludedHi: 'पिछले वर्ष के आय-व्यय का ब्योरा पढ़ना, नए विकास कार्यों पर खुली बहस, नागरिकों के प्रश्नों का उत्तर और बैठक की वीडियोग्राफी/मिनट्स दर्ज करना।',
              intendedResultEn: 'Direct participatory democracy where every adult voter holds the Panchayat leadership accountable in open daylight.',
              intendedResultHi: 'सीधा लोकतांत्रिक नियंत्रण, जहां गांव का प्रत्येक मतदाता खुली बैठक में पंचायत के काम और बजट का हिसाब ले सके।',
              practicalProcessEn: 'Date determination -> 15-day prior public notice with Munadi -> Open assembly with quorum -> Minute recording in register -> Upload on MeetingOnline.',
              practicalProcessHi: 'तिथि निर्धारण -> 15 दिन पूर्व मुनादी व सार्वजनिक नोटिस -> कोरम सहित खुली बैठक -> रजिस्टर में कार्यवाही अंकन -> पोर्टल पर अपलोड।',
              verificationEvidenceEn: 'Gram Sabha proceedings register with signatures/thumbprints of attendees, notice receipt, and meeting photos uploaded on MeetingOnline portal.',
              verificationEvidenceHi: 'उपस्थित ग्रामीणों के हस्ताक्षर/अंगूठे युक्त ग्राम सभा कार्यवाही रजिस्टर, मुनादी रसीद और MeetingOnline पोर्टल पर फोटो व वीडियो।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994, Sec 11',
            ),
            DutyItem(
              titleEn: 'Monthly Gram Panchayat Meetings & Resolution Record',
              titleHi: 'मासिक ग्राम पंचायत बैठक और प्रस्ताव पंजिका का संधारण',
              descriptionEn:
                  'Hold at least one formal Gram Panchayat meeting every month, invite all Panches, record minutes in proceedings register signed by all attending members.',
              descriptionHi:
                  'हर महीने कम से कम एक बैठक बुलाना, सभी पंचों को आमंत्रित करना और कार्यवाही रजिस्टर में हस्ताक्षर युक्त प्रस्ताव लिखना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              procedureOrApprovalEn: 'Quorum of majority of elected Panches is mandatory.',
              procedureOrApprovalHi: 'बहुमत पंचों की उपस्थिति (कोरम) अनिवार्य है।',
              representativeRoleEn: 'Convenes all elected Panches once every month, conducts structured discussion on ward issues, and records decisions in the register.',
              representativeRoleHi: 'प्रत्येक माह सभी वार्ड पंचों की बैठक बुलाते हैं, वार्डों की समस्याओं पर चर्चा कर बहुमत से प्रस्ताव पारित करते हैं।',
              activitiesIncludedEn: 'Circulating agenda 3 days prior, confirming quorum of Panches, deciding expenditure allocations, and reviewing pending departmental works.',
              activitiesIncludedHi: 'बैठक का 3 दिन पूर्व नोटिस देना, कोरम पूरा करना, वार्ड-वार प्राथमिकताओं पर फैसला और लंबित कार्यों की समीक्षा।',
              intendedResultEn: 'Collaborative decision-making where all wards of the village get fair attention without autocracy.',
              intendedResultHi: 'सामूहिक निर्णय प्रक्रिया जिससे सभी वार्डों के हितों की समान रक्षा हो और पंचायत में तानाशाही न पनपे।',
              practicalProcessEn: 'Notice with agenda to Panches -> Monthly meeting -> Discussion and majority voting -> Immediate signing of proceedings register -> Gram Sachiv attestation.',
              practicalProcessHi: 'पंचों को एजेंडा नोटिस -> मासिक बैठक -> विचार-विमर्श व मतदान -> कार्यवाही पंजिका में तुरंत हस्ताक्षर -> ग्राम सचिव द्वारा सत्यापन।',
              verificationEvidenceEn: 'Gram Panchayat proceedings book (Karwahi Register) signed by all attending Panches and counter-signed by Gram Sachiv.',
              verificationEvidenceHi: 'ग्राम पंचायत कार्यवाही पंजिका (रजिस्टर) जिस पर उपस्थित सभी पंचों के हस्ताक्षर और ग्राम सचिव के प्रतिहस्ताक्षर हों।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994, Sec 13',
            ),
            DutyItem(
              titleEn: 'Annual Budget Preparation and Presentation',
              titleHi: 'वार्षिक बजट तैयार करना और ग्राम सभा में प्रस्तुत करना',
              descriptionEn:
                  'Prepare annual budget of estimated receipts and expenditure for the upcoming fiscal year and place it before the Gram Sabha for deliberation.',
              descriptionHi:
                  'आगामी वित्तीय वर्ष की अनुमानित आय-व्यय का बजट तैयार करना और विचारार्थ ग्राम सभा के समक्ष रखना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              additionalResponsibilityTypes: [ResponsibilityType.requiresApproval],
              procedureOrApprovalEn: 'Gram Sabha review + Gram Panchayat adoption + submission to Panchayat Samiti.',
              procedureOrApprovalHi: 'ग्राम सभा में चर्चा + पंचायत द्वारा अंगीकरण + पंचायत समिति को प्रेषण।',
              representativeRoleEn: 'Prepares annual financial plan with Gram Sachiv estimating local revenues, stamp duty share, and grants; places it before Gram Sabha for open review.',
              representativeRoleHi: 'ग्राम सचिव के साथ मिलकर पंचायत की अनुमानित आय और विकास व्यय का बजट तैयार कर ग्राम सभा के समक्ष विचारार्थ रखते हैं।',
              activitiesIncludedEn: 'Consolidating ward demands, forecasting recurring maintenance vs capital works, and balancing grant allocation across education, water, and roads.',
              activitiesIncludedHi: 'सभी वार्डों की मांगों का संकलन, अनुमानित राजस्व की गणना और केंद्र/राज्य वित्त आयोग के अनुदानों का मद-वार आवंटन।',
              intendedResultEn: 'Fiscal transparency preventing unauthorized deficit or diversion of dedicated development grants.',
              intendedResultHi: 'वित्तीय पारदर्शिता, जिससे सरकारी अनुदान का दुरुपयोग रुके और गांव का योजनाबद्ध विकास हो सके।',
              practicalProcessEn: 'Draft budget preparation with Gram Sachiv -> Gram Sabha consultation -> GP formal adoption -> Upload on e-GramSwaraj -> Panchayat Samiti submission.',
              practicalProcessHi: 'ग्राम सचिव संग बजट प्रारूप -> ग्राम सभा में चर्चा -> पंचायत द्वारा पारित -> ई-ग्रामस्वराज पर अपलोड -> पंचायत समिति को अनुमोदन हेतु प्रेषण।',
              verificationEvidenceEn: 'Budget resolution passed by Gram Sabha, GPDP entry on e-GramSwaraj portal, and approval letter from Panchayat Samiti.',
              verificationEvidenceHi: 'ग्राम सभा द्वारा अनुमोदित बजट प्रस्ताव, ई-ग्रामस्वराज पोर्टल पर GPDP प्लान और पंचायत समिति की अनुमोदन प्रति।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994, Sec 12 & Sec 39',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.socialSectorCoordination,
          items: [
            DutyItem(
              titleEn: 'Coordination with Village Primary School & Anganwadi Centers',
              titleHi: 'गांव के प्राथमिक विद्यालय व आंगनवाड़ी केंद्रों से समन्वय',
              descriptionEn:
                  'Inspect midday meal hygiene, verify school building safety, monitor children attendance, and assist Anganwadi workers in nutrition tracking.',
              descriptionHi:
                  'मिड-डे मील की गुणवत्ता, स्कूल भवन की सुरक्षा, बच्चों की उपस्थिति व आंगनवाड़ी पोषण वितरण की निगरानी करना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              additionalResponsibilityTypes: [ResponsibilityType.departmentalResponsibility],
              procedureOrApprovalEn: 'School Management Committee (SMC) & Village Health Sanitation Committee (VHSNC).',
              procedureOrApprovalHi: 'स्कूल प्रबंधन समिति (SMC) व ग्राम स्वास्थ्य एवं स्वच्छता समिति के माध्यम से।',
              lineDepartmentEn: 'School Education Department / Women & Child Development Department.',
              lineDepartmentHi: 'स्कूल शिक्षा विभाग / महिला एवं बाल विकास विभाग।',
              representativeRoleEn: 'Co-chairs or visits School Management Committee (SMC), inspects mid-day meal hygiene, and ensures girl child safety and functional toilets.',
              representativeRoleHi: 'स्कूल प्रबंधन समिति (SMC) के साथ बैठक करते हैं, मिड-डे मील व पानी-शौचालय की व्यवस्था जांचते हैं और बालिकाओं की सुरक्षा सुनिश्चित करते हैं।',
              activitiesIncludedEn: 'Checking cooking area cleanliness, encouraging school dropout enrollment, verifying Anganwadi supplementary nutrition packets.',
              activitiesIncludedHi: 'रसोई की स्वच्छता जांचना, स्कूल छोड़ चुके बच्चों को दोबारा दाखिला दिलाना और आंगनवाड़ी में बच्चों व गर्भवती महिलाओं के पोषण आहार का निरीक्षण।',
              intendedResultEn: 'Healthy learning environment for village children and eradication of child malnutrition.',
              intendedResultHi: 'गांव के बच्चों को स्वच्छ व सुरक्षित शिक्षा माहौल और कुपोषण से मुक्ति।',
              practicalProcessEn: 'Periodic visits -> SMC meeting participation -> Inspection notes recorded in visitor book -> Urgent building issues escalated to Block Education Officer.',
              practicalProcessHi: 'नियमित दौरा -> एसएमसी बैठक में भागीदारी -> विजिटर बुक में निरीक्षण टिप्पणी -> जर्जर भवन की सूचना खंड शिक्षा अधिकारी (BEO) को प्रेषण।',
              verificationEvidenceEn: 'SMC meeting register, Anganwadi inspection remarks diary, and GP resolution recommending repairs to Education Dept.',
              verificationEvidenceHi: 'स्कूल प्रबंधन समिति रजिस्टर, आंगनवाड़ी निरीक्षण डायरी और शिक्षा विभाग को भेजी गई मरम्मत अनुशंसा।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994, Sec 21(XIII) (Education) & Sec 21(XX) (Women & Child Development)',
            ),
            DutyItem(
              titleEn: 'Rural Health Sub-Center and Vaccination Camps Support',
              titleHi: 'स्वास्थ्य उप-केंद्र व टीकाकरण अभियानों में सहयोग',
              descriptionEn:
                  'Assist ANM and ASHA workers during immunization days, pulse polio drives, and seasonal epidemic prevention campaigns.',
              descriptionHi:
                  'टीकाकरण दिवसों, पल्स पोलियो और मौसमी बीमारियों से बचाव अभियानों में एएनएम व आशा वर्कर को सहयोग देना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              additionalResponsibilityTypes: [ResponsibilityType.departmentalResponsibility],
              lineDepartmentEn: 'Health Department, Haryana.',
              lineDepartmentHi: 'स्वास्थ्य विभाग, हरियाणा।',
              representativeRoleEn: 'Mobilizes villagers for monthly Village Health Sanitation and Nutrition Day (VHSND), ensures health sub-center building is maintained.',
              representativeRoleHi: 'गांव में हर माह लगने वाले टीकाकरण दिवस पर ग्रामीणों को प्रेरित करते हैं और स्वास्थ्य केंद्र भवन का रखरखाव सुनिश्चित करते हैं।',
              activitiesIncludedEn: 'Arranging clean seating for mothers and infants, announcing immunization dates, supporting fogging during malaria/dengue seasons.',
              activitiesIncludedHi: 'टीकाकरण केंद्र पर पेयजल व छाया का प्रबंध, गांव में मुनादी कराना और मलेरिया/डेंगू के समय फॉगिंग व दवा का छिड़काव कराना।',
              intendedResultEn: '100% infant immunization coverage, zero maternal/child preventable mortality, and control over seasonal epidemics.',
              intendedResultHi: 'शत-प्रतिशत बच्चों का टीकाकरण, मौसमी बीमारियों पर नियंत्रण और सुरक्षित मातृत्व।',
              practicalProcessEn: 'Coordination with ANM/ASHA -> Public announcement -> Center logistics support -> Health feedback to Medical Officer In-charge.',
              practicalProcessHi: 'एएनएम व आशा वर्कर से समन्वय -> गांव में मुनादी -> केंद्र पर व्यवस्था सहयोग -> पीएचसी प्रभारी को स्वास्थ्य रिपोर्ट।',
              verificationEvidenceEn: 'VHSND camp attendance log, Primary Health Centre (PHC) medical officer camp report, and village medicine stock record.',
              verificationEvidenceHi: 'ग्राम स्वास्थ्य समिति रजिस्टर, पीएचसी चिकित्सा अधिकारी की रिपोर्ट और कीटनाशक छिड़काव लॉग।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994, Sec 21(XIX) (Public Health, Epidemics & Vaccination)',
            ),
            DutyItem(
              titleEn: 'Agriculture, Field Channels and Minor Irrigation Assistance',
              titleHi: 'कृषि, खाल (खाले) व लघु सिंचाई में सहयोग',
              descriptionEn:
                  'Facilitate soil health card camps, coordinate watercourse (khal) desilting, and report canal tail-end water shortages to Irrigation Department.',
              descriptionHi:
                  'मृदा स्वास्थ्य कार्ड शिविर, नहरी खालों की सफाई में सहयोग व टेल तक पानी न पहुंचने पर सिंचाई विभाग को सूचित करना।',
              responsibilityType: ResponsibilityType.departmentalResponsibility,
              lineDepartmentEn: 'Irrigation & Water Resources Department / Agriculture Department.',
              lineDepartmentHi: 'सिंचाई एवं जल संसाधन विभाग / कृषि एवं किसान कल्याण विभाग।',
              representativeRoleEn: 'Helps farmers coordinate collective desilting of field channels (khal) and escorts Irrigation Department officials to canal tail-ends.',
              representativeRoleHi: 'किसानों के साथ मिलकर नहरी खाले (कच्चे/पक्के खाल) साफ कराने में समन्वय करते हैं और टेल तक पानी न आने पर अधिकारियों को मौके पर बुलाते हैं।',
              activitiesIncludedEn: 'Resolving farmer watercourse disputes peacefully, mobilizing Soil Health Card test camps, and reporting tubewell power tripping.',
              activitiesIncludedHi: 'खालों की सफाई में आपसी सहयोग, मिट्टी जांच कैंप लगवाना और नहरी पानी के वारबंदी विवादों को सुलझाने में सहायता।',
              intendedResultEn: 'Fair canal water reach for small farmers at tail-ends and enhanced crop yields without water theft.',
              intendedResultHi: 'टेल पर बैठे अंतिम किसान तक नहरी पानी पहुंचना और आपसी विवादों का शांतिपूर्ण समाधान।',
              practicalProcessEn: 'Farmer grievance collection -> Joint inspection with Patwari/Canal Overseer -> Letter to SDO Irrigation -> Follow-up during canal run.',
              practicalProcessHi: 'किसानों की समस्या सुनना -> नहरी पटवारी संग स्थल निरीक्षण -> उपमंडल अभियंता (SDO) को पत्र -> नहर चलने पर टेल पर पानी जांच।',
              verificationEvidenceEn: 'Irrigation Department tail-gauge inspection register, canal complaint receipt, and Agriculture Dept camp roster.',
              verificationEvidenceHi: 'सिंचाई विभाग टेल-गेज माप रिकॉर्ड, उपमंडल अभियंता (SDO नहरी) को दी गई शिकायत और कृषि शिविर विवरण।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994, Sec 21(II) (Agriculture & Agriculture Extension)',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.welfareAndDisaster,
          items: [
            DutyItem(
              titleEn: 'Emergency Response in Floods, Fire, or Natural Calamities',
              titleHi: 'बाढ़, आगजनी या प्राकृतिक आपदा में तत्काल राहत समन्वय',
              descriptionEn:
                  'Organize temporary shelter, alert emergency rescue authorities, and assist Revenue Department Patwari in Girdawari (crop loss assessment).',
              descriptionHi:
                  'अस्थायी आश्रय की व्यवस्था, प्रशासन को सूचना देना और फसल खराबे की गिरदावरी में पटवारी को सहयोग करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              procedureOrApprovalEn: 'Immediate notification to BDPO / Sub-Divisional Magistrate (SDM) / Tehsildar.',
              procedureOrApprovalHi: 'बीडीपीओ / उपमंडल दंडाधिकारी (SDM) / तहसीलदार को तुरंत सूचना।',
              lineDepartmentEn: 'Revenue & Disaster Management Department.',
              lineDepartmentHi: 'राजस्व एवं आपदा प्रबंधन विभाग।',
              representativeRoleEn: 'Takes immediate lead in organizing community rescue, alerts SDM/Tehsildar, and accompanies Patwari during crop damage Girdawari.',
              representativeRoleHi: 'आपदा के समय तुरंत मौके पर पहुंचकर राहत कार्य शुरू कराते हैं, एसडीएम/तहसीलदार को सूचित करते हैं और पटवारी के साथ गिरदावरी में सहयोग करते हैं।',
              activitiesIncludedEn: 'Setting up community kitchen/shelter in Chaupal or school, arranging tractor/pumps for water dewatering, listing affected families.',
              activitiesIncludedHi: 'चौपाल में अस्थायी राहत शिविर, जलभराव में पंप लगवाकर पानी निकलवाना और प्रभावित किसानों व परिवारों की सूची बनवाना।',
              intendedResultEn: 'Rapid preservation of human life and livestock, zero panic, and prompt government compensation for destroyed crops or homes.',
              intendedResultHi: 'जान-माल व मवेशियों की त्वरित सुरक्षा और प्रभावित ग्रामीणों को सरकारी मुआवजे की पारदर्शी सिफारिश।',
              practicalProcessEn: 'Immediate local rescue alert -> Telephonic/written flash report to SDM/Tehsildar -> Joint Girdawari with Patwari -> Verification on e-Kshatipurti.',
              practicalProcessHi: 'त्वरित स्थानीय राहत कार्य -> एसडीएम/तहसीलदार को आपात सूचना -> पटवारी संग विशेष गिरदावरी -> ई-क्षतिपूर्ति पोर्टल पर क्षति सत्यापन।',
              verificationEvidenceEn: 'Joint calamity report signed by Sarpanch & Patwari, SDM relief dispatch order, and e-Kshatipurti portal compensation list.',
              verificationEvidenceHi: 'सरपंच व पटवारी द्वारा संयुक्त हस्ताक्षर युक्त आपदा रिपोर्ट, एसडीएम राहत आदेश और ई-क्षतिपूर्ति पोर्टल सत्यापन सूची।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994, Sec 19(1)(e)',
            ),
            DutyItem(
              titleEn: 'Protection of Village Common Lands (Shamlat Deh)',
              titleHi: 'शामलात देह व सार्वजनिक भूमि की सुरक्षा',
              descriptionEn:
                  'Protect panchayat pasture, pond banks, and community land from illegal encroachments and report unauthorized constructions to the BDPO.',
              descriptionHi:
                  'पंचायत की चरागाह, जोहड़ व शामलात भूमि पर अवैध कब्जों को रोकना और बीडीपीओ को बेदखली हेतु रिपोर्ट देना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              additionalResponsibilityTypes: [ResponsibilityType.requiresApproval],
              procedureOrApprovalEn: 'Eviction proceedings under Haryana Public Premises and Land (Eviction and Rent Recovery) Act.',
              procedureOrApprovalHi: 'हरियाणा लोक परिसर एवं भूमि बेदखली अधिनियम के तहत सहायक कलेक्टर/बीडीपीओ द्वारा कार्यवाही।',
              representativeRoleEn: 'Statutory duty to inspect village common lands; cannot use physical force directly, must issue notice and report to BDPO under Sec 24.',
              representativeRoleHi: 'शामलात भूमि व आम रास्तों की सुरक्षा करना; खुद बल प्रयोग करने का अधिकार नहीं है, धारा 24 के तहत नोटिस देकर बीडीपीओ व पुलिस को कानूनी कार्रवाई के लिए लिखते हैं।',
              activitiesIncludedEn: 'Conducting demarcation (Nishandehi) with Kanungo/Patwari, serving notice to illegal occupants, filing eviction suit before Assistant Collector 1st Grade.',
              activitiesIncludedHi: 'राजस्व विभाग से निशानदेही कराना, अवैध कब्जाधारी को कानूनी नोटिस जारी करना और सहायक कलेक्टर प्रथम श्रेणी की अदालत में बेदखली वाद दायर करना।',
              intendedResultEn: 'Preservation of public grazing grounds, roads, and village ponds for common benefit of all inhabitants.',
              intendedResultHi: 'गांव के सार्वजनिक रास्तों, जोहड़ों व गोचर भूमि को भू-माफिया या अवैध कब्जे से मुक्त रखना।',
              practicalProcessEn: 'Complaint / discovery of encroachment -> Official demarcation by revenue field staff -> Notice under Sec 24 -> Eviction order execution by BDPO/Police.',
              practicalProcessHi: 'कब्जे की पहचान -> राजस्व कानूनगो/पटवारी से निशानदेही -> धारा 24 का नोटिस -> बीडीपीओ/पुलिस सहयोग से बेदखली आदेश का अमल।',
              verificationEvidenceEn: 'Revenue demarcation report (Nishandehi Roznamcha entry), Sec 24 eviction order by BDPO, and Gram Panchayat land register.',
              verificationEvidenceHi: 'राजस्व निशानदेही रिपोर्ट, बीडीपीओ/कलेक्टर द्वारा जारी बेदखली आदेश और ग्राम पंचायत शामलात भूमि रजिस्टर।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994, Sec 24 & Punjab Village Common Lands Act 1961',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.legalLimitsAndExclusions,
          items: [
            DutyItem(
              titleEn: 'No Unilateral Financial Authority without Resolution',
              titleHi: 'बिना पंचायत प्रस्ताव के अकेले वित्तीय लेनदेन की मनाही',
              descriptionEn:
                  'The Sarpanch cannot spend any money or withdraw funds from the bank account independently without an affirmative resolution passed in a convened meeting of the Gram Panchayat and co-authorization of the Gram Sachiv.',
              descriptionHi:
                  'सरपंच ग्राम पंचायत की विधिवत बैठक में पारित प्रस्ताव और ग्राम सचिव के सह-हस्ताक्षर के बिना अकेले बैंक से कोई राशि नहीं निकाल सकते।',
              responsibilityType: ResponsibilityType.requiresApproval,
              procedureOrApprovalEn: 'Joint digital signature / dual cheque signing with Gram Sachiv strictly per sanctioned estimates.',
              procedureOrApprovalHi: 'ग्राम सचिव के साथ संयुक्त डिजिटल हस्ताक्षर/चेक हस्ताक्षर विहित अनुमानों के अनुसार।',
              representativeRoleEn: 'Must adhere strictly to statutory financial limits and joint signing rules; individual cash transactions are illegal.',
              representativeRoleHi: 'वैधानिक वित्तीय सीमाओं व संयुक्त हस्ताक्षर नियमों का कड़ाई से पालन करना अनिवार्य है; अकेले नकद लेनदेन करना गैर-कानूनी है।',
              intendedResultEn: 'Prevents embezzlement of public funds and guarantees collective financial oversight.',
              intendedResultHi: 'ग्राम निधि के गबन पर रोक और विकास राशि की सार्वजनिक जवाबदेही सुनिश्चित होना।',
              practicalProcessEn: 'Resolution in meeting -> Administrative and technical sanction -> e-GramSwaraj DSC co-approval with Gram Sachiv.',
              practicalProcessHi: 'बैठक में संकल्प -> तकनीकी व प्रशासनिक मंजूरी -> ग्राम सचिव के साथ ई-ग्रामस्वराज पर संयुक्त डिजिटल हस्ताक्षर (DSC)।',
              verificationEvidenceEn: 'Bank passbook statements, Public Financial Management System (PFMS) vouchers, and local fund audit reports.',
              verificationEvidenceHi: 'बैंक पासबुक स्टेटमेंट, PFMS ऑनलाइन वाउचर और स्थानीय निधि लेखापरीक्षा (Audit) रिपोर्ट।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994, Sec 39 & Haryana PR Finance Rules',
            ),
            DutyItem(
              titleEn: 'No Judicial or Criminal Case Adjudication Powers',
              titleHi: 'आपराधिक मामलों में फैसला सुनाने का कोई अधिकार नहीं',
              descriptionEn:
                  'A Sarpanch does not possess criminal magistrate powers, cannot impose prison sentences, cannot detain individuals, and must refer all criminal offenses to the Police Department.',
              descriptionHi:
                  'सरपंच के पास कोई आपराधिक दंडाधिकारी अधिकार नहीं है, वे किसी को बंदी नहीं बना सकते और सभी अपराधों की सूचना पुलिस को देना अनिवार्य है।',
              responsibilityType: ResponsibilityType.departmentalResponsibility,
              lineDepartmentEn: 'State Police / Judiciary (Civil and Criminal Courts).',
              lineDepartmentHi: 'पुलिस प्रशासन / न्यायपालिका (सिविल व क्रिमिनल कोर्ट)।',
              representativeRoleEn: 'May assist in peaceful civil compromise between villagers, but cannot run kangaroo courts or pass illegal fines.',
              representativeRoleHi: 'ग्रामीणों के आपसी विवाद में सामाजिक समझौते का प्रयास कर सकते हैं, परंतु कोई अवैध खाप पंचायत/जुर्माना या सजा नहीं सुना सकते।',
              intendedResultEn: 'Protection of citizen fundamental rights and rule of law under the Constitution of India.',
              intendedResultHi: 'संविधान के तहत प्रत्येक नागरिक के मौलिक अधिकारों की रक्षा और कानून का शासन।',
              practicalProcessEn: 'Offense report -> Immediate referral to Station House Officer (SHO) of local Police Station -> Assist in keeping peace.',
              practicalProcessHi: 'अपराध की सूचना -> स्थानीय थाना प्रभारी (SHO) को तत्काल लिखित सूचना -> शांति व्यवस्था बनाए रखने में पुलिस का सहयोग।',
              verificationEvidenceEn: 'Police station Daily Diary (DD) entry or FIR copy.',
              verificationEvidenceHi: 'थाना दैनिक डायरी (DD एंट्री) या प्रथम सूचना रिपोर्ट (FIR) की प्रति।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994',
            ),
            DutyItem(
              titleEn: 'No Direct Ration Distribution Authority',
              titleHi: 'राशन वितरण में सीधे हस्तक्षेप का अधिकार नहीं',
              descriptionEn:
                  'PDS fair price shops are licensed by the Food & Civil Supplies Department. The Gram Panchayat may inspect functioning and report irregularities to the Inspector, but cannot seize or re-allot quotas independently.',
              descriptionHi:
                  'राशन डिपो खाद्य एवं आपूर्ति विभाग द्वारा संचालित होते हैं। पंचायत केवल अनियमितता की शिकायत निरीक्षक से कर सकती है, डिपो बंद या रद्द नहीं कर सकती।',
              responsibilityType: ResponsibilityType.departmentalResponsibility,
              lineDepartmentEn: 'Department of Food, Civil Supplies & Consumer Affairs, Haryana.',
              lineDepartmentHi: 'खाद्य, नागरिक आपूर्ति एवं उपभोक्ता मामले विभाग।',
              representativeRoleEn: 'Can inspect public distribution shop (PDS) weighing scales and register citizen complaints, but cannot cancel depot license unilaterally.',
              representativeRoleHi: 'राशन डिपो के तौल व वितरण की जांच कर सकते हैं और शिकायतें दर्ज कर सकते हैं, किंतु स्वयं डिपो लाइसेंस रद्द या जब्त नहीं कर सकते।',
              intendedResultEn: 'Fair and transparent distribution of subsidized food grains without political interference or black marketing.',
              intendedResultHi: 'गरीब परिवारों को सही तौल व निर्धारित दर पर सरकारी राशन मिलना और कालाबाजारी पर रोक।',
              practicalProcessEn: 'PDS vigilance inspection -> Report irregularities to District Food and Supplies Controller (DFSC) -> DFSC conducts departmental inquiry.',
              practicalProcessHi: 'निगरानी समिति द्वारा जांच -> जिला खाद्य एवं आपूर्ति नियंत्रक (DFSC) को रिपोर्ट -> विभाग द्वारा कानूनी जांच व कार्रवाई।',
              verificationEvidenceEn: 'PDS vigilance committee inspection diary and DFSC complaint receipt.',
              verificationEvidenceHi: 'राशन सतर्कता समिति निरीक्षण डायरी और डीएफएससी कार्यालय शिकायत पावती।',
              statutoryCitation: 'Haryana PDS Control Orders & Sec 21',
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // WARD PANCH (Ward Member of Gram Panchayat)
  // =========================================================================
  static RepresentativeRoleProfile _buildWardPanchProfile(bool isHaryana) {
    return RepresentativeRoleProfile(
      role: RepresentativeRole.wardPanch,
      titleEn: 'Ward Member (Panch)',
      titleHi: 'वार्ड पंच (ग्राम पंचायत सदस्य)',
      governingBodyEn: 'Gram Panchayat (Ward Level)',
      governingBodyHi: 'ग्राम पंचायत (वार्ड स्तर)',
      constitutionalPostSummaryEn:
          'Directly elected representative of a specific ward within the Gram Panchayat. Has equal voting rights on all Gram Panchayat resolutions, monitors ward-level public works, represents ward residents in meetings, and serves on functional sub-committees.',
      constitutionalPostSummaryHi:
          'ग्राम पंचायत के विशिष्ट वार्ड से प्रत्यक्ष निर्वाचित प्रतिनिधि। ग्राम पंचायत के सभी प्रस्तावों पर समान मताधिकार रखते हैं, वार्ड में विकास कार्यों की निगरानी करते हैं, वार्डवासियों की आवाज उठाते हैं और पंचायत की उप-समितियों में सदस्य होते हैं।',
      legalReference: LegalSourceReference(
        sourceTitle: isHaryana
            ? 'The Haryana Panchayati Raj Act, 1994 (Haryana Act No. 11 of 1994)'
            : 'General Model Guidance (Constitution 73rd Amendment & Model Panchayati Raj Framework)',
        relevantSections: isHaryana
            ? 'Sections 8, 9 (Election of Panches), 13 (Meetings and Voting), 22 (Sub-Committees), 51 (Suspension/Removal)'
            : 'Article 243C & 243E (State-specific statute governs ward powers)',
        jurisdictionState: isHaryana ? 'Haryana' : 'General / Model Framework',
        sourceUrl: isHaryana ? haryanaActPdfUrl : moprUrl,
        lastVerifiedDate: '2026-10-26',
        isStateSpecific: isHaryana,
        officialGuidanceNoteEn: isHaryana
            ? 'Statutory provisions governing ward members under Haryana Panchayati Raj Act, 1994.'
            : 'General Model Guidance for ward members (Panches) in Gram Panchayats.',
        officialGuidanceNoteHi: isHaryana
            ? 'हरियाणा पंचायती राज अधिनियम, 1994 के अंतर्गत वार्ड पंचों के वैधानिक प्रावधान।'
            : 'ग्राम पंचायतों में वार्ड पंचों के लिए सामान्य मॉडल मार्गदर्शन।',
      ),
      citizenQa: const [
        CitizenQaItem(
          questionEn: 'What can my Ward Panch do for our street/ward?',
          questionHi: 'वार्ड पंच हमारे वार्ड/गली के लिए क्या कर सकते हैं?',
          answerEn:
              'A Ward Panch can propose paving for specific streets, installation of streetlights, clearing of choked drains, and repair of water taps in their ward during monthly Gram Panchayat meetings. They can vote on the budget and inspect works in progress.',
          answerHi:
              'वार्ड पंच मासिक पंचायत बैठक में अपने वार्ड की टूटी गली, बंद नाली, स्ट्रीट लाइट लगवाने या हैंडपंप की मरम्मत का प्रस्ताव रख सकते हैं। वे बजट पर वोट दे सकते हैं और वार्ड में चल रहे कार्य की गुणवत्ता जांच सकते हैं।',
        ),
        CitizenQaItem(
          questionEn: 'Can a Ward Panch independently sanction money or issue tenders?',
          questionHi: 'क्या वार्ड पंच अकेले पैसे मंजूर कर सकते हैं या टेंडर दे सकते हैं?',
          answerEn:
              'NO. An individual Ward Panch has NO individual financial signing authority or power to award contracts. All financial decisions must be passed collectively as a Gram Panchayat resolution.',
          answerHi:
              'नहीं। किसी भी वार्ड पंच के पास अकेले कोई वित्तीय स्वीकृति देने, चेक काटने या ठेका देने का अधिकार नहीं है। सभी वित्तीय निर्णय ग्राम पंचायत की बैठक में सामूहिक प्रस्ताव द्वारा ही लिए जाते हैं।',
        ),
        CitizenQaItem(
          questionEn: 'How does a Ward Panch help in government schemes?',
          questionHi: 'सरकारी योजनाओं में वार्ड पंच कैसे मदद कर सकते हैं?',
          answerEn:
              'A Ward Panch assists in identifying eligible families for PM Awas, social pensions, and MGNREGA job cards within their ward, and verifies that genuine poor families are included in the Gram Sabha agenda.',
          answerHi:
              'वार्ड पंच अपने वार्ड के वास्तविक जरूरतमंद परिवारों की पहचान कर सकते हैं ताकि पीएम आवास, वृद्धावस्था पेंशन या मनरेगा जॉब कार्ड में कोई पात्र परिवार छूट न जाए और ग्राम सभा में उनके नाम रखे जा सकें।',
        ),
        CitizenQaItem(
          questionEn: 'What committees can a Ward Panch be a part of?',
          questionHi: 'वार्ड पंच किन-किन समितियों में शामिल हो सकते हैं?',
          answerEn:
              'Under Section 22 of the Haryana Panchayati Raj Act, the Gram Panchayat appoints sub-committees for Production, Social Justice, and Amenities. Panches chair or serve as members of these sub-committees.',
          answerHi:
              'हरियाणा पंचायती राज अधिनियम की धारा 22 के तहत ग्राम पंचायत सामाजिक न्याय, निर्माण व जन-सुविधाओं के लिए उप-समितियां बनाती है, जिनमें वार्ड पंच सदस्य या संयोजक होते हैं।',
        ),
        CitizenQaItem(
          questionEn: 'Where can citizens raise a concern if a Ward Panch is unresponsive?',
          questionHi: 'यदि वार्ड पंच ध्यान न दें तो नागरिक शिकायत कहाँ करें?',
          answerEn:
              'Bring the issue directly to the open Gram Sabha general meeting or submit a written request to the Sarpanch and Gram Sachiv. For unresolved administrative issues, approach the BDPO.',
          answerHi:
              'सीधे खुली ग्राम सभा बैठक में अपनी समस्या रखें या सरपंच व ग्राम सचिव को लिखित आवेदन दें। प्रशासनिक समाधान न मिलने पर बीडीपीओ से संपर्क करें।',
        ),
      ],
      legalLimitationsEn: const [
        'Has NO individual executive or financial signing authority; cannot operate the Gram Fund bank account.',
        'Cannot unilaterally sanction works, award tenders, hire contractors, or order expenditures outside a formal Gram Panchayat resolution.',
        'Cannot issue official government certificates or approvals in an individual capacity.',
        'Cannot override decisions passed by the majority vote of the Gram Panchayat or the Gram Sabha.',
      ],
      legalLimitationsHi: const [
        'कोई व्यक्तिगत कार्यकारी या वित्तीय हस्ताक्षर अधिकार नहीं है; ग्राम निधि बैंक खाते का संचालन अकेले नहीं कर सकते।',
        'ग्राम पंचायत के औपचारिक प्रस्ताव के बिना अकेले कोई वित्तीय मंजूरी देने, ठेका देने या काम का आदेश जारी करने का अधिकार नहीं है।',
        'व्यक्तिगत हैसियत से कोई आधिकारिक सरकारी प्रमाण पत्र जारी करने का अधिकार नहीं है।',
        'ग्राम पंचायत या ग्राम सभा के बहुमत से लिए गए निर्णय को अकेले खारिज या रद्द करने का अधिकार नहीं है।',
      ],
      grievanceEscalationEn:
          'Local: Gram Panchayat Meeting -> Open Gram Sabha.\nAdministrative: Block Development & Panchayat Officer (BDPO) -> Additional Deputy Commissioner (ADC).',
      grievanceEscalationHi:
          'स्थानीय: ग्राम पंचायत बैठक -> खुली ग्राम सभा।\nप्रशासनिक: खंड विकास एवं पंचायत अधिकारी (BDPO) -> अतिरिक्त उपायुक्त (ADC)।',
      categories: const [
        DutyCategorySection(
          category: DutyCategory.publicAssets,
          items: [
            DutyItem(
              titleEn: 'Propose and Prioritize Ward Infrastructure Works',
              titleHi: 'वार्ड के विकास कार्यों का प्रस्ताव रखना व प्राथमिकता तय करना',
              descriptionEn:
                  'Identify broken street paving, blocked drainage outfalls, and drinking water shortages in their ward and formally table them in Gram Panchayat meetings.',
              descriptionHi:
                  'वार्ड में टूटी गलियों, बंद नालियों व पेयजल की समस्याओं को चिन्हित कर पंचायत बैठक में प्रस्ताव दर्ज कराना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              additionalResponsibilityTypes: [ResponsibilityType.collectiveResponsibility],
              procedureOrApprovalEn: 'Must be formally recorded in Gram Panchayat proceedings register.',
              procedureOrApprovalHi: 'पंचायत की कार्यवाही पंजिका में औपचारिक रूप से दर्ज कराना आवश्यक।',
              representativeRoleEn: 'Surveys ward streets, consults ward residents on priority lanes, and insists on recording ward resolutions in the official agenda.',
              representativeRoleHi: 'वार्ड की गलियों का मुआयना करते हैं, वार्डवासियों से मिलकर प्राथमिकता तय करते हैं और पंचायत की आधिकारिक कार्यवाही में वार्ड का प्रस्ताव लिखवाते हैं।',
              activitiesIncludedEn: 'Listing unpaved street segments, marking blocked drain spots, identifying non-functional streetlight poles in the ward.',
              activitiesIncludedHi: 'कच्ची गलियों की पैमाइश/सूची बनाना, गंदे पानी के निकास की रुकावटें दर्ज करना और वार्ड में बंद पड़ी लाइटों का विवरण तैयार करना।',
              intendedResultEn: 'Fair share of Gram Panchayat development funds for the ward without neglect or favoritism.',
              intendedResultHi: 'ग्राम पंचायत के विकास फंड में वार्ड को उसका उचित हक मिलना और वार्डवासियों की बुनियादी समस्याओं का समाधान।',
              practicalProcessEn: 'Ward consultation -> Formal proposal at monthly GP meeting -> Majority vote approval -> Inclusion in GPDP on e-GramSwaraj.',
              practicalProcessHi: 'वार्ड में चर्चा -> मासिक पंचायत बैठक में प्रस्ताव -> बहुमत से पारित -> ई-ग्रामस्वराज पर GPDP में शामिल होना।',
              verificationEvidenceEn: 'Ward demand written submission, monthly GP meeting proceedings register signed by Ward Panch.',
              verificationEvidenceHi: 'वार्ड पंच द्वारा लिखित मांग पत्र और पंचायत कार्यवाही रजिस्टर में दर्ज प्रस्ताव प्रविष्टि।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994, Sec 13 & 21',
            ),
            DutyItem(
              titleEn: 'Inspect Quality of Ward Public Works',
              titleHi: 'वार्ड में चल रहे सार्वजनिक निर्माण कार्यों की गुणवत्ता जांचना',
              descriptionEn:
                  'Inspect ongoing street construction, brick paving, and pipe laying in their ward to verify material quality and specifications.',
              descriptionHi:
                  'वार्ड में बन रही गली, नाली या पाइपलाइन कार्य की सामग्री व गुणवत्ता की स्थल पर जांच करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              procedureOrApprovalEn: 'Report defects to Gram Panchayat and JE Panchayati Raj.',
              procedureOrApprovalHi: 'कमी पाए जाने पर ग्राम पंचायत व कनिष्ठ अभियंता को सूचित करना।',
              representativeRoleEn: 'Conducts spot inspections of brick mortar, concrete thickness, and drain slope; files written objections before payment is processed.',
              representativeRoleHi: 'गली-नाली निर्माण में सीमेंट-बजरी के अनुपात, ढलान और सामग्री की मौके पर जांच करते हैं और घटिया काम दिखने पर भुगतान रोकने के लिए लिखते हैं।',
              activitiesIncludedEn: 'Checking paver block quality, verifying road width, observing drainage flow during trials, gathering neighbor feedback.',
              activitiesIncludedHi: 'पेवर ब्लॉक की मजबूती देखना, गली की चौड़ाई नापना, पानी बहाकर नाली का ढलान जांचना और पड़ोसियों की राय लेना।',
              intendedResultEn: 'Long-lasting and sturdy public works that do not break down prematurely.',
              intendedResultHi: 'मजबूत और टिकाऊ निर्माण कार्य जिससे सरकारी धन की बर्बादी न हो और गली वर्षों तक सुरक्षित रहे।',
              practicalProcessEn: 'On-site physical inspection -> Immediate photo/video capture of defects -> Notice to Sarpanch and JE -> Retesting by JE before MB entry.',
              practicalProcessHi: 'मौके पर भौतिक निरीक्षण -> खामियों की फोटो/वीडियो -> सरपंच व कनिष्ठ अभियंता को लिखित शिकायत -> माप पुस्तिका (MB) भरने से पहले सुधार।',
              verificationEvidenceEn: 'Defect notice copy submitted to BDPO/JE, and social audit committee inspection memo.',
              verificationEvidenceHi: 'बीडीपीओ/जेई को भेजी गई शिकायत प्रति और सोशल ऑडिट निरीक्षण रिपोर्ट।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994, Sec 22',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.schemesAndBeneficiaries,
          items: [
            DutyItem(
              titleEn: 'Ward Beneficiary Identification and Mobilization',
              titleHi: 'वार्ड के पात्र लाभार्थियों की पहचान व सहायता',
              descriptionEn:
                  'Inform ward residents about MGNREGA works, rural housing (PMAY-G), and toilet construction subsidies; ensure deserving poor are not omitted.',
              descriptionHi:
                  'वार्डवासियों को मनरेगा, आवास योजना व शौचालय अनुदान की जानकारी देना व पात्रों के नाम सूची में दर्ज कराना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              additionalResponsibilityTypes: [ResponsibilityType.requiresApproval],
              procedureOrApprovalEn: 'Final approval must be given by Gram Sabha.',
              procedureOrApprovalHi: 'अंतिम अनुमोदन ग्राम सभा द्वारा ही मान्य होता है।',
              representativeRoleEn: 'Acts as citizen link in the ward; ensures poor, disabled, and landless households are registered for welfare schemes.',
              representativeRoleHi: 'वार्ड के गरीब, भूमिहीन व दिव्यांग परिवारों को सरकारी योजनाओं से जोड़ने और ग्राम सभा में उनकी पात्रता की पैरवी करने का दायित्व।',
              activitiesIncludedEn: 'Distributing scheme brochures, helping fill MGNREGA job card forms, cross-verifying kutcha house claims in the ward.',
              activitiesIncludedHi: 'योजनाओं की जानकारी बांटना, मनरेगा जॉब कार्ड फॉर्म भरवाना और वार्ड में बेघर परिवारों के नाम सूची में शामिल कराना।',
              intendedResultEn: '100% saturation of eligible welfare benefits across all households of the ward.',
              intendedResultHi: 'वार्ड के हर पात्र गरीब परिवार को बिना किसी रिश्वत या भेदभाव के सरकारी लाभ मिलना।',
              practicalProcessEn: 'Ward survey -> List reading in Gram Sabha -> Gram Sabha ratification -> Forwarding to block authorities.',
              practicalProcessHi: 'वार्ड स्तर पर सत्यापन -> ग्राम सभा में नामों का वाचन -> ग्राम सभा से अनुमोदन -> ब्लॉक कार्यालय को प्रेषण।',
              verificationEvidenceEn: 'Gram Sabha approved beneficiary list copy, and MGNREGA job card register for the ward.',
              verificationEvidenceHi: 'ग्राम सभा द्वारा पारित लाभार्थी सूची और वार्ड जॉब कार्ड रजिस्टर।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994, Sec 12 & 21',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.meetingsAndBudgets,
          items: [
            DutyItem(
              titleEn: 'Mandatory Attendance & Voting in Gram Panchayat Meetings',
              titleHi: 'ग्राम पंचायत बैठकों में उपस्थिति व मताधिकार',
              descriptionEn:
                  'Attend every monthly Gram Panchayat meeting, participate in debates, review accounts, and vote on all resolutions (one member, one vote).',
              descriptionHi:
                  'मासिक बैठक में भाग लेना, आय-व्यय की समीक्षा करना और प्रत्येक प्रस्ताव पर मतदान करना (प्रत्येक पंच का एक वोट)।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              procedureOrApprovalEn:
                  'Absence from five consecutive meetings without prior permission or leave of the Gram Panchayat can attract removal inquiry under Sec. 51(3)(d) after due show-cause opportunity.',
              procedureOrApprovalHi:
                  'ग्राम पंचायत की पूर्व अनुमति या अवकाश के बिना लगातार 5 बैठकों में अनुपस्थित रहने पर धारा 51(3)(d) के तहत कारण बताओ अवसर व जांच के बाद ही हटाने की कार्रवाई हो सकती है।',
              representativeRoleEn: 'Has equal voting power to every other member including the Sarpanch; can demand recorded division/vote on disputed resolutions.',
              representativeRoleHi: 'पंचायत के प्रत्येक प्रस्ताव पर सरपंच के बराबर एक वोट का अधिकार; मतभेद होने पर अपना असहमति नोट दर्ज कराने का कानूनी अधिकार।',
              activitiesIncludedEn: 'Scrutinizing monthly receipts and expenditure vouchers, questioning delayed ward works, voting on contracts and tenders.',
              activitiesIncludedHi: 'मासिक आय-व्यय वाउचरों की जांच, वार्ड के रुके हुए कामों पर जवाबदेही मांगना और प्रस्तावों पर पक्ष/विपक्ष में मतदान।',
              intendedResultEn: 'Democratic accountability in Panchayat governance preventing single-person monopolization.',
              intendedResultHi: 'पंचायत में सामूहिक लोकतांत्रिक नियंत्रण जिससे किसी एक व्यक्ति की मनमानी न चल सके।',
              practicalProcessEn: 'Meeting notice receipt -> Active debate -> Voting -> Signing Karwahi Register with dissent remarks if any.',
              practicalProcessHi: 'बैठक नोटिस प्राप्ति -> चर्चा में भाग -> मतदान -> कार्यवाही रजिस्टर पर हस्ताक्षर (असहमति हो तो असहमति नोट सहित)।',
              verificationEvidenceEn: 'Signatures in Gram Panchayat Karwahi Register (proceedings book).',
              verificationEvidenceHi: 'ग्राम पंचायत कार्यवाही पंजिका (रजिस्टर) में दर्ज हस्ताक्षर व उपस्थिति।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994, Sec 13 & Sec 51(3)(d)',
            ),
            DutyItem(
              titleEn: 'Active Participation in Gram Sabha Assemblies',
              titleHi: 'ग्राम सभा की बैठकों में सक्रिय सहभागिता',
              descriptionEn:
                  'Attend general Gram Sabha meetings with ward voters, present ward priorities, and ensure community concerns are heard.',
              descriptionHi:
                  'वार्ड के मतदाताओं के साथ ग्राम सभा में भाग लेना, वार्ड की प्राथमिकताएं रखना और ग्रामीणों की बात उठाना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              representativeRoleEn: 'Encourages ward voters to turn out in large numbers, speaks up on behalf of marginalized ward residents.',
              representativeRoleHi: 'वार्ड के नागरिकों को ग्राम सभा में लाने के लिए प्रेरित करते हैं और सभा में वार्ड की समस्याओं को प्रमुखता से उठाते हैं।',
              activitiesIncludedEn: 'Presenting ward development demands before all villagers, answering questions regarding ward works.',
              activitiesIncludedHi: 'पूरी ग्राम सभा के सामने वार्ड की जरूरतें रखना और वार्ड में हुए कार्यों का ग्रामीणों को हिसाब देना।',
              intendedResultEn: 'Participatory grassroots democracy with open public oversight.',
              intendedResultHi: 'मजबूत ग्रामीण लोकतंत्र जहां जनता के सामने खुली बहस में फैसले लिए जाएं।',
              practicalProcessEn: 'Ward mobilisation before meeting -> Active presentation during session -> Ratification in final minutes.',
              practicalProcessHi: 'बैठक से पूर्व वार्ड में संपर्क -> सभा में प्रस्ताव प्रस्तुति -> अंतिम कार्यवाही विवरण में अंकन।',
              verificationEvidenceEn: 'Attendance sheet and proceedings register of Gram Sabha.',
              verificationEvidenceHi: 'ग्राम सभा उपस्थिति पत्रक व कार्यवाही रजिस्टर।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994, Sec 11',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.socialSectorCoordination,
          items: [
            DutyItem(
              titleEn: 'Serve on Gram Panchayat Sub-Committees (Up-Samitis)',
              titleHi: 'ग्राम पंचायत की उप-समितियों में दायित्व निर्वहन',
              descriptionEn:
                  'Serve as member or head of appointed standing committees for Social Justice, Amenities, and Education under Section 22.',
              descriptionHi:
                  'धारा 22 के तहत गठित सामाजिक न्याय, नागरिक सुविधा व शिक्षा उप-समितियों में सक्रिय भूमिका निभाना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              representativeRoleEn: 'Leads or participates in sub-committee inspections of village schools, chaupals, and water distribution networks.',
              representativeRoleHi: 'सामाजिक न्याय व जनसुविधा उप-समिति के सदस्य के रूप में स्कूल, चौपाल और पानी व्यवस्था की जांच करते हैं।',
              activitiesIncludedEn: 'Drafting sub-committee inspection reports, recommending policy improvements to the full Gram Panchayat.',
              activitiesIncludedHi: 'उप-समिति की रिपोर्ट तैयार करना और पूरी पंचायत के समक्ष सुधार के सुझाव प्रस्तुत करना।',
              intendedResultEn: 'Specialized oversight and decentralized administrative efficiency at the village tier.',
              intendedResultHi: 'ग्राम स्तर पर विभिन्न क्षेत्रों की विशेषज्ञ निगरानी और पारदर्शी प्रशासन।',
              practicalProcessEn: 'Appointment by Gram Panchayat -> Periodic committee meetings -> Field inspections -> Submission of recommendations.',
              practicalProcessHi: 'पंचायत द्वारा समिति गठन -> नियमित बैठकें -> मौके पर जांच -> पंचायत को सिफारिशें सौंपना।',
              verificationEvidenceEn: 'Sub-committee meeting minutes book and inspection reports.',
              verificationEvidenceHi: 'उप-समिति कार्यवाही रजिस्टर और निरीक्षण रिपोर्ट।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994, Sec 22',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.welfareAndDisaster,
          items: [
            DutyItem(
              titleEn: 'Ward Grievance Reporting and Disaster Alerting',
              titleHi: 'वार्ड की समस्याओं व आपदा की तुरंत सूचना देना',
              descriptionEn:
                  'Report waterlogging, contaminated water, electrical hazards, or disease outbreaks in the ward immediately to the Sarpanch and line department staff.',
              descriptionHi:
                  'वार्ड में जलभराव, दूषित पानी, बिजली के खतरे या बीमारी फैलने पर तुरंत सरपंच व संबंधित अधिकारियों को सूचित करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              representativeRoleEn: 'Acts as first emergency responder in the ward; alerts authorities and assists in distributing relief to ward residents.',
              representativeRoleHi: 'वार्ड में आपदा या संकट के समय तुरंत सक्रिय होकर प्रशासन को सूचित करना और राहत वितरण में सहयोग करना।',
              activitiesIncludedEn: 'Visiting affected families during heavy rains or fire, arranging temporary shelter, reporting snapped power lines.',
              activitiesIncludedHi: 'भारी बारिश या आगजनी में प्रभावित घरों का दौरा, सुरक्षित स्थान की व्यवस्था और टूटे बिजली तारों की सूचना देना।',
              intendedResultEn: 'Immediate containment of local hazards and protection of ward lives and cattle.',
              intendedResultHi: 'वार्डवासियों की जान-माल की रक्षा और आपातकाल में त्वरित सरकारी सहायता।',
              practicalProcessEn: 'Spot verification -> Immediate communication to Sarpanch / BDPO / Discom -> Assistance during relief operations.',
              practicalProcessHi: 'मौके पर स्थिति देखना -> सरपंच/बीडीपीओ/बिजली निगम को फोन व लिखित सूचना -> राहत कार्य में सहायता।',
              verificationEvidenceEn: 'Log of complaints sent to BDPO/Discom, and disaster inspection report signed by Ward Panch.',
              verificationEvidenceHi: 'संबंधित विभाग को भेजी गई शिकायत प्रति व आपदा निरीक्षण रिपोर्ट।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994, Sec 19 & 21',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.legalLimitsAndExclusions,
          items: [
            DutyItem(
              titleEn: 'No Independent Financial Signing Authority',
              titleHi: 'अकेले किसी भी प्रकार की वित्तीय शक्ति नहीं',
              descriptionEn:
                  'A Ward Panch cannot issue cheques, disburse funds, or contractually bind the Gram Panchayat independently.',
              descriptionHi:
                  'वार्ड पंच अकेले चेक जारी नहीं कर सकते, कोई भुगतान नहीं कर सकते और न ही सीधे कोई टेंडर दे सकते हैं।',
              responsibilityType: ResponsibilityType.requiresApproval,
              representativeRoleEn: 'Must never solicit or accept individual cash or issue payment guarantees; all money is disbursed through joint Panchayat digital signatures.',
              representativeRoleHi: 'व्यक्तिगत रूप से कोई नकद लेनदेन या भुगतान का वादा नहीं कर सकते; समस्त भुगतान केवल संयुक्त डिजिटल हस्ताक्षर से होता है।',
              intendedResultEn: 'Prevents extortion, bribery, and unauthorized contracting at the ward level.',
              intendedResultHi: 'वार्ड स्तर पर भ्रष्टाचार, अवैध वसूली और फर्जी ठेकों पर पूर्ण रोक।',
              practicalProcessEn: 'All expenditure proposals must be voted on and sanctioned by the collective Gram Panchayat body.',
              practicalProcessHi: 'सभी खर्चे पंचायत बैठक में सामूहिक रूप से पारित होकर ही स्वीकृत होते हैं।',
              verificationEvidenceEn: 'Official government banking records and e-GramSwaraj PFMS account audits.',
              verificationEvidenceHi: 'ई-ग्रामस्वराज PFMS बैंक रिकॉर्ड और सरकारी ऑडिट रिपोर्ट।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994, Sec 39',
            ),
            DutyItem(
              titleEn: 'Cannot Exercise Sarpanch Executive Powers Unless Officiating',
              titleHi: 'सरपंच के कार्यकारी अधिकारों का प्रयोग अकेले नहीं कर सकते',
              descriptionEn:
                  'Executive supervision of records, correspondence with government, and official custody of registers rests with Sarpanch and Gram Sachiv, not individual Panches.',
              descriptionHi:
                  'रिकॉर्ड की देखरेख और प्रशासनिक पत्राचार सरपंच व ग्राम सचिव का काम है, किसी व्यक्तिगत पंच का नहीं।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              representativeRoleEn: 'Cannot summon official staff or alter government registers without statutory authorization or designation as officiating Sarpanch.',
              representativeRoleHi: 'बिना कानूनी नियुक्ति (कार्यवाहक सरपंच) के पंचायत कर्मचारियों को आदेश देने या सरकारी रजिस्टर बदलने का कोई अधिकार नहीं है।',
              intendedResultEn: 'Maintains administrative chain of command and protects official record integrity.',
              intendedResultHi: 'प्रशासनिक अनुशासन बना रहना और पंचायत के आधिकारिक रिकॉर्ड की सुरक्षा।',
              practicalProcessEn: 'In case of Sarpanch absence exceeding statutory limit, the BDPO conducts formal election for an officiating Sarpanch.',
              practicalProcessHi: 'सरपंच की लंबी अनुपस्थिति में बीडीपीओ द्वारा कार्यवाहक सरपंच के विधिवत चुनाव के बाद ही शक्तियां मिलती हैं।',
              verificationEvidenceEn: 'Official notification issued by BDPO / Deputy Commissioner.',
              verificationEvidenceHi: 'बीडीपीओ/उपायुक्त द्वारा जारी आधिकारिक कार्यवाहक आदेश।',
              statutoryCitation: 'Haryana Panchayati Raj Act 1994, Sec 19',
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // PANCHAYAT SAMITI CHAIRPERSON (Block Pramukh / President)
  // =========================================================================
  static RepresentativeRoleProfile _buildPanchayatSamitiChairpersonProfile(bool isHaryana) {
    return RepresentativeRoleProfile(
      role: RepresentativeRole.panchayatSamitiChairperson,
      titleEn: 'Panchayat Samiti Chairperson (Block Pramukh)',
      titleHi: 'पंचायत समिति अध्यक्ष (ब्लॉक प्रमुख)',
      governingBodyEn: 'Panchayat Samiti (Block Level Intermediate Tier)',
      governingBodyHi: 'पंचायत समिति (मध्यवर्ती ब्लॉक स्तर)',
      constitutionalPostSummaryEn:
          'Elected political head of the intermediate rural panchayat tier elected by and from amongst elected members under Article 243C(5). Responsible for convening and presiding over Samiti meetings, guiding intermediate block development planning, consolidating Gram Panchayat proposals, supervising implementation of collective decisions, and coordinating with the Block Development and Panchayat Officer (BDPO) and district administration.',
      constitutionalPostSummaryHi:
          'संविधान के अनुच्छेद 243C(5) के तहत निर्वाचित सदस्यों में से चुने गए मध्यवर्ती ग्रामीण निकाय (पंचायत समिति) के राजनीतिक प्रमुख। पंचायत समिति की बैठकों की अध्यक्षता करना, ब्लॉक विकास योजना तैयार कराना, ग्राम पंचायतों के प्रस्तावों का समन्वय करना, स्वीकृत निर्णयों की प्रगति की समीक्षा करना और खंड विकास एवं पंचायत अधिकारी (BDPO) व जिला प्रशासन के साथ समन्वय स्थापित करना इनका मुख्य दायित्व है।',
      legalReference: LegalSourceReference(
        sourceTitle: isHaryana
            ? 'The Haryana Panchayati Raj Act, 1994 (Haryana Act No. 11 of 1994)'
            : 'General Model Guidance (National Intermediate Panchayat Governance Framework)',
        relevantSections: isHaryana
            ? 'Sections 56 (Constitution), 59 (Election of Chairman), 61 (Powers, Duties & Emergency Powers of Chairman), 65 (Executive Officer), 66 (Meetings & Casting Vote), 75 (Functions), 83 (Standing Committees), 101 (Annual Budget)'
            : 'Constitution of India (73rd Amendment), Articles 243B, 243C, 243G (Eleventh Schedule) & Respective State Panchayati Raj Acts',
        jurisdictionState: isHaryana ? 'Haryana' : 'General / Model Framework',
        sourceUrl: isHaryana ? haryanaActPdfUrl : moprUrl,
        lastVerifiedDate: '2026-10-26',
        isStateSpecific: isHaryana,
        officialGuidanceNoteEn: isHaryana
            ? 'Statutory intermediate rural governance provisions under the Haryana Department of Development and Panchayats.'
            : 'General Model Guidance grounded in Constitutional Panchayati Raj provisions. Consult the respective State Panchayati Raj Act for local financial powers, standing committee structures, and delegated authorities.',
        officialGuidanceNoteHi: isHaryana
            ? 'हरियाणा विकास एवं पंचायत विभाग के अंतर्गत मध्यवर्ती पंचायत समिति के वैधानिक प्रावधान।'
            : '73वें संविधान संशोधन पर आधारित सामान्य मॉडल मार्गदर्शन। वित्तीय शक्तियों, स्थायी समितियों व कार्यकारी प्रक्रियाओं के लिए संबंधित राज्य के पंचायती राज अधिनियम का संदर्भ लें।',
      ),
      citizenQa: const [
        CitizenQaItem(
          questionEn: 'What can this representative do? (What can a Panchayat Samiti Chairperson do?)',
          questionHi: 'पंचायत समिति अध्यक्ष ब्लॉक के लिए क्या-क्या कर सकते हैं?',
          answerEn:
              'A Chairperson convenes and presides over statutory Panchayat Samiti meetings, finalizes meeting agendas with the BDPO, guides preparation of the comprehensive Block Development Plan, oversees inter-village connecting roads and drainage, heads the Finance, Audit & Planning Standing Committee, and reviews progress of government development schemes across the block.',
          answerHi:
              'पंचायत समिति अध्यक्ष ब्लॉक स्तरीय बैठकों की अध्यक्षता करते हैं, बीडीपीओ के साथ मिलकर एजेंडा तय करते हैं, ब्लॉक विकास योजना तैयार करवाते हैं, अंतर-ग्रामीण संपर्क मार्गों व बड़े नालों के निर्माण की निगरानी करते हैं, वित्त व योजना स्थायी समिति का नेतृत्व करते हैं और ब्लॉक में चल रही सरकारी विकास योजनाओं की प्रगति की समीक्षा करते हैं।',
        ),
        CitizenQaItem(
          questionEn: 'What is the Chairperson personally responsible for?',
          questionHi: 'पंचायत समिति अध्यक्ष की व्यक्तिगत जिम्मेदारी क्या है?',
          answerEn:
              'Ensuring statutory meetings are held at least once every two months, preserving decorum in proceedings, casting a deciding vote only in event of equality of votes where authorized by rules, placing the annual Samiti budget before the house for approval, and alerting district authorities during block-wide natural disasters or epidemics.',
          answerHi:
              'नियमों के तहत हर दो महीने में कम से कम एक बार बैठक बुलाना, सदन की कार्यवाही का सुचारू संचालन, मत बराबर होने पर विहित नियमानुसार निर्णायक मत (कास्टिंग वोट) देना, वार्षिक बजट सदन में पारित कराना और ब्लॉक में प्राकृतिक आपदा या महामारी की स्थिति में जिला प्रशासन को तुरंत सूचित करना।',
        ),
        CitizenQaItem(
          questionEn: 'Which works require collective Samiti sanction or higher departmental approval?',
          questionHi: 'किस काम में पंचायत समिति या उच्चाधिकारी की मंजूरी चाहिए?',
          answerEn:
              'All development projects, tenders, and budget allocations require an affirmative collective resolution of the Panchayat Samiti, technical sanction from the Panchayati Raj Engineering Wing (SDO/XEN), administrative approval, and sanction from the Zila Parishad or State Directorate for major works. The Chairperson cannot independently award tenders, sign payment cheques, or divert scheme funds without statutory approvals.',
          answerHi:
              'सभी विकास कार्यों, टेंडरों और बजट आवंटन के लिए पंचायत समिति का सामूहिक प्रस्ताव, पंचायती राज इंजीनियरिंग विंग (एसडीओ/एक्सईएन) से तकनीकी स्वीकृति और जिला परिषद या निदेशालय से प्रशासनिक स्वीकृति आवश्यक होती है। अध्यक्ष अकेले किसी टेंडर को मंजूरी नहीं दे सकते, न ही बिना बजट व प्रस्ताव के कोई चेक जारी कर सकते हैं।',
        ),
        CitizenQaItem(
          questionEn: 'Which works belong to line departments or other administrative authorities?',
          questionHi: 'ये काम किस सरकारी विभाग के अधीन आते हैं?',
          answerEn:
              'State highways and major district roads belong to PWD (B&R); large piped drinking water networks and rural sewerage belong to Public Health Engineering Department (PHED); high-voltage agricultural electricity feeders belong to Power Discoms; primary health centres and hospitals belong to Health Department; police and law enforcement belong to District Police; land titles and revenue records belong to the Revenue Department (Tehsildar/Patwari).',
          answerHi:
              'राज्य राजमार्ग व मुख्य जिला सड़कें लोक निर्माण विभाग (PWD) के अधीन हैं; बड़े जलघर व ग्रामीण सीवरेज जनस्वास्थ्य अभियांत्रिकी विभाग (PHED) के पास हैं; कृषि बिजली आपूर्ति व ट्रांसफार्मर बिजली निगम के पास हैं; प्राथमिक स्वास्थ्य केंद्र व अस्पताल स्वास्थ्य विभाग के पास हैं; कानून-व्यवस्था पुलिस प्रशासन का कार्य है; और भूमि रिकॉर्ड व पैमाइश राजस्व विभाग (तहसीलदार/पटवारी) का कार्य है।',
        ),
        CitizenQaItem(
          questionEn: 'Where and how can citizens raise grievances or report block issues?',
          questionHi: 'ब्लॉक स्तर की शिकायत कहाँ और कैसे करें?',
          answerEn:
              'First submit a written representation to the Chairperson or the Block Development and Panchayat Officer (BDPO) at the Block Office. For unresolved grievances or financial irregularities, escalate to the Chief Executive Officer (CEO), Zila Parishad / Additional Deputy Commissioner (ADC), the Deputy Commissioner, or lodge a petition on the state grievance portal (e.g. CM Window Haryana).',
          answerHi:
              'सबसे पहले ब्लॉक कार्यालय में अध्यक्ष या खंड विकास एवं पंचायत अधिकारी (BDPO) को लिखित प्रार्थना पत्र दें। यदि समस्या का समाधान न हो या वित्तीय अनियमितता हो, तो मुख्य कार्यकारी अधिकारी (CEO) जिला परिषद / अतिरिक्त उपायुक्त (ADC), उपायुक्त को शिकायत दें या राज्य सीएम विंडो पोर्टल पर ऑनलाइन शिकायत दर्ज करें।',
        ),
      ],
      legalLimitationsEn: const [
        'Does NOT have individual executive control over block administration; executive authority and day-to-day staff control are statutorily vested in the Block Development and Panchayat Officer (BDPO) under Section 65.',
        'Cannot unilaterally expend Samiti funds or disburse payments without a formal collective resolution and approved budgetary allocation passed by the Panchayat Samiti.',
        'Has no legal authority to suspend, transfer, or discipline government employees (teachers, patwaris, doctors, BDPO staff); can only submit formal complaints or recommend inquiry to competent appointing authorities.',
        'Has no administrative command to suspend or dismiss a Sarpanch or interfere in internal Gram Sabha statutory decisions (regulatory powers rest with the State Government / Deputy Commissioner under Section 51).',
        'Possesses no police, criminal magistrate, or civil judicial powers to adjudicate disputes, impose fines, or issue search/detention warrants.',
        'Cannot alter statutory eligibility criteria for government welfare schemes (PMAY-G, pensions, NFSA ration cards) or guarantee benefits outside official verification registers.',
      ],
      legalLimitationsHi: const [
        'ब्लॉक प्रशासन पर कोई व्यक्तिगत कार्यकारी नियंत्रण नहीं है; दैनिक कर्मचारी प्रशासन, टेंडर व पत्राचार की वैधानिक जिम्मेदारी धारा 65 के तहत खंड विकास एवं पंचायत अधिकारी (BDPO) में निहित है।',
        'पंचायत समिति के विधिवत पारित प्रस्ताव और स्वीकृत बजट आवंटन के बिना अकेले समिति निधि से कोई भी राशि खर्च करने या चेक जारी करने का अधिकार नहीं है।',
        'सरकारी कर्मचारियों (अध्यापक, पटवारी, डॉक्टर, ब्लॉक कर्मचारी) को निलंबित, स्थानांतरित या दंडित करने का अधिकार नहीं है; केवल सक्षम प्राधिकारी को जांच हेतु सिफारिश या शिकायत भेजी जा सकती है।',
        'ग्राम पंचायत के आंतरिक मामलों में मनमाना हस्तक्षेप करने या सरपंच को निलंबित/बर्खास्त करने का अधिकार नहीं है (यह शक्ति सरकार/उपायुक्त के पास धारा 51 के तहत है)।',
        'किसी भी दीवानी या आपराधिक विवाद में फैसला सुनाने, जुर्माना लगाने या बंदी बनाने का कोई न्यायिक या पुलिस अधिकार नहीं है।',
        'सरकारी कल्याणकारी योजनाओं (पीएम आवास, पेंशन, राशन कार्ड) के पात्रता नियमों को बदलने या आधिकारिक सत्यापन के बिना लाभ की गारंटी देने का अधिकार नहीं है।',
      ],
      grievanceEscalationEn:
          'Block Level: Panchayat Samiti Chairperson / BDPO Office -> District Level: CEO, Zila Parishad / Additional Deputy Commissioner (ADC) -> Deputy Commissioner (DC) -> State Level: Directorate of Development & Panchayats -> State Grievance Redressal Portal (CM Window) / Lokayukta.',
      grievanceEscalationHi:
          'ब्लॉक स्तर: पंचायत समिति अध्यक्ष / बीडीपीओ कार्यालय -> जिला स्तर: मुख्य कार्यकारी अधिकारी (CEO) जिला परिषद / अतिरिक्त उपायुक्त (ADC) -> उपायुक्त -> राज्य स्तर: विकास एवं पंचायत निदेशालय -> राज्य शिकायत पोर्टल (सीएम विंडो) / लोकायुक्त।',
      categories: const [
        DutyCategorySection(
          category: DutyCategory.publicAssets,
          items: [
            DutyItem(
              titleEn: 'Inter-Village Roads & Block Infrastructure Coordination',
              titleHi: 'अंतर-ग्रामीण संपर्क मार्ग व ब्लॉक स्तरीय ढांचा समन्वय',
              descriptionEn:
                  'Coordinate and prioritize connecting roads, culverts, and causeways between villages within the block jurisdiction that are not maintained by the PWD.',
              descriptionHi:
                  'ब्लॉक के अंतर्गत गांवों को जोड़ने वाले मुख्य रास्तों, पुलियों व संपर्क मार्गों की योजना बनाना जो पीडब्ल्यूडी के अधीन नहीं हैं।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              additionalResponsibilityTypes: [ResponsibilityType.requiresApproval],
              procedureOrApprovalEn: 'Panchayat Samiti resolution + Technical sanction from Panchayati Raj Engineering Wing.',
              procedureOrApprovalHi: 'पंचायत समिति का प्रस्ताव + पंचायती राज तकनीकी विंग से तकनीकी स्वीकृति।',
              representativeRoleEn: 'Presides over the block infrastructure agenda, balances link road allocations across different panchayats, and pushes execution with BDPO.',
              representativeRoleHi: 'ब्लॉक निर्माण एजेंडे की अध्यक्षता करते हैं, विभिन्न पंचायतों के बीच संपर्क मार्गों का संतुलित आवंटन कराते हैं और बीडीपीओ के साथ काम आगे बढ़ाते हैं।',
              activitiesIncludedEn: 'Approving road priorities, coordinating joint surveys between neighboring villages, tracking Panchayati Raj SDO/XEN technical estimates.',
              activitiesIncludedHi: 'सड़कों की प्राथमिकता तय करना, दो गांवों के बीच साझा रास्तों का सर्वे कराना और पंचायती राज एसडीओ/एक्सईएन से लागत प्राक्कलन तैयार कराना।',
              intendedResultEn: 'Smooth inter-village all-weather connectivity improving access to mandis, schools, and hospitals.',
              intendedResultHi: 'गांवों के बीच पक्के संपर्क मार्ग, जिससे मंडियों, स्कूलों और अस्पतालों तक ग्रामीणों का पहुंचना सुगम हो।',
              practicalProcessEn: 'Gram Panchayat requests received -> Samiti house resolution -> Panchayati Raj SDO technical sanction -> E-tender floated by BDPO -> Measurement & payment.',
              practicalProcessHi: 'ग्राम पंचायतों से मांग -> समिति सदन में पारित -> पंचायती राज विंग से तकनीकी स्वीकृति -> बीडीपीओ द्वारा ई-टेंडर -> कार्य निरीक्षण व भुगतान।',
              verificationEvidenceEn: 'Panchayat Samiti resolution minutes, Haryana e-tender portal contract ID, and Panchayati Raj Engineering MB record.',
              verificationEvidenceHi: 'पंचायत समिति प्रस्ताव रजिस्टर, हरियाणा ई-टेंडर पोर्टल वर्क आईडी और माप पुस्तिका (MB) विवरण।',
              statutoryCitation: 'The Haryana Panchayati Raj Act, 1994, Sec. 75 & Schedule II',
            ),
            DutyItem(
              titleEn: 'Intermediate Drainage Outfalls & Water Conservation Oversight',
              titleHi: 'क्षेत्रीय जल निकासी नाले व जल संरक्षण योजनाओं की देखरेख',
              descriptionEn:
                  'Guide community drainage outfalls connecting multiple village ponds, minor irrigation channels, and watershed management works across the block.',
              descriptionHi:
                  'कई गांवों के जोहड़ों को जोड़ने वाले बड़े ड्रेनेज नालों, लघु सिंचाई व जल संचयन कार्यों की ब्लॉक स्तर पर देखरेख करना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              additionalResponsibilityTypes: [ResponsibilityType.departmentalResponsibility],
              procedureOrApprovalEn: 'Coordination with Irrigation & Water Resources Department / BDPO technical staff.',
              procedureOrApprovalHi: 'सिंचाई विभाग व बीडीपीओ तकनीकी शाखा के साथ समन्वय।',
              representativeRoleEn: 'Facilitates consensus between upstream and downstream villages regarding overflow channels to prevent flash flooding.',
              representativeRoleHi: 'ऊपरी व निचले गांवों के बीच जल निकासी को लेकर सहमति बनवाते हैं ताकि बरसात में किसी गांव में जलभराव या विवाद न हो।',
              activitiesIncludedEn: 'Planning multi-village drainage routes, inspecting pond overflows, resolving culvert blockages with Irrigation officers.',
              activitiesIncludedHi: 'साझा ड्रेनेज मार्ग की योजना, जोहड़ ओवरफ्लो की जांच और सिंचाई विभाग के अधिकारियों के साथ पुलियों की सफाई सुनिश्चित करना।',
              intendedResultEn: 'Protection of agricultural fields and village settlements from seasonal rainwater inundation.',
              intendedResultHi: 'बरसाती पानी से फसलों और आबादी को डूबने से बचाना और जल संरक्षण बढ़ाना।',
              practicalProcessEn: 'Joint site survey with BDPO & Irrigation SDO -> Samiti approval -> Inter-departmental clearance -> Work order.',
              practicalProcessHi: 'बीडीपीओ व सिंचाई एसडीओ संग संयुक्त सर्वे -> समिति से मंजूरी -> अंतर-विभागीय अनापत्ति -> कार्य आदेश।',
              verificationEvidenceEn: 'Block watershed plan approved copy and field inspection report signed by BDPO & Samiti Chairman.',
              verificationEvidenceHi: 'ब्लॉक जल संचयन योजना और बीडीपीओ व अध्यक्ष द्वारा हस्ताक्षरित संयुक्त निरीक्षण रिपोर्ट।',
              statutoryCitation: 'The Haryana Panchayati Raj Act, 1994, Sec. 75',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.schemesAndBeneficiaries,
          items: [
            DutyItem(
              titleEn: 'Block Scheme Monitoring & Poverty Alleviation Review',
              titleHi: 'ब्लॉक स्तरीय सरकारी योजनाओं व गरीबी उन्मूलन की समीक्षा',
              descriptionEn:
                  'Review implementation progress of MGNREGA works, Pradhan Mantri Awas Yojana (Gramin), and Deendayal Antyodaya Yojana - NRLM across all Gram Panchayats in the block.',
              descriptionHi:
                  'ब्लॉक की सभी ग्राम पंचायतों में मनरेगा, पीएम आवास योजना (ग्रामीण) और राज्य आजीविका मिशन (NRLM) की प्रगति की समीक्षा करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              procedureOrApprovalEn: 'Review in bi-monthly Samiti meetings with BDPO scheme coordinators.',
              procedureOrApprovalHi: 'बीडीपीओ योजना समन्वयकों के साथ द्वैमासिक बैठक में समीक्षा।',
              representativeRoleEn: 'Chairs review sessions, summons scheme data, and flags delayed payments or incomplete houses to district officers.',
              representativeRoleHi: 'समीक्षा बैठकों की अध्यक्षता करते हैं, योजनाओं का डेटा तलब करते हैं और रुकी मजदूरी या अधूरे मकानों की रिपोर्ट उपायुक्त को भेजते हैं।',
              activitiesIncludedEn: 'Tracking block MGNREGA expenditure, evaluating Self-Help Group (SHG) credit linkage, checking PMAY-G completion rates.',
              activitiesIncludedHi: 'ब्लॉक मनरेगा खर्च की समीक्षा, स्वयं सहायता समूहों (SHG) को ऋण सुविधा दिलाना और पीएम आवासों की प्रगति जांचना।',
              intendedResultEn: 'Timely flow of scheme funds to rural beneficiaries and elimination of administrative bottlenecks.',
              intendedResultHi: 'ग्रामीण गरीबों तक योजनाओं का लाभ समय पर पहुंचना और ब्लॉक कार्यालय में फाइलों के अनावश्यक अटकाव पर रोक।',
              practicalProcessEn: 'Bi-monthly review meeting -> Scrutiny of MIS portals -> House resolution on bottlenecks -> Submission to District Zila Parishad.',
              practicalProcessHi: 'द्वैमासिक समीक्षा बैठक -> ऑनलाइन पोर्टल समीक्षा -> बाधाओं पर प्रस्ताव -> मुख्य कार्यकारी अधिकारी (CEO) जिला परिषद को प्रेषण।',
              verificationEvidenceEn: 'Panchayat Samiti bi-monthly meeting minutes and block scheme progress chart.',
              verificationEvidenceHi: 'पंचायत समिति बैठक कार्यवाही विवरण और ब्लॉक योजना प्रगति चार्ट।',
              statutoryCitation: 'The Haryana Panchayati Raj Act, 1994, Sec. 75 & 76',
            ),
            DutyItem(
              titleEn: 'Agricultural Extension & Rural Livelihoods Promotion',
              titleHi: 'कृषि विस्तार, पशुपालन व ग्रामीण आजीविका संवर्धन',
              descriptionEn:
                  'Facilitate agricultural extension exhibitions, seed distribution drives, veterinary camps, and dairy development support through departmental officers.',
              descriptionHi:
                  'कृषि प्रदर्शनी, उन्नत बीज वितरण, पशु चिकित्सा शिविर व दुग्ध विकास कार्यक्रमों में कृषि एवं पशुपालन अधिकारियों के साथ समन्वय करना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              representativeRoleEn: 'Coordinates with Agriculture and Animal Husbandry departments to organize block-level Kisan Melas and livestock health camps.',
              representativeRoleHi: 'कृषि व पशुपालन विभाग के अधिकारियों के साथ मिलकर ब्लॉक स्तरीय किसान मेला और पशु स्वास्थ्य शिविर आयोजित कराते हैं।',
              activitiesIncludedEn: 'Scheduling veterinary mobile dispensary routes, spreading crop residue management awareness, arranging seed testing stalls.',
              activitiesIncludedHi: 'पशु चिकित्सा वैन के दौरे तय करना, पराली प्रबंधन जागरूकता फैलाना और प्रमाणित बीजों के स्टॉल लगवाना।',
              intendedResultEn: 'Increased farming productivity, improved milk yields, and sustainable farmer incomes.',
              intendedResultHi: 'उन्नत कृषि तकनीक, मवेशियों का बेहतर स्वास्थ्य और किसानों व पशुपालकों की आय में वृद्धि।',
              practicalProcessEn: 'Coordination meeting with Sub-Divisional Agriculture Officer -> Schedule finalization -> Camp execution across clusters.',
              practicalProcessHi: 'कृषि व पशुपालन अधिकारियों के साथ बैठक -> शिविर कार्यक्रम निर्धारण -> क्लस्टर स्तर पर क्रियान्वयन।',
              verificationEvidenceEn: 'Block agriculture extension schedule and camp attendance logs.',
              verificationEvidenceHi: 'ब्लॉक कृषि विस्तार कार्यक्रम और शिविर उपस्थिति पंजिका।',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.meetingsAndBudgets,
          items: [
            DutyItem(
              titleEn: 'Convene and Preside over Panchayat Samiti Meetings',
              titleHi: 'पंचायत समिति बैठकों की अध्यक्षता व कार्यवाही संचालन',
              descriptionEn:
                  'Convene statutory bi-monthly meetings, approve meeting agendas prepared with the BDPO, maintain democratic order, and exercise a casting vote in event of an equality of votes.',
              descriptionHi:
                  'कम से कम हर दो माह में बैठक बुलाना, बीडीपीओ के साथ एजेंडा तय करना, कार्यवाही का लोकतांत्रिक संचालन और मत बराबर होने पर निर्णायक मत (कास्टिंग वोट) देना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              procedureOrApprovalEn: 'Conducted under Haryana Panchayat Samiti Conduct of Business Rules.',
              procedureOrApprovalHi: 'हरियाणा पंचायत समिति कार्य संचालन नियमावली के अंतर्गत।',
              representativeRoleEn: 'Sets the meeting agenda with BDPO, presides over deliberations, maintains decorum, and signs official proceedings.',
              representativeRoleHi: 'बीडीपीओ संग बैठक का एजेंडा तय करते हैं, सदन की अध्यक्षता करते हैं और सभी पारित प्रस्तावों पर हस्ताक्षर करते हैं।',
              activitiesIncludedEn: 'Issuing meeting notices to all elected members, confirming quorum, managing debates, recording votes.',
              activitiesIncludedHi: 'सभी सदस्यों को बैठक का नोटिस जारी कराना, कोरम पूरा कराना, सदस्यों के सवालों पर जवाब दिलवाना और मतदान कराना।',
              intendedResultEn: 'Transparent and accountable governance at the intermediate tier with active participation of all elected members.',
              intendedResultHi: 'ब्लॉक स्तर पर लोकतांत्रिक जवाबदेही और सभी निर्वाचन क्षेत्रों के सदस्यों की समान भागीदारी।',
              practicalProcessEn: 'Notice issued 10 days in advance -> Meeting presided -> Proceedings recorded by BDPO -> Signed by Chairman within 3 days.',
              practicalProcessHi: '10 दिन पूर्व नोटिस -> बैठक की अध्यक्षता -> बीडीपीओ द्वारा कार्यवाही अंकन -> 3 दिन में अध्यक्ष द्वारा हस्ताक्षर।',
              verificationEvidenceEn: 'Panchayat Samiti official Karwahi Register signed by Chairperson and BDPO.',
              verificationEvidenceHi: 'अध्यक्ष व बीडीपीओ के हस्ताक्षरों से युक्त पंचायत समिति कार्यवाही पंजिका।',
              statutoryCitation: 'The Haryana Panchayati Raj Act, 1994, Sec. 61 & 66',
            ),
            DutyItem(
              titleEn: 'Block Development Plan Formulation & Budget Presentation',
              titleHi: 'ब्लॉक विकास योजना का समेकन व वार्षिक बजट प्रस्तुति',
              descriptionEn:
                  'Consolidate annual development plans submitted by Gram Panchayats into the Block Development Plan and place the annual Panchayat Samiti budget before the house for approval.',
              descriptionHi:
                  'ग्राम पंचायतों की विकास योजनाओं को एकीकृत कर ब्लॉक विकास योजना तैयार कराना और वार्षिक आय-व्यय बजट सदन में पारित कराना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              additionalResponsibilityTypes: [ResponsibilityType.requiresApproval],
              procedureOrApprovalEn: 'Panchayat Samiti resolution + Submission to Zila Parishad for statutory sanction.',
              procedureOrApprovalHi: 'पंचायत समिति का प्रस्ताव + जिला परिषद को अंतिम स्वीकृति हेतु प्रेषण।',
              representativeRoleEn: 'Presents the draft budget to the house, defends budget priorities, and ensures balanced allocation among member wards.',
              representativeRoleHi: 'सदन के समक्ष वार्षिक बजट प्रस्तुत करते हैं, विभिन्न मदों पर चर्चा कराते हैं और सभी वार्डों के लिए न्यायसंगत बजट सुनिश्चित करते हैं।',
              activitiesIncludedEn: 'Compiling revenue estimates from local cesses, evaluating grant-in-aid shares, approving scheme allocations.',
              activitiesIncludedHi: 'स्थानीय शुल्कों व करों से आय का आकलन, राज्य व केंद्रीय वित्त आयोग अनुदान का आवंटन और सदन से पारित कराना।',
              intendedResultEn: 'Prudent fiscal allocation driving holistic infrastructure growth across the entire block.',
              intendedResultHi: 'ब्लॉक का सुनियोजित विकास और विकास बजट का पारदर्शी उपयोग।',
              practicalProcessEn: 'Budget draft prepared by BDPO -> Standing committee review -> Presentation to full Samiti -> Adoption -> Zila Parishad approval.',
              practicalProcessHi: 'बीडीपीओ द्वारा प्रारूप -> वित्त समिति जांच -> सदन में पारित -> जिला परिषद को अनुमोदन हेतु प्रेषण।',
              verificationEvidenceEn: 'Annual budget resolution and Zila Parishad approval order.',
              verificationEvidenceHi: 'वार्षिक बजट प्रस्ताव और जिला परिषद का औपचारिक अनुमोदन आदेश।',
              statutoryCitation: 'The Haryana Panchayati Raj Act, 1994, Sec. 101',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.socialSectorCoordination,
          items: [
            DutyItem(
              titleEn: 'Lead Statutory Standing Committees',
              titleHi: 'वैधानिक स्थायी समितियों का नेतृत्व व समन्वय',
              descriptionEn:
                  'Serve as ex-officio chairman of the Finance, Audit and Planning Standing Committee and oversee the functioning of the General and Social Justice Committees under Section 83.',
              descriptionHi:
                  'धारा 83 के तहत वित्त, लेखा परीक्षा व योजना स्थायी समिति की अध्यक्षता करना और सामाजिक न्याय समिति के कार्यों की निगरानी करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              representativeRoleEn: 'Chairs Finance & Audit committee, checks internal audit queries, and directs administrative efficiency.',
              representativeRoleHi: 'वित्त एवं ऑडिट समिति की अध्यक्षता करते हैं, वित्तीय कमियों को दूर कराते हैं और समिति के काम की निगरानी करते हैं।',
              activitiesIncludedEn: 'Reviewing quarterly audit reports, allocating discretionary committee grants, directing social audits.',
              activitiesIncludedHi: 'त्रैमासिक ऑडिट रिपोर्ट की जांच, सामाजिक न्याय समिति की सिफारिशों की समीक्षा और ब्लॉक स्तर पर अनुपालन सुनिश्चित करना।',
              intendedResultEn: 'Specialized oversight and strict fiscal vigilance over block funds.',
              intendedResultHi: 'ब्लॉक फंड की सख्त वित्तीय निगरानी और सामाजिक न्याय से जुड़े मामलों का त्वरित समाधान।',
              practicalProcessEn: 'Standing committee meetings convened -> Recommendations submitted to general house -> Ratification.',
              practicalProcessHi: 'स्थायी समिति की बैठक -> सिफारिशें सदन के समक्ष पेश -> सामान्य सदन द्वारा पुष्टि।',
              verificationEvidenceEn: 'Standing Committee proceedings book and signed audit inspection reports.',
              verificationEvidenceHi: 'स्थायी समिति कार्यवाही रजिस्टर और हस्ताक्षरित ऑडिट रिपोर्ट।',
              statutoryCitation: 'The Haryana Panchayati Raj Act, 1994, Sec. 83',
            ),
            DutyItem(
              titleEn: 'Rural Health, Primary Education & Anganwadi Support',
              titleHi: 'ग्रामीण स्वास्थ्य, प्राथमिक शिक्षा व आंगनवाड़ी केंद्रों का सहयोग',
              descriptionEn:
                  'Coordinate with Block Education Officer (BEO) and Senior Medical Officer (SMO) to highlight shortages of medical staff, medicines, and school facilities.',
              descriptionHi:
                  'ब्लॉक शिक्षा अधिकारी व चिकित्सा अधिकारी के साथ समन्वय कर स्कूलों व प्राथमिक स्वास्थ्य केंद्रों की व्यवस्थाओं को सुदृढ़ कराना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              additionalResponsibilityTypes: [ResponsibilityType.departmentalResponsibility],
              representativeRoleEn: 'Presents consolidated health and education requirements to district administration and raises staff vacancies.',
              representativeRoleHi: 'ब्लॉक के स्कूलों व स्वास्थ्य केंद्रों में डॉक्टरों, अध्यापकों व दवाओं की कमी को जिला प्रशासन के समक्ष उठाते हैं।',
              activitiesIncludedEn: 'Conducting surprise visits to Community Health Centres (CHCs), reviewing mid-day meal supplies, inspecting school boundaries.',
              activitiesIncludedHi: 'सीएचसी/पीएचसी का निरीक्षण, मिड-डे मील की गुणवत्ता देखना और स्कूलों में पानी-शौचालय की सुविधा सुनिश्चित करना।',
              intendedResultEn: 'Higher quality of primary education and robust rural healthcare for all families in the block.',
              intendedResultHi: 'ब्लॉक के सभी ग्रामीणों के लिए बेहतर सरकारी स्कूल और सुलभ व सस्ती स्वास्थ्य सेवाएं।',
              practicalProcessEn: 'Block coordination meeting with BEO/SMO -> Resolution on vacancies/repairs -> Escalation to DC/State Directors.',
              practicalProcessHi: 'अधिकारियों संग समन्वय बैठक -> कमियों पर प्रस्ताव -> उपायुक्त व संबंधित विभाग को रिपोर्ट प्रेषण।',
              verificationEvidenceEn: 'Inspection visit reports and formal communications sent to District Education Officer / CMO.',
              verificationEvidenceHi: 'निरीक्षण रिपोर्ट और जिला शिक्षा अधिकारी/मुख्य चिकित्सा अधिकारी को भेजे गए पत्र।',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.welfareAndDisaster,
          items: [
            DutyItem(
              titleEn: 'Block Emergency Relief & Disaster Response Coordination',
              titleHi: 'ब्लॉक स्तरीय आपदा प्रबंधन व आपातकालीन राहत समन्वय',
              descriptionEn:
                  'Take emergency measures during floods, waterlogging, fire accidents, or crop failures; coordinate with SDM and BDPO for immediate relief camps and drain clearing.',
              descriptionHi:
                  'बाढ़, जलभराव या आगजनी में आपात राहत कार्यों का नेतृत्व करना और एसडीएम व बीडीपीओ के साथ राहत शिविर व जल निकासी सुनिश्चित करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              procedureOrApprovalEn: 'Emergency action under Sec. 61(2) with mandatory reporting to Samiti at next meeting.',
              procedureOrApprovalHi: 'धारा 61(2) के तहत आपात आदेश, जिसकी अगली बैठक में पुष्टि अनिवार्य है।',
              representativeRoleEn: 'Exercises statutory emergency powers under Section 61(2) to direct urgent relief, coordinating directly with SDM and BDPO.',
              representativeRoleHi: 'धारा 61(2) के तहत आपातकालीन शक्तियों का प्रयोग करते हुए तत्काल राहत कार्य कराते हैं और अगली बैठक में सदन से पुष्टि कराते हैं।',
              activitiesIncludedEn: 'Mobilizing dewatering pumps, arranging fodder for cattle in flood-hit villages, setting up temporary medical outposts.',
              activitiesIncludedHi: 'जलभराव में बड़े पंप लगवाना, बाढ़ प्रभावित पशुओं के लिए चारे का प्रबंध और राहत शिविरों में भोजन-दवा पहुंचाना।',
              intendedResultEn: 'Swift mitigation of calamities preventing loss of human and livestock life.',
              intendedResultHi: 'आपदा में तत्काल राहत, जिससे ग्रामीणों के जीवन व मवेशियों का नुकसान कम से कम हो।',
              practicalProcessEn: 'Emergency declaration -> Directions issued to BDPO under Sec. 61(2) -> Relief mobilization -> Post-facto approval at next Samiti meeting.',
              practicalProcessHi: 'आपात स्थिति की सूचना -> धारा 61(2) में बीडीपीओ को निर्देश -> राहत कार्य -> अगली समिति बैठक में प्रस्ताव पारित कर पुष्टि।',
              verificationEvidenceEn: 'Emergency relief sanction order and SDM disaster management dispatch register.',
              verificationEvidenceHi: 'आपात राहत आदेश और उपमंडल आपदा प्रबंधन राहत रजिस्टर।',
              statutoryCitation: 'The Haryana Panchayati Raj Act, 1994, Sec. 61(2)',
            ),
            DutyItem(
              titleEn: 'Inter-Village Dispute Mitigation & Common Facility Allocation',
              titleHi: 'अंतर-ग्रामीण विवाद समाधान व साझा सुविधाओं का आवंटन',
              descriptionEn:
                  'Facilitate amicable solutions between neighboring Gram Panchayats on boundary drainage, cremation ground access, and shared pasture or cattle pond usage.',
              descriptionHi:
                  'पड़ोसी ग्राम पंचायतों के बीच जल निकासी, रास्तों या साझा चरागाह से जुड़े विवादों में सौहार्दपूर्ण समाधान कराना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              representativeRoleEn: 'Convenes joint discussions with concerned Sarpanches and Panches to resolve boundary disputes without litigation.',
              representativeRoleHi: 'संबंधित पंचायतों के सरपंचों व ग्रामीणों की संयुक्त बैठक बुलाकर आपसी सहमति से विवाद का शांतिपूर्ण हल निकालते हैं।',
              activitiesIncludedEn: 'Field site hearings, examining old revenue boundaries with Tehsildar, drafting mutual compromise agreements.',
              activitiesIncludedHi: 'मौके पर सुनवाई, तहसीलदार के साथ राजस्व नक्शे देखना और दोनों पंचायतों के बीच आपसी समझौते का दस्तावेज तैयार करना।',
              intendedResultEn: 'Harmony and peaceful cooperation between neighboring rural communities.',
              intendedResultHi: 'पड़ोसी गांवों के बीच भाईचारा और शांतिपूर्ण सह-अस्तित्व, जिससे कानूनी मुकदमों से बचा जा सके।',
              practicalProcessEn: 'Dispute representation -> Joint site visit by Chairperson & BDPO -> Settlement agreement recorded in Samiti minutes.',
              practicalProcessHi: 'विवाद का आवेदन -> अध्यक्ष व बीडीपीओ का संयुक्त दौरा -> समिति कार्यवाही में सर्वसम्मत समझौता प्रविष्टि।',
              verificationEvidenceEn: 'Signed compromise resolution passed jointly by concerned Gram Panchayats and Panchayat Samiti.',
              verificationEvidenceHi: 'संबंधित ग्राम पंचायतों और पंचायत समिति द्वारा हस्ताक्षरित संयुक्त समझौता प्रस्ताव।',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.legalLimitsAndExclusions,
          items: [
            DutyItem(
              titleEn: 'Administrative Separation of Political Leadership and Executive Officer',
              titleHi: 'राजनीतिक नेतृत्व व कार्यकारी अधिकारी का प्रशासनिक पृथक्करण',
              descriptionEn:
                  'The Chairperson provides policy guidance and presides over meetings; executive management of staff, tenders, official registers, and payments is the statutory duty of the BDPO.',
              descriptionHi:
                  'अध्यक्ष नीतिगत नेतृत्व करते हैं; कर्मचारी प्रशासन, टेंडर प्रक्रिया, रिकॉर्ड संधारण व भुगतान बीडीपीओ का वैधानिक दायित्व है।',
              responsibilityType: ResponsibilityType.departmentalResponsibility,
              representativeRoleEn: 'Respects the statutory boundary between political governance and executive administration under Section 65.',
              representativeRoleHi: 'धारा 65 के तहत नीतिगत नेतृत्व और प्रशासनिक अधिकारों की कानूनी सीमा का सम्मान करना अनिवार्य है।',
              intendedResultEn: 'Clear institutional accountability avoiding political interference in administrative operations.',
              intendedResultHi: 'स्पष्ट प्रशासनिक जवाबदेही और सरकारी कार्यों में अवैध राजनीतिक दखलंदाजी पर रोक।',
              practicalProcessEn: 'Policy direction via house resolution -> Executive implementation strictly handled by BDPO and engineering staff.',
              practicalProcessHi: 'सदन के प्रस्ताव से नीति तय करना -> बीडीपीओ व तकनीकी कर्मचारियों द्वारा नियमों के अनुसार निष्पादन।',
              verificationEvidenceEn: 'Official government conduct rules and Section 65 statutory mandate.',
              verificationEvidenceHi: 'हरियाणा पंचायती राज अधिनियम धारा 65 और आधिकारिक सेवा नियमावली।',
              statutoryCitation: 'The Haryana Panchayati Raj Act, 1994, Sec. 65',
            ),
            DutyItem(
              titleEn: 'No Unilateral Financial Signing or Tender Awarding Authority',
              titleHi: 'बिना समिति प्रस्ताव व विहित नियमों के अकेले वित्तीय शक्ति नहीं',
              descriptionEn:
                  'The Chairperson cannot independently withdraw Samiti funds, sign contractor cheques, or award works without an affirmative house resolution, technical sanction, and BDPO co-authorization.',
              descriptionHi:
                  'अध्यक्ष अकेले समिति निधि से पैसे नहीं निकाल सकते, न ही बिना सदन के प्रस्ताव और तकनीकी स्वीकृति के कोई टेंडर दे सकते हैं।',
              responsibilityType: ResponsibilityType.requiresApproval,
              representativeRoleEn: 'Must disburse all funds through formal house approval and joint PFMS authorization; personal contracting is forbidden.',
              representativeRoleHi: 'सभी भुगतान केवल सदन के प्रस्ताव और संयुक्त डिजिटल हस्ताक्षर से ही स्वीकृत किए जाते हैं; अकेले कोई ठेका देना वर्जित है।',
              intendedResultEn: 'Complete fiscal integrity and prevention of corruption in block public contracting.',
              intendedResultHi: 'ब्लॉक विकास कार्यों में पूर्ण वित्तीय ईमानदारी और भ्रष्टाचार पर प्रभावी रोकथाम।',
              practicalProcessEn: 'Formal tender process via e-tender Haryana -> Verification by BDPO & technical branch -> Joint fund release.',
              practicalProcessHi: 'ई-टेंडर पोर्टल से निविदा -> बीडीपीओ व तकनीकी विंग द्वारा जांच -> संयुक्त वित्तीय भुगतान।',
              verificationEvidenceEn: 'Haryana government e-procurement audit logs and local fund audit certificate.',
              verificationEvidenceHi: 'ई-प्रोक्योरमेंट ऑडिट लॉग और महालेखाकार (AG) स्थानीय निधि लेखापरीक्षा रिपोर्ट।',
              statutoryCitation: 'The Haryana Panchayati Raj Act, 1994, Sec. 98 & 101',
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // PANCHAYAT SAMITI MEMBER (BDC / Block Samiti Sadasya)
  // =========================================================================
  static RepresentativeRoleProfile _buildPanchayatSamitiMemberProfile(bool isHaryana) {
    return RepresentativeRoleProfile(
      role: RepresentativeRole.panchayatSamitiMember,
      titleEn: 'Panchayat Samiti Member (BDC / Block Level)',
      titleHi: 'पंचायत समिति सदस्य (BDC / ब्लॉक स्तर)',
      governingBodyEn: 'Panchayat Samiti (Territorial Constituency)',
      governingBodyHi: 'पंचायत समिति (क्षेत्रीय निर्वाचन क्षेत्र)',
      constitutionalPostSummaryEn:
          'Directly elected representative of a territorial constituency (ward) within the intermediate block tier under Article 243C. Responsible for representing the villages of the constituency, raising local connectivity and public asset requirements, participating in Samiti debates, voting on resolutions and annual budgets, examining scheme allocations, and serving on statutory standing committees.',
      constitutionalPostSummaryHi:
          'संविधान के अनुच्छेद 243C के तहत मध्यवर्ती ब्लॉक स्तर पर अपने प्रादेशिक निर्वाचन क्षेत्र (वार्ड) से प्रत्यक्ष निर्वाचित प्रतिनिधि। अपने क्षेत्र के गांवों की समस्याओं को उठाना, संपर्क मार्ग व जनसुविधाओं के प्रस्ताव रखना, पंचायत समिति की बहसों में भाग लेना, बजट व प्रस्तावों पर मतदान करना, योजनाओं की समीक्षा करना और स्थायी समितियों में दायित्व निभाना इनका मुख्य कार्य है।',
      legalReference: LegalSourceReference(
        sourceTitle: isHaryana
            ? 'The Haryana Panchayati Raj Act, 1994 (Haryana Act No. 11 of 1994)'
            : 'General Model Guidance (National Intermediate Panchayat Governance Framework)',
        relevantSections: isHaryana
            ? 'Sections 56 (Constitution & Territorial Constituencies), 60 (Term of Office), 66 (Meetings & Voting Rights), 75 (Panchayat Samiti Functions), 83 (Standing Committees)'
            : 'Constitution of India (73rd Amendment), Articles 243C, 243E, 243G & Model Panchayati Raj Legislation',
        jurisdictionState: isHaryana ? 'Haryana' : 'General / Model Framework',
        sourceUrl: isHaryana ? haryanaActPdfUrl : moprUrl,
        lastVerifiedDate: '2026-10-26',
        isStateSpecific: isHaryana,
        officialGuidanceNoteEn: isHaryana
            ? 'Statutory provisions governing elected Panchayat Samiti members under the Haryana Panchayati Raj Act, 1994.'
            : 'General Model Guidance for elected intermediate block panchayat members (BDC / Samiti members). Refer to state-specific rules for local committee procedures.',
        officialGuidanceNoteHi: isHaryana
            ? 'हरियाणा पंचायती राज अधिनियम, 1994 के अंतर्गत पंचायत समिति सदस्यों के वैधानिक प्रावधान।'
            : 'निर्वाचित मध्यवर्ती ब्लॉक पंचायत सदस्यों (BDC) के लिए सामान्य मॉडल मार्गदर्शन। स्थानीय समिति प्रक्रियाओं के लिए राज्य नियमों का संदर्भ लें।',
      ),
      citizenQa: const [
        CitizenQaItem(
          questionEn: 'What can an individual Panchayat Samiti (BDC) member do for our villages?',
          questionHi: 'पंचायत समिति (BDC) सदस्य हमारे गांवों के लिए क्या कर सकते हैं?',
          answerEn:
              'A member proposes development works for villages in their constituency during bi-monthly Samiti meetings—such as paving inter-village link roads, repairing block drainage outfalls, upgrading veterinary centres, and installing solar lighting. They vote on the allocation of block grants and review progress.',
          answerHi:
              'सदस्य पंचायत समिति की बैठकों में अपने क्षेत्र के गांवों के लिए प्रस्ताव रखते हैं—जैसे गांवों को जोड़ने वाले रास्तों को पक्का कराना, जल निकासी नाले बनवाना, पशु औषधालय का उन्नयन और सोलर लाइट लगवाना। वे ब्लॉक विकास बजट पर मतदान करते हैं और कार्यों की प्रगति की समीक्षा करते हैं।',
        ),
        CitizenQaItem(
          questionEn: 'Does a Panchayat Samiti member have an individual development fund quota?',
          questionHi: 'क्या पंचायत समिति सदस्य के पास व्यक्तिगत फंड कोटा होता है?',
          answerEn:
              'NO. Unless a state government officially notifies a specific discretionary scheme, an individual Samiti member has NO personal development quota or independent cheque-signing power. All development works must be approved through collective resolutions passed by the Panchayat Samiti within the sanctioned budget.',
          answerHi:
              'नहीं। जब तक राज्य सरकार द्वारा कोई विशेष विवेकाधीन योजना अधिसूचित न की जाए, किसी भी सदस्य के पास कोई व्यक्तिगत फंड कोटा या चेक काटने का अधिकार नहीं होता। सभी कार्य पंचायत समिति के सामूहिक प्रस्ताव द्वारा ही स्वीकृत किए जाते हैं।',
        ),
        CitizenQaItem(
          questionEn: 'Which works require Panchayat Samiti resolution and engineering sanction?',
          questionHi: 'किस काम में पंचायत समिति का प्रस्ताव और तकनीकी स्वीकृति चाहिए?',
          answerEn:
              'Any proposal initiated by a member requires a formal resolution passed by the Panchayat Samiti, technical sanction and cost estimation by the Panchayati Raj Engineering Wing (Junior Engineer / SDO), and administrative execution by the Block Development and Panchayat Officer (BDPO).',
          answerHi:
              'सदस्य द्वारा रखे गए किसी भी प्रस्ताव के लिए पंचायत समिति का औपचारिक प्रस्ताव, पंचायती राज इंजीनियरिंग विंग (कनिष्ठ अभियंता/एसडीओ) से तकनीकी स्वीकृति व लागत प्राक्कलन, और बीडीपीओ द्वारा प्रशासनिक क्रियान्वयन अनिवार्य होता है।',
        ),
        CitizenQaItem(
          questionEn: 'Can a Samiti member direct or override the Sarpanch or Gram Panchayat?',
          questionHi: 'क्या समिति सदस्य सरपंच या ग्राम पंचायत को कोई आदेश दे सकते हैं?',
          answerEn:
              'NO. The Gram Panchayat is an independent statutory local government tier. A Panchayat Samiti member cannot suspend a Sarpanch, veto Gram Sabha resolutions, or dictate village-level asset decisions. Their role is intermediate coordination between villages and the block.',
          answerHi:
              'नहीं। ग्राम पंचायत एक स्वतंत्र वैधानिक इकाई है। पंचायत समिति सदस्य किसी सरपंच को निलंबित नहीं कर सकते, न ही ग्राम सभा के प्रस्तावों को रद्द कर सकते हैं। उनका कार्य गांवों के बीच संपर्क और ब्लॉक स्तर पर समन्वय का है।',
        ),
        CitizenQaItem(
          questionEn: 'Where should citizens approach for block-level issues or scheme assistance?',
          questionHi: 'ब्लॉक स्तर की समस्याओं के लिए नागरिक कहाँ संपर्क करें?',
          answerEn:
              'Residents can meet their elected Samiti member to request that constituency priorities be tabled at the next Panchayat Samiti meeting. Official complaints regarding delayed works, poor construction quality, or scheme irregularities should also be submitted in writing to the BDPO Office or the District Collector.',
          answerHi:
              'नागरिक अपने समिति सदस्य से मिलकर अगली पंचायत समिति बैठक में अपने गांव की समस्याएं रखने का अनुरोध कर सकते हैं। निर्माण कार्य में देरी, घटिया सामग्री या योजनाओं में गड़बड़ी की आधिकारिक शिकायत बीडीपीओ कार्यालय या उपायुक्त को भी लिखित में दी जानी चाहिए।',
        ),
      ],
      legalLimitationsEn: const [
        'Has NO individual executive or financial signing authority; cannot independently issue tenders, sign cheques, or sanction government contracts.',
        'Does not hold an individual discretionary development fund quota unless specifically designated under official state legislation.',
        'Cannot exercise administrative authority over the Sarpanch, Gram Sachiv, or Gram Panchayat; cannot dismiss or suspend any village official.',
        'Cannot suspend, discipline, or direct government employees (teachers, doctors, patwaris); can only bring issues to the notice of the Samiti and BDPO.',
        'Possesses no police, magisterial, or judicial powers to adjudicate disputes or take law enforcement action.',
        'Cannot alter official eligibility criteria or guarantee benefits for welfare schemes independently.',
      ],
      legalLimitationsHi: const [
        'कोई व्यक्तिगत कार्यकारी या वित्तीय अधिकार नहीं है; अकेले टेंडर जारी करने, चेक काटने या ठेका मंजूर करने की शक्ति नहीं है।',
        'जब तक राज्य सरकार द्वारा विहित न किया जाए, कोई व्यक्तिगत विवेकाधीन फंड या खर्च का कोटा नहीं होता।',
        'सरपंच, ग्राम सचिव या ग्राम पंचायत पर कोई प्रशासनिक नियंत्रण नहीं है; किसी पंचायत प्रतिनिधि को निलंबित करने का अधिकार नहीं है।',
        'सरकारी कर्मचारियों (अध्यापक, डॉक्टर, पटवारी आदि) को निलंबित या अनुशासित करने का अधिकार नहीं है; केवल समिति में मुद्दा उठाया जा सकता है।',
        'किसी भी विवाद में फैसला सुनाने या कानून लागू करने का कोई न्यायिक या पुलिस अधिकार नहीं है।',
        'कल्याणकारी योजनाओं की पात्रता नियमों को बदलने या व्यक्तिगत स्तर पर लाभ की गारंटी देने का अधिकार नहीं है।',
      ],
      grievanceEscalationEn:
          'Constituency Level: Panchayat Samiti Member -> Block Level: Block Development & Panchayat Officer (BDPO) / Samiti Chairperson -> District Level: CEO, Zila Parishad / Additional Deputy Commissioner (ADC) -> Deputy Commissioner -> State Grievance Portal (CM Window) / Lokayukta.',
      grievanceEscalationHi:
          'क्षेत्र स्तर: पंचायत समिति सदस्य -> ब्लॉक स्तर: खंड विकास एवं पंचायत अधिकारी (BDPO) / समिति अध्यक्ष -> जिला स्तर: मुख्य कार्यकारी अधिकारी (CEO) जिला परिषद / अतिरिक्त उपायुक्त (ADC) -> उपायुक्त -> राज्य सीएम विंडो / लोकायुक्त।',
      categories: const [
        DutyCategorySection(
          category: DutyCategory.publicAssets,
          items: [
            DutyItem(
              titleEn: 'Inter-Village Link Roads and Drainage Proposals',
              titleHi: 'अंतर-ग्रामीण संपर्क मार्गों व जल निकासी का प्रस्ताव',
              descriptionEn:
                  'Identify and propose construction or repair of connecting roads, culverts, and common drainage channels linking villages within the member constituency.',
              descriptionHi:
                  'अपने निर्वाचन क्षेत्र के गांवों को जोड़ने वाले रास्तों, पुलियों व साझा नालों के निर्माण व मरम्मत का प्रस्ताव पंचायत समिति में रखना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              additionalResponsibilityTypes: [ResponsibilityType.collectiveResponsibility],
              procedureOrApprovalEn: 'Must be formally recorded in Panchayat Samiti meeting proceedings.',
              procedureOrApprovalHi: 'पंचायत समिति की बैठक की कार्यवाही में विधिवत दर्ज कराना अनिवार्य।',
              representativeRoleEn: 'Surveys constituency villages, consults local Panches/Sarpanches, and moves formal resolution in the bi-monthly house meeting.',
              representativeRoleHi: 'अपने क्षेत्र के गांवों का दौरा करते हैं, स्थानीय पंचायत प्रतिनिधियों से मिलकर मांगें तय करते हैं और समिति सदन में औपचारिक प्रस्ताव रखते हैं।',
              activitiesIncludedEn: 'Listing inter-village missing road links, estimating lengths, presenting written demands during question hour.',
              activitiesIncludedHi: 'कच्चे संपर्क मार्गों की सूची बनाना, लंबाई का अनुमान लगाना और बैठक के दौरान कार्यसूची में शामिल कराने के लिए लिखित आवेदन देना।',
              intendedResultEn: 'Sanction and funding of crucial connectivity routes benefiting multiple rural communities.',
              intendedResultHi: 'कई गांवों को लाभ पहुंचाने वाले संपर्क मार्गों की स्वीकृति और आवागमन का सुगम होना।',
              practicalProcessEn: 'Constituency representation -> Resolution passed in Samiti house -> Engineering wing estimate -> BDPO work order.',
              practicalProcessHi: 'क्षेत्रीय मांग पत्र -> समिति सदन से प्रस्ताव पारित -> तकनीकी विंग से प्राक्कलन -> बीडीपीओ द्वारा कार्य आदेश।',
              verificationEvidenceEn: 'Resolution text in official Samiti proceedings book and work code in Panchayat Samiti plan.',
              verificationEvidenceHi: 'पंचायत समिति कार्यवाही पंजिका में दर्ज प्रस्ताव और समिति विकास योजना में कार्य कोड।',
              statutoryCitation: 'The Haryana Panchayati Raj Act, 1994, Sec. 75',
            ),
            DutyItem(
              titleEn: 'On-Site Inspection of Sanctioned Block Public Works',
              titleHi: 'स्वीकृत ब्लॉक निर्माण कार्यों की गुणवत्ता की स्थल पर जांच',
              descriptionEn:
                  'Inspect ongoing development works in the constituency, check execution against approved specifications, and report substandard materials to the JE/SDO Panchayati Raj.',
              descriptionHi:
                  'अपने क्षेत्र में चल रहे कार्यों की स्थल पर जांच करना और घटिया सामग्री या कमी पाए जाने पर कनिष्ठ अभियंता/एसडीओ को सूचित करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              procedureOrApprovalEn: 'Written inspection report submitted to BDPO.',
              procedureOrApprovalHi: 'बीडीपीओ को लिखित निरीक्षण रिपोर्ट प्रेषित करना।',
              representativeRoleEn: 'Visits construction sites unannounced, checks material specifications, and forwards photographic evidence of deficiencies.',
              representativeRoleHi: 'निर्माण स्थलों का औचक निरीक्षण करते हैं, सामग्री की गुणवत्ता देखते हैं और कमी दिखने पर फोटो सहित बीडीपीओ को शिकायत देते हैं।',
              activitiesIncludedEn: 'Observing road thickness, checking cement-sand mix in culverts, speaking with villagers about contractor conduct.',
              activitiesIncludedHi: 'सड़क की मोटाई जांचना, पुलियों में कंक्रीट का अनुपात देखना और ठेकेदार के कार्य के प्रति ग्रामीणों से फीडबैक लेना।',
              intendedResultEn: 'Durable infrastructure built strictly to government engineering standards without siphoning of public money.',
              intendedResultHi: 'गुणवत्तापूर्ण व टिकाऊ निर्माण, जिससे घटिया सामग्री के इस्तेमाल और सरकारी पैसे की बर्बादी पर रोक लगे।',
              practicalProcessEn: 'Site inspection -> Written notice to BDPO / JE Panchayati Raj -> Verification before payment release.',
              practicalProcessHi: 'स्थल निरीक्षण -> बीडीपीओ व कनिष्ठ अभियंता को लिखित शिकायत -> अंतिम बिल पास होने से पूर्व सुधार।',
              verificationEvidenceEn: 'Copy of written complaint submitted to BDPO office with receipt stamp.',
              verificationEvidenceHi: 'बीडीपीओ कार्यालय में जमा कराई गई शिकायत की पावती रसीद।',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.schemesAndBeneficiaries,
          items: [
            DutyItem(
              titleEn: 'Citizen Awareness & Scheme Information Dissemination',
              titleHi: 'नागरिक जागरूकता व सरकारी योजनाओं की जानकारी पहुंचाना',
              descriptionEn:
                  'Educate constituency residents about central and state schemes including rural housing (PMAY-G), farm ponds, and community solar streetlights.',
              descriptionHi:
                  'क्षेत्र के ग्रामीणों को पीएम आवास योजना (ग्रामीण), खेत तालाब, सोलर लाइट व अन्य कल्याणकारी योजनाओं की पात्रता की जानकारी देना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              representativeRoleEn: 'Holds public meetings in villages of the constituency, explains welfare eligibility criteria, and helps citizens approach block helpdesks.',
              representativeRoleHi: 'क्षेत्र के गांवों में चौपाल लगाकर सरकारी योजनाओं के नियम समझाते हैं और पात्र ग्रामीणों को ब्लॉक कार्यालय से आवेदन में मदद करते हैं।',
              activitiesIncludedEn: 'Sharing scheme circulars, clarifying application procedures, guiding beneficiaries on portal registration.',
              activitiesIncludedHi: 'योजनाओं के दिशा-निर्देश साझा करना, आवेदन प्रक्रिया समझाना और अंत्योदय/सरल पोर्टल पर पंजीकरण में मार्गदर्शन देना।',
              intendedResultEn: 'High public literacy and elimination of predatory middlemen in government benefit distribution.',
              intendedResultHi: 'ग्रामीणों में जागरूकता और सरकारी योजनाओं में बिचौलियों व दलालों का खात्मा।',
              practicalProcessEn: 'Village interactions -> Informational handouts -> Liaison with block scheme nodal officers.',
              practicalProcessHi: 'गांवों में चौपाल -> योजना प्रपत्र वितरण -> ब्लॉक नोडल अधिकारी से समन्वय।',
              verificationEvidenceEn: 'Meeting records in constituency villages and scheme facilitation feedback entries.',
              verificationEvidenceHi: 'क्षेत्र के गांवों में आयोजित बैठकों का विवरण व सहायता प्राप्त नागरिकों की सूची।',
            ),
            DutyItem(
              titleEn: 'Support for Rural Livelihoods & Self-Help Groups',
              titleHi: 'ग्रामीण आजीविका व स्वयं सहायता समूहों (SHG) को प्रोत्साहन',
              descriptionEn:
                  'Encourage formation of women Self-Help Groups under National Rural Livelihoods Mission (NRLM) and coordinate with block cluster coordinators for bank linkages.',
              descriptionHi:
                  'राष्ट्रीय ग्रामीण आजीविका मिशन (NRLM) के तहत महिला स्वयं सहायता समूहों के गठन व ऋण सुविधा में ब्लॉक अधिकारियों से समन्वय करना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              additionalResponsibilityTypes: [ResponsibilityType.departmentalResponsibility],
              representativeRoleEn: 'Advocates for women economic empowerment, connects SHGs with block cluster coordinators, and supports local craft sales.',
              representativeRoleHi: 'महिला समूहों को आर्थिक रूप से सशक्त बनाने में सहयोग करते हैं, बैंकों से ऋण दिलाने में पैरवी करते हैं और उनके उत्पादों की बिक्री में मदद करते हैं।',
              activitiesIncludedEn: 'Attending SHG cluster federation meets, addressing bank credit delays with Lead District Manager, supporting community enterprises.',
              activitiesIncludedHi: 'समूहों की क्लस्टर बैठकों में भाग लेना, बैंक ऋण में देरी का मामला उठाना और ग्रामीण मेलों में स्टॉल दिलाने में सहयोग।',
              intendedResultEn: 'Sustainable supplementary income for rural women and growth of micro-enterprises in villages.',
              intendedResultHi: 'ग्रामीण महिलाओं की आर्थिक आत्मनिर्भरता और स्थानीय स्तर पर छोटे उद्योगों का विकास।',
              practicalProcessEn: 'SHG mobilization -> Coordination with Block Programme Manager (NRLM) -> Bank credit linkage review.',
              practicalProcessHi: 'महिला समूहों से संवाद -> ब्लॉक कार्यक्रम प्रबंधक (NRLM) संग बैठक -> बैंक ऋण स्वीकृत कराने में सहायता।',
              verificationEvidenceEn: 'NRLM block progress report and SHG meeting participation register.',
              verificationEvidenceHi: 'एनआरएलएम ब्लॉक प्रगति रिपोर्ट और महिला समूह बैठक उपस्थिति विवरण।',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.meetingsAndBudgets,
          items: [
            DutyItem(
              titleEn: 'Mandatory Attendance, Deliberation & Voting in Samiti Meetings',
              titleHi: 'समिति बैठकों में अनिवार्य उपस्थिति, बहस व मताधिकार',
              descriptionEn:
                  'Attend every statutory meeting of the Panchayat Samiti, articulate constituency priorities, review revenue/expenditure accounts, and vote on all resolutions.',
              descriptionHi:
                  'पंचायत समिति की बैठकों में नियमित उपस्थित रहना, क्षेत्र की बात रखना, आय-व्यय की समीक्षा करना और प्रत्येक प्रस्ताव पर मतदान करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              procedureOrApprovalEn: 'Absence from consecutive meetings without leave risks disqualification under Sec. 60.',
              procedureOrApprovalHi: 'बिना अनुमति लगातार बैठकों में अनुपस्थित रहने पर सदस्यता समाप्त हो सकती है (धारा 60)।',
              representativeRoleEn: 'Possesses one vote on every house resolution; actively questions block authorities on scheme delivery and performance.',
              representativeRoleHi: 'सदन के प्रत्येक प्रस्ताव पर एक मत का अधिकार; ब्लॉक अधिकारियों से योजनाओं के क्रियान्वयन और फंड उपयोग पर सवाल पूछते हैं।',
              activitiesIncludedEn: 'Submitting questions 7 days in advance, moving amendments to proposed works, voting on contracts and chairman motions.',
              activitiesIncludedHi: 'बैठक से पूर्व प्रश्न लगाना, प्रस्तावित कार्यों में संशोधन प्रस्ताव रखना और सभी प्रस्तावों पर पक्ष/विपक्ष में मतदान।',
              intendedResultEn: 'Robust legislative scrutiny preventing executive arbitrariness at the block level.',
              intendedResultHi: 'ब्लॉक प्रशासन पर निर्वाचित सदस्यों का कड़ा विधायी नियंत्रण और पारदर्शिता।',
              practicalProcessEn: 'Receipt of agenda notice -> Detailed review -> Participation in house debate -> Official voting and signing.',
              practicalProcessHi: 'एजेंडा नोटिस प्राप्ति -> फाइलों का अध्ययन -> सदन में बहस -> मतदान और उपस्थिति पंजिका पर हस्ताक्षर।',
              verificationEvidenceEn: 'Panchayat Samiti attendance register and recorded voting sheets in proceedings book.',
              verificationEvidenceHi: 'पंचायत समिति उपस्थिति रजिस्टर और कार्यवाही पंजिका में दर्ज मतदान रिकॉर्ड।',
              statutoryCitation: 'The Haryana Panchayati Raj Act, 1994, Sec. 60 & 66',
            ),
            DutyItem(
              titleEn: 'Examination of Annual Block Budget & Resource Allocation',
              titleHi: 'वार्षिक ब्लॉक बजट व संसाधन आवंटन की समीक्षा',
              descriptionEn:
                  'Scrutinize the annual draft budget prepared by the BDPO, ensure equitable fund distribution among all constituencies, and vote on budget passage.',
              descriptionHi:
                  'बीडीपीओ द्वारा तैयार बजट प्राक्कलन की समीक्षा करना, सभी क्षेत्रों के लिए न्यायसंगत बजट सुनिश्चित करना और बजट पर मतदान करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              additionalResponsibilityTypes: [ResponsibilityType.requiresApproval],
              representativeRoleEn: 'Fights for equitable distribution of block funds across all wards; votes in favor or moves budget reduction motions.',
              representativeRoleHi: 'सभी वार्डों में बजट के समान वितरण की वकालत करते हैं और बजट प्रस्तावों पर बहस कर मतदान करते हैं।',
              activitiesIncludedEn: 'Reviewing head-wise revenue and expenditure figures, demanding allocations for neglected pockets, voting on final passage.',
              activitiesIncludedHi: 'मद-वार आय-व्यय आंकड़ों की जांच, पिछड़े गांवों के लिए विशेष बजट की मांग और अंतिम बजट पर मतदान।',
              intendedResultEn: 'Fair distribution of public revenues without regional discrimination or political favoritism.',
              intendedResultHi: 'ब्लॉक के सभी गांवों में सरकारी बजट का निष्पक्ष व पारदर्शी वितरण।',
              practicalProcessEn: 'Draft budget circulation -> Scrutiny in house -> Debate -> Roll-call voting -> Final adoption.',
              practicalProcessHi: 'बजट प्रारूप का वितरण -> सदन में चर्चा -> बहस -> मतदान द्वारा बजट पारित।',
              verificationEvidenceEn: 'Signed budget document and recorded budget voting record in Samiti minutes.',
              verificationEvidenceHi: 'हस्ताक्षरित वार्षिक बजट प्रति और कार्यवाही रजिस्टर में दर्ज बजट मतदान प्रविष्टि।',
              statutoryCitation: 'The Haryana Panchayati Raj Act, 1994, Sec. 101',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.socialSectorCoordination,
          items: [
            DutyItem(
              titleEn: 'Active Service on Appointed Standing Committees',
              titleHi: 'नियुक्त स्थायी समितियों में सक्रिय दायित्व निर्वहन',
              descriptionEn:
                  'Serve as an elected member of the General Standing Committee, Finance Committee, or Social Justice Committee to review specialized sector proposals.',
              descriptionHi:
                  'धारा 83 के तहत गठित सामान्य, वित्त या सामाजिक न्याय स्थायी समिति में सदस्य के रूप में विभागीय प्रस्तावों की विस्तृत जांच करना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              representativeRoleEn: 'Attends assigned standing committee sessions, scrutinizes departmental schemes in detail, and drafts recommendations.',
              representativeRoleHi: 'स्थायी समिति की बैठकों में भाग लेते हैं, विभागीय फाइलों की गहराई से जांच करते हैं और सुधार की सिफारिशें तैयार करते हैं।',
              activitiesIncludedEn: 'Evaluating social justice welfare grants, checking SC/ST beneficiary allocations, vetting proposed construction tenders.',
              activitiesIncludedHi: 'अनुसूचित जाति/पिछड़े वर्ग कल्याण अनुदानों की जांच, छात्रवृत्ति वितरण की समीक्षा और निर्माण निविदाओं का मूल्यांकन।',
              intendedResultEn: 'Focused sector-specific governance ensuring welfare benefits reach vulnerable demographics.',
              intendedResultHi: 'वंचित व गरीब वर्गों तक सरकारी योजनाओं का शत-प्रतिशत लाभ पहुंचाना।',
              practicalProcessEn: 'Committee appointment -> Regular meetings -> Field inquiries -> Report submission to full house.',
              practicalProcessHi: 'समिति में मनोनयन -> नियमित बैठकें -> स्थलीय जांच -> सदन को सिफारिशें प्रस्तुत करना।',
              verificationEvidenceEn: 'Standing committee attendance register and signed committee inquiry reports.',
              verificationEvidenceHi: 'स्थायी समिति उपस्थिति रजिस्टर और समिति द्वारा हस्ताक्षरित जांच रिपोर्ट।',
              statutoryCitation: 'The Haryana Panchayati Raj Act, 1994, Sec. 83',
            ),
            DutyItem(
              titleEn: 'Highlighting Rural Healthcare, Veterinary & School Needs',
              titleHi: 'स्वास्थ्य केंद्र, पशु औषधालय व स्कूल सुविधाओं की मांग उठाना',
              descriptionEn:
                  'Represent community requirements for doctors, medicines, school building repairs, and clean drinking water facilities to departmental officers during Samiti meetings.',
              descriptionHi:
                  'प्राथमिक स्वास्थ्य केंद्र, पशु अस्पताल व स्कूलों में अध्यापकों व सुविधाओं की कमी को समिति बैठक में विभागीय अधिकारियों के समक्ष उठाना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              additionalResponsibilityTypes: [ResponsibilityType.departmentalResponsibility],
              representativeRoleEn: 'Acts as citizen spokesperson for constituency health and education facilities; questions line department representatives directly.',
              representativeRoleHi: 'क्षेत्र के स्कूलों व डिस्पेंसरियों की बदहाली पर सीधे संबंधित विभागीय अधिकारियों से जवाब मांगते हैं।',
              activitiesIncludedEn: 'Listing vacant teacher posts in constituency schools, noting drug shortages at PHCs, demanding new veterinary outposts.',
              activitiesIncludedHi: 'शिक्षकों के रिक्त पदों की सूची बनाना, स्वास्थ्य केंद्र पर दवाओं की कमी दर्ज कराना और नए पशु अस्पताल की मांग रखना।',
              intendedResultEn: 'Administrative responsiveness leading to prompt repair of facilities and posting of essential personnel.',
              intendedResultHi: 'गांवों में डॉक्टरों, अध्यापकों व दवाओं की उपलब्धता और सरकारी भवनों की समय पर मरम्मत।',
              practicalProcessEn: 'Collection of village complaints -> Tabling during Samiti question hour -> Officer assurance recorded in minutes.',
              practicalProcessHi: 'ग्रामीणों की शिकायतें एकत्र करना -> समिति बैठक में प्रश्न उठाना -> अधिकारी का जवाब कार्यवाही में दर्ज कराना।',
              verificationEvidenceEn: 'Question notices submitted to BDPO and departmental responses recorded in minutes.',
              verificationEvidenceHi: 'बीडीपीओ को दिए गए प्रश्न पत्र और कार्यवाही रजिस्टर में दर्ज विभागीय उत्तर।',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.welfareAndDisaster,
          items: [
            DutyItem(
              titleEn: 'Alerting Administration on Flooding, Drought & Crop Loss',
              titleHi: 'बाढ़, सूखा व फसल खराबे की प्रशासन को तुरंत सूचना देना',
              descriptionEn:
                  'Tour affected villages during hail, excessive rains, or pest attacks; alert the BDPO and Tehsildar, and assist revenue patwaris during special Girdawari assessments.',
              descriptionHi:
                  'ओलावृष्टि, जलभराव या कीट प्रकोप में गांवों का दौरा कर बीडीपीओ व तहसीलदार को सूचित करना और विशेष गिरदावरी में सहयोग करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              representativeRoleEn: 'Conducts rapid field assessment during natural disasters, alerts district magistrates, and ensures no damaged village is left out.',
              representativeRoleHi: 'आपदा के समय तुरंत खेतों व गांवों का मुआयना करते हैं, प्रशासन को सतर्क करते हैं और गिरदावरी में हर किसान का नुकसान दर्ज कराते हैं।',
              activitiesIncludedEn: 'Photographing waterlogged crops, coordinating tractor pumps, accompanying Patwari during field assessment.',
              activitiesIncludedHi: 'डूबी हुई फसलों की तस्वीरें लेना, पानी निकासी हेतु पंपों की व्यवस्था कराना और पटवारी के साथ गिरदावरी में उपस्थित रहना।',
              intendedResultEn: 'Accurate and timely crop loss documentation ensuring fair compensation payouts to affected farmers.',
              intendedResultHi: 'फसल नुकसान का सही आकलन जिससे पीड़ित किसानों को समय पर पूरा सरकारी मुआवजा मिल सके।',
              practicalProcessEn: 'Field inspection -> Urgent message to BDPO/Tehsildar -> Joint Girdawari assistance -> Compensation tracking.',
              practicalProcessHi: 'खेतों का दौरा -> बीडीपीओ व तहसीलदार को आपात संदेश -> संयुक्त गिरदावरी में सहयोग -> मुआवजा वितरण की निगरानी।',
              verificationEvidenceEn: 'Formal representation submitted to Sub-Divisional Magistrate (SDM) / Tehsildar.',
              verificationEvidenceHi: 'एसडीएम/तहसीलदार कार्यालय को सौंपी गई फसल क्षति रिपोर्ट व पावती।',
            ),
            DutyItem(
              titleEn: 'Facilitating Resolution of Shared Inter-Village Grievances',
              titleHi: 'साझा अंतर-ग्रामीण समस्याओं के समाधान में मध्यस्थता',
              descriptionEn:
                  'Bring together Sarpanches and elders of neighboring villages within the constituency to resolve disputes over field path connectivity and water outlet sharing.',
              descriptionHi:
                  'खेतों के रास्तों व पानी के मोघों से जुड़े विवादों में पड़ोसी ग्राम पंचायतों के बीच समन्वय स्थापित कर समाधान निकालना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              representativeRoleEn: 'Serves as impartial mediator between neighboring village panchayats on common boundaries and waterways.',
              representativeRoleHi: 'पड़ोसी पंचायतों के बीच आम रास्तों व पानी की निकासी को लेकर निष्पक्ष मध्यस्थ की भूमिका निभाते हैं।',
              activitiesIncludedEn: 'Convening joint village meetings, visiting dispute sites with revenue staff, brokering amicable written accords.',
              activitiesIncludedHi: 'दोनों गांवों के मौजिज लोगों की साझा बैठक बुलाना, मौके पर जाकर स्थिति देखना और लिखित समझौते पर सहमति बनाना।',
              intendedResultEn: 'Peaceful community relations preventing prolonged police cases and expensive court litigation.',
              intendedResultHi: 'गांवों में आपसी सद्भाव व भाईचारा, जिससे ग्रामीणों का समय और पैसा कोर्ट-कचहरी में बर्बाद न हो।',
              practicalProcessEn: 'Community grievance received -> Joint consultation convened -> Compromise recorded -> Endorsement by Samiti.',
              practicalProcessHi: 'विवाद का आवेदन -> संयुक्त बैठक -> आपसी समझौते का मसौदा -> पंचायत समिति में सूचना।',
              verificationEvidenceEn: 'Compromise agreement signed by both village delegations and Samiti member.',
              verificationEvidenceHi: 'दोनों गांवों के प्रतिनिधियों व समिति सदस्य द्वारा हस्ताक्षरित समझौता पत्र।',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.legalLimitsAndExclusions,
          items: [
            DutyItem(
              titleEn: 'No Individual Financial Signing or Discretionary Quotas',
              titleHi: 'कोई व्यक्तिगत वित्तीय हस्ताक्षर अधिकार या विवेकाधीन कोटा नहीं',
              descriptionEn:
                  'A Panchayat Samiti member has NO personal development funds, cannot sanction contracts, and cannot sign cheques or disburse money independently.',
              descriptionHi:
                  'सदस्य के पास कोई व्यक्तिगत फंड नहीं होता, वे अकेले कोई टेंडर नहीं दे सकते और न ही कोई भुगतान चेक जारी कर सकते हैं।',
              responsibilityType: ResponsibilityType.requiresApproval,
              representativeRoleEn: 'Must make clear to citizens that all development allocations are collective decisions of the house, not individual discretionary grants.',
              representativeRoleHi: 'नागरिकों को स्पष्ट करते हैं कि विकास कार्य सदन के सामूहिक प्रस्ताव से पास होते हैं, किसी सदस्य के व्यक्तिगत कोटे से नहीं।',
              intendedResultEn: 'Prevents misleading claims, financial corruption, and unlawful promises to voters.',
              intendedResultHi: 'फर्जी वादों, वित्तीय धोखाधड़ी और जनता को गुमराह करने पर रोक।',
              practicalProcessEn: 'All proposals must go through the formal Samiti legislative procedure and government e-procurement.',
              practicalProcessHi: 'सभी प्रस्ताव विधिवत सदन में पारित होकर ही सरकारी ई-टेंडरिंग द्वारा लागू होते हैं।',
              verificationEvidenceEn: 'State government Panchayati Raj finance rules and absence of individual member drawing accounts.',
              verificationEvidenceHi: 'हरियाणा पंचायती राज वित्त नियमावली और बैंक खातों का आधिकारिक प्रारूप।',
              statutoryCitation: 'The Haryana Panchayati Raj Act, 1994, Sec. 98',
            ),
            DutyItem(
              titleEn: 'No Disciplinary Authority over Government Staff or Sarpanch',
              titleHi: 'कर्मचारियों या सरपंच पर कोई अनुशासनात्मक अधिकार नहीं',
              descriptionEn:
                  'A member cannot suspend, transfer, or issue disciplinary notices to government employees or village Sarpanches; issues must be raised through formal administrative channels.',
              descriptionHi:
                  'सदस्य किसी सरकारी कर्मचारी या ग्राम सरपंच को निलंबित या स्थानांतरित नहीं कर सकते; शिकायत केवल सक्षम अधिकारी को दी जा सकती है।',
              responsibilityType: ResponsibilityType.departmentalResponsibility,
              representativeRoleEn: 'Exercises legislative oversight without encroaching upon the executive chain of command or village panchayat autonomy.',
              representativeRoleHi: 'विधायी निगरानी का प्रयोग करते हैं किंतु प्रशासनिक शक्तियों या ग्राम पंचायत की स्वायत्तता में दखल नहीं दे सकते।',
              intendedResultEn: 'Preserves the statutory hierarchy and administrative discipline across local bodies.',
              intendedResultHi: 'प्रशासनिक अनुशासन और त्रि-स्तरीय पंचायती राज व्यवस्था में संस्थागत स्वायत्तता की रक्षा।',
              practicalProcessEn: 'Grievance against official -> Written representation to BDPO/ADC -> Inquiry by appointing authority.',
              practicalProcessHi: 'कर्मचारी की शिकायत -> बीडीपीओ/उपायुक्त को लिखित प्रतिवेदन -> सक्षम अधिकारी द्वारा विभागीय जांच।',
              verificationEvidenceEn: 'Official government service rules and Section 51/65 statutory mandates.',
              verificationEvidenceHi: 'हरियाणा पंचायती राज अधिनियम धारा 51 व 65 के आधिकारिक प्रावधान।',
              statutoryCitation: 'The Haryana Panchayati Raj Act, 1994, Sec. 51 & 65',
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // ZILA PARISHAD CHAIRPERSON (District Council President / Zila Pramukh)
  // =========================================================================
  static RepresentativeRoleProfile _buildZilaParishadChairpersonProfile(String? stateIdentifier) {
    final bool isHaryana = stateIdentifier == 'haryana';
    final bool isRajasthan = stateIdentifier == 'rajasthan';
    final bool isStateSpecific = isHaryana || isRajasthan;

    final String sourceTitle = isHaryana
        ? 'The Haryana Panchayati Raj Act, 1994 (Haryana Act No. 11 of 1994)'
        : (isRajasthan
            ? 'The Rajasthan Panchayati Raj Act, 1994 (Act No. 13 of 1994)'
            : 'General Model Guidance (National Local Governance Framework)');

    final String relevantSections = isHaryana
        ? 'Sections 117 (Constitution), 121 (Powers and duties of President), 123 (Emergency Powers), 127 (Meetings & Casting Vote), 133 (CEO Executive Authority), 137 (Functions), 139 (Standing Committees), 146 (Annual Budget)'
        : (isRajasthan
            ? 'Sections 14 (Composition), 26 (Election of Zila Pramukh), 32 (Powers, Duties & Functions of Zila Pramukh), 56 (Standing Committees), 57 (Functions of Zila Parishad), 60 (CEO Powers), 65 (Budget)'
            : 'Constitution (73rd Amendment) Act, 1992, Articles 243B, 243C, 243G (Eleventh Schedule) & Respective State Panchayati Raj Acts');

    final String jurisdictionState = isHaryana
        ? 'Haryana'
        : (isRajasthan ? 'Rajasthan' : 'General / Model Framework');

    final String sourceUrl = isHaryana
        ? haryanaActPdfUrl
        : (isRajasthan ? rajasthanActUrl : moprUrl);

    final String officialGuidanceNoteEn = isHaryana
        ? 'Statutory provisions governing apex district rural councils under Department of Development and Panchayats, Government of Haryana.'
        : (isRajasthan
            ? 'Statutory provisions governing apex district panchayats under Panchayati Raj Department, Government of Rajasthan. Zila Pramukh heads the elected council.'
            : 'General Model Guidance grounded in Constitutional Panchayati Raj provisions. Specific state-level legislation for this jurisdiction has not yet been verified in the app database; consult the respective State Panchayati Raj Act for local financial powers, standing committee rules, and delegated administrative thresholds.');

    final String officialGuidanceNoteHi = isHaryana
        ? 'हरियाणा विकास एवं पंचायत विभाग के अंतर्गत शीर्ष जिला परिषद के वैधानिक प्रावधान।'
        : (isRajasthan
            ? 'राजस्थान पंचायती राज विभाग के अंतर्गत वैधानिक प्रावधान। जिला प्रमुख निर्वाचित परिषद का नेतृत्व करते हैं।'
            : '73वें संविधान संशोधन पर आधारित सामान्य मॉडल मार्गदर्शन। इस अधिकार क्षेत्र के लिए राज्य-विशिष्ट पंचायती राज कानून अभी ऐप डेटाबेस में सत्यापित नहीं है; वित्तीय शक्तियों व समिति नियमों के लिए संबंधित राज्य के अधिनियम का संदर्भ लें।');

    return RepresentativeRoleProfile(
      role: RepresentativeRole.zilaParishadChairperson,
      titleEn: isRajasthan
          ? 'Zila Pramukh (Zila Parishad Chairperson)'
          : 'Zila Parishad Chairperson (Zila Pramukh / President)',
      titleHi: isRajasthan
          ? 'जिला प्रमुख (जिला परिषद अध्यक्ष)'
          : 'जिला परिषद अध्यक्ष (जिला प्रमुख)',
      governingBodyEn: 'Zila Parishad (Apex District Rural Tier)',
      governingBodyHi: 'जिला परिषद (शीर्ष जिला ग्रामीण निकाय)',
      constitutionalPostSummaryEn:
          'Elected political head of the apex district tier of Panchayati Raj under Article 243C(5). Responsible for presiding over Zila Parishad meetings, coordinating inter-block rural infrastructure, guiding preparation of the comprehensive District Development Plan, leading the Finance and Planning Standing Committee, and overseeing implementation of rural welfare programmes in coordination with the Chief Executive Officer (CEO).',
      constitutionalPostSummaryHi:
          'संविधान के अनुच्छेद 243C(5) के तहत निर्वाचित सदस्यों द्वारा चुने गए शीर्ष जिला ग्रामीण निकाय (जिला परिषद) के राजनीतिक प्रमुख। परिषद की बैठकों की अध्यक्षता करना, ब्लॉक स्तर की योजनाओं को एकीकृत कर जिला विकास योजना तैयार कराना, वित्त एवं योजना स्थायी समिति का नेतृत्व करना और मुख्य कार्यकारी अधिकारी (CEO) के साथ मिलकर ग्रामीण विकास कार्यों की प्रगति की निगरानी करना इनका मुख्य दायित्व है।',
      legalReference: LegalSourceReference(
        sourceTitle: sourceTitle,
        relevantSections: relevantSections,
        jurisdictionState: jurisdictionState,
        sourceUrl: sourceUrl,
        lastVerifiedDate: '2026-10-26',
        isStateSpecific: isStateSpecific,
        officialGuidanceNoteEn: officialGuidanceNoteEn,
        officialGuidanceNoteHi: officialGuidanceNoteHi,
      ),
      citizenQa: const [
        CitizenQaItem(
          questionEn: 'What can this representative do? (What can a Zila Parishad Chairperson do?)',
          questionHi: 'जिला परिषद अध्यक्ष जिले के लिए क्या-क्या कर सकते हैं?',
          answerEn:
              'A Chairperson convenes and presides over statutory meetings of the Zila Parishad, guides preparation of the District Development Plan consolidating proposals from all Panchayat Samitis, heads the Finance and Planning Standing Committee, allocates district plan grants across rural blocks, and reviews progress of government development schemes across the district.',
          answerHi:
              'जिला परिषद की बैठकों की अध्यक्षता करते हैं, सभी पंचायत समितियों के प्रस्तावों को मिलाकर जिला विकास योजना तैयार करवाते हैं, वित्त व योजना स्थायी समिति का नेतृत्व करते हैं, ग्रामीण ब्लॉकों के बीच जिला योजना अनुदानों का आवंटन करवाते हैं और विकास योजनाओं की प्रगति की समीक्षा करते हैं।',
        ),
        CitizenQaItem(
          questionEn: 'What is the Chairperson personally responsible for?',
          questionHi: 'जिला परिषद अध्यक्ष की व्यक्तिगत जिम्मेदारी क्या है?',
          answerEn:
              'Ensuring statutory meetings are held at least once every three months, maintaining decorum, casting a deciding vote only in event of equality of votes where authorized, placing the annual Zila Parishad budget before the house for approval, and coordinating emergency relief with the District Magistrate during floods or natural disasters.',
          answerHi:
              'नियमों के तहत हर तीन माह में कम से कम एक बार बैठक बुलाना, सदन का सुचारू संचालन, मत बराबर होने पर निर्णायक मत (कास्टिंग वोट) देना, वार्षिक बजट सदन में पारित कराना और बाढ़ या प्राकृतिक आपदा में जिलाधिकारी/उपायुक्त के साथ समन्वय कर राहत कार्य सुनिश्चित करना।',
        ),
        CitizenQaItem(
          questionEn: 'Which works require collective council approval or higher sanction?',
          questionHi: 'किस काम में जिला परिषद या उच्चाधिकारी की मंजूरी चाहिए?',
          answerEn:
              'All district rural works, tender sanctions, and budget disbursements require an affirmative collective resolution of the Zila Parishad, technical approval from the Panchayati Raj Engineering Wing (Superintending Engineer / Executive Engineer), and administrative execution by the Chief Executive Officer (CEO). The Chairperson cannot independently award tenders or sign contractor cheques.',
          answerHi:
              'सभी जिला ग्रामीण निर्माण कार्यों, टेंडरों और बजट आवंटन के लिए जिला परिषद का सामूहिक प्रस्ताव, पंचायती राज इंजीनियरिंग विंग (अधीक्षण/अधिशासी अभियंता) से तकनीकी स्वीकृति और मुख्य कार्यकारी अधिकारी (CEO) द्वारा प्रशासनिक क्रियान्वयन अनिवार्य होता है। अध्यक्ष अकेले कोई ठेका या चेक जारी नहीं कर सकते।',
        ),
        CitizenQaItem(
          questionEn: 'Which works belong to state departments or external agencies?',
          questionHi: 'ये काम किस सरकारी विभाग के अधीन आते हैं?',
          answerEn:
              'State highways and national highways belong to PWD / NHAI; major piped water supply and canal irrigation belong to PHED and Water Resources; high-voltage rural power grids belong to State Power Discoms; district hospitals belong to Health Department; law and order belongs to District Police; criminal courts belong to the Judiciary.',
          answerHi:
              'राज्य व राष्ट्रीय राजमार्ग लोक निर्माण विभाग (PWD) / NHAI के अधीन हैं; बड़ी नहरें व पेयजल योजनाएं सिंचाई व जनस्वास्थ्य विभाग (PHED) के पास हैं; हाई-टेंशन बिजली लाइनें व ग्रिड बिजली निगम के पास हैं; जिला अस्पताल स्वास्थ्य विभाग के पास हैं; कानून-व्यवस्था पुलिस प्रशासन का कार्य है; और न्यायिक मामले न्यायालयों के अधीन हैं।',
        ),
        CitizenQaItem(
          questionEn: 'Where and how should citizens raise grievances or report district irregularities?',
          questionHi: 'जिला स्तर की शिकायत कहाँ और कैसे करें?',
          answerEn:
              'Submit a written petition to the Chairperson or the Chief Executive Officer (CEO, Zila Parishad) at the District Zila Parishad Office. For unresolved issues or corruption, escalate to the Deputy Commissioner / District Magistrate, State Directorate of Panchayats, or lodge a complaint on the official state grievance portal (e.g. CM Window Haryana / Rajasthan Sampark).',
          answerHi:
              'जिला परिषद कार्यालय में अध्यक्ष या मुख्य कार्यकारी अधिकारी (CEO, जिला परिषद) को लिखित आवेदन दें। समाधान न होने या भ्रष्टाचार के मामलों में उपायुक्त/जिलाधिकारी, पंचायती राज निदेशालय को शिकायत दें या राज्य के आधिकारिक समाधान पोर्टल (सीएम विंडो / राजस्थान संपर्क) पर ऑनलाइन दर्ज करें।',
        ),
      ],
      legalLimitationsEn: [
        isHaryana
            ? 'Executive administration and financial disbursements are statutorily vested in the Chief Executive Officer (CEO) under Section 133 of the Haryana Panchayati Raj Act, 1994; the President exercises political and policy leadership.'
            : (isRajasthan
                ? 'Executive administration and financial disbursements are statutorily vested in the Chief Executive Officer (CEO) under Section 60 / Section 84 of the Rajasthan Panchayati Raj Act, 1994; the Zila Pramukh maintains supervision.'
                : 'Executive administration and financial disbursements are statutorily vested in the Chief Executive Officer (CEO); political leadership exercises policy supervision.'),
        'Does NOT hold executive authority over district civil servants; day-to-day staff control, contracts, e-tendering, and bill disbursements are statutorily vested in the Chief Executive Officer (CEO, Zila Parishad).',
        'Cannot unilaterally expend Zila Parishad funds or issue payment cheques without a formal resolution passed by the council and approved budgetary allocation.',
        'Has no legal authority to suspend, transfer, or discipline government officials (doctors, engineers, BDPOs, teachers); can only table resolutions or submit inquiry recommendations to competent state authorities.',
        'Cannot dissolve a Gram Panchayat or suspend a Sarpanch (statutory power strictly vested in the State Government / Deputy Commissioner).',
        'Possesses no judicial, criminal magistrate, or police powers to adjudicate private disputes or order detentions.',
        'Cannot alter statutory eligibility rules for welfare schemes (PMGSY, PMAY-G, pensions, NFSA) or independently issue entitlement certificates.',
      ],
      legalLimitationsHi: [
        isHaryana
            ? 'दैनिक कर्मचारी प्रशासन, अनुबंध व भुगतान का वैधानिक दायित्व धारा 133 के तहत मुख्य कार्यकारी अधिकारी (CEO) में निहित है।'
            : (isRajasthan
                ? 'दैनिक कर्मचारी प्रशासन, अनुबंध व भुगतान का वैधानिक दायित्व धारा 60 / धारा 84 के तहत मुख्य कार्यकारी अधिकारी (CEO) में निहित है।'
                : 'दैनिक कर्मचारी प्रशासन, अनुबंध व भुगतान का वैधानिक दायित्व मुख्य कार्यकारी अधिकारी (CEO) में निहित है।'),
        'अधिकारियों व कर्मचारियों पर कोई व्यक्तिगत कार्यकारी नियंत्रण नहीं है; दैनिक कर्मचारी प्रशासन, टेंडर प्रक्रिया व भुगतान का वैधानिक दायित्व मुख्य कार्यकारी अधिकारी (CEO, जिला परिषद) में निहित है।',
        'परिषद के विधिवत पारित प्रस्ताव और स्वीकृत बजट के बिना अकेले जिला परिषद निधि से राशि खर्च करने या चेक जारी करने का अधिकार नहीं है।',
        'सरकारी अधिकारियों (डॉक्टर, इंजीनियर, बीडीपीओ, अध्यापक आदि) को निलंबित, स्थानांतरित या दंडित करने का अधिकार नहीं है; केवल सरकार या सक्षम प्राधिकारी को जांच हेतु सिफारिश भेजी जा सकती है।',
        'ग्राम पंचायत को भंग करने या सरपंच को निलंबित करने का अधिकार नहीं है (यह शक्ति सरकार/उपायुक्त के पास सुरक्षित है)।',
        'किसी भी विवाद में फैसला सुनाने या बंदी बनाने का कोई न्यायिक या पुलिस अधिकार नहीं है।',
        'कल्याणकारी योजनाओं के पात्रता नियमों को बदलने या आधिकारिक सत्यापन के बिना लाभ देने का अधिकार नहीं है।',
      ],
      grievanceEscalationEn: isRajasthan
          ? 'District Level: Zila Pramukh / Chief Executive Officer (CEO), Zila Parishad -> District Collector -> State Level: Panchayati Raj Department -> Principal Secretary, Panchayati Raj -> Rajasthan Sampark Portal (181) / Lokayukta.'
          : (isHaryana
              ? 'District Level: Zila Parishad Chairperson / Chief Executive Officer (CEO), Zila Parishad -> Deputy Commissioner -> Divisional Level: Divisional Commissioner -> State Level: Directorate of Development & Panchayats -> CM Window Haryana / Lokayukta.'
              : 'District Level: Zila Parishad Chairperson / Chief Executive Officer (CEO), Zila Parishad -> District Magistrate -> State Level: Directorate of Panchayati Raj -> State Grievance Redressal Portal / Lokayukta.'),
      grievanceEscalationHi: isRajasthan
          ? 'जिला स्तर: जिला प्रमुख / मुख्य कार्यकारी अधिकारी (CEO), जिला परिषद -> जिला कलेक्टर -> राज्य स्तर: पंचायती राज विभाग -> प्रधान सचिव, पंचायती राज -> राजस्थान संपर्क पोर्टल (181) / लोकायुक्त।'
          : (isHaryana
              ? 'जिला स्तर: जिला परिषद अध्यक्ष / मुख्य कार्यकारी अधिकारी (CEO), जिला परिषद -> उपायुक्त -> मंडल स्तर: मंडलायुक्त (Divisional Commissioner) -> राज्य स्तर: विकास एवं पंचायत निदेशालय -> सीएम विंडो हरियाणा / लोकायुक्त।'
              : 'जिला स्तर: जिला परिषद अध्यक्ष / मुख्य कार्यकारी अधिकारी (CEO), जिला परिषद -> जिलाधिकारी -> राज्य स्तर: पंचायती राज निदेशालय -> राज्य शिकायत निवारण पोर्टल / लोकायुक्त।'),
      categories: [
        DutyCategorySection(
          category: DutyCategory.publicAssets,
          items: [
            DutyItem(
              titleEn: 'District Rural Road & Infrastructure Master Planning',
              titleHi: 'जिला ग्रामीण सड़क व बुनियादी ढांचा मास्टर प्लान',
              descriptionEn:
                  'Coordinate district-wide rural connecting road networks, intermediate bridges, and drainage outfalls spanning across multiple Panchayat Samitis.',
              descriptionHi:
                  'कई पंचायत समितियों को जोड़ने वाली मुख्य ग्रामीण सड़कों, पुलियों व बड़े ड्रेनों के जिला नेटवर्क की योजना तैयार करना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              procedureOrApprovalEn: 'Zila Parishad resolution + Technical sanction from Panchayati Raj Engineering Wing.',
              procedureOrApprovalHi: 'जिला परिषद का प्रस्ताव + पंचायती राज तकनीकी विंग से तकनीकी मंजूरी।',
              statutoryCitation: isHaryana
                  ? 'The Haryana Panchayati Raj Act, 1994, Sec. 137'
                  : (isRajasthan ? 'The Rajasthan Panchayati Raj Act, 1994, Sec. 57' : 'Constitution of India, Article 243G'),
            ),
            const DutyItem(
              titleEn: 'District Drainage Outfalls & Water Harvesting Networks',
              titleHi: 'जिला जल निकासी नाले व जल संचयन प्रणालियां',
              descriptionEn:
                  'Oversee regional stormwater channels, check dams, and watershed management projects covering more than one block.',
              descriptionHi:
                  'एक से अधिक ब्लॉकों में फैले जल संचयन प्रोजेक्ट्स, चेक डैम और मुख्य बरसाती नालों के प्रबंधन की निगरानी करना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
            ),
          ],
        ),
        const DutyCategorySection(
          category: DutyCategory.schemesAndBeneficiaries,
          items: [
            DutyItem(
              titleEn: 'District Rural Scheme Monitoring (MGNREGA, PMGSY & Jal Jeevan)',
              titleHi: 'जिला ग्रामीण योजनाओं की निगरानी (मनरेगा, पीएमजीएसवाई व जल जीवन)',
              descriptionEn:
                  'Review progress of rural connectivity (PMGSY), wage employment (MGNREGA), and piped rural drinking water coverage (Jal Jeevan Mission) across blocks.',
              descriptionHi:
                  'जिले भर में ग्रामीण सड़कों (PMGSY), मनरेगा और जल जीवन मिशन के तहत हर घर जल योजनाओं की प्रगति की समीक्षा करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              procedureOrApprovalEn: 'Quarterly review meetings with District Programme Coordinators / Executive Engineers.',
              procedureOrApprovalHi: 'जिला कार्यक्रम समन्वयकों व अधिशासी अभियंताओं के साथ त्रैमासिक समीक्षा बैठकें।',
            ),
            DutyItem(
              titleEn: 'Agricultural & Dairy Development Coordination',
              titleHi: 'कृषि, पशुपालन व दुग्ध विकास योजनाओं का समन्वय',
              descriptionEn:
                  'Promote district animal fairs, veterinary dispensaries, soil testing labs, and rural farmer producer organizations (FPOs).',
              descriptionHi:
                  'पशु मेलों, पशु चिकित्सालयों, मृदा परीक्षण प्रयोगशालाओं और कृषक उत्पादक संगठनों (FPO) को बढ़ावा देना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.meetingsAndBudgets,
          items: [
            DutyItem(
              titleEn: 'Convene and Preside over Statutory Zila Parishad Meetings',
              titleHi: 'जिला परिषद की बैठकों की अध्यक्षता व कार्यवाही का संचालन',
              descriptionEn:
                  'Convene quarterly meetings, approve meeting agendas prepared with the CEO, guide house debates, and exercise a casting vote in event of an equality of votes.',
              descriptionHi:
                  'त्रैमासिक बैठकें बुलाना, मुख्य कार्यकारी अधिकारी के साथ एजेंडा तय करना, लोकतांत्रिक कार्यवाही का संचालन और मत बराबर होने पर निर्णायक मत (कास्टिंग वोट) देना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              statutoryCitation: isHaryana
                  ? 'The Haryana Panchayati Raj Act, 1994, Sec. 123 & 127'
                  : (isRajasthan ? 'The Rajasthan Panchayati Raj Act, 1994, Sec. 32' : 'Constitution of India, Article 243C'),
            ),
            DutyItem(
              titleEn: 'District Development Plan Consolidation & Annual Budget Presentation',
              titleHi: 'जिला विकास योजना का एकीकरण व वार्षिक बजट प्रस्तुति',
              descriptionEn:
                  'Consolidate Panchayat Samiti plans into the District Development Plan and place the annual Zila Parishad budget before the house for approval and submission to State Government.',
              descriptionHi:
                  'ब्लॉक योजनाओं को एकीकृत कर जिला विकास योजना तैयार कराना और वार्षिक बजट सदन में पारित करवाकर राज्य सरकार को भेजना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              procedureOrApprovalEn: 'Zila Parishad resolution + Statutory sanction by State Government (Directorate of Panchayats).',
              procedureOrApprovalHi: 'परिषद का प्रस्ताव + राज्य सरकार (पंचायती राज निदेशालय) से वैधानिक स्वीकृति।',
              statutoryCitation: isHaryana
                  ? 'The Haryana Panchayati Raj Act, 1994, Sec. 146'
                  : (isRajasthan ? 'The Rajasthan Panchayati Raj Act, 1994, Sec. 65' : 'Constitution of India, Article 243G'),
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.socialSectorCoordination,
          items: [
            DutyItem(
              titleEn: 'Lead Statutory Standing Committees',
              titleHi: 'वैधानिक स्थायी समितियों का नेतृत्व व समन्वय',
              descriptionEn:
                  'Ex-officio Chairman of the General Standing Committee and Finance, Audit and Planning Standing Committee (Sec. 139), and coordinator for Social Justice and Education/Health committees.',
              descriptionHi:
                  'सामान्य स्थायी समिति (General Standing Committee) और वित्त, लेखा परीक्षा व योजना स्थायी समिति के पदेन अध्यक्ष तथा सामाजिक न्याय व शिक्षा/स्वास्थ्य समितियों के कार्यों का समन्वय।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              statutoryCitation: isHaryana
                  ? 'The Haryana Panchayati Raj Act, 1994, Sec. 139'
                  : (isRajasthan ? 'The Rajasthan Panchayati Raj Act, 1994, Sec. 56' : 'State Panchayati Raj Acts'),
            ),
            const DutyItem(
              titleEn: 'District Rural Healthcare & Secondary Education Coordination',
              titleHi: 'ग्रामीण स्वास्थ्य सुविधाएं व माध्यमिक शिक्षा का सुदृढ़ीकरण',
              descriptionEn:
                  'Coordinate with the Chief Medical Officer (CMO) and District Education Officer (DEO) to address staff shortages, ambulance availability, and rural school infrastructure.',
              descriptionHi:
                  'मुख्य चिकित्सा अधिकारी व जिला शिक्षा अधिकारी के साथ समन्वय कर स्वास्थ्य केंद्रों में डॉक्टरों व ग्रामीण स्कूलों में सुविधाओं की समीक्षा करना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.welfareAndDisaster,
          items: [
            DutyItem(
              titleEn: 'District Emergency Relief & Natural Disaster Response Coordination',
              titleHi: 'आपदा प्रबंधन, बाढ़ राहत व आपातकालीन कार्य समन्वय',
              descriptionEn: isHaryana
                  ? 'Exercise emergency powers under Section 122(1)(b) to direct immediate execution or stoppage of public safety works during natural calamities, floods, or epidemics, subject to mandatory reporting at the next council meeting.'
                  : (isRajasthan
                      ? 'Exercise emergency powers under Section 35 to sanction immediate relief during natural calamities in consultation with the CEO, subject to ratification by the Zila Parishad.'
                      : 'Coordinate emergency relief camps, fodder distribution, and drainage pumps with the District Magistrate during severe floods, hailstorms, or droughts under emergency powers.'),
              descriptionHi: isHaryana
                  ? 'धारा 122(1)(b) के तहत लोक सुरक्षा हेतु आपातकालीन अधिकार (Emergency Powers) से त्वरित कार्य कराने या रोकने का निर्देश देना, जिसकी अगली बैठक में पुष्टि अनिवार्य है।'
                  : (isRajasthan
                      ? 'धारा 35 के तहत प्राकृतिक आपदा में त्वरित राहत कार्य स्वीकृत करने का आपातकालीन अधिकार, जिसकी जिला परिषद द्वारा पुष्टि आवश्यक है।'
                      : 'बाढ़, ओलावृष्टि या सूखे की स्थिति में जिलाधिकारी के साथ मिलकर राहत शिविर, चारा डिपो और जल निकासी की व्यवस्था करना।'),
              responsibilityType: ResponsibilityType.statutoryDuty,
              procedureOrApprovalEn: 'Emergency action under relevant statutory powers with mandatory reporting at next council meeting.',
              procedureOrApprovalHi: 'आपातकालीन अधिकार के तहत कार्यवाही, जिसकी अगली बैठक में पुष्टि अनिवार्य है।',
              statutoryCitation: isHaryana
                  ? 'The Haryana Panchayati Raj Act, 1994, Sec. 122(1)(b)'
                  : (isRajasthan ? 'The Rajasthan Panchayati Raj Act, 1994, Sec. 35' : 'State Disaster Management Rules'),
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.legalLimitsAndExclusions,
          items: [
            DutyItem(
              titleEn: 'Administrative Separation of Political Leadership and Chief Executive Officer (CEO)',
              titleHi: 'राजनीतिक नेतृत्व व मुख्य कार्यकारी अधिकारी (CEO) का प्रशासनिक पृथक्करण',
              descriptionEn:
                  'The Chairperson leads policy deliberations and presides over meetings; executive administration of officers, e-tendering, contracts, and payments is the statutory duty of the CEO.',
              descriptionHi:
                  'अध्यक्ष नीतिगत नेतृत्व करते हैं; अधिकारियों का प्रशासनिक नियंत्रण, टेंडरिंग, अनुबंध व भुगतान मुख्य कार्यकारी अधिकारी (CEO) का वैधानिक कार्य है।',
              responsibilityType: ResponsibilityType.departmentalResponsibility,
              statutoryCitation: isHaryana
                  ? 'The Haryana Panchayati Raj Act, 1994, Sec. 133'
                  : (isRajasthan ? 'The Rajasthan Panchayati Raj Act, 1994, Sec. 60' : 'State Panchayati Raj Acts'),
            ),
            DutyItem(
              titleEn: 'No Discretionary Financial Withdrawals or Direct Employee Discipline',
              titleHi: 'बिना परिषद प्रस्ताव के अकेले वित्तीय लेनदेन या कर्मचारी निलंबन की मनाही',
              descriptionEn:
                  'The Chairperson cannot independently withdraw funds, sign contractor cheques, or suspend district officials without formal council resolutions and competent administrative sanction.',
              descriptionHi:
                  'अध्यक्ष अकेले परिषद कोष से राशि नहीं निकाल सकते, न ही किसी सरकारी अधिकारी को निलंबित कर सकते हैं।',
              responsibilityType: ResponsibilityType.requiresApproval,
              statutoryCitation: isHaryana
                  ? 'The Haryana Panchayati Raj Act, 1994, Sec. 145 & 146'
                  : (isRajasthan ? 'The Rajasthan Panchayati Raj Act, 1994, Sec. 60 & 65' : 'State PR Finance Rules'),
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // ZILA PARISHAD MEMBER (District Ward Representative)
  // =========================================================================
  static RepresentativeRoleProfile _buildZilaParishadMemberProfile(String? stateIdentifier) {
    final bool isHaryana = stateIdentifier == 'haryana';
    final bool isRajasthan = stateIdentifier == 'rajasthan';
    final bool isStateSpecific = isHaryana || isRajasthan;

    final String sourceTitle = isHaryana
        ? 'The Haryana Panchayati Raj Act, 1994 (Haryana Act No. 11 of 1994)'
        : (isRajasthan
            ? 'The Rajasthan Panchayati Raj Act, 1994 (Act No. 13 of 1994)'
            : 'General Model Guidance (National Local Governance Framework)');

    final String relevantSections = isHaryana
        ? 'Sections 118 (Composition & Ward Members), 122 (Term of Office), 127 (Meetings & Voting Rights), 137 (Functions), 139 (Standing Committees)'
        : (isRajasthan
            ? 'Sections 14 (Composition), 15 (Elected Members), 27 (Rights and Duties of Members), 56 (Standing Committees), 57 (Functions)'
            : 'Constitution (73rd Amendment) Act, 1992, Articles 243B, 243C, 243E, 243G (Eleventh Schedule) & Model Panchayati Raj Legislation');

    final String jurisdictionState = isHaryana
        ? 'Haryana'
        : (isRajasthan ? 'Rajasthan' : 'General / Model Framework');

    final String sourceUrl = isHaryana
        ? haryanaActPdfUrl
        : (isRajasthan ? rajasthanActUrl : moprUrl);

    final String officialGuidanceNoteEn = isHaryana
        ? 'Statutory provisions governing elected Zila Parishad ward members under Haryana Panchayati Raj Act, 1994.'
        : (isRajasthan
            ? 'Rajasthan Panchayati Raj Act, 1994 provisions governing elected Zila Parishad ward members.'
            : 'General Model Guidance for elected district panchayat ward members. Specific state-level legislation for this jurisdiction has not yet been verified in the app database; refer to the respective State Panchayati Raj Act.');

    final String officialGuidanceNoteHi = isHaryana
        ? 'हरियाणा पंचायती राज अधिनियम, 1994 के अंतर्गत जिला परिषद सदस्यों के वैधानिक प्रावधान।'
        : (isRajasthan
            ? 'राजस्थान पंचायती राज अधिनियम, 1994 के तहत निर्वाचित जिला परिषद सदस्यों के वैधानिक प्रावधान।'
            : 'जिला पंचायत वार्ड सदस्यों के लिए सामान्य मॉडल मार्गदर्शन। इस अधिकार क्षेत्र के राज्य-विशिष्ट कानून अभी ऐप डेटाबेस में सत्यापित नहीं हैं; संबंधित राज्य के अधिनियम का संदर्भ लें।');

    return RepresentativeRoleProfile(
      role: RepresentativeRole.zilaParishadMember,
      titleEn: 'Zila Parishad Member (District Level)',
      titleHi: 'जिला परिषद सदस्य (जिला स्तर)',
      governingBodyEn: 'Zila Parishad (Territorial Constituency)',
      governingBodyHi: 'जिला परिषद (प्रादेशिक निर्वाचन क्षेत्र)',
      constitutionalPostSummaryEn:
          'Directly elected representative of a district territorial ward in the apex rural local self-government under Article 243C. Responsible for representing ward residents, raising constituency connectivity and amenity priorities, reviewing district revenue and expenditure, voting on resolutions and the annual budget, and serving on statutory standing committees.',
      constitutionalPostSummaryHi:
          'संविधान के अनुच्छेद 243C के तहत शीर्ष ग्रामीण निकाय (जिला परिषद) में अपने जिला प्रादेशिक वार्ड से प्रत्यक्ष निर्वाचित प्रतिनिधि। अपने क्षेत्र के ग्रामीणों की आवाज उठाना, सड़क व जनसुविधाओं के प्रस्ताव रखना, आय-व्यय की समीक्षा करना, बजट व प्रस्तावों पर मतदान करना और स्थायी समितियों में सक्रिय योगदान देना इनका मुख्य कार्य है।',
      legalReference: LegalSourceReference(
        sourceTitle: sourceTitle,
        relevantSections: relevantSections,
        jurisdictionState: jurisdictionState,
        sourceUrl: sourceUrl,
        lastVerifiedDate: '2026-10-26',
        isStateSpecific: isStateSpecific,
        officialGuidanceNoteEn: officialGuidanceNoteEn,
        officialGuidanceNoteHi: officialGuidanceNoteHi,
      ),
      citizenQa: const [
        CitizenQaItem(
          questionEn: 'What can an individual Zila Parishad Member do for their ward?',
          questionHi: 'जिला परिषद सदस्य अपने वार्ड के लिए क्या-क्या कर सकते हैं?',
          answerEn:
              'Proposes major connecting roads between blocks, upgrades to community health centres, and drinking water pipelines during quarterly Zila Parishad meetings; votes on the allocation of district plan funds; and inspects progress of sanctioned works in their ward.',
          answerHi:
              'जिला परिषद की बैठकों में अपने वार्ड के लिए मुख्य संपर्क सड़कों, सामुदायिक स्वास्थ्य केंद्र (CHC) के उन्नयन व पेयजल पाइपलाइन के प्रस्ताव रखते हैं; जिला योजना बजट के आवंटन पर मतदान करते हैं; और स्वीकृत निर्माण कार्यों की गुणवत्ता की जांच करते हैं।',
        ),
        CitizenQaItem(
          questionEn: 'Does a Zila Parishad Member have an individual development fund or quota?',
          questionHi: 'क्या जिला परिषद सदस्य के पास व्यक्तिगत विवेकाधीन फंड कोटा होता है?',
          answerEn:
              'NO. Unless a state government specifically notifies an individual discretionary scheme, a Zila Parishad member has NO personal development purse, independent spending quota, or cheque-signing power. All works must be sanctioned collectively by the Zila Parishad within the approved budget.',
          answerHi:
              'नहीं। जब तक राज्य सरकार द्वारा कोई विशेष विवेकाधीन योजना अधिसूचित न की जाए, किसी भी सदस्य के पास कोई व्यक्तिगत फंड कोटा या चेक काटने का अधिकार नहीं होता। सभी कार्य जिला परिषद के सामूहिक प्रस्ताव द्वारा बजट के अनुसार ही मंजूर किए जाते हैं।',
        ),
        CitizenQaItem(
          questionEn: 'Which works require formal Zila Parishad resolution and engineering approval?',
          questionHi: 'किस काम में जिला परिषद का प्रस्ताव और तकनीकी स्वीकृति चाहिए?',
          answerEn:
              'Any development proposal requires an affirmative resolution passed by the Zila Parishad, technical sanction by the Executive Engineer / Superintending Engineer (Panchayati Raj), and administrative execution by the Chief Executive Officer (CEO). An individual member cannot issue tenders or sign contracts.',
          answerHi:
              'सदस्य द्वारा रखे गए किसी भी प्रस्ताव के लिए जिला परिषद का औपचारिक प्रस्ताव, अधीक्षण/अधिशासी अभियंता से तकनीकी स्वीकृति और मुख्य कार्यकारी अधिकारी (CEO) द्वारा प्रशासनिक क्रियान्वयन जरूरी होता है। सदस्य अकेले कोई टेंडर या ठेका नहीं दे सकते।',
        ),
        CitizenQaItem(
          questionEn: 'Can a Zila Parishad Member direct block or village officials?',
          questionHi: 'क्या जिला परिषद सदस्य ब्लॉक या गांव के अधिकारियों को सीधे आदेश दे सकते हैं?',
          answerEn:
              'NO. Gram Panchayats and Panchayat Samitis are distinct constitutional tiers. A Zila Parishad member cannot direct a Sarpanch, veto Gram Sabha decisions, or instruct BDPOs and Gram Sachivs. Their role is district-level policy, budget deliberation, and oversight.',
          answerHi:
              'नहीं। ग्राम पंचायत व पंचायत समिति स्वतंत्र संवैधानिक निकाय हैं। जिला परिषद सदस्य किसी सरपंच को आदेश नहीं दे सकते, न ही बीडीपीओ या ग्राम सचिव को सीधे निर्देशित कर सकते हैं। उनका कार्य जिला स्तर पर नीति निर्माण व निगरानी का है।',
        ),
        CitizenQaItem(
          questionEn: 'Where should citizens approach for district ward grievances?',
          questionHi: 'जिला वार्ड की समस्याओं के लिए नागरिक कहाँ संपर्क करें?',
          answerEn:
              'Meet the elected Zila Parishad Member to request that constituency needs be raised in the council. Formal representations regarding stalled projects, substandard construction, or official delays should also be submitted to the CEO, Zila Parishad or the District Magistrate.',
          answerHi:
              'नागरिक अपने जिला परिषद सदस्य से मिलकर अपनी मांगें सदन में रखने का आग्रह कर सकते हैं। रुके हुए कार्यों, घटिया निर्माण या प्रशासनिक लापरवाही की आधिकारिक शिकायत मुख्य कार्यकारी अधिकारी (CEO, जिला परिषद) या जिलाधिकारी को भी दी जानी चाहिए।',
        ),
      ],
      legalLimitationsEn: const [
        'Has NO individual executive or financial signing authority; cannot unilaterally award contracts, sign cheques, or disburse public funds.',
        'Holds NO individual discretionary development fund quota unless expressly notified under state legislation.',
        'Cannot exercise administrative authority over the Sarpanch, Gram Panchayat, or Panchayat Samiti; cannot suspend or dismiss any elected representative.',
        'Cannot suspend, discipline, or transfer government officials (doctors, engineers, teachers, patwaris); can only table concerns before the council.',
        'Possesses no police, magisterial, or judicial powers to adjudicate disputes.',
        'Cannot alter official welfare scheme eligibility criteria or guarantee benefits outside statutory lists.',
      ],
      legalLimitationsHi: const [
        'कोई व्यक्तिगत विवेकाधीन विकास फंड कोटा या व्यक्तिगत चेक हस्ताक्षर अधिकार नहीं है; विकास कार्यों के सभी प्रस्ताव जिला परिषद द्वारा सामूहिक रूप से बजट के तहत ही स्वीकृत होते हैं।',
        'कोई व्यक्तिगत कार्यकारी या वित्तीय अधिकार नहीं है; अकेले टेंडर जारी करने, चेक काटने या फंड खर्च करने की शक्ति नहीं है।',
        'जब तक राज्य सरकार द्वारा विहित न किया जाए, कोई व्यक्तिगत विवेकाधीन फंड या खर्च का कोटा नहीं होता।',
        'सरपंच, ग्राम पंचायत या पंचायत समिति पर कोई प्रशासनिक नियंत्रण नहीं है; किसी निर्वाचित प्रतिनिधि को पद से हटाने का अधिकार नहीं है।',
        'सरकारी कर्मचारियों (डॉक्टर, इंजीनियर, अध्यापक आदि) को निलंबित या अनुशासित करने का अधिकार नहीं है; केवल परिषद में मामला उठाया जा सकता है।',
        'किसी भी विवाद में फैसला सुनाने का कोई न्यायिक या पुलिस अधिकार नहीं है।',
        'कल्याणकारी योजनाओं के नियमों को बदलने या व्यक्तिगत स्तर पर लाभ की गारंटी देने का अधिकार नहीं है।',
      ],
      grievanceEscalationEn: isRajasthan
          ? 'Ward Level: Zila Parishad Member -> District Level: Chief Executive Officer (CEO), Zila Parishad -> District Collector -> State Level: Panchayati Raj Department -> Rajasthan Sampark Portal (181) / Lokayukta.'
          : (isHaryana
              ? 'Ward Level: Zila Parishad Member -> District Level: CEO, Zila Parishad -> Deputy Commissioner -> State Level: Directorate of Development & Panchayats -> CM Window Haryana / Lokayukta.'
              : 'Ward Level: Zila Parishad Member -> District Level: CEO, Zila Parishad -> District Magistrate -> State Level: Directorate of Panchayati Raj -> State Grievance Portal / Lokayukta.'),
      grievanceEscalationHi: isRajasthan
          ? 'वार्ड स्तर: जिला परिषद सदस्य -> जिला स्तर: मुख्य कार्यकारी अधिकारी (CEO), जिला परिषद -> जिला कलेक्टर -> राज्य स्तर: पंचायती राज विभाग -> राजस्थान संपर्क पोर्टल (181) / लोकायुक्त।'
          : (isHaryana
              ? 'वार्ड स्तर: जिला परिषद सदस्य -> जिला स्तर: मुख्य कार्यकारी अधिकारी (CEO), जिला परिषद -> उपायुक्त -> राज्य स्तर: विकास एवं पंचायत निदेशालय -> सीएम विंडो हरियाणा / लोकायुक्त।'
              : 'वार्ड स्तर: जिला परिषद सदस्य -> जिला स्तर: मुख्य कार्यकारी अधिकारी (CEO), जिला परिषद -> जिलाधिकारी -> राज्य स्तर: पंचायती राज निदेशालय -> राज्य शिकायत निवारण पोर्टल / लोकायुक्त।'),
      categories: [
        DutyCategorySection(
          category: DutyCategory.publicAssets,
          items: [
            DutyItem(
              titleEn: 'Inter-Block Road Connectivity & Infrastructure Proposals',
              titleHi: 'अंतर-ब्लॉक सड़क संपर्क व बुनियादी ढांचे का प्रस्ताव',
              descriptionEn:
                  'Propose connecting roads linking villages across block boundaries and inspect culverts and road paving funded by district plan grants in the ward.',
              descriptionHi:
                  'वार्ड में दो ब्लॉकों को जोड़ने वाली सड़कों, पुलियों व जिला योजना से स्वीकृत विकास कार्यों का प्रस्ताव रखना और निगरानी करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              statutoryCitation: isHaryana
                  ? 'The Haryana Panchayati Raj Act, 1994, Sec. 137'
                  : (isRajasthan ? 'The Rajasthan Panchayati Raj Act, 1994, Sec. 57' : 'Constitution of India, Article 243G'),
            ),
            const DutyItem(
              titleEn: 'On-Site Inspection of Sanctioned District Public Works',
              titleHi: 'स्वीकृत जिला निर्माण कार्यों की स्थल पर जांच',
              descriptionEn:
                  'Inspect materials and construction quality of ongoing district works in the ward, reporting defects to the Executive Engineer (Panchayati Raj) and CEO.',
              descriptionHi:
                  'वार्ड में चल रहे जिला परिषद के निर्माण कार्यों की गुणवत्ता जांचना और कमी पाए जाने पर अधिशासी अभियंता व सीईओ को रिपोर्ट देना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
            ),
          ],
        ),
        const DutyCategorySection(
          category: DutyCategory.schemesAndBeneficiaries,
          items: [
            DutyItem(
              titleEn: 'Disseminating Information on Central & State Rural Welfare Schemes',
              titleHi: 'सरकारी योजनाओं की जानकारी ग्रामीणों तक पहुंचाना',
              descriptionEn:
                  'Inform rural residents in the ward about state rural housing subsidies, farm pond incentives, and skill development programmes.',
              descriptionHi:
                  'वार्डवासियों को आवास योजनाओं, खेत तलाई, सौर ऊर्जा पंप व कौशल विकास योजनाओं की पात्रता की जानकारी देना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
            ),
            DutyItem(
              titleEn: 'Supporting Rural Livelihoods & Producer Organizations',
              titleHi: 'ग्रामीण आजीविका व कृषक उत्पादक समूहों को सहयोग',
              descriptionEn:
                  'Encourage rural youth self-employment, farmer producer organizations, and women self-help group federations in coordination with district officials.',
              descriptionHi:
                  'ग्रामीण युवाओं के स्वरोजगार और महिला स्वयं सहायता समूह संघों के लिए जिला स्तरीय योजनाओं से समन्वय करना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.meetingsAndBudgets,
          items: [
            DutyItem(
              titleEn: 'Mandatory Attendance, Deliberation & Voting in Council Meetings',
              titleHi: 'परिषद बैठकों में अनिवार्य उपस्थिति, विचार-विमर्श व मताधिकार',
              descriptionEn:
                  'Attend quarterly meetings of the Zila Parishad, actively deliberate on district development policies, represent constituency priorities, table motions and resolutions, and vote on collective council decisions.',
              descriptionHi:
                  'जिला परिषद की बैठकों में अनिवार्य रूप से उपस्थित होना, जिला नीतियों पर विचार-विमर्श (deliberate) करना, अपने निर्वाचन क्षेत्र (constituency) की प्राथमिकताएं उठाना, प्रस्ताव (motions and resolutions) पेश करना और सामूहिक निर्णयों पर मतदान करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              statutoryCitation: isHaryana
                  ? 'The Haryana Panchayati Raj Act, 1994, Sec. 127'
                  : (isRajasthan ? 'The Rajasthan Panchayati Raj Act, 1994, Sec. 57' : 'State Panchayati Raj Acts'),
            ),
            DutyItem(
              titleEn: 'Scrutinizing Annual District Budget & Fund Allocation',
              titleHi: 'वार्षिक जिला बजट की समीक्षा व न्यायसंगत आवंटन',
              descriptionEn:
                  'Examine draft annual budget proposals prepared by the CEO to ensure equitable distribution of state and central finance commission grants across wards.',
              descriptionHi:
                  'सीईओ द्वारा तैयार बजट प्रस्ताव की समीक्षा करना और सभी वार्डों में वित्त आयोग अनुदानों का न्यायसंगत वितरण सुनिश्चित करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              statutoryCitation: isHaryana
                  ? 'The Haryana Panchayati Raj Act, 1994, Sec. 146'
                  : (isRajasthan ? 'The Rajasthan Panchayati Raj Act, 1994, Sec. 65' : 'Constitution of India, Article 243G'),
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.socialSectorCoordination,
          items: [
            DutyItem(
              titleEn: 'Active Service on Appointed Statutory Standing Committees',
              titleHi: 'नियुक्त स्थायी समितियों में सक्रिय दायित्व निर्वहन',
              descriptionEn:
                  'Serve as member on specialized standing committees (General, Finance, Social Justice, Education/Health) to examine departmental estimates.',
              descriptionHi:
                  'सामान्य, वित्त, सामाजिक न्याय या शिक्षा/स्वास्थ्य स्थायी समिति में सदस्य के रूप में विभागीय कार्यों की विस्तृत जांच करना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              statutoryCitation: isHaryana
                  ? 'The Haryana Panchayati Raj Act, 1994, Sec. 139'
                  : (isRajasthan ? 'The Rajasthan Panchayati Raj Act, 1994, Sec. 56' : 'State Panchayati Raj Acts'),
            ),
            const DutyItem(
              titleEn: 'Representing Secondary Education & Community Healthcare Needs',
              titleHi: 'माध्यमिक स्कूलों व सामुदायिक स्वास्थ्य केंद्रों की मांग उठाना',
              descriptionEn:
                  'Highlight shortage of teachers, ambulances, and laboratory facilities in rural secondary schools and CHCs to departmental heads during meetings.',
              descriptionHi:
                  'ग्रामीण सीनियर सेकेंडरी स्कूलों व सीएचसी में शिक्षकों, एम्बुलेंस व दवाओं की कमी को संबंधित जिला अधिकारियों के समक्ष उठाना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
            ),
          ],
        ),
        const DutyCategorySection(
          category: DutyCategory.welfareAndDisaster,
          items: [
            DutyItem(
              titleEn: 'Alerting Administration on District Disasters, Floods & Crop Losses',
              titleHi: 'प्राकृतिक आपदा, बाढ़ व फसल खराबे की सूचना देना',
              descriptionEn:
                  'Survey affected villages during unseasonal rains, drought, or epidemics; alert the CEO and District Collector, and monitor prompt relief delivery.',
              descriptionHi:
                  'अतिवृष्टि, सूखा या महामारी में प्रभावित गांवों का दौरा कर जिला प्रशासन को सूचित करना और राहत वितरण की निगरानी करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.legalLimitsAndExclusions,
          items: [
            DutyItem(
              titleEn: 'No Independent Financial Signing or Discretionary Quotas',
              titleHi: 'कोई व्यक्तिगत वित्तीय हस्ताक्षर अधिकार या विवेकाधीन कोटा नहीं',
              descriptionEn:
                  'A Zila Parishad member has NO personal development purse, cannot sanction contracts, and cannot sign cheques or disburse money independently.',
              descriptionHi:
                  'सदस्य के पास कोई व्यक्तिगत फंड नहीं होता, वे अकेले कोई टेंडर नहीं दे सकते और न ही कोई भुगतान चेक जारी कर सकते हैं।',
              responsibilityType: ResponsibilityType.requiresApproval,
              statutoryCitation: isHaryana
                  ? 'The Haryana Panchayati Raj Act, 1994, Sec. 145'
                  : (isRajasthan ? 'The Rajasthan Panchayati Raj Act, 1994, Sec. 60' : 'State PR Finance Rules'),
            ),
            const DutyItem(
              titleEn: 'No Administrative Authority over Civil Servants or Village Panchayats',
              titleHi: 'सरकारी कर्मचारियों या ग्राम पंचायतों पर कोई प्रशासनिक नियंत्रण नहीं',
              descriptionEn:
                  'A member cannot suspend or direct government officers (BDPOs, doctors, engineers) or village Sarpanches; issues must be raised through the council.',
              descriptionHi:
                  'सदस्य किसी सरकारी अधिकारी या ग्राम सरपंच को निलंबित या निर्देशित नहीं कर सकते; शिकायत केवल सदन में रखी जा सकती है।',
              responsibilityType: ResponsibilityType.departmentalResponsibility,
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // 1. MUNICIPAL COUNCILLOR (Urban Ward Member / वार्ड पार्षद)
  // =========================================================================
  static RepresentativeRoleProfile _buildMunicipalCouncillorProfile(bool isHaryana) {
    return RepresentativeRoleProfile(
      role: RepresentativeRole.municipalCouncillor,
      titleEn: 'Ward Councillor / Municipal Member',
      titleHi: 'वार्ड पार्षद / नगर पालिका सदस्य',
      governingBodyEn: 'Municipality / Municipal Council / Corporation',
      governingBodyHi: 'नगर पालिका / नगर परिषद / नगर निगम',
      isAdministrativeOfficer: false,
      constitutionalPostSummaryEn:
          'Elected representative of an urban ward under the 74th Constitutional Amendment (Article 243R) and Section 9 of The Haryana Municipal Act, 1973 / Section 5 of The Haryana Municipal Corporation Act, 1994. Responsible for representing ward residents in council debates, proposing local infrastructure works (streets, drainage, sanitation, streetlights), voting on municipal budgets and bye-laws, and monitoring daily civic service delivery. Holds deliberative, representative, and monitoring duties; possesses NO individual executive contracting or fund-signing authority.',
      constitutionalPostSummaryHi:
          '74वें संविधान संशोधन (अनुच्छेद 243R) व हरियाणा नगर पालिका अधिनियम, 1973 की धारा 9 / हरियाणा नगर निगम अधिनियम, 1994 की धारा 5 के तहत शहरी वार्ड से निर्वाचित जनप्रतिनिधि। नगर सदन में वार्डवासियों की समस्याओं को उठाना, गली-नाली, सफाई व स्ट्रीट लाइट के प्रस्ताव रखना, बजट व उप-नियमों पर मतदान करना और दैनिक नागरिक सेवाओं की निगरानी करना इनका मुख्य कार्य है। इनके पास कोई व्यक्तिगत वित्तीय चेक काटने या टेंडर जारी करने का कार्यकारी अधिकार नहीं है।',
      legalReference: LegalSourceReference(
        sourceTitle: isHaryana
            ? 'The Haryana Municipal Act, 1973 & Haryana Municipal Corporation Act, 1994'
            : 'General Model Guidance (National Local Governance Framework)',
        relevantSections: isHaryana
            ? 'Sections 9, 11-15 (Ward Delimitation & Election), 25-28 (Meetings & Voting), 61-80 (Civic Services)'
            : 'Constitution of India (74th Amendment), Articles 243R & 243W (Twelfth Schedule)',
        jurisdictionState: isHaryana ? 'Haryana' : 'General / Model Framework',
        sourceUrl: isHaryana ? 'https://ulbharyana.gov.in/acts-and-rules' : 'https://legislative.gov.in/constitution-of-india',
        lastVerifiedDate: '2026-10-28',
        isStateSpecific: isHaryana,
        officialGuidanceNoteEn: isHaryana
            ? 'Statutory provisions governing ward members under Haryana Municipal Laws.'
            : 'General Model Guidance grounded in the 74th Constitutional Amendment for urban ward councillors.',
        officialGuidanceNoteHi: isHaryana
            ? 'हरियाणा नगर पालिका कानूनों के अंतर्गत वार्ड पार्षदों से संबंधित वैधानिक प्रावधान।'
            : 'शहरी वार्ड पार्षदों के लिए 74वें संविधान संशोधन पर आधारित सामान्य मॉडल मार्गदर्शन।',
      ),
      citizenQa: const [
        CitizenQaItem(
          questionEn: 'How can citizens identify their municipal body and ward number?',
          questionHi: 'नागरिक अपने शहरी स्थानीय निकाय और वार्ड नंबर की पहचान कैसे करें?',
          answerEn:
              'Check your latest Property Tax Assessment bill, No Dues Certificate (NDC) on the state ULB portal (ulbhryndc.org in Haryana), voter slip, or voter identity card. Municipalities are categorized by population into Municipal Committees (small towns), Municipal Councils (medium cities), and Municipal Corporations (large cities like Gurugram, Faridabad, Karnal).',
          answerHi:
              'अपनी संपत्ति कर रसीद, राज्य शहरी निकाय पोर्टल (हरियाणा में ulbhryndc.org) पर प्रॉपर्टी आईडी/एनडीसी, या वोटर पर्ची पर वार्ड नंबर देखें। आबादी के अनुसार छोटे शहरों में नगर पालिका समिति, मध्यम शहरों में नगर परिषद और 3 लाख से अधिक आबादी वाले बड़े शहरों में नगर निगम होता है।',
        ),
        CitizenQaItem(
          questionEn: 'What can an urban Ward Councillor do for our ward?',
          questionHi: 'वार्ड पार्षद हमारे वार्ड के लिए क्या-क्या कर सकते हैं?',
          answerEn:
              'A Councillor raises ward civic issues in municipal board meetings, proposes paving of damaged streets, desilting of drains, and installation of LED streetlights, inspects daily door-to-door waste collection, and assists residents in forwarding welfare scheme applications.',
          answerHi:
              'पार्षद नगर पालिका सदन में वार्ड की समस्याएं उठाते हैं, टूटी गलियों के निर्माण, नालियों की सफाई व स्ट्रीट लाइट लगवाने का प्रस्ताव रखते हैं, दैनिक सफाई व्यवस्था की निगरानी करते हैं और जनकल्याणकारी योजनाओं में नागरिकों की मदद करते हैं।',
        ),
        CitizenQaItem(
          questionEn: 'Can a Councillor independently sanction tenders or spend municipal funds?',
          questionHi: 'क्या पार्षद अकेले कोई टेंडर पास कर सकते हैं या फंड खर्च कर सकते हैं?',
          answerEn:
              'NO. An individual Councillor has NO unilateral executive or financial signing authority. Works require a collective board resolution, technical sanction from the Municipal Engineer, and administrative/financial sanction from the Executive Officer (EO) / Commissioner.',
          answerHi:
              'नहीं। पार्षद के पास अकेले कोई टेंडर जारी करने या फंड खर्च करने का अधिकार नहीं होता। सभी कार्यों के लिए बोर्ड का सामूहिक प्रस्ताव, म्युनिसिपल इंजीनियर से तकनीकी मंजूरी और कार्यकारी अधिकारी (EO)/आयुक्त से प्रशासनिक स्वीकृति अनिवार्य है।',
        ),
        CitizenQaItem(
          questionEn: 'Can a Councillor approve house building plans or issue birth/death certificates?',
          questionHi: 'क्या पार्षद मकान का नक्शा पास कर सकते हैं या जन्म/मृत्यु प्रमाण पत्र जारी कर सकते हैं?',
          answerEn:
              'NO. Building plans are sanctioned through the municipal administration / Town Planning wing (by the Commissioner in Corporations under Sec. 254 of HMCA 1994, or by the Committee / Executive Officer in Municipalities under Sec. 205 of HMA 1973) under the Haryana Building Code, and birth/death certificates are issued by the designated Registrar (Health Branch). Councillors do not sanction maps or issue statutory certificates.',
          answerHi:
              'नहीं। भवन निर्माण का नक्शा पास करना नगर निगमों में आयुक्त (HMCA 1994, धारा 254) तथा नगर पालिकाओं/परिषदों में समिति/कार्यकारी अधिकारी (HMA 1973, धारा 205) का वैधानिक कार्य है, और जन्म/मृत्यु प्रमाण पत्र रजिस्ट्रार द्वारा जारी किया जाता है। पार्षद नक्शा पास करने या प्रमाण पत्र जारी करने के लिए अधिकृत नहीं हैं।',
        ),
        CitizenQaItem(
          questionEn: 'Where should urban citizens report civic complaints, and how to follow up?',
          questionHi: 'शहरी नागरिक अपनी समस्याएं कहाँ दर्ज कराएं और फॉलो-अप कैसे करें?',
          answerEn:
              'Submit issues to your Ward Councillor and the municipal Sanitary Inspector or register on the municipal online portal / Swachhata App / CM Window. Always keep the grievance tracking ID. If unresolved, escalate in writing to the Executive Officer (EO) or District Municipal Commissioner (DMC).',
          answerHi:
              'समस्या की शिकायत वार्ड पार्षद व सफाई निरीक्षक को दें या नगरपालिका ऑनलाइन पोर्टल/स्वच्छता ऐप/सीएम विंडो पर दर्ज करें और शिकायत संख्या (Tracking ID) संभाल कर रखें। समाधान न होने पर कार्यकारी अधिकारी (EO) या जिला नगर आयुक्त (DMC) को लिखित प्रतिवेदन दें।',
        ),
      ],
      legalLimitationsEn: const [
        'Has NO individual executive or financial signing authority; cannot unilaterally award tenders or disburse municipal funds.',
        'Cannot unilaterally sanction building plans or regularize unauthorized construction outside statutory town planning rules.',
        'Cannot issue official commercial trade licenses or birth/death certificates; these require statutory registration by designated municipal officers.',
        'Cannot direct police or executive magistrates in private civil or criminal disputes.',
        'Cannot exempt properties from statutory municipal property taxes, water charges, or user fees.',
      ],
      legalLimitationsHi: const [
        'कोई व्यक्तिगत कार्यकारी या वित्तीय हस्ताक्षर अधिकार नहीं है; अकेले टेंडर जारी करने या फंड खर्च करने का अधिकार नहीं है।',
        'भवन निर्माण का नक्शा पास करने या अवैध निर्माण को नियमित करने का व्यक्तिगत अधिकार नहीं है (यह नगर योजना शाखा/EO का कार्य है)।',
        'व्यापारिक लाइसेंस या जन्म/मृत्यु प्रमाण पत्र सीधे जारी नहीं कर सकते; यह विहित रजिस्ट्रार/स्वास्थ्य अधिकारी का कार्य है।',
        'निजी दीवानी या आपराधिक विवादों में पुलिस या प्रशासन को निर्देशित करने का अधिकार नहीं है।',
        'नगर पालिका करों, जल शुल्क या यूजर चार्ज में व्यक्तिगत स्तर पर छूट देने का अधिकार नहीं है।',
      ],
      grievanceEscalationEn:
          'Ward Level: Ward Councillor / Sanitary Inspector -> Executive Officer (EO) / Municipal Commissioner -> District Municipal Commissioner (DMC) -> Directorate of Urban Local Bodies Haryana -> CM Window / Lokayukta.',
      grievanceEscalationHi:
          'वार्ड स्तर: वार्ड पार्षद / सफाई निरीक्षक -> कार्यकारी अधिकारी (EO) / नगर आयुक्त -> जिला नगर आयुक्त (DMC) -> शहरी स्थानीय निकाय निदेशालय -> सीएम विंडो / लोकायुक्त।',
      categories: const [
        DutyCategorySection(
          category: DutyCategory.publicAssets,
          items: [
            DutyItem(
              titleEn: 'Ward Streets, Paver Blocks, and Storm Drainage',
              titleHi: 'वार्ड की गलियां, पेवर ब्लॉक व जल निकासी',
              descriptionEn:
                  'Propose internal street paving, paver-block repairs, and culvert construction; monitor regular cleaning of open storm water drains in the ward.',
              descriptionHi:
                  'वार्ड की आंतरिक गलियों के निर्माण, पेवर ब्लॉक मरम्मत व नालियों की सफाई का प्रस्ताव रखना और निगरानी करना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              additionalResponsibilityTypes: [ResponsibilityType.requiresApproval],
              procedureOrApprovalEn: 'Municipal Board resolution + Municipal Engineer technical sanction.',
              procedureOrApprovalHi: 'नगर पालिका बोर्ड का प्रस्ताव + नगरपालिका अभियंता की तकनीकी मंजूरी।',
              representativeRoleEn: 'Surveys ward street damage, presents priority list in House meetings, and inspects quality during execution.',
              representativeRoleHi: 'वार्ड में क्षतिग्रस्त गलियों का सर्वे करते हैं, बोर्ड बैठक में प्रस्ताव रखते हैं और निर्माण के समय गुणवत्ता का निरीक्षण करते हैं।',
              activitiesIncludedEn: 'Pothole patching, laying concrete/paver blocks, desilting open drains before monsoon, constructing culverts.',
              activitiesIncludedHi: 'गड्ढे भरना, पेवर ब्लॉक या सीसी सड़क निर्माण, मानसून पूर्व नालों की तलीझाड़ सफाई और पुलिया निर्माण।',
              intendedResultEn: 'Waterlogging-free, clean all-weather streets and safe pedestrian movement in the ward.',
              intendedResultHi: 'वार्ड में जलभराव से मुक्ति, पक्के व सुगम रास्ते और स्वच्छता।',
              practicalProcessEn: 'Ward citizen demand -> Councillor proposal in House -> Engineering estimate & technical sanction -> E-tendering by EO -> Execution & MB recording.',
              practicalProcessHi: 'वार्डवासियों की मांग -> सदन में पार्षद का प्रस्ताव -> इंजीनियरिंग प्राक्कलन व तकनीकी स्वीकृति -> ई-टेंडर -> माप पुस्तिका (MB) अंकन।',
              lineDepartmentEn: 'Municipal Engineering Branch / Public Works Wing',
              lineDepartmentHi: 'नगर पालिका इंजीनियरिंग शाखा / लोक निर्माण विंग',
              verificationEvidenceEn: 'Municipal board resolution minutes, e-tender work order ID, and Measurement Book (MB) record.',
              verificationEvidenceHi: 'नगर पालिका बोर्ड प्रस्ताव, ई-टेंडर कार्य आदेश व माप पुस्तिका रिकॉर्ड।',
              statutoryCitation: 'The Haryana Municipal Act, 1973, Sec. 61-66',
            ),
            DutyItem(
              titleEn: 'Ward Sanitation, Garbage Pickup, and Dustbin Placement',
              titleHi: 'वार्ड की सफाई, कचरा उठान व डस्टबिन व्यवस्था',
              descriptionEn:
                  'Inspect daily door-to-door waste collection, ensure proper placement of community garbage bins, and monitor deployment of ward safai karamcharis.',
              descriptionHi:
                  'डोर-टू-डोर कचरा संग्रहण की निगरानी, सार्वजनिक कचरा पात्रों की व्यवस्था और सफाई कर्मचारियों की उपस्थिति सुनिश्चित करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              additionalResponsibilityTypes: [ResponsibilityType.departmentalResponsibility],
              procedureOrApprovalEn: 'Supervised through Chief Sanitary Inspector / Executive Officer.',
              procedureOrApprovalHi: 'सफाई निरीक्षक व कार्यकारी अधिकारी के माध्यम से क्रियान्वयन।',
              representativeRoleEn: 'Monitors sweeper attendance, reports garbage dumps (GVP points), and coordinates with Sanitary Inspector for prompt clearance.',
              representativeRoleHi: 'सफाई कर्मचारियों की उपस्थिति जांचते हैं, खुले कचरा डंपों की सूचना देते हैं और सफाई निरीक्षक से समन्वय करते हैं।',
              activitiesIncludedEn: 'Ensuring daily tipper collection, clearing overflow bins, monitoring street sweeping, desilting drain choked points.',
              activitiesIncludedHi: 'डोर-टू-डोर टिपर से कचरा उठाव, डस्टबिन खाली कराना, नालियों की सिल्ट निकालना और गलियों में नियमित झाड़ू लगवाना।',
              intendedResultEn: 'Litter-free, disease-free ward environment with zero open garbage vulnerable points.',
              intendedResultHi: 'कचरामुक्त वार्ड, दुर्गंध व बीमारियों की रोकथाम और स्वच्छ वातावरण।',
              practicalProcessEn: 'Daily morning ward inspection -> Reporting missed routes to Sanitary Inspector -> Enforcement via municipal waste concessionaire.',
              practicalProcessHi: 'सुबह वार्ड निरीक्षण -> सफाई निरीक्षक को सूचना -> कचरा उठाने वाली एजेंसी द्वारा उठान।',
              lineDepartmentEn: 'Municipal Sanitation & Health Wing',
              lineDepartmentHi: 'नगर पालिका स्वास्थ्य एवं स्वच्छता शाखा',
              verificationEvidenceEn: 'Daily safai karamchari attendance register and Swachhata portal complaint resolution record.',
              verificationEvidenceHi: 'सफाई कर्मचारी उपस्थिति रजिस्टर और स्वच्छता पोर्टल शिकायत निवारण लॉग।',
              statutoryCitation: 'The Haryana Municipal Act, 1973, Sec. 154-160',
            ),
            DutyItem(
              titleEn: 'Maintenance of Public Streetlights and LED Fixtures',
              titleHi: 'स्ट्रीट लाइट व एलईडी लाइटों का रखरखाव',
              descriptionEn:
                  'Report dark spots and non-functional streetlights in the ward to the municipal electrical wing for timely replacement.',
              descriptionHi:
                  'वार्ड में बंद पड़ी स्ट्रीट लाइटों की सूचना नगर पालिका की विद्युत शाखा को देकर नई लाइटें लगवाना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              additionalResponsibilityTypes: [ResponsibilityType.departmentalResponsibility],
              procedureOrApprovalEn: 'Coordination with municipal electrical maintenance contractor / Discom.',
              procedureOrApprovalHi: 'नगर पालिका विद्युत शाखा व संबंधित बिजली निगम के साथ समन्वय।',
              representativeRoleEn: 'Compiles list of non-functional lights, points out dark alley spots for new poles, and follows up on maintenance tickets.',
              representativeRoleHi: 'खराब लाइटों की सूची तैयार करते हैं, अंधेरे रास्तों पर नए पोल लगवाने का प्रस्ताव देते हैं और बिजली शाखा से मरम्मत कराते हैं।',
              activitiesIncludedEn: 'Replacing burnt LED drivers/fixtures, resetting automatic timers, inspecting earthing safety.',
              activitiesIncludedHi: 'खराब एलईडी लाइट बदलना, टाइमर दुरुस्त करना और तारों की सुरक्षा सुनिश्चित करना।',
              intendedResultEn: 'Fully illuminated public alleys and streets improving night-time pedestrian safety and security.',
              intendedResultHi: 'रात में सभी रास्तों पर रोशनी जिससे महिलाओं व नागरिकों का आवागमन सुरक्षित हो।',
              practicalProcessEn: 'Citizen complaint / night survey -> Work ticket logged on electrical portal -> Maintenance contractor repairs within SLA.',
              practicalProcessHi: 'शिकायत प्राप्ति -> विद्युत शाखा में शिकायत दर्ज -> ठेकेदार द्वारा निर्धारित समय में लाइट बदलना।',
              lineDepartmentEn: 'Municipal Electrical Wing & Power Distribution Utility (Discom)',
              lineDepartmentHi: 'नगर पालिका विद्युत शाखा व बिजली निगम (Discom)',
              verificationEvidenceEn: 'Municipal streetlight maintenance logbook and central control monitoring system (CCMS) report.',
              verificationEvidenceHi: 'स्ट्रीट लाइट लॉगबुक और सीसीएमएस (CCMS) पोर्टल रिपोर्ट।',
              statutoryCitation: 'The Haryana Municipal Act, 1973, Sec. 214-225',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.schemesAndBeneficiaries,
          items: [
            DutyItem(
              titleEn: 'Urban Housing & Street Vendor Assistance (PMAY & PM SVANidhi)',
              titleHi: 'शहरी आवास व स्ट्रीट वेंडर योजना सहायता (PMAY व पीएम स्वनिधि)',
              descriptionEn:
                  'Identify eligible homeless urban families for Pradhan Mantri Awas Yojana (Urban) and assist street vendors in obtaining vendor cards and micro-credit under PM SVANidhi.',
              descriptionHi:
                  'वार्ड के बेघर परिवारों को पीएम आवास योजना (शहरी) और रेहड़ी-पटरी वालों को पीएम स्वनिधि में वेंडर कार्ड व ऋण दिलाने में सहायता करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              additionalResponsibilityTypes: [ResponsibilityType.requiresApproval],
              procedureOrApprovalEn: 'Verification by Municipal Social Development Officer (SDO) / DUDA.',
              procedureOrApprovalHi: 'नगर पालिका समाज कल्याण अधिकारी व डूडा (DUDA) द्वारा सत्यापन।',
              representativeRoleEn: 'Facilitates awareness camps, counters false intermediaries, and supports genuine eligible street vendors.',
              representativeRoleHi: 'जागरूकता शिविर लगवाते हैं, दलालों से बचाते हैं और पात्र वेंडरों के आवेदन पत्र नगर पालिका में जमा कराने में मदद करते हैं।',
              activitiesIncludedEn: 'Surveying street vending zones, assisting biometric verification, forwarding subsidy forms.',
              activitiesIncludedHi: 'वेंडिंग जोन सर्वेक्षण, बायोमीट्रिक सत्यापन में मदद और अनुदान फॉर्म प्रेषण।',
              intendedResultEn: 'Pucca housing for poor urban slum dwellers and organized vending zones without extortion.',
              intendedResultHi: 'कच्चे मकानों में रहने वाले गरीबों को पक्का मकान और रेहड़ी-पटरी वालों को सस्ता ऋण व सम्मानजनक रोजगार।',
              practicalProcessEn: 'Application on central portal -> Municipal field verification -> District sanction -> Direct benefit transfer (DBT).',
              practicalProcessHi: 'पोर्टल पर आवेदन -> नगर पालिका फील्ड सत्यापन -> जिला स्तरीय स्वीकृति -> सीधे बैंक खाते में भुगतान।',
              lineDepartmentEn: 'Urban Local Bodies Social Development Branch & DUDA',
              lineDepartmentHi: 'शहरी स्थानीय निकाय समाज विकास शाखा व डूडा (DUDA)',
              verificationEvidenceEn: 'Municipal Town Vending Committee (TVC) certificate and PMAY beneficiary sanction letter.',
              verificationEvidenceHi: 'टाउन वेंडिंग कमेटी (TVC) पहचान पत्र और पीएम आवास स्वीकृति पत्र।',
            ),
            DutyItem(
              titleEn: 'Citizen Identification & Social Welfare Attestations',
              titleHi: 'पात्र लाभार्थियों की पहचान व कल्याणकारी योजनाओं में सत्यापन',
              descriptionEn:
                  'Attest residency proof for genuine poor, disabled, and elderly ward residents applying for social security pensions and ration subsidies.',
              descriptionHi:
                  'वार्ड के गरीब, दिव्यांग व वरिष्ठ नागरिकों के पेंशन व राशन कार्ड आवेदनों पर वार्ड निवासी होने का सत्यापन करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              representativeRoleEn: 'Attests genuine residency proof without bias and assists vulnerable citizens in accessing social security.',
              representativeRoleHi: 'बिना भेदभाव पात्र नागरिकों के निवास प्रमाण को सत्यापित करते हैं और सरकारी पेंशन दिलवाने में सहायता करते हैं।',
              activitiesIncludedEn: 'Signing pension application forms, certifying local residency, guiding family ID (PPP) corrections.',
              activitiesIncludedHi: 'पेंशन फॉर्म पर हस्ताक्षर, स्थानीय निवास सत्यापन और परिवार पहचान पत्र (PPP) त्रुटि सुधार में मार्गदर्शन।',
              intendedResultEn: 'Timely welfare pension disbursement to eligible elderly, widows, and disabled ward residents.',
              intendedResultHi: 'वार्ड के पात्र बुजुर्गों, विधवाओं और दिव्यांगों को समय पर पेंशन लाभ।',
              practicalProcessEn: 'Citizen application -> Councillor attestation -> Municipal Social Welfare verification -> District Social Welfare Officer sanction.',
              practicalProcessHi: 'आवेदन -> पार्षद सत्यापन -> नगर पालिका सत्यापन -> जिला समाज कल्याण अधिकारी द्वारा स्वीकृति।',
              lineDepartmentEn: 'Social Justice & Empowerment Department / Municipal Welfare Cell',
              lineDepartmentHi: 'सामाजिक न्याय एवं अधिकारिता विभाग / नगर पालिका कल्याण शाखा',
              verificationEvidenceEn: 'Social welfare pension sanction order and Municipal attestation register.',
              verificationEvidenceHi: 'पेंशन स्वीकृति आदेश और नगर पालिका प्रतिवेदन रजिस्टर।',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.meetingsAndBudgets,
          items: [
            DutyItem(
              titleEn: 'Board Meeting Participation, Agendas, and Voting',
              titleHi: 'बोर्ड बैठकों में भागीदारी, एजेंडा प्रस्तुत करना व मतदान',
              descriptionEn:
                  'Attend mandatory municipal meetings, move resolutions for ward priorities, vote on civic tax proposals, and scrutinize annual municipal expenditure budgets.',
              descriptionHi:
                  'नगर पालिका की बैठकों में शामिल होना, वार्ड की प्राथमिकताओं के प्रस्ताव रखना, कर प्रस्तावों पर मतदान और बजट की समीक्षा करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              procedureOrApprovalEn: 'Voting governed by Municipal Rules of Business.',
              procedureOrApprovalHi: 'नगर पालिका कार्य संचालन नियमों के तहत मतदान।',
              representativeRoleEn: 'Studies meeting agenda papers, actively raises ward demands, questions budget leakages, and records dissent when necessary.',
              representativeRoleHi: 'एजेंडा पढ़ते हैं, वार्ड के जरूरी काम रखवाते हैं, बजट पर सवाल पूछते हैं और असहमति होने पर असहमति नोट दर्ज कराते हैं।',
              activitiesIncludedEn: 'Tabling ward resolution notices, participating in budget discussions, voting on municipal bye-laws.',
              activitiesIncludedHi: 'प्रस्ताव नोटिस देना, बजट चर्चा में भाग लेना, उप-नियमों व कर दरों पर मतदान करना।',
              intendedResultEn: 'Democratic accountability in urban expenditure and equitable fund allocation across all wards.',
              intendedResultHi: 'शहरी विकास बजट में पारदर्शिता और सभी वार्डों में समान विकास।',
              practicalProcessEn: 'Meeting notice received -> Deliberation in council hall -> Recorded division/voting -> Entry into Municipal Proceedings Book.',
              practicalProcessHi: 'बैठक नोटिस -> सदन में चर्चा -> मतदान -> नगर पालिका कार्यवाही पंजिका (Minutes Register) में अंकन।',
              verificationEvidenceEn: 'Signed municipal house meeting proceedings register and official gazetted resolutions.',
              verificationEvidenceHi: 'हस्ताक्षरित नगर पालिका बैठक कार्यवाही रजिस्टर व आधिकारिक संकल्प।',
              statutoryCitation: 'The Haryana Municipal Act, 1973, Sec. 25-28',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.socialSectorCoordination,
          items: [
            DutyItem(
              titleEn: 'Urban Health, Anganwadi, and Vector Control Coordination',
              titleHi: 'शहरी स्वास्थ्य, आंगनवाड़ी व मच्छर जनित रोग रोकथाम',
              descriptionEn:
                  'Coordinate with Urban Primary Health Centres (UPHCs) and health inspectors for anti-larval sprays, fogging during dengue/malaria seasons, and pulse polio drives in the ward.',
              descriptionHi:
                  'शहरी स्वास्थ्य केंद्रों (UPHC) से समन्वय कर डेंगू-मलेरिया रोकथाम के लिए फॉगिंग, दवा का छिड़काव व टीकाकरण में सहयोग करना।',
              responsibilityType: ResponsibilityType.departmentalResponsibility,
              lineDepartmentEn: 'District Health Department / Urban Primary Health Centre.',
              lineDepartmentHi: 'जिला स्वास्थ्य विभाग / शहरी प्राथमिक स्वास्थ्य केंद्र।',
              representativeRoleEn: 'Identifies stagnant water pools for chemical treatment and mobilizes residents for vaccination camps.',
              representativeRoleHi: 'जलभराव स्थलों पर कीटनाशक डलवाते हैं और वार्ड में स्वास्थ्य व टीकाकरण शिविरों का प्रचार करते हैं।',
              activitiesIncludedEn: 'Arranging thermal fogging in narrow alleys, tracking water tank chlorination, inspecting Anganwadi nutrition.',
              activitiesIncludedHi: 'तंग गलियों में फॉगिंग, पेयजल टंकियों में दवा डलवाना और आंगनवाड़ी पोषाहार वितरण की निगरानी।',
              intendedResultEn: 'Prevention of dengue/chikungunya outbreaks and full immunization coverage for urban children.',
              intendedResultHi: 'डेंगू-मलेरिया के प्रकोप पर नियंत्रण और बच्चों का शत-प्रतिशत टीकाकरण।',
              practicalProcessEn: 'Ward vector alert -> Coordination with Health Inspector -> Scheduled fogging -> Resident verification.',
              practicalProcessHi: 'सूचना प्रेषण -> स्वास्थ्य निरीक्षक से समन्वय -> फॉगिंग व छिड़काव -> नागरिकों से सत्यापन।',
              verificationEvidenceEn: 'Urban Primary Health Centre fogging roster and health camp log.',
              verificationEvidenceHi: 'शहरी स्वास्थ्य केंद्र फॉगिंग रोस्टर और चिकित्सा शिविर उपस्थिति रिकॉर्ड।',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.welfareAndDisaster,
          items: [
            DutyItem(
              titleEn: 'Monsoon Waterlogging Relief & Emergency Reporting',
              titleHi: 'जलभराव राहत कार्य व आपदा प्रबंधन में सहयोग',
              descriptionEn:
                  'Coordinate deployment of portable water pumps during heavy rainfall waterlogging, report collapsed structures, and facilitate relief for fire or storm victims in the ward.',
              descriptionHi:
                  'भारी बारिश में जलभराव पर पंप लगवाना, जर्जर भवनों की सूचना देना और आगजनी या आपदा में नागरिकों को राहत दिलाना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              representativeRoleEn: 'Maintains emergency contact with Executive Officer and Fire / Disaster cells; arranges tractor pumps in low-lying pockets.',
              representativeRoleHi: 'कार्यकारी अधिकारी व आपदा प्रबंधन शाखा से संपर्क रखते हैं और निचले इलाकों में ट्रैक्टर पंप लगवाते हैं।',
              activitiesIncludedEn: 'Deploying municipal suction machines, opening choked main line catchpits, escorting relief teams.',
              activitiesIncludedHi: 'सक्शन मशीनों की तैनाती, जाम नालों को खुलवाना और आपदा पीड़ितों को सुरक्षित स्थान पर पहुंचाना।',
              intendedResultEn: 'Swift water drainage within hours of torrential rains and prompt relief to affected families.',
              intendedResultHi: 'बारिश के बाद शीघ्र पानी निकासी और प्रभावित नागरिकों को तत्काल सहायता।',
              practicalProcessEn: 'Rain alert -> Mobilizing municipal flood control cell -> On-ground pump operation -> Escalating severe breaches to DMC.',
              practicalProcessHi: 'जलभराव सूचना -> नगर पालिका बाढ़ नियंत्रण कक्ष सक्रियण -> पंप संचालन -> जिला प्रशासन को रिपोर्ट।',
              lineDepartmentEn: 'Municipal Disaster / Engineering Wing & District Disaster Management Authority (DDMA)',
              lineDepartmentHi: 'नगर पालिका आपदा प्रबंधन शाखा व जिला आपदा प्रबंधन प्राधिकरण (DDMA)',
              verificationEvidenceEn: 'Municipal flood control room deployment register and fuel log for pumps.',
              verificationEvidenceHi: 'बाढ़ नियंत्रण कक्ष वाहन/पंप लॉगबुक और राहत वितरण विवरण।',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.legalLimitsAndExclusions,
          items: [
            DutyItem(
              titleEn: 'Separation of Deliberative and Executive Authority',
              titleHi: 'राजनीतिक व प्रशासनिक शक्तियों का संवैधानिक पृथक्करण',
              descriptionEn:
                  'Councillors deliberate, vote, and monitor policy; administrative execution, joint contract execution under Sec. 50 of HMA 1973 (or Sec. 166 of HMCA 1994), and day-to-day office management belong to the executive administration under statutory municipal rules.',
              descriptionHi:
                  'पार्षद नीति बनाने, प्रस्ताव रखने व मतदान का कार्य करते हैं; प्रशासनिक क्रियान्वयन, अनुबंधों का संयुक्त निष्पादन और दैनिक कार्यालय प्रबंधन वैधानिक नियमों के तहत प्रशासनिक शाखा का कार्य है।',
              responsibilityType: ResponsibilityType.departmentalResponsibility,
              representativeRoleEn: 'Deliberates in the municipal house; refrains from unlawful interference in statutory procurement or executive licensing.',
              representativeRoleHi: 'सदन में नीतिगत चर्चा करते हैं; टेंडर प्रक्रिया, चालान या लाइसेंसिंग में गैर-कानूनी हस्तक्षेप से दूर रहते हैं।',
              activitiesIncludedEn: 'Voting on policy proposals, scrutinizing audit objections, conveying citizen priorities.',
              activitiesIncludedHi: 'नीतिगत प्रस्तावों पर मतदान, ऑडिट आपत्तियों की समीक्षा और नागरिक प्राथमिकताओं को सदन में रखना।',
              intendedResultEn: 'Upholding constitutional checks and balances between elected representatives and permanent civil administration.',
              intendedResultHi: 'जनप्रतिनिधियों और स्थाई प्रशासनिक अधिकारियों के बीच शक्तियों का संतुलन व कानून का पालन।',
              practicalProcessEn: 'House resolution passes policy -> Executive Officer executes under law -> Internal/State audit reviews expenditure.',
              practicalProcessHi: 'सदन प्रस्ताव पारित करता है -> कार्यकारी अधिकारी कानून अनुसार क्रियान्वित करते हैं -> राज्य ऑडिट द्वारा जांच।',
              lineDepartmentEn: 'Executive Officer / Municipal Commissioner & Directorate of Urban Local Bodies',
              lineDepartmentHi: 'कार्यकारी अधिकारी / निगमायुक्त व शहरी स्थानीय निकाय निदेशालय',
              verificationEvidenceEn: 'State Government audit report and Municipal Board resolutions record.',
              verificationEvidenceHi: 'राज्य सरकार ऑडिट रिपोर्ट और नगर पालिका संकल्प पंजिका।',
              statutoryCitation: 'The Haryana Municipal Act, 1973, Sec. 25-29, 50 & 74th Constitutional Amendment (Art. 243W)',
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // 2. MUNICIPAL CHAIRPERSON / PRESIDENT (नगर पालिका / परिषद अध्यक्ष)
  // =========================================================================
  static RepresentativeRoleProfile _buildMunicipalChairpersonProfile(bool isHaryana) {
    return RepresentativeRoleProfile(
      role: RepresentativeRole.municipalChairperson,
      titleEn: 'Municipal Chairperson / Mayor',
      titleHi: 'नगर पालिका अध्यक्ष / मेयर',
      governingBodyEn: 'Municipal Council / Municipal Committee',
      governingBodyHi: 'नगर परिषद / नगर पालिका समिति',
      isAdministrativeOfficer: false,
      constitutionalPostSummaryEn:
          'Directly elected presiding political head of the Municipal Council or Municipal Committee under Section 18 of The Haryana Municipal Act, 1973 (as amended by Haryana Act No. 12 of 2022). Responsible for convening and presiding over board meetings (Sec. 25-28), guiding town development policies, placing the annual municipal budget estimates before the board under Chapter IV (Sec. 56-60) and the Haryana Municipal Account Code, 2025 (notified 20 May 2025, repealing the 1930 Code), and reviewing civic administration with the Executive Officer. Holds deliberative, presiding, and general supervisory powers; contracts exceeding Rs. 500 require joint execution under Section 50 with the Executive Officer / Secretary.',
      constitutionalPostSummaryHi:
          'हरियाणा नगर पालिका अधिनियम, 1973 की धारा 18 (2022 में संशोधित) के तहत नगर परिषद या नगर पालिका के प्रत्यक्ष निर्वाचित पीठासीन राजनीतिक प्रमुख। बोर्ड बैठकों को बुलाना व अध्यक्षता करना (धारा 25-28), शहर के विकास की नीतियां तय करना, अध्याय IV (धारा 56-60) व हरियाणा म्युनिसिपल अकाउंट कोड, 2025 (20 मई 2025 को अधिसूचित, जिसने 1930 कोड को निरस्त किया) के तहत वार्षिक बजट अनुमान सदन में रखना और नागरिक प्रशासन की समीक्षा करना इनका मुख्य कार्य है। सामान्य प्रशासन और नीतिगत मार्गदर्शन इनका दायित्व है; धारा 50 के तहत 500 रुपये से अधिक के अनुबंधों का ईओ/सचिव के साथ संयुक्त निष्पादन अनिवार्य है।',
      legalReference: LegalSourceReference(
        sourceTitle: isHaryana
            ? 'The Haryana Municipal Act, 1973 (Haryana Act No. 24 of 1973)'
            : 'General Model Guidance (National Local Governance Framework)',
        relevantSections: isHaryana
            ? 'Sections 18 (Direct Election of President), 25-28 (Meetings & Deliberations), 33 (Delegation of Powers by Resolution), 49-50 (Contract Delegation & Mandatory Joint Execution), 56-60 (Municipal Fund & Application)'
            : 'Constitution of India (74th Amendment), Articles 243R & 243W (Twelfth Schedule)',
        jurisdictionState: isHaryana ? 'Haryana' : 'General / Model Framework',
        sourceUrl: isHaryana ? 'https://ulbharyana.gov.in/the-haryana-municipal-act-1973' : 'https://legislative.gov.in/constitution-of-india',
        lastVerifiedDate: '2026-10-28',
        isStateSpecific: isHaryana,
        officialGuidanceNoteEn: isHaryana
            ? 'Statutory provisions governing Municipal Presidents under The Haryana Municipal Act, 1973.'
            : 'General Model Guidance grounded in the 74th Constitutional Amendment for municipal chairpersons.',
        officialGuidanceNoteHi: isHaryana
            ? 'हरियाणा नगर पालिका अधिनियम, 1973 के अंतर्गत नगर पालिका/परिषद अध्यक्षों के वैधानिक प्रावधान।'
            : 'नगर पालिका अध्यक्षों के लिए 74वें संविधान संशोधन पर आधारित सामान्य मॉडल मार्गदर्शन।',
      ),
      citizenQa: const [
        CitizenQaItem(
          questionEn: 'How is a Municipal President / Chairperson elected in Haryana?',
          questionHi: 'हरियाणा में नगर पालिका/परिषद अध्यक्ष का चुनाव कैसे होता है?',
          answerEn:
              'Under the Haryana Municipal (Amendment) Act 2022 (amending Section 18), the President of a Municipal Council or Municipal Committee is DIRECTLY elected by the registered voters of the entire municipality, rather than being chosen indirectly by councillors.',
          answerHi:
              'हरियाणा नगर पालिका (संशोधन) अधिनियम 2022 (धारा 18 संशोधन) के तहत नगर परिषद व नगर पालिका के अध्यक्ष (प्रधान) का चुनाव पूरे शहर के मतदाताओं द्वारा प्रत्यक्ष (Direct Election) रूप से किया जाता है।',
        ),
        CitizenQaItem(
          questionEn: 'What does a Municipal President / Chairperson do for the city?',
          questionHi: 'नगर पालिका अध्यक्ष शहर के लिए क्या-क्या करते हैं?',
          answerEn:
              'The President convenes and presides over house meetings, finalizes the civic development agenda, tables the annual budget for board approval, guides town infrastructure policies (drainage, roads, sanitation, parks, lighting), and coordinates with the state government for development grants.',
          answerHi:
              'अध्यक्ष नगरपालिका सदन की बैठकों की अध्यक्षता करते हैं, विकास एजेंडा तय करते हैं, वार्षिक बजट सदन में प्रस्तुत करते हैं, सड़कों, नालों, सफाई, पार्कों व लाइट की नीति बनाते हैं और राज्य सरकार से विकास अनुदान लाते हैं।',
        ),
        CitizenQaItem(
          questionEn: 'Who approves city development projects, budgets, and tenders?',
          questionHi: 'शहर के विकास कार्यों, बजट और टेंडरों को मंजूरी कौन देता है?',
          answerEn:
              'The elected Municipal Board passes the budget and project resolutions. Technical sanction is issued by the Municipal Engineer. Administrative and financial sanction is accorded by the Executive Officer (EO) / District Municipal Commissioner (DMC) as per state procurement rules. The President cannot unilaterally award contracts without public e-tendering.',
          answerHi:
              'विकास बजट व प्रस्तावों को निर्वाचित बोर्ड पारित करता है; तकनीकी स्वीकृति म्युनिसिपल इंजीनियर देते हैं; और प्रशासनिक स्वीकृति व ई-टेंडरिंग कार्यकारी अधिकारी (EO)/DMC द्वारा की जाती है। अध्यक्ष अकेले बिना टेंडर कोई ठेका नहीं दे सकते।',
        ),
        CitizenQaItem(
          questionEn: 'Which works belong to other line departments outside the municipality?',
          questionHi: 'कौन से कार्य नगर पालिका के अधिकार क्षेत्र से बाहर अन्य विभागों के हैं?',
          answerEn:
              'Major national/state highways belong to PWD/NHAI; major piped water tubewells and underground sewerage networks often belong to PHED/Water Boards; power supply and transformers belong to Discoms; master planning and land-use zoning belong to Town & Country Planning; crime and policing belong to State Police.',
          answerHi:
              'मुख्य राष्ट्रीय/राज्य राजमार्ग लोक निर्माण विभाग (PWD)/NHAI के अधीन हैं; सीवरेज ट्रीटमेंट प्लांट व पेयजल लाइनें जनस्वास्थ्य विभाग (PHED) के पास हैं; बिजली आपूर्ति बिजली निगम (Discom) के पास है; और मास्टर प्लान/भूमि उपयोग राज्य नगर योजना विभाग का कार्य है।',
        ),
        CitizenQaItem(
          questionEn: 'Where should citizens report municipal maladministration or corruption?',
          questionHi: 'नगर पालिका में भ्रष्टाचार या लापरवाही की शिकायत कहाँ करें?',
          answerEn:
              'Submit a written representation to the Executive Officer (EO) or District Municipal Commissioner (DMC). You can also escalate to the Directorate of Urban Local Bodies Haryana, or register on CM Window Haryana / Lokayukta portal.',
          answerHi:
              'कार्यकारी अधिकारी (EO) या जिला नगर आयुक्त (DMC) को लिखित शिकायत दें। समाधान न होने पर शहरी स्थानीय निकाय निदेशालय या हरियाणा सीएम विंडो (cmwindow.haryana.gov.in) / लोकायुक्त को शिकायत भेजें।',
        ),
      ],
      legalLimitationsEn: const [
        'Does not possess unilateral executive authority to award tenders or disburse municipal funds without Board resolution and EO concurrence.',
        'Cannot override state town planning master plan zoning regulations or unilaterally regularize unauthorized colonies.',
        'Cannot personally appoint municipal permanent employees or alter state municipal civil service service rules.',
        'Cannot order police investigations, arrests, or magisterial court proceedings.',
        'Cannot grant illegal property tax exemptions or waive statutory municipal development charges contrary to state rules.',
      ],
      legalLimitationsHi: const [
        'बोर्ड प्रस्ताव और कार्यकारी अधिकारी (EO) की प्रशासनिक स्वीकृति के बिना अकेले टेंडर आवंटन या भुगतान का अधिकार नहीं है।',
        'टाउन एंड कंट्री प्लानिंग के मास्टर प्लान नियमों का उल्लंघन करने या अवैध कॉलोनियों को अकेले नियमित करने का अधिकार नहीं है।',
        'स्थाई नगर पालिका कर्मचारियों की सीधी भर्ती करने या राज्य सेवा नियमों में बदलाव करने का अधिकार नहीं है।',
        'पुलिस जांच, गिरफ्तारी या न्यायिक कार्यवाही का आदेश देने का कोई अधिकार नहीं है।',
        'राज्य नियमों के विपरीत जाकर अवैध रूप से संपत्ति कर या विकास शुल्क माफ करने का अधिकार नहीं है।',
      ],
      grievanceEscalationEn:
          'Municipal Board: President / Executive Officer (EO) -> District Municipal Commissioner (DMC) -> Director, Urban Local Bodies Haryana -> Principal Secretary, Urban Local Bodies -> CM Window / Lokayukta.',
      grievanceEscalationHi:
          'नगर पालिका स्तर: अध्यक्ष / कार्यकारी अधिकारी (EO) -> जिला नगर आयुक्त (DMC) -> निदेशक, शहरी स्थानीय निकाय हरियाणा -> प्रधान सचिव, शहरी निकाय -> सीएम विंडो / लोकायुक्त।',
      categories: const [
        DutyCategorySection(
          category: DutyCategory.publicAssets,
          items: [
            DutyItem(
              titleEn: 'Town-wide Road Network, Paving, and Drainage Coordination',
              titleHi: 'शहर भर में सड़क नेटवर्क, पेवर ब्लॉक व नाला निर्माण समन्वय',
              descriptionEn:
                  'Prioritize inter-ward master roads, stormwater trunk drains, and culverts; guide town-wide paving plans and monitor drainage outfalls.',
              descriptionHi:
                  'सभी वार्डों को जोड़ने वाली मुख्य सड़कों, जल निकासी के बड़े नालों व पुलियों के निर्माण की प्राथमिकता तय करना और जल निकासी की देखरेख।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              additionalResponsibilityTypes: [ResponsibilityType.requiresApproval],
              procedureOrApprovalEn: 'Board approval + Municipal Engineer technical sanction + E-tendering by EO.',
              procedureOrApprovalHi: 'बोर्ड अनुमोदन + नगरपालिका अभियंता तकनीकी स्वीकृति + EO द्वारा ई-टेंडरिंग।',
              representativeRoleEn: 'Presides over development agenda, balances allocations across wards, and inspects ongoing infrastructure works.',
              representativeRoleHi: 'विकास एजेंडे की अध्यक्षता करते हैं, वार्डों में बजट का संतुलित आवंटन कराते हैं और चल रहे निर्माण कार्यों का निरीक्षण करते हैं।',
              activitiesIncludedEn: 'Approving master drainage schemes, reviewing road carpeting tenders, coordinating utility shifting with Discom/PHED.',
              activitiesIncludedHi: 'जल निकासी योजनाएं स्वीकृत कराना, सड़क निर्माण टेंडरों की समीक्षा और बिजली/पेयजल लाइनों की शिफ्टिंग में समन्वय।',
              intendedResultEn: 'Durable pothole-free roads and reliable stormwater runoff protecting city colonies from flooding.',
              intendedResultHi: 'शहर में जलभराव से मुक्ति, पक्की सड़कें और सुगम यातायात।',
              practicalProcessEn: 'Ward demands consolidated -> Town development plan tabled by President -> Board resolution passed -> Engineering technical sanction -> E-tendering & execution.',
              practicalProcessHi: 'वार्ड प्रस्ताव संकलन -> अध्यक्ष द्वारा नगर विकास योजना प्रस्तुत -> बोर्ड संकल्प -> तकनीकी स्वीकृति -> ई-टेंडर व निर्माण।',
              lineDepartmentEn: 'Municipal Engineering Wing & Directorate of Urban Local Bodies',
              lineDepartmentHi: 'नगर पालिका इंजीनियरिंग विंग व शहरी स्थानीय निकाय निदेशालय',
              verificationEvidenceEn: 'Municipal board resolution register and Haryana Engineering Works portal work contract record.',
              verificationEvidenceHi: 'नगर पालिका संकल्प पंजिका और हरियाणा इंजीनियरिंग वर्क्स पोर्टल कार्य अनुबंध।',
              statutoryCitation: 'The Haryana Municipal Act, 1973, Sec. 61-66',
            ),
            DutyItem(
              titleEn: 'Comprehensive City Solid Waste Management & Sanitation Plan',
              titleHi: 'समग्र शहरी ठोस अपशिष्ट प्रबंधन व स्वच्छता कार्ययोजना',
              descriptionEn:
                  'Guide town-wide waste management strategy, door-to-door segregated collection, deployment of mechanical sweepers, and legacy dumpsite remediation.',
              descriptionHi:
                  'शहर की संपूर्ण कचरा प्रबंधन नीति का मार्गदर्शन, डोर-टू-डोर कचरा एकत्रण, मशीनी सफाई और डंपिंग ग्राउंड का निस्तारण।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              additionalResponsibilityTypes: [ResponsibilityType.requiresApproval],
              representativeRoleEn: 'Chairs municipal sanitation review, ensures adequate sanitation budget, and inspects landfill legacy waste processing.',
              representativeRoleHi: 'सफाई व्यवस्था की समीक्षा बैठकों की अध्यक्षता करते हैं, बजट आवंटन सुनिश्चित करते हैं और सॉलिड वेस्ट प्लांट का दौरा करते हैं।',
              activitiesIncludedEn: 'Allocating funds for tipper vehicles, setting secondary garbage transfer stations, monitoring Swachh Survekshan rankings.',
              activitiesIncludedHi: 'कचरा गाड़ियों का आवंटन, सेकेंडरी ट्रांसफर स्टेशन बनवाना और स्वच्छ सर्वेक्षण रैंकिंग सुधारना।',
              intendedResultEn: 'Clean, open-defecation-free and litter-free urban environment with scientific solid waste processing.',
              intendedResultHi: 'स्वच्छ शहर, वैज्ञानिक कचरा निस्तारण और प्रदूषण से मुक्ति।',
              practicalProcessEn: 'Solid waste action plan approved by Board -> E-tender for waste processing concessionaire -> Monitored by EO & Sanitary branch.',
              practicalProcessHi: 'बोर्ड द्वारा कार्ययोजना पारित -> टेंडर द्वारा एजेंसी चयन -> EO व स्वास्थ्य शाखा द्वारा दैनिक निगरानी।',
              lineDepartmentEn: 'Municipal Health & Sanitation Wing & State Pollution Control Board',
              lineDepartmentHi: 'नगर पालिका स्वास्थ्य शाखा व राज्य प्रदूषण नियंत्रण बोर्ड',
              verificationEvidenceEn: 'Swachh Bharat Mission (Urban) portal compliance status and waste processing agreement.',
              verificationEvidenceHi: 'स्वच्छ भारत मिशन (शहरी) पोर्टल स्टेटस और कचरा प्रबंधन अनुबंध पत्र।',
              statutoryCitation: 'The Haryana Municipal Act, 1973, Sec. 154-165',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.schemesAndBeneficiaries,
          items: [
            DutyItem(
              titleEn: 'PMAY(U), PM SVANidhi, and National Urban Livelihoods Mission',
              titleHi: 'शहरी आवास, पीएम स्वनिधि व राष्ट्रीय शहरी आजीविका मिशन (NULM)',
              descriptionEn:
                  'Review implementation of central urban welfare schemes, ensure inclusion of slum clusters, and facilitate micro-credit loans for self-help groups.',
              descriptionHi:
                  'केंद्रीय शहरी कल्याण योजनाओं की समीक्षा, कच्ची बस्तियों के पात्र परिवारों को पक्के मकान और महिला स्वयं सहायता समूहों को ऋण सहायता।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              additionalResponsibilityTypes: [ResponsibilityType.collectiveResponsibility],
              representativeRoleEn: 'Mobilizes city welfare awareness drives, inaugurates loan distribution camps, and reviews beneficiary coverage with EO.',
              representativeRoleHi: 'कल्याणकारी शिविरों का नेतृत्व करते हैं, ऋण वितरण कैंप लगवाते हैं और ईओ के साथ प्रगति की समीक्षा करते हैं।',
              activitiesIncludedEn: 'Verifying slum survey coverage, inaugurating vendor facilitation centers, monitoring DUDA grants.',
              activitiesIncludedHi: 'स्लम बस्तियों का सर्वेक्षण, वेंडर सुविधा केंद्रों का संचालन और डूडा अनुदानों की निगरानी।',
              intendedResultEn: 'Eradication of urban homelessness, sustainable livelihoods for street vendors, and women economic empowerment.',
              intendedResultHi: 'शहरी गरीबों को पक्के आवास और रेहड़ी-पटरी वालों को आर्थिक संबल।',
              practicalProcessEn: 'Beneficiary mobilization -> Town Vending Committee scrutiny -> Municipal Board endorsement -> Directorate fund release.',
              practicalProcessHi: 'लाभार्थी चयन -> टाउन वेंडिंग कमेटी जांच -> बोर्ड संस्तुति -> निदेशालय द्वारा बजट जारी।',
              lineDepartmentEn: 'District Urban Development Authority (DUDA) / Municipal Social Development Wing',
              lineDepartmentHi: 'जिला शहरी विकास प्राधिकरण (DUDA) / नगर पालिका समाज विकास शाखा',
              verificationEvidenceEn: 'PMAY-U portal sanction list and Town Vending Committee (TVC) registration roster.',
              verificationEvidenceHi: 'पीएम आवास पोर्टल स्वीकृति सूची और टाउन वेंडिंग कमेटी रजिस्टर।',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.meetingsAndBudgets,
          items: [
            DutyItem(
              titleEn: 'Convene and Preside Over Municipal Board Meetings',
              titleHi: 'नगर पालिका बोर्ड बैठकों को बुलाना व अध्यक्षता करना',
              descriptionEn:
                  'Convene mandatory monthly/quarterly meetings of the Municipal Board, finalize agenda items, guide deliberations, and exercise casting vote in case of ties.',
              descriptionHi:
                  'नगर पालिका बोर्ड की नियमित बैठकें बुलाना, एजेंडा तय करना, चर्चा का संचालन करना और मत बराबर होने पर निर्णायक मत देना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              procedureOrApprovalEn: 'Conducted under Municipal Board Conduct of Business Regulations.',
              procedureOrApprovalHi: 'नगर पालिका बोर्ड कार्य संचालन विनियमों के तहत।',
              representativeRoleEn: 'Issues meeting notices through EO, presides impartially over debates, and signs formal minutes of proceedings.',
              representativeRoleHi: 'कार्यकारी अधिकारी के माध्यम से बैठक बुलाते हैं, निष्पक्ष अध्यक्षता करते हैं और कार्यवृत्त पर हस्ताक्षर करते हैं।',
              activitiesIncludedEn: 'Regulating order in the House, admitting councillor question notices, signing resolution book.',
              activitiesIncludedHi: 'सदन में अनुशासन बनाए रखना, पार्षदों के प्रश्नों को शामिल करना और प्रस्ताव पंजिका पर हस्ताक्षर।',
              intendedResultEn: 'Transparent, democratic urban local governance ensuring accountability to citizens.',
              intendedResultHi: 'लोकतांत्रिक व पारदर्शी शासन प्रणाली और जनता के प्रति जवाबदेही।',
              practicalProcessEn: 'Agenda approved by President -> Notice served to members -> Meeting conducted -> Resolutions recorded and sent to Deputy Commissioner.',
              practicalProcessHi: 'अध्यक्ष द्वारा एजेंडा फाइनल -> सदस्यों को नोटिस -> बैठक का संचालन -> प्रस्ताव पारित कर उपायुक्त को प्रेषण।',
              verificationEvidenceEn: 'Official signed Municipal Proceedings Register and DC acknowledgment letter.',
              verificationEvidenceHi: 'हस्ताक्षरित नगर पालिका कार्यवाही रजिस्टर व उपायुक्त पावती।',
              statutoryCitation: 'The Haryana Municipal Act, 1973, Sec. 25-32',
            ),
            DutyItem(
              titleEn: 'Annual Municipal Budget Presentation & Revenue Review',
              titleHi: 'वार्षिक बजट प्रस्तुतिकरण व नगरपालिका राजस्व समीक्षा',
              descriptionEn:
                  'Place the annual municipal estimate of receipts and expenditures before the Board for approval; review property tax, fire tax, and license fee collections.',
              descriptionHi:
                  'वार्षिक आय-व्यय बजट प्राक्कलन बोर्ड के समक्ष अनुमोदन हेतु प्रस्तुत करना; संपत्ति कर, जल कर व लाइसेंस शुल्क वसूली की समीक्षा।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              additionalResponsibilityTypes: [ResponsibilityType.collectiveResponsibility],
              procedureOrApprovalEn: 'Budget approval by Municipal Board + submission to Director, Urban Local Bodies.',
              procedureOrApprovalHi: 'बोर्ड द्वारा बजट पारित + निदेशक, शहरी स्थानीय निकाय को अनुमोदन हेतु प्रेषण।',
              representativeRoleEn: 'Presents policy vision in the budget, proposes public amenity outlays, and motivates revenue recovery with EO.',
              representativeRoleHi: 'बजट में विकास दृष्टि प्रस्तुत करते हैं, जनसुविधाओं के लिए फंड रखवाते हैं और कर वसूली बढ़ाने पर जोर देते हैं।',
              activitiesIncludedEn: 'Scrutinizing property tax demands, evaluating development expenditure, ensuring mandatory reservations for poor areas.',
              activitiesIncludedHi: 'संपत्ति कर वसूली की समीक्षा, विकास खर्च का मूल्यांकन और गरीब बस्तियों के लिए बजट आवंटन।',
              intendedResultEn: 'Fiscal health and self-sustainability of the municipality enabling robust civic infrastructure.',
              intendedResultHi: 'नगर पालिका की वित्तीय सुदृढ़ता और शहर के सभी क्षेत्रों का समग्र विकास।',
              practicalProcessEn: 'Draft budget prepared by EO/Accountant -> President review -> Tabled in special budget session -> Passed by majority -> Sent to Directorate.',
              practicalProcessHi: 'ईओ/लेखापाल द्वारा बजट ड्राफ्ट -> अध्यक्ष द्वारा समीक्षा -> विशेष बजट बैठक में पारित -> निदेशालय प्रेषण।',
              lineDepartmentEn: 'Municipal Accounts Branch & Directorate of Urban Local Bodies',
              lineDepartmentHi: 'नगर पालिका लेखा शाखा व शहरी स्थानीय निकाय निदेशालय',
              verificationEvidenceEn: 'Budget approval resolution copy and Directorate ULB sanction letter.',
              verificationEvidenceHi: 'बजट स्वीकृति संकल्प प्रति और शहरी निकाय निदेशालय का मंजूरी पत्र।',
              statutoryCitation: 'The Haryana Municipal Act, 1973, Sec. 56-60 & Haryana Municipal Account Code, 2025 (notified 20 May 2025, repealing 1930 Code)',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.socialSectorCoordination,
          items: [
            DutyItem(
              titleEn: 'Urban Parks, Community Centers, Libraries, and Crematoriums',
              titleHi: 'शहरी पार्क, सामुदायिक भवन, पुस्तकालय व श्मशान घाट विकास',
              descriptionEn:
                  'Guide development of community parks, open gym facilities, municipal public libraries, and renovation of crematoriums and burial grounds.',
              descriptionHi:
                  'सार्वजनिक पार्कों, ओपन जिम, नगर पालिका पुस्तकालयों और श्मशान घाटों/कब्रिस्तानों का आधुनिकीकरण व रखरखाव।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              representativeRoleEn: 'Allocates municipal development grants for public green spaces and monitors maintenance contracts.',
              representativeRoleHi: 'हरित क्षेत्रों व पार्कों के लिए फंड आवंटित कराते हैं और मेंटेनेंस की निगरानी करते हैं।',
              activitiesIncludedEn: 'Installing solar lights in parks, arranging walking tracks, upgrading crematorium sheds.',
              activitiesIncludedHi: 'पार्कों में सोलर लाइट व पाथवे बनवाना, ओपन जिम लगाना और श्मशान घाटों पर शेड व पेयजल व्यवस्था।',
              intendedResultEn: 'Accessible recreational, sports, and cultural public spaces for families, youth, and senior citizens.',
              intendedResultHi: 'बच्चों, युवाओं और बुजुर्गों के लिए स्वच्छ व सुंदर पार्क और बेहतर नागरिक सुविधाएं।',
              practicalProcessEn: 'Board resolution -> Horticulture / Engineering estimate -> Work execution -> Park Development Committee oversight.',
              practicalProcessHi: 'बोर्ड प्रस्ताव -> इंजीनियरिंग प्राक्कलन -> टेंडर द्वारा निर्माण -> पार्क विकास समिति द्वारा निगरानी।',
              lineDepartmentEn: 'Municipal Horticulture / Engineering Branch',
              lineDepartmentHi: 'नगर पालिका उद्यान एवं इंजीनियरिंग शाखा',
              verificationEvidenceEn: 'Municipal asset register entry and work completion certificate.',
              verificationEvidenceHi: 'नगर पालिका संपत्ति रजिस्टर प्रविष्टि और कार्य पूर्णता प्रमाण पत्र।',
              statutoryCitation: 'The Haryana Municipal Act, 1973, Sec. 66 & Twelfth Schedule',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.welfareAndDisaster,
          items: [
            DutyItem(
              titleEn: 'Emergency Response in Urban Floods, Fires, or Seasonal Outbreaks',
              titleHi: 'शहरी बाढ़, आगजनी या महामारी में आपातकालीन राहत समन्वय',
              descriptionEn:
                  'Mobilize city administration, municipal fire services, and dewatering pumps during torrential waterlogging, fire incidents, or seasonal epidemics.',
              descriptionHi:
                  'भारी बारिश में जलभराव, आगजनी या महामारी के समय नगर पालिका फायर ब्रिगेड, पंप व राहत टीमों का संचालन सुनिश्चित करना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              representativeRoleEn: 'Coordinates on-ground relief operations with the District Deputy Commissioner and oversees distribution of emergency relief.',
              representativeRoleHi: 'उपायुक्त व जिला प्रशासन से समन्वय करते हैं और मौके पर पहुंचकर राहत कार्य सुनिश्चित करते हैं।',
              activitiesIncludedEn: 'Deploying tractor-mounted pumps in submerged sectors, alerting fire stations, coordinating temporary shelters.',
              activitiesIncludedHi: 'जलभराव वाले इलाकों में भारी पंप लगवाना, अग्निशमन दल को अलर्ट करना और प्रभावितों के भोजन-आश्रय की व्यवस्था।',
              intendedResultEn: 'Immediate preservation of life and property during natural calamities and civic disasters.',
              intendedResultHi: 'आपदा के समय जान-माल की रक्षा और नागरिकों को त्वरित राहत।',
              practicalProcessEn: 'Emergency alert -> Municipal disaster cell activated -> Field pump deployment -> Coordination with DDMA.',
              practicalProcessHi: 'अलर्ट प्राप्ति -> आपदा सेल सक्रिय -> पंपों व राहत दलों की तैनाती -> जिला आपदा प्रबंधन से समन्वय।',
              lineDepartmentEn: 'Municipal Disaster / Fire Services & District Disaster Management Authority (DDMA)',
              lineDepartmentHi: 'नगर पालिका अग्निशमन सेवा व जिला आपदा प्रबंधन प्राधिकरण',
              verificationEvidenceEn: 'Municipal emergency logbook and District Collector disaster assistance record.',
              verificationEvidenceHi: 'आपातकालीन नियंत्रण कक्ष लॉगबुक और जिला प्रशासन राहत रिपोर्ट।',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.legalLimitsAndExclusions,
          items: [
            DutyItem(
              titleEn: 'Statutory Allocation of Executive Functions and Contract Execution',
              titleHi: 'कार्यकारी कार्यों एवं अनुबंध निष्पादन का वैधानिक आवंटन',
              descriptionEn:
                  'The President presides over the board and exercises administrative supervision; under Section 50 of HMA 1973, contracts exceeding Rs. 500 require joint execution by two members (including President/VP) and the EO/Secretary, while specific committee powers may be delegated under Section 33 with prior State Government sanction.',
              descriptionHi:
                  'प्रधान सदन की बैठकों की अध्यक्षता करते हैं व सामान्य पर्यवेक्षण रखते हैं; हरियाणा नगर पालिका अधिनियम, 1973 की धारा 50 के अनुसार 500 रुपये से अधिक के अनुबंधों पर दो सदस्यों (प्रधान/उप-प्रधान सहित) और ईओ/सचिव के संयुक्त हस्ताक्षर अनिवार्य हैं, तथा धारा 33 के तहत राज्य सरकार की पूर्व मंजूरी से विशिष्ट शक्तियों का प्रत्यायोजन किया जा सकता है।',
              responsibilityType: ResponsibilityType.departmentalResponsibility,
              representativeRoleEn: 'Upholds statutory separation between elected political leadership and permanent civil administration.',
              representativeRoleHi: 'निर्वाचित नेतृत्व और स्थाई प्रशासनिक अधिकारियों के बीच शक्तियों के वैधानिक संतुलन का पालन करते हैं।',
              activitiesIncludedEn: 'Reviewing progress, tabling policy guidelines, checking audit compliance.',
              activitiesIncludedHi: 'प्रगति समीक्षा, नीतिगत दिशानिर्देश देना और ऑडिट अनुपालन सुनिश्चित करना।',
              intendedResultEn: 'Rule of law and prevention of unilateral financial abuse in municipal governance.',
              intendedResultHi: 'कानून का शासन और नगर पालिका प्रशासन में वित्तीय अनुशासन।',
              practicalProcessEn: 'Board resolutions passed democratically -> Executive Officer carries out execution under statutory rules.',
              practicalProcessHi: 'सदन द्वारा विधिवत प्रस्ताव पारित -> कार्यकारी अधिकारी द्वारा नियमानुसार क्रियान्वयन।',
              lineDepartmentEn: 'Executive Officer / Secretary & Directorate of Urban Local Bodies',
              lineDepartmentHi: 'कार्यकारी अधिकारी / सचिव व शहरी स्थानीय निकाय निदेशालय',
              verificationEvidenceEn: 'State Municipal Audit Inspection Report and official proceedings book.',
              verificationEvidenceHi: 'राज्य नगर पालिका ऑडिट रिपोर्ट और आधिकारिक कार्यवाही पंजिका।',
              statutoryCitation: 'The Haryana Municipal Act, 1973, Sec. 33, 49, 50 & Haryana Municipal Account Code, 2025',
            ),
          ],
        ),
      ],
    );
  }


  // =========================================================================
  // 3. MAYOR (Municipal Corporation / नगर निगम महापौर)
  // =========================================================================
  static RepresentativeRoleProfile _buildMayorProfile(String? stateIdentifier) {
    final bool isHaryana = stateIdentifier == 'haryana';
    return RepresentativeRoleProfile(
      role: RepresentativeRole.mayor,
      isAdministrativeOfficer: false,
      titleEn: 'Mayor (Municipal Corporation)',
      titleHi: 'महापौर / मेयर (नगर निगम)',
      governingBodyEn: 'Municipal Corporation (Nagar Nigam)',
      governingBodyHi: 'नगर निगम',
      constitutionalPostSummaryEn:
          'First citizen and elected political head of the Municipal Corporation. Presides over the General House meetings, guides city development policies, monitors execution of master plans and municipal budgets, and liaises with the State Government on urban development funds and infrastructure projects.',
      constitutionalPostSummaryHi:
          'नगर निगम के प्रथम नागरिक और निर्वाचित राजनीतिक मुखिया। निगम सदन (जनरल हाउस) की बैठकों की अध्यक्षता करते हैं, शहर की विकास नीतियों का मार्गदर्शन करते हैं, बजट व मास्टर प्लान के क्रियान्वयन की निगरानी करते हैं, और शहरी विकास योजनाओं के लिए राज्य सरकार से समन्वय करते हैं।',
      legalReference: LegalSourceReference(
        sourceTitle: isHaryana
            ? 'The Haryana Municipal Corporation Act, 1994 (Haryana Act No. 16 of 1994)'
            : 'General Model Guidance (National Local Governance Framework)',
        relevantSections: isHaryana
            ? 'Sections 4(3) (Direct Election of Mayor), 36-38 (Powers of Mayor & Deputy Mayor), 54-64 (Meetings and Proceedings of Corporation), 49 & 165-167 (Executive Powers and Contract Approval Thresholds), 73-76 & 83 (Municipal Fund and Budget Adoption)'
            : 'Constitution of India (74th Amendment), Articles 243R, 243S, 243W & Twelfth Schedule (Functions 1-18)',
        jurisdictionState: isHaryana ? 'Haryana' : 'General / Model Framework',
        sourceUrl: isHaryana ? 'https://ulbharyana.gov.in/the-haryana-municipal-corporation-act-1994' : 'https://legislative.gov.in/constitution-of-india',
        lastVerifiedDate: '2026-10-28',
        isStateSpecific: isHaryana,
        officialGuidanceNoteEn: isHaryana
            ? 'Statutory provisions governing Mayors under The Haryana Municipal Corporation Act, 1994.'
            : 'General Model Guidance grounded in the 74th Constitutional Amendment for municipal corporation mayors.',
        officialGuidanceNoteHi: isHaryana
            ? 'हरियाणा नगर निगम अधिनियम, 1994 के अंतर्गत महापौर (मेयर) से संबंधित वैधानिक प्रावधान।'
            : 'महापौर के लिए 74वें संविधान संशोधन पर आधारित सामान्य मॉडल मार्गदर्शन।',
      ),
      legalLimitationsEn: const [
        'No direct executive contracting or disbursement power: Under Sec. 49 of HMCA 1994, executive power for carrying out Act provisions vests in the Municipal Commissioner, and contracts are executed under Sec. 166, not directly by the Mayor.',
        'Cannot unilaterally approve building plans, change land-use (CLU), or award tenders without compliance with statutory municipal rules and House sanction.',
        'No authority to punish or transfer civil servants: Administrative control of municipal staff belongs to the Municipal Commissioner and Directorate of Urban Local Bodies.',
        'Resolutions passed by the Corporation are subject to state government oversight under Sec. 400-408 of the Haryana Municipal Corporation Act, 1994.',
      ],
      legalLimitationsHi: const [
        'प्रत्यक्ष कार्यकारी, निविदा या चेक जारी करने की शक्ति नहीं: हरियाणा नगर निगम अधिनियम, 1994 की धारा 49 के तहत कार्यकारी शक्तियां आयुक्त (कमिश्नर) में निहित हैं, और धारा 166 के तहत अनुबंध आयुक्त द्वारा निष्पादित किए जाते हैं, मेयर द्वारा सीधे नहीं।',
        'बिना वैधानिक प्रक्रिया और सदन की मंजूरी के मनमाने ढंग से सीएलयू (CLU), नक्शे पास करने या टेंडर स्वीकृत करने का अधिकार नहीं।',
        'अधिकारियों/कर्मचारियों के स्थानांतरण या दंडात्मक कार्रवाई का अधिकार नहीं: प्रशासनिक नियंत्रण निगमायुक्त व शहरी स्थानीय निकाय विभाग के पास है।',
        'सदन द्वारा पारित प्रस्तावों पर राज्य सरकार की निगरानी और समीक्षा की वैधानिक सीमा लागू होती है (धारा 400-408)।',
      ],
      grievanceEscalationEn:
          'City Ward Issues -> Ward Councillor / Zonal Municipal Office -> Municipal Commissioner / Joint Commissioner -> Mayor (General House Grievance & Policy) -> Directorate of Urban Local Bodies / Urban Local Bodies Minister / CM Window.',
      grievanceEscalationHi:
          'वार्ड स्तर की समस्याएं -> वार्ड पार्षद / जोनल नगर निगम कार्यालय -> नगर निगम आयुक्त (कमिश्नर) / संयुक्त आयुक्त -> महापौर (निगम सदन एवं नीतिगत शिकायत) -> महानिदेशक, शहरी स्थानीय निकाय / स्थानीय निकाय मंत्री / सीएम विंडो।',
      citizenQa: const [
        CitizenQaItem(
          questionEn: 'What is the role of the Mayor versus the Municipal Commissioner?',
          questionHi: 'मेयर (महापौर) और नगर निगम आयुक्त (कमिश्नर) की भूमिका में क्या अंतर है?',
          answerEn:
              'The Mayor is the elected political representative who heads the Corporation, presides over House meetings, approves city budgets and policies, and represents citizen interests. The Municipal Commissioner is a senior appointed IAS/HCS administrative officer who holds complete executive power to issue work orders, manage finances, sanction building plans, and enforce municipal bye-laws.',
          answerHi:
              'मेयर निर्वाचित जनप्रतिनिधि हैं जो निगम के राजनीतिक मुखिया होते हैं, सदन की अध्यक्षता करते हैं, शहर का बजट व विकास नीतियां तय करते हैं और जनता की आवाज उठाते हैं। निगमायुक्त (कमिश्नर) राज्य सरकार द्वारा नियुक्त वरिष्ठ प्रशासनिक अधिकारी (IAS/HCS) होते हैं, जिनके पास टेंडर जारी करने, बजट खर्च करने, नक्शे पास करने और दैनिक प्रशासन चलाने की समस्त वैधानिक कार्यकारी शक्तियां होती हैं।',
        ),
        CitizenQaItem(
          questionEn: 'Can the Mayor directly order road repairs or sanitation staff in my area?',
          questionHi: 'क्या मेयर सीधे मेरे क्षेत्र में सड़क मरम्मत या सफाई कर्मचारियों को निर्देश दे सकते हैं?',
          answerEn:
              'The Mayor can instruct the Municipal Commissioner and relevant Joint Commissioners/Executive Engineers to address ward grievances or place development works in the Corporation budget, but day-to-day administrative deployment of sanitation workers and tendering of civil works is officially executed by the Commissioner and engineering staff.',
          answerHi:
              'मेयर नगर निगम आयुक्त, संयुक्त आयुक्त या एक्सईएन को सार्वजनिक शिकायत के निवारण हेतु निर्देशित कर सकते हैं और बजट में कार्य शामिल करवा सकते हैं, परंतु सफाई कर्मियों की दैनिक तैनाती और टेंडर की प्रशासनिक फाइल आयुक्त व इंजीनियरिंग शाखा द्वारा ही क्रियान्वित की जाती है।',
        ),
        CitizenQaItem(
          questionEn: 'How can citizens submit major city-level suggestions or grievances to the Mayor?',
          questionHi: 'नागरिक शहर स्तर के बड़े सुझाव या समस्याएं मेयर के समक्ष कैसे रख सकते हैं?',
          answerEn:
              'Citizens and resident welfare associations (RWAs) can submit memorandums during the Mayor Open Public Hearing (Jan Sunwai), meet the Mayor at the Municipal Corporation Head Office, or petition during House meeting agendas through their local Ward Councillor.',
          answerHi:
              'नागरिक और आरडब्ल्यूए (RWA) मेयर जनसुनवाई के दौरान ज्ञापन दे सकते हैं, नगर निगम मुख्यालय में मेयर कार्यालय में मिलकर मांग पत्र सौंप सकते हैं, या अपने वार्ड पार्षद के माध्यम से निगम सदन की बैठक के एजेंडे में मुद्दा उठवा सकते हैं।',
        ),
      ],
      categories: const [
        DutyCategorySection(
          category: DutyCategory.publicAssets,
          items: [
            DutyItem(
              titleEn: 'Comprehensive City Infrastructure Master Planning & Approval',
              titleHi: 'शहर के समग्र बुनियादी ढांचे का मास्टर प्लान तैयार करना व अनुमोदन',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              additionalResponsibilityTypes: [ResponsibilityType.requiresApproval],
              descriptionEn:
                  'Steering the formulation and adoption of comprehensive master plans for arterial roads, multi-level flyovers, storm water drainage trunks, and solid waste processing plants in the Municipal Corporation House.',
              descriptionHi:
                  'नगर निगम सदन में शहर की मुख्य सड़कों, फ्लाईओवर, बरसाती पानी के मुख्य नालों और ठोस कचरा प्रसंस्करण संयंत्रों के समग्र विकास व मास्टर प्लान का नेतृत्व और अनुमोदन करना।',
              activitiesIncludedEn:
                  'Reviewing comprehensive mobility and drainage plans prepared by urban planners; placing proposals before the Corporation House; allocating municipal infrastructure funds.',
              activitiesIncludedHi:
                  'शहरी योजनाकारों द्वारा तैयार मोबिलिटी व ड्रेनेज प्लान की समीक्षा; निगम सदन के समक्ष प्रस्ताव रखना; बुनियादी ढांचा मदों में बजट आवंटन।',
              intendedResultEn: 'Planned, resilient urban expansion with modern public transit, traffic management, and flood-resilient stormwater drainage.',
              intendedResultHi: 'योजनाबद्ध शहरी विकास, आधुनिक सार्वजनिक परिवहन, यातायात प्रबंधन और जलभराव-मुक्त ड्रेनेज व्यवस्था।',
              practicalProcessEn: 'Engineering division drafts plan -> Placed before Corporation General House -> Mayor presides and leads debate -> Approved resolution forwarded to Commissioner for tendering.',
              practicalProcessHi: 'इंजीनियरिंग शाखा द्वारा ड्राफ्ट तैयार -> निगम सदन में प्रस्तुति -> मेयर की अध्यक्षता में चर्चा व प्रस्ताव पारित -> आयुक्त को टेंडर हेतु प्रेषित।',
              lineDepartmentEn: 'Municipal Corporation Engineering Wing & Directorate of Urban Local Bodies',
              lineDepartmentHi: 'नगर निगम इंजीनियरिंग शाखा व शहरी स्थानीय निकाय विभाग',
              verificationEvidenceEn: 'Corporation General House Resolution and sanctioned City Development Plan document.',
              verificationEvidenceHi: 'नगर निगम सदन का आधिकारिक प्रस्ताव और स्वीकृत नगर विकास योजना दस्तावेज।',
              statutoryCitation: 'The Haryana Municipal Corporation Act, 1994, Sec. 42, 49, 54 & 165-167',
            ),
            DutyItem(
              titleEn: 'Solid Waste Processing Plants & Environmental Cleanliness',
              titleHi: 'ठोस कचरा प्रबंधन संयंत्र एवं व्यापक पर्यावरणीय स्वच्छता',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              additionalResponsibilityTypes: [ResponsibilityType.requiresApproval],
              descriptionEn:
                  'Monitoring city-wide waste segregation, municipal waste-to-energy/compost plants, door-to-door collection coverage, and legacy landfill remediation in compliance with National Green Tribunal (NGT) and SWM Rules 2016.',
              descriptionHi:
                  'एनजीटी (NGT) और ठोस अपशिष्ट प्रबंधन नियम 2016 के तहत डोर-टू-डोर कचरा संग्रहण, कचरा प्रसंस्करण/कंपोस्ट प्लांट और लैंडफिल साइटों के निस्तारण की शहर स्तर पर निगरानी करना।',
              activitiesIncludedEn:
                  'Inspecting centralized dumping and waste-to-energy facilities; reviewing mechanical sweeping contracts; directing health branch to address community sanitation lapses.',
              activitiesIncludedHi:
                  'डंपिंग यार्ड व प्रसंस्करण संयंत्रों का निरीक्षण; मैकेनिकल स्वीपिंग कार्यों की समीक्षा; स्वास्थ्य शाखा को सफाई व्यवस्था दुरुस्त रखने के निर्देश।',
              intendedResultEn: 'Clean, garbage-free city with zero open dumping and compliant scientific municipal waste processing.',
              intendedResultHi: 'स्वच्छ शहर, खुले में कचरा डंपिंग से मुक्ति और वैज्ञानिक अपशिष्ट प्रबंधन।',
              practicalProcessEn: 'Sanitation wing reports monthly waste processing metrics -> Standing committee / General House reviews -> Mayor directs executive rectification of non-performing concessionaires.',
              practicalProcessHi: 'स्वास्थ्य शाखा मासिक रिपोर्ट पेश करती है -> सदन में समीक्षा -> मेयर द्वारा कार्य में लापरवाही बरतने वाली एजेंसियों पर कार्रवाई के निर्देश।',
              lineDepartmentEn: 'Municipal Health Branch & Pollution Control Board',
              lineDepartmentHi: 'नगर निगम स्वास्थ्य शाखा एवं प्रदूषण नियंत्रण बोर्ड',
              verificationEvidenceEn: 'Monthly SWM processing reports and NGT compliance monitoring certificates.',
              verificationEvidenceHi: 'मासिक ठोस अपशिष्ट प्रसंस्करण रिपोर्ट और प्रदूषण नियंत्रण अनुपालन प्रमाण पत्र।',
              statutoryCitation: 'The Haryana Municipal Corporation Act, 1994, Sec. 42(6), 268-274 & SWM Rules 2016',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.meetingsAndBudgets,
          items: [
            DutyItem(
              titleEn: 'Presiding Over Corporation Meetings & Legislative Guidance',
              titleHi: 'निगम सदन की बैठकों की अध्यक्षता एवं विधायी कार्य संचालन',
              responsibilityType: ResponsibilityType.statutoryDuty,
              descriptionEn:
                  'Presiding over every statutory and special meeting of the Municipal Corporation, regulating debates among Ward Councillors, maintaining order, and deciding agenda voting under statutory rules of procedure.',
              descriptionHi:
                  'नगर निगम की सामान्य और विशेष बैठकों की अध्यक्षता करना, पार्षदों के बीच सदन में व्यवस्था बनाए रखना, बहसों का संचालन करना और कार्यसूची पर मतदान कराना।',
              activitiesIncludedEn:
                  'Fixing dates for Corporation House meetings in consultation with the Commissioner; approving meeting agendas; presiding over proceedings and recording casting vote in tie breaks.',
              activitiesIncludedHi:
                  'आयुक्त के परामर्श से बैठक की तारीख तय करना; सदन का एजेंडा मंजूर करना; बैठक की अध्यक्षता करना और मत बराबर होने पर निर्णायक मत देना।',
              intendedResultEn: 'Democratic, transparent deliberation on public works, civic bye-laws, and equitable ward allocations.',
              intendedResultHi: 'लोकतांत्रिक और पारदर्शी बहस, जनहितैषी नीतियां और सभी वार्डों का समानुपातिक विकास।',
              practicalProcessEn: 'Notice issued 7 days prior -> House convenes -> Questions and motions heard -> Resolutions passed by majority -> Confirmed minutes signed by Mayor.',
              practicalProcessHi: '7 दिन पूर्व बैठक नोटिस -> सदन की बैठक -> प्रश्नकाल व प्रस्ताव -> बहुमत से पारित -> मेयर द्वारा हस्ताक्षरित कार्यवाही।',
              lineDepartmentEn: 'Municipal Corporation General Administration & Municipal Secretary',
              lineDepartmentHi: 'नगर निगम सामान्य प्रशासन एवं निगम सचिव',
              verificationEvidenceEn: 'Signed Corporation House Proceedings Book and published gazette bye-laws.',
              verificationEvidenceHi: 'हस्ताक्षरित सदन कार्यवाही पंजिका एवं प्रकाशित उप-नियम गजट अधिसूचना।',
              statutoryCitation: 'The Haryana Municipal Corporation Act, 1994, Sec. 54-64',
            ),
            DutyItem(
              titleEn: 'Annual Municipal Budget Tabling & Ward Equity Scrutiny',
              titleHi: 'वार्षिक निगम बजट की प्रस्तुति, समीक्षा एवं वार्डवार समानुपातिक विकास',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              additionalResponsibilityTypes: [ResponsibilityType.requiresApproval],
              descriptionEn:
                  'Guiding the preparation of the multi-crore annual municipal budget estimate, ensuring adequate allocations for basic civic services, slum development, green belts, and water supply across all wards without political favoritism.',
              descriptionHi:
                  'नगर निगम के बहु-करोड़ीय वार्षिक बजट का मार्गदर्शन करना, यह सुनिश्चित करना कि सभी वार्डों में पेयजल, सीवरेज, सड़क और झुग्गी बस्तियों के सुधार हेतु निष्पक्ष बजट मिले।',
              activitiesIncludedEn:
                  'Reviewing revenue estimates (property tax, fire tax, stamp duty surcharge, trade licences); finalizing capital development priorities; leading budget presentation and adoption in House.',
              activitiesIncludedHi:
                  'राजस्व अनुमानों (प्रॉपर्टी टैक्स, ट्रेड लाइसेंस आदि) की समीक्षा; विकास प्राथमिकताओं का निर्धारण; सदन में बजट पेश करना व पारित कराना।',
              intendedResultEn: 'Fiscally disciplined, balanced corporation budget meeting urban infrastructure needs and statutory obligations.',
              intendedResultHi: 'वित्तीय रूप से सुदृढ़, संतुलित बजट जो शहर की बुनियादी जरूरतों और कानूनी दायित्वों को पूरा करे।',
              practicalProcessEn: 'Commissioner submits budget estimates before Jan 15 -> Mayor and House debate estimates -> Adopted by Feb 15 -> Submitted to State Govt for final sanction.',
              practicalProcessHi: 'आयुक्त 15 जनवरी तक ड्राफ्ट बजट प्रस्तुत करते हैं -> मेयर के नेतृत्व में बहस -> 15 फरवरी तक सदन से पारित -> राज्य सरकार को अंतिम अनुमोदन हेतु प्रेषित।',
              lineDepartmentEn: 'Municipal Accounts & Finance Department',
              lineDepartmentHi: 'नगर निगम लेखा एवं वित्त शाखा',
              verificationEvidenceEn: 'Sanctioned Annual Budget Estimates and State Government Approval Order.',
              verificationEvidenceHi: 'सदन द्वारा स्वीकृत वार्षिक बजट पुस्तिका और राज्य सरकार का प्रशासनिक अनुमोदन आदेश।',
              statutoryCitation: 'The Haryana Municipal Corporation Act, 1994, Sec. 73-76 & 83',
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // 4. DEPUTY MAYOR (Municipal Corporation / उप-महापौर)
  // =========================================================================
  static RepresentativeRoleProfile _buildDeputyMayorProfile(String? stateIdentifier) {
    final bool isHaryana = stateIdentifier == 'haryana';
    return RepresentativeRoleProfile(
      role: RepresentativeRole.deputyMayor,
      isAdministrativeOfficer: false,
      titleEn: 'Deputy Mayor (Municipal Corporation)',
      titleHi: 'उप-महापौर / डिप्टी मेयर (नगर निगम)',
      governingBodyEn: 'Municipal Corporation (Nagar Nigam)',
      governingBodyHi: 'नगर निगम',
      constitutionalPostSummaryEn:
          'Elected by members of the Municipal Corporation from amongst themselves. Assists the Mayor in presiding over meetings during the Mayor absence, supports statutory committees, and liaises with Ward Councillors on public utility redressal.',
      constitutionalPostSummaryHi:
          'नगर निगम के निर्वाचित पार्षदों द्वारा अपने में से चुना गया पद। महापौर की अनुपस्थिति में निगम सदन की बैठकों की अध्यक्षता करना, वैधानिक समितियों में सहयोग देना और वार्ड पार्षदों की समस्याओं के समाधान हेतु समन्वय करना।',
      legalReference: LegalSourceReference(
        sourceTitle: isHaryana
            ? 'The Haryana Municipal Corporation Act, 1994 (Haryana Act No. 16 of 1994)'
            : 'General Model Guidance (National Local Governance Framework)',
        relevantSections: isHaryana
            ? 'Sections 36 (Election of Senior Deputy Mayor & Deputy Mayor), 37-38 (Functions & Powers in absence of Mayor), 54-57 (Presiding at Meetings)'
            : 'Constitution of India (74th Amendment), Articles 243R & 243S',
        jurisdictionState: isHaryana ? 'Haryana' : 'General / Model Framework',
        sourceUrl: isHaryana ? 'https://ulbharyana.gov.in/the-haryana-municipal-corporation-act-1994' : 'https://legislative.gov.in/constitution-of-india',
        lastVerifiedDate: '2026-10-28',
        isStateSpecific: isHaryana,
        officialGuidanceNoteEn: isHaryana
            ? 'Statutory provisions governing Deputy Mayors under The Haryana Municipal Corporation Act, 1994.'
            : 'General Model Guidance grounded in the 74th Constitutional Amendment for deputy mayors.',
        officialGuidanceNoteHi: isHaryana
            ? 'हरियाणा नगर निगम अधिनियम, 1994 के अंतर्गत उप-महापौर से संबंधित वैधानिक प्रावधान।'
            : 'उप-महापौर के लिए 74वें संविधान संशोधन पर आधारित सामान्य मॉडल मार्गदर्शन।',
      ),
      legalLimitationsEn: const [
        'No independent executive authority: Powers to preside or act as Mayor are conditional upon the absence or written delegation of the Mayor.',
        'Cannot sign cheques, approve tenders, or direct municipal administrative staff unilaterally.',
        'Functions strictly within collective decisions of the General House and provisions of HMCA 1994.',
      ],
      legalLimitationsHi: const [
        'कोई स्वतंत्र कार्यकारी शक्ति नहीं: मेयर की अनुपस्थिति या लिखित प्रत्यायोजन की स्थिति में ही मेयर के कार्यों का निर्वहन कर सकते हैं।',
        'स्वतंत्र रूप से निविदा स्वीकृत करने, चेक जारी करने या अधिकारियों को आदेश देने का अधिकार नहीं।',
        'निगम सदन के सामूहिक निर्णयों और अधिनियम के नियमों के दायरे में ही कार्य करते हैं।',
      ],
      grievanceEscalationEn:
          'Ward Councillor -> Deputy Mayor -> Mayor -> Municipal Commissioner -> Directorate of Urban Local Bodies.',
      grievanceEscalationHi:
          'वार्ड पार्षद -> उप-महापौर -> महापौर -> नगर निगम आयुक्त -> शहरी स्थानीय निकाय निदेशालय।',
      citizenQa: const [
        CitizenQaItem(
          questionEn: 'What are the main responsibilities of the Deputy Mayor?',
          questionHi: 'उप-महापौर (डिप्टी मेयर) की मुख्य जिम्मेदारियां क्या हैं?',
          answerEn:
              'The Deputy Mayor assists the Mayor in the administration of the House, presides over Corporation meetings when the Mayor is absent, represents the Corporation at civic events, and coordinates with Ward Councillors on civic delivery bottlenecks.',
          answerHi:
              'डिप्टी मेयर सदन के संचालन में महापौर का सहयोग करते हैं, मेयर की अनुपस्थिति में सदन की अध्यक्षता करते हैं, नागरिक मंचों पर निगम का प्रतिनिधित्व करते हैं और पार्षदों के साथ वार्ड समस्याओं के समाधान में समन्वय करते हैं।',
        ),
      ],
      categories: const [
        DutyCategorySection(
          category: DutyCategory.meetingsAndBudgets,
          items: [
            DutyItem(
              titleEn: 'Officiating and Presiding in Absence of Mayor',
              titleHi: 'महापौर की अनुपस्थिति में बैठकों की अध्यक्षता एवं दायित्व निर्वहन',
              responsibilityType: ResponsibilityType.statutoryDuty,
              descriptionEn:
                  'Exercising the presiding officer powers during statutory meetings of the Corporation in the temporary absence or vacancy of the Mayor.',
              descriptionHi:
                  'महापौर के अवकाश या अनुपस्थिति के दौरान नगर निगम सदन की बैठकों की अध्यक्षता करना और सदन की कार्यवाही सुचारू रूप से संचालित करना।',
              activitiesIncludedEn:
                  'Regulating Councillor debates; recording votes on civic resolutions; forwarding minutes to the Municipal Commissioner.',
              activitiesIncludedHi:
                  'पार्षदों की बहसों का नियमन; विकास प्रस्तावों पर मतदान कराना; पारित कार्यवाहियों को आयुक्त के पास भिजवाना।',
              intendedResultEn: 'Uninterrupted governance of the municipal corporation during the Mayor absence.',
              intendedResultHi: 'मेयर की अनुपस्थिति में भी नगर निगम के विधायी और नीतिगत कार्यों का निर्बाध संचालन।',
              practicalProcessEn: 'Absence recorded -> Deputy Mayor assumes chair -> Conducts meeting -> Signs proceedings.',
              practicalProcessHi: 'अनुपस्थिति दर्ज -> डिप्टी मेयर द्वारा अध्यक्षता -> कार्यवाही संचालन -> हस्ताक्षर।',
              lineDepartmentEn: 'Municipal Corporation General Administration',
              lineDepartmentHi: 'नगर निगम सामान्य प्रशासन',
              verificationEvidenceEn: 'House Proceedings recording Deputy Mayor in chair.',
              verificationEvidenceHi: 'सदन की कार्यवाही पंजिका जिसमें डिप्टी मेयर द्वारा अध्यक्षता दर्ज हो।',
              statutoryCitation: 'The Haryana Municipal Corporation Act, 1994, Sec. 37 & 54',
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // 5. MUNICIPAL VICE-CHAIRPERSON (Municipal Council/Committee / उप-प्रधान)
  // =========================================================================
  static RepresentativeRoleProfile _buildMunicipalViceChairpersonProfile(bool isHaryana) {
    return RepresentativeRoleProfile(
      role: RepresentativeRole.municipalViceChairperson,
      isAdministrativeOfficer: false,
      titleEn: 'Municipal Vice-President / Vice-Chairperson',
      titleHi: 'उप-प्रधान / उप-चेयरपर्सन (नगर परिषद / नगर पालिका)',
      governingBodyEn: 'Municipal Council / Municipal Committee',
      governingBodyHi: 'नगर परिषद / नगर पालिका',
      constitutionalPostSummaryEn:
          'Elected by members of the municipal council/committee from amongst themselves under Section 18(2) of the Haryana Municipal Act, 1973. Presides over board meetings in the absence of the President and assists the President in coordinating civic development.',
      constitutionalPostSummaryHi:
          'हरियाणा नगर पालिका अधिनियम, 1973 की धारा 18(2) के तहत नगर परिषद/पालिका सदस्यों द्वारा अपने में से चुना गया पद। प्रधान की अनुपस्थिति में बैठकों की अध्यक्षता करना और विकास कार्यों के समन्वय में सहयोग देना।',
      legalReference: LegalSourceReference(
        sourceTitle: isHaryana
            ? 'The Haryana Municipal Act, 1973 (Haryana Act No. 24 of 1973)'
            : 'General Model Guidance (National Local Governance Framework)',
        relevantSections: isHaryana
            ? 'Sections 18(2) (Election of Vice-President), 26 (Presiding at Meetings in absence of President), 33-35 (Powers and Functions)'
            : 'Constitution of India (74th Amendment), Articles 243R & 243S',
        jurisdictionState: isHaryana ? 'Haryana' : 'General / Model Framework',
        sourceUrl: isHaryana ? 'https://ulbharyana.gov.in/the-haryana-municipal-act-1973' : 'https://legislative.gov.in/constitution-of-india',
        lastVerifiedDate: '2026-10-28',
        isStateSpecific: isHaryana,
        officialGuidanceNoteEn: isHaryana
            ? 'Statutory provisions governing Vice-Presidents under The Haryana Municipal Act, 1973.'
            : 'General Model Guidance grounded in the 74th Constitutional Amendment for municipal vice-presidents.',
        officialGuidanceNoteHi: isHaryana
            ? 'हरियाणा नगर पालिका अधिनियम, 1973 के अंतर्गत उप-प्रधान से संबंधित वैधानिक प्रावधान।'
            : 'उप-प्रधान के लिए 74वें संविधान संशोधन पर आधारित सामान्य मॉडल मार्गदर्शन।',
      ),
      legalLimitationsEn: const [
        'No direct executive, financial, or cheque-signing authority without statutory delegation.',
        'Presiding authority arises only when President is absent, incapacitated, or on leave.',
        'Executive administration and contract execution in the municipality are governed by Sections 33, 49 & 50 (joint execution by President/VP and EO/Secretary), not unilateral individual authority.',
      ],
      legalLimitationsHi: const [
        'बिना वैधानिक प्रत्यायोजन के सीधे वित्तीय या चेक जारी करने की शक्ति नहीं।',
        'बैठक की अध्यक्षता करने का अधिकार केवल प्रधान की अनुपस्थिति या अवकाश पर ही मिलता है।',
        'नगर पालिका में प्रशासनिक कार्य और अनुबंध निष्पादन धारा 33, 49 व 50 (प्रधान/उप-प्रधान और ईओ/सचिव द्वारा संयुक्त निष्पादन) के तहत होते हैं, किसी एक व्यक्ति के पास एकतरफा अधिकार नहीं है।',
      ],
      grievanceEscalationEn:
          'Ward Councillor -> Vice-President -> Municipal President -> Executive Officer / Deputy Commissioner -> Directorate of Urban Local Bodies.',
      grievanceEscalationHi:
          'वार्ड पार्षद -> उप-प्रधान -> नगर पालिका प्रधान -> कार्यकारी अधिकारी / उपायुक्त -> शहरी स्थानीय निकाय निदेशालय।',
      citizenQa: const [
        CitizenQaItem(
          questionEn: 'What power does a Municipal Vice-President have?',
          questionHi: 'नगर पालिका उप-प्रधान के क्या अधिकार होते हैं?',
          answerEn:
              'A Vice-President exercises all powers of the President during the President absence, presides over statutory meetings, and participates in standing committees overseeing civic development.',
          answerHi:
              'उप-प्रधान, प्रधान की अनुपस्थिति में सदन की बैठकों की अध्यक्षता करते हैं और सभी शक्तियों का निर्वहन करते हैं, तथा नागरिक विकास से जुड़ी उप-समितियों में भाग लेते हैं।',
        ),
      ],
      categories: const [
        DutyCategorySection(
          category: DutyCategory.meetingsAndBudgets,
          items: [
            DutyItem(
              titleEn: 'Officiating as Presiding Officer in Board Meetings',
              titleHi: 'प्रधान की अनुपस्थिति में बोर्ड बैठकों की अध्यक्षता करना',
              responsibilityType: ResponsibilityType.statutoryDuty,
              descriptionEn:
                  'Presiding over regular and special board meetings of the municipality when the President is absent, guiding debate, and recording resolutions.',
              descriptionHi:
                  'प्रधान की अनुपस्थिति में नगर परिषद/पालिका की बैठकों की अध्यक्षता करना, सदन का संचालन करना और प्रस्तावों को पारित कराना।',
              activitiesIncludedEn:
                  'Regulating member debates; putting motions to vote; signing meeting minutes in the absence of President.',
              activitiesIncludedHi:
                  'पार्षदों की बहसों का नियमन; प्रस्तावों पर मतदान; प्रधान की अनुपस्थिति में कार्यवाही पर हस्ताक्षर।',
              intendedResultEn: 'Continuity of municipal governance and decision-making on public works.',
              intendedResultHi: 'नगर पालिका के विकास कार्यों और निर्णयों का निर्बाध संचालन।',
              practicalProcessEn: 'Absence noted -> Vice-President takes chair -> Debates conducted -> Minutes forwarded to EO/Secretary.',
              practicalProcessHi: 'अनुपस्थिति दर्ज -> उप-प्रधान द्वारा अध्यक्षता -> कार्यवाही -> ईओ/सचिव को प्रेषित।',
              lineDepartmentEn: 'Municipal Administration',
              lineDepartmentHi: 'नगर पालिका प्रशासन',
              verificationEvidenceEn: 'Meeting Proceedings signed by Vice-President.',
              verificationEvidenceHi: 'उप-प्रधान द्वारा हस्ताक्षरित बैठक कार्यवाही पंजिका।',
              statutoryCitation: 'The Haryana Municipal Act, 1973, Sec. 26',
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // 6. MUNICIPAL COMMITTEE MEMBER (Sub-Committees / उप-समिति सदस्य)
  // =========================================================================
  static RepresentativeRoleProfile _buildMunicipalCommitteeMemberProfile(bool isHaryana) {
    return RepresentativeRoleProfile(
      role: RepresentativeRole.municipalCommitteeMember,
      isAdministrativeOfficer: false,
      titleEn: 'Municipal Committee / Sub-Committee Member',
      titleHi: 'नगर पालिका समिति / उप-समिति सदस्य',
      governingBodyEn: 'Municipal Council / Committee Standing Committees',
      governingBodyHi: 'नगर पालिका / नगर परिषद की स्थायी एवं उप-समितियां',
      constitutionalPostSummaryEn:
          'Member of statutory sub-committees constituted under Section 34 of the Haryana Municipal Act, 1973 (e.g., Public Works, Health & Sanitation, Finance & Taxation, Water Supply). Scrutinizes technical estimates, reviews vendor performance, and recommends proposals to the full board.',
      constitutionalPostSummaryHi:
          'हरियाणा नगर पालिका अधिनियम, 1973 की धारा 34 के तहत गठित वैधानिक उप-समितियों (जैसे लोक निर्माण, स्वास्थ्य व सफाई, वित्त व कर, जल आपूर्ति) के सदस्य। तकनीकी अनुमानों की जांच करना, कार्यों की समीक्षा करना और बोर्ड को सिफारिशें देना।',
      legalReference: LegalSourceReference(
        sourceTitle: isHaryana
            ? 'The Haryana Municipal Act, 1973 (Haryana Act No. 24 of 1973)'
            : 'General Model Guidance (National Local Governance Framework)',
        relevantSections: isHaryana
            ? 'Sections 34 (Appointment of Sub-Committees), 35 (Powers and Duties of Sub-Committees), 61-75 (Works & Sanitation Inspection)'
            : 'Constitution of India (74th Amendment), Articles 243S & 243W',
        jurisdictionState: isHaryana ? 'Haryana' : 'General / Model Framework',
        sourceUrl: isHaryana ? 'https://ulbharyana.gov.in/the-haryana-municipal-act-1973' : 'https://legislative.gov.in/constitution-of-india',
        lastVerifiedDate: '2026-10-28',
        isStateSpecific: isHaryana,
        officialGuidanceNoteEn: isHaryana
            ? 'Statutory provisions governing Sub-Committees under The Haryana Municipal Act, 1973.'
            : 'General Model Guidance grounded in the 74th Constitutional Amendment for municipal sub-committees.',
        officialGuidanceNoteHi: isHaryana
            ? 'हरियाणा नगर पालिका अधिनियम, 1973 के अंतर्गत उप-समितियों से संबंधित वैधानिक प्रावधान।'
            : 'उप-समितियों के लिए 74वें संविधान संशोधन पर आधारित सामान्य मॉडल मार्गदर्शन।',
      ),
      legalLimitationsEn: const [
        'Sub-committee decisions are recommendatory and require final confirmation by the full Municipal Board or Commissioner/EO.',
        'Members have no individual authority to award tenders, disburse payments, or alter building sanctions.',
      ],
      legalLimitationsHi: const [
        'उप-समिति के निर्णय सिफारिशी होते हैं, जिन्हें लागू करने के लिए पूरे बोर्ड या ईओ की मंजूरी आवश्यक होती है।',
        'सदस्यों को व्यक्तिगत रूप से टेंडर देने, भुगतान करने या नक्शा पास करने का अधिकार नहीं होता।',
      ],
      grievanceEscalationEn:
          'Sub-Committee Member -> Committee Chairperson -> Municipal President / EO -> Deputy Commissioner.',
      grievanceEscalationHi:
          'उप-समिति सदस्य -> समिति सभापति -> पालिका प्रधान / ईओ -> उपायुक्त।',
      citizenQa: const [
        CitizenQaItem(
          questionEn: 'What does a Municipal Sub-Committee do?',
          questionHi: 'नगर पालिका उप-समिति क्या काम करती है?',
          answerEn:
              'Sub-committees examine specialized civic topics in depth, such as sanitation contracts, streetlighting maintenance, property tax assessments, and park maintenance, making concrete recommendations before the full council votes.',
          answerHi:
              'उप-समितियां विशेषज्ञ विषयों की गहराई से जांच करती हैं, जैसे सफाई ठेके, स्ट्रीट लाइट रखरखाव, प्रॉपर्टी टैक्स और पार्कों का रख-रखाव, और पूरे बोर्ड के समक्ष ठोस सिफारिशें रखती हैं।',
        ),
      ],
      categories: const [
        DutyCategorySection(
          category: DutyCategory.publicAssets,
          items: [
            DutyItem(
              titleEn: 'Scrutiny of Civic Work Estimates and Sanitations',
              titleHi: 'नागरिक विकास अनुमानों व सफाई व्यवस्था की तकनीकी जांच',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              descriptionEn:
                  'Conducting field inspections and examining engineering estimates for municipal civil works, drain cleaning, and sanitation contracts before final board sanction.',
              descriptionHi:
                  'नगर पालिका के निर्माण कार्यों, नाला सफाई और सफाई ठेकों के तकनीकी अनुमानों की जांच और मौका मुआयना करना।',
              activitiesIncludedEn:
                  'Reviewing tender specifications; site visits to project locations; reporting deficiencies to the Executive Officer.',
              activitiesIncludedHi:
                  'टेंडर शर्तों की समीक्षा; कार्यस्थल का भौतिक निरीक्षण; कमियों को ईओ के संज्ञान में लाना।',
              intendedResultEn: 'High quality of public works and cost-efficient municipal expenditure.',
              intendedResultHi: 'सार्वजनिक निर्माण कार्यों में उच्च गुणवत्ता और जनता के धन का सदुपयोग।',
              practicalProcessEn: 'Committee inspects -> Submits evaluation report to Board -> Board acts on recommendations.',
              practicalProcessHi: 'समिति का निरीक्षण -> बोर्ड को रिपोर्ट -> बोर्ड द्वारा नियमानुसार कार्रवाई।',
              lineDepartmentEn: 'Municipal Engineering & Health Branches',
              lineDepartmentHi: 'नगर पालिका इंजीनियरिंग एवं स्वास्थ्य शाखा',
              verificationEvidenceEn: 'Sub-Committee Inspection Reports and Minutes.',
              verificationEvidenceHi: 'उप-समिति की निरीक्षण आख्या और कार्यवाही विवरण।',
              statutoryCitation: 'The Haryana Municipal Act, 1973, Sec. 33 & 34',
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // 7. MUNICIPAL COMMISSIONER (Municipal Corporation / निगमायुक्त - Administrative)
  // =========================================================================
  static RepresentativeRoleProfile _buildMunicipalCommissionerProfile(String? stateIdentifier) {
    final bool isHaryana = stateIdentifier == 'haryana';
    return RepresentativeRoleProfile(
      role: RepresentativeRole.municipalCommissioner,
      isAdministrativeOfficer: true,
      titleEn: 'Municipal Commissioner (Municipal Corporation)',
      titleHi: 'नगर निगम आयुक्त / कमिश्नर (प्रशासनिक प्रमुख)',
      governingBodyEn: 'Municipal Corporation (Nagar Nigam Administration)',
      governingBodyHi: 'नगर निगम प्रशासन (शहरी स्थानीय निकाय)',
      constitutionalPostSummaryEn:
          'Senior administrative officer (IAS) appointed by the State Government under Section 45 of the Haryana Municipal Corporation Act, 1994. Exercises the executive power of the Corporation for carrying out Act provisions under Section 49, subject to the general supervision and control of the Corporation and express statutory restrictions (including Corporation House approvals for contracts under Section 166 and budget grants under Sections 73-76 & 83).',
      constitutionalPostSummaryHi:
          'हरियाणा नगर निगम अधिनियम, 1994 की धारा 45 के तहत राज्य सरकार द्वारा नियुक्त वरिष्ठ प्रशासनिक अधिकारी (IAS)। धारा 49 के तहत निगम के सामान्य पर्यवेक्षण व नियंत्रण तथा वैधानिक सीमाओं (धारा 166 के तहत अनुबंधों हेतु सदन अनुमोदन तथा धारा 73-76 व 83 के तहत बजट सीमाओं) के अधीन रहते हुए अधिनियम के क्रियान्वयन की कार्यकारी शक्तियां निगमायुक्त में निहित हैं।',
      legalReference: LegalSourceReference(
        sourceTitle: isHaryana
            ? 'The Haryana Municipal Corporation Act, 1994 (Haryana Act No. 16 of 1994)'
            : 'General Model Guidance (National Local Governance Framework)',
        relevantSections: isHaryana
            ? 'Sections 45 (Appointment of Commissioner), 49 (Executive Power and Functions of Commissioner), 73-76 (Corporation Fund & Cheque Operations), 83 (Adoption of Budget Estimates), 165-167 (Contracts & Tenders), 250-264 (Building Plan Sanctions & Demolitions), 268-274 (Sanitation & Rubbish Removal), 400-408 (Government Control)'
            : 'Constitution of India (74th Amendment), Article 243W & State Municipal Corporation Acts',
        jurisdictionState: isHaryana ? 'Haryana' : 'General / Model Framework',
        sourceUrl: isHaryana ? 'https://ulbharyana.gov.in/the-haryana-municipal-corporation-act-1994' : 'https://legislative.gov.in/constitution-of-india',
        lastVerifiedDate: '2026-10-28',
        isStateSpecific: isHaryana,
        officialGuidanceNoteEn: isHaryana
            ? 'Statutory executive authority vested in the Municipal Commissioner under The Haryana Municipal Corporation Act, 1994.'
            : 'General Model Guidance grounded in the 74th Constitutional Amendment for municipal commissioners.',
        officialGuidanceNoteHi: isHaryana
            ? 'हरियाणा नगर निगम अधिनियम, 1994 के अंतर्गत निगमायुक्त में निहित वैधानिक कार्यकारी शक्तियां।'
            : 'नगर निगम आयुक्त के लिए 74वें संविधान संशोधन पर आधारित सामान्य मॉडल मार्गदर्शन।',
      ),
      legalLimitationsEn: const [
        'Appointed civil servant, not a political representative: Must execute the policy decisions and resolutions legally passed by the Corporation House.',
        'Executive authority under Section 49 is subject to the general supervision and control of the Corporation House; it does not override statutory approval, budget allocation, or committee sanction requirements.',
        'Contracts are subject to Section 166 (as amended by Haryana Act No. 13 of 2007): contracts exceeding ₹20 lakh require prior Corporation House approval under clause (d); contracts exceeding ₹50 lakh require prior Government approval under the proviso to Sec. 166(d). Departmental administrative approval orders (e.g. works delegations up to ₹2.5 Crore) do not amend these statutory thresholds or override prior approval requirements. Any subsequent Gazette notification formally fixing a higher statutory ceiling under the Sec. 166(d) proviso remains Verification Pending.',
        'Cannot levy new taxes or alter tax rates without legislative resolution of the House and State Government notification.',
        'Actions and orders are subject to statutory appeal and judicial review before State Appellate Authorities.',
      ],
      legalLimitationsHi: const [
        'नियुक्त प्रशासनिक अधिकारी, राजनीतिक प्रतिनिधि नहीं: निगम सदन द्वारा वैधानिक रूप से पारित प्रस्तावों और नीतियों का क्रियान्वयन करने हेतु बाध्य हैं।',
        'वैधानिक सीमा से अधिक के बड़े प्रोजेक्ट व ऋण के लिए सदन और राज्य सरकार की पूर्व मंजूरी अनिवार्य है।',
        'बिना सदन के प्रस्ताव और राज्य सरकार की अधिसूचना के नए कर लगाने या कर दरों में बदलाव करने का अधिकार नहीं।',
        'आदेशों और निर्णयों के विरुद्ध राज्य अपीलीय प्राधिकरण या अदालत में अपील की जा सकती है।',
      ],
      grievanceEscalationEn:
          'Citizen Complaint / Jan Sunwai -> Joint Commissioner / Zonal Officer -> Municipal Commissioner -> Divisional Commissioner (Appellate Authority) -> Directorate of Urban Local Bodies / Additional Chief Secretary (ULB) / CM Window.',
      grievanceEscalationHi:
          'नागरिक शिकायत / समाधान शिविर -> संयुक्त आयुक्त / जोनल अधिकारी -> नगर निगम आयुक्त (कमिश्नर) -> मंडलायुक्त (डिवीजनल कमिश्नर - अपीलीय प्राधिकारी) -> महानिदेशक, शहरी स्थानीय निकाय / अतिरिक्त मुख्य सचिव / सीएम विंडो।',
      citizenQa: const [
        CitizenQaItem(
          questionEn: 'Is the Municipal Commissioner an elected representative?',
          questionHi: 'क्या नगर निगम आयुक्त (कमिश्नर) निर्वाचित जनप्रतिनिधि होते हैं?',
          answerEn:
              'No. The Municipal Commissioner is an appointed senior civil servant (IAS/HCS officer) posted by the State Government. The Commissioner exercises full statutory executive authority, whereas the Mayor and Councillors are the elected political representatives.',
          answerHi:
              'नहीं। नगर निगम आयुक्त एक वरिष्ठ नियुक्त प्रशासनिक अधिकारी (IAS/HCS) होते हैं जिन्हें राज्य सरकार द्वारा तैनात किया जाता है। कमिश्नर के पास समस्त कार्यकारी और प्रशासनिक शक्तियां होती हैं, जबकि मेयर और पार्षद जनता द्वारा निर्वाचित प्रतिनिधि होते हैं।',
        ),
        CitizenQaItem(
          questionEn: 'Whom should I approach for building map approval or unauthorized construction complaints?',
          questionHi: 'मकान का नक्शा पास कराने या अवैध निर्माण की शिकायत के लिए किसे संपर्क करें?',
          answerEn:
              'Building plan sanction applications must be submitted online to the Municipal Corporation Town Planning Branch under the authority of the Municipal Commissioner. For unauthorized construction, complaints can be filed directly with the Joint Commissioner / Enforcement Wing or Municipal Commissioner.',
          answerHi:
              'मकान का नक्शा पास कराने हेतु नगर निगम के नगर योजना (टाउन प्लानिंग) पोर्टल पर आवेदन किया जाता है, जिसे निगमायुक्त के अधिकार क्षेत्र में स्वीकृति मिलती है। अवैध निर्माण की शिकायत संयुक्त आयुक्त, इनफोर्समेंट विंग या निगमायुक्त के पास दर्ज कराई जाती है।',
        ),
        CitizenQaItem(
          questionEn: 'Can the Commissioner overrule a resolution passed by the Mayor and Councillors?',
          questionHi: 'क्या कमिश्नर मेयर और पार्षदों द्वारा पारित प्रस्ताव को खारिज कर सकते हैं?',
          answerEn:
              'If the Commissioner believes a resolution violates the law, exceeds corporate powers, or is contrary to public interest, the Commissioner must refer it to the State Government for direction under Section 400-408 of the Haryana Municipal Corporation Act, 1994, rather than unilaterally cancelling it.',
          answerHi:
              'यदि आयुक्त को प्रतीत होता है कि कोई प्रस्ताव कानून के विरुद्ध है, निगम के अधिकार क्षेत्र से बाहर है या जनहित के खिलाफ है, तो वह इसे सीधे रद्द करने के बजाय धारा 400-408 के तहत मार्गदर्शन और निर्णय हेतु राज्य सरकार को भेजते हैं।',
        ),
      ],
      categories: const [
        DutyCategorySection(
          category: DutyCategory.publicAssets,
          items: [
            DutyItem(
              titleEn: 'Execution of Municipal Works, Tenders and Contracts',
              titleHi: 'निगम निर्माण कार्यों, निविदाओं एवं अनुबंधों का निष्पादन',
              responsibilityType: ResponsibilityType.statutoryDuty,
              descriptionEn:
                  'Inviting competitive e-tenders, sanctioning work orders, and signing binding contracts on behalf of the Municipal Corporation under Sections 165-167 (subject to prior Corporation House approval exceeding ₹20 lakh and State Government approval exceeding ₹50 lakh under Sec. 166 as amended by Haryana Act No. 13 of 2007).',
              descriptionHi:
                  'हरियाणा नगर निगम अधिनियम, 1994 की धारा 165-167 के तहत नगर निगम की ओर से ई-टेंडर आमंत्रित करने, कार्य आदेश जारी करने व अनुबंध निष्पादित करने का दायित्व (हरियाणा एक्ट 13/2007 के तहत ₹20 लाख से अधिक पर सदन अनुमोदन व ₹50 लाख से अधिक पर राज्य सरकार के अनुमोदन के अधीन)।',
              activitiesIncludedEn:
                  'Approving technical estimates; floating tenders on the state e-procurement portal; issuing work orders; signing contractor agreements.',
              activitiesIncludedHi:
                  'तकनीकी अनुमानों को प्रशासनिक स्वीकृति; सरकारी ई-प्रोक्योरमेंट पोर्टल पर टेंडर जारी करना; वर्क ऑर्डर देना; अनुबंध पत्रों पर हस्ताक्षर।',
              intendedResultEn: 'Transparent, accountable procurement and timely completion of urban roads, drains, sewerage, and streetlighting works.',
              intendedResultHi: 'पारदर्शी निविदा प्रक्रिया और शहरी सड़कों, नालों, सीवर व लाइटों का समयबद्ध व गुणवत्तापूर्ण निर्माण।',
              practicalProcessEn: 'House passes budget head -> Engineering prepares estimate -> Sanction accorded under Sec. 166 (within ₹20L; exceeding ₹20L approved by House, exceeding ₹50L approved by Govt under Sec. 166(d) proviso) -> e-tender published -> Agreement signed.',
              practicalProcessHi: 'सदन से बजट मंजूरी -> इंजीनियरिंग विंग द्वारा एस्टीमेट -> निगमायुक्त द्वारा प्रशासनिक स्वीकृति -> ई-टेंडर -> अनुबंध हस्ताक्षर।',
              lineDepartmentEn: 'Engineering Branch, Municipal Corporation',
              lineDepartmentHi: 'इंजीनियरिंग शाखा, नगर निगम',
              verificationEvidenceEn: 'Administrative Sanction Orders, e-tender notice, and signed contractor agreements.',
              verificationEvidenceHi: 'प्रशासनिक स्वीकृति आदेश, ई-टेंडर नोटिस और हस्ताक्षरित अनुबंध दस्तावेज।',
              statutoryCitation: 'The Haryana Municipal Corporation Act, 1994, Sec. 49, 165, 166 & 167',
            ),
            DutyItem(
              titleEn: 'Enforcement Against Encroachments & Building Plan Sanctions',
              titleHi: 'अतिक्रमण हटाना एवं भवन निर्माण नक्शों की वैधानिक स्वीकृति',
              responsibilityType: ResponsibilityType.statutoryDuty,
              descriptionEn:
                  'Statutory regulation of urban land development, sanctioning architectural building plans under the Haryana Building Code, issuing completion certificates, and ordering demolition or sealing of unauthorized constructions and public encroachments.',
              descriptionHi:
                  'हरियाणा भवन निर्माण संहिता के तहत मकानों/दुकानों के नक्शे स्वीकृत करना, पूर्णता प्रमाण पत्र जारी करना और अवैध निर्माण व सरकारी जमीन पर अतिक्रमण को सील या ध्वस्त करने के वैधानिक आदेश जारी करना।',
              activitiesIncludedEn:
                  'Scrutinizing building applications; conducting site inspections; issuing show-cause notices under Sec. 261/263; leading anti-encroachment enforcement drives with police support.',
              activitiesIncludedHi:
                  'नक्शा आवेदनों की तकनीकी जांच; स्थल निरीक्षण; धारा 261/263 के तहत कारण बताओ नोटिस; पुलिस बल के सहयोग से अतिक्रमण व अवैध निर्माण हटाना।',
              intendedResultEn: 'Planned urban development, fire-safety compliance, and encroachment-free public roads and footpaths.',
              intendedResultHi: 'नियोजित शहरी विकास, सुरक्षित भवन निर्माण और अतिक्रमण-मुक्त सड़कें व फुटपाथ।',
              practicalProcessEn: 'Online portal application -> DTP branch inspects -> Commissioner / Authorized officer sanctions -> Violation triggers notice and demolition order.',
              practicalProcessHi: 'पोर्टल पर ऑनलाइन आवेदन -> डीटीपी शाखा जांच -> आयुक्त/सक्षम अधिकारी द्वारा मंजूरी -> उल्लंघन पर नोटिस व सीलिंग/ध्वस्तीकरण।',
              lineDepartmentEn: 'Town Planning & Enforcement Wings, Municipal Corporation',
              lineDepartmentHi: 'नगर योजना (टाउन प्लानिंग) एवं इनफोर्समेंट शाखा, नगर निगम',
              verificationEvidenceEn: 'Sanctioned Building Plan with QR code, Sealing Orders, Demolition notices.',
              verificationEvidenceHi: 'स्वीकृत भवन नक्शा, सीलिंग व ध्वस्तीकरण आदेश पत्र।',
              statutoryCitation: 'The Haryana Municipal Corporation Act, 1994, Sec. 250, 252, 254, 261 & 264',
            ),
          ],
        ),
        DutyCategorySection(
          category: DutyCategory.meetingsAndBudgets,
          items: [
            DutyItem(
              titleEn: 'Preparation of Annual Budget Estimates and Revenue Recovery',
              titleHi: 'वार्षिक बजट अनुमान तैयार करना एवं नगर निगम राजस्व वसूली',
              responsibilityType: ResponsibilityType.statutoryDuty,
              descriptionEn:
                  'Formulating the annual municipal budget estimate for submission to the General House, managing the Municipal Fund, collecting property taxes, water-sewer user fees, trade licences, and ensuring state audit compliance.',
              descriptionHi:
                  'सदन के समक्ष वार्षिक बजट अनुमान प्रस्तुत करना, नगर निगम कोष का प्रबंधन, प्रॉपर्टी टैक्स, जल-सीवर शुल्क व लाइसेंस फीस की वसूली और राज्य ऑडिट नियमों की अनुपालना।',
              activitiesIncludedEn:
                  'Directing property tax survey and NDC verification; issuing demand notices; presenting budget estimates before the Mayor and Corporation House by Jan 15.',
              activitiesIncludedHi:
                  'प्रॉपर्टी टैक्स सर्वे व एनडीसी सत्यापन; डिमांड नोटिस जारी करना; 15 जनवरी तक सदन में वार्षिक बजट पेश करना।',
              intendedResultEn: 'Financial solvency of the Corporation and robust municipal revenues to fund city infrastructure and public services.',
              intendedResultHi: 'निगम की वित्तीय मजबूती और जनसुविधाओं व विकास कार्यों हेतु पर्याप्त राजस्व की उपलब्धता।',
              practicalProcessEn: 'Accounts wing collates receipts & liabilities -> Commissioner finalizes budget draft -> Placed before House -> Expenditure audited by Local Audit Department.',
              practicalProcessHi: 'लेखा शाखा द्वारा ड्राफ्ट तैयार -> निगमायुक्त द्वारा अंतिम रूप -> सदन में प्रस्तुति -> स्थानीय निकाय ऑडिट विभाग द्वारा जांच।',
              lineDepartmentEn: 'Accounts and Revenue Branches, Municipal Corporation',
              lineDepartmentHi: 'लेखा एवं राजस्व शाखा, नगर निगम',
              verificationEvidenceEn: 'Draft Budget Document, Treasury payment scroll, and Annual Audit Report.',
              verificationEvidenceHi: 'बजट दस्तावेज, ट्रेजरी वाउचर स्क्रॉल और वार्षिक ऑडिट रिपोर्ट।',
              statutoryCitation: 'The Haryana Municipal Corporation Act, 1994, Sec. 73-76 & 83',
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // 8. EXECUTIVE OFFICER (Municipal Council / कार्यकारी अधिकारी - Administrative)
  // =========================================================================
  static RepresentativeRoleProfile _buildExecutiveOfficerProfile(bool isHaryana) {
    return RepresentativeRoleProfile(
      role: RepresentativeRole.executiveOfficer,
      isAdministrativeOfficer: true,
      titleEn: 'Executive Officer (Municipal Council)',
      titleHi: 'कार्यकारी अधिकारी / ईओ (नगर परिषद - प्रशासनिक प्रमुख)',
      governingBodyEn: 'Municipal Council Administration (Nagar Parishad)',
      governingBodyHi: 'नगर परिषद प्रशासन (शहरी स्थानीय निकाय)',
      constitutionalPostSummaryEn:
          'Appointed state administrative officer (HCS or state municipal service) posted under Section 38 of the Haryana Municipal Act, 1973 in Municipal Councils. Exercises specific powers delegated by the committee by resolution with previous State Government sanction under Section 33; joins in contract execution exceeding Rs. 500 under Section 50; participates in building plan sanctions under Section 205; and manages municipal fund custody and disbursements under Sections 56-60 and the Haryana Municipal Account Code, 2025 (notified 20 May 2025, repealing the 1930 Code).',
      constitutionalPostSummaryHi:
          'हरियाणा नगर पालिका अधिनियम, 1973 की धारा 38 के तहत नगर परिषदों में राज्य सरकार द्वारा नियुक्त प्रशासनिक अधिकारी (HCS/राज्य नगर पालिका सेवा)। धारा 33 के तहत राज्य सरकार की पूर्व मंजूरी से सदन संकल्प द्वारा प्रत्यायोजित विशिष्ट शक्तियों का निर्वहन; धारा 50 के तहत 500 रुपये से अधिक के अनुबंधों का संयुक्त निष्पादन; धारा 205 के तहत नक्शा स्वीकृति; और धारा 56-60 व हरियाणा म्युनिसिपल अकाउंट कोड, 2025 (20 मई 2025 को अधिसूचित, 1930 कोड को निरस्त करते हुए) के तहत नगर पालिका कोष व भुगतानों का प्रबंधन करते हैं।',
      legalReference: LegalSourceReference(
        sourceTitle: isHaryana
            ? 'The Haryana Municipal Act, 1973 (Haryana Act No. 24 of 1973)'
            : 'General Model Guidance (National Local Governance Framework)',
        relevantSections: isHaryana
            ? 'Sections 33 (Delegation of Specified Powers by Resolution with Government Sanction), 35 (Extraordinary Emergency Powers), 38 (Constitution of Municipal Service), 49 (Contract Authority Delegation), 50 (Mandatory Joint Mode of Executing Contracts), 56-60 (Municipal Fund & Custody), 201, 205, 208, 208A (Building Sanctions, Demolition & Sealing), 246-250 (Control and Supervision)'
            : 'Constitution of India (74th Amendment), Article 243W & State Municipal Laws',
        jurisdictionState: isHaryana ? 'Haryana' : 'General / Model Framework',
        sourceUrl: isHaryana ? 'https://ulbharyana.gov.in/the-haryana-municipal-act-1973' : 'https://legislative.gov.in/constitution-of-india',
        lastVerifiedDate: '2026-10-28',
        isStateSpecific: isHaryana,
        officialGuidanceNoteEn: isHaryana
            ? 'Statutory executive authority vested in the Executive Officer under The Haryana Municipal Act, 1973.'
            : 'General Model Guidance grounded in the 74th Constitutional Amendment for municipal executive officers.',
        officialGuidanceNoteHi: isHaryana
            ? 'हरियाणा नगर पालिका अधिनियम, 1973 के अंतर्गत कार्यकारी अधिकारी में निहित वैधानिक कार्यकारी शक्तियां।'
            : 'कार्यकारी अधिकारी के लिए 74वें संविधान संशोधन पर आधारित सामान्य मॉडल मार्गदर्शन।',
      ),
      legalLimitationsEn: const [
        'Section 38 provides for the constitution of the Municipal Service (cadre and recruitment); it does not confer delegation of committee powers.',
        'Section 33 strictly permits delegation of specifically enumerated powers only, subject to statutory conditions and requiring previous sanction of the State Government by resolution.',
        'Section 35 is strictly an extraordinary emergency provision (applicable only during sudden events threatening human life, extensive property damage, or grave public inconvenience) requiring immediate report to the Deputy Commissioner; it is not a general source of routine executive power.',
        'Cannot execute contracts exceeding Rs. 500 unilaterally: Section 50 mandates joint execution in writing signed by two members (one of whom is President or Vice-President) and also the Executive Officer or Secretary.',
        'Budget formulation, payments, and double-entry accounting are governed by the Haryana Municipal Account Code, 2025 (notified 20 May 2025 in Gazette June 2025, repealing the 1930 Code with transitional savings) in conjunction with HMA 1973 Sections 56-60; payments must be covered by valid sanctioned budget provisions.',
      ],
      legalLimitationsHi: const [
        'नियुक्त प्रशासनिक अधिकारी, निर्वाचित नेता नहीं: निर्वाचित नगर परिषद द्वारा पारित वैधानिक प्रस्तावों का क्रियान्वयन करने के लिए बाध्य हैं।',
        'बोर्ड और शहरी स्थानीय निकाय विभाग द्वारा स्वीकृत बजट सीमाओं से बाहर जाकर फंड खर्च करने का अधिकार नहीं।',
        'नई कर दरों या नीतिगत परिवर्तनों के लिए निर्वाचित सदन और राज्य सरकार की मंजूरी जरूरी है।',
      ],
      grievanceEscalationEn:
          'Ward Councillor / Resident Complaint -> Municipal Branch Heads (ME, CSI) -> Executive Officer (EO) -> Sub-Divisional Magistrate (SDM) / Deputy Commissioner (DC) -> Directorate of Urban Local Bodies / CM Window.',
      grievanceEscalationHi:
          'वार्ड पार्षद / नागरिक शिकायत -> नगर परिषद शाखा प्रभारी (एमई, सफाई निरीक्षक) -> कार्यकारी अधिकारी (ईओ) -> एसडीएम / उपायुक्त (डीसी) -> महानिदेशक, शहरी स्थानीय निकाय / सीएम विंडो।',
      citizenQa: const [
        CitizenQaItem(
          questionEn: 'What is the role of an Executive Officer (EO) in a Municipal Council?',
          questionHi: 'नगर परिषद में कार्यकारी अधिकारी (ईओ) की क्या भूमिका है?',
          answerEn:
              'The Executive Officer is the full-time administrative head of the Municipal Council who signs cheques, awards tenders, sanctions building maps, directs sanitation staff, and executes the board resolutions passed by the President and Councillors.',
          answerHi:
              'कार्यकारी अधिकारी नगर परिषद के पूर्णकालिक प्रशासनिक मुखिया होते हैं, जो चेक पर हस्ताक्षर करते हैं, टेंडर आवंटित करते हैं, नक्शे पास करते हैं, सफाई कर्मियों पर नियंत्रण रखते हैं और सदन द्वारा पारित प्रस्तावों को धरातल पर लागू करते हैं।',
        ),
      ],
      categories: const [
        DutyCategorySection(
          category: DutyCategory.publicAssets,
          items: [
            DutyItem(
              titleEn: 'Sanction and Execution of Municipal Development Works',
              titleHi: 'नगर परिषद विकास कार्यों की स्वीकृति एवं निविदा निष्पादन',
              responsibilityType: ResponsibilityType.statutoryDuty,
              descriptionEn:
                  'Issuing administrative sanction for road paving, drainage construction, park development, and solid waste management contracts under Haryana Municipal rules.',
              descriptionHi:
                  'हरियाणा नगर पालिका नियमों के तहत सड़कों के निर्माण, नाला निर्माण, पार्क सौंदर्यीकरण और कचरा प्रबंधन के टेंडर और कार्यादेश जारी करना।',
              activitiesIncludedEn:
                  'Supervising Municipal Engineer (ME); floating e-tenders; measuring contractor works; issuing payment cheques.',
              activitiesIncludedHi:
                  'नगर पालिका अभियंता (ME) के कार्यों का पर्यवेक्षण; ई-टेंडर जारी करना; ठेकेदार के कार्यों की माप-पुस्तिका जांच; चेक जारी करना।',
              intendedResultEn: 'Timely and transparent infrastructure delivery in the municipal council jurisdiction.',
              intendedResultHi: 'नगर परिषद क्षेत्र में गुणवत्तापूर्ण और समयबद्ध बुनियादी ढांचा विकास।',
              practicalProcessEn: 'Board approves work -> ME prepares estimate -> EO accords sanction -> e-tender awarded -> Work inspected -> Cheque released.',
              practicalProcessHi: 'बोर्ड से मंजूरी -> एमई द्वारा एस्टीमेट -> ईओ द्वारा प्रशासनिक स्वीकृति -> टेंडर आवंटन -> निरीक्षण -> भुगतान।',
              lineDepartmentEn: 'Municipal Engineering Wing',
              lineDepartmentHi: 'नगर परिषद इंजीनियरिंग शाखा',
              verificationEvidenceEn: 'Work orders, MB measurement book verification, and payment vouchers.',
              verificationEvidenceHi: 'कार्यादेश (Work Order), माप-पुस्तिका (MB) सत्यापन एवं ट्रेजरी भुगतान वाउचर।',
              statutoryCitation: 'The Haryana Municipal Act, 1973, Sec. 33, 49, 50 & 56-60',
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // 9. MUNICIPAL SECRETARY (Municipal Committee / सचिव - Administrative)
  // =========================================================================
  static RepresentativeRoleProfile _buildMunicipalSecretaryProfile(bool isHaryana) {
    return RepresentativeRoleProfile(
      role: RepresentativeRole.municipalSecretary,
      isAdministrativeOfficer: true,
      titleEn: 'Municipal Secretary (Municipal Committee / Council)',
      titleHi: 'सचिव / सेक्रेटरी (नगर पालिका / परिषद - प्रशासनिक अधिकारी)',
      governingBodyEn: 'Municipal Committee / Municipal Council Administration',
      governingBodyHi: 'नगर पालिका / नगर परिषद प्रशासन',
      constitutionalPostSummaryEn:
          'Appointed municipal administrative officer under Section 38 of the Haryana Municipal Act, 1973 in Municipal Committees (and supporting councils). Acts as official custodian of municipal records and draws proceedings under Section 30, manages official correspondence, issues meeting notices under Section 25, assists in contract execution under Section 50, and maintains civic registries.',
      constitutionalPostSummaryHi:
          'हरियाणा नगर पालिका अधिनियम, 1973 की धारा 38 के तहत नगर पालिकाओं में नियुक्त प्रशासनिक अधिकारी। धारा 30 के तहत बैठक कार्यवाही व पंजिका के वैधानिक संरक्षक, धारा 25 के तहत बैठक नोटिस जारी करने वाले, धारा 50 के तहत अनुबंध निष्पादन और नागरिक पंजिकाओं के रख-रखाव हेतु उत्तरदायी।',
      legalReference: LegalSourceReference(
        sourceTitle: isHaryana
            ? 'The Haryana Municipal Act, 1973 (Haryana Act No. 24 of 1973)'
            : 'General Model Guidance (National Local Governance Framework)',
        relevantSections: isHaryana
            ? 'Sections 25 (Meetings), 30 (Record and Publication of Proceedings), 33 (Delegation of Specified Functions), 38 (Constitution of Municipal Service), 49 (Contract Authority Delegation), 50 (Mandatory Joint Mode of Executing Contracts), 56-60 (Municipal Fund Custody), 201, 205, 208, 208A (Building Applications & Sealing)'
            : 'Constitution of India (74th Amendment), Article 243W & State Municipal Laws',
        jurisdictionState: isHaryana ? 'Haryana' : 'General / Model Framework',
        sourceUrl: isHaryana ? 'https://ulbharyana.gov.in/the-haryana-municipal-act-1973' : 'https://legislative.gov.in/constitution-of-india',
        lastVerifiedDate: '2026-10-28',
        isStateSpecific: isHaryana,
        officialGuidanceNoteEn: isHaryana
            ? 'Statutory secretarial duties under The Haryana Municipal Act, 1973.'
            : 'General Model Guidance grounded in the 74th Constitutional Amendment for municipal secretaries.',
        officialGuidanceNoteHi: isHaryana
            ? 'हरियाणा नगर पालिका अधिनियम, 1973 के अंतर्गत सचिव पद से संबंधित वैधानिक प्रावधान।'
            : 'नगर पालिका सचिव के लिए 74वें संविधान संशोधन पर आधारित सामान्य मॉडल मार्गदर्शन।',
      ),
      legalLimitationsEn: const [
        'Appointed civil servant acting under supervision of Executive Officer/President and Deputy Commissioner.',
        'Cannot alter board resolutions or approve unbudgeted expenditures without authority.',
      ],
      legalLimitationsHi: const [
        'कार्यकारी अधिकारी/प्रधान व उपायुक्त के पर्यवेक्षण में कार्य करने वाले नियुक्त प्रशासनिक अधिकारी।',
        'बोर्ड के प्रस्तावों में मनमाना फेरबदल करने या बिना बजट खर्च स्वीकृत करने का अधिकार नहीं।',
      ],
      grievanceEscalationEn:
          'Ward Councillor / Resident -> Municipal Secretary -> Executive Officer / President -> Sub-Divisional Magistrate / Deputy Commissioner.',
      grievanceEscalationHi:
          'वार्ड पार्षद / नागरिक -> नगर पालिका सचिव -> कार्यकारी अधिकारी / प्रधान -> एसडीएम / उपायुक्त।',
      citizenQa: const [
        CitizenQaItem(
          questionEn: 'What is the function of the Municipal Secretary?',
          questionHi: 'नगर पालिका सचिव (सेक्रेटरी) का क्या कार्य होता है?',
          answerEn:
              'The Municipal Secretary maintains the official records of all board proceedings, issues certified copies of municipal resolutions, supervises birth/death registrations and trade licenses, and manages day-to-day office administration in Municipal Committees.',
          answerHi:
              'नगर पालिका सचिव सदन की सभी बैठकों का आधिकारिक रिकॉर्ड रखते हैं, प्रस्तावों की प्रमाणित प्रतियां देते हैं, जन्म-मृत्यु पंजीकरण व ट्रेड लाइसेंस की देखरेख करते हैं और पालिका कार्यालय का प्रशासनिक कार्य संभालते हैं।',
        ),
      ],
      categories: const [
        DutyCategorySection(
          category: DutyCategory.meetingsAndBudgets,
          items: [
            DutyItem(
              titleEn: 'Maintenance of Board Proceedings and Official Records',
              titleHi: 'सदन की कार्यवाही पंजिका एवं आधिकारिक रिकॉर्ड का वैधानिक रख-रखाव',
              responsibilityType: ResponsibilityType.statutoryDuty,
              descriptionEn:
                  'Issuing statutory notices for municipal meetings, accurately drafting and recording meeting minutes, obtaining presidential confirmation, and maintaining safe custody of municipal records under Section 30 of HMA 1973.',
              descriptionHi:
                  'हरियाणा नगर पालिका अधिनियम, 1973 की धारा 30 के अनुसार बैठकों के वैधानिक नोटिस जारी करना, कार्यवाही विवरण (मिनट्स) तैयार करना, प्रधान के हस्ताक्षर कराना और रिकॉर्ड का सुरक्षित रख-रखाव करना।',
              activitiesIncludedEn:
                  'Circulating agendas to Ward Councillors; recording attendance and resolutions; issuing certified copies to citizens and government authorities.',
              activitiesIncludedHi:
                  'पार्षदों को एजेंडा प्रेषित करना; उपस्थिति व प्रस्ताव दर्ज करना; नागरिकों व अधिकारियों को प्रमाणित प्रतियां उपलब्ध कराना।',
              intendedResultEn: 'Authentic, legally defensible, and transparent municipal records of all civic decisions.',
              intendedResultHi: 'सभी नागरिक निर्णयों का प्रामाणिक, पारदर्शी और वैधानिक रिकॉर्ड।',
              practicalProcessEn: 'Meeting convened -> Minutes drafted -> Signed by Presiding Officer -> Entered into permanent register -> Copy sent to DC.',
              practicalProcessHi: 'बैठक -> मिनट्स ड्राफ्ट -> पीठासीन अधिकारी के हस्ताक्षर -> स्थायी रजिस्टर में प्रविष्टि -> उपायुक्त को प्रतिलिपि।',
              lineDepartmentEn: 'Municipal Administration Branch',
              lineDepartmentHi: 'नगर पालिका प्रशासनिक शाखा',
              verificationEvidenceEn: 'Official Municipal Proceedings Register and DC dispatch confirmation.',
              verificationEvidenceHi: 'आधिकारिक नगर पालिका कार्यवाही पंजिका और उपायुक्त कार्यालय प्रेषण रसीद।',
              statutoryCitation: 'The Haryana Municipal Act, 1973, Sec. 25 & 30',
            ),
          ],
        ),
      ],
    );
  }


  // =========================================================================
  // MEMBER OF LEGISLATIVE ASSEMBLY (MLA / विधायक)
  // =========================================================================
  static RepresentativeRoleProfile _buildMlaProfile(String? stateIdentifier) {
    final bool isHaryana = stateIdentifier == 'haryana';
    final bool isRajasthan = stateIdentifier == 'rajasthan';
    final bool isStateSpecific = isHaryana || isRajasthan;

    final String governingBodyEn = isHaryana
        ? 'Haryana Legislative Assembly (Vidhan Sabha), Chandigarh'
        : (isRajasthan
            ? 'Rajasthan Legislative Assembly (Vidhan Sabha), Jaipur'
            : 'State Legislative Assembly (Vidhan Sabha)');

    final String governingBodyHi = isHaryana
        ? 'हरियाणा विधान सभा, चंडीगढ़'
        : (isRajasthan
            ? 'राजस्थान विधान सभा, जयपुर'
            : 'राज्य विधान सभा (विधान मंडल)');

    final String sourceTitle = isHaryana
        ? 'Constitution of India (Part VI, Arts. 168-212) & Rules of Procedure of Haryana Vidhan Sabha'
        : (isRajasthan
            ? 'Constitution of India (Part VI, Arts. 168-212) & Rules of Procedure of Rajasthan Vidhan Sabha'
            : 'General Model Guidance (Constitution of India, Part VI - The States)');

    final String relevantSections = isHaryana
        ? 'Arts. 168, 174, 194, 196-201, 202-207; Rules of Procedure of Haryana Vidhan Sabha (Ch. VIII, XI, XIV); GoH Rural Development Dept VANGY Guidelines'
        : (isRajasthan
            ? 'Arts. 168, 174, 194, 196-201, 202-207; Rules of Procedure of Rajasthan Vidhan Sabha (Ch. VIII, XIII); GoR MLA-LAD Scheme Guidelines 2023 & Economic Review 2024-25'
            : 'Articles 168-212 (State Legislature, Legislative Powers, Financial Procedures, Privileges & Immunities)');

    final String jurisdictionState = isHaryana
        ? 'Haryana'
        : (isRajasthan ? 'Rajasthan' : 'General / Model Framework');

    final String sourceUrl = isHaryana
        ? 'https://haryanarural.gov.in'
        : (isRajasthan ? 'https://assembly.rajasthan.gov.in' : 'https://legislative.gov.in/constitution-of-india');

    final String officialGuidanceNoteEn = isHaryana
        ? 'Statutory legislative powers and assembly rules under Haryana Vidhan Sabha; constituency development under Haryana Rural Development Department Vidhayak Adarsh Nagar Avam Gram Yojana (VANGY) verified at Rs 2 Crore/year per constituency (population slabs: Rs 2 Cr for >10,000, Rs 1 Cr for 5,000-10,000, Rs 50 Lakh for <5,000; periodic Rs 5 Cr announcements remain pending gazetted verification).'
        : (isRajasthan
            ? 'Statutory legislative powers under Rajasthan Vidhan Sabha; constituency development under Rajasthan Vidhayak Sthaniya Kshetra Vikas Yojana (MLA-LAD Scheme - Rs 5 Cr/year with mandatory min. 20% SC/ST quota) supported by State Scheme Guidelines 2023 and Rajasthan Economic Review 2024-25.'
            : 'General Model Guidance grounded in Constitutional provisions (Articles 168-212). Specific state-level Assembly Rules of Procedure and MLALAD funding rules for this state have not yet been independently verified in the app database; consult the respective State Vidhan Sabha Secretariat and State Planning Department for local funding limits and Standing Committee procedures.');

    final String officialGuidanceNoteHi = isHaryana
        ? 'हरियाणा विधान सभा के तहत विधायी शक्तियां व कार्य संचालन नियम; ग्रामीण विकास विभाग हरियाणा की विधायक आदर्श नगर एवं ग्राम योजना (VANGY) के तहत रु 2 करोड़ प्रति विधान सभा क्षेत्र सत्यापित (जनसंख्या सीमाएं: 10,000 से अधिक पर रु 2 करोड़, 5,000-10,000 पर रु 1 करोड़, 5,000 तक पर रु 50 लाख; रु 5 करोड़ के दावे अपुष्ट बजट घोषणा हैं)।'
        : (isRajasthan
            ? 'राजस्थान विधान सभा कार्य संचालन नियम व ग्रामीण विकास विभाग की विधायक स्थानीय क्षेत्र विकास योजना (MLA-LAD - रु 5 करोड़ वार्षिक, न्यूनतम 20% अनिवार्य एससी/एसटी कोटा) योजना दिशा-निर्देश 2023 व राजस्थान आर्थिक समीक्षा 2024-25 द्वारा पुष्ट।'
            : 'भारत के संविधान (अनुच्छेद 168-212) पर आधारित सामान्य मॉडल मार्गदर्शन। इस राज्य के लिए विधान सभा प्रक्रिया नियम व विधायक निधि की विशिष्ट नियमावली अभी ऐप डेटाबेस में सत्यापित नहीं है; स्थानीय वित्तीय सीमाओं व समिति प्रक्रियाओं के लिए संबंधित राज्य विधान सभा सचिवालय का संदर्भ लें।');

    final String statusLabelEn = isStateSpecific ? 'Officially Verified Law' : 'General Guidance (State Verification Pending)';
    final String statusLabelHi = isStateSpecific ? 'आधिकारिक सत्यापित कानून' : 'सामान्य मार्गदर्शन (राज्य सत्यापन लंबित)';

    return RepresentativeRoleProfile(
      role: RepresentativeRole.mla,
      titleEn: isHaryana
          ? 'Member of Legislative Assembly (MLA) - Haryana'
          : (isRajasthan
              ? 'Member of Legislative Assembly (MLA) - Rajasthan'
              : 'Member of Legislative Assembly (MLA)'),
      titleHi: isHaryana
          ? 'विधायक (विधान सभा सदस्य - हरियाणा)'
          : (isRajasthan
              ? 'विधायक (विधान सभा सदस्य - राजस्थान)'
              : 'विधायक (विधान सभा सदस्य - MLA)'),
      governingBodyEn: governingBodyEn,
      governingBodyHi: governingBodyHi,
      constitutionalPostSummaryEn:
          'Elected representative of the state legislative assembly constituency under Article 168 & 170 of the Constitution of India. Primary constitutional duties include enacting state laws on State and Concurrent List subjects, scrutinizing and voting on the Annual State Budget and Demands for Grants, holding the Council of Ministers accountable during Question Hour and through legislative committees, recommending constituency capital works under the state MLA Local Area Development Scheme, and representing citizens before the executive bureaucracy.',
      constitutionalPostSummaryHi:
          'भारत के संविधान के अनुच्छेद 168 व 170 के अंतर्गत विधान सभा निर्वाचन क्षेत्र से सीधे निर्वाचित प्रतिनिधि। मुख्य संवैधानिक दायित्वों में राज्य व समवर्ती सूची पर राज्य के कानून बनाना, वार्षिक राज्य बजट व अनुदान मांगों पर चर्चा व मतदान करना, प्रश्नकाल व विधान सभा समितियों के माध्यम से मंत्रिपरिषद की जवाबदेही तय करना, विधायक स्थानीय क्षेत्र विकास योजना के तहत सार्वजनिक विकास कार्यों की अनुशंसा करना और प्रशासनिक तंत्र के समक्ष जनता की समस्याओं का प्रतिनिधित्व करना शामिल है।',
      legalReference: LegalSourceReference(
        sourceTitle: sourceTitle,
        relevantSections: relevantSections,
        jurisdictionState: jurisdictionState,
        sourceUrl: sourceUrl,
        lastVerifiedDate: '2026-10-26',
        isStateSpecific: isStateSpecific,
        officialGuidanceNoteEn: officialGuidanceNoteEn,
        officialGuidanceNoteHi: officialGuidanceNoteHi,
      ),
      citizenQa: [
        const CitizenQaItem(
          questionEn: 'What is the primary constitutional role of an MLA?',
          questionHi: 'विधायक (MLA) का मुख्य संवैधानिक कार्य क्या है?',
          answerEn:
              'An MLA is first and foremost a state lawmaker and member of the legislature. Their primary constitutional duties are to debate, amend, and enact state laws on State and Concurrent subjects, scrutinize and vote on state taxes and the annual state budget, hold government departments accountable during Assembly Question Hour, and table public concerns before the House. Recommending constituency development works is a secondary policy scheme, not an executive command.',
          answerHi:
              'विधायक मूल रूप से राज्य के कानून निर्माता (lawmaker) और विधान मंडल के सदस्य होते हैं। उनका मुख्य संवैधानिक कार्य राज्य व समवर्ती सूची के विषयों पर कानून बनाना, राज्य के बजट व कर प्रस्तावों पर चर्चा व मतदान करना, प्रश्नकाल में मंत्रियों से जवाब मांगना और सदन में जनहित के मुद्दे उठाना है। विधायक निधि से विकास कार्यों की सिफारिश करना एक सहायक योजना है, न कि कोई कार्यकारी प्रशासनिक आदेश।',
        ),
        CitizenQaItem(
          questionEn: 'What is the MLA Development Fund (MLALADS) and can an MLA award tenders or cheques directly?',
          questionHi: 'विधायक निधि (MLALAD Scheme) क्या है और क्या विधायक सीधे टेंडर या चेक जारी कर सकते हैं?',
          answerEn: isHaryana
              ? 'NO. Under the official Government of Haryana Rural Development Department guidelines for the Vidhayak Adarsh Nagar Avam Gram Yojana (VANGY), an MLA has an authorized constituency development allocation of Rs 2 Crore per annum (subject to population-based village ceilings: Rs 2 Crore for villages >10,000, Rs 1 Crore for 5,000–10,000, and Rs 50 Lakh for up to 5,000 population; announcements proposing Rs 5 Crore remain pending a published scheme order). The MLA CANNOT issue tenders, select private contractors, or disburse funds directly. Administrative sanction is issued by the Deputy Commissioner (DC) and works are executed by government engineering wings (Panchayati Raj, PWD, PHED).'
              : (isRajasthan
                  ? 'NO. Under the Rajasthan Vidhayak Sthaniya Kshetra Vikas Yojana (MLA-LAD Scheme), each MLA can recommend eligible works up to Rs 5 Crore per year (with mandatory 20% allocation for SC/ST areas, verified in Scheme Guidelines and Rajasthan Economic Review). An MLA CANNOT issue tenders, sign cheques, or directly hire contractors. Administrative sanction is strictly issued by the District Collector through the Zila Parishad, and execution is handled by authorized government line departments and Gram Panchayats.'
                  : 'NO. Under state MLA Local Area Development schemes (allocations typically Rs 2 to 5 Crore per annum depending on state policy), an MLA possesses only RECOMMENDATORY powers for eligible community assets. An MLA CANNOT award tenders, execute contracts, or disburse payments directly. Sanction is strictly granted by the District Magistrate / Collector and executed by government engineering departments under public finance rules.'),
          answerHi: isHaryana
              ? 'नहीं। ग्रामीण विकास विभाग, हरियाणा के आधिकारिक दिशा-निर्देशों के अनुसार विधायक आदर्श नगर एवं ग्राम योजना (VANGY) के अंतर्गत प्रत्येक विधान सभा क्षेत्र के लिए रु 2 करोड़ वार्षिक का प्रावधान है (ग्राम जनसंख्या के आधार पर सीमा: 10,000 से अधिक पर रु 2 करोड़, 5,000-10,000 पर रु 1 करोड़, तथा 5,000 तक पर रु 50 लाख; रु 5 करोड़ की बजट घोषणाएं अभी औपचारिक गजट आदेश सत्यापन हेतु लंबित हैं)। विधायक केवल पात्र विकास कार्यों की सिफारिश कर सकते हैं; वे सीधे टेंडर नहीं निकाल सकते, ठेकेदार नहीं चुन सकते और न ही चेक काट सकते हैं। प्रशासनिक स्वीकृति उपायुक्त द्वारा दी जाती है और निर्माण सरकारी तकनीकी विंग द्वारा कराया जाता है।'
              : (isRajasthan
                  ? 'नहीं। राजस्थान विधायक स्थानीय क्षेत्र विकास योजना (MLA-LAD) के तहत विधायक प्रतिवर्ष रु 5 करोड़ तक के विकास कार्यों की अनुशंसा कर सकते हैं (जिसमें न्यूनतम 20% राशि एससी/एसटी विकास हेतु अनिवार्य है, जैसा कि योजना नियमों व राजस्थान आर्थिक समीक्षा में पुष्ट है)। विधायक सीधे टेंडर जारी नहीं कर सकते, चेक नहीं काट सकते और न ही निजी फर्म को ठेका दे सकते हैं। प्रशासनिक स्वीकृति जिला कलेक्टर द्वारा दी जाती है और क्रियान्वयन संबंधित सरकारी विभागों द्वारा किया जाता है।'
                  : 'नहीं। राज्य विधायक स्थानीय क्षेत्र विकास योजनाओं में विधायक के पास केवल पात्र सामुदायिक संपत्तियों की सिफारिश (recommendation) का अधिकार होता है। विधायक सीधे टेंडर जारी नहीं कर सकते, ठेके नहीं दे सकते और न ही सरकारी खजाने से सीधे भुगतान कर सकते हैं। प्रशासनिक व वित्तीय स्वीकृति जिला कलेक्टर/मजिस्ट्रेट द्वारा दी जाती है और निर्माण कार्य सरकारी तकनीकी विंग द्वारा किया जाता है।'),
        ),
        const CitizenQaItem(
          questionEn: 'Can an MLA direct police officers to register, alter, or dismiss an FIR?',
          questionHi: 'क्या विधायक पुलिस को किसी मामले में एफआईआर दर्ज करने या रद्द करने का आदेश दे सकते हैं?',
          answerEn:
              'NO. Criminal investigation is an independent statutory executive power vested strictly in the police under the Code of Criminal Procedure (CrPC) / Bharatiya Nagarik Suraksha Sanhita (BNSS). An MLA has no constitutional authority to dictate police investigations, demand registration of biased FIRs, or dismiss criminal charges. Quashing an FIR is solely within the jurisdiction of the High Court under Section 482 CrPC / Section 528 BNSS.',
          answerHi:
              'नहीं। आपराधिक मामलों की जांच दंड प्रक्रिया संहिता (CrPC) / भारतीय नागरिक सुरक्षा संहिता (BNSS) के तहत पुलिस का स्वतंत्र वैधानिक अधिकार है। विधायक के पास किसी पुलिस अधिकारी को जांच प्रभावित करने, मनमानी एफआईआर दर्ज करने या किसी पर दर्ज एफआईआर को रद्द करने का कोई कानूनी अधिकार नहीं है। एफआईआर रद्द करने का अधिकार केवल उच्च न्यायालय के पास सुरक्षित है।',
        ),
        const CitizenQaItem(
          questionEn: 'Can an MLA suspend, transfer, or penalize government doctors, engineers, or teachers?',
          questionHi: 'क्या विधायक सरकारी डॉक्टरों, इंजीनियरों, पटवारियों या अध्यापकों को निलंबित या स्थानांतरित कर सकते हैं?',
          answerEn:
              'NO. An MLA is a legislator, not an appointing or disciplinary executive authority. Civil servants and police officers operate under the State Civil Services (Classification, Control and Appeal) Rules. Only the competent administrative authority (Departmental Secretary, Director, or District Head) can initiate disciplinary action, suspension, or transfer. An MLA can only write a recommendatory representation or raise an administrative grievance before the Minister in the Assembly.',
          answerHi:
              'नहीं। विधायक कानून निर्माता हैं, प्रशासनिक नियोक्ता नहीं। सरकारी कर्मचारी और पुलिस अधिकारी राज्य नागरिक सेवा (वर्गीकरण, नियंत्रण एवं अपील) नियमों के तहत कार्य करते हैं। किसी भी कर्मचारी का निलंबन, तबादला या विभागीय जांच केवल सक्षम प्रशासनिक प्राधिकारी (विभागीय सचिव, निदेशक या विभागाध्यक्ष) द्वारा ही की जा सकती है। विधायक केवल संबंधित मंत्री को शिकायत भेज सकते हैं या सदन में प्रश्न उठा सकते हैं।',
        ),
        const CitizenQaItem(
          questionEn: 'How can citizens and village delegations approach their MLA for collective constituency issues?',
          questionHi: 'नागरिक व ग्राम प्रतिनिधिमंडल अपने क्षेत्र की सामूहिक समस्याओं के लिए विधायक से कैसे संपर्क कर सकते हैं?',
          answerEn:
              'Citizens can meet the MLA at their designated constituency office during public grievance hearings, submit written memorandums on behalf of village/ward delegations, and request inclusion of local connecting roads or water works under the constituency development plan. For chronic state-level policy failures or stalled departmental projects, citizens can also submit formal petitions to the Committee on Petitions of the State Legislative Assembly.',
          answerHi:
              'नागरिक अपने निर्वाचन क्षेत्र के विधायक कार्यालय में जनसुनवाई के समय मिल सकते हैं, ग्राम/वार्ड प्रतिनिधिमंडल के माध्यम से सामूहिक मांग-पत्र प्रस्तुत कर सकते हैं और विधायक निधि में सड़क, पेयजल या सामुदायिक केंद्र की अनुशंसा का अनुरोध कर सकते हैं। बड़े नीतिगत मामलों या लंबे समय से लंबित परियोजनाओं के लिए नागरिक राज्य विधान सभा की याचिका समिति (Committee on Petitions) को भी औपचारिक याचिका भेज सकते हैं।',
        ),
      ],
      legalLimitationsEn: const [
        'Has NO direct administrative or executive authority to sanction or award public tenders, deploy public works contractors, or disburse public funds directly from treasuries.',
        'Cannot order police officers to register, alter, or dismiss criminal FIRs; criminal investigation is an independent statutory duty under CrPC / BNSS.',
        'Possesses NO judicial or magisterial authority to adjudicate land ownership, property partition, boundary disputes, or civil/criminal court trials.',
        'Cannot unilaterally transfer, suspend, or penalize civil servants (doctors, engineers, patwaris, police officers, teachers); disciplinary powers belong exclusively to appointing authorities under State Civil Services Rules.',
        'Cannot order Gram Panchayats, Panchayat Samitis, Zila Parishads, or Municipalities to cancel duly passed resolutions or issue building permits; local self-government is constitutionally autonomous under Parts IX & IXA.',
        'MLALADS / Vidhayak Nidhi recommendations are strictly subject to technical feasibility, administrative approval by the District Collector, and state public finance rules; MLAs cannot bypass public procurement guidelines.',
      ],
      legalLimitationsHi: const [
        'सीधे सरकारी टेंडर जारी करने, ठेके स्वीकृत करने या सरकारी खजाने से सीधे चेक काटने या धनराशि बांटने का कोई कार्यकारी अधिकार नहीं है।',
        'पुलिस को किसी मामले में एफआईआर दर्ज करने, बदलने या रद्द करने का सीधा आदेश नहीं दे सकते; आपराधिक जांच कानून के तहत पुलिस का स्वतंत्र वैधानिक कार्य है।',
        'जमीन की मलकियत, सीमा विवाद, दीवानी मामलों या आपराधिक मुकदमों में फैसला सुनाने का कोई न्यायिक या पुलिस अधिकार नहीं है।',
        'सरकारी कर्मचारियों (डॉक्टर, इंजीनियर, पटवारी, शिक्षक, पुलिस आदि) को सीधे निलंबित, दंडित या स्थानांतरित करने का अधिकार नहीं है; यह अधिकार केवल सक्षम प्रशासनिक प्राधिकारियों के पास सुरक्षित है।',
        'ग्राम पंचायतों, पंचायत समितियों, जिला परिषदों या नगर पालिकाओं द्वारा विधिवत पारित प्रस्तावों को सीधे रद्द करने या निर्माण स्वीकृतियां देने का अधिकार नहीं है (संविधान के भाग IX व IXA के तहत स्थानीय निकाय स्वायत्त हैं)।',
        'विधायक निधि (MLALAD) की सिफारिशें तकनीकी व्यवहार्यता, जिला कलेक्टर की प्रशासनिक मंजूरी व वित्तीय नियमों के अधीन होती हैं; विधायक वित्तीय नियमों का उल्लंघन नहीं कर सकते।',
      ],
      grievanceEscalationEn: isHaryana
          ? 'Constituency Level: MLA Public Hearing -> District Level: Deputy Commissioner / District Planning Committee -> Legislative Level: Vidhan Sabha Questions, Calling Attention & Committee on Petitions -> Speaker, Haryana Legislative Assembly -> State Level: Lokayukta Haryana -> CM Window Haryana / High Court of Punjab and Haryana.'
          : (isRajasthan
              ? 'Constituency Level: MLA Public Hearing -> District Level: District Collector / Zila Parishad -> Legislative Level: Vidhan Sabha Questions & Committee on Petitions -> Speaker, Rajasthan Legislative Assembly -> State Level: Rajasthan Sampark Portal (181) / Lokayukta Rajasthan -> Rajasthan High Court.'
              : 'Constituency Level: MLA Public Hearing -> District Level: District Magistrate / Collector -> Legislative Level: State Vidhan Sabha Questions & Committee on Petitions -> Speaker, State Legislative Assembly -> State Level: State Lokayukta / High Court.'),
      grievanceEscalationHi: isHaryana
          ? 'क्षेत्र स्तर: विधायक जनसुनवाई -> जिला स्तर: उपायुक्त / जिला योजना समिति -> विधायी स्तर: विधान सभा प्रश्न, ध्यानाकर्षण व याचिका समिति -> अध्यक्ष, हरियाणा विधान सभा -> राज्य स्तर: लोकायुक्त हरियाणा -> सीएम विंडो हरियाणा / पंजाब एवं हरियाणा उच्च न्यायालय।'
          : (isRajasthan
              ? 'क्षेत्र स्तर: विधायक जनसुनवाई -> जिला स्तर: जिला कलेक्टर / जिला परिषद -> विधायी स्तर: विधान सभा प्रश्न व याचिका समिति -> अध्यक्ष, राजस्थान विधान सभा -> राज्य स्तर: राजस्थान संपर्क पोर्टल (181) / लोकायुक्त राजस्थान -> राजस्थान उच्च न्यायालय।'
              : 'क्षेत्र स्तर: विधायक जनसुनवाई -> जिला स्तर: जिलाधिकारी / कलेक्टर -> विधायी स्तर: राज्य विधान सभा प्रश्न व याचिका समिति -> अध्यक्ष, राज्य विधान सभा -> राज्य स्तर: राज्य लोकायुक्त / उच्च न्यायालय।'),
      categories: [
        // ==========================================
        // 1. Legislative Duties & Lawmaking Powers
        // ==========================================
        DutyCategorySection(
          category: DutyCategory.meetingsAndBudgets,
          customTitleEn: 'Legislative Duties & Lawmaking Powers',
          customTitleHi: 'विधायी कार्य, कानून निर्माण व संवैधानिक शक्तियां',
          items: [
            DutyItem(
              titleEn: 'Enacting State Legislation on State & Concurrent Lists',
              titleHi: 'राज्य व समवर्ती सूची पर राज्य कानून निर्माण',
              descriptionEn:
                  'Debate, introduce amendments, and vote on all legislative bills concerning agriculture, public health, local government, police, land revenue, and civil rights under List II (State List) and List III (Concurrent List) of the Seventh Schedule.',
              descriptionHi:
                  'सातवीं अनुसूची की राज्य सूची (सूची II) व समवर्ती सूची (सूची III) के अंतर्गत कृषि, जनस्वास्थ्य, स्थानीय स्वशासन, पुलिस, भूमि व नागरिक अधिकारों से संबंधित विधेयकों पर बहस करना, संशोधन पेश करना और मतदान करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'Cannot legislate on Union List subjects (defense, foreign affairs, banking, railways) or enact laws repugnant to Central legislation on Concurrent subjects without Presidential assent.',
              limitationHi:
                  'संघ सूची (रक्षा, विदेश, बैंकिंग, रेलवे आदि) पर कानून नहीं बना सकते; समवर्ती सूची पर केंद्र के कानून के विपरीत राज्य कानून राष्ट्रपति की सहमति (अनुच्छेद 254(2)) के बिना मान्य नहीं होता।',
              lineDepartmentEn: 'Law & Legislative Affairs Department / Legislative Assembly Secretariat',
              lineDepartmentHi: 'विधि एवं विधायी कार्य विभाग / विधान सभा सचिवालय',
              procedureOrApprovalEn: 'Introduced in Vidhan Sabha -> Three Readings -> Passed by majority -> Assent of the Governor (Art. 200) / President (Art. 201).',
              procedureOrApprovalHi: 'विधान सभा में पेश -> तीन वाचन -> बहुमत से पारित -> राज्यपाल (अनुच्छेद 200) / राष्ट्रपति (अनुच्छेद 201) की स्वीकृति।',
              jurisdictionScopeEn: 'State-wide Jurisdiction',
              jurisdictionScopeHi: 'राज्य स्तरीय अधिकार क्षेत्र',
              verificationStatusEn: statusLabelEn,
              verificationStatusHi: statusLabelHi,
              statutoryCitation: 'Constitution of India, Articles 196-201, 246, Seventh Schedule',
            ),
            DutyItem(
              titleEn: 'Introduction & Deliberation of Private Member Bills & Resolutions',
              titleHi: 'गैर-सरकारी विधेयक व संकल्प प्रस्तुत करना',
              descriptionEn:
                  'Table Private Member Bills and non-official resolutions on designated legislative sitting days (usually Fridays) to advocate for new social welfare policies, agrarian protections, or legal reforms.',
              descriptionHi:
                  'विधान सभा में निर्धारित दिनों (प्रायः शुक्रवार) पर जनहित के नए विषयों, सामाजिक सुरक्षा व कृषि सुधारों पर गैर-सरकारी विधेयक व संकल्प पेश करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'Cannot introduce Private Member Money Bills or bills imposing taxation without the prior recommendation of the Governor (Article 207).',
              limitationHi:
                  'राज्यपाल की पूर्व सिफारिश के बिना कर लगाने या सरकारी खर्च से जुड़ा कोई गैर-सरकारी धन विधेयक पेश नहीं किया जा सकता (अनुच्छेद 207)।',
              lineDepartmentEn: 'Legislative Assembly Secretariat',
              lineDepartmentHi: 'विधान सभा सचिवालय',
              procedureOrApprovalEn: 'Ballot admission by the Speaker under House Rules + Governor recommendation if public expenditure is involved.',
              procedureOrApprovalHi: 'विधान सभा प्रक्रिया नियमों के तहत अध्यक्ष द्वारा मतपत्र व स्वीकृति + खर्च होने पर राज्यपाल की पूर्व अनुशंसा।',
              jurisdictionScopeEn: 'State Legislature',
              jurisdictionScopeHi: 'राज्य विधान मंडल',
              verificationStatusEn: statusLabelEn,
              verificationStatusHi: statusLabelHi,
              statutoryCitation: isHaryana
                  ? 'Rules of Procedure and Conduct of Business in the Haryana Legislative Assembly, Chapter XIV; Art. 207'
                  : (isRajasthan
                      ? 'Rules of Procedure and Conduct of Business in the Rajasthan Legislative Assembly, Chapter XIV; Art. 207'
                      : 'Constitution of India, Article 207; State Legislative Assembly Rules'),
            ),
          ],
        ),

        // ==========================================
        // 2. Budget, Taxation & Financial Oversight
        // ==========================================
        DutyCategorySection(
          category: DutyCategory.publicAssets,
          customTitleEn: 'Budget, Taxation & Financial Oversight',
          customTitleHi: 'राज्य बजट, कराधान व वित्तीय नियंत्रण',
          items: [
            DutyItem(
              titleEn: 'Scrutinizing & Voting on Annual State Budget (Demands for Grants)',
              titleHi: 'वार्षिक राज्य बजट व अनुदान मांगों की समीक्षा व मतदान',
              descriptionEn:
                  'Examine the Annual Financial Statement (Budget) presented under Article 202, debate departmental budget allocations (education, healthcare, irrigation, roads), move cut motions (Policy, Economy, Token), and vote to pass Demands for Grants under Article 203.',
              descriptionHi:
                  'अनुच्छेद 202 के तहत प्रस्तुत वार्षिक वित्तीय विवरण (बजट) की समीक्षा करना, शिक्षा, स्वास्थ्य, सिंचाई व सड़कों के विभागीय बजट पर बहस करना, कटौती प्रस्ताव पेश करना और अनुदान मांगों पर मतदान करना (अनुच्छेद 203)।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'MLAs cannot move amendments to increase expenditure grants beyond the Governor recommendation; cannot unilaterally reallocate budgetary provisions between departments.',
              limitationHi:
                  'राज्यपाल की सिफारिश के बिना अनुदान राशि में बढ़ोतरी का प्रस्ताव नहीं रख सकते; विभागों के बीच बजट राशि का मनमाना फेरबदल नहीं कर सकते।',
              lineDepartmentEn: 'Finance Department & State Legislature Secretariat',
              lineDepartmentHi: 'वित्त विभाग एवं विधान सभा सचिवालय',
              procedureOrApprovalEn: 'General Budget Debate -> Departmental Standing Committee Scrutiny -> Voting on Demands for Grants in Assembly.',
              procedureOrApprovalHi: 'सामान्य बजट बहस -> विभागीय स्थायी समिति समीक्षा -> विधान सभा में अनुदान मांगों पर मतदान।',
              jurisdictionScopeEn: 'State Financial Jurisdiction',
              jurisdictionScopeHi: 'राज्य वित्तीय अधिकार क्षेत्र',
              verificationStatusEn: statusLabelEn,
              verificationStatusHi: statusLabelHi,
              statutoryCitation: 'Constitution of India, Articles 202, 203, 205',
            ),
            DutyItem(
              titleEn: 'Statutory Enactment of Appropriation & Finance Bills',
              titleHi: 'विनियोग व वित्त विधेयकों की वैधानिक स्वीकृति',
              descriptionEn:
                  'Vote on the Appropriation Bill under Article 204 enabling lawful withdrawal of public money from the Consolidated Fund of the State, and Finance Bills enacting state taxes, duties, and excise.',
              descriptionHi:
                  'अनुच्छेद 204 के तहत विनियोग विधेयक पारित करना जिससे राज्य की संचित निधि से वैधानिक धन निकासी संभव होती है, और राज्य करों को लागू करने वाले वित्त विधेयक पर मतदान करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'No money can be withdrawn from the Consolidated Fund and no tax levied except by authority of enacted state law (Article 204 & Article 265); MLAs have no personal cheque-drawing power.',
              limitationHi:
                  'विधान सभा द्वारा पारित कानून के बिना राज्य संचित निधि से एक भी रुपया नहीं निकाला जा सकता और न ही कोई कर लगाया जा सकता है (अनुच्छेद 204 व 265); विधायक के पास कोई व्यक्तिगत चेक आहरण अधिकार नहीं है।',
              lineDepartmentEn: 'Finance Department & State Treasury',
              lineDepartmentHi: 'वित्त विभाग एवं राज्य कोषागार',
              procedureOrApprovalEn: 'Statutory passage by Legislative Assembly + Assent of the Governor.',
              procedureOrApprovalHi: 'विधान सभा द्वारा वैधानिक पारितीकरण + राज्यपाल की अनुमति।',
              jurisdictionScopeEn: 'State-wide',
              jurisdictionScopeHi: 'राज्य स्तर',
              verificationStatusEn: statusLabelEn,
              verificationStatusHi: statusLabelHi,
              statutoryCitation: 'Constitution of India, Article 204 (Appropriation), Article 265 (Taxes)',
            ),
            DutyItem(
              titleEn: 'Financial Audit Scrutiny via Public Accounts Committee (PAC)',
              titleHi: 'लोक लेखा समिति (PAC) द्वारा सीएजी ऑडिट व वित्तीय जांच',
              descriptionEn:
                  'Serve on statutory legislative financial committees (Public Accounts Committee, Estimates Committee, Committee on Public Undertakings) to examine Comptroller and Auditor General (CAG) audit reports, investigate fiscal leakages, and summon departmental heads to explain unspent funds.',
              descriptionHi:
                  'विधान सभा की वित्तीय समितियों (लोक लेखा समिति, प्राक्कलन समिति आदि) में सदस्य के रूप में सीएजी (CAG) की ऑडिट रिपोर्ट की जांच करना, वित्तीय अनियमितताओं की पड़ताल करना और अधिकारियों से जवाब तलब करना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              limitationEn:
                  'Legislative committees exercise investigative oversight and table recommendatory reports; they do not possess executive prosecuting powers to convict or dismiss officials directly.',
              limitationHi:
                  'समितियां केवल जांच व सिफारिश कर सकती हैं; उनके पास अधिकारियों को सीधे सजा देने या बर्खास्त करने का न्यायिक अधिकार नहीं है।',
              lineDepartmentEn: 'Comptroller and Auditor General of India (CAG) & Vidhan Sabha Secretariat',
              lineDepartmentHi: 'भारत के नियंत्रक एवं महालेखापरीक्षक (CAG) एवं विधान सभा सचिवालय',
              procedureOrApprovalEn: 'Committee examination -> Report tabled in Assembly -> Action Taken Reports submitted by State Government.',
              procedureOrApprovalHi: 'समिति द्वारा जांच -> सदन में रिपोर्ट प्रस्तुत -> सरकार द्वारा कृत कार्रवाई रिपोर्ट (ATR) पेश करना।',
              jurisdictionScopeEn: 'State Government Departments & Undertakings',
              jurisdictionScopeHi: 'राज्य सरकार के समस्त विभाग व उपक्रम',
              verificationStatusEn: statusLabelEn,
              verificationStatusHi: statusLabelHi,
              statutoryCitation: 'Constitution of India, Article 151(2); Assembly Financial Committee Rules',
            ),
          ],
        ),

        // ==========================================
        // 3. Questions, Motions & Government Oversight
        // ==========================================
        DutyCategorySection(
          category: DutyCategory.schemesAndBeneficiaries,
          customTitleEn: 'Questions, Motions & Government Oversight',
          customTitleHi: 'विधान सभा प्रश्न, प्रस्ताव व सरकार पर नियंत्रण',
          items: [
            DutyItem(
              titleEn: 'Holding Ministers Accountable during Assembly Question Hour',
              titleHi: 'विधान सभा प्रश्नकाल में सरकार की जवाबदेही',
              descriptionEn:
                  'Submit Starred Questions during Question Hour (demanding oral answers and supplementary probing questions on the floor of the House) and Unstarred Questions (demanding written factual data) regarding constituency canal water deficits, hospital staff shortages, damaged highways, and crop compensation.',
              descriptionHi:
                  'सदन में तारांकित प्रश्न (सदन में मौखिक उत्तर व पूरक प्रश्न पूछना) और अतारांकित प्रश्न (लिखित आंकड़े मांगना) लगाकर नहरी पानी की कमी, अस्पतालों में डॉक्टरों के रिक्त पद, टूटी सड़कें और फसल मुआवजे पर संबंधित मंत्रियों को जवाबदेह बनाना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'Questions must comply with strict parliamentary admissibility rules; cannot ask questions on sub-judice court cases, matters outside state purview, or individual personal service disputes.',
              limitationHi:
                  'प्रश्न विधान सभा नियमों के अधीन होने चाहिए; न्यायालय में विचाराधीन मामलों, केंद्र के विषयों या किसी कर्मचारी के व्यक्तिगत सेवा विवाद पर प्रश्न नहीं पूछा जा सकता।',
              lineDepartmentEn: 'Concerned State Line Departments & Assembly Secretariat',
              lineDepartmentHi: 'संबंधित राज्य विभाग एवं विधान सभा सचिवालय',
              procedureOrApprovalEn: 'Notice submitted under House Rules -> Scrutiny and admission by the Speaker -> Answered by Minister on designated rota day.',
              procedureOrApprovalHi: 'नियमों के तहत नोटिस -> विधान सभा अध्यक्ष द्वारा स्वीकृति -> संबंधित मंत्री द्वारा सदन में उत्तर।',
              jurisdictionScopeEn: 'State Legislature & Constituency',
              jurisdictionScopeHi: 'विधान सभा व निर्वाचन क्षेत्र',
              verificationStatusEn: statusLabelEn,
              verificationStatusHi: statusLabelHi,
              statutoryCitation: isHaryana
                  ? 'Rules of Procedure and Conduct of Business in the Haryana Legislative Assembly, Chapter VIII'
                  : (isRajasthan
                      ? 'Rules of Procedure and Conduct of Business in the Rajasthan Legislative Assembly, Chapter VIII'
                      : 'State Legislative Assembly Rules of Procedure, Chapter on Questions'),
            ),
            DutyItem(
              titleEn: 'Calling Attention & Zero Hour Urgent Public Submissions',
              titleHi: 'ध्यानाकर्षण प्रस्ताव व शून्यकाल में तात्कालिक जनहित मुद्दे उठाना',
              descriptionEn:
                  'Table Calling Attention Notices to draw the immediate attention of a Minister to pressing public emergencies (crop pest infestations, drinking water contamination, flash floods, major bridge collapses) and make rapid submissions during Zero Hour.',
              descriptionHi:
                  'बाढ़, ओलावृष्टि, फसल बर्बादी, पेयजल संकट या जहरीले पानी जैसी तात्कालिक आपदाओं पर ध्यानाकर्षण प्रस्ताव (Calling Attention) लाकर सरकार से सदन में तुरंत आधिकारिक बयान मांगना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'Does not confer executive disaster command authority; an MLA cannot unilaterally requisition military helicopters or override district disaster management SOPs.',
              limitationHi:
                  'यह कोई कार्यकारी आपदा कमान शक्ति नहीं है; विधायक सीधे सेना या राहत बजट जारी करने का प्रशासनिक आदेश नहीं दे सकते।',
              lineDepartmentEn: 'Disaster Management, Revenue & Concerned Administrative Departments',
              lineDepartmentHi: 'आपदा प्रबंधन, राजस्व एवं संबंधित प्रशासनिक विभाग',
              procedureOrApprovalEn: 'Admitted by the Speaker under Rule of Urgent Public Importance -> Ministerial statement on floor of House.',
              procedureOrApprovalHi: 'विधान सभा अध्यक्ष द्वारा तात्कालिक जनहित में स्वीकृति -> मंत्री द्वारा सदन में वक्तव्य।',
              jurisdictionScopeEn: 'State & Assembly Constituency',
              jurisdictionScopeHi: 'राज्य व विधान सभा क्षेत्र',
              verificationStatusEn: statusLabelEn,
              verificationStatusHi: statusLabelHi,
              statutoryCitation: isHaryana
                  ? 'Rules of Procedure and Conduct of Business in the Haryana Legislative Assembly, Chapter XI'
                  : (isRajasthan
                      ? 'Rules of Procedure and Conduct of Business in the Rajasthan Legislative Assembly, Chapter XIII'
                      : 'State Legislative Assembly Rules of Procedure, Calling Attention Notices'),
            ),
          ],
        ),

        // ==========================================
        // 4. Constituency Representation & Public Grievance Assistance
        // ==========================================
        DutyCategorySection(
          category: DutyCategory.socialSectorCoordination,
          customTitleEn: 'Constituency Representation & Public Grievance Assistance',
          customTitleHi: 'क्षेत्र प्रतिनिधित्व व जनसमस्या सहायता',
          items: [
            DutyItem(
              titleEn: 'Constituency Office Public Grievance Hearings & Representations',
              titleHi: 'क्षेत्रीय कार्यालय में जनसुनवाई व मांग-पत्र अग्रसारण',
              descriptionEn:
                  'Maintain a dedicated constituency office to receive citizen delegations, hear grievances regarding welfare schemes, water shortages, and electricity supply, and issue formal recommendatory representations (D.O. letters) to the Deputy Commissioner / District Collector.',
              descriptionHi:
                  'निर्वाचन क्षेत्र में नियमित जनसुनवाई करना, ग्रामीणों व नागरिकों के मांग-पत्र लेना और जनहित की समस्याओं पर उपायुक्त/जिला कलेक्टर व संबंधित अधिकारियों को अनुशंसा पत्र भेजना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'MLA representations and D.O. letters are recommendatory and advisory in law; they do NOT constitute legally binding executive orders. Bureaucrats must examine requests under established statutory rules.',
              limitationHi:
                  'विधायक के अनुशंसा पत्र (D.O. Letters) कानूनी रूप से केवल सलाहकारी व संस्तुति रूप में होते हैं, कोई बाध्यकारी प्रशासनिक आदेश नहीं। अधिकारी नियमों के अनुसार ही कार्रवाई कर सकते हैं।',
              lineDepartmentEn: 'District Administration, Line Departments & Panchayat Bodies',
              lineDepartmentHi: 'जिला प्रशासन, संबंधित विभाग व पंचायत संस्थाएं',
              procedureOrApprovalEn: 'Citizen representation -> MLA recommendation letter -> Departmental inquiry and disposal under executive citizen charter.',
              procedureOrApprovalHi: 'नागरिक मांग-पत्र -> विधायक अनुशंसा -> विभागीय जांच व नागरिक सेवा नियमों के तहत निस्तारण।',
              jurisdictionScopeEn: 'Assembly Constituency',
              jurisdictionScopeHi: 'विधान सभा निर्वाचन क्षेत्र',
              verificationStatusEn: statusLabelEn,
              verificationStatusHi: statusLabelHi,
              statutoryCitation: 'General Democratic Practice & Executive Rules of Business',
            ),
            DutyItem(
              titleEn: 'Submitting Citizen Petitions to Vidhan Sabha Committee on Petitions',
              titleHi: 'विधान सभा याचिका समिति में नागरिक याचिकाएं पेश करना',
              descriptionEn:
                  'Present formal citizen petitions on collective grievances (e.g. stalled multi-village canal siphon, unbuilt bypass road, sub-divisional hospital deficiencies) to the Committee on Petitions of the Legislative Assembly for statutory legislative investigation.',
              descriptionHi:
                  'क्षेत्र की गंभीर व सामूहिक समस्याओं (जैसे नहर की अधूरी पुलिया, बाईपास सड़क, अस्पताल में ट्रॉमा सेंटर) पर नागरिकों की औपचारिक याचिका विधान सभा की याचिका समिति में प्रस्तुत करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'Petitions concerning sub-judice legal disputes, individual service or disciplinary matters, or cases within the jurisdiction of courts or tribunals are inadmissible.',
              limitationHi:
                  'अदालत में विचाराधीन मामलों, सरकारी कर्मचारियों के व्यक्तिगत विवादों या ट्रिब्यूनल के मामलों में याचिका स्वीकार नहीं की जा सकती।',
              lineDepartmentEn: 'Committee on Petitions, Legislative Assembly Secretariat',
              lineDepartmentHi: 'याचिका समिति, विधान सभा सचिवालय',
              procedureOrApprovalEn: 'Petition signed by citizens -> Counter-signed and presented by MLA -> Examined by Petitions Committee -> Report with recommendations tabled in Assembly.',
              procedureOrApprovalHi: 'नागरिकों द्वारा हस्ताक्षरित याचिका -> विधायक द्वारा प्रस्तुत -> याचिका समिति द्वारा जांच -> सदन में सिफारिश रिपोर्ट।',
              jurisdictionScopeEn: 'Assembly Constituency & State',
              jurisdictionScopeHi: 'विधान सभा क्षेत्र व राज्य',
              verificationStatusEn: statusLabelEn,
              verificationStatusHi: statusLabelHi,
              statutoryCitation: 'Assembly Rules of Procedure, Committee on Petitions',
            ),
          ],
        ),

        // ==========================================
        // 5. Development Works, Scheme Monitoring & District Coordination
        // ==========================================
        DutyCategorySection(
          category: DutyCategory.welfareAndDisaster,
          customTitleEn: 'Development Works (MLALADS) & District Coordination (DISHA)',
          customTitleHi: 'विकास कार्य (विधायक निधि), योजना निगरानी व जिला समन्वय (DISHA)',
          items: [
            DutyItem(
              titleEn: 'Recommending Works under MLA Local Area Development Scheme (MLALADS)',
              titleHi: 'विधायक स्थानीय क्षेत्र विकास योजना (MLALADS / विधायक निधि) में अनुशंसा',
              descriptionEn: isHaryana
                  ? 'Recommend capital public works (community halls, drinking water plants, crematorium sheds, rural roads, library rooms) under the Haryana Vidhayak Adarsh Nagar Avam Gram Yojana (VANGY) within the verified allocation of Rs 2 Crore per constituency per year, adhering to population-based village ceilings (Rs 2 Crore for >10,000; Rs 1 Crore for 5,000-10,000; Rs 50 Lakh for <5,000; generic Rs 5 Crore claims remain unverified budget proposals).'
                  : (isRajasthan
                      ? 'Recommend durable community assets (rural roads, school classrooms, drinking water tube-wells, sports grounds) up to Rs 5 Crore per constituency per year under the Rajasthan Vidhayak Sthaniya Kshetra Vikas Yojana (MLA-LAD Scheme), adhering to mandatory SC/ST allocations (min. 20% / Rs 1 Crore), supported by Scheme Guidelines 2023 and Rajasthan Economic Review 2024-25.'
                      : 'Recommend durable public infrastructure works within the statutory annual financial ceiling established by the state government (typically Rs 2 to 5 Crore per year), ensuring community assets are created on government/public land.'),
              descriptionHi: isHaryana
                  ? 'हरियाणा सरकार की विधायक आदर्श नगर एवं ग्राम योजना (VANGY) के तहत प्रतिवर्ष रु 2 करोड़ की सत्यापित सीमा में विकास कार्यों की अनुशंसा करना, जिसमें ग्राम जनसंख्या अनुसार सीमाएं लागू हैं (10,000 से अधिक पर रु 2 करोड़; 5,000-10,000 पर रु 1 करोड़; 5,000 तक पर रु 50 लाख; रु 5 करोड़ का दावा अपुष्ट बजट घोषणा है)।'
                  : (isRajasthan
                      ? 'राजस्थान विधायक स्थानीय क्षेत्र विकास योजना (MLA-LAD) के तहत प्रतिवर्ष रु 5 करोड़ तक के विकास कार्यों (पेयजल, स्कूल कक्षा-कक्ष, खेल मैदान, ग्रामीण रास्ते) की अनुशंसा करना, जिसमें 20% राशि (रु 1 करोड़) एससी/एसटी विकास हेतु अनिवार्य है (योजना नियमावली 2023 व राजस्थान आर्थिक समीक्षा द्वारा पुष्ट)।'
                      : 'राज्य सरकार की विधायक निधि योजना के तहत वार्षिक निर्धारित राशि (रु 2 से 5 करोड़) के अंतर्गत सार्वजनिक भूमि पर टिकाऊ सामुदायिक परिसंपत्तियों की अनुशंसा करना।'),
              responsibilityType: ResponsibilityType.requiresApproval,
              limitationEn: isHaryana
                  ? 'Works must adhere to village population ceilings (max Rs 50 Lakh for pop <5,000, Rs 1 Crore for 5,000-10,000, Rs 2 Crore for >10,000); cannot recommend works on private land or places of worship; cannot award contracts or sign cheques directly.'
                  : 'Cannot recommend works on private land, commercial properties, or places of worship; cannot split works to bypass financial sanction thresholds; cannot award contracts or sign cheques directly.',
              limitationHi: isHaryana
                  ? 'कार्य ग्राम जनसंख्या सीमा के अनुसार होने चाहिए (5,000 तक अधिकतम रु 50 लाख, 5,000-10,000 पर रु 1 करोड़, 10,000 से अधिक पर रु 2 करोड़); निजी भूमि या धार्मिक स्थलों पर सिफारिश नहीं कर सकते; सीधे ठेका देने या चेक काटने का अधिकार नहीं है।'
                  : 'निजी भूमि, व्यावसायिक दुकानों या धार्मिक स्थलों पर कार्य की सिफारिश नहीं कर सकते; वित्तीय सीमा से बचने के लिए कार्यों को टुकड़ों में नहीं बांट सकते; सीधे ठेका देने या चेक काटने का कोई अधिकार नहीं है।',
              lineDepartmentEn: isHaryana
                  ? 'Deputy Commissioner, Rural Development Department & Panchayati Raj Engineering Wing / PWD'
                  : (isRajasthan
                      ? 'District Collector (Zila Parishad / Planning Cell) & Executing Line Departments'
                      : 'District Magistrate / Collector & State Public Works / Panchayati Raj Engineering Department'),
              lineDepartmentHi: isHaryana
                  ? 'उपायुक्त, ग्रामीण विकास विभाग एवं पंचायती राज तकनीकी विंग / PWD'
                  : (isRajasthan
                      ? 'जिला कलेक्टर (जिला परिषद / आयोजना प्रकोष्ठ) एवं संबंधित निर्माण विभाग'
                      : 'जिला कलेक्टर / मजिस्ट्रेट एवं लोक निर्माण / पंचायती राज इंजीनियरिंग विभाग'),
              procedureOrApprovalEn:
                  'MLA recommendation letter -> Feasibility inspection by Executive Engineer -> Administrative Sanction by DC/Collector -> Technical Sanction -> E-Tendering and execution by Line Department.',
              procedureOrApprovalHi:
                  'विधायक अनुशंसा पत्र -> अधिशासी अभियंता द्वारा तकनीकी व्यवहार्यता जांच -> उपायुक्त/कलेक्टर द्वारा प्रशासनिक स्वीकृति -> तकनीकी स्वीकृति -> ई-टेंडरिंग द्वारा निर्माण कार्य।',
              jurisdictionScopeEn: 'Assembly Constituency',
              jurisdictionScopeHi: 'विधान सभा निर्वाचन क्षेत्र',
              verificationStatusEn: statusLabelEn,
              verificationStatusHi: statusLabelHi,
              statutoryCitation: isHaryana
                  ? 'Government of Haryana, Rural Development Department, VANGY Guidelines (haryanarural.gov.in); Rs 5 Cr general claim pending gazetted verification'
                  : (isRajasthan
                      ? 'Government of Rajasthan, Rural Development & Panchayati Raj Dept, MLA-LAD Guidelines 2023 & Rajasthan Economic Review 2024-25'
                      : 'Respective State Government Planning Department MLA Scheme Guidelines'),
            ),
            DutyItem(
              titleEn: 'Monitoring Central & State Schemes in DISHA Committee',
              titleHi: 'जिला विकास समन्वय एवं निगरानी समिति (DISHA) में निगरानी',
              descriptionEn:
                  'Participate as a nominated member in the District Development Coordination and Monitoring Committee (DISHA) constituted by the Ministry of Rural Development, reviewing implementation progress, fund utilization, and quality of works under MGNREGA, PMGSY, PMAY-G, Jal Jeevan Mission, and Ayushman Bharat.',
              descriptionHi:
                  'केंद्रीय ग्रामीण विकास मंत्रालय द्वारा गठित जिला विकास समन्वय एवं निगरानी समिति (DISHA) में सदस्य के रूप में मनरेगा, पीएमजीएसवाई, प्रधानमंत्री आवास, जल जीवन मिशन व आयुष्मान भारत के कार्यों की प्रगति, गुणवत्ता व धन के सदुपयोग की समीक्षा करना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              limitationEn:
                  'DISHA is an oversight and coordination body chaired by the senior Lok Sabha MP; MLAs do not have individual executive powers to terminate contractors or alter central program guidelines.',
              limitationHi:
                  'दिशा समिति की अध्यक्षता वरिष्ठ लोकसभा सांसद करते हैं; विधायक के पास ठेकेदारों को सीधे हटाने या केंद्रीय योजनाओं के नियमों को बदलने की व्यक्तिगत शक्ति नहीं है।',
              lineDepartmentEn: 'Ministry of Rural Development (GoI) & District Collector / CEO Zila Parishad',
              lineDepartmentHi: 'ग्रामीण विकास मंत्रालय (भारत सरकार) एवं जिला कलेक्टर / मुख्य कार्यकारी अधिकारी, जिला परिषद',
              procedureOrApprovalEn: 'Quarterly review meetings -> Observations recorded in DISHA minutes -> Recommendations sent to State & Central Governments.',
              procedureOrApprovalHi: 'त्रैमासिक बैठकें -> दिशा कार्यवृत्त में टिप्पणियां दर्ज -> राज्य व केंद्र सरकार को सुधारात्मक सिफारिशें।',
              jurisdictionScopeEn: 'District (Constituency Blocks)',
              jurisdictionScopeHi: 'जिला स्तर (विधान सभा क्षेत्र के अंतर्गत)',
              verificationStatusEn: statusLabelEn,
              verificationStatusHi: statusLabelHi,
              statutoryCitation: 'Ministry of Rural Development, Government of India, DISHA Guidelines',
            ),
            DutyItem(
              titleEn: 'District Planning Committee (DPC) Integration & Master Planning',
              titleHi: 'जिला योजना समिति (DPC) में जिला विकास योजना का समेकन',
              descriptionEn:
                  'Participate in the District Planning Committee under Article 243ZD of the Constitution to consolidate draft development plans prepared by Panchayats and Municipalities into a unified draft development plan for the district.',
              descriptionHi:
                  'संविधान के अनुच्छेद 243ZD के तहत जिला योजना समिति की बैठकों में भाग लेकर पंचायतों व नगर पालिकाओं द्वारा तैयार विकास योजनाओं का जिले के संपूर्ण विकास प्लान में समेकन करना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              limitationEn:
                  'Cannot unilaterally veto or override resolutions legally passed by autonomous Gram Panchayats, Panchayat Samitis, or Municipal Councils.',
              limitationHi:
                  'स्वायत्त ग्राम पंचायतों, पंचायत समितियों या नगर पालिकाओं द्वारा विधिवत पारित प्रस्तावों को मनमाने ढंग से वीटो या खारिज नहीं कर सकते।',
              lineDepartmentEn: 'District Planning Committee & State Planning Department',
              lineDepartmentHi: 'जिला योजना समिति एवं राज्य योजना विभाग',
              procedureOrApprovalEn: 'DPC collective deliberations -> Resolution adopted by committee -> Forwarded to State Government.',
              procedureOrApprovalHi: 'जिला योजना समिति की बैठक -> प्रस्ताव पारित -> राज्य सरकार को प्रेषण।',
              jurisdictionScopeEn: 'District Jurisdiction',
              jurisdictionScopeHi: 'जिला स्तरीय अधिकार क्षेत्र',
              verificationStatusEn: statusLabelEn,
              verificationStatusHi: statusLabelHi,
              statutoryCitation: 'Constitution of India, Article 243ZD',
            ),
          ],
        ),

        // ==========================================
        // 6. Electoral Responsibilities & Legal Limits
        // ==========================================
        DutyCategorySection(
          category: DutyCategory.legalLimitsAndExclusions,
          customTitleEn: 'Electoral Responsibilities & Legal Limits',
          customTitleHi: 'चुनावी दायित्व, कानूनी सीमाएं व विभागीय स्वीकृतियां',
          items: [
            DutyItem(
              titleEn: 'Constitutional Voting in Presidential and Rajya Sabha Elections',
              titleHi: 'राष्ट्रपति व राज्यसभा चुनावों में संवैधानिक मताधिकार',
              descriptionEn:
                  'Vote as an elected member of the Electoral College in the election of the President of India (Article 54) with a population-weighted vote value, and elect members to the Council of States (Rajya Sabha) under Article 80(4) through proportional representation by single transferable vote.',
              descriptionHi:
                  'भारत के राष्ट्रपति के चुनाव (अनुच्छेद 54) में निर्वाचक मंडल के सदस्य के रूप में मत डालना, और अनुच्छेद 80(4) के तहत एकल संक्रमणीय मत द्वारा आनुपातिक प्रतिनिधित्व से राज्यसभा सांसदों का चुनाव करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'Nominated members (if any) cannot vote in Presidential elections; voting is an individual constitutional franchise governed by the Election Commission of India and anti-defection rules.',
              limitationHi:
                  'मनोनीत सदस्य राष्ट्रपति चुनाव में मत नहीं दे सकते; मतदान भारत निर्वाचन आयोग के नियमों व संवैधानिक प्रक्रियाओं के अधीन व्यक्तिगत मताधिकार है।',
              lineDepartmentEn: 'Election Commission of India & Returning Officer (Secretary, Legislative Assembly)',
              lineDepartmentHi: 'भारत निर्वाचन आयोग एवं निर्वाचन अधिकारी (सचिव, विधान सभा)',
              procedureOrApprovalEn: 'Secret ballot / Open ballot under Election Commission of India notifications & Representation of the People Act, 1951.',
              procedureOrApprovalHi: 'भारत निर्वाचन आयोग की अधिसूचना व लोक प्रतिनिधित्व अधिनियम, 1951 के तहत मतदान।',
              jurisdictionScopeEn: 'Constitutional / National',
              jurisdictionScopeHi: 'संवैधानिक / राष्ट्रीय',
              verificationStatusEn: statusLabelEn,
              verificationStatusHi: statusLabelHi,
              statutoryCitation: 'Constitution of India, Articles 54, 55 (President), Article 80(4) (Rajya Sabha)',
            ),
            DutyItem(
              titleEn: 'Election to State Legislative Council (Vidhan Parishad) Where Applicable',
              titleHi: 'विधान परिषद चुनाव - जहां द्विसदनीय विधान मंडल लागू हो',
              descriptionEn: isHaryana || isRajasthan
                  ? 'Haryana and Rajasthan have UNICAMERAL legislatures (Vidhan Sabha only; no Vidhan Parishad exists). In the 6 Indian states having a bicameral legislature (Uttar Pradesh, Bihar, Maharashtra, Karnataka, Andhra Pradesh, Telangana), elected MLAs elect one-third of the members of the Legislative Council under Article 171(3)(d).'
                  : 'In the 6 Indian states having a bicameral legislature (Uttar Pradesh, Bihar, Maharashtra, Karnataka, Andhra Pradesh, Telangana), elected MLAs elect one-third of the members of the State Legislative Council under Article 171(3)(d). In unicameral states, this post does not exist.',
              descriptionHi: isHaryana || isRajasthan
                  ? 'हरियाणा और राजस्थान में एकसदनीय विधान मंडल (केवल विधान सभा) है; यहाँ विधान परिषद का अस्तित्व नहीं है। भारत के 6 द्विसदनीय राज्यों (उत्तर प्रदेश, बिहार, महाराष्ट्र, कर्नाटक, आंध्र प्रदेश, तेलंगाना) में निर्वाचित विधायक अनुच्छेद 171(3)(d) के तहत विधान परिषद के एक-तिहाई सदस्यों का चुनाव करते हैं।'
                  : 'भारत के 6 द्विसदनीय राज्यों (उत्तर प्रदेश, बिहार, महाराष्ट्र, कर्नाटक, आंध्र प्रदेश, तेलंगाना) में निर्वाचित विधायक अनुच्छेद 171(3)(d) के तहत विधान परिषद के 1/3 सदस्यों का चुनाव करते हैं। एकसदनीय राज्यों में यह लागू नहीं है।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'Inapplicable in unicameral states (including Haryana and Rajasthan). Only applicable where a Legislative Council has been constitutionally established under Article 169.',
              limitationHi:
                  'एकसदनीय राज्यों (हरियाणा, राजस्थान आदि) में लागू नहीं है। यह केवल उन्हीं राज्यों में लागू है जहाँ अनुच्छेद 169 के तहत विधान परिषद गठित है।',
              lineDepartmentEn: 'Election Commission of India & State Legislative Council',
              lineDepartmentHi: 'भारत निर्वाचन आयोग एवं राज्य विधान परिषद',
              procedureOrApprovalEn: 'Proportional representation by means of single transferable vote (Article 171(3)(d)).',
              procedureOrApprovalHi: 'एकल संक्रमणीय मत द्वारा आनुपातिक प्रतिनिधित्व (अनुच्छेद 171(3)(d))।',
              jurisdictionScopeEn: 'State Specific (Bicameral States Only)',
              jurisdictionScopeHi: 'केवल द्विसदनीय राज्यों में',
              verificationStatusEn: statusLabelEn,
              verificationStatusHi: statusLabelHi,
              statutoryCitation: 'Constitution of India, Article 169, 171(3)(d)',
            ),
            DutyItem(
              titleEn: 'Strict Separation of Executive, Police & Judicial Powers',
              titleHi: 'कार्यकारी, पुलिस व न्यायिक शक्तियों का वैधानिक पृथक्करण',
              descriptionEn:
                  'Uphold the constitutional doctrine of separation of powers (Article 50 & Part VI of the Constitution). An MLA makes state laws and represents public interest, while executive departments, police authorities, and courts function independently under their respective statutory frameworks.',
              descriptionHi:
                  'संविधान के अनुच्छेद 50 व भाग VI के तहत शक्तियों के पृथक्करण का पालन करना। विधायक कानून बनाते हैं और जनता की आवाज उठाते हैं, जबकि प्रशासनिक विभाग, पुलिस और अदालतें कानून के अनुसार पूरी तरह स्वतंत्र कार्य करती हैं।',
              responsibilityType: ResponsibilityType.departmentalResponsibility,
              limitationEn:
                  'Absolute constitutional and statutory prohibition against ordering FIR registrations or closures, demanding case transfers, interfering in active police investigations, resolving civil property titles, or directing magistrate decisions.',
              limitationHi:
                  'एफआईआर दर्ज कराने या रद्द कराने, पुलिस विवेचना में हस्तक्षेप करने, जमीन के मालिकाना हक का फैसला करने या अदालत/मजिस्ट्रेट को आदेश देने का पूर्ण वैधानिक निषेध है।',
              lineDepartmentEn: 'Judiciary (Subordinate Courts / High Court), State Police & Civil Bureaucracy',
              lineDepartmentHi: 'न्यायपालिका (अधीनस्थ अदालतें / उच्च न्यायालय), राज्य पुलिस एवं सिविल प्रशासन',
              procedureOrApprovalEn: 'Regulated strictly under Code of Criminal Procedure / BNSS, Indian Penal Code / BNS, and Civil Procedure Code.',
              procedureOrApprovalHi: 'दंड प्रक्रिया संहिता / बीएनएसएस, भारतीय न्याय संहिता एवं सिविल प्रक्रिया संहिता के तहत संचालित।',
              jurisdictionScopeEn: 'Constitutional Separation of Powers',
              jurisdictionScopeHi: 'संवैधानिक शक्तियों का पृथक्करण',
              verificationStatusEn: statusLabelEn,
              verificationStatusHi: statusLabelHi,
              statutoryCitation: 'Constitution of India, Articles 50, 162, 166 (Separation of Powers)',
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // MEMBER OF PARLIAMENT (MP - Lok Sabha / Rajya Sabha)
  // =========================================================================
  static RepresentativeRoleProfile _buildMpProfile(String? stateIdentifier, {Place? place}) {
    const String statusLabelEn = 'Officially Verified Constitutional Law';
    const String statusLabelHi = 'आधिकारिक सत्यापित संवैधानिक कानून';

    return const RepresentativeRoleProfile(
      role: RepresentativeRole.mp,
      titleEn: 'Member of Parliament (MP) - Lok Sabha / Rajya Sabha',
      titleHi: 'सांसद (संसद सदस्य - लोक सभा / राज्य सभा)',
      governingBodyEn: 'Parliament of India (Lok Sabha / Rajya Sabha), New Delhi',
      governingBodyHi: 'भारत की संसद (लोक सभा / राज्य सभा), नई दिल्ली',
      constitutionalPostSummaryEn:
          'Elected national representative in the Parliament of India (Part V of the Constitution of India). Primary constitutional duties include enacting Union and Concurrent legislation (Articles 107-111, 246), scrutinizing and passing the Union Budget and Demands for Grants (Articles 112-114), holding the Union Council of Ministers accountable during Question Hour and parliamentary motions, recommending durable community infrastructure under the Member of Parliament Local Area Development Scheme (MPLADS - ₹5 Crore/year), participating in national electoral colleges (President & Vice-President), and coordinating district-level development through the DISHA committee.',
      constitutionalPostSummaryHi:
          'भारत के संविधान (भाग V) के अंतर्गत संसद के निर्वाचित राष्ट्रीय प्रतिनिधि। मुख्य संवैधानिक दायित्वों में संघ व समवर्ती सूची पर केंद्रीय कानून बनाना (अनुच्छेद 107-111, 246), वार्षिक केंद्रीय बजट व अनुदान मांगों की समीक्षा व स्वीकृति (अनुच्छेद 112-114), प्रश्नकाल व संसदीय प्रस्तावों के माध्यम से केंद्रीय मंत्रिपरिषद की जवाबदेही तय करना, सांसद स्थानीय क्षेत्र विकास योजना (MPLADS - ₹5 करोड़ वार्षिक) के तहत टिकाऊ सार्वजनिक संपत्तियों की अनुशंसा करना, राष्ट्रपति व उपराष्ट्रपति चुनाव में मतदान करना तथा दिशा (DISHA) समिति के माध्यम से जिला स्तरीय विकास योजनाओं की समीक्षा करना शामिल है।',
      legalReference: LegalSourceReference(
        sourceTitle: 'Constitution of India (Part V, Arts. 79-122) & MoSPI Revised MPLADS Guidelines 2023',
        relevantSections: 'Arts. 79-84, 105, 107-117, 118, 124, 368; MoSPI Revised MPLADS Guidelines 2023 (Ch. 2-5, Annexure-II); MoRD DISHA Guidelines (Order Q-13016/1/2016-DISHA cited)',
        jurisdictionState: 'Union of India (National)',
        sourceUrl: 'https://www.legislative.gov.in/static/uploads/2025/08/cb1b190ea633a1746368ed1fac35fb30.pdf',
        lastVerifiedDate: '2026-10-26',
        isStateSpecific: true,
        officialGuidanceNoteEn:
            'Shared umbrella reference covers constitutional Part V provisions (Constitution as on 1 May 2024: https://www.legislative.gov.in/static/uploads/2025/08/cb1b190ea633a1746368ed1fac35fb30.pdf). Specific statutory instruments, Lok Sabha procedure rules (https://sansad.in/ls/rules), MoSPI Revised MPLADS Guidelines 2023 (https://www.mplads.gov.in/MPLADS/UploadedFiles/MPLADSGuidelines2023_English_.pdf), and MoRD DISHA Framework (https://disha.gov.in/guidelines) are cited directly on each duty item below.',
        officialGuidanceNoteHi:
            'यह साझा संदर्भ मुख्य रूप से संवैधानिक भाग V के प्रावधानों को संदर्भित करता है (1 मई 2024 तक अद्यतन संविधान: legislative.gov.in)। विशिष्ट अधिनियम, लोक सभा कार्य संचालन नियम (sansad.in/ls/rules), संशोधित सांसद निधि 2023 और दिशा दिशा-निर्देश (disha.gov.in/guidelines) नीचे दिए गए प्रत्येक दायित्व पर सीधे उद्धृत हैं।',
      ),
      citizenQa: [
        CitizenQaItem(
          questionEn: 'What is the primary constitutional role of a Member of Parliament (MP)?',
          questionHi: 'सांसद (MP) का मुख्य संवैधानिक कार्य क्या है?',
          answerEn:
              'An MP is first and foremost a national federal lawmaker and representative in Parliament. Their primary constitutional duties are to debate, amend, and enact Union and Concurrent laws (defense, railways, national highways, banking, telecom), scrutinize and pass the Union Budget and taxes, hold Central Ministries accountable during Question Hour and through parliamentary committees, and represent citizen concerns before the Union Government. Recommending local development works under MPLADS is a secondary central scheme, not an executive command.',
          answerHi:
              'सांसद मुख्य रूप से देश के कानून निर्माता (national lawmaker) और संसद के सदस्य होते हैं। उनका मुख्य संवैधानिक दायित्व संघ व समवर्ती सूची (रक्षा, विदेश, राष्ट्रीय राजमार्ग, रेलवे, बैंकिंग, दूरसंचार आदि) पर कानून बनाना, केंद्रीय बजट व करों पर चर्चा व मतदान करना, प्रश्नकाल व संसदीय समितियों के माध्यम से मंत्रालयों की जवाबदेही तय करना और केंद्र सरकार के समक्ष जनहित के मुद्दे उठाना है। सांसद निधि से कार्यों की सिफारिश करना एक सहायक योजना है, न कि कोई कार्यकारी प्रशासनिक आदेश।',
        ),
        CitizenQaItem(
          questionEn: 'What is the MPLADS Scheme and can an MP award contracts, select vendors, or sign cheques directly?',
          questionHi: 'सांसद निधि (MPLADS) क्या है और क्या सांसद सीधे टेंडर जारी कर सकते हैं या चेक काट सकते हैं?',
          answerEn:
              'NO. Under the Revised MPLADS Guidelines (effective 1 April 2023) issued by the Ministry of Statistics and Programme Implementation (MoSPI), each MP has an annual entitlement of ₹5 Crore (managed digitally via the e-SAKSHI portal, historically disbursed in two equal installments of ₹2.5 Crore) strictly for recommending durable public utility community assets (drinking water, school classrooms, community centers, rural roads). The MP CANNOT issue tenders, select private vendors, or disburse funds directly. Funds are NEVER deposited into the MP\'s personal account. The Nodal / Implementing District Authority (DC/DM/Collector) scrutinizes technical feasibility, accords administrative sanction under Para 4.3.2, and selects government implementing agencies who execute works via transparent e-tendering and make direct PFMS payments. Works on private/commercial property, places of worship, or for individual benefits are strictly prohibited under Annexure-II of the Guidelines.',
          answerHi:
              'नहीं। सांख्यिकी और कार्यक्रम कार्यान्वयन मंत्रालय (MoSPI) के संशोधित दिशा-निर्देशों (1 अप्रैल 2023 से प्रभावी) के अनुसार प्रत्येक सांसद को प्रतिवर्ष ₹5 करोड़ (ई-साक्षी / e-SAKSHI वेब पोर्टल के माध्यम से अधिकृत, पूर्व में ₹2.5 करोड़ की दो किस्तों में) की पात्रता केवल टिकाऊ सार्वजनिक सामुदायिक संपत्तियों (पेयजल, स्कूल कमरे, पुस्तकालय, ग्रामीण रास्ते) की अनुशंसा करने के लिए मिलती है। सांसद सीधे टेंडर जारी नहीं कर सकते, निजी ठेकेदार नहीं चुन सकते और न ही चेक काट सकते हैं। फंड कभी भी सांसद के निजी बैंक खाते में नहीं आता। जिला प्राधिकारी (जिलाधिकारी/उपायुक्त) तकनीकी जांच के बाद प्रशासनिक स्वीकृति देते हैं और सरकारी कार्यदायी एजेंसियां ई-टेंडरिंग द्वारा कार्य कराकर PFMS के माध्यम से सीधे भुगतान करती हैं। निजी भूमि, व्यावसायिक प्रतिष्ठानों या धार्मिक स्थलों पर कार्य दिशा-निर्देशों के परिशिष्ट-II (Annexure-II) के तहत पूर्णतः प्रतिबंधित हैं।',
        ),
        CitizenQaItem(
          questionEn: 'What are the territorial recommendation differences between Lok Sabha, Rajya Sabha, and Nominated MPs?',
          questionHi: 'लोक सभा, राज्य सभा और मनोनीत सांसदों के कार्यक्षेत्र व सिफारिश के दायरे में क्या अंतर है?',
          answerEn:
              '1) Lok Sabha MP: Directly elected from a single-member territorial constituency; can recommend MPLADS works STRICTLY within their Parliamentary Constituency. 2) Elected Rajya Sabha MP: Elected by the MLAs of a State; can recommend MPLADS works in ONE OR MORE DISTRICTS within the State from which elected. 3) Nominated MP (Lok Sabha or Rajya Sabha): Nominated by the President of India; can select ONE OR MORE DISTRICTS FROM ANY ONE STATE IN THE COUNTRY of their choice for implementation of eligible works under the Scheme (Para 2.5 of MPLADS Guidelines).',
          answerHi:
              '1) लोक सभा सांसद: क्षेत्रीय संसदीय निर्वाचन क्षेत्र से सीधे जनता द्वारा निर्वाचित होते हैं; वे सांसद निधि के विकास कार्यों की सिफारिश केवल अपने संसदीय क्षेत्र के भीतर ही कर सकते हैं। 2) निर्वाचित राज्य सभा सांसद: राज्य के विधायकों द्वारा चुने जाते हैं; वे संबंधित राज्य के किसी भी एक या अधिक जिलों में विकास कार्यों की सिफारिश कर सकते हैं। 3) मनोनीत सांसद: राष्ट्रपति द्वारा मनोनीत होते हैं; वे देश के किसी भी एक राज्य के भीतर एक या अधिक जिलों का चयन कर सांसद निधि कार्यों की सिफारिश कर सकते हैं (दिशा-निर्देश पैरा 2.5)।',
        ),
        CitizenQaItem(
          questionEn: 'Can an MP direct state police officers, register or quash criminal FIRs, or suspend district officials?',
          questionHi: 'क्या सांसद राज्य पुलिस को एफआईआर दर्ज करने या रद्द करने का आदेश दे सकते हैं, या जिला अधिकारियों को निलंबित कर सकते हैं?',
          answerEn:
              'NO direct statutory command authority. Public order and police are state subjects under Entries 1 and 2 of List II (State List) of the Seventh Schedule. Criminal investigation is an independent statutory duty of the police under CrPC (Sec. 154, 156) / BNSS (Sec. 173, 175). An MP has NO statutory authority to order the registration, alteration, or quashing of FIRs, command arrests, or direct investigations (quashing is solely High Court jurisdiction under Sec. 482 CrPC / Sec. 528 BNSS). District officers operate under State Civil Services Rules; an MP has no executive power to suspend, penalize, or transfer them. However, lawful communication, representing constituent hardship, and forwarding public representations to the Superintendent of Police or competent executive authorities are legitimate representative functions.',
          answerHi:
              'सीधा प्रशासनिक या आदेशात्मक अधिकार नहीं है। लोक-व्यवस्था और पुलिस संविधान की सातवीं अनुसूची की राज्य सूची (सूची II, प्रविष्टि 1 व 2) के विषय हैं। आपराधिक जांच दंड प्रक्रिया संहिता (CrPC) / बीएनएसएस के तहत पुलिस का स्वतंत्र वैधानिक कर्तव्य है। सांसद के पास एफआईआर दर्ज करने, बदलने या रद्द करने का सीधा आदेश देने या विवेचना को निर्देशित करने की कोई वैधानिक शक्ति नहीं है (एफआईआर रद्द करना केवल उच्च न्यायालय का अधिकार है)। जिला अधिकारियों पर प्रशासनिक नियंत्रण राज्य सरकार का होता है; सांसद उन्हें सीधे निलंबित या स्थानांतरित नहीं कर सकते। हालांकि, जनता की शिकायतों पर अधिकारियों से पत्राचार करना या जनसमस्याओं को पुलिस अधीक्षक या सक्षम प्राधिकारी के संज्ञान में लाना जनप्रतिनिधि का वैध अधिकार है।',
        ),
        CitizenQaItem(
          questionEn: 'What is the DISHA Committee and does the MP have administrative command over district officials?',
          questionHi: 'दिशा (DISHA) समिति क्या है और क्या सांसद को जिला अधिकारियों पर प्रशासनिक कमान प्राप्त है?',
          answerEn:
              'The District Development Coordination and Monitoring Committee (DISHA) is constituted under Ministry of Rural Development Guidelines to ensure synergized implementation and quarterly review of Centrally Sponsored Schemes (MGNREGA, PMGSY, PMAY, Jal Jeevan Mission, SBM, Ayushman Bharat). The senior-most Lok Sabha MP from the district is designated as the CHAIRPERSON. DISHA is strictly an oversight and coordination forum to identify execution bottlenecks; it does NOT confer individual executive command on the MP to terminate contractors, alter central guidelines, or issue administrative penalties against district officers.',
          answerHi:
              'जिला विकास समन्वय एवं निगरानी समिति (DISHA) केंद्रीय ग्रामीण विकास मंत्रालय के दिशा-निर्देशों के तहत गठित एक समन्वय व समीक्षा समिति है। यह मनरेगा, पीएमजीएसवाई, प्रधानमंत्री आवास, जल जीवन मिशन जैसी केंद्रीय योजनाओं की हर तिमाही समीक्षा करती है। जिले के वरिष्ठतम लोक सभा सांसद इसके अध्यक्ष होते हैं। दिशा समिति एक निगरानी व समीक्षा मंच है; इसके तहत सांसद को ठेकेदारों को सीधे हटाने, केंद्रीय योजना नियमों को बदलने या जिला अधिकारियों को प्रशासनिक दंड देने का कोई व्यक्तिगत कार्यकारी अधिकार नहीं है।',
        ),
      ],
      legalLimitationsEn: [
        'Has NO personal account receipt, custody, or cheque-signing authority over MPLADS funds; all sanctions and disbursements are executed strictly by the Nodal District Authority via PFMS.',
        'Cannot directly award tenders, hire private works contractors, or select commercial suppliers; works are executed through transparent public e-tendering by government line agencies.',
        'Possesses NO direct administrative or executive command over State Police, District Magistrates, Superintendents of Police, or local civil servants (without restricting lawful communication or public interest representations).',
        'Cannot order police officers to register, alter, or dismiss criminal FIRs or direct statutory investigation steps (CrPC / BNSS; CrPC Sec. 482 / BNSS Sec. 528); lawful representations on citizen hardship remain permissible.',
        'Possesses NO judicial or magisterial authority to adjudicate land titles, property boundaries, civil suits, or criminal court trials (Article 50).',
        'Cannot unilaterally transfer, suspend, or discipline state civil servants (doctors, teachers, patwaris, engineers); disciplinary authority belongs solely to state appointing authorities.',
        'Cannot override, cancel, or veto resolutions legally passed by autonomous Gram Panchayats, Panchayat Samitis, Zila Parishads, or Municipalities (Parts IX & IXA).',
        'Cannot recommend MPLADS works on private land, commercial properties, or places of worship / religious institutions.',
      ],
      legalLimitationsHi: [
        'सांसद निधि (MPLADS) का पैसा कभी भी सांसद के व्यक्तिगत बैंक खाते में नहीं आता और न ही सांसद के पास कोई चेक काटने का अधिकार है; सभी भुगतान जिला प्राधिकारी द्वारा PFMS के माध्यम से किए जाते हैं।',
        'सीधे किसी निजी ठेकेदार को काम सौंपने, टेंडर जारी करने या सामग्री खरीदने का कोई अधिकार नहीं है; कार्य सरकारी एजेंसियों द्वारा ई-टेंडरिंग से ही कराए जाते हैं।',
        'राज्य पुलिस, जिलाधिकारी (DM/DC), पुलिस अधीक्षक (SP) या स्थानीय कर्मचारियों पर कोई सीधा प्रशासनिक या कार्यकारी कमान अधिकार नहीं है (जनसमस्याओं पर औपचारिक पत्राचार या अभ्यावेदन की अनुमति है)।',
        'पुलिस को एफआईआर दर्ज करने, बदलने या हटाने का सीधा कानूनी आदेश नहीं दे सकते और न ही जांच में दखल दे सकते हैं (CrPC/BNSS); हालांकि पीड़ित नागरिकों की शिकायतें सक्षम अधिकारियों को अग्रेषित की जा सकती हैं।',
        'जमीन के मालिकाना हक, सीमा विवाद, दीवानी मामलों या आपराधिक मुकदमों में फैसला सुनाने का कोई न्यायिक या पुलिस अधिकार नहीं है (अनुच्छेद 50)।',
        'सरकारी कर्मचारियों (डॉक्टर, शिक्षक, पटवारी, इंजीनियर आदि) को सीधे निलंबित, दंडित या स्थानांतरित करने का अधिकार नहीं है।',
        'ग्राम पंचायतों, पंचायत समितियों, जिला परिषदों या नगर पालिकाओं द्वारा पारित वैधानिक प्रस्तावों को रद्द या वीटो करने का कोई अधिकार नहीं है (संविधान के भाग IX व IXA)।',
        'निजी भूमि, व्यावसायिक परिसरों या धार्मिक स्थलों/पूजा स्थलों पर सांसद निधि से कार्य कराने की सिफारिश नहीं की जा सकती।',
      ],
      grievanceEscalationEn:
          'Constituency Level: MP Public Hearing / Representation -> District Level: District Magistrate / DISHA Committee -> Parliamentary Level: Lok Sabha / Rajya Sabha Questions, Calling Attention & Committee on Petitions -> Presiding Officer (Speaker, Lok Sabha / Chairman, Rajya Sabha) -> National Oversight: Lokpal of India / Central Vigilance Commission (CVC) -> Judicial Remedy: High Court (Art. 226) / Supreme Court of India (Art. 32).',
      grievanceEscalationHi:
          'क्षेत्र स्तर: सांसद जनसुनवाई / मांग-पत्र -> जिला स्तर: जिलाधिकारी / दिशा (DISHA) समिति -> संसदीय स्तर: संसद में प्रश्न, ध्यानाकर्षण व याचिका समिति -> पीठासीन अधिकारी (अध्यक्ष, लोक सभा / सभापति, राज्य सभा) -> राष्ट्रीय निगरानी: भारत का लोकपाल / केंद्रीय सतर्कता आयोग (CVC) -> न्यायिक उपचार: उच्च न्यायालय (अनुच्छेद 226) / भारत का सर्वोच्च न्यायालय (अनुच्छेद 32)।',
      categories: [
        // ==========================================
        // 1. Parliamentary Structure, Legislation & Lawmaking Powers
        // ==========================================
        DutyCategorySection(
          category: DutyCategory.meetingsAndBudgets,
          customTitleEn: 'Parliamentary Structure, Legislation & Lawmaking Powers',
          customTitleHi: 'संसदीय संरचना, विधायी कार्य व कानून निर्माण शक्तियां',
          items: [
            DutyItem(
              titleEn: 'Enacting Union Legislation (Union List I & Concurrent List III)',
              titleHi: 'केंद्रीय कानून निर्माण (संघ सूची व समवर्ती सूची)',
              descriptionEn:
                  'Introduce, debate, move amendments to, and vote on all parliamentary legislative bills concerning defense, foreign affairs, atomic energy, banking, railways, national highways, telecommunications, and maritime trade (List I - Union List) and concurrent subjects (List III - education, civil procedure, forests) under Article 246 of the Constitution.',
              descriptionHi:
                  'संविधान के अनुच्छेद 246 के तहत संघ सूची (रक्षा, विदेश, रेलवे, राष्ट्रीय राजमार्ग, बैंकिंग, परमाणु ऊर्जा आदि) और समवर्ती सूची (शिक्षा, वन, नागरिक प्रक्रिया) के विषयों पर संसद में विधेयक पेश करना, बहस करना, संशोधन प्रस्ताव लाना और मतदान करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'Cannot unilaterally enact laws on State List II subjects (police, public order, agriculture, public health, local government) except under special constitutional circumstances (Art. 249 resolution by Rajya Sabha, Art. 250 emergency, Art. 252 consent of states).',
              limitationHi:
                  'राज्य सूची (सूची II) के विषयों (पुलिस, कानून-व्यवस्था, कृषि, स्वास्थ्य, स्थानीय निकाय) पर सामान्य परिस्थिति में कानून नहीं बना सकते (केवल अनुच्छेद 249, 250 या 252 की विशेष संवैधानिक परिस्थितियों को छोड़कर)।',
              lineDepartmentEn: 'Ministry of Law and Justice & Parliament Secretariat (Lok Sabha / Rajya Sabha)',
              lineDepartmentHi: 'विधि एवं न्याय मंत्रालय एवं संसद सचिवालय (लोक सभा / राज्य सभा)',
              procedureOrApprovalEn:
                  'Introduction in either House -> Three Readings -> Passage by simple majority -> Sent to other House -> Assent of the President of India (Article 111).',
              procedureOrApprovalHi:
                  'किसी भी सदन में प्रस्तुति -> तीन वाचन -> साधारण बहुमत से पारित -> दूसरे सदन में विचार -> भारत के राष्ट्रपति की स्वीकृति (अनुच्छेद 111)।',
              jurisdictionScopeEn: 'National / Union of India',
              jurisdictionScopeHi: 'राष्ट्रीय / संपूर्ण भारत',
              verificationStatusEn: statusLabelEn,
              verificationStatusHi: statusLabelHi,
              statutoryCitation:
                  'Constitution of India, Articles 107-111, 246, Seventh Schedule (https://www.legislative.gov.in/static/uploads/2025/08/cb1b190ea633a1746368ed1fac35fb30.pdf)',
            ),
            DutyItem(
              titleEn: 'Special Procedure for Money Bills (Lok Sabha Primacy under Art. 109)',
              titleHi: 'धन विधेयकों की विशेष प्रक्रिया (अनुच्छेद 109 के तहत लोक सभा का विशेषाधिकार)',
              descriptionEn:
                  'Money Bills (imposing taxes, regulating government borrowing, custody of the Consolidated Fund of India under Art. 110) can ONLY be introduced in Lok Sabha on the recommendation of the President (Art. 117(1)). Rajya Sabha cannot reject or amend a Money Bill; it can only return it with recommendations within 14 days, which Lok Sabha may accept or reject.',
              descriptionHi:
                  'धन विधेयक (कर लगाने, सरकारी ऋण, या भारत की संचित निधि से संबंधित, अनुच्छेद 110) राष्ट्रपति की सिफारिश पर केवल लोक सभा में पेश किए जा सकते हैं (अनुच्छेद 117(1))। राज्य सभा धन विधेयक को खारिज या संशोधित नहीं कर सकती; वह केवल 14 दिनों के भीतर सिफारिशों के साथ लौटा सकती है, जिसे स्वीकार या अस्वीकार करना लोक सभा पर निर्भर है।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'Rajya Sabha MPs have no power to vote against or defeat a Money Bill beyond the 14-day return period; the Speaker of Lok Sabha possesses sole and conclusive authority to certify whether a bill is a Money Bill (Art. 110(4)).',
              limitationHi:
                  'राज्य सभा सांसद 14 दिन की अवधि के बाद धन विधेयक को रोक या अस्वीकार नहीं कर सकते; कोई विधेयक धन विधेयक है या नहीं, इसे प्रमाणित करने का अंतिम और निर्णायक अधिकार लोक सभा अध्यक्ष (स्पीकर) के पास है (अनुच्छेद 110(4))।',
              lineDepartmentEn: 'Ministry of Finance & Lok Sabha Secretariat',
              lineDepartmentHi: 'वित्त मंत्रालय एवं लोक सभा सचिवालय',
              procedureOrApprovalEn:
                  'Recommendation of President (Art. 117(1)) -> Introduced in Lok Sabha -> Passed and Speaker Certificate (Art. 110(4)) -> Transmitted to Rajya Sabha (14-day limit) -> Assent of President (Art. 111).',
              procedureOrApprovalHi:
                  'राष्ट्रपति की पूर्व सिफारिश -> लोक सभा में पारित -> स्पीकर प्रमाणन -> राज्य सभा को प्रेषण (14 दिन की सीमा) -> राष्ट्रपति की स्वीकृति।',
              jurisdictionScopeEn: 'Union of India (Lok Sabha & Rajya Sabha)',
              jurisdictionScopeHi: 'भारत संघ (लोक सभा व राज्य सभा)',
              verificationStatusEn: statusLabelEn,
              verificationStatusHi: statusLabelHi,
              statutoryCitation:
                  'Constitution of India, Articles 109, 110, 117(1) (https://www.legislative.gov.in/static/uploads/2025/08/cb1b190ea633a1746368ed1fac35fb30.pdf)',
            ),
            DutyItem(
              titleEn: 'Enactment of Constitution Amendment Bills (Article 368)',
              titleHi: 'संविधान संशोधन विधेयक पारित करना (अनुच्छेद 368 - दोनों सदनों की समानता)',
              descriptionEn:
                  'Introduce and vote on bills amending the Constitution of India under Article 368. Must be passed in EACH House by a special majority (majority of total membership of the House AND not less than two-thirds of members present and voting). No provision exists for a joint sitting under Art. 108 if the Houses disagree.',
              descriptionHi:
                  'अनुच्छेद 368 के अंतर्गत संविधान संशोधन विधेयक पेश करना और उस पर मतदान करना। प्रत्येक सदन द्वारा विशेष बहुमत (सदन की कुल सदस्य संख्या का बहुमत तथा उपस्थित और मतदान करने वाले सदस्यों का कम से कम दो-तिहाई बहुमत) से अलग-अलग पारित होना अनिवार्य है। असहमति की स्थिति में संयुक्त बैठक (Joint Sitting) का कोई प्रावधान नहीं है।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'Cannot amend the Basic Structure of the Constitution (Kesavananda Bharati doctrine); federal amendments specified in Art. 368(2) proviso also require ratification by legislatures of not less than half of the States.',
              limitationHi:
                  'संविधान के मूल ढांचे (Basic Structure) में बदलाव नहीं कर सकते; अनुच्छेद 368(2) के अंतर्गत संघीय ढांचे से संबंधित संशोधनों के लिए कम से कम आधे राज्यों के विधान मंडलों द्वारा पुष्टि आवश्यक है।',
              lineDepartmentEn: 'Ministry of Law and Justice & Parliament Secretariat',
              lineDepartmentHi: 'विधि एवं न्याय मंत्रालय एवं संसद सचिवालय',
              procedureOrApprovalEn:
                  'Introduced in either House -> Passed by Special Majority in both Houses separately -> State Ratification (if federal) -> Assent of President (mandatory under Art. 368(2)).',
              procedureOrApprovalHi:
                  'किसी भी सदन में प्रस्तुति -> दोनों सदनों में अलग-अलग विशेष बहुमत से पारित -> राज्यों का अनुसमर्थन (यदि आवश्यक हो) -> राष्ट्रपति की अनिवार्य सहमति।',
              jurisdictionScopeEn: 'National / Constitutional',
              jurisdictionScopeHi: 'राष्ट्रीय / संवैधानिक',
              verificationStatusEn: statusLabelEn,
              verificationStatusHi: statusLabelHi,
              statutoryCitation:
                  'Constitution of India, Article 368 (https://www.legislative.gov.in/static/uploads/2025/08/cb1b190ea633a1746368ed1fac35fb30.pdf)',
            ),
            DutyItem(
              titleEn: 'Tabling Private Members\' Bills and Resolutions',
              titleHi: 'गैर-सरकारी विधेयक व संकल्प प्रस्तुत करना',
              descriptionEn:
                  'Any MP who is not a Union Minister can table Private Members\' Bills and non-official resolutions on designated sitting days (Friday afternoons) to propose national social reforms, labor protections, or policy amendments.',
              descriptionHi:
                  'केंद्रीय मंत्री के अलावा कोई भी सांसद निर्धारित दिनों (शुक्रवार अपराह्न) पर गैर-सरकारी विधेयक और संकल्प पेश कर सकते हैं, ताकि राष्ट्रीय सुधारों, श्रम अधिकारों या नए नीतिगत मुद्दों पर संसद का ध्यान आकर्षित किया जा सके।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'Subject to parliamentary balloting and Speaker/Chairman admission; cannot introduce a Private Member Money Bill or bill requiring expenditure without Presidential recommendation.',
              limitationHi:
                  'मतपत्र (बैलेट) और पीठासीन अधिकारी की स्वीकृति के अधीन; राष्ट्रपति की पूर्व सिफारिश के बिना खर्च या कर से संबंधित गैर-सरकारी विधेयक पेश नहीं किया जा सकता।',
              lineDepartmentEn: 'Secretariat of Lok Sabha / Rajya Sabha',
              lineDepartmentHi: 'लोक सभा / राज्य सभा सचिवालय',
              procedureOrApprovalEn:
                  'One month prior notice -> Ballot admission by Presiding Officer -> Friday afternoon debate in House.',
              procedureOrApprovalHi:
                  'एक माह पूर्व नोटिस -> पीठासीन अधिकारी द्वारा मतपत्र स्वीकृति -> शुक्रवार अपराह्न सदन में चर्चा।',
              jurisdictionScopeEn: 'Parliament of India',
              jurisdictionScopeHi: 'भारत की संसद',
              verificationStatusEn: 'Officially Verified Parliamentary Procedure',
              verificationStatusHi: 'आधिकारिक सत्यापित संसदीय प्रक्रिया',
              statutoryCitation:
                  'Rules of Procedure and Conduct of Business in Lok Sabha, Rules 65-73 (https://sansad.in/ls/rules); Rules of Procedure and Conduct of Business in the Council of States (Rajya Sabha), Rules 24-25, 62-67 (https://sansad.in/uploads/English_2052022english_3092021rules_pro_8efbe8ead1.pdf)',
            ),
          ],
        ),

        // ==========================================
        // 2. Union Budget, Financial Oversight & Public Accounts
        // ==========================================
        DutyCategorySection(
          category: DutyCategory.publicAssets,
          customTitleEn: 'Union Budget, Financial Oversight & Public Accounts',
          customTitleHi: 'केंद्रीय बजट, वित्तीय नियंत्रण व लोक लेखा समिति',
          items: [
            DutyItem(
              titleEn: 'Voting on Demands for Grants (Lok Sabha Exclusive Power under Art. 113)',
              titleHi: 'अनुदान मांगों पर मतदान (अनुच्छेद 113 के तहत लोक सभा का अनन्य अधिकार)',
              descriptionEn:
                  'Scrutinize the Annual Financial Statement (Union Budget) presented under Article 112. Under Article 113(2), ONLY the Lok Sabha has the constitutional power to vote on Demands for Grants (ministry-wise expenditures for defense, railways, agriculture, health) and move Cut Motions (Disapproval of Policy Cut, Economy Cut, Token Cut). Rajya Sabha discusses the budget but cannot vote on Demands for Grants.',
              descriptionHi:
                  'अनुच्छेद 112 के तहत प्रस्तुत वार्षिक वित्तीय विवरण (केंद्रीय बजट) की समीक्षा करना। अनुच्छेद 113(2) के अनुसार केवल लोक सभा को ही विभिन्न मंत्रालयों (रक्षा, रेलवे, कृषि, स्वास्थ्य आदि) की अनुदान मांगों पर मतदान करने और कटौती प्रस्ताव (नीति कटौती, मितव्ययिता कटौती, सांकेतिक कटौती) लाने का अधिकार है। राज्य सभा बजट पर केवल चर्चा कर सकती है, मतदान नहीं।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'MPs cannot increase the expenditure grant recommended by the President; Rajya Sabha MPs cannot vote on or reject Demands for Grants; charged expenditures (Art. 112(3)) are not submitted to the vote of Parliament.',
              limitationHi:
                  'सांसद राष्ट्रपति द्वारा अनुशंसित अनुदान राशि को बढ़ा नहीं सकते; राज्य सभा सांसद अनुदान मांगों पर मतदान नहीं कर सकते; भारत की संचित निधि पर भारित व्यय (अनुच्छेद 112(3)) पर मतदान नहीं होता।',
              lineDepartmentEn: 'Ministry of Finance (Department of Economic Affairs) & Lok Sabha Secretariat',
              lineDepartmentHi: 'वित्त मंत्रालय (आर्थिक कार्य विभाग) एवं लोक सभा सचिवालय',
              procedureOrApprovalEn:
                  'Budget Presentation -> General Discussion in both Houses -> Departmental Standing Committee Scrutiny -> Voting on Demands for Grants in Lok Sabha (Art. 113) -> Guillotine.',
              procedureOrApprovalHi:
                  'बजट प्रस्तुति -> सामान्य चर्चा -> विभागीय स्थायी समितियों द्वारा विस्तृत जांच -> लोक सभा में अनुदान मांगों पर मतदान -> गिलोटिन।',
              jurisdictionScopeEn: 'Union Financial Jurisdiction',
              jurisdictionScopeHi: 'केंद्रीय वित्तीय अधिकार क्षेत्र',
              verificationStatusEn: statusLabelEn,
              verificationStatusHi: statusLabelHi,
              statutoryCitation:
                  'Constitution of India, Articles 112, 113 (https://www.legislative.gov.in/static/uploads/2025/08/cb1b190ea633a1746368ed1fac35fb30.pdf); Rules of Procedure in Lok Sabha, Rules 204-219 (https://sansad.in/ls/rules)',
            ),
            DutyItem(
              titleEn: 'Statutory Passage of Appropriation Bill & Finance Act',
              titleHi: 'विनियोग विधेयक व वित्त अधिनियम का वैधानिक पारितीकरण',
              descriptionEn:
                  'Pass the Appropriation Bill under Article 114 authorizing lawful withdrawal of public money from the Consolidated Fund of India, and the annual Finance Bill giving statutory effect to taxation proposals, income tax slabs, customs, and excise rates under Article 265.',
              descriptionHi:
                  'अनुच्छेद 114 के तहत विनियोग विधेयक पारित करना जिससे भारत की संचित निधि से वैधानिक धन निकासी संभव होती है, तथा अनुच्छेद 265 के अंतर्गत वार्षिक वित्त विधेयक पारित कर आयकर, सीमा शुल्क व केंद्रीय करों को लागू करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'No tax can be levied and no money withdrawn from the Consolidated Fund except by authority of enacted Parliamentary law (Art. 114 & 265); an MP has no personal authority to draw cheques or divert treasury funds.',
              limitationHi:
                  'संसद द्वारा पारित कानून के बिना भारत की संचित निधि से एक भी रुपया नहीं निकाला जा सकता और न ही कोई कर लगाया जा सकता है; सांसद के पास कोई व्यक्तिगत चेक आहरण अधिकार नहीं है।',
              lineDepartmentEn: 'Ministry of Finance (Department of Revenue & Expenditure)',
              lineDepartmentHi: 'वित्त मंत्रालय (राजस्व एवं व्यय विभाग)',
              procedureOrApprovalEn:
                  'Passed by Lok Sabha -> Transmitted to Rajya Sabha as Money Bill -> Assent of President of India.',
              procedureOrApprovalHi:
                  'लोक सभा द्वारा पारित -> धन विधेयक के रूप में राज्य सभा को प्रेषण -> राष्ट्रपति की स्वीकृति।',
              jurisdictionScopeEn: 'Union of India',
              jurisdictionScopeHi: 'संपूर्ण भारत',
              verificationStatusEn: statusLabelEn,
              verificationStatusHi: statusLabelHi,
              statutoryCitation:
                  'Constitution of India, Article 114 (Appropriation), Article 265 (Taxes) (https://www.legislative.gov.in/static/uploads/2025/08/cb1b190ea633a1746368ed1fac35fb30.pdf)',
            ),
            DutyItem(
              titleEn: 'Financial Scrutiny via Public Accounts Committee (PAC) & CAG Audits',
              titleHi: 'लोक लेखा समिति (PAC) व सीएजी ऑडिट द्वारा वित्तीय जांच',
              descriptionEn:
                  'Serve as elected members on parliamentary financial committees (Public Accounts Committee - 22 members: 15 LS, 7 RS, conventionally chaired by Opposition; Estimates Committee - 30 members strictly from Lok Sabha; Committee on Public Undertakings - 22 members) to examine CAG audit reports (Art. 151(1)), investigate fiscal waste, and question ministry secretaries.',
              descriptionHi:
                  'संसदीय वित्तीय समितियों (लोक लेखा समिति - 22 सदस्य: 15 लोक सभा, 7 राज्य सभा, विपक्ष के नेता की अध्यक्षता में; प्राक्कलन समिति - 30 सदस्य केवल लोक सभा से; सार्वजनिक उपक्रम समिति - 22 सदस्य) में सदस्य के रूप में सीएजी (CAG) की ऑडिट रिपोर्ट की जांच करना और मंत्रालयों से वित्तीय जवाबदेही मांगना।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              limitationEn:
                  'Committees examine post-expenditure accounts and submit recommendatory reports; they do not possess executive judicial powers to directly sentence or dismiss errant officials.',
              limitationHi:
                  'समितियां खर्च के बाद वित्तीय जांच कर संसद को सिफारिश रिपोर्ट देती हैं; उनके पास अधिकारियों को सीधे दंडित या बर्खास्त करने का न्यायिक अधिकार नहीं है।',
              lineDepartmentEn: 'Comptroller and Auditor General of India (CAG) & Parliament Secretariats',
              lineDepartmentHi: 'भारत के नियंत्रक एवं महालेखापरीक्षक (CAG) एवं संसद सचिवालय',
              procedureOrApprovalEn:
                  'Elected annually by proportional representation via single transferable vote -> Ministry examination -> Reports tabled in Parliament -> Action Taken Reports.',
              procedureOrApprovalHi:
                  'आनुपातिक प्रतिनिधित्व द्वारा वार्षिक चुनाव -> विभागीय जांच -> संसद में रिपोर्ट प्रस्तुत -> सरकार द्वारा कृत कार्रवाई रिपोर्ट (ATR)।',
              jurisdictionScopeEn: 'Union Ministries and Public Sector Undertakings',
              jurisdictionScopeHi: 'केंद्रीय मंत्रालय व सार्वजनिक क्षेत्र के उपक्रम',
              verificationStatusEn: 'Officially Verified Parliamentary Procedure',
              verificationStatusHi: 'आधिकारिक सत्यापित संसदीय प्रक्रिया',
              statutoryCitation:
                  'Constitution of India, Article 151(1) (https://www.legislative.gov.in/static/uploads/2025/08/cb1b190ea633a1746368ed1fac35fb30.pdf); Rules of Procedure in Lok Sabha, Rules 308, 310, 312A (https://sansad.in/ls/rules)',
            ),
          ],
        ),

        // ==========================================
        // 3. Executive Accountability, Questions & Motions
        // ==========================================
        DutyCategorySection(
          category: DutyCategory.schemesAndBeneficiaries,
          customTitleEn: 'Executive Accountability, Questions & Motions',
          customTitleHi: 'कार्यपालिका की जवाबदेही, प्रश्नकाल व संसदीय प्रस्ताव',
          items: [
            DutyItem(
              titleEn: 'Question Hour (Starred/Unstarred) & Zero Hour Submissions',
              titleHi: 'प्रश्नकाल (तारांकित/अतारांकित) व शून्यकाल में सरकार से जवाबदेही',
              descriptionEn:
                  'Hold Union Ministers accountable during the first hour of parliamentary sittings (Question Hour). Submit Starred Questions (demanding oral answers and supplementary probing questions on the floor of the House) and Unstarred Questions (demanding detailed written statistical replies) regarding national highways, rail stoppages, defense procurement, fertilizer subsidies, and banking services. Raise pressing matters during Zero Hour (an uncodified parliamentary convention, distinguished from codified Question Hour and Rajya Sabha Special Mentions under Rules 180A-180E).',
              descriptionHi:
                  'संसद की बैठक के पहले घंटे (प्रश्नकाल) में केंद्रीय मंत्रियों से जवाब मांगना। राष्ट्रीय राजमार्गों, रेलवे ठहराव, उर्वरक सब्सिडी और केंद्रीय योजनाओं पर तारांकित प्रश्न (मौखिक उत्तर व पूरक प्रश्न) और अतारांकित प्रश्न (लिखित आंकड़े) लगाना। शून्यकाल (एक अलिखित व गैर-संहिताबद्ध संसदीय परंपरा, जो संहिताबद्ध प्रश्नकाल व राज्य सभा में नियम 180A-180E के विशेष उल्लेख से भिन्न है) में तात्कालिक जनहित के मुद्दे उठाना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'Questions must comply with admissibility rules under the Presiding Officer (cannot raise sub-judice matters, personal character allegations, or confidential national defense secrets without permission).',
              limitationHi:
                  'प्रश्न पीठासीन अधिकारी के नियमों के तहत स्वीकार्य होने चाहिए (अदालत में विचाराधीन मामलों या गोपनीय रक्षा मामलों पर प्रश्न नहीं पूछे जा सकते)।',
              lineDepartmentEn: 'Secretariat of Lok Sabha / Rajya Sabha & Respective Union Ministries',
              lineDepartmentHi: 'लोक सभा / राज्य सभा सचिवालय एवं संबंधित केंद्रीय मंत्रालय',
              procedureOrApprovalEn:
                  '15 days prior notice -> Balloting and Speaker/Chairman admission -> Answered on floor of House / laid on table.',
              procedureOrApprovalHi:
                  '15 दिन पूर्व नोटिस -> बैलेट व अध्यक्ष/सभापति द्वारा स्वीकृति -> सदन में मौखिक उत्तर / पटल पर लिखित उत्तर।',
              jurisdictionScopeEn: 'Union Ministries & Departments',
              jurisdictionScopeHi: 'केंद्रीय मंत्रालय व विभाग',
              verificationStatusEn: 'Officially Verified Parliamentary Procedure',
              verificationStatusHi: 'आधिकारिक सत्यापित संसदीय प्रक्रिया',
              statutoryCitation:
                  'Rules of Procedure and Conduct of Business in Lok Sabha, Rules 32-54 (Question Hour) (https://sansad.in/ls/rules); Rules of Procedure and Conduct of Business in the Council of States (Rajya Sabha), Rules 38-57 (Question Hour) & Rules 180A-180E (Special Mention; Zero Hour is an uncodified convention) (https://sansad.in/uploads/English_2052022english_3092021rules_pro_8efbe8ead1.pdf)',
            ),
            DutyItem(
              titleEn: 'Motion of No-Confidence (Exclusive to Lok Sabha under Art. 75(3) & Rule 198)',
              titleHi: 'अविश्वास प्रस्ताव (अनुच्छेद 75(3) व नियम 198 के तहत केवल लोक सभा का अधिकार)',
              descriptionEn:
                  'Under Article 75(3) of the Constitution, the Union Council of Ministers is collectively responsible SOLELY to the House of the People (Lok Sabha). Members of Lok Sabha can table a Motion of No-Confidence against the government under Rule 198 (supported by at least 50 members). If passed by a simple majority, the Prime Minister and Council of Ministers must resign. Rajya Sabha has NO power to move or vote on a motion of no-confidence.',
              descriptionHi:
                  'संविधान के अनुच्छेद 75(3) के तहत केंद्रीय मंत्रिपरिषद सामूहिक रूप से केवल लोक सभा के प्रति उत्तरदायी है। लोक सभा सदस्य नियम 198 के तहत सरकार के खिलाफ अविश्वास प्रस्ताव ला सकते हैं (कम से कम 50 सदस्यों का समर्थन अनिवार्य)। यदि प्रस्ताव बहुमत से पारित हो जाता है, तो प्रधानमंत्री व पूरी मंत्रिपरिषद को इस्तीफा देना पड़ता है। राज्य सभा में अविश्वास प्रस्ताव लाने का कोई अधिकार नहीं है।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'Strictly exclusive to Lok Sabha; Rajya Sabha MPs have no standing to move or vote on a motion of no-confidence; requires leave granted by at least 50 Lok Sabha members.',
              limitationHi:
                  'यह अधिकार केवल लोक सभा के पास है; राज्य सभा सांसद अविश्वास प्रस्ताव नहीं ला सकते; प्रस्ताव चर्चा के लिए स्वीकार होने हेतु कम से कम 50 लोक सभा सदस्यों का समर्थन आवश्यक है।',
              lineDepartmentEn: 'Prime Minister\'s Office, Union Cabinet & Lok Sabha Secretariat',
              lineDepartmentHi: 'प्रधानमंत्री कार्यालय, केंद्रीय मंत्रिमंडल एवं लोक सभा सचिवालय',
              procedureOrApprovalEn:
                  'Notice under Rule 198 -> Leave granted by at least 50 members -> Debate scheduled within 10 days -> Division/Voting in Lok Sabha.',
              procedureOrApprovalHi:
                  'नियम 198 के तहत नोटिस -> कम से कम 50 सदस्यों का समर्थन -> 10 दिन के भीतर बहस -> लोक सभा में मतदान।',
              jurisdictionScopeEn: 'Union Executive (Council of Ministers)',
              jurisdictionScopeHi: 'केंद्रीय कार्यपालिका (मंत्रिपरिषद)',
              verificationStatusEn: 'Officially Verified Constitutional Procedure',
              verificationStatusHi: 'आधिकारिक सत्यापित संवैधानिक प्रक्रिया',
              statutoryCitation:
                  'Constitution of India, Article 75(3) (https://www.legislative.gov.in/static/uploads/2025/08/cb1b190ea633a1746368ed1fac35fb30.pdf); Rules of Procedure in Lok Sabha, Rule 198 (https://sansad.in/ls/rules)',
            ),
            DutyItem(
              titleEn: 'Service on Department-related Parliamentary Standing Committees (DRSCs)',
              titleHi: 'विभागीय संसदीय स्थायी समितियों (DRSC) में विधायी दायित्व',
              descriptionEn:
                  'Serve as nominated members on 24 Department-related Parliamentary Standing Committees covering all Union Ministries (Defense, External Affairs, Home, Agriculture, Finance, Railways). Each committee has 31 members (21 from Lok Sabha, 10 from Rajya Sabha) to examine ministry budget estimates, review draft legislation, and scrutinize government implementation.',
              descriptionHi:
                  'सभी केंद्रीय मंत्रालयों (रक्षा, विदेश, गृह, कृषि, रेलवे आदि) के लिए गठित 24 विभागीय स्थायी समितियों में कार्य करना। प्रत्येक समिति में 31 सदस्य (21 लोक सभा से, 10 राज्य सभा से) होते हैं, जो मंत्रालयों की बजट मांगों, विधेयकों और सरकारी नीतियों की विस्तृत जांच करते हैं।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              limitationEn:
                  'Committees table advisory and recommendatory reports; they do not exercise daily administrative command over ministry civil servants or tender allocations.',
              limitationHi:
                  'समितियां सलाहकार व सिफारिश रिपोर्ट देती हैं; वे मंत्रालयों के दैनिक प्रशासनिक कार्यों या टेंडर निर्णयों में सीधा हस्तक्षेप नहीं कर सकतीं।',
              lineDepartmentEn: 'Secretariats of Lok Sabha & Rajya Sabha and Concerned Union Ministries',
              lineDepartmentHi: 'लोक सभा व राज्य सभा सचिवालय एवं संबंधित केंद्रीय मंत्रालय',
              procedureOrApprovalEn:
                  'Nominated by Speaker/Chairman -> Committee sittings and hearings -> Reports tabled in both Houses.',
              procedureOrApprovalHi:
                  'स्पीकर/सभापति द्वारा मनोनयन -> समिति बैठकें व गवाहियां -> दोनों सदनों में रिपोर्ट प्रस्तुत।',
              jurisdictionScopeEn: 'Union Ministries & Departments',
              jurisdictionScopeHi: 'केंद्रीय मंत्रालय व विभाग',
              verificationStatusEn: 'Officially Verified Parliamentary Procedure',
              verificationStatusHi: 'आधिकारिक सत्यापित संसदीय प्रक्रिया',
              statutoryCitation:
                  'Rules of Procedure and Conduct of Business in Lok Sabha, Rules 331C-331N (https://sansad.in/ls/rules)',
            ),
          ],
        ),

        // ==========================================
        // 4. Constituency Representation & Central Ministry Advocacy
        // ==========================================
        DutyCategorySection(
          category: DutyCategory.socialSectorCoordination,
          customTitleEn: 'Constituency Representation & Central Ministry Advocacy',
          customTitleHi: 'संसदीय क्षेत्र प्रतिनिधित्व व केंद्रीय मंत्रालय संपर्क',
          items: [
            DutyItem(
              titleEn: 'Public Grievance Hearings & Representations to Central Ministries',
              titleHi: 'संसदीय कार्यालय में जनसुनवाई व केंद्रीय मंत्रालयों को मांग-पत्र',
              descriptionEn:
                  'Maintain a public constituency office to receive citizen delegations and memorandums. Issue formal demi-official (D.O.) recommendatory letters to Union Ministries (Railways for train stoppages and ROBs, MoRTH for national highway bypasses, Civil Aviation, Communications/BSNL, Home Affairs). Representations are a legitimate channel of public advocacy and grievance redressal under official administrative protocol: under Central Secretariat Manual of Office Procedure (CSMOP Paras 8.8-8.9) incorporated in DoPT consolidated guidelines, communications are to receive an acknowledgment within 15 days, followed by a reply within the next 15 days after acknowledgment, or an interim reply within 15 days from receipt where a final reply is expected to be delayed. These administrative timelines guide internal departmental handling and courtesy, but do not constitute a legally enforceable command or statutory directive.',
              descriptionHi:
                  'संसदीय क्षेत्र में कार्यालय संचालित कर नागरिकों की समस्याएं सुनना। रेलवे स्टॉपेज, ओवरब्रिज, राष्ट्रीय राजमार्ग (NH), दूरसंचार, डाक सेवाओं व केंद्रीय विद्यालयों के लिए केंद्रीय मंत्रालयों व सचिवों को आधिकारिक मांग-पत्र (D.O. Letters) भेजना। यह प्रशासनिक प्रोटोकॉल के तहत लोक प्रतिनिधित्व का वैध माध्यम है: डीओपीटी समेकित दिशा-निर्देशों में शामिल केंद्रीय सचिवालय कार्यालय पद्धति नियमावली (CSMOP पैरा 8.8-8.9) के अनुसार 15 दिनों के भीतर पावती, पावती के बाद अगले 15 दिनों में अंतिम उत्तर, और जहां विलंब संभावित हो वहां प्राप्ति से 15 दिनों के भीतर अंतरिम उत्तर देने का प्रशासनिक मार्गदर्शन है। यह आंतरिक शिष्टाचार व निपटान प्रोटोकॉल है, कोई कानूनी रूप से बाध्यकारी आदेश नहीं।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              additionalResponsibilityTypes: [ResponsibilityType.departmentalResponsibility],
              limitationEn:
                  'Representations and D.O. letters are recommendatory and persuasive advocacy; an MP possesses NO executive command authority to compel a Central Ministry or departmental head to violate statutory rules, alter administrative contracts, or sanction uneconomic projects.',
              limitationHi:
                  'मांग-पत्र व डी.ओ. पत्र केवल अनुशंसात्मक अभ्यावेदन हैं; सांसद के पास किसी केंद्रीय मंत्रालय या विभागाध्यक्ष को नियमों के विरुद्ध कार्य करने या सीधे प्रशासनिक आदेश देने की कोई कार्यकारी शक्ति नहीं है।',
              representativeRoleEn: 'Holds weekly public hearings, listens to citizen delegations, and forwards signed demi-official representations to competent Union ministers and secretaries.',
              representativeRoleHi: 'संसदीय कार्यालय में जनसुनवाई करते हैं, जनता के ज्ञापन लेते हैं और केंद्रीय मंत्रियों व सचिवों को आधिकारिक सिफारिशी पत्र (D.O. Letters) भेजते हैं।',
              activitiesIncludedEn: 'Drafting D.O. letters on train stoppages, NHAI bypasses, and rural post offices; tracking ministerial acknowledgment and replies under CSMOP timelines.',
              activitiesIncludedHi: 'ट्रेन ठहराव, आरओबी निर्माण, राष्ट्रीय राजमार्ग बाईपास व दूरसंचार टॉवर हेतु मांग-पत्र तैयार करना और सीएसएमओपी नियमों के तहत मंत्रालयों से फॉलो-अप लेना।',
              intendedResultEn: 'Direct citizen voice reaching top national decision-makers in New Delhi and prompt redressal of constituency infrastructure grievances.',
              intendedResultHi: 'संसदीय क्षेत्र की बुनियादी समस्याओं की दिल्ली के शीर्ष नीति-निर्माताओं तक सीधी पहुंच और जनसमस्याओं का समयबद्ध समाधान।',
              practicalProcessEn:
                  'Citizen representation -> MP recommendatory letter -> Administrative processing under DoPT/CSMOP guidelines (15-day acknowledgment, reply within next 15 days, or interim reply within 15 days if delayed).',
              practicalProcessHi:
                  'नागरिक मांग-पत्र -> सांसद का अनुशंसा पत्र -> डीओपीटी/सीएसएमओपी दिशा-निर्देशों के तहत प्रशासनिक कार्रवाई (15 दिन में पावती, पावती के बाद अगले 15 दिन में उत्तर, या विलंब पर 15 दिन में अंतरिम उत्तर)।',
              verificationEvidenceEn: 'Official MP letterhead dispatch diary entry, Ministry speed-post acknowledgment, and formal reply letter from the Union Minister or Secretary.',
              verificationEvidenceHi: 'सांसद कार्यालय जावक (dispatch) रजिस्टर प्रविष्टि, मंत्रालय से प्राप्त पावती रसीद और केंद्रीय मंत्री या सचिव द्वारा भेजा गया आधिकारिक जवाब।',
              jurisdictionScopeEn: 'Parliamentary Constituency & Union Ministries',
              jurisdictionScopeHi: 'संसदीय क्षेत्र व केंद्रीय मंत्रालय',
              verificationStatusEn: 'Central Administrative Protocol (Informational Representation Guidance)',
              verificationStatusHi: 'केंद्रीय प्रशासनिक प्रोटोकॉल (सूचनात्मक प्रतिनिधित्व मार्गदर्शन)',
              statutoryCitation:
                  'DoPT Consolidated Guidelines on Official Dealings with MPs & MLAs, O.M. F. No. 11013/14/2022-Estt.A-III dated 13.09.2022 (incorporating CSMOP 2019 Paras 8.8-8.9: 15-day acknowledgment, reply within next 15 days, interim reply within 15 days; consolidating O.M. No. 11013/4/2011-Estt.(A)) (https://dopt.gov.in/sites/default/files/Official_dealing_consolidation13092022.pdf); DARPG O.M. No. 48013/1/2011-O&M & CSMOP Chapter on Correspondence with MPs (prompt disposal; standalone DARPG PDF pending active portal hosting)',
            ),
            DutyItem(
              titleEn: 'Submitting Citizen Petitions to Parliament Committee on Petitions',
              titleHi: 'संसद की याचिका समिति में नागरिक याचिकाएं पेश करना',
              descriptionEn:
                  'Present formal petitions signed by citizens on major public grievances (national highway corridor issues, broad gauge railway conversions, central hospital facilities) to the Committee on Petitions of Lok Sabha or Rajya Sabha for formal parliamentary inquiry.',
              descriptionHi:
                  'राष्ट्रीय राजमार्ग, रेल लाइन दोहरीकरण या केंद्रीय स्वास्थ्य संस्थानों से जुड़ी जनता की सामूहिक याचिकाओं को संसद की याचिका समिति (Committee on Petitions) के समक्ष औपचारिक जांच हेतु प्रस्तुत करना।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'Petitions concerning sub-judice legal disputes, individual service/disciplinary cases, or state subject disputes are inadmissible under parliamentary rules.',
              limitationHi:
                  'न्यायालय में विचाराधीन मामलों, कर्मचारियों के व्यक्तिगत विवादों या विशुद्ध राज्य सूची के मामलों पर याचिका स्वीकार नहीं की जा सकती।',
              lineDepartmentEn: 'Committee on Petitions, Lok Sabha / Rajya Sabha Secretariat',
              lineDepartmentHi: 'याचिका समिति, लोक सभा / राज्य सभा सचिवालय',
              procedureOrApprovalEn:
                  'Signed by citizens -> Countersigned and presented by MP -> Examined by Petitions Committee -> Recommendations tabled in Parliament.',
              procedureOrApprovalHi:
                  'नागरिकों द्वारा हस्ताक्षर -> सांसद द्वारा प्रतिहस्ताक्षरित व प्रस्तुत -> याचिका समिति द्वारा जांच -> संसद में सिफारिश रिपोर्ट।',
              jurisdictionScopeEn: 'National / Parliament of India',
              jurisdictionScopeHi: 'राष्ट्रीय / भारत की संसद',
              verificationStatusEn: 'Officially Verified Parliamentary Procedure',
              verificationStatusHi: 'आधिकारिक सत्यापित संसदीय प्रक्रिया',
              statutoryCitation:
                  'Rules of Procedure and Conduct of Business in Lok Sabha, Rules 160-179 (https://sansad.in/ls/rules); Rules of Procedure and Conduct of Business in the Council of States (Rajya Sabha), Rules 137-153 (https://sansad.in/uploads/English_2052022english_3092021rules_pro_8efbe8ead1.pdf)',
            ),
            DutyItem(
              titleEn: 'Recommending Medical Assistance from Prime Minister\'s National Relief Fund',
              titleHi: 'प्रधानमंत्री राष्ट्रीय राहत कोष (PMNRF) से चिकित्सा सहायता की अनुशंसा',
              descriptionEn:
                  'Forward and recommend hardship applications of indigent citizens suffering from major life-threatening ailments (cancer, heart surgery, organ transplant, kidney failure) for discretionary grant sanctions from the Prime Minister\'s National Relief Fund (PMNRF). Under the published PMNRF framework (https://pmnrf.gov.in/en/about), relief is disbursed at the sole discretion of the Prime Minister entirely from voluntary contributions; while citizen requests are conventionally forwarded with an MP\'s letterhead recommendation to the Prime Minister\'s Office (PMO), an MP has NO statutory sanctioning power, quota, fund custody, or binding entitlement under PMNRF.',
              descriptionHi:
                  'गंभीर बीमारियों (कैंसर, हृदय रोग, किडनी प्रत्यारोपण आदि) से पीड़ित गरीब नागरिकों के इलाज के लिए प्रधानमंत्री राष्ट्रीय राहत कोष (PMNRF) से सहायता हेतु आवेदन अग्रेषित व अनुशंसित करना। प्रकाशित पीएमएनआरएफ रूपरेखा (pmnrf.gov.in/en/about) के अनुसार राहत पूर्णतः प्रधानमंत्री के विवेकानुसार दी जाती है; सांसद के पत्र पर सिफारिश पारंपरिक रूप से भेजी जाती है, परंतु सांसद के पास कोई वैधानिक कोटा, स्वीकृति शक्ति या फंड आहरण अधिकार नहीं है।',
              responsibilityType: ResponsibilityType.requiresApproval,
              limitationEn:
                  'Grants are sanctioned exclusively at the discretion of the PMO under federal relief guidelines; an MP holds no individual sanctioning quota and funds are disbursed directly to the empanelled hospital, never through the MP or in cash.',
              limitationHi:
                  'सहायता केवल पीएमओ के विवेकानुसार संघीय राहत दिशा-निर्देशों के तहत सीधे अस्पताल को दी जाती है; सांसद के पास कोई व्यक्तिगत कोटा या चेक आहरण अधिकार नहीं है।',
              lineDepartmentEn: 'Prime Minister\'s Office (PMO) & Empanelled Hospitals',
              lineDepartmentHi: 'प्रधानमंत्री कार्यालय (PMO) एवं सूचीबद्ध अस्पताल',
              procedureOrApprovalEn:
                  'Citizen hospital estimate -> MP forwarding & recommendation letter -> Administrative scrutiny by PMO -> Direct fund transfer to hospital account.',
              procedureOrApprovalHi:
                  'अस्पताल का प्राक्कलन -> सांसद का अनुशंसा पत्र -> पीएमओ द्वारा जांच -> सीधे अस्पताल के बैंक खाते में भुगतान।',
              jurisdictionScopeEn: 'National / PMO Discretionary Relief',
              jurisdictionScopeHi: 'राष्ट्रीय / पीएमओ विवेकाधीन राहत',
              verificationStatusEn: 'Discretionary Central Relief (MP Recommendation Procedure Pending Verification)',
              verificationStatusHi: 'विवेकाधीन केंद्रीय राहत (सांसद सिफारिश प्रक्रिया सत्यापन लंबित)',
              statutoryCitation:
                  'Prime Minister\'s National Relief Fund (PMNRF) Operating Framework (https://pmnrf.gov.in/en/about); specific MP recommendation protocol pending primary gazetted verification',
            ),
          ],
        ),

        // ==========================================
        // 5. MPLADS Scheme & District Development Coordination (DISHA)
        // ==========================================
        DutyCategorySection(
          category: DutyCategory.welfareAndDisaster,
          customTitleEn: 'MPLADS Scheme & District Development Coordination (DISHA)',
          customTitleHi: 'सांसद निधि (MPLADS) व जिला विकास समन्वय (DISHA)',
          items: [
            DutyItem(
              titleEn: 'Recommending Works under MPLADS (₹5 Crore/Year Scheme Allocation & Territorial Slabs)',
              titleHi: 'सांसद स्थानीय क्षेत्र विकास योजना (MPLADS - ₹5 करोड़ वार्षिक योजना आवंटन व क्षेत्रीय सीमाएं)',
              descriptionEn:
                  'Recommend eligible durable public community assets (drinking water plants, public school classrooms, government hospital equipment, community halls, solar streetlights) within the annual scheme allocation limit of ₹5 Crore per annum under MoSPI Guidelines (authorized via the web-based e-SAKSHI portal under revised fund-flow procedures, transitioning from the earlier bi-annual ₹2.5 Crore installments). Territorial recommendation rules: Lok Sabha MP recommends works strictly within their Parliamentary Constituency; elected Rajya Sabha MP recommends in one or more districts of the State from which elected; Nominated MP (Lok Sabha or Rajya Sabha) may select one or more districts from any one State in the country of their choice for implementation of eligible works under Para 2.5 of the Guidelines. Mandatory reservation: At least 15% of annual funds must be utilized in Scheduled Caste (SC) areas and 7.5% in Scheduled Tribe (ST) areas.',
              descriptionHi:
                  'सांख्यिकी व कार्यक्रम कार्यान्वयन मंत्रालय (MoSPI) के दिशा-निर्देशों के तहत प्रतिवर्ष ₹5 करोड़ की योजना आवंटन सीमा (ई-साक्षी / e-SAKSHI वेब पोर्टल अधिकृत, पूर्व में ₹2.5 करोड़ की दो किस्तों में) में टिकाऊ सार्वजनिक संपत्तियों (पेयजल, स्कूल कमरे, अस्पताल उपकरण, सामुदायिक भवन आदि) की अनुशंसा करना। क्षेत्रीय नियम: लोक सभा सांसद अपने संसदीय क्षेत्र में; निर्वाचित राज्य सभा सांसद अपने राज्य के एक या अधिक जिलों में; और मनोनीत सांसद (लोक सभा या राज्य सभा) देश के किसी भी एक राज्य के भीतर एक या अधिक जिलों का चयन कर सिफारिश कर सकते हैं (दिशा-निर्देश पैरा 2.5)। अनिवार्य आरक्षण: कम से कम 15% राशि अनुसूचित जाति (SC) और 7.5% राशि अनुसूचित जनजाति (ST) क्षेत्रों में खर्च होना अनिवार्य है।',
              responsibilityType: ResponsibilityType.requiresApproval,
              additionalResponsibilityTypes: [],
              limitationEn:
                  'MPs possess ONLY recommendatory authority; funds are NEVER credited to an MP\'s personal account; MPs CANNOT issue tenders, hire private contractors, or sign payment cheques; private/commercial land, religious places, and prohibited works under Annexure-II are strictly barred.',
              limitationHi:
                  'सांसद के पास केवल सिफारिश (recommendation) का अधिकार है; फंड कभी भी सांसद के निजी खाते में नहीं आता; सांसद सीधे टेंडर जारी नहीं कर सकते, निजी ठेकेदार नहीं रख सकते और न ही चेक काट सकते हैं; निजी भूमि, धार्मिक स्थलों या परिशिष्ट-II के तहत निषिद्ध कार्य पूर्णतः वर्जित हैं।',
              lineDepartmentEn:
                  'Ministry of Statistics and Programme Implementation (MoSPI) & Nodal District Authority (DC/DM/Collector)',
              lineDepartmentHi:
                  'सांख्यिकी एवं कार्यक्रम कार्यान्वयन मंत्रालय (MoSPI) एवं नोडल जिला प्राधिकारी (उपायुक्त/जिलाधिकारी/कलेक्टर)',
              representativeRoleEn: 'Recommends community works digitally through the e-SAKSHI portal up to ₹5 Crore annually; does not select contractors or disburse cheques.',
              representativeRoleHi: 'ई-साक्षी (e-SAKSHI) पोर्टल के माध्यम से ₹5 करोड़ तक के सामुदायिक कार्यों की ऑनलाइन सिफारिश करते हैं; सीधे ठेकेदार चुनने या चेक काटने का अधिकार नहीं है।',
              activitiesIncludedEn: 'Submitting work recommendations on e-SAKSHI, inspecting completed public assets, reviewing quarterly utilization statements from the District Collector.',
              activitiesIncludedHi: 'ई-साक्षी पोर्टल पर कार्य प्रस्ताव दर्ज करना, पूरे हुए सार्वजनिक कार्यों का निरीक्षण और जिलाधिकारी से त्रैमासिक उपयोग प्रमाण पत्र (UC) की समीक्षा।',
              intendedResultEn: 'Creation of high-utility community infrastructure (water treatment, schools, roads, medical diagnostic units) meeting local voter priorities.',
              intendedResultHi: 'पेयजल, शिक्षा, सड़क और स्वास्थ्य जैसे क्षेत्रों में जनता की जरूरत के अनुसार टिकाऊ सामुदायिक परिसंपत्तियों का निर्माण।',
              practicalProcessEn:
                  'MP recommendation via e-SAKSHI portal -> Implementing District Authority feasibility scrutiny & sanction (Para 4.3.2) -> E-Tendering and execution by government line agency -> Payment via PFMS/MPLADS portal directly to executing agency.',
              practicalProcessHi:
                  'ई-साक्षी पोर्टल द्वारा सांसद की सिफारिश -> जिला प्राधिकारी द्वारा जांच व प्रशासनिक स्वीकृति (पैरा 4.3.2) -> सरकारी एजेंसी द्वारा ई-टेंडरिंग -> सीधे कार्यदायी एजेंसी को PFMS द्वारा भुगतान।',
              verificationEvidenceEn: 'e-SAKSHI portal work sanction order, District Collector administrative approval letter, and public asset plaque with MP name and project cost.',
              verificationEvidenceHi: 'ई-साक्षी पोर्टल स्वीकृति आदेश, जिलाधिकारी का प्रशासनिक स्वीकृति पत्र और स्थल पर लगा शिलापट्ट जिस पर कार्य का नाम व लागत अंकित हो।',
              jurisdictionScopeEn: 'Lok Sabha: Constituency; Rajya Sabha: State Districts; Nominated: Districts in Any One State',
              jurisdictionScopeHi: 'लोक सभा: संसदीय क्षेत्र; राज्य सभा: संबंधित राज्य के जिले; मनोनीत: किसी एक राज्य के जिले',
              verificationStatusEn: 'Officially Verified Central Scheme Guideline',
              verificationStatusHi: 'आधिकारिक सत्यापित केंद्रीय योजना दिशा-निर्देश',
              statutoryCitation:
                  'MoSPI, Government of India, Revised MPLADS Guidelines 2023 (Effective 1 April 2023), Chapters 2 (Para 2.5), 4 (Para 4.3.2), 5 & Annexure-II (https://www.mplads.gov.in/MPLADS/UploadedFiles/MPLADSGuidelines2023_English_.pdf)',
            ),
            DutyItem(
              titleEn: 'Chairing / Participating in District Monitoring Committee (DISHA)',
              titleHi: 'जिला विकास समन्वय एवं निगरानी समिति (DISHA) की अध्यक्षता / सदस्यता',
              descriptionEn:
                  'Under Ministry of Rural Development Guidelines, the senior-most Lok Sabha MP elected from the district is designated as the CHAIRPERSON of the DISHA Committee (other Lok Sabha and Rajya Sabha MPs serve as Co-Chairpersons/Members; all district MLAs, Zila Parishad Chairpersons, Mayors, and the District Collector as Member-Secretary participate). The committee conducts quarterly reviews of Centrally Sponsored Schemes (MGNREGA, PMGSY, PMAY, Jal Jeevan Mission, SBM, Ayushman Bharat, Samagra Shiksha) to eliminate implementation bottlenecks and ensure fund utilization.',
              descriptionHi:
                  'केंद्रीय ग्रामीण विकास मंत्रालय के दिशा-निर्देशों के अनुसार जिले से निर्वाचित वरिष्ठतम लोक सभा सांसद दिशा (DISHA) समिति के अध्यक्ष होते हैं (अन्य सांसद सह-अध्यक्ष/सदस्य; सभी विधायक, जिला प्रमुख, महापौर व कलेक्टर सदस्य-सचिव होते हैं)। समिति हर तिमाही मनरेगा, पीएमजीएसवाई, प्रधानमंत्री आवास, जल जीवन मिशन, स्वच्छ भारत व आयुष्मान भारत जैसी केंद्रीय योजनाओं की प्रगति व गुणवत्ता की समीक्षा करती है।',
              responsibilityType: ResponsibilityType.collectiveResponsibility,
              additionalResponsibilityTypes: [ResponsibilityType.departmentalResponsibility],
              limitationEn:
                  'DISHA is an oversight and coordination committee; an MP has NO executive authority to suspend district officials, cancel administrative contracts, or alter central scheme operational rules.',
              limitationHi:
                  'दिशा केवल समन्वय व निगरानी समिति है; सांसद के पास जिला अधिकारियों को निलंबित करने, अनुबंध रद्द करने या केंद्रीय योजना के नियमों को बदलने की कोई सीधी प्रशासनिक शक्ति नहीं है।',
              lineDepartmentEn: 'Ministry of Rural Development (GoI), District Collector & Zila Parishad',
              lineDepartmentHi: 'ग्रामीण विकास मंत्रालय (भारत सरकार), जिला कलेक्टर एवं जिला परिषद',
              representativeRoleEn: 'Chairs or participates in quarterly district coordination meetings to monitor implementation speed of Centrally Sponsored Schemes.',
              representativeRoleHi: 'जिले में केंद्रीय योजनाओं की गति और गुणवत्ता की निगरानी के लिए त्रैमासिक दिशा बैठक की अध्यक्षता या सहभागिता करते हैं।',
              activitiesIncludedEn: 'Reviewing progress indicators of MGNREGA, PMGSY, PMAY, and Jal Jeevan Mission; recording agency delays; issuing monitoring observations.',
              activitiesIncludedHi: 'मनरेगा, पीएमजीएसवाई, जल जीवन मिशन व आयुष्मान भारत की प्रगति देखना, कार्य में देरी पर संबंधित अधिकारियों से स्पष्टीकरण मांगना।',
              intendedResultEn: 'Synergy between central funding and district execution, ending red-tape and expediting infrastructure for citizens.',
              intendedResultHi: 'केंद्रीय बजट और जिला प्रशासन के बीच तालमेल, जिससे योजनाओं की बाधाएं दूर हों और जनता को समय पर विकास का लाभ मिले।',
              practicalProcessEn:
                  'Quarterly committee meetings -> Joint inspection of bottlenecks -> Minutes submitted to Ministry of Rural Development and State Government.',
              practicalProcessHi:
                  'त्रैमासिक बैठकें -> कार्यों का संयुक्त निरीक्षण -> बैठक कार्यवृत्त राज्य व ग्रामीण विकास मंत्रालय को प्रेषित।',
              verificationEvidenceEn: 'DISHA meeting minutes signed by Chairperson, published on disha.gov.in portal.',
              verificationEvidenceHi: 'अध्यक्ष द्वारा हस्ताक्षरित दिशा बैठक कार्यवृत्त, जो disha.gov.in पोर्टल पर सार्वजनिक रूप से उपलब्ध होता है।',
              jurisdictionScopeEn: 'District Administrative Jurisdiction',
              jurisdictionScopeHi: 'जिला प्रशासनिक अधिकार क्षेत्र',
              verificationStatusEn: 'Central Executive Guideline (Gazette Order Verification Pending)',
              verificationStatusHi: 'केंद्रीय कार्यकारी दिशा-निर्देश (राजपत्र आदेश सत्यापन लंबित)',
              statutoryCitation:
                  'Ministry of Rural Development, Order No. Q-13016/1/2016-DISHA (Dated 28 June 2016 cited; primary signed gazetted order pending verification) & DISHA Operational Guidelines (https://disha.gov.in/guidelines)',
            ),
          ],
        ),

        // ==========================================
        // 6. Constitutional Electoral Functions, Removals & Legal Limits
        // ==========================================
        DutyCategorySection(
          category: DutyCategory.legalLimitsAndExclusions,
          customTitleEn: 'Constitutional Electoral Functions, Removals & Legal Limits',
          customTitleHi: 'संवैधानिक चुनावी कार्य, पदमुक्ति प्रक्रियाएं व कानूनी सीमाएं',
          items: [
            DutyItem(
              titleEn: 'Voting in Presidential & Vice-Presidential Elections (Constitutional Distinctions)',
              titleHi: 'राष्ट्रपति व उपराष्ट्रपति चुनावों में मतदान (संवैधानिक निर्वाचक मंडल का अंतर)',
              descriptionEn:
                  'Exercise constitutional voting rights in national high-office elections: 1) President of India (Articles 54, 55): Electoral College consists of ELECTED members of both Houses of Parliament (MPs) AND ELECTED members of State Legislative Assemblies (MLAs); nominated MPs, nominated MLAs, and Legislative Council members (MLCs) CANNOT vote. 2) Vice-President of India (Article 66): Electoral College consists of members of BOTH Houses of Parliament (Lok Sabha & Rajya Sabha) ONLY, INCLUDING nominated members! MLAs and MLCs DO NOT vote in Vice-Presidential elections.',
              descriptionHi:
                  'संवैधानिक चुनावों में मताधिकार का प्रयोग: 1) भारत के राष्ट्रपति का चुनाव (अनुच्छेद 54 व 55): निर्वाचक मंडल में संसद के दोनों सदनों के केवल निर्वाचित सदस्य (सांसद) और राज्यों के निर्वाचित विधायक (MLA) शामिल होते हैं; मनोनीत सांसद/विधायक और विधान परिषद सदस्य (MLC) मतदान नहीं कर सकते। 2) उपराष्ट्रपति का चुनाव (अनुच्छेद 66): निर्वाचक मंडल में संसद के दोनों सदनों के सभी सदस्य (निर्वाचित व मनोनीत सांसद) शामिल होते हैं; इसमें राज्यों के विधायक या एमएलसी मतदान नहीं करते।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'Nominated MPs cannot vote in Presidential elections; MPs cannot vote on party whip in Presidential/Vice-Presidential elections (secret ballot under Presidential and Vice-Presidential Elections Act, 1952).',
              limitationHi:
                  'मनोनीत सांसद राष्ट्रपति चुनाव में मतदान नहीं कर सकते; राष्ट्रपति व उपराष्ट्रपति चुनाव गुप्त मतदान द्वारा होते हैं जिसमें पार्टी व्हिप लागू नहीं होता।',
              lineDepartmentEn: 'Election Commission of India & Returning Officer (Secretary-General, Parliament)',
              lineDepartmentHi: 'भारत निर्वाचन आयोग एवं निर्वाचन अधिकारी (महासचिव, लोक सभा / राज्य सभा)',
              procedureOrApprovalEn:
                  'Secret ballot voting via proportional representation by means of single transferable vote (Arts. 55 & 66).',
              procedureOrApprovalHi:
                  'एकल संक्रमणीय मत द्वारा आनुपातिक प्रतिनिधित्व से गुप्त मतदान (अनुच्छेद 55 व 66)।',
              jurisdictionScopeEn: 'National / Constitutional Electoral College',
              jurisdictionScopeHi: 'राष्ट्रीय / संवैधानिक निर्वाचक मंडल',
              verificationStatusEn: 'Officially Verified Constitutional Law',
              verificationStatusHi: 'आधिकारिक सत्यापित संवैधानिक कानून',
              statutoryCitation:
                  'Constitution of India, Articles 54, 55, 66 (https://www.legislative.gov.in/static/uploads/2025/08/cb1b190ea633a1746368ed1fac35fb30.pdf); Presidential and Vice-Presidential Elections Act, 1952',
            ),
            DutyItem(
              titleEn: 'Constitutional Removal Procedures (Distinct Impeachment / Address Provisions)',
              titleHi: 'संवैधानिक पदमुक्ति प्रक्रियाएं (महाभियोग व प्रस्तावों में कानूनी अंतर)',
              descriptionEn:
                  'Participate in distinct constitutional removal procedures according to specified constitutional standards: 1) President of India: Impeached under Article 61 ONLY on the ground of "violation of the Constitution" by a two-thirds majority of the TOTAL MEMBERSHIP of each House. 2) Vice-President of India: Removed under Article 67(b) by a resolution initiated in Rajya Sabha passed by an effective majority (majority of then members) and agreed to by Lok Sabha. 3) Supreme Court / High Court Judges: Removed by Presidential order following an address by both Houses under Article 124(4)/217 on grounds of "proved misbehaviour or incapacity", requiring a special majority (majority of total membership AND 2/3 present and voting in each House) after statutory investigation under Judges (Inquiry) Act, 1968. 4) CAG and CEC: The Comptroller and Auditor General (Art. 148(1)) and ONLY the Chief Election Commissioner (Art. 324(5) first proviso) are removed in like manner and on like grounds as a Supreme Court Judge; other Election Commissioners have no such parliamentary address protection and can be removed by the President upon the recommendation of the CEC (Art. 324(5) second proviso).',
              descriptionHi:
                  'संवैधानिक पदों की पदमुक्ति में भाग लेना: 1) राष्ट्रपति पर महाभियोग (अनुच्छेद 61): केवल "संविधान के उल्लंघन" के आधार पर दोनों सदनों की कुल सदस्य संख्या के 2/3 बहुमत से। 2) उपराष्ट्रपति को हटाना (अनुच्छेद 67(b)): राज्य सभा में प्रस्तुत प्रस्ताव जो तत्कालीन सदस्यों के बहुमत से पारित हो और लोक सभा सहमत हो। 3) सर्वोच्च न्यायालय/उच्च न्यायालय के न्यायाधीश (अनुच्छेद 124(4)/217): केवल "सिद्ध कदाचार या असमर्थता" के आधार पर दोनों सदनों में विशेष बहुमत (कुल सदस्यों का बहुमत तथा उपस्थित व मतदान करने वालों का 2/3) से पारित समावेदन पर। 4) सीएजी व मुख्य चुनाव आयुक्त (CEC): नियंत्रक एवं महालेखापरीक्षक (अनुच्छेद 148(1)) और केवल मुख्य चुनाव आयुक्त (अनुच्छेद 324(5) पहला परंतुक) को ही न्यायाधीश के समान संसदीय समावेदन द्वारा हटाया जा सकता है; अन्य चुनाव आयुक्तों को यह सुरक्षा प्राप्त नहीं है और उन्हें मुख्य चुनाव आयुक्त की सिफारिश पर राष्ट्रपति द्वारा हटाया जा सकता है (अनुच्छेद 324(5) दूसरा परंतुक)।',
              responsibilityType: ResponsibilityType.statutoryDuty,
              limitationEn:
                  'Removal motions cannot be initiated without meeting statutory notice and signatory thresholds; cannot remove constitutional judges without an inquiry report by a statutory judicial committee; Election Commissioners other than the CEC cannot be removed via parliamentary impeachment.',
              limitationHi:
                  'निर्धारित सदस्य संख्या और नोटिस के बिना प्रस्ताव पेश नहीं हो सकता; न्यायाधीश जांच अधिनियम 1968 के तहत न्यायिक जांच रिपोर्ट के बिना न्यायाधीशों को नहीं हटाया जा सकता; मुख्य चुनाव आयुक्त के अलावा अन्य चुनाव आयुक्तों के विरुद्ध महाभियोग प्रस्ताव नहीं लाया जाता।',
              lineDepartmentEn: 'Parliament of India & Ministry of Law and Justice',
              lineDepartmentHi: 'भारत की संसद एवं विधि एवं न्याय मंत्रालय',
              procedureOrApprovalEn:
                  'Notice signed by required MPs -> Presiding Officer admission -> Investigation Committee (for Judges) -> Debate and voting by prescribed constitutional majority.',
              procedureOrApprovalHi:
                  'सांसदों द्वारा हस्ताक्षरित नोटिस -> पीठासीन अधिकारी की स्वीकृति -> जांच समिति -> निर्धारित संवैधानिक बहुमत से मतदान।',
              jurisdictionScopeEn: 'National / Constitutional Jurisdiction',
              jurisdictionScopeHi: 'राष्ट्रीय / संवैधानिक अधिकार क्षेत्र',
              verificationStatusEn: 'Officially Verified Constitutional Law',
              verificationStatusHi: 'आधिकारिक सत्यापित संवैधानिक कानून',
              statutoryCitation:
                  'Constitution of India, Articles 61, 67(b), 124(4)-(5), 148(1), 217(1)(b), 324(5) (https://www.legislative.gov.in/static/uploads/2025/08/cb1b190ea633a1746368ed1fac35fb30.pdf); Judges (Inquiry) Act, 1968',
            ),
            DutyItem(
              titleEn: 'Strict Separation from State Police, Civil Bureaucracy & Judiciary',
              titleHi: 'राज्य पुलिस, सिविल प्रशासन व न्यायपालिका से पूर्ण पृथक्करण',
              descriptionEn:
                  'Uphold the constitutional doctrine of separation of powers (Article 50 & Seventh Schedule). An MP is a federal legislator, NOT an executive commander or law enforcement officer. An MP possesses NO direct statutory command authority to order police officers to register, alter, or dismiss criminal FIRs, command arrests, or direct statutory criminal investigations. Similarly, an MP has no executive authority to unilaterally transfer, suspend, or penalize state civil servants, resolve private property/land boundary disputes, or direct magisterial court trials. However, lawful communication, representing constituent hardships, and forwarding public interest petitions to the Superintendent of Police or competent disciplinary authorities remain legitimate representative functions.',
              descriptionHi:
                  'संविधान के अनुच्छेद 50 व सातवीं अनुसूची के तहत शक्तियों के पृथक्करण का पालन करना। सांसद कानून निर्माता हैं, प्रशासनिक या पुलिस कमांडर नहीं। सांसद के पास राज्य पुलिस को एफआईआर दर्ज करने या बदलने का सीधा आदेश देने, किसी को गिरफ्तार कराने या विवेचना को निर्देशित करने का कोई वैधानिक अधिकार नहीं है। इसी प्रकार, राज्य/जिला अधिकारियों को सीधे स्थानांतरित या निलंबित करने, जमीन विवाद सुलझाने या अदालतों के फैसलों को प्रभावित करने की कोई सीधी शक्ति नहीं है। हालांकि, जनसमस्याओं पर अधिकारियों से पत्राचार करना, ज्ञापन अग्रेषित करना या व्यवस्थागत समस्याओं को पुलिस अधीक्षक या सक्षम प्राधिकारी के संज्ञान में लाना जनप्रतिनिधि का वैध अधिकार है।',
              responsibilityType: ResponsibilityType.departmentalResponsibility,
              limitationEn:
                  'Absence of direct statutory command authority over independent police criminal investigations (CrPC Sec. 154, 156 / BNSS Sec. 173, 175) or state civil service disciplinary control (Arts. 309-311); lawful advocacy and grievance forwarding remain permissible.',
              limitationHi:
                  'आपराधिक जांच (CrPC/BNSS) या सिविल सेवा अनुशासनात्मक नियंत्रण में सीधा प्रशासनिक आदेश देने का अधिकार नहीं है; हालांकि जनहित में शिकायतें अग्रेषित करना मान्य है।',
              lineDepartmentEn: 'State Police, State Civil Services, District Administration & Judiciary',
              lineDepartmentHi: 'राज्य पुलिस, राज्य सिविल सेवा, जिला प्रशासन एवं न्यायपालिका',
              procedureOrApprovalEn:
                  'Regulated under Code of Criminal Procedure / BNSS, State Police Acts, and State Civil Services Rules.',
              procedureOrApprovalHi:
                  'दंड प्रक्रिया संहिता / बीएनएसएस, राज्य पुलिस अधिनियम एवं राज्य नागरिक सेवा नियमों के तहत संचालित।',
              jurisdictionScopeEn: 'Constitutional & Statutory Limits',
              jurisdictionScopeHi: 'संवैधानिक व वैधानिक सीमाएं',
              verificationStatusEn: 'Officially Verified Constitutional & Statutory Limits',
              verificationStatusHi: 'आधिकारिक सत्यापित संवैधानिक व वैधानिक सीमाएं',
              statutoryCitation:
                  'Constitution of India, Article 50 & Seventh Schedule (List II, Entries 1-2) (https://www.legislative.gov.in/static/uploads/2025/08/cb1b190ea633a1746368ed1fac35fb30.pdf); CrPC 1973 (Sec. 154, 156, 482) / BNSS 2023 (Sec. 173, 175, 528) (https://www.indiacode.nic.in/handle/123456789/20062)',
            ),
          ],
        ),
      ],
    );
  }
}
