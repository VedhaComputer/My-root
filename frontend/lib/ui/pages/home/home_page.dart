import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../models/claim.dart';
import '../../../models/place.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/community_repository.dart';
import '../../../repositories/place_repository.dart';
import '../../../services/auth_service.dart';
import '../../../services/community_service.dart';
import '../../../services/place_service.dart';
import '../../card/claim_card.dart';
import '../../card/place_status_card.dart';
import '../../widgets/app_header.dart';
import '../../widgets/home_features_drawer.dart';
import '../../widgets/latest_users_drawer.dart';
import '../../widgets/session_persistence_warning_banner.dart';
import '../auth/login_page.dart';
import '../claims/claim_detail_page.dart';
import '../claims/category_claims_page.dart';
import '../places/place_detail_page.dart';
import '../places/progressive_contribution_page.dart';
import '../places/section_data_contribution_page.dart';
import '../profile/profile_page.dart';

enum HomeActiveView {
  locationHome,
  exploreStories,
  contribute,
  categoryClaims,
  add,
  profile,
  sectionContribution,
}

class HomePage extends StatefulWidget {
  final ApiClient? apiClient;
  final AuthService? authService;
  final PlaceService? placeService;
  final CommunityService? communityService;
  final HomeActiveView? initialActiveView;
  final String? initialCategory;
  final SectionContributionType? initialSectionType;

