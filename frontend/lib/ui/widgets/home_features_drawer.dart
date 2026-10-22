import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../models/user.dart';

class HomeFeaturesDrawer extends StatelessWidget {
  final VoidCallback? onHome;
  final VoidCallback? onProfile;
  final VoidCallback onExploreStories;
  final VoidCallback onContribute;
  final void Function(String category) onCategory;
  final VoidCallback onAdd;
  final String? selectedPlaceName;
  final User? user;
  final String currentRoute;

  const HomeFeaturesDrawer({
    super.key,
    this.onHome,
    this.onProfile,
    required this.onExploreStories,
    required this.onContribute,
    required this.onCategory,
    required this.onAdd,
    this.selectedPlaceName,
    this.user,
    this.currentRoute = 'home',
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
                        if (user != null && (user!.indigenousClassification?.isNotEmpty == true || user!.role.isNotEmpty))
                          Text(
                            user!.indigenousClassification?.isNotEmpty == true
                                ? user!.indigenousClassification!
                                : user!.role.replaceAll('_', ' '),
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

            // Scrollable feature list with Navigation, Features, Categories, and Add
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Navigation Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      'Navigation',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // 1. Home
                  ListTile(
                    key: const Key('feature_home'),
                    selected: currentRoute == 'home',
                    selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    selectedColor: theme.colorScheme.primary,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: currentRoute == 'home'
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.home,
                        size: 18,
                        color: currentRoute == 'home'
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      l10n?.navHome ?? 'Home',
                      style: TextStyle(
                        fontWeight: currentRoute == 'home' ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text('Community knowledge overview'),
                    onTap: () => _handleTap(context, onHome ?? () {}),
                  ),

                  const Divider(indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      'Features',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // 3. Explore Stories
                  ListTile(
                    key: const Key('feature_explore_stories'),
                    selected: currentRoute == 'explore_stories',
                    selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    selectedColor: theme.colorScheme.primary,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: currentRoute == 'explore_stories'
                          ? theme.colorScheme.primary
                          : Colors.blue.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.explore,
                        size: 18,
                        color: currentRoute == 'explore_stories'
                            ? theme.colorScheme.onPrimary
                            : Colors.blue,
                      ),
                    ),
                    title: Text(
                      l10n?.exploreButtonLabel ?? 'Explore Stories',
                      style: TextStyle(
                        fontWeight: currentRoute == 'explore_stories' ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text('Discover documented knowledge and stories'),
                    onTap: () => _handleTap(context, onExploreStories),
                  ),

                  // 4. Contribute
                  ListTile(
                    key: const Key('feature_contribute'),
                    selected: currentRoute == 'contribute',
                    selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    selectedColor: theme.colorScheme.primary,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: currentRoute == 'contribute'
                          ? theme.colorScheme.primary
                          : Colors.teal.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.add_circle_outline,
                        size: 18,
                        color: currentRoute == 'contribute'
                            ? theme.colorScheme.onPrimary
                            : Colors.teal,
                      ),
                    ),
                    title: Text(
                      l10n?.contributeButtonLabel ?? 'Contribute',
                      style: TextStyle(
                        fontWeight: currentRoute == 'contribute' ? FontWeight.bold : FontWeight.w600,
                      ),
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

                  // 5. Historical Record
                  ListTile(
                    key: const Key('feature_historical_record'),
                    selected: currentRoute == ClaimCategory.historicalRecord,
                    selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    selectedColor: theme.colorScheme.primary,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: currentRoute == ClaimCategory.historicalRecord
                          ? theme.colorScheme.primary
                          : Colors.brown.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.history_edu,
                        size: 18,
                        color: currentRoute == ClaimCategory.historicalRecord
                            ? theme.colorScheme.onPrimary
                            : Colors.brown,
                      ),
                    ),
                    title: Text(
                      l10n?.categoryHistoricalRecord ?? 'Historical Record',
                      style: TextStyle(
                        fontWeight: currentRoute == ClaimCategory.historicalRecord ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    onTap: () => _handleTap(
                      context,
                      () => onCategory(ClaimCategory.historicalRecord),
                    ),
                  ),

                  // 6. Current Fact
                  ListTile(
                    key: const Key('feature_current_fact'),
                    selected: currentRoute == ClaimCategory.currentFact,
                    selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    selectedColor: theme.colorScheme.primary,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: currentRoute == ClaimCategory.currentFact
                          ? theme.colorScheme.primary
                          : Colors.blue.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.fact_check,
                        size: 18,
                        color: currentRoute == ClaimCategory.currentFact
                            ? theme.colorScheme.onPrimary
                            : Colors.blue,
                      ),
                    ),
                    title: Text(
                      l10n?.categoryCurrentFact ?? 'Current Fact',
                      style: TextStyle(
                        fontWeight: currentRoute == ClaimCategory.currentFact ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    onTap: () => _handleTap(
                      context,
                      () => onCategory(ClaimCategory.currentFact),
                    ),
                  ),

                  // 7. Folklore / Proverb
                  ListTile(
                    key: const Key('feature_folklore'),
                    selected: currentRoute == ClaimCategory.folklore,
                    selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    selectedColor: theme.colorScheme.primary,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: currentRoute == ClaimCategory.folklore
                          ? theme.colorScheme.primary
                          : Colors.purple.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.auto_stories,
                        size: 18,
                        color: currentRoute == ClaimCategory.folklore
                            ? theme.colorScheme.onPrimary
                            : Colors.purple,
                      ),
                    ),
                    title: Text(
                      l10n?.categoryFolklore ?? 'Folklore / Proverb',
                      style: TextStyle(
                        fontWeight: currentRoute == ClaimCategory.folklore ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    onTap: () => _handleTap(
                      context,
                      () => onCategory(ClaimCategory.folklore),
                    ),
                  ),

                  // 8. Personal Experience
                  ListTile(
                    key: const Key('feature_personal_experience'),
                    selected: currentRoute == ClaimCategory.personalExperience,
                    selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    selectedColor: theme.colorScheme.primary,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: currentRoute == ClaimCategory.personalExperience
                          ? theme.colorScheme.primary
                          : Colors.teal.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.person,
                        size: 18,
                        color: currentRoute == ClaimCategory.personalExperience
                            ? theme.colorScheme.onPrimary
                            : Colors.teal,
                      ),
                    ),
                    title: Text(
                      l10n?.categoryPersonalExperience ?? 'Personal Experience',
                      style: TextStyle(
                        fontWeight: currentRoute == ClaimCategory.personalExperience ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    onTap: () => _handleTap(
                      context,
                      () => onCategory(ClaimCategory.personalExperience),
                    ),
                  ),

                  // 9. Public Opinion
                  ListTile(
                    key: const Key('feature_public_opinion'),
                    selected: currentRoute == ClaimCategory.publicOpinion,
                    selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    selectedColor: theme.colorScheme.primary,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: currentRoute == ClaimCategory.publicOpinion
                          ? theme.colorScheme.primary
                          : Colors.orange.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.groups,
                        size: 18,
                        color: currentRoute == ClaimCategory.publicOpinion
                            ? theme.colorScheme.onPrimary
                            : Colors.orange,
                      ),
                    ),
                    title: Text(
                      l10n?.categoryPublicOpinion ?? 'Public Opinion',
                      style: TextStyle(
                        fontWeight: currentRoute == ClaimCategory.publicOpinion ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    onTap: () => _handleTap(
                      context,
                      () => onCategory(ClaimCategory.publicOpinion),
                    ),
                  ),

                  // 10. Survey Data
                  ListTile(
                    key: const Key('feature_survey_data'),
                    selected: currentRoute == ClaimCategory.surveyData,
                    selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    selectedColor: theme.colorScheme.primary,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: currentRoute == ClaimCategory.surveyData
                          ? theme.colorScheme.primary
                          : Colors.indigo.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.bar_chart,
                        size: 18,
                        color: currentRoute == ClaimCategory.surveyData
                            ? theme.colorScheme.onPrimary
                            : Colors.indigo,
                      ),
                    ),
                    title: Text(
                      l10n?.categorySurveyData ?? 'Survey Data',
                      style: TextStyle(
                        fontWeight: currentRoute == ClaimCategory.surveyData ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    onTap: () => _handleTap(
                      context,
                      () => onCategory(ClaimCategory.surveyData),
                    ),
                  ),

                  const Divider(indent: 16, endIndent: 16),

                  // 11. Add
                  ListTile(
                    key: const Key('feature_add'),
                    selected: currentRoute == 'add',
                    selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    selectedColor: theme.colorScheme.primary,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: currentRoute == 'add'
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.post_add,
                        size: 18,
                        color: currentRoute == 'add'
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.primary,
                      ),
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
