import 'package:flutter/material.dart';
import '../../models/place.dart';

/// Reusable PlaceCard widget.
/// ALL place card UI must use this widget. Do NOT create local Card
/// implementations in individual pages.
class PlaceCard extends StatelessWidget {
  final Place place;
  final VoidCallback? onTap;

  const PlaceCard({
    super.key,
    required this.place,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final localizedName = place.nameForLanguage(locale);
    final showLocalized = localizedName.isNotEmpty && localizedName != place.canonicalName;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _levelColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _levelColor.withValues(alpha: 0.3)),
                ),
                child: Icon(_levelIcon, color: _levelColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _PlaceLevelChip(level: place.level),
                        const Spacer(),
                        if (place.parentPath != null && place.parentPath!.isNotEmpty)
                          Text(
                            '${place.parentPath!.length} levels up',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      place.canonicalName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showLocalized) ...[
                      const SizedBox(height: 2),
                      Text(
                        localizedName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (place.parentPath != null && place.parentPath!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        place.parentPath!.map((p) => p.canonicalName).join(' › '),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData get _levelIcon => switch (place.level) {
        'COUNTRY' => Icons.public,
        'STATE' => Icons.map,
        'DISTRICT' => Icons.location_city,
        'CITY_TOWN' => Icons.apartment,
        'VILLAGE' => Icons.holiday_village,
        _ => Icons.place,
      };

  Color get _levelColor => switch (place.level) {
        'COUNTRY' => Colors.indigo,
        'STATE' => Colors.deepPurple,
        'DISTRICT' => Colors.teal,
        'CITY_TOWN' => Colors.blue,
        'VILLAGE' => Colors.green,
        _ => Colors.grey,
      };
}

class _PlaceLevelChip extends StatelessWidget {
  final String level;

  const _PlaceLevelChip({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 10,
          color: _color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String get _label => switch (level) {
        'COUNTRY' => 'Country',
        'STATE' => 'State',
        'DISTRICT' => 'District',
        'CITY_TOWN' => 'City / Town',
        'VILLAGE' => 'Village',
        _ => level,
      };

  Color get _color => switch (level) {
        'COUNTRY' => Colors.indigo,
        'STATE' => Colors.deepPurple,
        'DISTRICT' => Colors.teal,
        'CITY_TOWN' => Colors.blue,
        'VILLAGE' => Colors.green,
        _ => Colors.grey,
      };
}
