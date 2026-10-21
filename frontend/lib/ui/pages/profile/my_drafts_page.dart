import 'package:flutter/material.dart';
import '../../../models/claim.dart';
import '../../../services/auth_service.dart';
import '../../../services/community_service.dart';
import '../../card/claim_card.dart';
import '../places/progressive_contribution_page.dart';

class MyDraftsPage extends StatefulWidget {
  final AuthService authService;
  final CommunityService communityService;

  const MyDraftsPage({
    super.key,
    required this.authService,
    required this.communityService,
  });

  @override
  State<MyDraftsPage> createState() => _MyDraftsPageState();
}

class _MyDraftsPageState extends State<MyDraftsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadDrafts();
      }
    });
  }

  void _loadDrafts() {
    final user = widget.authService.currentUser;
    if (user != null && mounted) {
      widget.communityService.fetchMyDrafts(user.id);
    }
  }

  void _openDraft(Claim draft) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProgressiveContributionPage(
          placeId: draft.locationId,
          placeName: 'Saved Place Draft',
          communityService: widget.communityService,
          existingDraft: draft,
        ),
      ),
    ).then((_) {
      if (mounted) {
        _loadDrafts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Drafts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Drafts',
            onPressed: _loadDrafts,
          ),
        ],
      ),
      body: SafeArea(
        child: user == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 48, color: theme.colorScheme.outline),
                      const SizedBox(height: 12),
                      const Text(
                        'Authentication Required',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please log in to view and resume your saved community drafts.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : AnimatedBuilder(
                animation: widget.communityService,
                builder: (context, _) {
                  if (widget.communityService.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final drafts = widget.communityService.myDrafts;
                  if (drafts.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_note, size: 56, color: theme.colorScheme.outline),
                            const SizedBox(height: 12),
                            const Text(
                              'No Saved Drafts',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'When you save contributions without submitting, they will appear here so you can resume anytime.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: drafts.length,
                    itemBuilder: (context, index) {
                      final draft = drafts[index];
                      return ClaimCard(
                        claim: draft,
                        onTap: () => _openDraft(draft),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
