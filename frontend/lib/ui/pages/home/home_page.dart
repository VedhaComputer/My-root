import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../models/place.dart';
import '../../../models/place_progress.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/community_repository.dart';
import '../../../repositories/place_repository.dart';
import '../../../services/auth_service.dart';
import '../../../services/community_service.dart';
import '../../../services/place_service.dart';
import '../../card/claim_card.dart';
import '../../widgets/app_header.dart';
import '../../widgets/home_features_drawer.dart';
import '../../widgets/latest_users_drawer.dart';
import '../../widgets/location_search_dialog.dart';
import '../../widgets/session_persistence_warning_banner.dart';
import '../auth/login_page.dart';
import '../claims/claim_detail_page.dart';
import '../claims/category_claims_page.dart';
import '../places/place_detail_page.dart';
import '../places/progressive_contribution_page.dart';

enum HomeActiveView {
  locationHome,
  exploreStories,
  contribute,
  categoryClaims,
  add,
}

class HomePage extends StatefulWidget {
  final ApiClient? apiClient;
  final AuthService? authService;
  final PlaceService? placeService;

  const HomePage({
    super.key,
    this.apiClient,
    this.authService,
    this.placeService,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ApiClient _apiClient;
  late final AuthService _authService;
  late final PlaceService _placeService;
  late final CommunityService _communityService;

  HomeActiveView _activeView = HomeActiveView.locationHome;
  String? _activeCategory;
  Place? _currentSelectedPlace;
  bool _lastAuthStatus = false;
  String? _lastAuthUserId;

  @override
  void initState() {
    super.initState();
    if (widget.apiClient != null) {
      _apiClient = widget.apiClient!;
    } else if (widget.authService != null && widget.authService!.repository is AuthRepositoryImpl) {
      _apiClient = (widget.authService!.repository as AuthRepositoryImpl).client;
    } else if (widget.placeService != null && widget.placeService!.repository is PlaceRepositoryImpl) {
      _apiClient = (widget.placeService!.repository as PlaceRepositoryImpl).client;
    } else {
      _apiClient = ApiClient();
    }

    _authService = widget.authService ??
        AuthService(repository: AuthRepositoryImpl(client: _apiClient));
    _placeService = widget.placeService ??
        PlaceService(repository: PlaceRepositoryImpl(client: _apiClient));
    _communityService = CommunityService(
      repository: CommunityRepositoryImpl(client: _apiClient),
    );

    _lastAuthStatus = _authService.isAuthenticated;
    _lastAuthUserId = _authService.currentUser?.id;
    _authService.addListener(_onAuthChanged);
    _authService.restoreSession().then((_) {
      if (mounted) {
        _lastAuthStatus = _authService.isAuthenticated;
        _lastAuthUserId = _authService.currentUser?.id;
        _loadLocationData();
      }
    });
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final currentStatus = _authService.isAuthenticated;
    final currentUserId = _authService.currentUser?.id;
    if (currentStatus != _lastAuthStatus || currentUserId != _lastAuthUserId) {
      _lastAuthStatus = currentStatus;
      _lastAuthUserId = currentUserId;
      _returnToLocationHome();
      _loadLocationData();
    } else {
      setState(() {});
    }
  }

  Future<void> _loadLocationData() async {
    if (!_authService.isAuthenticated) {
      _currentSelectedPlace = null;
      if (mounted) setState(() {});
      return;
    }

    final placeId = await _resolveSelectedPlaceId();
    if (placeId != null && placeId.isNotEmpty) {
      Place? place = _placeService.selectedPlace;
      if (place == null || place.id != placeId) {
        place = await _placeService.resolveSelectedPlace(placeId);
      }
      _currentSelectedPlace = place;
      await _communityService.fetchCommunityData(placeId);
    } else {
      _currentSelectedPlace = null;
      await _communityService.fetchRecentClaims(limit: 10);
    }
    if (mounted) setState(() {});
  }

  Future<String?> _resolveSelectedPlaceId() async {
    final user = _authService.currentUser;
    if (user?.selectedPlaceId != null && user!.selectedPlaceId!.isNotEmpty) {
      return user.selectedPlaceId;
    }
    if (user?.verifiedLocationId != null && user!.verifiedLocationId!.isNotEmpty) {
      return user.verifiedLocationId;
    }
    if (_placeService.selectedPlace?.id != null && _placeService.selectedPlace!.id.isNotEmpty) {
      return _placeService.selectedPlace!.id;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (user != null) {
        final userPref = prefs.getString('selected_place_id_${user.id}');
        if (userPref != null && userPref.isNotEmpty) return userPref;
      }
      final globalPref = prefs.getString('selected_place_id');
      if (globalPref != null && globalPref.isNotEmpty) return globalPref;
    } catch (_) {}
    return null;
  }

  Future<({String id, String name})?> _ensureSelectedPlace() async {
    final existingId = await _resolveSelectedPlaceId();
    if (existingId != null && existingId.isNotEmpty) {
      final place = _placeService.selectedPlace ?? _currentSelectedPlace;
      final name = place?.canonicalName ?? 'Local Area';
      return (id: existingId, name: name);
    }

    if (!mounted) return null;
    final picked = await showDialog<Place>(
      context: context,
      builder: (_) => LocationSearchDialog(
        placeService: _placeService,
        currentPlaceId: _currentSelectedPlace?.id,
        currentPlaceName: _currentSelectedPlace?.canonicalName,
      ),
    );
    if (!mounted || picked == null) return null;

    _placeService.setSelectedPlace(picked);
    _currentSelectedPlace = picked;

    if (_authService.currentUser != null) {
      try {
        await _authService.updateSelectedPlace(picked.id);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'selected_place_id_${_authService.currentUser!.id}',
          picked.id,
        );
      } catch (_) {}
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_place_id', picked.id);
      } catch (_) {}
    }

    await _loadLocationData();
    return (id: picked.id, name: picked.canonicalName);
  }

