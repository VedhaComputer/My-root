import 'package:flutter_test/flutter_test.dart';
import 'package:my_root/models/place.dart';
import 'package:my_root/models/representative_duty.dart';
import 'package:my_root/services/representative_duty_service.dart';

void main() {
  group('RepresentativeDutyService Unit Tests', () {
    test('1. Accurately identifies Haryana vs non-Haryana places', () {
      const haryanaPlace1 = Place(
        id: 'p1',
        canonicalName: 'Narwana, Haryana',
        level: 'CITY_TOWN',
        names: [PlaceName(language: 'en', name: 'Narwana')],
      );
      expect(RepresentativeDutyService.isHaryanaPlace(haryanaPlace1), isTrue);

      const haryanaPlace2 = Place(
        id: 'p2',
        canonicalName: 'Dhamtan Sahib',
        level: 'VILLAGE',
        names: [PlaceName(language: 'en', name: 'Dhamtan Sahib')],
        parentPath: [
          PlacePathItem(id: 'p-dist', canonicalName: 'Jind', level: 'DISTRICT'),
          PlacePathItem(id: 'p-state', canonicalName: 'Haryana', level: 'STATE'),
        ],
      );
      expect(RepresentativeDutyService.isHaryanaPlace(haryanaPlace2), isTrue);

      const upPlace = Place(
        id: 'p3',
        canonicalName: 'Sundarpur',
        level: 'VILLAGE',
        names: [PlaceName(language: 'en', name: 'Sundarpur')],
        parentPath: [
          PlacePathItem(id: 'p-dist2', canonicalName: 'Varanasi', level: 'DISTRICT'),
          PlacePathItem(id: 'p-state2', canonicalName: 'Uttar Pradesh', level: 'STATE'),
        ],
      );
      expect(RepresentativeDutyService.isHaryanaPlace(upPlace), isFalse);
    });

    test('2. Returns distinct statutory profiles for Sarpanch and Ward Panch in Haryana', () {
      final sarpanchProfile = RepresentativeDutyService.getProfile(
        RepresentativeRole.sarpanch,
        isHaryana: true,
      );
      final panchProfile = RepresentativeDutyService.getProfile(
        RepresentativeRole.wardPanch,
        isHaryana: true,
      );

      // Sarpanch vs Panch titles
      expect(sarpanchProfile.titleEn, contains('Sarpanch'));
      expect(panchProfile.titleEn, contains('Panch'));

      // Haryana Panchayati Raj Act 1994 statutory grounding
      expect(sarpanchProfile.legalReference.sourceTitle, contains('The Haryana Panchayati Raj Act, 1994'));
      expect(sarpanchProfile.legalReference.sourceUrl, contains('haryanadp.gov.in'));
      expect(panchProfile.legalReference.sourceTitle, contains('The Haryana Panchayati Raj Act, 1994'));

      // Statutory distinction: Panch cannot unilaterally authorize expenditures or sign cheques
      expect(panchProfile.legalLimitationsEn, anyElement(contains('unilaterally sanction')));
      expect(sarpanchProfile.legalLimitationsEn, anyElement(contains('unilaterally expend')));

      // Panch duty mentions representing ward and voting in resolutions
      final allPanchDuties = panchProfile.categories.expand((c) => c.items).map((d) => d.descriptionEn).toList();
      expect(allPanchDuties, anyElement(contains('ward')));

      // Both have 6 categorized duty sections
      expect(sarpanchProfile.categories.length, equals(6));
      expect(panchProfile.categories.length, equals(6));
    });

    test('3. General model guidance is used for non-Haryana places', () {
      final generalSarpanch = RepresentativeDutyService.getProfile(
        RepresentativeRole.sarpanch,
        isHaryana: false,
      );

      expect(generalSarpanch.legalReference.sourceTitle, contains('General Model Guidance'));
      expect(generalSarpanch.legalReference.isStateSpecific, isFalse);
      expect(generalSarpanch.categories.length, equals(6));
      expect(generalSarpanch.citizenQa.length, equals(5));
    });

    test('4. Citizen Q&A covers the 5 core citizen questions in Hindi and English', () {
      final profile = RepresentativeDutyService.getProfile(
        RepresentativeRole.sarpanch,
        isHaryana: true,
      );

      final questionsHi = profile.citizenQa.map((q) => q.questionHi).toList();
      expect(questionsHi, anyElement(contains('क्या कर सकते हैं')));
      expect(questionsHi, anyElement(contains('जिम्मेदारी')));
      expect(questionsHi, anyElement(contains('मंजूरी')));
      expect(questionsHi, anyElement(contains('विभाग')));
      expect(questionsHi, anyElement(contains('शिकायत')));

      // Verify answers are non-empty
      for (final qa in profile.citizenQa) {
        expect(qa.questionEn.trim().isNotEmpty, isTrue);
        expect(qa.answerEn.trim().isNotEmpty, isTrue);
        expect(qa.questionHi.trim().isNotEmpty, isTrue);
        expect(qa.answerHi.trim().isNotEmpty, isTrue);
      }
    });

    test('5. Grievance escalation hierarchy contains multiple levels and contact points', () {
      final profile = RepresentativeDutyService.getProfile(
        RepresentativeRole.sarpanch,
        isHaryana: true,
      );

      expect(profile.grievanceEscalationEn, contains('Panchayat Secretary'));
      expect(profile.grievanceEscalationEn, contains('BDPO'));
      expect(profile.grievanceEscalationEn, contains('CM Window'));
    });

    test('6. Applicable roles cleanly separate rural vs urban administrative levels', () {
      final ruralRoles = RepresentativeDutyService.getApplicableRoles('VILLAGE');
      expect(ruralRoles, contains(RepresentativeRole.sarpanch));
      expect(ruralRoles, contains(RepresentativeRole.wardPanch));
      expect(ruralRoles, contains(RepresentativeRole.panchayatSamitiMember));
      expect(ruralRoles, contains(RepresentativeRole.zilaParishadMember));
      expect(ruralRoles, contains(RepresentativeRole.mla));
      expect(ruralRoles, contains(RepresentativeRole.mp));
      expect(ruralRoles, isNot(contains(RepresentativeRole.municipalChairperson)));
      expect(ruralRoles, isNot(contains(RepresentativeRole.municipalCouncillor)));

      final urbanRoles = RepresentativeDutyService.getApplicableRoles('CITY_TOWN');
      expect(urbanRoles, contains(RepresentativeRole.municipalChairperson));
      expect(urbanRoles, contains(RepresentativeRole.municipalCouncillor));
      expect(urbanRoles, contains(RepresentativeRole.mla));
      expect(urbanRoles, contains(RepresentativeRole.mp));
      expect(urbanRoles, isNot(contains(RepresentativeRole.sarpanch)));
      expect(urbanRoles, isNot(contains(RepresentativeRole.wardPanch)));
    });

    test('7. Returns distinct statutory profiles for Panchayat Samiti Chairperson and Member in Haryana', () {
      final chairpersonProfile = RepresentativeDutyService.getProfile(
        RepresentativeRole.panchayatSamitiChairperson,
        isHaryana: true,
      );
      final memberProfile = RepresentativeDutyService.getProfile(
        RepresentativeRole.panchayatSamitiMember,
        isHaryana: true,
      );

      // Titles and governing body
      expect(chairpersonProfile.titleEn, contains('Panchayat Samiti Chairperson'));
      expect(chairpersonProfile.titleEn, contains('Block Pramukh'));
      expect(chairpersonProfile.titleHi, contains('ब्लॉक प्रमुख'));
      expect(memberProfile.titleEn, contains('Panchayat Samiti Member'));
      expect(memberProfile.titleEn, contains('BDC'));
      expect(memberProfile.titleHi, contains('BDC'));

      // Both have 6 comprehensive duty categories and 5 citizen Q&A items
      expect(chairpersonProfile.categories.length, equals(6));
      expect(memberProfile.categories.length, equals(6));
      expect(chairpersonProfile.citizenQa.length, equals(5));
      expect(memberProfile.citizenQa.length, equals(5));

      // Haryana Panchayati Raj Act 1994 statutory references
      expect(chairpersonProfile.legalReference.sourceTitle, contains('The Haryana Panchayati Raj Act, 1994'));
      expect(chairpersonProfile.legalReference.relevantSections, contains('56'));
      expect(chairpersonProfile.legalReference.relevantSections, contains('59'));
      expect(chairpersonProfile.legalReference.relevantSections, contains('61'));
      expect(chairpersonProfile.legalReference.relevantSections, contains('101'));

      expect(memberProfile.legalReference.sourceTitle, contains('The Haryana Panchayati Raj Act, 1994'));
      expect(memberProfile.legalReference.relevantSections, contains('66'));
      expect(memberProfile.legalReference.relevantSections, contains('75'));

      // Distinct statutory powers & limitations
      // Chairperson presides, prepares agenda, casts deciding vote in tie, coordinates plan
      final chairDuties = chairpersonProfile.categories.expand((c) => c.items).map((d) => d.descriptionEn).toList();
      expect(chairDuties, anyElement(contains('preside')));
      expect(chairDuties, anyElement(contains('Block Development Plan')));

      // Member deliberates, votes in resolutions, inspects constituency works, NO individual fund quota
      final memberDuties = memberProfile.categories.expand((c) => c.items).map((d) => d.descriptionEn).toList();
      expect(memberDuties, anyElement(contains('propose')));
      expect(memberDuties, anyElement(contains('constituency')));

      // Limitations
      expect(chairpersonProfile.legalLimitationsEn, anyElement(contains('executive authority')));
      expect(chairpersonProfile.legalLimitationsEn, anyElement(contains('unilaterally expend Samiti funds')));
      expect(memberProfile.legalLimitationsEn, anyElement(contains('individual discretionary development fund quota')));
      expect(memberProfile.legalLimitationsEn, anyElement(contains('individual executive or financial signing authority')));

      // Grievance escalation hierarchy
      expect(chairpersonProfile.grievanceEscalationEn, contains('BDPO'));
      expect(chairpersonProfile.grievanceEscalationEn, contains('CEO, Zila Parishad'));
      expect(memberProfile.grievanceEscalationEn, contains('BDPO'));
      expect(memberProfile.grievanceEscalationEn, contains('Panchayat Samiti Member'));
    });

    test('8. General model guidance for Panchayat Samiti roles outside Haryana', () {
      final generalChairperson = RepresentativeDutyService.getProfile(
        RepresentativeRole.panchayatSamitiChairperson,
        isHaryana: false,
      );
      final generalMember = RepresentativeDutyService.getProfile(
        RepresentativeRole.panchayatSamitiMember,
        isHaryana: false,
      );

      expect(generalChairperson.legalReference.sourceTitle, contains('General Model Guidance'));
      expect(generalChairperson.legalReference.isStateSpecific, isFalse);
      expect(generalChairperson.categories.length, equals(6));
      expect(generalChairperson.citizenQa.length, equals(5));

      expect(generalMember.legalReference.sourceTitle, contains('General Model Guidance'));
      expect(generalMember.legalReference.isStateSpecific, isFalse);
      expect(generalMember.categories.length, equals(6));
      expect(generalMember.citizenQa.length, equals(5));
    });

    test('9. Sub-district / Tehsil / Block levels include intermediate Panchayat Samiti roles', () {
      final subDistrictRoles = RepresentativeDutyService.getApplicableRoles('SUB_DISTRICT');
      expect(subDistrictRoles, contains(RepresentativeRole.panchayatSamitiChairperson));
      expect(subDistrictRoles, contains(RepresentativeRole.panchayatSamitiMember));
      expect(subDistrictRoles, contains(RepresentativeRole.zilaParishadMember));

      final blockRoles = RepresentativeDutyService.getApplicableRoles('BLOCK');
      expect(blockRoles, contains(RepresentativeRole.panchayatSamitiChairperson));
      expect(blockRoles, contains(RepresentativeRole.panchayatSamitiMember));
    });

    test('10. Accurately resolves canonical state identifiers across different state jurisdictions', () {
      const haryanaPlace = Place(
        id: 'p-hr',
        canonicalName: 'Dhamtan Sahib',
        level: 'VILLAGE',
        names: [PlaceName(language: 'en', name: 'Dhamtan Sahib')],
        parentPath: [
          PlacePathItem(id: 'dist-1', canonicalName: 'Jind', level: 'DISTRICT'),
          PlacePathItem(id: 'state-1', canonicalName: 'Haryana', level: 'STATE'),
        ],
      );
      expect(RepresentativeDutyService.resolveStateIdentifier(haryanaPlace), equals('haryana'));
      expect(RepresentativeDutyService.extractStateName(haryanaPlace), equals('Haryana'));

      const rajasthanPlace = Place(
        id: 'p-rj',
        canonicalName: 'Mandore',
        level: 'VILLAGE',
        names: [PlaceName(language: 'en', name: 'Mandore')],
        parentPath: [
          PlacePathItem(id: 'dist-2', canonicalName: 'Jodhpur', level: 'DISTRICT'),
          PlacePathItem(id: 'state-2', canonicalName: 'Rajasthan', level: 'STATE'),
        ],
      );
      expect(RepresentativeDutyService.resolveStateIdentifier(rajasthanPlace), equals('rajasthan'));
      expect(RepresentativeDutyService.extractStateName(rajasthanPlace), equals('Rajasthan'));

      const upPlace = Place(
        id: 'p-up',
        canonicalName: 'Shivpur',
        level: 'VILLAGE',
        names: [PlaceName(language: 'en', name: 'Shivpur')],
        parentPath: [
          PlacePathItem(id: 'dist-3', canonicalName: 'Varanasi', level: 'DISTRICT'),
          PlacePathItem(id: 'state-3', canonicalName: 'Uttar Pradesh', level: 'STATE'),
        ],
      );
      expect(RepresentativeDutyService.resolveStateIdentifier(upPlace), equals('uttar_pradesh'));
      expect(RepresentativeDutyService.extractStateName(upPlace), equals('Uttar Pradesh'));

      const unknownPlace = Place(
        id: 'p-unknown',
        canonicalName: 'Remote Valley',
        level: 'VILLAGE',
        names: [PlaceName(language: 'en', name: 'Remote Valley')],
      );
      expect(RepresentativeDutyService.resolveStateIdentifier(unknownPlace), isNull);
    });

    test('11. Returns distinct statutory profiles for Zila Parishad Chairperson and Member in Haryana', () {
      final chairpersonProfile = RepresentativeDutyService.getProfile(
        RepresentativeRole.zilaParishadChairperson,
        stateIdentifier: 'haryana',
      );
      final memberProfile = RepresentativeDutyService.getProfile(
        RepresentativeRole.zilaParishadMember,
        stateIdentifier: 'haryana',
      );

      // Titles
      expect(chairpersonProfile.titleEn, contains('Zila Parishad Chairperson'));
      expect(chairpersonProfile.titleEn, contains('Zila Pramukh / President'));
      expect(chairpersonProfile.titleHi, contains('जिला परिषद अध्यक्ष (जिला प्रमुख)'));

      expect(memberProfile.titleEn, contains('Zila Parishad Member (District Level)'));
      expect(memberProfile.titleHi, contains('जिला परिषद सदस्य (जिला स्तर)'));

      // Both have 6 comprehensive categories and 5 citizen Q&A
      expect(chairpersonProfile.categories.length, equals(6));
      expect(memberProfile.categories.length, equals(6));
      expect(chairpersonProfile.citizenQa.length, equals(5));
      expect(memberProfile.citizenQa.length, equals(5));

      // Haryana Panchayati Raj Act, 1994 statutory references
      expect(chairpersonProfile.legalReference.sourceTitle, contains('The Haryana Panchayati Raj Act, 1994 (Haryana Act No. 11 of 1994)'));
      expect(chairpersonProfile.legalReference.isStateSpecific, isTrue);
      expect(chairpersonProfile.legalReference.relevantSections, contains('117'));
      expect(chairpersonProfile.legalReference.relevantSections, contains('121'));
      expect(chairpersonProfile.legalReference.relevantSections, contains('123'));
      expect(chairpersonProfile.legalReference.relevantSections, contains('127'));
      expect(chairpersonProfile.legalReference.relevantSections, contains('133'));
      expect(chairpersonProfile.legalReference.relevantSections, contains('139'));

      expect(memberProfile.legalReference.sourceTitle, contains('The Haryana Panchayati Raj Act, 1994 (Haryana Act No. 11 of 1994)'));
      expect(memberProfile.legalReference.isStateSpecific, isTrue);
      expect(memberProfile.legalReference.relevantSections, contains('118'));
      expect(memberProfile.legalReference.relevantSections, contains('122'));
      expect(memberProfile.legalReference.relevantSections, contains('127'));
      expect(memberProfile.legalReference.relevantSections, contains('137'));
      expect(memberProfile.legalReference.relevantSections, contains('139'));

      // Powers & Duties distinction
      final chairDuties = chairpersonProfile.categories.expand((c) => c.items).map((d) => d.descriptionEn).toList();
      expect(chairDuties, anyElement(contains('preside')));
      expect(chairDuties, anyElement(contains('General Standing Committee')));
      expect(chairDuties, anyElement(contains('emergency powers')));

      final memberDuties = memberProfile.categories.expand((c) => c.items).map((d) => d.descriptionEn).toList();
      expect(memberDuties, anyElement(contains('deliberate')));
      expect(memberDuties, anyElement(contains('constituency')));
      expect(memberDuties, anyElement(contains('motions and resolutions')));

      // Statutory Limitations: Executive separation & Member quota limits
      expect(chairpersonProfile.legalLimitationsEn, anyElement(contains('Chief Executive Officer (CEO)')));
      expect(chairpersonProfile.legalLimitationsEn, anyElement(contains('unilaterally expend')));
      expect(memberProfile.legalLimitationsEn, anyElement(contains('individual discretionary development fund quota')));
      expect(memberProfile.legalLimitationsEn, anyElement(contains('individual executive')));

      // Grievance escalation
      expect(chairpersonProfile.grievanceEscalationEn, contains('Chief Executive Officer (CEO)'));
      expect(chairpersonProfile.grievanceEscalationEn, contains('Divisional Commissioner'));
      expect(memberProfile.grievanceEscalationEn, contains('CEO, Zila Parishad'));
    });

    test('12. Returns verified Rajasthan Panchayati Raj Act profiles for Zila Parishad roles in Rajasthan', () {
      final chairpersonProfile = RepresentativeDutyService.getProfile(
        RepresentativeRole.zilaParishadChairperson,
        stateIdentifier: 'rajasthan',
      );
      final memberProfile = RepresentativeDutyService.getProfile(
        RepresentativeRole.zilaParishadMember,
        stateIdentifier: 'rajasthan',
      );

      // Titles & Body
      expect(chairpersonProfile.titleEn, contains('Zila Pramukh'));
      expect(chairpersonProfile.titleHi, contains('जिला प्रमुख'));
      expect(memberProfile.titleEn, contains('Zila Parishad Member'));

      // Rajasthan Panchayati Raj Act 1994 statutory references
      expect(chairpersonProfile.legalReference.sourceTitle, contains('The Rajasthan Panchayati Raj Act, 1994 (Act No. 13 of 1994)'));
      expect(chairpersonProfile.legalReference.isStateSpecific, isTrue);
      expect(chairpersonProfile.legalReference.sourceUrl, contains('panchayat.rajasthan.gov.in'));
      expect(chairpersonProfile.legalReference.relevantSections, contains('14'));
      expect(chairpersonProfile.legalReference.relevantSections, contains('26'));
      expect(chairpersonProfile.legalReference.relevantSections, contains('32'));
      expect(chairpersonProfile.legalReference.relevantSections, contains('56'));
      expect(chairpersonProfile.legalReference.relevantSections, contains('60'));

      expect(memberProfile.legalReference.sourceTitle, contains('The Rajasthan Panchayati Raj Act, 1994 (Act No. 13 of 1994)'));
      expect(memberProfile.legalReference.isStateSpecific, isTrue);
      expect(memberProfile.legalReference.relevantSections, contains('14'));
      expect(memberProfile.legalReference.relevantSections, contains('15'));
      expect(memberProfile.legalReference.relevantSections, contains('27'));
      expect(memberProfile.legalReference.relevantSections, contains('56'));

      // Executive separation under Rajasthan law (Section 60 CEO)
      expect(chairpersonProfile.legalLimitationsEn, anyElement(contains('Section 60')));
      expect(memberProfile.legalLimitationsEn, anyElement(contains('individual discretionary development fund quota')));

      // Grievance escalation in Rajasthan
      expect(chairpersonProfile.grievanceEscalationEn, contains('Rajasthan Sampark Portal (181)'));
      expect(chairpersonProfile.grievanceEscalationHi, contains('राजस्थान संपर्क पोर्टल (181)'));
    });

    test('13. General model guidance for Zila Parishad roles in unverified/unsupported state jurisdictions', () {
      final generalChairperson = RepresentativeDutyService.getProfile(
        RepresentativeRole.zilaParishadChairperson,
        stateIdentifier: 'unsupported_state',
      );
      final generalMember = RepresentativeDutyService.getProfile(
        RepresentativeRole.zilaParishadMember,
        stateIdentifier: 'unsupported_state',
      );

      expect(generalChairperson.legalReference.sourceTitle, contains('General Model Guidance'));
      expect(generalChairperson.legalReference.isStateSpecific, isFalse);
      expect(generalChairperson.legalReference.relevantSections, contains('243B'));
      expect(generalChairperson.legalReference.relevantSections, contains('Eleventh Schedule'));
      expect(generalChairperson.categories.length, equals(6));
      expect(generalChairperson.citizenQa.length, equals(5));

      expect(generalMember.legalReference.sourceTitle, contains('General Model Guidance'));
      expect(generalMember.legalReference.isStateSpecific, isFalse);
      expect(generalMember.categories.length, equals(6));
      expect(generalMember.citizenQa.length, equals(5));
    });

    test('14. District administrative level includes both Zila Parishad Chairperson and Member', () {
      final districtRoles = RepresentativeDutyService.getApplicableRoles('DISTRICT');
      expect(districtRoles, contains(RepresentativeRole.zilaParishadChairperson));
      expect(districtRoles, contains(RepresentativeRole.zilaParishadMember));
      expect(districtRoles, contains(RepresentativeRole.mla));
      expect(districtRoles, contains(RepresentativeRole.mp));
      expect(districtRoles, isNot(contains(RepresentativeRole.sarpanch)));
      expect(districtRoles, isNot(contains(RepresentativeRole.wardPanch)));
    });

    test('15. Returns source-verified MLA profile for Haryana with VAGY / MLALAD Rs 5 Cr and Assembly Rules', () {
      final mlaProfile = RepresentativeDutyService.getProfile(
        RepresentativeRole.mla,
        stateIdentifier: 'haryana',
      );

      // Titles & Body
      expect(mlaProfile.titleEn, contains('Member of Legislative Assembly (MLA) - Haryana'));
      expect(mlaProfile.titleHi, contains('विधायक (विधान सभा सदस्य - हरियाणा)'));
      expect(mlaProfile.governingBodyEn, contains('Haryana Legislative Assembly (Vidhan Sabha)'));
      expect(mlaProfile.governingBodyHi, contains('हरियाणा विधान सभा'));

      // Verification & Citations
      expect(mlaProfile.legalReference.isStateSpecific, isTrue);
      expect(mlaProfile.legalReference.jurisdictionState, equals('Haryana'));
      expect(mlaProfile.legalReference.sourceUrl, equals('https://haryanaassembly.gov.in'));
      expect(mlaProfile.legalReference.sourceTitle, contains('Rules of Procedure of Haryana Vidhan Sabha'));
      expect(mlaProfile.legalReference.relevantSections, contains('168'));
      expect(mlaProfile.legalReference.relevantSections, contains('202-207'));

      // 6 Structured Categories and 5 Citizen Q&A
      expect(mlaProfile.categories.length, equals(6));
      expect(mlaProfile.citizenQa.length, equals(5));

      // Structured Duty Items & Content Verification
      final allDutiesEn = mlaProfile.categories.expand((c) => c.items).map((d) => d.descriptionEn).toList();
      expect(allDutiesEn, anyElement(contains('State List')));
      expect(allDutiesEn, anyElement(contains('Question Hour')));
      expect(allDutiesEn, anyElement(contains('Vidhayak Adarsh Gram Yojana')));
      expect(allDutiesEn, anyElement(contains('Rs 5 Crore')));
      expect(allDutiesEn, anyElement(contains('DISHA')));
      expect(allDutiesEn, anyElement(contains('President of India')));
      expect(allDutiesEn, anyElement(contains('Rajya Sabha')));

      // Actionable Item Structure: Limitations, Departments, Approvals, Jurisdictions
      final firstItem = mlaProfile.categories.first.items.first;
      expect(firstItem.limitationEn, isNotNull);
      expect(firstItem.limitationEn, contains('Union List'));
      expect(firstItem.lineDepartmentEn, isNotNull);
      expect(firstItem.procedureOrApprovalEn, isNotNull);
      expect(firstItem.jurisdictionScopeEn, contains('State'));
      expect(firstItem.verificationStatusEn, contains('Officially Verified Law'));

      // Limitations
      expect(mlaProfile.legalLimitationsEn, anyElement(contains('award public tenders')));
      expect(mlaProfile.legalLimitationsEn, anyElement(contains('order police officers to register, alter, or dismiss criminal FIRs')));
      expect(mlaProfile.legalLimitationsEn, anyElement(contains('transfer, suspend, or penalize civil servants')));

      // Grievance Escalation
      expect(mlaProfile.grievanceEscalationEn, contains('Deputy Commissioner'));
      expect(mlaProfile.grievanceEscalationEn, contains('Speaker, Haryana Legislative Assembly'));
      expect(mlaProfile.grievanceEscalationEn, contains('Lokayukta Haryana'));
    });

    test('16. Returns source-verified MLA profile for Rajasthan with MLA-LAD Rs 5 Cr and Rajasthan Vidhan Sabha Rules', () {
      final mlaProfile = RepresentativeDutyService.getProfile(
        RepresentativeRole.mla,
        stateIdentifier: 'rajasthan',
      );

      // Titles & Body
      expect(mlaProfile.titleEn, contains('Member of Legislative Assembly (MLA) - Rajasthan'));
      expect(mlaProfile.titleHi, contains('विधायक (विधान सभा सदस्य - राजस्थान)'));
      expect(mlaProfile.governingBodyEn, contains('Rajasthan Legislative Assembly (Vidhan Sabha)'));

      // Verification & Citations
      expect(mlaProfile.legalReference.isStateSpecific, isTrue);
      expect(mlaProfile.legalReference.jurisdictionState, equals('Rajasthan'));
      expect(mlaProfile.legalReference.sourceUrl, equals('https://assembly.rajasthan.gov.in'));
      expect(mlaProfile.legalReference.sourceTitle, contains('Rules of Procedure of Rajasthan Vidhan Sabha'));

      // Rajasthan MLA-LAD scheme details
      final allDutiesEn = mlaProfile.categories.expand((c) => c.items).map((d) => d.descriptionEn).toList();
      expect(allDutiesEn, anyElement(contains('Rajasthan Vidhayak Sthaniya Kshetra Vikas Yojana')));
      expect(allDutiesEn, anyElement(contains('Rs 5 Crore')));
      expect(allDutiesEn, anyElement(contains('SC/ST')));

      // Grievance Escalation
      expect(mlaProfile.grievanceEscalationEn, contains('District Collector'));
      expect(mlaProfile.grievanceEscalationEn, contains('Speaker, Rajasthan Legislative Assembly'));
      expect(mlaProfile.grievanceEscalationEn, contains('Rajasthan Sampark Portal (181)'));
      expect(mlaProfile.grievanceEscalationHi, contains('राजस्थान संपर्क पोर्टल (181)'));
    });

    test('17. Returns General Model Guidance for MLA in unverified state jurisdictions', () {
      final mlaProfile = RepresentativeDutyService.getProfile(
        RepresentativeRole.mla,
        stateIdentifier: 'unsupported_state',
      );

      expect(mlaProfile.titleEn, equals('Member of Legislative Assembly (MLA)'));
      expect(mlaProfile.legalReference.isStateSpecific, isFalse);
      expect(mlaProfile.legalReference.sourceTitle, contains('General Model Guidance'));
      expect(mlaProfile.legalReference.jurisdictionState, equals('General / Model Framework'));
      expect(mlaProfile.legalReference.sourceUrl, equals('https://legislative.gov.in/constitution-of-india'));
      expect(mlaProfile.categories.length, equals(6));
      expect(mlaProfile.citizenQa.length, equals(5));

      // Bicameral vs Unicameral distinction is made
      final bicameralDuty = mlaProfile.categories
          .expand((c) => c.items)
          .firstWhere((d) => d.titleEn.contains('Legislative Council'));
      expect(bicameralDuty.descriptionEn, contains('Uttar Pradesh, Bihar, Maharashtra, Karnataka, Andhra Pradesh, Telangana'));
    });
  });
}
