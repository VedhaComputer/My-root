import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../models/claim.dart';
import '../../../services/auth_service.dart';
import '../../../services/community_service.dart';
import '../../../services/place_service.dart';
import '../../card/claim_card.dart';
import '../places/progressive_contribution_page.dart';
import 'claim_detail_page.dart';

class CategoryClaimsPage extends StatefulWidget {
  final String placeId;
  final String? placeName;
  final String category;
  final CommunityService communityService;
  final PlaceService? placeService;
  final AuthService? authService;
  final VoidCallback? onBackToHome;

  const CategoryClaimsPage({
    super.key,
    required this.placeId,
    this.placeName,
    required this.category,
    required this.communityService,
    this.placeService,
    this.authService,
    this.onBackToHome,
  });

  @override
  State<CategoryClaimsPage> createState() => _CategoryClaimsPageState();
}

class _CategoryClaimsPageState extends State<CategoryClaimsPage> {
  List<Claim> _claims = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadClaims();
  }

  @override
  void didUpdateWidget(CategoryClaimsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category || oldWidget.placeId != widget.placeId) {
      _loadClaims();
    }
  }

  Future<void> _loadClaims() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final claims = await widget.communityService.fetchClaimsForCategory(
        placeId: widget.placeId,
        category: widget.category,
      );
      if (mounted) {
        setState(() {
          _claims = claims;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _getCategoryTitle(AppLocalizations l10n) {
    switch (widget.category) {
      case ClaimCategory.historicalRecord:
        return l10n.categoryHistoricalRecord;
      case ClaimCategory.currentFact:
        return l10n.categoryCurrentFact;
      case ClaimCategory.folklore:
        return l10n.categoryFolklore;
      case ClaimCategory.personalExperience:
        return l10n.categoryPersonalExperience;
      case ClaimCategory.publicOpinion:
        return l10n.categoryPublicOpinion;
      case ClaimCategory.surveyData:
        return l10n.categorySurveyData;
      default:
        return widget.category;
    }
  }

  IconData _getCategoryIcon() {
    switch (widget.category) {
      case ClaimCategory.historicalRecord:
        return Icons.history_edu;
      case ClaimCategory.currentFact:
        return Icons.fact_check;
      case ClaimCategory.folklore:
        return Icons.auto_stories;
      case ClaimCategory.personalExperience:
        return Icons.person;
      case ClaimCategory.publicOpinion:
        return Icons.groups;
      case ClaimCategory.surveyData:
        return Icons.bar_chart;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor() {
    switch (widget.category) {
      case ClaimCategory.historicalRecord:
        return Colors.brown;
      case ClaimCategory.currentFact:
        return Colors.blue;
      case ClaimCategory.folklore:
        return Colors.purple;
      case ClaimCategory.personalExperience:
        return Colors.teal;
      case ClaimCategory.publicOpinion:
        return Colors.orange;
      case ClaimCategory.surveyData:
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  String _getCategoryTopic() {
    switch (widget.category) {
      case ClaimCategory.historicalRecord:
        return 'history';
      case ClaimCategory.folklore:
        return 'culture';
      case ClaimCategory.personalExperience:
        return 'biography';
      case ClaimCategory.publicOpinion:
        return 'opinion';
      case ClaimCategory.currentFact:
      case ClaimCategory.surveyData:
      default:
        return 'facilities';
    }
  }

  Widget _buildNoticeBanner(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final color = _getCategoryColor();
    final icon = _getCategoryIcon();

    String noticeText;
    switch (widget.category) {
      case ClaimCategory.folklore:
        noticeText = l10n.folkloreNoticeBanner;
        break;
      case ClaimCategory.publicOpinion:
        noticeText = l10n.publicOpinionNoticeBanner;
        break;
      case ClaimCategory.historicalRecord:
        noticeText = widget.onBackToHome != null
            ? 'Historical Records & Documented Heritage for this location.'
            : 'Historical Records & Documented Heritage for ${widget.placeName ?? "this location"}.';
        break;
      case ClaimCategory.currentFact:
        noticeText = widget.onBackToHome != null
            ? 'Current factual data and verified local records for this location.'
            : 'Current factual data and verified local records for ${widget.placeName ?? "this location"}.';
        break;
      case ClaimCategory.personalExperience:
        noticeText = 'Personal experiences, memoirs, and lived accounts shared by local contributors.';
        break;
      case ClaimCategory.surveyData:
        noticeText = 'Survey findings, public polls, and structured statistical observations.';
        break;
      default:
        noticeText = 'Community contributions under ${widget.category}.';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              noticeText,
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

  void _openContribution() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProgressiveContributionPage(
          placeId: widget.placeId,
          placeName: widget.placeName ?? 'Local Area',
          communityService: widget.communityService,
          initialTopic: _getCategoryTopic(),
        ),
      ),
    ).then((_) => _loadClaims());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final categoryTitle = _getCategoryTitle(l10n);

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
        title: Text(
          widget.onBackToHome != null
              ? categoryTitle
              : (widget.placeName != null && widget.placeName!.isNotEmpty
                  ? '$categoryTitle • ${widget.placeName}'
                  : categoryTitle),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.retryButton,
            onPressed: _loadClaims,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null && _claims.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _loadClaims,
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.retryButton),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 80),
                    children: [
                      _buildNoticeBanner(context, l10n),
                      if (_claims.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_getCategoryIcon(), size: 48, color: theme.colorScheme.outline),
                                const SizedBox(height: 12),
                                Text(
                                  'No $categoryTitle records for this location yet.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Be the first to share and preserve knowledge in this category.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: _openContribution,
                                  icon: const Icon(Icons.add),
                                  label: Text('Contribute $categoryTitle'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._claims.map(
                          (claim) => ClaimCard(
                            claim: claim,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ClaimDetailPage(
                                    claim: claim,
                                    communityService: widget.communityService,
                                  ),
                                ),
                              ).then((_) => _loadClaims());
                            },
                          ),
                        ),
                    ],
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openContribution,
        icon: const Icon(Icons.add),
        label: Text('Add $categoryTitle'),
        tooltip: 'Add $categoryTitle',
      ),
    );
  }
}
