import 'package:flutter/material.dart';
import '../../../models/claim.dart';
import '../../../models/evidence.dart';
import '../../../services/auth_service.dart';
import '../../../services/community_service.dart';
import '../../card/evidence_card.dart';

class ClaimDetailPage extends StatefulWidget {
  final Claim claim;
  final CommunityService communityService;
  final String? placeName;
  final AuthService? authService;

  const ClaimDetailPage({
    super.key,
    required this.claim,
    required this.communityService,
    this.placeName,
    this.authService,
  });

  @override
  State<ClaimDetailPage> createState() => _ClaimDetailPageState();
}

class _ClaimDetailPageState extends State<ClaimDetailPage> {
  late Claim _currentClaim;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _currentClaim = widget.claim;
    _refreshDetail();
  }

  Future<void> _refreshDetail() async {
    final updated = await widget.communityService.fetchClaimDetail(widget.claim.id);
    await widget.communityService.fetchEvidenceForClaim(widget.claim.id);
    if (updated != null && mounted) {
      setState(() {
        _currentClaim = updated;
      });
    }
  }

  String? get _currentUserId => widget.authService?.currentUser?.id;

  bool get _isReviewer {
    final user = widget.authService?.currentUser;
    return user != null && user.isReviewer;
  }

  bool get _isOwner {
    final user = widget.authService?.currentUser;
    if (user == null) return false;
    if (_currentClaim.submittedBy != null && _currentClaim.submittedBy == user.id) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Story Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshDetail,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Status and Category Badges
              Row(
                children: [
                  _buildCategoryChip(_currentClaim.category),
                  const SizedBox(width: 8),
                  _buildStatusChip(_currentClaim.status),
                  const Spacer(),
                  if (_currentClaim.isFolklore)
                    const Tooltip(
                      message: 'Folklore — not independently verified as historical fact',
                      child: Icon(Icons.auto_stories, size: 20, color: Colors.purple),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // 2. Information Class Integrity Banners
              if (_currentClaim.isFolklore)
                _buildInfoBanner(
                  icon: Icons.auto_stories,
                  title: 'Folklore & Oral Tradition',
                  message:
                      'This record preserves local oral lore, proverbs, or legendary traditions. It represents community cultural heritage and is not treated as verified historical fact.',
                  color: Colors.purple,
                )
              else if (_currentClaim.isOpinion)
                _buildInfoBanner(
                  icon: Icons.groups,
                  title: 'Public Opinion / Community Perspective',
                  message:
                      'This entry reflects personal perspectives and subjective community viewpoints, not independently verified factual data.',
                  color: Colors.orange,
                )
              else if (_currentClaim.isHistorical)
                _buildInfoBanner(
                  icon: Icons.history_edu,
                  title: 'Historical Fact Candidate',
                  message:
                      'This record is assessed under historical evidence standards and requires corroborating source documentation for full verification.',
                  color: Colors.brown,
                ),

              const SizedBox(height: 16),

              // 3. Title
              Text(
                _currentClaim.title.original,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // 4. Place Association & Attribution Metadata
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    if (widget.placeName != null || _currentClaim.locationId.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.placeName ?? 'Place ID: ${_currentClaim.locationId}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.account_circle, size: 16, color: theme.colorScheme.outline),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _currentClaim.sourceAttribution != null && _currentClaim.sourceAttribution!.isNotEmpty
                                ? 'Attribution: ${_currentClaim.sourceAttribution}'
                                : 'Contributor: Community Contributor',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                        if (_currentClaim.timePeriod != null && _currentClaim.timePeriod!.isNotEmpty) ...[
                          Icon(Icons.calendar_today, size: 14, color: theme.colorScheme.outline),
                          const SizedBox(width: 4),
                          Text(
                            _currentClaim.timePeriod!,
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 5. Living Person Consent Gate
              if (_currentClaim.consentObtained || _currentClaim.consentState != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_currentClaim.consentState == 'consent_verified' ? Colors.teal : Colors.amber.shade900)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _currentClaim.consentState == 'consent_verified' ? Colors.teal : Colors.amber.shade700,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _currentClaim.consentState == 'consent_verified'
                            ? Icons.verified_user
                            : Icons.hourglass_top,
                        color: _currentClaim.consentState == 'consent_verified' ? Colors.teal : Colors.amber.shade900,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentClaim.consentState == 'consent_verified'
                                  ? 'Consent Verified (Living Person)'
                                  : 'Consent Pending Verification',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _currentClaim.consentState == 'consent_verified'
                                    ? Colors.teal
                                    : Colors.amber.shade900,
                              ),
                            ),
                            if (_currentClaim.consentDetails != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _currentClaim.consentDetails!,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 6. Main Body Content
              Text(
                'Story & Knowledge Content',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Text(
                  _currentClaim.body.original,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ),

              const SizedBox(height: 20),

              // 6b. Corroborating Evidence Management Section
              ListenableBuilder(
                listenable: widget.communityService,
                builder: (context, _) {
                  final evidenceList = widget.communityService.evidenceList;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Corroborating Evidence (${evidenceList.length})',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _showAddEvidenceDialog,
                            icon: const Icon(Icons.add_circle_outline, size: 16),
                            label: const Text('Attach Evidence'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Primary source records, documents, URLs, and archives submitted to corroborate this claim. Attaching or verifying evidence does not automatically verify the claim.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (evidenceList.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.folder_open, size: 36, color: theme.colorScheme.outline),
                              const SizedBox(height: 8),
                              Text(
                                'No Corroborating Evidence Attached',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Help verify this community story by attaching primary documentary references or archival links.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                              ),
                            ],
                          ),
                        )
                      else
                        ...evidenceList.map((ev) {
                          final isUploader = _currentUserId != null && ev.uploadedBy == _currentUserId;
                          final canReview = _isReviewer && !isUploader;
                          return EvidenceCard(
                            evidence: ev,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            canReview: canReview,
                            onReview: () => _showReviewEvidenceDialog(ev),
                          );
                        }),
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              // 7. Latest Review Verdict Section
              if (_currentClaim.latestReview != null) ...[
                Text(
                  'Independent Reviewer Verdict',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _statusColor(_currentClaim.latestReview!.decisionStatus).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _statusColor(_currentClaim.latestReview!.decisionStatus),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildStatusChip(_currentClaim.latestReview!.decisionStatus),
                          const Spacer(),
                          Text(
                            _formatDate(_currentClaim.latestReview!.timestamp),
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Reason for Verdict:',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentClaim.latestReview!.reason,
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (_currentClaim.latestReview!.reviewerNote != null &&
                          _currentClaim.latestReview!.reviewerNote!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Reviewer Comments: ${_currentClaim.latestReview!.reviewerNote}',
                          style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 8. Interactive Actions (Reviewer, Owner, Community)
              if (_isReviewer) ...[
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _showReviewDialog,
                  icon: const Icon(Icons.rate_review),
                  label: const Text('Review & Decide Claim (Reviewer Gate)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (_currentClaim.isDraft && _isOwner) ...[
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submitDraft,
                  icon: const Icon(Icons.send),
                  label: const Text('Submit Draft for Public Review'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              OutlinedButton.icon(
                onPressed: _showCorrectionDialog,
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('Request Correction or Removal'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitDraft() async {
    setState(() => _isSubmitting = true);
    final success = await widget.communityService.submitDraftForReview(_currentClaim.id);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft submitted successfully for independent review.')),
      );
      _refreshDetail();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.communityService.errorMessage ?? 'Submission failed.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showReviewDialog() {
    String selectedDecision = 'verified';
    if (_currentClaim.isFolklore || _currentClaim.isOpinion) {
      selectedDecision = 'partially_verified';
    }
    final reasonController = TextEditingController();
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isFolkloreOrOpinion = _currentClaim.isFolklore || _currentClaim.isOpinion;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review Claim — ${_currentClaim.title.original}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (isFolkloreOrOpinion)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.shade700),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.deepOrange, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'RULE: Folklore and Public Opinion cannot be marked as verified historical fact.',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Text('Decision Verdict:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDecision,
                      items: [
                        if (!isFolkloreOrOpinion)
                          const DropdownMenuItem(value: 'verified', child: Text('Verified (Factual Corroboration)')),
                        const DropdownMenuItem(value: 'partially_verified', child: Text('Partially Verified')),
                        const DropdownMenuItem(value: 'unverified', child: Text('Unverified')),
                        const DropdownMenuItem(value: 'disputed', child: Text('Disputed')),
                        const DropdownMenuItem(value: 'insufficient_evidence', child: Text('Insufficient Evidence')),
                        const DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedDecision = val);
                        }
                      },
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    const Text('Reason for Decision (minimum 20 characters):',
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
                    const Text('Reviewer Comments (Optional):', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      onPressed: () async {
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
                        setState(() => _isSubmitting = true);
                        final success = await widget.communityService.reviewClaim(
                          claimId: _currentClaim.id,
                          decisionStatus: selectedDecision,
                          reason: reason,
                          reviewerNote: noteController.text.trim(),
                        );
                        if (!mounted) return;
                        setState(() => _isSubmitting = false);

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Review verdict recorded successfully.')),
                          );
                          _refreshDetail();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(widget.communityService.errorMessage ?? 'Review failed.'),
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

  void _showCorrectionDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Request Correction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If this story contains inaccurate dates, unverified accounts, or restricted information, submit a correction request for independent review:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Provide details on the correction needed...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reason must be at least 10 characters.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.of(dialogCtx).pop();
              final success = await widget.communityService.submitCorrectionRequest(_currentClaim.id, reason);
              if (!mounted) return;

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Correction request submitted for review.')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to submit correction request.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  void _showAddEvidenceDialog() {
    String selectedSourceType = 'DOCUMENT';
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final docRefController = TextEditingController();
    final urlController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (bottomCtx, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(bottomCtx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.note_add_outlined),
                        const SizedBox(width: 8),
                        const Text(
                          'Attach Corroborating Evidence',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(bottomCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Provide documentary references, archives, links, or field notes that support this story. Attaching evidence does not automatically mark the claim verified.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    const Text('Source Type *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSourceType,
                      items: const [
                        DropdownMenuItem(value: 'DOCUMENT', child: Text('Historical Document / Manuscript')),
                        DropdownMenuItem(value: 'GOVERNMENT_RECORD', child: Text('Government Record / Gazette')),
                        DropdownMenuItem(value: 'ACADEMIC_PAPER', child: Text('Academic Paper / Publication')),
                        DropdownMenuItem(value: 'NEWS_ARTICLE', child: Text('News Article / Report')),
                        DropdownMenuItem(value: 'PHOTOGRAPH', child: Text('Photograph / Inscription')),
                        DropdownMenuItem(value: 'ORAL_TESTIMONY', child: Text('Oral Testimony / Interview')),
                        DropdownMenuItem(value: 'URL', child: Text('Public Web Link / Archive Reference')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Other Primary Source')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedSourceType = val);
                      },
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    const Text('Title / Source Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'e.g. 1923 Land Revenue Settlement Record',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Description & Context * (min 10 chars)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Describe how this source corroborates specific facts in the story...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Document Reference / Archive ID (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: docRefController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'e.g. Vol IV, Folio 42, State Archives',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Web Link / URL (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: urlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'https://...',
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final desc = descriptionController.text.trim();
                        final docRef = docRefController.text.trim();
                        final url = urlController.text.trim();

                        if (title.length < 3) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Title must be at least 3 characters.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (desc.length < 10) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Description must be at least 10 characters.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        Navigator.of(bottomCtx).pop();
                        final evidence = await widget.communityService.submitEvidence(
                          claimId: _currentClaim.id,
                          sourceType: selectedSourceType,
                          title: title,
                          description: desc,
                          documentRef: docRef.isNotEmpty ? docRef : null,
                          url: url.isNotEmpty ? url : null,
                        );

                        if (!mounted) return;
                        if (evidence != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Evidence attached successfully. Pending independent reviewer verification.'),
                            ),
                          );
                          _refreshDetail();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(widget.communityService.errorMessage ?? 'Failed to attach evidence.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: const Text('Attach Evidence'),
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

  void _showReviewEvidenceDialog(Evidence evidence) {
    String decision = 'verified';
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (bottomCtx, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(bottomCtx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Review Evidence: ${evidence.title}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(bottomCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.blue),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Independent Review Gate: Reviewing this evidence item does not automatically mark the claim as verified.',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Decision Verdict *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: decision,
                      items: const [
                        DropdownMenuItem(value: 'verified', child: Text('Verified (Source Validated)')),
                        DropdownMenuItem(value: 'disputed', child: Text('Disputed (Authenticity Questioned)')),
                        DropdownMenuItem(value: 'rejected', child: Text('Rejected (Inapplicable or Inaccurate)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => decision = val);
                      },
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    const Text('Review Notes * (min 10 characters)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Document verification methodology or reason for dispute...',
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () async {
                        final notes = notesController.text.trim();
                        if (notes.length < 10) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Review notes must be at least 10 characters.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        Navigator.of(bottomCtx).pop();
                        final success = await widget.communityService.reviewEvidence(
                          evidenceId: evidence.id,
                          decision: decision,
                          reviewNotes: notes,
                        );

                        if (!mounted) return;
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Evidence reviewed as $decision.'),
                            ),
                          );
                          _refreshDetail();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(widget.communityService.errorMessage ?? 'Failed to review evidence.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: const Text('Submit Evidence Verdict'),
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

  Widget _buildInfoBanner({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    final color = _categoryColor(category);
    return Chip(
      label: Text(_categoryLabel(category), style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color, width: 0.5),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _categoryLabel(String category) => switch (category) {
        'HISTORICAL_RECORD' => 'Historical Record',
        'CURRENT_FACT' => 'Current Fact',
        'FOLKLORE' => 'Folklore / Tradition',
        'PERSONAL_EXPERIENCE' => 'Personal Experience',
        'PUBLIC_OPINION' => 'Public Opinion',
        'SURVEY_DATA' => 'Survey Data',
        'DISPUTED_CLAIM' => 'Disputed Claim',
        _ => category,
      };

  Color _categoryColor(String category) => switch (category) {
        'HISTORICAL_RECORD' => Colors.brown,
        'CURRENT_FACT' => Colors.blue,
        'FOLKLORE' => Colors.purple,
        'PERSONAL_EXPERIENCE' => Colors.teal,
        'PUBLIC_OPINION' => Colors.orange,
        'SURVEY_DATA' => Colors.indigo,
        'DISPUTED_CLAIM' => Colors.red,
        _ => Colors.grey,
      };

  String _statusLabel(String status) => switch (status) {
        'draft' => 'Draft',
        'submitted' => 'Submitted for Review',
        'under_review' => 'Under Review',
        'verified' => 'Verified Fact',
        'partially_verified' => 'Partially Verified',
        'unverified' => 'Unverified',
        'disputed' => 'Disputed',
        'insufficient_evidence' => 'Insufficient Evidence',
        'rejected' => 'Rejected',
        'archived' => 'Archived',
        _ => status,
      };

  Color _statusColor(String status) => switch (status) {
        'verified' => Colors.green,
        'partially_verified' => Colors.lightGreen.shade700,
        'unverified' => Colors.orange,
        'disputed' => Colors.red,
        'rejected' => Colors.red.shade900,
        'insufficient_evidence' => Colors.deepOrange,
        'archived' => Colors.grey,
        _ => Colors.blueGrey,
      };
}
