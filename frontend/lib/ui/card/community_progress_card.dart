import 'package:flutter/material.dart';
import '../../models/place_progress.dart';

/// Reusable CommunityProgressCard widget under lib/ui/card/
class CommunityProgressCard extends StatelessWidget {
  final PlaceProgress progress;
  final VoidCallback? onContributeTap;

  const CommunityProgressCard({
    super.key,
    required this.progress,
    this.onContributeTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.military_tech, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Community Knowledge Score',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Fair evaluation: based on evidence quality, not population',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${progress.qualityCoverageScore}/100',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (progress.qualityCoverageScore / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _MetricItem(
                  icon: Icons.verified,
                  label: 'Verified Facts',
                  count: progress.verifiedFactsCount,
                  color: Colors.green,
                ),
                _MetricItem(
                  icon: Icons.pending,
                  label: 'In Review',
                  count: progress.pendingReviewCount,
                  color: Colors.amber.shade800,
                ),
                _MetricItem(
                  icon: Icons.auto_stories,
                  label: 'Folklore & Tradition',
                  count: progress.folkloreCount,
                  color: Colors.purple,
                ),
                _MetricItem(
                  icon: Icons.person,
                  label: 'Biographies',
                  count: progress.biographiesCount,
                  color: Colors.teal,
                ),
                _MetricItem(
                  icon: Icons.location_city,
                  label: 'Facilities',
                  count: progress.facilitiesCount,
                  color: Colors.blue,
                ),
                _MetricItem(
                  icon: Icons.attach_file,
                  label: 'Evidence Files',
                  count: progress.evidenceAttachmentsCount,
                  color: Colors.indigo,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              progress.criteriaExplanation,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _MetricItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Text(
          '$count',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
