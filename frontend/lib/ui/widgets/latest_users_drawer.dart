import 'package:flutter/material.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/place_service.dart';

class LatestUsersDrawer extends StatefulWidget {
  final AuthService? authService;
  final PlaceService? placeService;
  final VoidCallback? onHomeTap;

  const LatestUsersDrawer({
    super.key,
    this.authService,
    this.placeService,
    this.onHomeTap,
  });

  @override
  State<LatestUsersDrawer> createState() => _LatestUsersDrawerState();
}

class _LatestUsersDrawerState extends State<LatestUsersDrawer> {
  List<PublicUser> _users = [];
  bool _isLoading = true;
  bool _isUnsupported = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isUnsupported = false;
    });

    final authService = widget.authService;
    if (authService == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUnsupported = true;
        });
      }
      return;
    }

    try {
      final response = await authService.getLatestUsers();
      if (!mounted) return;

      if (response.isSuccess && response.data != null) {
        setState(() {
          _users = response.data!;
          _isLoading = false;
          _isUnsupported = false;
        });
      } else {
        final failure = response.failure;
        final isNotFound = failure?.code == 'NOT_FOUND' ||
            (failure?.message.toLowerCase().contains('not found') ?? false) ||
            (failure?.message.toLowerCase().contains('404') ?? false);

        setState(() {
          _isLoading = false;
          if (isNotFound) {
            _isUnsupported = true;
          } else {
            _errorMessage = failure?.message ?? 'Failed to load latest users';
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred while loading users';
      });
    }
  }

  String _formatJoined(DateTime? dt) {
    if (dt == null) return 'Recently joined';
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays < 1) {
      return 'Joined today';
    } else if (difference.inDays < 30) {
      return 'Joined ${difference.inDays}d ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Joined ${months}mo ago';
    } else {
      return 'Joined ${dt.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final currentUser = widget.authService?.currentUser;

    return Drawer(
      key: const Key('latest_users_drawer'),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drawer App Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
                border: Border(
                  bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.nature_people, size: 28, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(
                        l10n?.appTitle ?? 'My Root',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.tagline ?? 'Preserving Local Knowledge',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  if (currentUser != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: theme.colorScheme.primary,
                          child: Text(
                            currentUser.displayName.isNotEmpty
                                ? currentUser.displayName[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currentUser.displayName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Navigation Links
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(l10n?.navHome ?? 'Home'),
              onTap: () {
                Navigator.of(context).pop();
                widget.onHomeTap?.call();
              },
            ),

            const Divider(indent: 16, endIndent: 16),

            // Dedicated Section for "Latest Users"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.people_outline, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Latest Users',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: 'Refresh',
                    onPressed: _loadUsers,
                  ),
                ],
              ),
            ),

            // Content Area: Loading / Unsupported / Error / Empty / List
            Expanded(
              child: _buildLatestUsersContent(context, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestUsersContent(BuildContext context, ThemeData theme) {
    if (_isLoading) {
      return const Center(
        key: Key('latest_users_loading'),
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isUnsupported) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          key: const Key('latest_users_unsupported'),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 36,
                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 8),
                Text(
                  'Public Directory Unavailable',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'A public user directory API is not exposed by the current backend to protect user privacy.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        key: const Key('latest_users_error'),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 36, color: theme.colorScheme.error),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(
        key: Key('latest_users_empty'),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No recent users found.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Render users safely showing strictly public fields (displayName, public avatar, joinedAt)
    return ListView.separated(
      key: const Key('latest_users_list'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
      itemBuilder: (context, index) {
        final user = _users[index];
        final initial = user.displayName.trim().isNotEmpty
            ? user.displayName.trim()[0].toUpperCase()
            : 'U';

        return ListTile(
          key: Key('latest_user_item_${user.displayName}'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primaryContainer,
            backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                ? Text(
                    initial,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
          title: Text(
            user.displayName,
            key: Key('user_name_${user.displayName}'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            _formatJoined(user.joinedAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontSize: 11,
            ),
          ),
        );
      },
    );
  }
}
