import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../models/claim.dart';
import '../../../models/place.dart';
import '../../../services/auth_service.dart';
import '../../../services/place_service.dart';
import '../../../services/community_service.dart';
import '../../../repositories/community_repository.dart';
import '../../card/place_card.dart';
import '../../card/claim_card.dart';
import '../../card/matrbhoomi_card.dart';
import 'progressive_contribution_page.dart';
import '../claims/claim_detail_page.dart';

class PlaceDetailPage extends StatefulWidget {
  final String placeId;
  final Place? initialPlace;
  final PlaceService placeService;
  final CommunityService? communityService;
  final AuthService? authService;
  final String? initialCategory;
  final bool openContribution;
  final VoidCallback? onBackToHome;

  const PlaceDetailPage({
    super.key,
    required this.placeId,
    this.initialPlace,
    required this.placeService,
    this.communityService,
    this.authService,
    this.initialCategory,
    this.openContribution = false,
    this.onBackToHome,
  });

  @override
  State<PlaceDetailPage> createState() => _PlaceDetailPageState();
}

class _PlaceDetailPageState extends State<PlaceDetailPage> {
  late final CommunityService _communityService;
  bool _showMatrbhoomiPrompt = false;
  int _matrbhoomiStep = 1; // 1 = Q1, 2 = Q2, 3 = Contribute prompt
  bool _highlightApprovedHistory = false;

