import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

/// In-app warning banner displayed when a user is authenticated but their session
/// cannot be saved persistently because OS/hardware secure storage is unavailable.
///
/// Features:
/// - Listens reactively to [AuthService].
/// - Displays when `authService.isAuthenticated && !authService.isSessionPersistent`.
/// - Disappears automatically when session is cleared or persistence is restored.
/// - Supports accessible live-region semantics and in-session dismissal with auto-reset.
class SessionPersistenceWarningBanner extends StatefulWidget {
  final AuthService authService;
  final VoidCallback? onDismissed;

  const SessionPersistenceWarningBanner({
    super.key,
    required this.authService,
    this.onDismissed,
  });

  @override
  State<SessionPersistenceWarningBanner> createState() =>
      _SessionPersistenceWarningBannerState();
}

class _SessionPersistenceWarningBannerState
    extends State<SessionPersistenceWarningBanner> {
  bool _isDismissed = false;
  bool? _lastSessionPersistent;
  String? _lastUserId;

  void _syncDismissalState() {
    final currentPersistent = widget.authService.isSessionPersistent;
    final currentUserId = widget.authService.currentUser?.id;

    // Reset dismissal whenever persistence transitions or user identity changes
    if (_lastSessionPersistent != null &&
        _lastSessionPersistent != currentPersistent) {
      _isDismissed = false;
    }
    if (_lastUserId != currentUserId) {
      _isDismissed = false;
    }

    _lastSessionPersistent = currentPersistent;
    _lastUserId = currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authService,
      builder: (context, _) {
        _syncDismissalState();

        if (!widget.authService.isAuthenticated ||
            widget.authService.isSessionPersistent ||
            _isDismissed) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        const warningTitle = 'Session Persistence Disabled';
        const warningBody =
            'Secure credential storage is unavailable on this device. '
            'Your session may be lost when the app closes, and you will need to log in again.';

        return Semantics(
          container: true,
          liveRegion: true,
          label: '$warningTitle: $warningBody',
          child: Container(
            key: const Key('session_persistence_warning_banner'),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.error.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.error,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        warningTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        warningBody,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          height: 1.3,
                        ),
                      ),
                      if (widget.authService.persistenceWarning != null &&
                          widget.authService.persistenceWarning!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.authService.persistenceWarning!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.error,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('dismiss_persistence_warning_button'),
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Dismiss warning',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() {
                      _isDismissed = true;
                    });
                    widget.onDismissed?.call();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