  Future<void> _selectFunction(HomeActiveView view, {String? category}) async {
    final place = await _ensureSelectedPlace();
    if (!mounted || place == null) return;

    setState(() {
      _activeView = view;
      _activeCategory = category;
    });
  }

  void _returnToLocationHome() {
    if (mounted && (_activeView != HomeActiveView.locationHome || _activeCategory != null)) {
      setState(() {
        _activeView = HomeActiveView.locationHome;
        _activeCategory = null;
      });
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (!_authService.isInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.nature_people, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                l10n.appTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.tagline,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    final place = _placeService.selectedPlace ?? _currentSelectedPlace;
    final hasSelectedLocation = _authService.isAuthenticated && place != null;

    return PopScope(
      canPop: _activeView == HomeActiveView.locationHome,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _activeView != HomeActiveView.locationHome) {
          _returnToLocationHome();
        }
      },
      child: Scaffold(
        appBar: GlobalAppBar(
          authService: _authService,
          placeService: _placeService,
          communityService: _communityService,
          onPlaceChanged: () {
            _returnToLocationHome();
            _loadLocationData();
          },
          onAuthChanged: () {
            _returnToLocationHome();
            _loadLocationData();
          },
        ),
        drawer: HomeFeaturesDrawer(
          user: _authService.currentUser,
          selectedPlaceName: place?.canonicalName,
          onExploreStories: () => _selectFunction(HomeActiveView.exploreStories),
          onContribute: () => _selectFunction(HomeActiveView.contribute),
          onCategory: (cat) => _selectFunction(HomeActiveView.categoryClaims, category: cat),
          onAdd: () => _selectFunction(HomeActiveView.add),
        ),
        endDrawer: LatestUsersDrawer(
          authService: _authService,
          placeService: _placeService,
        ),
        body: SafeArea(
          child: Column(
            children: [
              SessionPersistenceWarningBanner(authService: _authService),
              Expanded(
                child: _buildCentralContent(context, l10n, theme, place, hasSelectedLocation),
              ),
            ],
          ),
        ),
        floatingActionButton: (_activeView == HomeActiveView.locationHome)
            ? FloatingActionButton.extended(
                heroTag: 'home_fab_add',
                onPressed: () => _selectFunction(HomeActiveView.add),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                tooltip: 'Add',
              )
            : null,
      ),
    );
  }

