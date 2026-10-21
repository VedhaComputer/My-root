import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../models/user.dart';

class HomeFeaturesDrawer extends StatelessWidget {
  final VoidCallback onExploreStories;
  final VoidCallback onContribute;
  final void Function(String category) onCategory;
  final VoidCallback onAdd;
  final String? selectedPlaceName;
  final User? user;

  const HomeFeaturesDrawer({
    super.key,
    required this.onExploreStories,
    required this.onContribute,
    required this.onCategory,
    required this.onAdd,
    this.selectedPlaceName,
    this.user,
  });

  void _handleTap(BuildContext context, VoidCallback action) {
    // Smoothly auto-close the drawer before executing destination action
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final effectiveName = (user != null && user!.displayName.trim().isNotEmpty)
        ? user!.displayName.trim()
        : (user != null ? 'User' : 'Guest');
    final effectiveInitial = effectiveName.isNotEmpty
        ? effectiveName.substring(0, 1).toUpperCase()
        : 'U';

    return Drawer(
      key: const Key('home_features_drawer'),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drawer Header: Authenticated User Profile
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                border: Border(
                  bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.primary,
                    child: user != null
                        ? Text(
                            effectiveInitial,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : Icon(
                            Icons.person_outline,
                            color: theme.colorScheme.onPrimary,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          effectiveName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (user != null && user!.role.isNotEmpty)
                          Text(
                            user!.role.replaceAll('_', ' '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          )
                        else if (selectedPlaceName != null && selectedPlaceName!.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.place, size: 12, color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  selectedPlaceName!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable feature list with all 9 shortcuts
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // 1. Explore Stories
                  ListTile(
                    key: const Key('feature_explore_stories'),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.blue.withValues(alpha: 0.15),
                      child: const Icon(Icons.explore, size: 18, color: Colors.blue),
                    ),
                    title: Text(
                      l10n?.exploreButtonLabel ?? 'Explore Stories',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('Discover documented knowledge and stories'),
                    onTap: () => _handleTap(context, onExploreStories),
                  ),

                  // 2. Contribute
                  ListTile(
                    key: const Key('feature_contribute'),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.teal.withValues(alpha: 0.15),
                      child: const Icon(Icons.add_circle_outline, size: 18, color: Colors.teal),
                    ),
                    title: Text(
                      l10n?.contributeButtonLabel ?? 'Contribute',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('Submit community facts, records, or experiences'),
                    onTap: () => _handleTap(context, onContribute),
                  ),

                  const Divider(indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      'Categories',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // 3. Historical Record
                  ListTile(
                    key: const Key('feature_historical_record'),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.brown.withValues(alpha: 0.15),
                      child: const Icon(Icons.history_edu, size: 18, color: Colors.brown),
                    ),
                    title: Text(
                      l10n?.categoryHistoricalRecord ?? 'Historical Record',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () => _handleTap(
                      context,
                      () => onCategory(ClaimCategory.historicalRecord),
                    ),
                  ),

                  // 4. Current Fact
                  ListTile(
                    key: const Key('feature_current_fact'),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.blue.withValues(alpha: 0.15),
                      child: const Icon(Icons.fact_check, size: 18, color: Colors.blue),
                    ),
                    title: Text(
                      l10n?.categoryCurrentFact ?? 'Current Fact',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () => _handleTap(
                      context,
                      () => onCategory(ClaimCategory.currentFact),
                    ),
                  ),

                  // 5. Folklore / Proverb
                  ListTile(
                    key: const Key('feature_folklore'),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.purple.withValues(alpha: 0.15),
                      child: const Icon(Icons.auto_stories, size: 18, color: Colors.purple),
                    ),
                    title: Text(
                      l10n?.categoryFolklore ?? 'Folklore / Proverb',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () => _handleTap(
                      context,
                      () => onCategory(ClaimCategory.folklore),
                    ),
                  ),

                  // 6. Personal Experience
                  ListTile(
                    key: const Key('feature_personal_experience'),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.teal.withValues(alpha: 0.15),
                      child: const Icon(Icons.person, size: 18, color: Colors.teal),
                    ),
                    title: Text(
                      l10n?.categoryPersonalExperience ?? 'Personal Experience',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () => _handleTap(
                      context,
                      () => onCategory(ClaimCategory.personalExperience),
                    ),
                  ),

                  // 7. Public Opinion
                  ListTile(
                    key: const Key('feature_public_opinion'),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.orange.withValues(alpha: 0.15),
                      child: const Icon(Icons.groups, size: 18, color: Colors.orange),
                    ),
                    title: Text(
                      l10n?.categoryPublicOpinion ?? 'Public Opinion',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () => _handleTap(
                      context,
                      () => onCategory(ClaimCategory.publicOpinion),
                    ),
                  ),

                  // 8. Survey Data
                  ListTile(
                    key: const Key('feature_survey_data'),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.indigo.withValues(alpha: 0.15),
                      child: const Icon(Icons.bar_chart, size: 18, color: Colors.indigo),
                    ),
                    title: Text(
                      l10n?.categorySurveyData ?? 'Survey Data',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () => _handleTap(
                      context,
                      () => onCategory(ClaimCategory.surveyData),
                    ),
                  ),

                  const Divider(indent: 16, endIndent: 16),

                  // 9. Add
                  ListTile(
                    key: const Key('feature_add'),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                      child: Icon(Icons.post_add, size: 18, color: theme.colorScheme.primary),
                    ),
                    title: const Text(
                      'Add',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Create a new community entry'),
                    onTap: () => _handleTap(context, onAdd),
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