  const HomePage({
    super.key,
    this.apiClient,
    this.authService,
    this.placeService,
    this.communityService,
    this.initialActiveView,
    this.initialCategory,
    this.initialSectionType,
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
  SectionContributionType? _activeSectionType;
  Place? _currentSelectedPlace;
  bool _isLoadingLocation = false;
  bool _lastAuthStatus = false;
  String? _lastAuthUserId;

  @override
  void initState() {
    super.initState();
    _activeView = widget.initialActiveView ?? HomeActiveView.locationHome;
    _activeCategory = widget.initialCategory;
    _activeSectionType = widget.initialSectionType;
    _isLoadingLocation = true;
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
    _communityService = widget.communityService ??
        CommunityService(
          repository: CommunityRepositoryImpl(client: _apiClient),
        );

    _lastAuthStatus = _authService.isAuthenticated;
    _lastAuthUserId = _authService.currentUser?.id;
    _authService.addListener(_onAuthChanged);
    _communityService.addListener(_onCommunityChanged);
    _authService.restoreSession().then((_) {
      if (mounted) {
        _lastAuthStatus = _authService.isAuthenticated;
        _lastAuthUserId = _authService.currentUser?.id;
        _loadLocationData();
      }
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
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
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
      return;
    }

    if (mounted && !_isLoadingLocation) {
      setState(() {
        _isLoadingLocation = true;
      });
    }

    try {
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
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

  void _selectFunction(HomeActiveView view, {String? category, SectionContributionType? sectionType}) {
    if (!mounted) return;
    setState(() {
      _activeView = view;
      _activeCategory = category;
      _activeSectionType = sectionType;
    });
  }

  void _returnToLocationHome() {
    if (mounted && (_activeView != HomeActiveView.locationHome || _activeCategory != null || _activeSectionType != null)) {
      setState(() {
        _activeView = HomeActiveView.locationHome;
        _activeCategory = null;
        _activeSectionType = null;
      });
    }
  }

  void _onCommunityChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    _communityService.removeListener(_onCommunityChanged);
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
          onProfileTap: () => _selectFunction(HomeActiveView.profile),
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
          currentRoute: switch (_activeView) {
            HomeActiveView.locationHome => 'home',
            HomeActiveView.exploreStories => 'explore_stories',
            HomeActiveView.contribute => 'contribute',
            HomeActiveView.categoryClaims => _activeCategory ?? 'category',
            HomeActiveView.add => 'add',
            HomeActiveView.profile => 'profile',
            HomeActiveView.sectionContribution => 'contribute',
          },
          onHome: () => _returnToLocationHome(),
          onProfile: () => _selectFunction(HomeActiveView.profile),
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
    if (place == null) {
      if (_activeView == HomeActiveView.locationHome) {
        return _buildUnauthenticatedOrNoPlaceHome(context, l10n, theme);
      }
      if (_activeView == HomeActiveView.profile) {
        return ProfilePage(
          key: const Key('embedded_profile_page'),
          authService: _authService,
          placeService: _placeService,
          communityService: _communityService,
          initialSelectedPlace: null,
          onBackToHome: _returnToLocationHome,
          onSelectFunction: (view, {category}) => _selectFunction(view, category: category),
        );
      }
      if (_isLoadingLocation || !_authService.isInitialized) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: CircularProgressIndicator(),
          ),
        );
      }
      return _buildNoPlaceSelectedView(context, l10n, theme);
    }

    switch (_activeView) {
      case HomeActiveView.profile:
        return ProfilePage(
          key: const Key('embedded_profile_page'),
          authService: _authService,
          placeService: _placeService,
          communityService: _communityService,
          initialSelectedPlace: place,
          onBackToHome: _returnToLocationHome,
          onSelectFunction: (view, {category}) => _selectFunction(view, category: category),
        );

      case HomeActiveView.exploreStories:
        return PlaceDetailPage(
          key: const Key('embedded_place_detail'),
          placeId: place.id,
          initialPlace: place,
          placeService: _placeService,
          communityService: _communityService,
          authService: _authService,
          onBackToHome: _returnToLocationHome,
        );

      case HomeActiveView.contribute:
        return ProgressiveContributionPage(
          key: const Key('embedded_progressive_contribution'),
          placeId: place.id,
          placeName: place.canonicalName,
          communityService: _communityService,
          onBackToHome: _returnToLocationHome,
        );

      case HomeActiveView.categoryClaims:
        return CategoryClaimsPage(
          key: const Key('embedded_category_claims'),
          placeId: place.id,
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
          placeId: place.id,
          placeName: place.canonicalName,
          communityService: _communityService,
          onBackToHome: _returnToLocationHome,
        );

      case HomeActiveView.sectionContribution:
        return SectionDataContributionPage(
          key: const Key('embedded_section_contribution'),
          placeId: place.id,
          placeName: place.canonicalName,
          sectionType: _activeSectionType ?? SectionContributionType.demographics,
          communityService: _communityService,
          onBackToHome: _returnToLocationHome,
        );

      case HomeActiveView.locationHome:
        if (hasSelectedLocation) {
          return _buildLocationHomeContent(context, place, l10n, theme);
        } else {
          return _buildUnauthenticatedOrNoPlaceHome(context, l10n, theme);
        }
    }
  }

  Widget _buildNoPlaceSelectedView(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          key: const Key('home_no_location_card'),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_off_outlined,
                  size: 48,
                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Location Selected',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please select a location using the location selector in the top header to view or contribute community knowledge.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: _returnToLocationHome,
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

        // Categorize claims
        final historyClaims = claims.where((c) => c.category == ClaimCategory.historicalRecord).toList();
        final folkloreClaims = claims.where((c) => c.category == ClaimCategory.folklore).toList();
        final communityClaims = claims.where((c) =>
          c.category == ClaimCategory.currentFact ||
          c.category == ClaimCategory.personalExperience ||
          c.category == ClaimCategory.publicOpinion ||
          c.category == ClaimCategory.surveyData ||
          c.category == ClaimCategory.disputedClaim
        ).toList();

        // Categorize attributes
        final populationAttrs = attributes.where((a) => a.category == 'population').toList();
        final religionCasteAttrs = populationAttrs.where((a) =>
          a.key.toLowerCase().contains('religion') || a.key.toLowerCase().contains('caste')
        ).toList();
        final generalPopulationAttrs = populationAttrs.where((a) => !religionCasteAttrs.contains(a)).toList();

        final occupationEconomyAttrs = attributes.where((a) =>
          a.key.toLowerCase().contains('occupation') ||
          a.key.toLowerCase().contains('agriculture') ||
          a.key.toLowerCase().contains('business') ||
          a.key.toLowerCase().contains('industry') ||
          a.key.toLowerCase().contains('employment') ||
          a.key.toLowerCase().contains('economy')
        ).toList();

        final voterAttrs = attributes.where((a) =>
          a.key.toLowerCase().contains('voter') ||
          a.key.toLowerCase().contains('election') ||
          a.key.toLowerCase().contains('constituency') ||
          a.key.toLowerCase().contains('polling')
        ).toList();

        final historyAttrs = attributes.where((a) =>
          a.category == 'identity' &&
          (a.key.toLowerCase().contains('history') ||
           a.key.toLowerCase().contains('origin') ||
           a.key.toLowerCase().contains('naming') ||
           a.key.toLowerCase().contains('settlement'))
        ).toList();

        final identityOtherAttrs = attributes.where((a) =>
          a.category == 'identity' &&
          !historyAttrs.contains(a) &&
          !occupationEconomyAttrs.contains(a)
        ).toList();

        final devFacilityAttrs = attributes.where((a) =>
          a.category == 'facility' ||
          a.category == 'development' ||
          a.category == 'issue'
        ).toList();

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

                // Error state
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

                // ==========================================
                // SECTION A: Current Village/City Status
                // ==========================================
                const SectionHeaderCard(
                  key: Key('section_current_status'),
                  sectionLetter: 'A',
                  title: 'Current Village / City Status',
                  subtitle: 'Administrative structure, demographics, electoral information, and occupations',
                  icon: Icons.account_balance,
                ),
                AdministrativeStructureCard(
                  place: place,
                  attributes: attributes,
                  onContributeRepresentative: () => _selectFunction(HomeActiveView.contribute),
                ),
                if (identityOtherAttrs.isNotEmpty) ...[
                  ...identityOtherAttrs.map((a) => PlaceAttributeCard(attribute: a)),
                ],
                // Demographics & Population
                if (generalPopulationAttrs.isNotEmpty) ...[
                  ...generalPopulationAttrs.map((a) => PlaceAttributeCard(attribute: a)),
                ] else ...[
                  UnavailableStatusCard(
                    title: 'Demographic & Population Statistics',
                    message: 'Official demographic profile, population count, and literacy statistics are not yet cataloged for this jurisdiction.',
                    citationRequirement: 'Requires official census publication citations (e.g. Census of India).',
                    onContribute: () => _selectFunction(HomeActiveView.sectionContribution, sectionType: SectionContributionType.demographics),
                    contributeLabel: 'Contribute Data',
                    contributeKey: const Key('contribute_demographics_button'),
                  ),
                ],
                // Religion and Caste statistics (only where credible aggregate data is available)
                if (religionCasteAttrs.isNotEmpty) ...[
                  ...religionCasteAttrs.map((a) => PlaceAttributeCard(attribute: a)),
                ] else ...[
                  UnavailableStatusCard(
                    title: 'Religion & Caste Demographics',
                    message: 'Aggregate religion and caste statistics are not recorded. Only credible aggregate demographic data from official sources is cataloged.',
                    citationRequirement: 'Requires verifiable government survey or official census gazette.',
                    onContribute: () => _selectFunction(HomeActiveView.sectionContribution, sectionType: SectionContributionType.religionCaste),
                    contributeLabel: 'Contribute Data',
                    contributeKey: const Key('contribute_religion_caste_button'),
                  ),
                ],
                // Occupations, Agriculture, Business, Employment
                if (occupationEconomyAttrs.isNotEmpty) ...[
                  ...occupationEconomyAttrs.map((a) => PlaceAttributeCard(attribute: a)),
                ] else ...[
                  UnavailableStatusCard(
                    title: 'Occupations, Agriculture & Employment',
                    message: 'Local economic profile, primary agricultural produce, and business activities are not yet cataloged.',
                    citationRequirement: 'Requires official district economic survey or cooperative records.',
                    onContribute: () => _selectFunction(HomeActiveView.sectionContribution, sectionType: SectionContributionType.occupationEconomy),
                    contributeLabel: 'Contribute Data',
                    contributeKey: const Key('contribute_occupation_economy_button'),
                  ),
                ],
                // Voter statistics and relevant electoral information
                if (voterAttrs.isNotEmpty) ...[
                  ...voterAttrs.map((a) => PlaceAttributeCard(attribute: a)),
                ] else ...[
                  UnavailableStatusCard(
                    title: 'Voter & Electoral Information',
                    message: 'Electoral roll summary, polling station counts, and constituency boundaries are not yet recorded.',
                    citationRequirement: 'Requires Election Commission notification or voter roll summary.',
                    onContribute: () => _selectFunction(HomeActiveView.sectionContribution, sectionType: SectionContributionType.voterElectoral),
                    contributeLabel: 'Contribute Data',
                    contributeKey: const Key('contribute_voter_electoral_button'),
                  ),
                ],

                // ==========================================
                // SECTION B: Local History
                // ==========================================
                SectionHeaderCard(
                  key: const Key('section_local_history'),
                  sectionLetter: 'B',
                  title: 'Local History',
                  subtitle: 'Origin, settlement, prominent figures, and historical events',
                  icon: Icons.history_edu,
                  count: historyClaims.length + historyAttrs.length,
                ),
                if (historyAttrs.isNotEmpty) ...[
                  ...historyAttrs.map((a) => PlaceAttributeCard(attribute: a)),
                ],
                if (historyClaims.isNotEmpty) ...[
                  ...historyClaims.map((claim) => ClaimCard(
                    claim: claim,
                    onTap: () => _openClaimDetail(claim),
                  )),
                ],
                if (historyAttrs.isEmpty && historyClaims.isEmpty) ...[
                  UnavailableStatusCard(
                    title: 'Documented Local History',
                    message: 'No documented historical records, origin accounts, or biographies are recorded yet for this location.',
                    citationRequirement: 'Historical records must distinguish documented facts from oral accounts and include source citations.',
                    onContribute: () => _selectFunction(HomeActiveView.categoryClaims, category: ClaimCategory.historicalRecord),
                    contributeLabel: 'Contribute History',
                    icon: Icons.history,
                  ),
                ],

                // ==========================================
                // SECTION C: Folk Proverbs, Folklore, and Oral Traditions
                // ==========================================
                SectionHeaderCard(
                  key: const Key('section_folklore_traditions'),
                  sectionLetter: 'C',
                  title: 'Folk Proverbs, Folklore & Oral Traditions',
                  subtitle: 'Preserved generational wisdom, proverbs, folktales, and local sayings',
                  icon: Icons.auto_stories,
                  count: folkloreClaims.length,
                ),
                const OralTraditionsNoticeCard(),
                if (folkloreClaims.isNotEmpty) ...[
                  ...folkloreClaims.map((claim) => ClaimCard(
                    claim: claim,
                    onTap: () => _openClaimDetail(claim),
                  )),
                ] else ...[
                  UnavailableStatusCard(
                    title: 'Oral Traditions & Folklore',
                    message: 'No local proverbs, traditional sayings, or folktales have been preserved yet for this location.',
                    citationRequirement: 'Community members and elders are encouraged to share oral histories and proverbs with context and community language attribution.',
                    onContribute: () => _selectFunction(HomeActiveView.categoryClaims, category: ClaimCategory.folklore),
                    contributeLabel: 'Contribute Oral Tradition',
                    icon: Icons.chat_bubble_outline,
                  ),
                ],

                // ==========================================
                // SECTION D: Development and Public Facilities
                // ==========================================
                SectionHeaderCard(
                  key: const Key('section_development_facilities'),
                  sectionLetter: 'D',
                  title: 'Development & Public Facilities',
                  subtitle: 'Infrastructure, public utilities, development schemes, and local issues',
                  icon: Icons.apartment,
                  count: devFacilityAttrs.length,
                ),
                if (devFacilityAttrs.isNotEmpty) ...[
                  ...devFacilityAttrs.map((a) => PlaceAttributeCard(attribute: a)),
                ] else ...[
                  UnavailableStatusCard(
                    title: 'Public Facilities & Development Records',
                    message: 'No public infrastructure, utility facilities, or development works are currently cataloged for this location.',
                    citationRequirement: 'Requires department records, government scheme sanction orders, or verified physical survey.',
                    onContribute: () => _selectFunction(HomeActiveView.sectionContribution, sectionType: SectionContributionType.publicFacilities),
                    contributeLabel: 'Contribute Data',
                    contributeKey: const Key('contribute_public_facilities_button'),
                    icon: Icons.build_outlined,
                  ),
                ],

                // ==========================================
                // SECTION E: Community and Cultural Knowledge
                // ==========================================
                SectionHeaderCard(
                  key: const Key('section_community_knowledge'),
                  sectionLetter: 'E',
                  title: 'Community & Cultural Knowledge',
                  subtitle: 'Current facts, personal experiences, public opinions, and surveys',
                  icon: Icons.people_outline,
                  count: communityClaims.length,
                ),
                if (communityClaims.isNotEmpty) ...[
                  ...communityClaims.map((claim) => ClaimCard(
                    claim: claim,
                    onTap: () => _openClaimDetail(claim),
                  )),
                ] else ...[
                  UnavailableStatusCard(
                    title: 'Community Knowledge & Observations',
                    message: 'No current facts, survey data, or personal community experiences recorded yet for this location.',
                    citationRequirement: 'Contributors can share verified facts, surveyed opinions, or lived experiences with transparency.',
                    onContribute: () => _selectFunction(HomeActiveView.contribute),
                    contributeLabel: 'Contribute Community Knowledge',
                    icon: Icons.groups_outlined,
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openClaimDetail(Claim claim) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClaimDetailPage(
          claim: claim,
          communityService: _communityService,
          authService: _authService,
        ),
      ),
    ).then((_) => _loadLocationData());
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
