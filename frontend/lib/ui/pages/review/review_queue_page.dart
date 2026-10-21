import 'package:flutter/material.dart';
import '../../../models/claim.dart';
import '../../../services/auth_service.dart';
import '../../../services/community_service.dart';
import '../../../services/place_service.dart';
import '../claims/claim_detail_page.dart';

class ReviewQueuePage extends StatefulWidget {
  final CommunityService communityService;
  final AuthService authService;
  final PlaceService? placeService;

  const ReviewQueuePage({
    super.key,
    required this.communityService,
    required this.authService,
    this.placeService,
  });

  @override
  State<ReviewQueuePage> createState() => _ReviewQueuePageState();
}

class _ReviewQueuePageState extends State<ReviewQueuePage> {
  bool _isSubmittingDecision = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.communityService.fetchReviewQueue();
    });
  }

  void _showReviewDialog(Claim claim) {
    final currentUserId = widget.authService.currentUser?.id;
    if (claim.submittedBy != null && claim.submittedBy == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot review your own submission (Self-review prohibited).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String selectedDecision = 'verified';
    if (claim.isFolklore || claim.category == 'PUBLIC_OPINION') {
      selectedDecision = 'partially_verified';
    }

    final reasonController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogContentCtx, setDialogState) {
            final cannotBeVerified = claim.isFolklore || claim.category == 'PUBLIC_OPINION';

            return AlertDialog(
              title: Text('Review Submission: ${claim.title.original}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (cannotBeVerified)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Folklore and public opinion submissions cannot be marked as fully verified.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Text('Decision Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDecision,
                      isExpanded: true,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: [
                        if (!cannotBeVerified)
                          const DropdownMenuItem(
                            value: 'verified',
                            child: Text('Verified (Confirmed with evidence)'),
                          ),
                        const DropdownMenuItem(
                          value: 'partially_verified',
                          child: Text('Partially Verified'),
                        ),
                        const DropdownMenuItem(
                          value: 'unverified',
                          child: Text('Unverified'),
                        ),
                        const DropdownMenuItem(
                          value: 'disputed',
                          child: Text('Disputed (Conflicting accounts)'),
                        ),
                        const DropdownMenuItem(
                          value: 'insufficient_evidence',
                          child: Text('Insufficient Evidence'),
                        ),
                        const DropdownMenuItem(
                          value: 'rejected',
                          child: Text('Rejected (Violates guidelines)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedDecision = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text('Verification Grounds / Reason (Min 20 characters):',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Explain evidence sources or grounds for verification verdict...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Reviewer Comments (Optional):',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Additional feedback for contributor...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _isSubmittingDecision
                          ? null
                          : () async {
                              final reason = reasonController.text.trim();
                              if (reason.length < 20) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Reason must be at least 20 characters.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              Navigator.of(dialogCtx).pop();
                              setState(() => _isSubmittingDecision = true);

                              final success = await widget.communityService.reviewClaim(
                                claimId: claim.id,
                                decisionStatus: selectedDecision,
                                reason: reason,
                                reviewerNote: noteController.text.trim(),
                              );

                              if (!mounted || !context.mounted) return;
                              setState(() => _isSubmittingDecision = false);

                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Review verdict recorded successfully.'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      widget.communityService.errorMessage ?? 'Review failed.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: const Text('Submit Review Verdict'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Queue',
            onPressed: () => widget.communityService.fetchReviewQueue(),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.communityService,
        builder: (context, _) {
          if (widget.communityService.isLoading && widget.communityService.reviewQueue.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (widget.communityService.errorMessage != null &&
              widget.communityService.reviewQueue.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text(
                      widget.communityService.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => widget.communityService.fetchReviewQueue(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (widget.communityService.reviewQueue.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.assignment_turned_in_outlined,
                        size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                    const SizedBox(height: 16),
                    Text(
                      'No Submissions Pending Review',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All community knowledge contributions have been reviewed and verified.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: widget.communityService.reviewQueue.length,
            itemBuilder: (context, index) {
              final claim = widget.communityService.reviewQueue[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildCategoryChip(claim.category),
                          const SizedBox(width: 8),
                          _buildStatusChip(claim.status),
                          const Spacer(),
                          Text(
                            _formatDate(claim.submittedAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        claim.title.original,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        claim.body.original,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 14, color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                claim.locationId,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.attach_file,
                                  size: 14, color: theme.colorScheme.outline),
                              const SizedBox(width: 4),
                              Text(
                                '${claim.evidenceCount} evidence items',
                                style: theme.textTheme.labelSmall,
                              ),
                            ],
                          ),
                          if (claim.sourceAttribution != null &&
                              claim.sourceAttribution!.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.source_outlined,
                                    size: 14, color: theme.colorScheme.outline),
                                const SizedBox(width: 4),
                                Text(
                                  'Source: ${claim.sourceAttribution}',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ClaimDetailPage(
                                    claim: claim,
                                    communityService: widget.communityService,
                                    authService: widget.authService,
                                  ),
                                ),
                              ).then((_) => widget.communityService.fetchReviewQueue());
                            },
                            icon: const Icon(Icons.visibility_outlined, size: 16),
                            label: const Text('View Detail'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _showReviewDialog(claim),
                            icon: const Icon(Icons.rate_review, size: 16),
                            label: const Text('Review Decision'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        category.replaceAll('_', ' '),
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'submitted':
        color = Colors.blue;
        break;
      case 'under_review':
        color = Colors.amber.shade800;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