  Widget _buildCentralContent(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    Place? place,
    bool hasSelectedLocation,
  ) {
    switch (_activeView) {
      case HomeActiveView.exploreStories:
        return PlaceDetailPage(
          key: const Key('embedded_place_detail'),
          placeId: place!.id,
          initialPlace: place,
          placeService: _placeService,
          communityService: _communityService,
          authService: _authService,
          onBackToHome: _returnToLocationHome,
        );

      case HomeActiveView.contribute:
        return ProgressiveContributionPage(
          key: const Key('embedded_progressive_contribution'),
          placeId: place!.id,
          placeName: place.canonicalName,
          communityService: _communityService,
          onBackToHome: _returnToLocationHome,
        );

      case HomeActiveView.categoryClaims:
        return CategoryClaimsPage(
          key: const Key('embedded_category_claims'),
          placeId: place!.id,
          placeName: place.canonicalName,
          category: _activeCategory ?? ClaimCategory.historicalRecord,
          communityService: _communityService,
          placeService: _placeService,
          authService: _authService,
          onBackToHome: _returnToLocationHome,
        );

      case HomeActiveView.add:
        return ProgressiveContributionPage(
          key: const Key('embedded_add_contribution'),
          placeId: place!.id,
          placeName: place.canonicalName,
          communityService: _communityService,
          onBackToHome: _returnToLocationHome,
        );

      case HomeActiveView.locationHome:
        if (hasSelectedLocation) {
          return _buildLocationHomeContent(context, place!, l10n, theme);
        } else {
          return _buildUnauthenticatedOrNoPlaceHome(context, l10n, theme);
        }
    }
  }

