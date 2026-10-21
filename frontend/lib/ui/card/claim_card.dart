import 'package:flutter/material.dart';
import '../../models/claim.dart';

/// Reusable ClaimCard widget.
/// ALL claim card UI must use this widget. Do NOT create local Card
/// implementations in individual pages.
class ClaimCard extends StatelessWidget {
  final Claim claim;
  final VoidCallback? onTap;

  const ClaimCard({super.key, required this.claim, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CategoryChip(category: claim.category),
                  const SizedBox(width: 8),
                  _StatusChip(status: claim.status),
                  const Spacer(),
                  if (claim.isFolklore)
                    Tooltip(
                      message: 'Folklore — not independently verified as historical fact',
                      child: Icon(Icons.info_outline, size: 16, color: theme.colorScheme.secondary),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                claim.title.original,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                claim.body.original,
                style: theme.textTheme.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (claim.sourceAttribution != null || claim.timePeriod != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: theme.colorScheme.outline),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${claim.sourceAttribution ?? "Source recorded"}${claim.timePeriod != null ? " • (${claim.timePeriod})" : ""}',
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.attach_file, size: 14, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text('${claim.evidenceCount} evidence', style: theme.textTheme.labelSmall),
                  if (claim.consentObtained) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: (claim.consentState == 'consent_verified' ? Colors.teal : Colors.amber)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            claim.consentState == 'consent_verified' ? Icons.check_circle : Icons.hourglass_top,
                            size: 10,
                            color: claim.consentState == 'consent_verified' ? Colors.teal : Colors.amber.shade800,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            claim.consentState == 'consent_verified' ? 'Consent Verified' : 'Consent Declared (Pending Verification)',
                            style: TextStyle(
                              fontSize: 9,
                              color: claim.consentState == 'consent_verified' ? Colors.teal : Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    _formatDate(claim.submittedAt),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(_label, style: const TextStyle(fontSize: 10)),
      backgroundColor: _color.withValues(alpha: 0.15),
      side: BorderSide(color: _color, width: 0.5),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      visualDensity: VisualDensity.compact,
    );
  }

  String get _label => switch (category) {
        'HISTORICAL_RECORD' => 'History',
        'CURRENT_FACT' => 'Fact',
        'FOLKLORE' => 'Folklore',
        'PERSONAL_EXPERIENCE' => 'Experience',
        'PUBLIC_OPINION' => 'Opinion',
        'SURVEY_DATA' => 'Survey',
        'DISPUTED_CLAIM' => 'Disputed',
        _ => category,
      };

  Color get _color => switch (category) {
        'HISTORICAL_RECORD' => Colors.brown,
        'CURRENT_FACT' => Colors.blue,
        'FOLKLORE' => Colors.purple,
        'PERSONAL_EXPERIENCE' => Colors.teal,
        'PUBLIC_OPINION' => Colors.orange,
        'SURVEY_DATA' => Colors.indigo,
        'DISPUTED_CLAIM' => Colors.red,
        _ => Colors.grey,
      };
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _color, width: 0.5),
      ),
      child: Text(_label,
          style: TextStyle(fontSize: 10, color: _color, fontWeight: FontWeight.w600)),
    );
  }

  String get _label => switch (status) {
        'draft' => 'Draft',
        'submitted' => 'Submitted',
        'under_review' => 'In Review',
        'verified' => 'Verified',
        'partially_verified' => 'Partial',
        'unverified' => 'Unverified',
        'disputed' => 'Disputed',
        'insufficient_evidence' => 'Insufficient',
        'rejected' => 'Rejected',
        'archived' => 'Archived',
        _ => status,
      };

  Color get _color => switch (status) {
        'verified' => Colors.green,
        'partially_verified' => Colors.lightGreen,
        'unverified' => Colors.orange,
        'disputed' => Colors.red,
        'rejected' => Colors.red.shade900,
        'insufficient_evidence' => Colors.deepOrange,
        'archived' => Colors.grey,
        _ => Colors.blueGrey,
      };
}
