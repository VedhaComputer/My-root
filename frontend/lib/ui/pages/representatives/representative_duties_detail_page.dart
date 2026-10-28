import 'package:flutter/material.dart';
import '../../../models/place.dart';
import '../../../models/place_progress.dart';
import '../../../models/representative_duty.dart';
import '../../../services/auth_service.dart';
import '../../../services/representative_duty_service.dart';
import '../polls/create_poll_page.dart';
import '../polls/polls_list_page.dart';

class RepresentativeDutiesDetailPage extends StatelessWidget {
  final Place place;
  final RepresentativeRole role;
  final PlaceAttribute? attribute;
  final AuthService? authService;

  const RepresentativeDutiesDetailPage({
    super.key,
    required this.place,
    required this.role,
    this.attribute,
    this.authService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final stateName = RepresentativeDutyService.extractStateName(place);
    final profile = RepresentativeDutyService.getProfile(role, place: place);
    final isStateSpecific = profile.legalReference.isStateSpecific;

    final String representativeName = (attribute != null && attribute!.value.trim().isNotEmpty)
        ? attribute!.value.trim()
        : (isHindi ? 'जानकारी उपलब्ध नहीं' : 'Information Not Available');

    final bool isVerified = attribute != null &&
        (attribute!.sourceDescription.isNotEmpty || attribute!.reportedPeriod != null);

    final String? term = attribute?.reportedPeriod;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isHindi ? profile.titleHi : profile.titleEn,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // 1. Header Card: Post, Name, Jurisdiction
            // ==========================================
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(Icons.account_balance, color: theme.colorScheme.onPrimaryContainer, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isHindi ? profile.titleHi : profile.titleEn,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isHindi ? profile.governingBodyHi : profile.governingBodyEn,
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: profile.isAdministrativeOfficer
                                      ? theme.colorScheme.tertiaryContainer
                                      : theme.colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isHindi
                                      ? profile.role.officerTypeBadgeHi
                                      : profile.role.officerTypeBadgeEn,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: profile.isAdministrativeOfficer
                                        ? theme.colorScheme.onTertiaryContainer
                                        : theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    // Representative Name
                    Row(
                      children: [
                        Icon(
                          isVerified ? Icons.verified : Icons.help_outline,
                          size: 16,
                          color: isVerified ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isHindi
                              ? (profile.isAdministrativeOfficer ? 'वर्तमान पदस्थ अधिकारी: ' : 'वर्तमान पदधारी: ')
                              : (profile.isAdministrativeOfficer ? 'Incumbent Officer: ' : 'Incumbent: '),
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Text(
                            representativeName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: isVerified ? FontWeight.w600 : FontWeight.normal,
                              color: isVerified ? theme.colorScheme.onSurface : theme.colorScheme.outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (term != null && term.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_month_outlined, size: 16, color: theme.colorScheme.outline),
                          const SizedBox(width: 6),
                          Text(
                            isHindi ? 'कार्यकाल: $term' : 'Term: $term',
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 16, color: theme.colorScheme.outline),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${place.canonicalName} ($stateName)',
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================
            // Live Public Opinion Poll Entry Point
            // ==========================================
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.how_to_vote, color: theme.colorScheme.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isHindi ? 'लाइव जनमत सर्वेक्षण' : 'Live Public Opinion Poll',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isHindi
                                    ? '$representativeName के कार्य व व्यवहार पर जनमत देखें या अपनी राय दर्ज करें।'
                                    : 'View public opinion on $representativeName or cast your vote with reasons.',
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.search, size: 16),
                            label: Text(isHindi ? 'पोल देखें' : 'View Polls'),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PollsListPage(
                                    authService: authService,
                                    initialSearch: representativeName != (isHindi ? 'जानकारी उपलब्ध नहीं' : 'Information Not Available')
                                        ? representativeName
                                        : profile.titleEn,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(isHindi ? 'नया पोल बनाएं' : 'Start Poll'),
                            onPressed: () {
                              final defaultName = representativeName != (isHindi ? 'जानकारी उपलब्ध नहीं' : 'Information Not Available')
                                  ? representativeName
                                  : '';
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CreatePollPage(
                                    initialPersonName: defaultName,
                                    initialPersonRole: isHindi ? profile.titleHi : profile.titleEn,
                                    initialPlaceId: place.id,
                                    initialPlaceName: place.canonicalName,
                                    initialTargetEntityId: role.key,
                                    authService: authService,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================
            // 2. Statutory Legal Reference & Verification Box
            // ==========================================
            Card(
              elevation: 0.5,
              color: isStateSpecific
                  ? Colors.blue.withValues(alpha: 0.08)
                  : Colors.amber.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.gavel, size: 16, color: isStateSpecific ? Colors.blue.shade800 : Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isHindi ? 'कानूनी आधार व वैधानिक संदर्भ' : 'Statutory Legal Authority & Citations',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isStateSpecific ? Colors.blue.shade900 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isStateSpecific ? Colors.blue.shade100 : Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            profile.legalReference.jurisdictionState,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isStateSpecific ? Colors.blue.shade900 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isStateSpecific ? Colors.green.shade50 : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isStateSpecific ? Colors.green.shade300 : Colors.amber.shade400,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isStateSpecific ? Icons.verified : Icons.warning_amber_rounded,
                            size: 14,
                            color: isStateSpecific ? Colors.green.shade800 : Colors.amber.shade900,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isStateSpecific
                                ? (profile.role == RepresentativeRole.mp
                                    ? (isHindi ? 'केंद्रीय संवैधानिक व वैधानिक आधार द्वारा सत्यापित' : 'Union Constitutional & Statutory Grounding')
                                    : (isHindi ? 'राज्य कानून द्वारा सत्यापित' : 'State Statutory Grounding'))
                                : (profile.role == RepresentativeRole.mp
                                    ? (isHindi
                                        ? 'सामान्य केंद्रीय ढांचा (सत्यापन लंबित - Union Verification Pending)'
                                        : 'General Union Model — Statutory Verification Pending')
                                    : (isHindi
                                        ? 'सामान्य मॉडल ढांचा (अपुष्ट राज्य कानून - State-Specific Legislation Pending Verification)'
                                        : 'General Model Guidance (Unverified State Law) — State-Specific Legislation Pending Verification')),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isStateSpecific ? Colors.green.shade900 : Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profile.legalReference.sourceTitle,
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isHindi ? "प्रासंगिक धाराएं/नियम: " : "Relevant Sections/Rules: "}${profile.legalReference.relevantSections}',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isHindi ? profile.legalReference.officialGuidanceNoteHi : profile.legalReference.officialGuidanceNoteEn,
                      style: theme.textTheme.labelSmall?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.outline),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.verified_outlined, size: 12, color: theme.colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          '${isHindi ? "अंतिम सत्यापन तिथि: " : "Last Verified: "}${profile.legalReference.lastVerifiedDate}',
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline, fontSize: 10),
                        ),
                      ],
                    ),
                    if (profile.legalReference.sourceUrl.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.link, size: 12, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${isHindi ? "आधिकारिक स्रोत: " : "Official Source: "}${profile.legalReference.sourceUrl}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================
            // 3. Citizen Questions ("नागरिकों के लिए मुख्य प्रश्न")
            // ==========================================
            Text(
              isHindi ? 'नागरिकों के लिए मुख्य प्रश्न' : 'Citizen Practical Guide (FAQ)',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...profile.citizenQa.map((qa) => _buildQaCard(context, theme, qa, isHindi)),
            const SizedBox(height: 16),

            // ==========================================
            // 3b. Classification Labels Guide / Legend
            // ==========================================
            _buildClassificationLegend(theme, isHindi),
            const SizedBox(height: 16),

            // ==========================================
            // 4. Six Categorized Duties & Powers Sections
            // ==========================================
            Text(
              isHindi ? 'संवैधानिक दायित्व एवं अधिकार क्षेत्र (6 श्रेणियां)' : 'Statutory Powers & Duties (6 Categories)',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...profile.categories.map((cat) => _buildCategorySection(context, theme, cat, isHindi)),
            const SizedBox(height: 16),

            // ==========================================
            // 5. Key Legal Limitations & Prohibitions
            // ==========================================
            Card(
              elevation: 0.5,
              color: Colors.red.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.block, size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          isHindi ? 'कानूनी सीमाएं व अधिकार क्षेत्र से बाहर के कार्य' : 'Legal Limitations & Matters Outside Authority',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...(isHindi ? profile.legalLimitationsHi : profile.legalLimitationsEn).map(
                      (limit) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                limit,
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================
            // 6. Grievance Escalation & Appropriate Authority
            // ==========================================
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.report_problem_outlined, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          isHindi ? 'शिकायत व समस्या निवारण की प्रक्रिया' : 'Grievance Redressal & Escalation Hierarchy',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isHindi ? profile.grievanceEscalationHi : profile.grievanceEscalationEn,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================
            // 7. Informational Legal Disclaimer
            // ==========================================
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: theme.colorScheme.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isHindi
                          ? 'अस्वीकरण: यह जानकारी नागरिकों की सामान्य जागरूकता और विधिक साक्षरता के लिए है। इसे व्यक्तिगत कानूनी सलाह न माना जाए। किसी भी विधिक विवाद में संबंधित अधिनियम के मूल गजट का संदर्भ लें।'
                          : 'Disclaimer: This information is presented for civic awareness and educational literacy. It does not constitute personalized legal advice. In legal disputes, refer to the authoritative gazetted statute.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildQaCard(BuildContext context, ThemeData theme, CitizenQaItem qa, bool isHindi) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        title: Text(
          isHindi ? qa.questionHi : qa.questionEn,
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        leading: Icon(Icons.help_outline, color: theme.colorScheme.primary, size: 18),
        childrenPadding: const EdgeInsets.only(left: 14, right: 14, bottom: 12),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              isHindi ? qa.answerHi : qa.answerEn,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    ThemeData theme,
    DutyCategorySection cat,
    bool isHindi,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getCategoryIcon(cat.category, theme),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isHindi
                        ? (cat.customTitleHi ?? cat.category.titleHi)
                        : (cat.customTitleEn ?? cat.category.titleEn),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            ...cat.items.map((item) => _buildDutyWorkCard(theme, item, isHindi)),
          ],
        ),
      ),
    );
  }

  Widget _buildClassificationLegend(ThemeData theme, bool isHindi) {
    return Card(
      key: const Key('classification_labels_guide'),
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.label_outline, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isHindi ? 'जिम्मेदारी श्रेणियों का अर्थ (दायित्व वर्गीकरण)' : 'Understanding Responsibility Labels',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isHindi
                  ? 'प्रत्येक कार्य के साथ अंकित लेबल यह स्पष्ट करते हैं कि वह प्रतिनिधि का सीधा कानूनी दायित्व है, सामूहिक निर्णय है, विहित स्वीकृति पर निर्भर है या किसी सरकारी विभाग का कार्य है:'
                  : 'Each work item carries a classification indicating whether it is an individual statutory duty, collective decision, requires administrative approval, or belongs to a government department:',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            ...ResponsibilityType.values.map(
              (type) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildResponsibilityBadge(theme, type, isHindi),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isHindi ? type.shortExplanationHi : type.shortExplanationEn,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDutyWorkCard(ThemeData theme, DutyItem item, bool isHindi) {
    final allTypes = item.allResponsibilityTypes;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and classification badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  isHindi ? item.titleHi : item.titleEn,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: allTypes.map((t) => _buildResponsibilityBadge(theme, t, isHindi)).toList(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Explanatory badge pill/strip explaining what the classification means for this duty
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: allTypes.map((t) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 12, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${isHindi ? t.badgeNameHi : t.badgeNameEn}: ${isHindi ? t.shortExplanationHi : t.shortExplanationEn}',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Plain-language description: What this work means
          Text(
            isHindi ? item.descriptionHi : item.descriptionEn,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.4,
            ),
          ),
          // Representative's Role (प्रतिनिधि की भूमिका)
          if (item.representativeRoleEn != null) ...[
            const SizedBox(height: 6),
            _buildDetailRow(
              icon: Icons.person_pin_outlined,
              iconColor: Colors.blue.shade800,
              labelHi: 'प्रतिनिधि की भूमिका: ',
              labelEn: 'Role of Representative: ',
              valueHi: item.representativeRoleHi ?? item.representativeRoleEn!,
              valueEn: item.representativeRoleEn!,
              isHindi: isHindi,
              theme: theme,
            ),
          ],
          // Activities included (शामिल मुख्य गतिविधियां)
          if (item.activitiesIncludedEn != null) ...[
            const SizedBox(height: 4),
            _buildDetailRow(
              icon: Icons.checklist_outlined,
              iconColor: Colors.indigo.shade800,
              labelHi: 'शामिल मुख्य गतिविधियां: ',
              labelEn: 'Activities Included: ',
              valueHi: item.activitiesIncludedHi ?? item.activitiesIncludedEn!,
              valueEn: item.activitiesIncludedEn!,
              isHindi: isHindi,
              theme: theme,
            ),
          ],
          // Intended Result (अपेक्षित परिणाम व प्रभाव)
          if (item.intendedResultEn != null) ...[
            const SizedBox(height: 4),
            _buildDetailRow(
              icon: Icons.track_changes_outlined,
              iconColor: Colors.teal.shade800,
              labelHi: 'अपेक्षित परिणाम: ',
              labelEn: 'Intended Result: ',
              valueHi: item.intendedResultHi ?? item.intendedResultEn!,
              valueEn: item.intendedResultEn!,
              isHindi: isHindi,
              theme: theme,
            ),
          ],
          // Practical Process & Approval Authority (प्रक्रिया व सक्षम स्वीकृति)
          if (item.practicalProcessEn != null || item.procedureOrApprovalEn != null) ...[
            const SizedBox(height: 4),
            _buildDetailRow(
              icon: Icons.rule_outlined,
              iconColor: Colors.orange.shade800,
              labelHi: 'प्रक्रिया व स्वीकृति: ',
              labelEn: 'Process & Approval: ',
              valueHi: item.practicalProcessHi ?? item.procedureOrApprovalHi ?? item.practicalProcessEn ?? item.procedureOrApprovalEn!,
              valueEn: item.practicalProcessEn ?? item.procedureOrApprovalEn!,
              isHindi: isHindi,
              theme: theme,
            ),
          ],
          // Responsible Line Department (संबंधित विभाग)
          if (item.lineDepartmentEn != null) ...[
            const SizedBox(height: 4),
            _buildDetailRow(
              icon: Icons.business_outlined,
              iconColor: Colors.teal.shade800,
              labelHi: 'संबंधित विभाग: ',
              labelEn: 'Department: ',
              valueHi: item.lineDepartmentHi ?? item.lineDepartmentEn!,
              valueEn: item.lineDepartmentEn!,
              isHindi: isHindi,
              theme: theme,
            ),
          ],
          // Citizen Evidence Verification (साक्ष्य व जांचने का तरीका)
          if (item.verificationEvidenceEn != null) ...[
            const SizedBox(height: 4),
            _buildDetailRow(
              icon: Icons.fact_check_outlined,
              iconColor: Colors.green.shade800,
              labelHi: 'साक्ष्य व जांच का तरीका: ',
              labelEn: 'Verification & Records: ',
              valueHi: item.verificationEvidenceHi ?? item.verificationEvidenceEn!,
              valueEn: item.verificationEvidenceEn!,
              isHindi: isHindi,
              theme: theme,
            ),
          ],
          // Limitations (सीमा / क्या नहीं कर सकते)
          if (item.limitationEn != null) ...[
            const SizedBox(height: 4),
            _buildDetailRow(
              icon: Icons.remove_circle_outline,
              iconColor: Colors.red.shade800,
              labelHi: 'सीमा / प्रतिबंध: ',
              labelEn: 'Limitation: ',
              valueHi: item.limitationHi ?? item.limitationEn!,
              valueEn: item.limitationEn!,
              isHindi: isHindi,
              theme: theme,
            ),
          ],
          // Jurisdiction Scope (अधिकार क्षेत्र)
          if (item.jurisdictionScopeEn != null) ...[
            const SizedBox(height: 4),
            _buildDetailRow(
              icon: Icons.map_outlined,
              iconColor: Colors.indigo.shade800,
              labelHi: 'अधिकार क्षेत्र: ',
              labelEn: 'Jurisdiction: ',
              valueHi: item.jurisdictionScopeHi ?? item.jurisdictionScopeEn!,
              valueEn: item.jurisdictionScopeEn!,
              isHindi: isHindi,
              theme: theme,
            ),
          ],
          // Verification Status (सत्यापन स्थिति)
          if (item.verificationStatusEn != null) ...[
            const SizedBox(height: 4),
            _buildDetailRow(
              icon: item.verificationStatusEn!.contains('Pending')
                  ? Icons.pending_actions_outlined
                  : ((item.verificationStatusEn!.contains('Executive') ||
                          item.verificationStatusEn!.contains('Guideline') ||
                          item.verificationStatusEn!.contains('Protocol') ||
                          item.verificationStatusEn!.contains('Facilitation') ||
                          item.verificationStatusEn!.contains('Scheme') ||
                          item.verificationStatusEn!.contains('Practice') ||
                          item.verificationStatusEn!.contains('Convention'))
                      ? Icons.info_outline
                      : Icons.verified_outlined),
              iconColor: item.verificationStatusEn!.contains('Pending')
                  ? Colors.amber.shade900
                  : ((item.verificationStatusEn!.contains('Executive') ||
                          item.verificationStatusEn!.contains('Guideline') ||
                          item.verificationStatusEn!.contains('Protocol') ||
                          item.verificationStatusEn!.contains('Facilitation') ||
                          item.verificationStatusEn!.contains('Scheme') ||
                          item.verificationStatusEn!.contains('Practice') ||
                          item.verificationStatusEn!.contains('Convention'))
                      ? Colors.blue.shade900
                      : Colors.green.shade900),
              labelHi: 'सत्यापन स्थिति: ',
              labelEn: 'Status: ',
              valueHi: item.verificationStatusHi ?? item.verificationStatusEn!,
              valueEn: item.verificationStatusEn!,
              isHindi: isHindi,
              theme: theme,
            ),
          ],
          // Statutory citation
          if (item.statutoryCitation != null) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.menu_book_outlined, size: 12, color: theme.colorScheme.outline),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${isHindi ? "विशिष्ट वैधानिक संदर्भ / स्रोत: " : "Specific Statutory Citation / Source: "}${item.statutoryCitation!}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String labelHi,
    required String labelEn,
    required String valueHi,
    required String valueEn,
    required bool isHindi,
    required ThemeData theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 4),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, color: theme.colorScheme.onSurface),
              children: [
                TextSpan(
                  text: isHindi ? labelHi : labelEn,
                  style: TextStyle(fontWeight: FontWeight.bold, color: iconColor),
                ),
                TextSpan(
                  text: isHindi ? valueHi : valueEn,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResponsibilityBadge(ThemeData theme, ResponsibilityType type, bool isHindi) {
    Color bg;
    Color fg;
    switch (type) {
      case ResponsibilityType.statutoryDuty:
        bg = Colors.blue.withValues(alpha: 0.15);
        fg = Colors.blue.shade900;
        break;
      case ResponsibilityType.collectiveResponsibility:
        bg = Colors.purple.withValues(alpha: 0.15);
        fg = Colors.purple.shade900;
        break;
      case ResponsibilityType.requiresApproval:
        bg = Colors.orange.withValues(alpha: 0.15);
        fg = Colors.orange.shade900;
        break;
      case ResponsibilityType.departmentalResponsibility:
        bg = Colors.teal.withValues(alpha: 0.15);
        fg = Colors.teal.shade900;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isHindi ? type.badgeNameHi : type.badgeNameEn,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _getCategoryIcon(DutyCategory category, ThemeData theme) {
    IconData icon;
    Color color;
    switch (category) {
      case DutyCategory.publicAssets:
        icon = Icons.alt_route;
        color = Colors.blue;
        break;
      case DutyCategory.schemesAndBeneficiaries:
        icon = Icons.handshake_outlined;
        color = Colors.green;
        break;
      case DutyCategory.meetingsAndBudgets:
        icon = Icons.groups_outlined;
        color = Colors.indigo;
        break;
      case DutyCategory.socialSectorCoordination:
        icon = Icons.school_outlined;
        color = Colors.teal;
        break;
      case DutyCategory.welfareAndDisaster:
        icon = Icons.emergency_outlined;
        color = Colors.deepOrange;
        break;
      case DutyCategory.legalLimitsAndExclusions:
        icon = Icons.rule_folder_outlined;
        color = Colors.red;
        break;
    }
    return Icon(icon, size: 18, color: color);
  }
}
