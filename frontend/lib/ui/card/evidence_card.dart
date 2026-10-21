import 'package:flutter/material.dart';
import '../../models/evidence.dart';

/// Reusable EvidenceCard widget.
/// ALL evidence card UI must use this widget. Do NOT create local Card
/// implementations in individual pages.
class EvidenceCard extends StatelessWidget {
  final Evidence evidence;
  final VoidCallback? onReview;
  final bool canReview;
  final EdgeInsetsGeometry? margin;

  const EvidenceCard({
    super.key,
    required this.evidence,
    this.onReview,
    this.canReview = false,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _EvidenceTypeChip(sourceType: evidence.sourceType),
                const SizedBox(width: 8),
                _EvidenceStatusChip(status: evidence.status),
                const Spacer(),
                Text(
                  _formatDate(evidence.uploadedAt),
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              evidence.title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              evidence.description,
              style: theme.textTheme.bodySmall,
            ),
            if (evidence.documentRef != null && evidence.documentRef!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.description_outlined, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Ref: ${evidence.documentRef}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (evidence.url != null && evidence.url!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.link, size: 14, color: theme.colorScheme.secondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      evidence.url!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.secondary,
                        decoration: TextDecoration.underline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (evidence.reviewNotes != null && evidence.reviewNotes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          evidence.isVerified
                              ? Icons.verified
                              : (evidence.isDisputed ? Icons.warning_amber : Icons.rate_review),
                          size: 14,
                          color: evidence.isVerified
                              ? Colors.green
                              : (evidence.isDisputed ? Colors.red : theme.colorScheme.primary),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Review Notes (${evidence.status.toUpperCase()})',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      evidence.reviewNotes!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (canReview && onReview != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onReview,
                  icon: const Icon(Icons.rate_review_outlined, size: 16),
                  label: const Text('Review Evidence'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _EvidenceTypeChip extends StatelessWidget {
  final String sourceType;
  const _EvidenceTypeChip({required this.sourceType});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = _metadata;
    return Chip(
      avatar: Icon(icon, size: 12, color: color),
      label: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.4), width: 0.5),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.only(right: 6, left: 2),
      visualDensity: VisualDensity.compact,
    );
  }

  (String, IconData, Color) get _metadata => switch (sourceType) {
        'DOCUMENT' => ('Document', Icons.description, Colors.blueGrey),
        'URL' => ('Web Link', Icons.public, Colors.indigo),
        'PHOTOGRAPH' => ('Photograph', Icons.photo_camera, Colors.teal),
        'ORAL_TESTIMONY' => ('Oral Testimony', Icons.record_voice_over, Colors.deepPurple),
        'GOVERNMENT_RECORD' => ('Gov Record', Icons.account_balance, Colors.brown),
        'ACADEMIC_PAPER' => ('Academic', Icons.school, Colors.blue),
        'NEWS_ARTICLE' => ('News', Icons.newspaper, Colors.orange),
        _ => ('Other', Icons.attach_file, Colors.grey),
      };
}

class _EvidenceStatusChip extends StatelessWidget {
  final String status;
  const _EvidenceStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _metadata;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  (String, Color) get _metadata => switch (status) {
        'verified' => ('Verified Evidence', Colors.green),
        'rejected' => ('Rejected', Colors.red.shade900),
        'disputed' => ('Disputed Evidence', Colors.red),
        'submitted' => ('Submitted (Unreviewed)', Colors.orange),
        _ => (status, Colors.grey),
      };
}
