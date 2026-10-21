import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../models/place.dart';
import '../../../models/user.dart';
import '../../../models/user_activity.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/community_repository.dart';
import '../../../repositories/place_repository.dart';
import '../../../services/auth_service.dart';
import '../../../services/community_service.dart';
import '../../../services/place_service.dart';
import '../home/home_page.dart';
import '../places/places_page.dart';
import '../places/place_detail_page.dart';
import '../../widgets/session_persistence_warning_banner.dart';
import 'my_drafts_page.dart';

class ProfilePage extends StatefulWidget {
  final AuthService authService;
  final CommunityService? communityService;
  final PlaceService? placeService;
  final Place? initialSelectedPlace;

  const ProfilePage({
    super.key,
    required this.authService,
    this.communityService,
    this.placeService,
    this.initialSelectedPlace,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  UserActivity? _activity;
  bool _isLoadingActivity = false;
  String? _activityError;
  Place? _selectedPlace;
  bool _isLoadingSelectedPlace = false;

  @override
  void initState() {
    super.initState();
    _selectedPlace = widget.initialSelectedPlace;
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging &&
          _selectedTabIndex != _tabController.index) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
    if (widget.authService.isAuthenticated) {
      _isLoadingActivity = true;
    }
    _loadActivity(isInitial: true);
    if (_selectedPlace == null) {
      _isLoadingSelectedPlace = true;
      _loadSelectedPlace(isInitial: true);
    }
  }

  Future<void> _loadSelectedPlace({bool isInitial = false}) async {
    final user = widget.authService.currentUser;
    if (user == null) {
      if (isInitial) {
        _isLoadingSelectedPlace = false;
      }
      return;
    }

    if (!isInitial) {
      setState(() {
        _isLoadingSelectedPlace = true;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPlaceId = user.selectedPlaceId ??
          prefs.getString('selected_place_id_${user.id}') ??
          user.verifiedLocationId;

      if (savedPlaceId != null && savedPlaceId.isNotEmpty) {
        final placeService = _getPlaceService();
        final res = await placeService.repository.getPlaceById(savedPlaceId);
        if (mounted && res.isSuccess && res.data != null) {
          setState(() {
            _selectedPlace = res.data;
          });
        }
      }
    } catch (_) {
      // Ignore errors gracefully
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSelectedPlace = false;
        });
      }
    }
  }

