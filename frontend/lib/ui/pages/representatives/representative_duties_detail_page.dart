import 'package:flutter/material.dart';
import '../../../models/place.dart';
import '../../../models/place_progress.dart';
import '../../../models/representative_duty.dart';
import '../../../services/representative_duty_service.dart';

class RepresentativeDutiesDetailPage extends StatelessWidget {
  final Place place;
  final RepresentativeRole role;
  final PlaceAttribute? attribute;

  const RepresentativeDutiesDetailPage({
    super.key,
    required this.place,
    required this.role,
    this.attribute,
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
                          isHindi ? 'वर्तमान पदधारी: ' : 'Incumbent: ',
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
                                ? (isHindi ? 'राज्य कानून द्वारा सत्यापित' : 'State Statutory Grounding')
                                : (isHindi
                                    ? 'सामान्य मॉडल ढांचा (अपुष्ट राज्य कानून - State-Specific Legislation Pending Verification)'
                                    : 'General Model Guidance (Unverified State Law) — State-Specific Legislation Pending Verification'),
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
            ...cat.items.map((item) => _buildDutyItemRow(theme, item, isHindi)),
          ],
        ),
      ),
    );
  }

  Widget _buildDutyItemRow(ThemeData theme, DutyItem item, bool isHindi) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  isHindi ? item.titleHi : item.titleEn,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              _buildResponsibilityBadge(theme, item.responsibilityType, isHindi),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isHindi ? item.descriptionHi : item.descriptionEn,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (item.limitationEn != null) ...[
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.remove_circle_outline, size: 12, color: Colors.red.shade800),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${isHindi ? "सीमा / प्रतिबंध: " : "Limitation: "}${isHindi ? item.limitationHi ?? item.limitationEn : item.limitationEn}',
                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.red.shade900, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
          if (item.procedureOrApprovalEn != null) ...[
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.rule_outlined, size: 12, color: Colors.orange.shade800),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${isHindi ? "प्रक्रिया/स्वीकृति: " : "Procedure/Approval: "}${isHindi ? item.procedureOrApprovalHi ?? item.procedureOrApprovalEn : item.procedureOrApprovalEn}',
                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.orange.shade900, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
          if (item.lineDepartmentEn != null) ...[
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.business_outlined, size: 12, color: Colors.teal.shade800),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${isHindi ? "संबंधित विभाग: " : "Department: "}${isHindi ? item.lineDepartmentHi ?? item.lineDepartmentEn : item.lineDepartmentEn}',
                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.teal.shade900, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
          if (item.jurisdictionScopeEn != null) ...[
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.map_outlined, size: 12, color: Colors.indigo.shade800),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${isHindi ? "अधिकार क्षेत्र: " : "Jurisdiction: "}${isHindi ? item.jurisdictionScopeHi ?? item.jurisdictionScopeEn : item.jurisdictionScopeEn}',
                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.indigo.shade900, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
          if (item.verificationStatusEn != null) ...[
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_outlined, size: 12, color: Colors.green.shade800),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${isHindi ? "सत्यापन स्थिति: " : "Status: "}${isHindi ? item.verificationStatusHi ?? item.verificationStatusEn : item.verificationStatusEn}',
                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.green.shade900, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
          if (item.statutoryCitation != null) ...[
            const SizedBox(height: 2),
            Text(
              item.statutoryCitation!,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline, fontSize: 10, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
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
