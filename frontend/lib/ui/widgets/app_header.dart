import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../models/place.dart';
import '../../models/user.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/community_repository.dart';
import '../../repositories/place_repository.dart';
import '../../services/auth_service.dart';
import '../../services/community_service.dart';
import '../../services/place_service.dart';
import '../pages/auth/login_page.dart';
import '../pages/profile/my_drafts_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/review/review_queue_page.dart';
import 'location_search_dialog.dart';
import 'residence_type_dialog.dart';

class GlobalAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String? titleText;
  final Widget? titleWidget;
  final Widget? leading;
  final AuthService? authService;
  final PlaceService? placeService;
  final CommunityService? communityService;
  final VoidCallback? onPlaceChanged;
  final VoidCallback? onAuthChanged;
  final VoidCallback? onProfileTap;
  final List<Widget>? extraActions;
  final bool showLocation;
  final bool showEndDrawerButton;
  final PreferredSizeWidget? bottom;

  const GlobalAppBar({
    super.key,
    this.titleText,
    this.titleWidget,
    this.leading,
    this.authService,
    this.placeService,
    this.communityService,
    this.onPlaceChanged,
    this.onAuthChanged,
    this.onProfileTap,
    this.extraActions,
    this.showLocation = true,
    this.showEndDrawerButton = true,
    this.bottom,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  State<GlobalAppBar> createState() => _GlobalAppBarState();
}

class _GlobalAppBarState extends State<GlobalAppBar> {
  String? _resolvedLocationName;
  String? _lastResolvedPlaceId;
  String? _lastAuthUserId;

  @override
  void initState() {
    super.initState();
    _lastAuthUserId = widget.authService?.currentUser?.id;
    widget.authService?.addListener(_handleStateChange);
    widget.placeService?.addListener(_handleStateChange);
    _resolveLocation();
  }

  @override
  void didUpdateWidget(covariant GlobalAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authService != widget.authService) {
      oldWidget.authService?.removeListener(_handleStateChange);
      widget.authService?.addListener(_handleStateChange);
      _lastAuthUserId = widget.authService?.currentUser?.id;
    }
    if (oldWidget.placeService != widget.placeService) {
      oldWidget.placeService?.removeListener(_handleStateChange);
      widget.placeService?.addListener(_handleStateChange);
    }
    _resolveLocation();
  }

  @override
  void dispose() {
    widget.authService?.removeListener(_handleStateChange);
    widget.placeService?.removeListener(_handleStateChange);
    super.dispose();
  }

  void _handleStateChange() {
    if (!mounted) return;
    final currentUserId = widget.authService?.currentUser?.id;
    if (_lastAuthUserId != currentUserId) {
      _lastAuthUserId = currentUserId;
      _lastResolvedPlaceId = null;
      _resolvedLocationName = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
        _resolveLocation();
      }
    });
  }

  Future<void> _resolveLocation() async {
    final user = widget.authService?.currentUser;
    String? currentPlaceId;
    if (user != null) {
      if (user.selectedPlaceId != null && user.selectedPlaceId!.isNotEmpty) {
        currentPlaceId = user.selectedPlaceId;
      } else if (user.verifiedLocationId != null && user.verifiedLocationId!.isNotEmpty) {
        currentPlaceId = user.verifiedLocationId;
      } else if (widget.placeService?.selectedPlaceUserId == user.id) {
        currentPlaceId = widget.placeService?.selectedPlace?.id;
      } else {
        String? cachedUserPlaceId;
        try {
          final prefs = await SharedPreferences.getInstance();
          cachedUserPlaceId = prefs.getString('selected_place_id_${user.id}');
        } catch (_) {}
        currentPlaceId = cachedUserPlaceId;
      }
    } else {
      if (widget.placeService?.selectedPlaceUserId == null) {
        currentPlaceId = widget.placeService?.selectedPlace?.id;
      } else {
        currentPlaceId = null;
      }
      if (currentPlaceId == null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          currentPlaceId = prefs.getString('selected_place_id');
        } catch (_) {}
      }
    }

    // 1. If memory already has the selected place and matches currentPlaceId
    if (currentPlaceId != null && currentPlaceId.isNotEmpty) {
      if (widget.placeService?.selectedPlace != null &&
          widget.placeService!.selectedPlace!.id == currentPlaceId &&
          (user == null
              ? widget.placeService!.selectedPlaceUserId == null
              : widget.placeService!.selectedPlaceUserId == user.id)) {
        final name = widget.placeService!.selectedPlace!.canonicalName;
        if (_resolvedLocationName != name) {
          if (mounted) setState(() => _resolvedLocationName = name);
        }
        return;
      }

      // 2. Check SharedPreferences cache to avoid flashing fallbacks during async resolution
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedName = user != null
            ? prefs.getString('selected_place_name_${user.id}')
            : prefs.getString('selected_place_name');
        final cachedId = user != null
            ? prefs.getString('selected_place_id_${user.id}')
            : prefs.getString('selected_place_id');

        if (cachedId == currentPlaceId && cachedName != null && cachedName.isNotEmpty) {
          if (mounted && _resolvedLocationName != cachedName) {
            setState(() => _resolvedLocationName = cachedName);
          }
        }
      } catch (_) {}

      // 3. Resolve asynchronously via PlaceService if not resolved or ID changed
      if (_lastResolvedPlaceId != currentPlaceId && widget.placeService != null) {
        _lastResolvedPlaceId = currentPlaceId;
        final place = await widget.placeService!.resolveSelectedPlace(currentPlaceId, userId: user?.id);
        if (place != null && mounted) {
          if (widget.authService?.currentUser?.id != user?.id) {
            return;
          }
          setState(() => _resolvedLocationName = place.canonicalName);
          try {
            final prefs = await SharedPreferences.getInstance();
            if (user != null) {
              await prefs.setString('selected_place_name_${user.id}', place.canonicalName);
            } else {
              await prefs.setString('selected_place_name', place.canonicalName);
            }
          } catch (_) {}
        }
      }
    } else {
      _lastResolvedPlaceId = null;
      if (_resolvedLocationName != null && mounted) {
        setState(() => _resolvedLocationName = null);
      }
    }
  }

  PlaceService _getPlaceService() {
    return widget.placeService ??
        PlaceService(repository: PlaceRepositoryImpl(client: ApiClient()));
  }

  AuthService _getAuthService() {
    return widget.authService ??
        AuthService(repository: AuthRepositoryImpl(client: ApiClient()));
  }

  CommunityService _getCommunityService() {
    return widget.communityService ??
        CommunityService(repository: CommunityRepositoryImpl(client: ApiClient()));
  }

  Future<void> _openLocationPicker() async {
    final picked = await showDialog<Place>(
      context: context,
      builder: (_) => LocationSearchDialog(
        placeService: _getPlaceService(),
        currentPlaceId: _lastResolvedPlaceId,
        currentPlaceName: _resolvedLocationName,
      ),
    );

    if (!mounted || picked == null) return;

    final user = widget.authService?.currentUser;
    final hasClassification = user != null && user.hasClassificationForPlace(picked.id);

    if (!hasClassification && user != null) {
      // Rule 2 & 3: Place is selected ONLY after explicit Indigenous / Non-Indigenous classification
      final result = await showDialog<PlaceRelationshipResult>(
        context: context,
        builder: (_) => ResidenceTypeDialog(placeName: picked.canonicalName),
      );

      // If user cancelled, place remains unselected
      if (!mounted || result == null) return;

      final relRes = await widget.authService?.updatePlaceRelationship(
        placeId: picked.id,
        residenceType: result.residenceType,
        indigenousClassification: result.indigenousClassification,
      );

      if (relRes != null && !relRes.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(relRes.failure?.message ?? 'Failed to update selected place on server'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }
    } else if (user != null) {
      // Place already has an established classification: switch directly
      final res = await widget.authService?.updateSelectedPlace(picked.id);
      if (res != null && !res.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.failure?.message ?? 'Failed to update selected place on server'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      if (user != null) {
        await prefs.setString('selected_place_id_${user.id}', picked.id);
        await prefs.setString('selected_place_name_${user.id}', picked.canonicalName);
      } else {
        await prefs.setString('selected_place_id', picked.id);
        await prefs.setString('selected_place_name', picked.canonicalName);
      }
    } catch (_) {}

    widget.placeService?.setSelectedPlace(picked, userId: user?.id);

    if (mounted) {
      setState(() {
        _resolvedLocationName = picked.canonicalName;
        _lastResolvedPlaceId = picked.id;
      });
    }

    widget.onPlaceChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appTitle = l10n?.appTitle ?? 'My Root';
    final theme = Theme.of(context);
    final user = widget.authService?.currentUser;

    return AppBar(
      leading: widget.leading ??
          Builder(
            builder: (leadingCtx) {
              final scaffold = Scaffold.maybeOf(leadingCtx);
              final hasDrawer = scaffold?.hasDrawer ?? false;
              final canPop = ModalRoute.of(leadingCtx)?.canPop ?? false;
              if (canPop) {
                return const BackButton();
              }
              if (hasDrawer) {
                return IconButton(
                  key: const Key('home_features_drawer_button'),
                  icon: const Icon(Icons.menu),
                  tooltip: 'Features & Functions',
                  onPressed: () {
                    Scaffold.of(leadingCtx).openDrawer();
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
      title: widget.titleWidget ??
          Text(
            widget.titleText ?? appTitle,
            overflow: TextOverflow.ellipsis,
          ),
      centerTitle: false,
      actions: [
        if (widget.showLocation) _buildLocationWidget(context, theme, l10n),
        IconButton(
          icon: const Icon(Icons.language),
          tooltip: 'Change Language / भाषा बदलें',
          onPressed: () => _showLanguageDialog(context),
        ),
        if (widget.extraActions != null) ...widget.extraActions!,
        if (user != null)
          _buildUserBadge(context, theme, l10n, user)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LoginPage(authService: _getAuthService()),
                  ),
                ).then((_) {
                  widget.onAuthChanged?.call();
                });
              },
              icon: const Icon(Icons.login, size: 16),
              label: Text(l10n?.loginTitle ?? 'Sign In'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
        if (widget.showEndDrawerButton)
          Builder(
            builder: (btnCtx) => IconButton(
              key: const Key('latest_users_drawer_button'),
              icon: const Icon(Icons.people_outline),
              tooltip: 'Latest Users',
              onPressed: () {
                Scaffold.of(btnCtx).openEndDrawer();
              },
            ),
          ),
      ],
      bottom: widget.bottom,
    );
  }

  Widget _buildLocationWidget(
      BuildContext context, ThemeData theme, AppLocalizations? l10n) {
    final hasSelection =
        _resolvedLocationName != null && _resolvedLocationName!.isNotEmpty;
    final displayName =
        hasSelection ? _resolvedLocationName! : (l10n?.placesTitle ?? 'Select Location');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: OutlinedButton.icon(
        key: Key(hasSelection ? 'header_selected_location' : 'header_location_selector'),
        onPressed: _openLocationPicker,
        icon: Icon(
          hasSelection ? Icons.place : Icons.place_outlined,
          size: 16,
          color: hasSelection ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Text(
            displayName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: hasSelection ? FontWeight.w600 : FontWeight.normal,
              color: hasSelection
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          side: BorderSide(
            color: hasSelection
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : theme.colorScheme.outlineVariant,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  Widget _buildUserBadge(
      BuildContext context, ThemeData theme, AppLocalizations? l10n, User user) {
    final effectiveName =
        user.displayName.trim().isNotEmpty ? user.displayName.trim() : 'User';

    return Theme(
      data: theme.copyWith(
        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Account Menu',
        offset: const Offset(0, 48),
        onSelected: (val) async {
          if (val == 'profile') {
            if (widget.onProfileTap != null) {
              widget.onProfileTap!();
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfilePage(
                    authService: _getAuthService(),
                    communityService: _getCommunityService(),
                    placeService: _getPlaceService(),
                  ),
                ),
              ).then((_) => widget.onAuthChanged?.call());
            }
          } else if (val == 'drafts') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MyDraftsPage(
                  authService: _getAuthService(),
                  communityService: _getCommunityService(),
                ),
              ),
            ).then((_) => widget.onAuthChanged?.call());
          } else if (val == 'review_queue') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReviewQueuePage(
                  communityService: _getCommunityService(),
                  authService: _getAuthService(),
                  placeService: _getPlaceService(),
                ),
              ),
            ).then((_) => widget.onAuthChanged?.call());
          } else if (val == 'logout') {
            _confirmSignOut(context);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  effectiveName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                if (user.indigenousClassification?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.indigenousClassification!,
                    key: const Key('header_user_classification'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
                if (user.role.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.role.replaceAll('_', ' '),
                    key: const Key('header_user_role'),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const Divider(),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'profile',
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 20),
                const SizedBox(width: 12),
                Text(l10n?.profileTitle ?? 'User Profile'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'drafts',
            child: Row(
              children: [
                Icon(Icons.edit_note, size: 20),
                SizedBox(width: 12),
                Text('My Drafts'),
              ],
            ),
          ),
          if (user.isReviewer)
            const PopupMenuItem<String>(
              value: 'review_queue',
              child: Row(
                children: [
                  Icon(Icons.rate_review_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Review Queue'),
                ],
              ),
            ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [
                Icon(Icons.logout, size: 20, color: theme.colorScheme.error),
                const SizedBox(width: 12),
                Text(
                  l10n?.logoutButton ?? 'Sign Out',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  key: const Key('header_user_avatar'),
                  radius: 13,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    effectiveName.isNotEmpty
                        ? effectiveName.substring(0, 1).toUpperCase()
                        : 'U',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    'Welcome, $effectiveName',
                    key: const Key('header_user_display_name'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Select Language / भाषा चुनें'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('English'),
              subtitle: const Text('Default system language'),
              onTap: () {
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Language set to English')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('हिन्दी (Hindi)'),
              subtitle: const Text('स्थानीय भाषा'),
              onTap: () {
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('भाषा हिन्दी में सेट की गई')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
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

    if (confirmed == true && context.mounted) {
      await widget.authService?.logout();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully signed out')),
        );
      }
      widget.onAuthChanged?.call();
    }
  }
}
