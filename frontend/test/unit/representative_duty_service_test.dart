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

    test('15. Returns source-verified MLA profile for Haryana with VANGY Rs 2 Cr, population limits, and Assembly Rules', () {
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
      expect(mlaProfile.legalReference.sourceUrl, equals('https://haryanarural.gov.in'));
      expect(mlaProfile.legalReference.sourceTitle, contains('Rules of Procedure of Haryana Vidhan Sabha'));
      expect(mlaProfile.legalReference.relevantSections, contains('168'));
      expect(mlaProfile.legalReference.relevantSections, contains('202-207'));
      expect(mlaProfile.legalReference.relevantSections, contains('VANGY'));

      // 6 Structured Categories and 5 Citizen Q&A
      expect(mlaProfile.categories.length, equals(6));
      expect(mlaProfile.citizenQa.length, equals(5));

      // Structured Duty Items & Content Verification
      final allDutiesEn = mlaProfile.categories.expand((c) => c.items).map((d) => d.descriptionEn).toList();
      expect(allDutiesEn, anyElement(contains('State List')));
      expect(allDutiesEn, anyElement(contains('Question Hour')));
      expect(allDutiesEn, anyElement(contains('Vidhayak Adarsh Nagar Avam Gram Yojana')));
      expect(allDutiesEn, anyElement(contains('Rs 2 Crore')));
      expect(allDutiesEn, anyElement(contains('population-based')));
      expect(allDutiesEn, anyElement(contains('unverified budget proposals')));
      // Guard against silent regression of unsupported statutory Rs 5 Cr claim
      expect(allDutiesEn, isNot(anyElement(contains('statutory allocation of Rs 5 Crore'))));
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

      // Verified VANGY limitations include population ceilings
      final mlaladItem = mlaProfile.categories
          .expand((c) => c.items)
          .firstWhere((d) => d.titleEn.contains('MLALADS'));
      expect(mlaladItem.limitationEn, contains('pop <5,000'));
      expect(mlaladItem.statutoryCitation, contains('haryanarural.gov.in'));
      expect(mlaladItem.statutoryCitation, contains('Rs 5 Cr general claim pending gazetted verification'));

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
      expect(allDutiesEn, anyElement(contains('Rajasthan Economic Review 2024-25')));

      final mlaladItem = mlaProfile.categories
          .expand((c) => c.items)
          .firstWhere((d) => d.titleEn.contains('MLALADS'));
      expect(mlaladItem.statutoryCitation, contains('Rajasthan Economic Review 2024-25'));
      expect(mlaladItem.statutoryCitation, contains('MLA-LAD Guidelines 2023'));

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

    test('18. Returns source-verified MP profile with Union legislative powers and Lok Sabha / Rajya Sabha distinctions', () {
      final mpProfile = RepresentativeDutyService.getProfile(RepresentativeRole.mp);

      // Titles & Body
      expect(mpProfile.titleEn, contains('Member of Parliament (MP) - Lok Sabha / Rajya Sabha'));
      expect(mpProfile.titleHi, contains('सांसद (संसद सदस्य - लोक सभा / राज्य सभा)'));
      expect(mpProfile.governingBodyEn, contains('Parliament of India (Lok Sabha / Rajya Sabha), New Delhi'));

      // Verification & Citations
      expect(mpProfile.legalReference.isStateSpecific, isTrue);
      expect(mpProfile.legalReference.jurisdictionState, contains('Union of India'));
      expect(mpProfile.legalReference.sourceUrl, equals('https://www.legislative.gov.in/static/uploads/2025/08/cb1b190ea633a1746368ed1fac35fb30.pdf'));
      expect(mpProfile.legalReference.sourceTitle, contains('Constitution of India (Part V, Arts. 79-122)'));
      expect(mpProfile.legalReference.relevantSections, contains('Arts. 79-84'));
      expect(mpProfile.legalReference.relevantSections, contains('MPLADS Guidelines 2023'));

      // 6 Categories and 5 Citizen Q&A
      expect(mpProfile.categories.length, equals(6));
      expect(mpProfile.citizenQa.length, equals(5));

      final allDutiesEn = mpProfile.categories.expand((c) => c.items).map((d) => d.descriptionEn).toList();
      // Legislative Distinctions
      expect(allDutiesEn, anyElement(contains('List I - Union List')));
      expect(allDutiesEn, anyElement(contains('List III - education')));
      // Money Bill Primacy
      expect(allDutiesEn, anyElement(contains('Money Bills (imposing taxes, regulating government borrowing')));
      expect(allDutiesEn, anyElement(contains('14 days')));
      // Constitution Amendment (Art. 368)
      expect(allDutiesEn, anyElement(contains('Article 368')));
      expect(allDutiesEn, anyElement(contains('No provision exists for a joint sitting')));
      // No-Confidence Motion exclusive to Lok Sabha
      expect(allDutiesEn, anyElement(contains('Article 75(3)')));
      expect(allDutiesEn, anyElement(contains('responsible SOLELY to the House of the People (Lok Sabha)')));
      expect(allDutiesEn, anyElement(contains('Rajya Sabha has NO power to move or vote on a motion of no-confidence')));

      // Separate Lok Sabha and Rajya Sabha Rule Citations
      final pmBillItem = mpProfile.categories
          .expand((c) => c.items)
          .firstWhere((d) => d.titleEn.contains('Private Members'));
      expect(pmBillItem.statutoryCitation, contains('https://sansad.in/ls/rules'));
      expect(pmBillItem.statutoryCitation, contains('https://sansad.in/uploads/English_2052022english_3092021rules_pro_8efbe8ead1.pdf'));

      final qHourItem = mpProfile.categories
          .expand((c) => c.items)
          .firstWhere((d) => d.titleEn.contains('Question Hour'));
      expect(qHourItem.statutoryCitation, contains('https://sansad.in/ls/rules'));
      expect(qHourItem.statutoryCitation, contains('https://sansad.in/uploads/English_2052022english_3092021rules_pro_8efbe8ead1.pdf'));

      final petitionItem = mpProfile.categories
          .expand((c) => c.items)
          .firstWhere((d) => d.titleEn.contains('Citizen Petitions'));
      expect(petitionItem.statutoryCitation, contains('https://sansad.in/ls/rules'));
      expect(petitionItem.statutoryCitation, contains('https://sansad.in/uploads/English_2052022english_3092021rules_pro_8efbe8ead1.pdf'));

      // Representations & Grievance Hearings
      final repItem = mpProfile.categories
          .expand((c) => c.items)
          .firstWhere((d) => d.titleEn.contains('Public Grievance Hearings'));
      expect(repItem.verificationStatusEn, contains('Central Administrative Protocol'));
      expect(repItem.statutoryCitation, contains('11013/14/2022-Estt.A-III'));
      expect(repItem.statutoryCitation, contains('Official_dealing_consolidation13092022.pdf'));
      expect(repItem.statutoryCitation, contains('11013/4/2011-Estt.(A)'));
      expect(repItem.statutoryCitation, contains('48013/1/2011-O&M'));
      expect(repItem.statutoryCitation, contains('CSMOP 2019 Paras 8.8-8.9'));
      expect(repItem.descriptionEn, contains('acknowledgment within 15 days'));
      expect(repItem.descriptionEn, contains('reply within the next 15 days after acknowledgment'));
      expect(repItem.descriptionEn, contains('interim reply within 15 days from receipt'));

      // PMNRF Discretionary Relief
      final pmnrfItem = mpProfile.categories
          .expand((c) => c.items)
          .firstWhere((d) => d.titleEn.contains('Prime Minister\'s National Relief Fund'));
      expect(pmnrfItem.verificationStatusEn, contains('Discretionary Central Relief (MP Recommendation Procedure Pending Verification)'));
      expect(pmnrfItem.statutoryCitation, contains('pmnrf.gov.in/en/about'));
      expect(pmnrfItem.statutoryCitation, contains('specific MP recommendation protocol pending primary gazetted verification'));
    });

    test('19. Verifies MPLADS ₹5 Crore annual allocation, MoSPI rules, territorial scopes, and fund restrictions', () {
      final mpProfile = RepresentativeDutyService.getProfile(RepresentativeRole.mp);

      final allDutiesEn = mpProfile.categories.expand((c) => c.items).map((d) => d.descriptionEn).toList();
      // MPLADS allocation and installment breakdown
      expect(allDutiesEn, anyElement(contains('₹5 Crore per annum')));
      expect(allDutiesEn, anyElement(contains('₹2.5 Crore installments')));
      // Territorial Slabs
      expect(allDutiesEn, anyElement(contains('Lok Sabha MP recommends works strictly within their Parliamentary Constituency')));
      expect(allDutiesEn, anyElement(contains('Rajya Sabha MP recommends in one or more districts of the State')));
      expect(allDutiesEn, anyElement(contains('Nominated MP (Lok Sabha or Rajya Sabha) may select one or more districts from any one State in the country')));
      // Mandatory SC/ST reservation
      expect(allDutiesEn, anyElement(contains('15% of annual funds must be utilized in Scheduled Caste')));
      expect(allDutiesEn, anyElement(contains('7.5% in Scheduled Tribe')));

      // Specific Item Metadata for MPLADS
      final mpladsItem = mpProfile.categories
          .expand((c) => c.items)
          .firstWhere((d) => d.titleEn.contains('MPLADS'));
      expect(mpladsItem.statutoryCitation, contains('Revised MPLADS Guidelines 2023'));
      expect(mpladsItem.lineDepartmentEn, contains('Ministry of Statistics and Programme Implementation (MoSPI)'));
      expect(mpladsItem.lineDepartmentEn, contains('Nodal District Authority'));
      expect(mpladsItem.limitationEn, contains('funds are NEVER credited to an MP\'s personal account'));
      expect(mpladsItem.limitationEn, contains('MPs CANNOT issue tenders'));

      // Limitations array
      expect(mpProfile.legalLimitationsEn, anyElement(contains('Has NO personal account receipt, custody, or cheque-signing authority over MPLADS funds')));
      expect(mpProfile.legalLimitationsEn, anyElement(contains('Cannot directly award tenders, hire private works contractors')));
      expect(mpProfile.legalLimitationsEn, anyElement(contains('Cannot recommend MPLADS works on private land')));
    });

    test('20. Verifies constitutional elections (President vs VP), removal distinctions, DISHA role, and executive separation', () {
      final mpProfile = RepresentativeDutyService.getProfile(RepresentativeRole.mp);

      final allDutiesEn = mpProfile.categories.expand((c) => c.items).map((d) => d.descriptionEn).toList();
      // President vs Vice-President Electorate
      expect(allDutiesEn, anyElement(contains('President of India (Articles 54, 55): Electoral College consists of ELECTED members')));
      expect(allDutiesEn, anyElement(contains('nominated MPs, nominated MLAs, and Legislative Council members (MLCs) CANNOT vote')));
      expect(allDutiesEn, anyElement(contains('Vice-President of India (Article 66): Electoral College consists of members of BOTH Houses of Parliament')));
      expect(allDutiesEn, anyElement(contains('INCLUDING nominated members')));
      expect(allDutiesEn, anyElement(contains('MLAs and MLCs DO NOT vote in Vice-Presidential elections')));

      // Removal / Impeachment distinctions
      expect(allDutiesEn, anyElement(contains('President of India: Impeached under Article 61 ONLY on the ground of "violation of the Constitution"')));
      expect(allDutiesEn, anyElement(contains('Vice-President of India: Removed under Article 67(b) by a resolution initiated in Rajya Sabha')));
      expect(allDutiesEn, anyElement(contains('Supreme Court / High Court Judges: Removed by Presidential order following an address by both Houses under Article 124(4)/217 on grounds of "proved misbehaviour or incapacity"')));
      expect(allDutiesEn, anyElement(contains('ONLY the Chief Election Commissioner (Art. 324(5) first proviso) are removed in like manner')));
      expect(allDutiesEn, anyElement(contains('other Election Commissioners have no such parliamentary address protection')));

      // DISHA Committee
      expect(allDutiesEn, anyElement(contains('senior-most Lok Sabha MP elected from the district is designated as the CHAIRPERSON of the DISHA Committee')));
      final allLimitationsEn = mpProfile.categories.expand((c) => c.items).map((d) => d.limitationEn ?? '').toList();
      expect(allLimitationsEn, anyElement(contains('DISHA is an oversight and coordination committee; an MP has NO executive authority to suspend district officials')));
      final dishaItem = mpProfile.categories
          .expand((c) => c.items)
          .firstWhere((d) => d.titleEn.contains('DISHA'));
      expect(dishaItem.verificationStatusEn, contains('Central Executive Guideline (Gazette Order Verification Pending)'));
      expect(dishaItem.statutoryCitation, contains('Order No. Q-13016/1/2016-DISHA'));
      expect(dishaItem.statutoryCitation, contains('primary signed gazetted order pending verification'));

      // Police & Executive Separation
      expect(mpProfile.legalLimitationsEn, anyElement(contains('Cannot order police officers to register, alter, or dismiss criminal FIRs')));
      expect(mpProfile.legalLimitationsEn, anyElement(contains('Possesses NO direct administrative or executive command over State Police')));
      expect(mpProfile.legalLimitationsEn, anyElement(contains('Cannot unilaterally transfer, suspend, or discipline state civil servants')));

      final separationItem = mpProfile.categories
          .expand((c) => c.items)
          .firstWhere((d) => d.titleEn.contains('Strict Separation'));
      expect(separationItem.statutoryCitation, contains('BNSS 2023'));
      expect(separationItem.statutoryCitation, contains('https://www.indiacode.nic.in/handle/123456789/20062'));
      expect(separationItem.verificationStatusEn, contains('Officially Verified Constitutional & Statutory Limits'));
    });

    test('21. Verifies responsibility classification label explanations and multi-classification support', () {
      // 1. All 4 responsibility types provide meaningful English and Hindi short explanations
      for (final type in ResponsibilityType.values) {
        expect(type.shortExplanationEn, isNotEmpty);
        expect(type.shortExplanationHi, isNotEmpty);
        expect(type.badgeNameEn, isNotEmpty);
        expect(type.badgeNameHi, isNotEmpty);
      }

      // Check specific classification concepts
      expect(ResponsibilityType.statutoryDuty.shortExplanationHi, contains('कानून'));
      expect(ResponsibilityType.statutoryDuty.shortExplanationEn, contains('statutory'));
      expect(ResponsibilityType.collectiveResponsibility.shortExplanationHi, contains('सामूहिक'));
      expect(ResponsibilityType.collectiveResponsibility.shortExplanationEn, contains('Collective'));
      expect(ResponsibilityType.requiresApproval.shortExplanationHi, contains('स्वीकृति'));
      expect(ResponsibilityType.requiresApproval.shortExplanationEn, contains('approval'));
      expect(ResponsibilityType.departmentalResponsibility.shortExplanationHi, contains('विभाग'));
      expect(ResponsibilityType.departmentalResponsibility.shortExplanationEn, contains('department'));

      // 2. Multi-classification support on DutyItem
      const testItem = DutyItem(
        titleEn: 'Test Duty',
        titleHi: 'परीक्षण कर्तव्य',
        descriptionEn: 'Test description',
        descriptionHi: 'परीक्षण विवरण',
        responsibilityType: ResponsibilityType.collectiveResponsibility,
        additionalResponsibilityTypes: [ResponsibilityType.requiresApproval],
      );

      expect(testItem.allResponsibilityTypes, contains(ResponsibilityType.collectiveResponsibility));
      expect(testItem.allResponsibilityTypes, contains(ResponsibilityType.requiresApproval));
      expect(testItem.allResponsibilityTypes.length, equals(2));
    });

    test('22. Verifies enriched comprehension fields on Sarpanch, Ward Panch, Panchayat Samiti, and MP duties', () {
      final sarpanch = RepresentativeDutyService.getProfile(RepresentativeRole.sarpanch, isHaryana: true);
      final streetDuty = sarpanch.categories
          .expand((c) => c.items)
          .firstWhere((d) => d.titleEn.contains('Village Internal Streets'));

      expect(streetDuty.representativeRoleEn, isNotNull);
      expect(streetDuty.representativeRoleHi, isNotNull);
      expect(streetDuty.activitiesIncludedEn, isNotNull);
      expect(streetDuty.activitiesIncludedHi, isNotNull);
      expect(streetDuty.intendedResultEn, isNotNull);
      expect(streetDuty.intendedResultHi, isNotNull);
      expect(streetDuty.practicalProcessEn, isNotNull);
      expect(streetDuty.practicalProcessHi, isNotNull);
      expect(streetDuty.verificationEvidenceEn, isNotNull);
      expect(streetDuty.verificationEvidenceHi, isNotNull);
      expect(streetDuty.allResponsibilityTypes.length, greaterThanOrEqualTo(2));

      // MP MPLADS duty verification
      final mp = RepresentativeDutyService.getProfile(RepresentativeRole.mp);
      final mpladsDuty = mp.categories
          .expand((c) => c.items)
          .firstWhere((d) => d.titleEn.contains('MPLADS'));

      expect(mpladsDuty.representativeRoleEn, contains('e-SAKSHI'));
      expect(mpladsDuty.representativeRoleHi, contains('ई-साक्षी'));
      expect(mpladsDuty.verificationEvidenceEn, contains('e-SAKSHI portal work sanction order'));
      expect(mpladsDuty.verificationEvidenceHi, contains('शिलापट्ट'));
    });
    test('20. Applicable roles for CITY_TOWN returns all 9 urban governance roles plus MLA and MP', () {
      final urbanRoles = RepresentativeDutyService.getApplicableRoles('CITY_TOWN');
      expect(urbanRoles, contains(RepresentativeRole.municipalChairperson));
      expect(urbanRoles, contains(RepresentativeRole.municipalCouncillor));
      expect(urbanRoles, contains(RepresentativeRole.mayor));
      expect(urbanRoles, contains(RepresentativeRole.deputyMayor));
      expect(urbanRoles, contains(RepresentativeRole.municipalViceChairperson));
      expect(urbanRoles, contains(RepresentativeRole.municipalCommitteeMember));
      expect(urbanRoles, contains(RepresentativeRole.municipalCommissioner));
      expect(urbanRoles, contains(RepresentativeRole.executiveOfficer));
      expect(urbanRoles, contains(RepresentativeRole.municipalSecretary));
      expect(urbanRoles, contains(RepresentativeRole.mla));
      expect(urbanRoles, contains(RepresentativeRole.mp));

      // Ensure rural roles are strictly absent
      expect(urbanRoles, isNot(contains(RepresentativeRole.sarpanch)));
      expect(urbanRoles, isNot(contains(RepresentativeRole.wardPanch)));
      expect(urbanRoles, isNot(contains(RepresentativeRole.panchayatSamitiMember)));
      expect(urbanRoles, isNot(contains(RepresentativeRole.zilaParishadMember)));
    });

    test('21. Administrative officers are correctly marked with isAdministrativeOfficer flag and distinct badges', () {
      final commissioner = RepresentativeDutyService.getProfile(RepresentativeRole.municipalCommissioner, stateIdentifier: 'haryana');
      final eo = RepresentativeDutyService.getProfile(RepresentativeRole.executiveOfficer, stateIdentifier: 'haryana');
      final secretary = RepresentativeDutyService.getProfile(RepresentativeRole.municipalSecretary, stateIdentifier: 'haryana');
      final mayor = RepresentativeDutyService.getProfile(RepresentativeRole.mayor, stateIdentifier: 'haryana');
      final councillor = RepresentativeDutyService.getProfile(RepresentativeRole.municipalCouncillor, stateIdentifier: 'haryana');

      expect(commissioner.isAdministrativeOfficer, isTrue);
      expect(eo.isAdministrativeOfficer, isTrue);
      expect(secretary.isAdministrativeOfficer, isTrue);
      expect(mayor.isAdministrativeOfficer, isFalse);
      expect(councillor.isAdministrativeOfficer, isFalse);

      expect(commissioner.role.officerTypeBadgeEn, contains('Administrative Officer'));
      expect(commissioner.role.officerTypeBadgeHi, contains('प्रशासनिक अधिकारी'));
      expect(mayor.role.officerTypeBadgeEn, contains('Elected Public Representative'));
      expect(mayor.role.officerTypeBadgeHi, contains('जनप्रतिनिधि'));
    });

    test('22. Urban statutory citations cite Haryana Municipal Acts for Haryana and Model Guidance outside Haryana', () {
      final haryanaMayor = RepresentativeDutyService.getProfile(RepresentativeRole.mayor, stateIdentifier: 'haryana');
      final upMayor = RepresentativeDutyService.getProfile(RepresentativeRole.mayor, stateIdentifier: 'uttar_pradesh');
      final haryanaEO = RepresentativeDutyService.getProfile(RepresentativeRole.executiveOfficer, stateIdentifier: 'haryana');
      final upEO = RepresentativeDutyService.getProfile(RepresentativeRole.executiveOfficer, stateIdentifier: 'uttar_pradesh');
      final commissioner = RepresentativeDutyService.getProfile(RepresentativeRole.municipalCommissioner, stateIdentifier: 'haryana');
      final secretary = RepresentativeDutyService.getProfile(RepresentativeRole.municipalSecretary, stateIdentifier: 'haryana');
      final chairperson = RepresentativeDutyService.getProfile(RepresentativeRole.municipalChairperson, stateIdentifier: 'haryana');
      final councillor = RepresentativeDutyService.getProfile(RepresentativeRole.municipalCouncillor, stateIdentifier: 'haryana');

      // Mayor assertions
      expect(haryanaMayor.legalReference.isStateSpecific, isTrue);
      expect(haryanaMayor.legalReference.sourceTitle, contains('The Haryana Municipal Corporation Act, 1994'));
      expect(haryanaMayor.legalReference.relevantSections, contains('Sections 4(3)'));
      expect(haryanaMayor.legalReference.relevantSections, contains('49 & 165-167'));

      // Commissioner assertions (Sec 45, 49 supervision, Sec 166 limitations)
      expect(commissioner.legalReference.relevantSections, contains('Sections 45'));
      expect(commissioner.legalReference.relevantSections, contains('49'));
      expect(commissioner.legalReference.relevantSections, isNot(contains('Sections 46-53')));
      expect(commissioner.categories.first.items.first.statutoryCitation, contains('Sec. 49, 165, 166 & 167'));
      expect(commissioner.legalLimitationsEn.any((l) => l.contains('general supervision and control of the Corporation House')), isTrue);
      expect(commissioner.legalLimitationsEn.any((l) => l.contains('Verification Pending')), isTrue);
      expect(commissioner.legalLimitationsEn.any((l) => l.contains('Haryana Act No. 13 of 2007')), isTrue);
      expect(commissioner.legalLimitationsEn.any((l) => l.contains('₹20 lakh')), isTrue);
      expect(commissioner.legalLimitationsEn.any((l) => l.contains('₹50 lakh')), isTrue);

      expect(upMayor.legalReference.isStateSpecific, isFalse);
      expect(upMayor.legalReference.sourceTitle, contains('General Model Guidance'));

      // Executive Officer assertions (Sec 38 cadre, Sec 33 delegation, Sec 50 joint execution, Sec 56-60 Fund)
      expect(haryanaEO.legalReference.isStateSpecific, isTrue);
      expect(haryanaEO.legalReference.sourceTitle, contains('The Haryana Municipal Act, 1973'));
      expect(haryanaEO.legalReference.relevantSections, contains('Sections 33'));
      expect(haryanaEO.legalReference.relevantSections, contains('38'));
      expect(haryanaEO.legalReference.relevantSections, isNot(contains('Sections 42')));
      expect(haryanaEO.legalReference.relevantSections, contains('56-60'));
      expect(haryanaEO.categories.first.items.first.statutoryCitation, contains('Sec. 33, 49, 50 & 56-60'));

      // Secretary assertions (Sec 25, 30, 38)
      expect(secretary.legalReference.relevantSections, contains('Sections 25'));
      expect(secretary.legalReference.relevantSections, contains('30'));
      expect(secretary.legalReference.relevantSections, contains('38'));
      expect(secretary.legalReference.relevantSections, isNot(contains('43, 44')));
      expect(secretary.categories.first.items.first.statutoryCitation, contains('Sec. 25 & 30'));

      // Chairperson & Councillor tightened assertions
      expect(chairperson.legalReference.relevantSections, contains('56-60'));
      final budgetDuty = chairperson.categories.expand((c) => c.items).firstWhere((d) => d.titleEn.contains('Budget'));
      expect(budgetDuty.statutoryCitation, contains('Sec. 56-60 & Haryana Municipal Account Code, 2025'));
      final execSeparationDuty = chairperson.categories.expand((c) => c.items).firstWhere((d) => d.titleEn.contains('Statutory Allocation'));
      expect(execSeparationDuty.statutoryCitation, contains('Sec. 33, 49, 50'));

      final councillorDelibDuty = councillor.categories.expand((c) => c.items).firstWhere((d) => d.titleEn.contains('Separation'));
      expect(councillorDelibDuty.statutoryCitation, contains('Sec. 25-29, 50'));
      expect(councillorDelibDuty.statutoryCitation, isNot(contains('Sec. 35')));

      // Direct official URLs & Safeguards
      expect(haryanaMayor.legalReference.sourceUrl, equals('https://ulbharyana.gov.in/the-haryana-municipal-corporation-act-1994'));
      expect(commissioner.legalReference.sourceUrl, equals('https://ulbharyana.gov.in/the-haryana-municipal-corporation-act-1994'));
      expect(haryanaEO.legalReference.sourceUrl, equals('https://ulbharyana.gov.in/the-haryana-municipal-act-1973'));
      expect(secretary.legalReference.sourceUrl, equals('https://ulbharyana.gov.in/the-haryana-municipal-act-1973'));
      expect(upMayor.legalReference.sourceUrl, equals('https://legislative.gov.in/constitution-of-india'));
      expect(haryanaEO.legalLimitationsEn.any((l) => l.contains('Section 38 provides for the constitution of the Municipal Service')), isTrue);
      expect(haryanaEO.legalLimitationsEn.any((l) => l.contains('Section 35 is strictly an extraordinary emergency provision')), isTrue);
      expect(haryanaEO.legalLimitationsEn.any((l) => l.contains('Section 50 mandates joint execution')), isTrue);

      expect(upEO.legalReference.isStateSpecific, isFalse);
    });

    test('23. Enriched comprehension fields are fully populated for urban civic responsibilities', () {
      final councillor = RepresentativeDutyService.getProfile(RepresentativeRole.municipalCouncillor, stateIdentifier: 'haryana');
      final streetDuty = councillor.categories
          .expand((c) => c.items)
          .firstWhere((d) => d.titleEn.contains('Paver Blocks'));

      expect(streetDuty.activitiesIncludedEn, isNotNull);
      expect(streetDuty.activitiesIncludedHi, isNotNull);
      expect(streetDuty.intendedResultEn, isNotNull);
      expect(streetDuty.intendedResultHi, isNotNull);
      expect(streetDuty.practicalProcessEn, isNotNull);
      expect(streetDuty.practicalProcessHi, isNotNull);
      expect(streetDuty.verificationEvidenceEn, isNotNull);
      expect(streetDuty.verificationEvidenceHi, isNotNull);
      expect(streetDuty.statutoryCitation, contains('The Haryana Municipal Act, 1973'));

      // Check citizen Q&A
      expect(councillor.citizenQa.length, greaterThanOrEqualTo(3));
      final firstQa = councillor.citizenQa.first;
      expect(firstQa.questionEn, contains('ward'));
      expect(firstQa.questionHi, contains('वार्ड'));
      expect(firstQa.answerEn, contains('Property Tax'));
      expect(firstQa.answerHi, contains('प्रॉपर्टी'));
    });
  });
}