  Widget _buildLocationHomeContent(
    BuildContext context,
    Place place,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return AnimatedBuilder(
      animation: Listenable.merge([_communityService, _placeService]),
      builder: (context, _) {
        final attributes = _communityService.attributes;
        final claims = _communityService.claims;
        final isLoading = _communityService.isLoading;
        final error = _communityService.errorMessage;

        return RefreshIndicator(
          onRefresh: () async {
            await _loadLocationData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Loading Indicator
                if (isLoading && claims.isEmpty && attributes.isEmpty) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ],

                // 4. Error state
                if (error != null && claims.isEmpty && attributes.isEmpty) ...[
                  Card(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 36),
                          const SizedBox(height: 8),
                          Text(error, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error)),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: () => _loadLocationData(),
                            child: Text(l10n.retryButton),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 5. Verified Attributes Section
                if (attributes.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.fact_check, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Verified Local Facts & Details',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...attributes.map((attr) => _buildAttributeCard(attr, theme)),
                  const SizedBox(height: 20),
                ],

                // 6. Local Stories & Community Records Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Local Stories & Records',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (claims.isNotEmpty)
                      Text(
                        '${claims.length} records',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (claims.isNotEmpty) ...[
                  ...claims.map(
                    (claim) => ClaimCard(
                      claim: claim,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ClaimDetailPage(
                              claim: claim,
                              communityService: _communityService,
                              authService: _authService,
                            ),
                          ),
                        ).then((_) => _loadLocationData());
                      },
                    ),
                  ),
                ],

                // 7. Clean Empty State (when no attributes and no claims)
                if (claims.isEmpty && attributes.isEmpty && !isLoading) ...[
                  Card(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.history_edu, size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.7)),
                          const SizedBox(height: 12),
                          Text(
                            'No community records yet',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Be the first to preserve and share local history, folklore, verified facts, and community knowledge.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _selectFunction(HomeActiveView.contribute),
                            icon: const Icon(Icons.add),
                            label: const Text('Contribute Knowledge'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // 8. Trust Notice Card
                Card(
                  color: theme.colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.verified_user, color: theme.colorScheme.onSecondaryContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.folkloreNote,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttributeCard(PlaceAttribute attr, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle,
              size: 20,
              color: Colors.green,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _formatAttributeKey(attr.key),
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          attr.category.toUpperCase(),
                          style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(attr.value, style: theme.textTheme.bodyMedium),
                  if (attr.sourceDescription.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Source: ${attr.sourceDescription}',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAttributeKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  Widget _buildUnauthenticatedOrNoPlaceHome(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.welcomeTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.welcomeSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _selectFunction(HomeActiveView.exploreStories),
                      icon: const Icon(Icons.explore),
                      label: Text(l10n.exploreButtonLabel),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _selectFunction(HomeActiveView.contribute),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.contributeButtonLabel),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onPrimary,
                        side: BorderSide(color: theme.colorScheme.onPrimary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Categories section
          Text(
            'Browse by Category',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _CategoryCard(
                icon: Icons.history_edu,
                label: l10n.categoryHistoricalRecord,
                color: Colors.brown,
                onTap: () => _selectFunction(HomeActiveView.categoryClaims, category: ClaimCategory.historicalRecord),
              ),
              _CategoryCard(
                icon: Icons.fact_check,
                label: l10n.categoryCurrentFact,
                color: Colors.blue,
                onTap: () => _selectFunction(HomeActiveView.categoryClaims, category: ClaimCategory.currentFact),
              ),
              _CategoryCard(
                icon: Icons.auto_stories,
                label: l10n.categoryFolklore,
                color: Colors.purple,
                onTap: () => _selectFunction(HomeActiveView.categoryClaims, category: ClaimCategory.folklore),
              ),
              _CategoryCard(
                icon: Icons.person,
                label: l10n.categoryPersonalExperience,
                color: Colors.teal,
                onTap: () => _selectFunction(HomeActiveView.categoryClaims, category: ClaimCategory.personalExperience),
              ),
              _CategoryCard(
                icon: Icons.groups,
                label: l10n.categoryPublicOpinion,
                color: Colors.orange,
                onTap: () => _selectFunction(HomeActiveView.categoryClaims, category: ClaimCategory.publicOpinion),
              ),
              _CategoryCard(
                icon: Icons.bar_chart,
                label: l10n.categorySurveyData,
                color: Colors.indigo,
                onTap: () => _selectFunction(HomeActiveView.categoryClaims, category: ClaimCategory.surveyData),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Village Knowledge & Recent Stories section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Village Knowledge & Recent Stories',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (_communityService.isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _communityService,
            builder: (context, _) {
              if (!_authService.isAuthenticated) {
                return Card(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.lock_outline, size: 40, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to explore village knowledge',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Connect with your community to view verified records, folklore, and local stories.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => LoginPage(authService: _authService),
                              ),
                            ).then((_) => _loadLocationData());
                          },
                          child: const Text('Sign In'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (_communityService.isLoading && _communityService.recentClaims.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (_communityService.recentClaims.isEmpty) {
                return Card(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.history_edu, size: 40, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                        const SizedBox(height: 8),
                        Text(
                          'No public village stories yet',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Be the first to preserve and share local history and community knowledge.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _communityService.recentClaims.length,
                itemBuilder: (context, index) {
                  final claim = _communityService.recentClaims[index];
                  return ClaimCard(
                    claim: claim,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ClaimDetailPage(
                            claim: claim,
                            communityService: _communityService,
                            authService: _authService,
                          ),
                        ),
                      ).then((_) => _loadLocationData());
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 32),

          // Trust notice
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.verified_user, color: theme.colorScheme.onSecondaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.folkloreNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _CategoryCard({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
