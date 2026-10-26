import 'package:flutter/material.dart';
import '../../models/place.dart';
import '../../models/place_progress.dart';
import '../../models/representative_duty.dart';
import '../pages/representatives/representative_duties_detail_page.dart';

/// Reusable Section Header for Location-Centric Content
class SectionHeaderCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final String sectionLetter;
  final int? count;

  const SectionHeaderCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.sectionLetter,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              sectionLetter,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (count != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$count',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable card displaying an honest unavailable state with explanation
class UnavailableStatusCard extends StatelessWidget {
  final String title;
  final String message;
  final String? citationRequirement;
  final VoidCallback? onContribute;
  final String contributeLabel;
  final Key? contributeKey;
  final IconData icon;

  const UnavailableStatusCard({
    super.key,
    required this.title,
    required this.message,
    this.citationRequirement,
    this.onContribute,
    this.contributeLabel = 'Contribute Data',
    this.contributeKey,
    this.icon = Icons.info_outline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0.5,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Unavailable',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (citationRequirement != null) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.menu_book_outlined, size: 14, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      citationRequirement!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (onContribute != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: contributeKey,
                  onPressed: onContribute,
                  icon: const Icon(Icons.add, size: 14),
                  label: Text(contributeLabel, style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reusable card displaying verified/estimated PlaceAttribute with source and reference year
class PlaceAttributeCard extends StatelessWidget {
  final PlaceAttribute attribute;
  final VoidCallback? onCorrect;

  const PlaceAttributeCard({
    super.key,
    required this.attribute,
    this.onCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEstimate = attribute.uncertainty != null && attribute.uncertainty!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    attribute.category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatAttributeKey(attribute.key),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                if (isEstimate)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Estimate (${attribute.uncertainty})',
                      style: const TextStyle(fontSize: 10, color: Colors.deepOrange, fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Verified Record',
                      style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              attribute.value,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.source, size: 12, color: theme.colorScheme.outline),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _buildSourceString(),
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _buildSourceString() {
    final parts = <String>[];
    if (attribute.sourceDescription.isNotEmpty) {
      parts.add('Source: ${attribute.sourceDescription}');
    }
    if (attribute.reportedPeriod != null && attribute.reportedPeriod!.isNotEmpty) {
      parts.add('Period / Year: ${attribute.reportedPeriod}');
    } else if (attribute.reportedDate != null) {
      parts.add('Reference Date: ${attribute.reportedDate!.year}');
    }
    return parts.isEmpty ? 'Source: Community Record' : parts.join(' • ');
  }

  String _formatAttributeKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}

/// Administrative Structure and Elected Representatives Card
/// Only shows offices and representatives relevant to the selected place's actual administrative structure.
class AdministrativeStructureCard extends StatelessWidget {
  final Place place;
  final List<PlaceAttribute> attributes;
  final VoidCallback? onContributeRepresentative;

  const AdministrativeStructureCard({
    super.key,
    required this.place,
    required this.attributes,
    this.onContributeRepresentative,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final applicableOffices = _getApplicableOffices(place.level);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_outlined, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Administrative Classification & Structure',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Classification note: avoid exact single-token 'Village' or 'City / Town'
            Text(
              'Administrative Jurisdiction: ${_formatLevelName(place.level)}',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (place.parentPath != null && place.parentPath!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  Text('Hierarchy: ', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                  ...place.parentPath!.map(
                    (p) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${p.canonicalName} (${_formatLevelName(p.level)})',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 20),
            Row(
              children: [
                Icon(Icons.how_to_reg_outlined, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Applicable Elected Representatives',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Showing only governance offices applicable to this administrative level (${_formatLevelName(place.level)}):',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 8),
            ...applicableOffices.map((office) {
              final recordedAttr = _findLeadershipAttribute(office.key);
              return _buildOfficeRow(context, theme, office, recordedAttr);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficeRow(
    BuildContext context,
    ThemeData theme,
    _RepresentativeOffice office,
    PlaceAttribute? attr,
  ) {
    final hasVerifiedValue = attr != null && attr.value.trim().isNotEmpty;
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';

    void openDuties() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RepresentativeDutiesDetailPage(
            place: place,
            role: office.role,
            attribute: attr,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('office_row_${office.role.name}'),
          borderRadius: BorderRadius.circular(8),
          onTap: openDuties,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    hasVerifiedValue ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                    size: 16,
                    color: hasVerifiedValue ? Colors.green : theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: theme.textTheme.bodySmall,
                          children: [
                            TextSpan(
                              text: '${office.title}: ',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (hasVerifiedValue)
                              TextSpan(text: attr.value)
                            else
                              TextSpan(
                                text: isHindi
                                    ? 'जानकारी उपलब्ध नहीं (Not recorded in community database - Official election citation required)'
                                    : 'Information Not Available (Not recorded in community database - Official election citation required)',
                                style: TextStyle(color: theme.colorScheme.outline),
                              ),
                          ],
                        ),
                      ),
                      if (hasVerifiedValue && (attr.sourceDescription.isNotEmpty || attr.reportedPeriod != null)) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Source: ${attr.sourceDescription}${attr.reportedPeriod != null ? " • Period: ${attr.reportedPeriod}" : ""}',
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: Key('view_duties_${office.role.name}'),
                  onPressed: openDuties,
                  icon: const Icon(Icons.gavel_outlined, size: 12),
                  label: Text(
                    isHindi ? 'अधिकार व कर्तव्य' : 'View Duties',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PlaceAttribute? _findLeadershipAttribute(String officeKey) {
    for (final a in attributes) {
      if (a.category == 'leadership' || a.key.toLowerCase().contains(officeKey.toLowerCase())) {
        final keyLower = a.key.toLowerCase();
        if (officeKey == 'panchayat_samiti') {
          if ((keyLower.contains('panchayat_samiti') || keyLower.contains('bdc') || keyLower.contains('block_samiti')) &&
              !keyLower.contains('chairperson') &&
              !keyLower.contains('pramukh') &&
              !keyLower.contains('president')) {
            return a;
          }
        } else if (officeKey == 'panchayat_samiti_chairperson') {
          if (keyLower.contains('pramukh') ||
              keyLower.contains('chairperson') ||
              (keyLower.contains('panchayat_samiti') && (keyLower.contains('head') || keyLower.contains('chief')))) {
            return a;
          }
        } else if (officeKey == 'zila_parishad') {
          if ((keyLower.contains('zila_parishad') || keyLower.contains('zp_member')) &&
              !keyLower.contains('chairperson') &&
              !keyLower.contains('pramukh') &&
              !keyLower.contains('chief') &&
              !keyLower.contains('president') &&
              !keyLower.contains('adhyaksh')) {
            return a;
          }
        } else if (officeKey == 'zila_parishad_chairperson' || officeKey == 'zila_parishad_chief') {
          if (keyLower.contains('zila_pramukh') ||
              keyLower.contains('adhyaksh') ||
              (keyLower.contains('zila_parishad') && (keyLower.contains('chairperson') || keyLower.contains('chief') || keyLower.contains('president')))) {
            return a;
          }
        } else if (keyLower.contains(officeKey.toLowerCase())) {
          return a;
        }
      }
    }
    return null;
  }

  List<_RepresentativeOffice> _getApplicableOffices(String level) {
    final upperLevel = level.toUpperCase();
    if (upperLevel == 'VILLAGE') {
      return const [
        _RepresentativeOffice(
          key: 'sarpanch',
          title: 'Sarpanch (Gram Panchayat Head)',
          role: RepresentativeRole.sarpanch,
        ),
        _RepresentativeOffice(
          key: 'ward_member',
          title: 'Ward Member (Panch)',
          role: RepresentativeRole.wardPanch,
        ),
        _RepresentativeOffice(
          key: 'panchayat_samiti_chairperson',
          title: 'Panchayat Samiti Chairperson (Block Pramukh)',
          role: RepresentativeRole.panchayatSamitiChairperson,
        ),
        _RepresentativeOffice(
          key: 'panchayat_samiti',
          title: 'Panchayat Samiti Member (BDC / Block Level)',
          role: RepresentativeRole.panchayatSamitiMember,
        ),
        _RepresentativeOffice(
          key: 'zila_parishad_chairperson',
          title: 'Zila Parishad Chairperson (Zila Pramukh)',
          role: RepresentativeRole.zilaParishadChairperson,
        ),
        _RepresentativeOffice(
          key: 'zila_parishad',
          title: 'Zila Parishad Member (District Level)',
          role: RepresentativeRole.zilaParishadMember,
        ),
        _RepresentativeOffice(
          key: 'mla',
          title: 'Member of Legislative Assembly (MLA)',
          role: RepresentativeRole.mla,
        ),
        _RepresentativeOffice(
          key: 'mp',
          title: 'Member of Parliament (MP)',
          role: RepresentativeRole.mp,
        ),
      ];
    } else if (upperLevel == 'SUB_DISTRICT' || upperLevel == 'TEHSIL' || upperLevel == 'BLOCK') {
      return const [
        _RepresentativeOffice(
          key: 'panchayat_samiti_chairperson',
          title: 'Panchayat Samiti Chairperson (Block Pramukh)',
          role: RepresentativeRole.panchayatSamitiChairperson,
        ),
        _RepresentativeOffice(
          key: 'panchayat_samiti',
          title: 'Panchayat Samiti Member (BDC / Block Level)',
          role: RepresentativeRole.panchayatSamitiMember,
        ),
        _RepresentativeOffice(
          key: 'zila_parishad_chairperson',
          title: 'Zila Parishad Chairperson (Zila Pramukh)',
          role: RepresentativeRole.zilaParishadChairperson,
        ),
        _RepresentativeOffice(
          key: 'zila_parishad',
          title: 'Zila Parishad Member (District Level)',
          role: RepresentativeRole.zilaParishadMember,
        ),
        _RepresentativeOffice(
          key: 'mla',
          title: 'Member of Legislative Assembly (MLA)',
          role: RepresentativeRole.mla,
        ),
        _RepresentativeOffice(
          key: 'mp',
          title: 'Member of Parliament (MP)',
          role: RepresentativeRole.mp,
        ),
      ];
    } else if (upperLevel == 'CITY_TOWN') {
      return const [
        _RepresentativeOffice(
          key: 'mayor',
          title: 'Municipal Chairperson / Mayor',
          role: RepresentativeRole.municipalChairperson,
        ),
        _RepresentativeOffice(
          key: 'councillor',
          title: 'Ward Councillor / Municipal Member',
          role: RepresentativeRole.municipalCouncillor,
        ),
        _RepresentativeOffice(
          key: 'mla',
          title: 'Member of Legislative Assembly (MLA)',
          role: RepresentativeRole.mla,
        ),
        _RepresentativeOffice(
          key: 'mp',
          title: 'Member of Parliament (MP)',
          role: RepresentativeRole.mp,
        ),
      ];
    } else if (upperLevel == 'DISTRICT') {
      return const [
        _RepresentativeOffice(
          key: 'zila_parishad_chairperson',
          title: 'Zila Parishad Chairperson (Zila Pramukh)',
          role: RepresentativeRole.zilaParishadChairperson,
        ),
        _RepresentativeOffice(
          key: 'zila_parishad',
          title: 'Zila Parishad Member (District Level)',
          role: RepresentativeRole.zilaParishadMember,
        ),
        _RepresentativeOffice(
          key: 'mla',
          title: 'Member of Legislative Assembly (MLA)',
          role: RepresentativeRole.mla,
        ),
        _RepresentativeOffice(
          key: 'mp',
          title: 'Member of Parliament (MP)',
          role: RepresentativeRole.mp,
        ),
      ];
    } else {
      return const [
        _RepresentativeOffice(
          key: 'mla',
          title: 'Member of Legislative Assembly (MLA)',
          role: RepresentativeRole.mla,
        ),
        _RepresentativeOffice(
          key: 'mp',
          title: 'Member of Parliament (MP)',
          role: RepresentativeRole.mp,
        ),
      ];
    }
  }

  String _formatLevelName(String level) {
    final upper = level.toUpperCase();
    if (upper == 'VILLAGE') return 'Gram Panchayat / Village Jurisdiction';
    if (upper == 'SUB_DISTRICT' || upper == 'TEHSIL' || upper == 'BLOCK') {
      return 'Block / Tehsil / Intermediate Jurisdiction';
    }
    if (upper == 'CITY_TOWN') return 'Urban Municipality / City-Town';
    if (upper == 'DISTRICT') return 'District Administration';
    if (upper == 'STATE') return 'State Territory';
    return level;
  }
}

class _RepresentativeOffice {
  final String key;
  final String title;
  final RepresentativeRole role;
  const _RepresentativeOffice({
    required this.key,
    required this.title,
    required this.role,
  });
}

/// Dedicated Trust & Preservation Card for Oral Traditions (Section C)
class OralTraditionsNoticeCard extends StatelessWidget {
  const OralTraditionsNoticeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0.5,
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_stories_outlined, size: 20, color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Generational Oral Traditions & Heritage',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Local proverbs, folklore, and sayings are preserved as cultural inheritance passed between generations. They reflect community wisdom and are not presented as independently verified historical facts.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