  @override
  void initState() {
    super.initState();
    _communityService = widget.communityService ??
        CommunityService(
          repository: CommunityRepositoryImpl(client: widget.placeService.repository.client),
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadDetail();
        _checkMatrbhoomiPromptStatus();
      }
    });
  }

  Future<void> _checkMatrbhoomiPromptStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = widget.authService?.currentUser;

      // Only prompt for user's designated home/selected place (selectedPlaceId or verifiedLocationId)
      final userHomePlaceId = user?.selectedPlaceId ??
          user?.verifiedLocationId ??
          (user != null ? prefs.getString('selected_place_id_${user.id}') : prefs.getString('selected_place_id'));

      if (userHomePlaceId == null || userHomePlaceId != widget.placeId) {
        // Do NOT prompt repeatedly across every PlaceDetailPage during general browsing!
        return;
      }

      final key = user != null
          ? 'matrbhoomi_prompt_${user.id}_${widget.placeId}'
          : 'matrbhoomi_prompt_${widget.placeId}';
      final hasAnsweredLocal = prefs.getBool(key) ?? false;

      final userInterest = user?.getInterestForPlace(widget.placeId);
      final hasAnsweredServer = userInterest != null;

      if (!hasAnsweredLocal && !hasAnsweredServer) {
        if (mounted) {
          setState(() {
            _showMatrbhoomiPrompt = true;
            _matrbhoomiStep = 1;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadDetail() async {
    await widget.placeService.fetchPlaceDetail(widget.placeId);
    await _communityService.fetchCommunityData(widget.placeId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: widget.placeService,
      builder: (context, _) {
        final currentPlace = widget.placeService.selectedPlace ?? widget.initialPlace;
        final children = widget.placeService.children;

        return Scaffold(
          appBar: AppBar(
            leading: widget.onBackToHome != null
                ? IconButton(
                    key: const Key('return_to_home_button'),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back to Location',
                    onPressed: widget.onBackToHome,
                  )
                : null,
            title: Text(widget.onBackToHome != null
                ? 'Explore Stories'
                : (currentPlace?.canonicalName ?? l10n.placesTitle)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: l10n.retryButton,
                onPressed: _loadDetail,
              ),
            ],
          ),
          body: SafeArea(
            child: widget.placeService.isLoading && currentPlace == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(l10n.loadingLabel),
                      ],
                    ),
                  )
                : widget.placeService.errorMessage != null && currentPlace == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 48, color: theme.colorScheme.error),
                              const SizedBox(height: 12),
                              Text(
                                widget.placeService.errorMessage!,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _loadDetail,
                                icon: const Icon(Icons.refresh),
                                label: Text(l10n.retryButton),
                              ),
                            ],
                          ),
                        ),
                      )
                    : currentPlace == null
                        ? Center(child: Text(l10n.errorNotFound))
                        : SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Place overview banner (Suppressed in Explore Stories embedded mode to prevent duplicate place card)
                                if (widget.onBackToHome == null) ...[
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 16),
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primary,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                currentPlace.level,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme.onPrimary,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              'ID: ${currentPlace.id}',
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: theme.colorScheme.outline,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          currentPlace.canonicalName,
                                          style: theme.textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        FilledButton.icon(
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => ProgressiveContributionPage(
                                                  placeId: currentPlace.id,
                                                  placeName: currentPlace.canonicalName,
                                                  communityService: _communityService,
                                                ),
                                              ),
                                            ).then((_) => _loadDetail());
                                          },
                                          icon: const Icon(Icons.add_comment),
                                          label: const Text('Contribute Local Knowledge'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Matrbhoomi History Banner (Requirement 1 & 2 & 3)
                                _buildMatrbhoomiBanner(context, currentPlace, l10n, theme),
                                const SizedBox(height: 16),

                                 // Hierarchy Path Section
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    l10n.placeHierarchy,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.symmetric(horizontal: 16),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: (currentPlace.parentPath != null &&
                                          currentPlace.parentPath!.isNotEmpty)
                                      ? Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            ...currentPlace.parentPath!.map((item) {
                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  ActionChip(
                                                    label: Text(
                                                      '${item.canonicalName} (${item.level})',
                                                      style: const TextStyle(fontSize: 11),
                                                    ),
                                                    onPressed: () {
                                                      Navigator.of(context).push(
                                                        MaterialPageRoute(
                                                          builder: (_) => PlaceDetailPage(
                                                            placeId: item.id,
                                                            placeService: widget.placeService,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(Icons.chevron_right,
                                                      size: 16, color: theme.colorScheme.outline),
                                                ],
                                              );
                                            }),
                                            Chip(
                                              label: Text(
                                                '${currentPlace.canonicalName} (${currentPlace.level})',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme.primary,
                                                ),
                                              ),
                                              backgroundColor:
                                                  theme.colorScheme.primary.withValues(alpha: 0.1),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Icon(Icons.account_tree_outlined,
                                                size: 16, color: theme.colorScheme.outline),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                currentPlace.level == 'COUNTRY'
                                                    ? 'Top-level Country node (No parent administrative boundary)'
                                                    : 'Root entity — No higher administrative hierarchy recorded.',
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: theme.colorScheme.outline,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                                const SizedBox(height: 16),

                                // Localized Names Section
                                if (widget.onBackToHome == null) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    l10n.localizedNamesLabel,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (currentPlace.names.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'No localized name variations registered for this place.',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: currentPlace.names.map((nameItem) {
                                        return Chip(
                                          avatar: CircleAvatar(
                                            child: Text(
                                              nameItem.language.toUpperCase(),
                                              style: const TextStyle(fontSize: 9),
                                            ),
                                          ),
                                          label: Text(nameItem.name),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                ],

                                // Sub-Places (Children) Section
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: [
                                      Text(
                                        l10n.childrenPlaces,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${children.length}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSecondaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (children.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Center(
                                      child: Text(
                                        l10n.noChildrenPlaces,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.outline,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  ...children.map((childPlace) {
                                    return PlaceCard(
                                      place: childPlace,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => PlaceDetailPage(
                                              placeId: childPlace.id,
                                              initialPlace: childPlace,
                                              placeService: widget.placeService,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }),
                                const SizedBox(height: 24),

                                // Place Attributes & Verified Facilities Section (Rule 5)
                                AnimatedBuilder(
                                  animation: _communityService,
                                  builder: (context, _) {
                                    final attrs = _communityService.attributes;
                                    if (attrs.isEmpty) return const SizedBox.shrink();

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Verified Local Records & Facilities',
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...attrs.map((attr) {
                                            final isEstimate = attr.uncertainty != null && attr.uncertainty!.isNotEmpty;
                                            return Card(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              elevation: 1,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                                                            attr.category.toUpperCase(),
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
                                                            attr.key,
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
                                                              'Estimate (${attr.uncertainty})',
                                                              style: const TextStyle(fontSize: 10, color: Colors.deepOrange),
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
                                                              style: TextStyle(fontSize: 10, color: Colors.green),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(attr.value, style: theme.textTheme.bodyMedium),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      children: [
                                                        Icon(Icons.source, size: 12, color: theme.colorScheme.outline),
                                                        const SizedBox(width: 4),
                                                        Expanded(
                                                          child: Text(
                                                            'Source: ${attr.sourceDescription}${attr.reportedPeriod != null ? " • Period: ${attr.reportedPeriod}" : ""}',
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
                                          }),
                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                                // Community Knowledge & Heritage Section Header
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Community Knowledge & Heritage',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => ProgressiveContributionPage(
                                                placeId: currentPlace.id,
                                                placeName: currentPlace.canonicalName,
                                                communityService: _communityService,
                                              ),
                                            ),
                                          ).then((_) => _loadDetail());
                                        },
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('Add Story'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Explicitly Separated Knowledge Categories by Data/Status Semantics
                                AnimatedBuilder(
                                  animation: _communityService,
                                  builder: (context, _) {
                                    final allClaims = _communityService.claims;
                                    if (allClaims.isEmpty) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: Card(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          child: Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Center(
                                              child: Column(
                                                children: [
                                                  Icon(Icons.history_edu, size: 36, color: theme.colorScheme.outline),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    _highlightApprovedHistory
                                                        ? l10n.matrbhoomiNoApprovedHistory
                                                        : 'No community stories yet. Be the first to share your local memories and heritage!',
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    // Category 1: Verified History & Facts (Requires verified status AND allowed category)
                                    final verifiedFacts = allClaims
                                        .where((c) =>
                                            c.isVerified &&
                                            (c.category == 'HISTORICAL_RECORD' ||
                                                c.category == 'CURRENT_FACT'))
                                        .toList();

                                    // Category 2: Folklore & Oral Traditions (Must include prominent disclaimer)
                                    final folkloreClaims = allClaims
                                        .where((c) => c.isFolklore)
                                        .toList();

                                    // Category 3: Community & Public Opinions (Subjective viewpoints)
                                    final opinionClaims = allClaims
                                        .where((c) =>
                                            c.category == 'PUBLIC_OPINION' ||
                                            c.category == 'PERSONAL_EXPERIENCE' ||
                                            c.category == 'SURVEY_DATA')
                                        .toList();

                                    // Category 4: Pending / Under Review / Disputed submissions
                                    final otherClaims = allClaims
                                        .where((c) =>
                                            !verifiedFacts.contains(c) &&
                                            !folkloreClaims.contains(c) &&
                                            !opinionClaims.contains(c))
                                        .toList();

                                    if (_highlightApprovedHistory) {
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildKnowledgeSection(
                                            context: context,
                                            title: l10n.verifiedFactsSection,
                                            icon: Icons.verified_outlined,
                                            iconColor: Colors.green,
                                            count: verifiedFacts.length,
                                            claims: verifiedFacts,
                                            emptyMessage: l10n.matrbhoomiNoApprovedHistory,
                                            placeName: currentPlace.canonicalName,
                                            isHistorySection: true,
                                          ),
                                        ],
                                      );
                                    }

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // 1. Verified History & Facts
                                        _buildKnowledgeSection(
                                          context: context,
                                          title: l10n.verifiedFactsSection,
                                          icon: Icons.verified_outlined,
                                          iconColor: Colors.green,
                                          count: verifiedFacts.length,
                                          claims: verifiedFacts,
                                          emptyMessage: _highlightApprovedHistory
                                              ? l10n.matrbhoomiNoApprovedHistory
                                              : l10n.noVerifiedClaims,
                                          placeName: currentPlace.canonicalName,
                                          isHistorySection: true,
                                        ),

                                        // 2. Folklore & Oral Traditions with prominent folklore notice
                                        _buildKnowledgeSection(
                                          context: context,
                                          title: l10n.folkloreSection,
                                          icon: Icons.auto_stories,
                                          iconColor: Colors.purple,
                                          count: folkloreClaims.length,
                                          claims: folkloreClaims,
                                          noticeBanner: _buildNoticeBanner(
                                            context,
                                            icon: Icons.info_outline,
                                            color: Colors.purple,
                                            message: l10n.folkloreNoticeBanner,
                                          ),
                                          emptyMessage: l10n.noFolkloreClaims,
                                          placeName: currentPlace.canonicalName,
                                        ),

                                        // 3. Public & Community Opinions with opinion notice
                                        _buildKnowledgeSection(
                                          context: context,
                                          title: l10n.opinionsSection,
                                          icon: Icons.groups_outlined,
                                          iconColor: Colors.orange,
                                          count: opinionClaims.length,
                                          claims: opinionClaims,
                                          noticeBanner: _buildNoticeBanner(
                                            context,
                                            icon: Icons.rate_review_outlined,
                                            color: Colors.orange,
                                            message: l10n.publicOpinionNoticeBanner,
                                          ),
                                          emptyMessage: l10n.noOpinionClaims,
                                          placeName: currentPlace.canonicalName,
                                        ),

                                        // 4. Under Review / Disputed / Other Submissions
                                        if (otherClaims.isNotEmpty)
                                          _buildKnowledgeSection(
                                            context: context,
                                            title: l10n.otherClaimsSection,
                                            icon: Icons.pending_actions_outlined,
                                            iconColor: Colors.blueGrey,
                                            count: otherClaims.length,
                                            claims: otherClaims,
                                            emptyMessage: l10n.noOtherClaims,
                                            placeName: currentPlace.canonicalName,
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
          ),
        );
      },
    );
  }

  Widget _buildNoticeBanner(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String message,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKnowledgeSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required int count,
    required List<Claim> claims,
    required String emptyMessage,
    required String placeName,
    Widget? noticeBanner,
    bool isHistorySection = false,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (noticeBanner != null) noticeBanner,
        if (claims.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: theme.colorScheme.outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        emptyMessage,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...claims.map((claim) {
            if (isHistorySection) {
              return MatrbhoomiCard(
                claim: claim,
                communityService: _communityService,
                currentUserId: widget.authService?.currentUser?.id,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ClaimDetailPage(
                        claim: claim,
                        communityService: _communityService,
                        placeName: placeName,
                        authService: widget.authService,
                      ),
                    ),
                  ).then((_) => _loadDetail());
                },
                onFeedbackSubmitted: _loadDetail,
              );
            }
            return ClaimCard(
              claim: claim,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ClaimDetailPage(
                      claim: claim,
                      communityService: _communityService,
                      placeName: placeName,
                      authService: widget.authService,
                    ),
                  ),
                ).then((_) => _loadDetail());
              },
            );
          }),
      ],
    );
  }

  Widget _buildMatrbhoomiBanner(
    BuildContext context,
    Place currentPlace,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    if (!_showMatrbhoomiPrompt) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8B5E3C).withValues(alpha: 0.12),
            theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5E3C).withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5E3C).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history_edu,
                  size: 20,
                  color: Color(0xFF8B5E3C),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.matrbhoomiTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF8B5E3C),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: l10n.cancelButton,
                onPressed: () {
                  setState(() => _showMatrbhoomiPrompt = false);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Step 1: Question 1
          if (_matrbhoomiStep == 1) ...[
            Text(
              l10n.matrbhoomiQuestion1,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      setState(() {
                        _matrbhoomiStep = 3;
                      });
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        final user = widget.authService?.currentUser;
                        final key = user != null
                            ? 'matrbhoomi_prompt_${user.id}_${widget.placeId}'
                            : 'matrbhoomi_prompt_${widget.placeId}';
                        await prefs.setBool(key, true);
                        await widget.authService?.updateMatrbhoomiInterest(
                          placeId: widget.placeId,
                          knowsHistory: true,
                        );
                      } catch (_) {}
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(l10n.matrbhoomiChoiceYes),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5E3C),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _matrbhoomiStep = 2;
                      });
                    },
                    child: Text(l10n.matrbhoomiChoiceNo),
                  ),
                ),
              ],
            ),
          ],

          // Step 2: Question 2 (Prompted after User says NO)
          if (_matrbhoomiStep == 2) ...[
            Text(
              l10n.matrbhoomiQuestion2,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      setState(() {
                        _showMatrbhoomiPrompt = false;
                        _highlightApprovedHistory = true;
                      });
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        final user = widget.authService?.currentUser;
                        final key = user != null
                            ? 'matrbhoomi_prompt_${user.id}_${widget.placeId}'
                            : 'matrbhoomi_prompt_${widget.placeId}';
                        await prefs.setBool(key, true);
                        await widget.authService?.updateMatrbhoomiInterest(
                          placeId: widget.placeId,
                          knowsHistory: false,
                          wantsToLearn: true,
                        );
                      } catch (_) {}
                    },
                    icon: const Icon(Icons.menu_book, size: 16),
                    label: Text(l10n.matrbhoomiChoiceLearnYes),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5E3C),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      setState(() {
                        _showMatrbhoomiPrompt = false;
                      });
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        final user = widget.authService?.currentUser;
                        final key = user != null
                            ? 'matrbhoomi_prompt_${user.id}_${widget.placeId}'
                            : 'matrbhoomi_prompt_${widget.placeId}';
                        await prefs.setBool(key, true);
                        await widget.authService?.updateMatrbhoomiInterest(
                          placeId: widget.placeId,
                          knowsHistory: false,
                          wantsToLearn: false,
                        );
                      } catch (_) {}
                    },
                    child: Text(l10n.matrbhoomiChoiceLearnNo),
                  ),
                ),
              ],
            ),
          ],

          // Step 3: Opportunity to Contribute (Prompted after User says YES)
          if (_matrbhoomiStep == 3) ...[
            Text(
              l10n.matrbhoomiContributePrompt,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProgressiveContributionPage(
                          placeId: currentPlace.id,
                          placeName: currentPlace.canonicalName,
                          communityService: _communityService,
                          initialTopic: 'history',
                        ),
                      ),
                    ).then((_) {
                      _loadDetail();
                      setState(() => _showMatrbhoomiPrompt = false);
                    });
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l10n.matrbhoomiContributeButton),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5E3C),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => setState(() => _showMatrbhoomiPrompt = false),
                  child: Text(l10n.cancelButton),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
