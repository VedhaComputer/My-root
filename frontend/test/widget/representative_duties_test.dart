import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_root/core/localization/generated/app_localizations.dart';
import 'package:my_root/models/place.dart';
import 'package:my_root/models/place_progress.dart';
import 'package:my_root/ui/card/place_status_card.dart';
import 'package:my_root/ui/pages/representatives/representative_duties_detail_page.dart';

void main() {
  Widget buildTestCard({
    required Place place,
    required List<PlaceAttribute> attributes,
    Locale locale = const Locale('en'),
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('hi')],
      home: Scaffold(
        body: SingleChildScrollView(
          child: AdministrativeStructureCard(
            place: place,
            attributes: attributes,
          ),
        ),
      ),
    );
  }

  group('Elected Representatives & Duties Widget Tests', () {
    const haryanaVillage = Place(
      id: 'village-haryana-1',
      canonicalName: 'Dhamtan Sahib, Jind, Haryana',
      level: 'VILLAGE',
      names: [PlaceName(language: 'en', name: 'Dhamtan Sahib')],
      parentPath: [
        PlacePathItem(id: 'dist-jind', canonicalName: 'Jind', level: 'DISTRICT'),
        PlacePathItem(id: 'state-haryana', canonicalName: 'Haryana', level: 'STATE'),
      ],
    );

    const upCity = Place(
      id: 'city-up-1',
      canonicalName: 'Varanasi, Uttar Pradesh',
      level: 'CITY_TOWN',
      names: [PlaceName(language: 'en', name: 'Varanasi')],
      parentPath: [
        PlacePathItem(id: 'state-up', canonicalName: 'Uttar Pradesh', level: 'STATE'),
      ],
    );

    const rajasthanVillage = Place(
      id: 'village-rajasthan-1',
      canonicalName: 'Mandore, Jodhpur, Rajasthan',
      level: 'VILLAGE',
      names: [PlaceName(language: 'en', name: 'Mandore')],
      parentPath: [
        PlacePathItem(id: 'dist-jodhpur', canonicalName: 'Jodhpur', level: 'DISTRICT'),
        PlacePathItem(id: 'state-rajasthan', canonicalName: 'Rajasthan', level: 'STATE'),
      ],
    );

    const upVillage = Place(
      id: 'village-up-1',
      canonicalName: 'Shivpur, Varanasi, Uttar Pradesh',
      level: 'VILLAGE',
      names: [PlaceName(language: 'en', name: 'Shivpur')],
      parentPath: [
        PlacePathItem(id: 'dist-varanasi', canonicalName: 'Varanasi', level: 'DISTRICT'),
        PlacePathItem(id: 'state-up', canonicalName: 'Uttar Pradesh', level: 'STATE'),
      ],
    );

    testWidgets('1. Shows unverified notice when representative data is missing without inventing names', (tester) async {
      await tester.pumpWidget(
        buildTestCard(
          place: haryanaVillage,
          attributes: const [],
          locale: const Locale('hi'),
        ),
      );
      await tester.pumpAndSettle();

      // Rural offices are rendered
      expect(find.textContaining('Sarpanch (Gram Panchayat Head)'), findsOneWidget);
      expect(find.textContaining('Ward Member (Panch)'), findsOneWidget);

      // Honest unverified notice in Hindi
      expect(find.textContaining('जानकारी उपलब्ध नहीं'), findsWidgets);
      // "View Duties" buttons are available
      expect(find.byKey(const Key('view_duties_sarpanch')), findsOneWidget);
      expect(find.byKey(const Key('view_duties_wardPanch')), findsOneWidget);
    });

    testWidgets('2. Shows verified representative name, term, and period when available', (tester) async {
      final attributes = [
        PlaceAttribute(
          id: 'attr-sarp-1',
          placeId: 'village-haryana-1',
          category: 'leadership',
          key: 'sarpanch',
          value: 'Balraj Singh',
          sourceDescription: 'Haryana State Election Commission Gazette',
          reportedPeriod: '2022-2027',
          createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
        ),
      ];

      await tester.pumpWidget(
        buildTestCard(
          place: haryanaVillage,
          attributes: attributes,
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Sarpanch (Gram Panchayat Head)'), findsOneWidget);
      expect(find.textContaining('Balraj Singh'), findsOneWidget);
      expect(find.textContaining('Period: 2022-2027'), findsOneWidget);
      expect(find.textContaining('Source: Haryana State Election Commission Gazette'), findsOneWidget);
    });

    testWidgets('3. Tapping View Duties opens RepresentativeDutiesDetailPage with complete statutory content', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestCard(
          place: haryanaVillage,
          attributes: const [],
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on View Duties button for Sarpanch
      final viewDutiesBtn = find.byKey(const Key('view_duties_sarpanch'));
      expect(viewDutiesBtn, findsOneWidget);
      await tester.tap(viewDutiesBtn);
      await tester.pumpAndSettle();

      // Detail page opened
      expect(find.byType(RepresentativeDutiesDetailPage), findsOneWidget);

      // Incumbent missing shows honest message
      expect(find.textContaining('Information Not Available'), findsWidgets);

      // Haryana Panchayati Raj Act 1994 statutory reference is displayed
      expect(find.textContaining('The Haryana Panchayati Raj Act, 1994'), findsOneWidget);
      expect(find.textContaining('Statutory Legal Authority & Citations'), findsOneWidget);

      // What this representative CANNOT do
      expect(find.textContaining('Legal Limitations & Matters Outside Authority'), findsOneWidget);
      expect(find.textContaining('Cannot unilaterally expend Gram Panchayat funds'), findsOneWidget);

      // Citizen Q&A
      expect(find.textContaining('Citizen Practical Guide (FAQ)'), findsOneWidget);
      expect(find.textContaining('What can this representative do?'), findsOneWidget);

      // 6 Duty Categories
      expect(find.textContaining('Statutory Powers & Duties (6 Categories)'), findsOneWidget);

      // Grievance Escalation
      expect(find.textContaining('Grievance Redressal & Escalation Hierarchy'), findsOneWidget);
      expect(find.textContaining('Panchayat Secretary'), findsOneWidget);

      // Legal disclaimer
      expect(find.textContaining('Disclaimer: This information is presented for civic awareness'), findsOneWidget);
    });

    testWidgets('4. Non-Haryana place displays General Model Guidance', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestCard(
          place: upCity,
          attributes: const [],
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      // Urban offices shown
      expect(find.textContaining('Municipal Chairperson / Mayor'), findsOneWidget);
      expect(find.textContaining('Ward Councillor / Municipal Member'), findsOneWidget);
      expect(find.textContaining('Sarpanch (Gram Panchayat Head)'), findsNothing);

      // Tap Councillor view duties
      await tester.tap(find.byKey(const Key('view_duties_municipalCouncillor')));
      await tester.pumpAndSettle();

      expect(find.byType(RepresentativeDutiesDetailPage), findsOneWidget);
      expect(find.textContaining('General Model Guidance (National Local Governance Framework)'), findsOneWidget);
    });

    testWidgets('5. Tapping View Duties for Panchayat Samiti Chairperson opens detail page with complete statutory content', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestCard(
          place: haryanaVillage,
          attributes: const [],
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      // Chairperson office is displayed
      expect(find.textContaining('Panchayat Samiti Chairperson (Block Pramukh)'), findsOneWidget);

      final chairDutiesBtn = find.byKey(const Key('view_duties_panchayatSamitiChairperson'));
      expect(chairDutiesBtn, findsOneWidget);
      await tester.tap(chairDutiesBtn);
      await tester.pumpAndSettle();

      // Detail page opened
      expect(find.byType(RepresentativeDutiesDetailPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Panchayat Samiti Chairperson (Block Pramukh)'),
        ),
        findsOneWidget,
      );

      // Haryana Panchayati Raj Act statutory citation
      expect(find.text('The Haryana Panchayati Raj Act, 1994 (Haryana Act No. 11 of 1994)'), findsOneWidget);
      expect(find.textContaining('Sections 56 (Constitution), 59 (Election of Chairman)'), findsOneWidget);

      // Powers & limitations
      expect(find.textContaining('Legal Limitations & Matters Outside Authority'), findsOneWidget);
      expect(find.textContaining('Does NOT have individual executive control over block administration'), findsOneWidget);
      expect(find.textContaining('Block Development and Panchayat Officer (BDPO)'), findsWidgets);

      // Citizen FAQ
      expect(find.textContaining('Citizen Practical Guide (FAQ)'), findsOneWidget);
      expect(find.textContaining('What can this representative do?'), findsOneWidget);

      // Grievance hierarchy
      expect(find.textContaining('Grievance Redressal & Escalation Hierarchy'), findsOneWidget);
      expect(find.textContaining('CEO, Zila Parishad'), findsOneWidget);
    });

    testWidgets('6. Tapping View Duties for Panchayat Samiti Member in Hindi opens detail page with BDC guidance', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestCard(
          place: haryanaVillage,
          attributes: const [],
          locale: const Locale('hi'),
        ),
      );
      await tester.pumpAndSettle();

      // Panchayat Samiti Member office is displayed
      expect(find.textContaining('Panchayat Samiti Member (BDC / Block Level)'), findsOneWidget);

      final memberDutiesBtn = find.byKey(const Key('view_duties_panchayatSamitiMember'));
      expect(memberDutiesBtn, findsOneWidget);
      await tester.tap(memberDutiesBtn);
      await tester.pumpAndSettle();

      // Detail page opened in Hindi
      expect(find.byType(RepresentativeDutiesDetailPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('पंचायत समिति सदस्य (BDC / ब्लॉक स्तर)'),
        ),
        findsOneWidget,
      );

      // Hindi statutory citations & FAQ
      expect(find.textContaining('नागरिकों के लिए मुख्य प्रश्न'), findsOneWidget);
      expect(find.textContaining('क्या पंचायत समिति सदस्य के पास व्यक्तिगत फंड कोटा होता है?'), findsOneWidget);

      // Clear limitations in Hindi
      expect(find.textContaining('कानूनी सीमाएं व अधिकार क्षेत्र से बाहर के कार्य'), findsOneWidget);
      expect(find.textContaining('कोई व्यक्तिगत कार्यकारी या वित्तीय अधिकार नहीं है'), findsOneWidget);
    });

    testWidgets('7. Tapping View Duties for Zila Parishad Chairperson in Haryana opens detail page with Section 121/123 citations and CEO executive separation', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestCard(
          place: haryanaVillage,
          attributes: const [],
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      // Zila Parishad Chairperson office displayed on card
      expect(find.textContaining('Zila Parishad Chairperson (Zila Pramukh)'), findsOneWidget);

      final chairDutiesBtn = find.byKey(const Key('view_duties_zilaParishadChairperson'));
      expect(chairDutiesBtn, findsOneWidget);
      await tester.tap(chairDutiesBtn);
      await tester.pumpAndSettle();

      // Detail page opened
      expect(find.byType(RepresentativeDutiesDetailPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Zila Parishad Chairperson (Zila Pramukh / President)'),
        ),
        findsOneWidget,
      );

      // Haryana Panchayati Raj Act statutory citation
      expect(find.text('The Haryana Panchayati Raj Act, 1994 (Haryana Act No. 11 of 1994)'), findsOneWidget);
      expect(find.textContaining('Sections 117 (Constitution), 121 (Powers and duties of President)'), findsOneWidget);

      // Powers & CEO separation limitations
      expect(find.textContaining('Legal Limitations & Matters Outside Authority'), findsOneWidget);
      expect(find.textContaining('Executive administration and financial disbursements are statutorily vested in the Chief Executive Officer (CEO)'), findsOneWidget);

      // Citizen FAQ
      expect(find.textContaining('Citizen Practical Guide (FAQ)'), findsOneWidget);
      expect(find.textContaining('What can this representative do?'), findsOneWidget);

      // Grievance hierarchy
      expect(find.textContaining('Grievance Redressal & Escalation Hierarchy'), findsOneWidget);
      expect(find.textContaining('Chief Executive Officer (CEO), Zila Parishad'), findsOneWidget);
    });

    testWidgets('8. Tapping View Duties for Zila Parishad Member in Rajasthan in Hindi opens detail page with absence of individual member fund quota', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestCard(
          place: rajasthanVillage,
          attributes: const [],
          locale: const Locale('hi'),
        ),
      );
      await tester.pumpAndSettle();

      // Zila Parishad Member office displayed on card
      expect(find.textContaining('Zila Parishad Member (District Level)'), findsOneWidget);

      final memberDutiesBtn = find.byKey(const Key('view_duties_zilaParishadMember'));
      expect(memberDutiesBtn, findsOneWidget);
      await tester.tap(memberDutiesBtn);
      await tester.pumpAndSettle();

      // Detail page opened in Hindi
      expect(find.byType(RepresentativeDutiesDetailPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('जिला परिषद सदस्य (जिला स्तर)'),
        ),
        findsOneWidget,
      );

      // Rajasthan Panchayati Raj Act statutory citation
      expect(find.text('The Rajasthan Panchayati Raj Act, 1994 (Act No. 13 of 1994)'), findsOneWidget);
      expect(find.textContaining('Sections 14 (Composition), 15 (Elected Members), 27 (Rights and Duties of Members)'), findsOneWidget);

      // Hindi FAQ & Lack of individual fund quota
      expect(find.textContaining('नागरिकों के लिए मुख्य प्रश्न'), findsOneWidget);
      expect(find.textContaining('क्या जिला परिषद सदस्य के पास व्यक्तिगत विवेकाधीन फंड कोटा होता है?'), findsOneWidget);

      // Hindi Limitations
      expect(find.textContaining('कानूनी सीमाएं व अधिकार क्षेत्र से बाहर के कार्य'), findsOneWidget);
      expect(find.textContaining('कोई व्यक्तिगत विवेकाधीन विकास फंड कोटा या व्यक्तिगत चेक हस्ताक्षर अधिकार नहीं है'), findsOneWidget);

      // Rajasthan Grievance Escalation
      expect(find.textContaining('राजस्थान संपर्क पोर्टल (181)'), findsOneWidget);
    });

    testWidgets('9. Unsupported state displays General Model Guidance with amber unverified indicator', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestCard(
          place: upVillage,
          attributes: const [],
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Zila Parishad Chairperson view duties
      final chairDutiesBtn = find.byKey(const Key('view_duties_zilaParishadChairperson'));
      expect(chairDutiesBtn, findsOneWidget);
      await tester.tap(chairDutiesBtn);
      await tester.pumpAndSettle();

      expect(find.byType(RepresentativeDutiesDetailPage), findsOneWidget);

      // General Model Guidance headers and badge
      expect(find.text('General Model Guidance (National Local Governance Framework)'), findsOneWidget);
      expect(find.textContaining('General Model Guidance (Unverified State Law)'), findsOneWidget);
      expect(find.textContaining('State-Specific Legislation Pending Verification'), findsOneWidget);
      expect(find.textContaining('Constitution (73rd Amendment) Act, 1992'), findsOneWidget);
    });

    testWidgets('10. Renders MLA duties with Constitutional citations, executive separation, and state MLALAD funds', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestCard(
          place: haryanaVillage,
          attributes: const [],
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      final mlaBtn = find.byKey(const Key('view_duties_mla'));
      expect(mlaBtn, findsOneWidget);
      await tester.tap(mlaBtn);
      await tester.pumpAndSettle();

      expect(find.byType(RepresentativeDutiesDetailPage), findsOneWidget);

      // Verify constitutional and assembly citation
      expect(find.textContaining('Constitution of India (Part VI, Arts. 168-212)'), findsOneWidget);
      expect(find.textContaining('Rules of Procedure and Conduct of Business in the Haryana Legislative Assembly'), findsWidgets);

      // Verify 6 duty categories rendered
      expect(find.textContaining('Statutory Powers & Duties (6 Categories)'), findsOneWidget);

      // Verify Haryana VANGY development fund item verified at Rs 2 Crore
      expect(find.textContaining('Rs 2 Crore'), findsWidgets);
      expect(find.textContaining('Vidhayak Adarsh Nagar Avam Gram Yojana'), findsWidgets);

      // Verify executive separation and limits
      expect(find.textContaining('Has NO direct administrative or executive authority to sanction or award public tenders'), findsOneWidget);

      // Verify FAQ
      expect(find.textContaining('Can an MLA direct police officers to register, alter, or dismiss an FIR?'), findsOneWidget);

      // Verify grievance escalation
      expect(find.textContaining('Lokayukta Haryana'), findsOneWidget);
    });

    testWidgets('11. Renders Rajasthan MLA duties in Hindi with Vidhan Sabha rules and MLA-LAD 20% SC/ST mandate', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestCard(
          place: rajasthanVillage,
          attributes: const [],
          locale: const Locale('hi'),
        ),
      );
      await tester.pumpAndSettle();

      final mlaBtn = find.byKey(const Key('view_duties_mla'));
      expect(mlaBtn, findsOneWidget);
      await tester.tap(mlaBtn);
      await tester.pumpAndSettle();

      expect(find.byType(RepresentativeDutiesDetailPage), findsOneWidget);

      // Verify Hindi title and statutory citation
      expect(find.textContaining('विधायक (विधान सभा सदस्य - राजस्थान)'), findsWidgets);
      expect(find.textContaining('Constitution of India (Part VI, Arts. 168-212)'), findsOneWidget);
      expect(find.textContaining('Rules of Procedure of Rajasthan Vidhan Sabha'), findsWidgets);

      // Verify Hindi development fund text including 20% SC/ST mandate
      expect(find.textContaining('रु 5 करोड़'), findsWidgets);
      expect(find.textContaining('एससी/एसटी विकास हेतु अनिवार्य है'), findsOneWidget);

      // Verify Hindi executive separation
      expect(find.textContaining('पुलिस को किसी मामले में एफआईआर दर्ज करने, बदलने या रद्द करने का सीधा आदेश नहीं दे सकते'), findsOneWidget);

      // Verify Rajasthan escalation
      expect(find.textContaining('राजस्थान संपर्क पोर्टल (181)'), findsOneWidget);
    });

    testWidgets('12. Renders MP duties with Union Constitutional Grounding, MPLADS ₹5 Cr, DISHA, and separation of powers', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestCard(
          place: haryanaVillage,
          attributes: const [],
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      final mpBtn = find.byKey(const Key('view_duties_mp'));
      expect(mpBtn, findsOneWidget);
      await tester.tap(mpBtn);
      await tester.pumpAndSettle();

      expect(find.byType(RepresentativeDutiesDetailPage), findsOneWidget);

      // Verify Union Constitutional Grounding badge
      expect(find.text('Union Constitutional & Statutory Grounding'), findsOneWidget);
      expect(find.textContaining('Constitution of India (Part V, Arts. 79-122)'), findsOneWidget);
      expect(find.textContaining('Parliament of India (Lok Sabha / Rajya Sabha)'), findsWidgets);

      // Verify 6 duty categories rendered
      expect(find.textContaining('Statutory Powers & Duties (6 Categories)'), findsOneWidget);

      // Verify MPLADS allocation & territorial rules
      expect(find.textContaining('₹5 Crore per annum under MoSPI Guidelines'), findsOneWidget);

      // Verify DISHA Committee
      expect(find.textContaining('senior-most Lok Sabha MP elected from the district is designated as the CHAIRPERSON of the DISHA Committee'), findsOneWidget);

      // Verify Executive Separation & Limits
      expect(find.textContaining('Has NO personal account receipt, custody, or cheque-signing authority over MPLADS funds'), findsOneWidget);
      expect(find.textContaining('Cannot order police officers to register, alter, or dismiss criminal FIRs'), findsOneWidget);

      // Verify FAQ
      expect(find.textContaining('What is the primary constitutional role of a Member of Parliament (MP)?'), findsOneWidget);
    });

    testWidgets('13. Renders MP duties in Hindi with Constitutional elections, Lok Sabha no-confidence, and MPLADS ₹5 Crore', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestCard(
          place: upCity,
          attributes: const [],
          locale: const Locale('hi'),
        ),
      );
      await tester.pumpAndSettle();

      final mpBtn = find.byKey(const Key('view_duties_mp'));
      expect(mpBtn, findsOneWidget);
      await tester.tap(mpBtn);
      await tester.pumpAndSettle();

      expect(find.byType(RepresentativeDutiesDetailPage), findsOneWidget);

      // Verify Hindi title & Union badge
      expect(find.textContaining('सांसद (संसद सदस्य - लोक सभा / राज्य सभा)'), findsWidgets);
      expect(find.text('केंद्रीय संवैधानिक व वैधानिक आधार द्वारा सत्यापित'), findsOneWidget);

      // Verify Hindi MPLADS text
      expect(find.textContaining('₹5 करोड़'), findsWidgets);

      // Verify Hindi No-confidence motion
      expect(find.textContaining('अविश्वास प्रस्ताव (अनुच्छेद 75(3) व नियम 198 के तहत केवल लोक सभा का अधिकार)'), findsOneWidget);

      // Verify Hindi President vs VP voting distinctions
      expect(find.textContaining('राष्ट्रपति व उपराष्ट्रपति चुनावों में मतदान (संवैधानिक निर्वाचक मंडल का अंतर)'), findsOneWidget);

      // Verify Hindi legal limitations
      expect(find.textContaining('सांसद निधि (MPLADS) का पैसा कभी भी सांसद के व्यक्तिगत बैंक खाते में नहीं आता'), findsOneWidget);
    });
  });
}