  Future<void> _saveSelectedPlace(Place place) async {
    final user = widget.authService.currentUser;
    if (user != null) {
      try {
        final res = await widget.authService.updateSelectedPlace(place.id);
        if (!res.isSuccess) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(res.failure?.message ?? 'Failed to update selected place'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
          return;
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_place_id_${user.id}', place.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update selected place: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _selectedPlace = place;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadActivity({bool isInitial = false}) async {
    if (!widget.authService.isAuthenticated) {
      if (isInitial) {
        _isLoadingActivity = false;
      }
      return;
    }

    if (!isInitial) {
      setState(() {
        _isLoadingActivity = true;
        _activityError = null;
      });
    }

    final res = await widget.authService.getUserActivity();
    if (!mounted) return;

    setState(() {
      _isLoadingActivity = false;
      if (res.isSuccess && res.data != null) {
        _activity = res.data;
      } else {
        _activityError =
            res.failure?.message ?? 'Failed to load user activity history';
      }
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Sign Out'),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.authService.logout();
      if (!mounted) return;

      // Navigate to HomePage and remove all previous routes from history
      // to prevent back-button reopening of authenticated screens.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomePage(authService: widget.authService),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final user = widget.authService.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.profileTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: theme.colorScheme.outline),
                const SizedBox(height: 12),
                const Text(
                  'No authenticated session found.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Return'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Activity',
            onPressed: _loadActivity,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.logoutButton,
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SessionPersistenceWarningBanner(authService: widget.authService),
              // User Identity Card
              _buildUserProfileCard(context, user),
              const SizedBox(height: 16),

              // Selected Place or Choose Your Place
              if (_isLoadingSelectedPlace) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (_selectedPlace == null) ...[
                _buildChooseYourPlaceShortcut(context),
                const SizedBox(height: 16),
              ] else ...[
                _buildSelectedPlaceCard(context, _selectedPlace!),
                const SizedBox(height: 16),
              ],

              // Contribute about this Place ("इस स्थान के बारे में योगदान दें")
              _buildContributeAboutPlaceAction(context),
              const SizedBox(height: 16),

              // Drafts & Local Actions Bar
              _buildDraftsShortcut(context),
              const SizedBox(height: 16),

              // Activity Summary Stats
              if (_activity != null) ...[
                _buildSummaryStats(context, _activity!.summary),
                const SizedBox(height: 16),
              ],

              // Navigation Tabs for Activity History
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.outline,
                  indicatorColor: theme.colorScheme.primary,
                  isScrollable: false,
                  onTap: (index) {
                    setState(() {
                      _selectedTabIndex = index;
                    });
                  },
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.history_edu, size: 18),
                      text: '${l10n.tabClaims} (${_activity?.claims.length ?? 0})',
                    ),
                    Tab(
                      icon: const Icon(Icons.verified, size: 18),
                      text: '${l10n.tabEvidence} (${_activity?.evidences.length ?? 0})',
                    ),
                    Tab(
                      icon: const Icon(Icons.place, size: 18),
                      text: '${l10n.tabPlaces} (${(_activity?.places.length ?? 0) + (_activity?.placeAttributes.length ?? 0)})',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Active Tab Content
              if (_isLoadingActivity)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_activityError != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 12),
                      Text(
                        _activityError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loadActivity,
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.retryButton),
                      ),
                    ],
                  ),
                )
              else
                _buildActiveTabContent(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(BuildContext context) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildClaimsList(context, _activity?.claims ?? []);
      case 1:
        return _buildEvidenceList(context, _activity?.evidences ?? []);
      case 2:
        return _buildPlacesList(
          context,
          _activity?.places ?? [],
          _activity?.placeAttributes ?? [],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildUserProfileCard(BuildContext context, User user) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    user.displayName.isNotEmpty
                        ? user.displayName.substring(0, 1).toUpperCase()
                        : 'U',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${user.id}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildRoleBadge(user.role),
                          if (user.isIdentityVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.green.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified,
                                      size: 12, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.identityVerifiedBadge,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.grey.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                l10n.unverifiedIdentityBadge,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 14, color: theme.colorScheme.outline),
                    const SizedBox(width: 6),
                    Text(
                      '${l10n.memberSinceLabel}: ${_formatDate(user.joinedAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                if (user.verifiedLocationId != null)
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Location Verified',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color bg;
    Color fg;
    switch (role) {
      case 'ADMIN':
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        break;
      case 'MODERATOR':
        bg = Colors.purple.shade100;
        fg = Colors.purple.shade900;
        break;
      case 'REVIEWER':
        bg = Colors.indigo.shade100;
        fg = Colors.indigo.shade900;
        break;
      case 'LOCAL_CONTRIBUTOR':
        bg = Colors.teal.shade100;
        fg = Colors.teal.shade900;
        break;
      default:
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role.replaceAll('_', ' '),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  PlaceService _getPlaceService() {
    if (widget.placeService != null) return widget.placeService!;
    final client = widget.authService.repository is AuthRepositoryImpl
        ? (widget.authService.repository as AuthRepositoryImpl).client
        : ApiClient();
    return PlaceService(repository: PlaceRepositoryImpl(client: client));
  }

  Widget _buildChooseYourPlaceShortcut(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.add_location_alt_outlined, color: theme.colorScheme.primary),
        title: const Text(
          'Choose Your Place',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Select your village, town, or district to add local information'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final placeService = _getPlaceService();
          final picked = await Navigator.of(context).push<Place>(
            MaterialPageRoute(
              builder: (_) => PlacesPage(
                placeService: placeService,
                isSelectionMode: true,
              ),
            ),
          );
          if (picked != null) {
            await _saveSelectedPlace(picked);
          }
          if (mounted) {
            _loadActivity();
          }
        },
      ),
    );
  }

  Widget _buildSelectedPlaceCard(BuildContext context, Place place) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final localizedName = place.nameForLanguage(locale);
    final showLocalized = localizedName.isNotEmpty && localizedName != place.canonicalName;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Place',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        place.canonicalName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (showLocalized)
                        Text(
                          localizedName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final placeService = _getPlaceService();
                    final picked = await Navigator.of(context).push<Place>(
                      MaterialPageRoute(
                        builder: (_) => PlacesPage(
                          placeService: placeService,
                          isSelectionMode: true,
                        ),
                      ),
                    );
                    if (picked != null) {
                      await _saveSelectedPlace(picked);
                    }
                    if (mounted) {
                      _loadActivity();
                    }
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                _buildPlaceLevelBadge(place.level),
                const SizedBox(width: 8),
                Text(
                  'ID: ${place.id}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                if (place.parentPath != null && place.parentPath!.isNotEmpty) ...[
                  const Spacer(),
                  Flexible(
                    child: Text(
                      place.parentPath!.map((p) => p.canonicalName).join(' > '),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceLevelBadge(String level) {
    Color bg;
    Color fg;
    switch (level.toUpperCase()) {
      case 'COUNTRY':
        bg = Colors.purple.shade100;
        fg = Colors.purple.shade900;
        break;
      case 'STATE':
        bg = Colors.indigo.shade100;
        fg = Colors.indigo.shade900;
        break;
      case 'DISTRICT':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        break;
      case 'TEHSIL':
        bg = Colors.teal.shade100;
        fg = Colors.teal.shade900;
        break;
      case 'VILLAGE':
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        break;
      default:
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        level,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildContributeAboutPlaceAction(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.add_comment_outlined, color: theme.colorScheme.primary),
        title: const Text(
          'इस स्थान के बारे में योगदान दें',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _selectedPlace != null
              ? 'Contribute stories and local knowledge for ${_selectedPlace!.canonicalName}'
              : 'Choose a place first to start contributing local knowledge',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          if (_selectedPlace == null) {
            final placeService = _getPlaceService();
            final picked = await Navigator.of(context).push<Place>(
              MaterialPageRoute(
                builder: (_) => PlacesPage(
                  placeService: placeService,
                  isSelectionMode: true,
                ),
              ),
            );
            if (picked != null) {
              await _saveSelectedPlace(picked);
              if (mounted) {
                _navigateToPlaceContribution(picked);
              }
            }
          } else {
            _navigateToPlaceContribution(_selectedPlace!);
          }
        },
      ),
    );
  }

  void _navigateToPlaceContribution(Place place) {
    final placeService = _getPlaceService();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceDetailPage(
          placeId: place.id,
          initialPlace: place,
          placeService: placeService,
          communityService: widget.communityService,
        ),
      ),
    ).then((_) {
      if (mounted) {
        _loadActivity();
      }
    });
  }

  Widget _buildDraftsShortcut(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.edit_note, color: theme.colorScheme.primary),
        title: const Text('My Saved Drafts'),
        subtitle: const Text('Resume working on unsubmitted contributions'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          final communityService = widget.communityService ??
              CommunityService(
                repository: CommunityRepositoryImpl(
                  client: widget.authService.repository is AuthRepositoryImpl
                      ? (widget.authService.repository as AuthRepositoryImpl).client
                      : ApiClient(),
                ),
              );

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MyDraftsPage(
                authService: widget.authService,
                communityService: communityService,
              ),
            ),
          ).then((_) {
            if (mounted) {
              _loadActivity();
            }
          });
        },
      ),
    );
  }

  Widget _buildSummaryStats(BuildContext context, UserActivitySummary summary) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(context, 'Total', summary.totalContributions),
            _buildStatItem(context, 'Stories', summary.claimsCount),
            _buildStatItem(context, 'Evidence', summary.evidencesCount),
            _buildStatItem(context, 'Places', summary.placesCount),
            _buildStatItem(context, 'Attributes', summary.placeAttributesCount),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, int count) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          '$count',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildClaimsList(BuildContext context, List<UserClaimActivity> claims) {
    if (claims.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history_edu,
        title: 'No Stories Submitted',
        message: 'Your submitted claims and stories will appear here with real-time verification statuses.',
      );
    }

    return Column(
      children: claims.map((c) {
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildCategoryBadge(c.category),
                    const SizedBox(width: 8),
                    _buildStatusBadge(c.status),
                    const Spacer(),
                    Text(
                      _formatDate(c.submittedAt),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  c.title.original,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                if (c.body != null && c.body!.original.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    c.body!.original,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.attach_file,
                        size: 14, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(
                      '${c.evidenceCount} evidence items',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (c.locationId != null) ...[
                      const Spacer(),
                      Text(
                        'Location ID: ${c.locationId}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEvidenceList(
      BuildContext context, List<UserEvidenceActivity> evidences) {
    if (evidences.isEmpty) {
      return _buildEmptyState(
        icon: Icons.verified,
        title: 'No Evidence Submissions',
        message: 'Documents, URLs, and photos you submit in support of claims will appear here.',
      );
    }

    return Column(
      children: evidences.map((e) {
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        e.sourceType,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(e.status),
                    const Spacer(),
                    Text(
                      _formatDate(e.submittedAt),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  e.summary.isNotEmpty ? e.summary : 'Evidence record #${e.id}',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  'Attached to Claim: ${e.claimId}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlacesList(
    BuildContext context,
    List<UserPlaceActivity> places,
    List<UserPlaceAttributeActivity> attributes,
  ) {
    if (places.isEmpty && attributes.isEmpty) {
      return Column(
        children: [
          _buildEmptyState(
            icon: Icons.place,
            title: 'No Place Contributions',
            message: 'New geographic locations and verified facility attributes you submit will be displayed here.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              final placeService = _getPlaceService();
              final picked = await Navigator.of(context).push<Place>(
                MaterialPageRoute(
                  builder: (_) => PlacesPage(
                    placeService: placeService,
                    isSelectionMode: true,
                  ),
                ),
              );
              if (picked != null) {
                await _saveSelectedPlace(picked);
              }
              if (mounted) {
                _loadActivity();
              }
            },
            icon: const Icon(Icons.add_location_alt),
            label: const Text('Select a Place to Contribute'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (places.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Places Created (${places.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          ...places.map((p) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.location_city),
                  title: Text(p.canonicalName),
                  subtitle: Text('Level: ${p.level} • Status: ${p.status}'),
                  trailing: Text(
                    _formatDate(p.createdAt),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              )),
          const SizedBox(height: 12),
        ],
        if (attributes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Facility & Attribute Records (${attributes.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          ...attributes.map((a) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.local_hospital_outlined),
                  title: Text(a.key),
                  subtitle: Text('Place: ${a.placeId} • Status: ${a.status}'),
                  trailing: Text(
                    _formatDate(a.submittedAt),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    Color color;
    switch (category) {
      case 'HISTORICAL_RECORD':
        color = Colors.brown;
        break;
      case 'CURRENT_FACT':
        color = Colors.blue;
        break;
      case 'FOLKLORE':
        color = Colors.purple;
        break;
      case 'PERSONAL_EXPERIENCE':
        color = Colors.teal;
        break;
      case 'PUBLIC_OPINION':
        color = Colors.orange;
        break;
      case 'SURVEY_DATA':
        color = Colors.indigo;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        category.replaceAll('_', ' '),
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'verified':
        color = Colors.green;
        break;
      case 'partially_verified':
        color = Colors.lightGreen;
        break;
      case 'unverified':
        color = Colors.orange;
        break;
      case 'disputed':
        color = Colors.red;
        break;
      case 'rejected':
        color = Colors.red.shade900;
        break;
      case 'insufficient_evidence':
        color = Colors.deepOrange;
        break;
      case 'under_review':
        color = Colors.amber.shade800;
        break;
      case 'submitted':
        color = Colors.blue;
        break;
      case 'draft':
        color = Colors.grey;
        break;
      default:
        color = Colors.blueGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
