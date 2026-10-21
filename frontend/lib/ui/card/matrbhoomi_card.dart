import 'package:flutter/material.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../models/claim.dart';
import '../../services/community_service.dart';

/// Reusable MatrbhoomiCard widget for historical records and community feedback.
/// Displays an approved historical record with author attribution and provides
/// the 4 optional community feedback responses for validation and corroboration.
class MatrbhoomiCard extends StatefulWidget {
  final Claim claim;
  final CommunityService communityService;
  final String? currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onFeedbackSubmitted;

  const MatrbhoomiCard({
    super.key,
    required this.claim,
    required this.communityService,
    this.currentUserId,
    this.onTap,
    this.onFeedbackSubmitted,
  });

  @override
  State<MatrbhoomiCard> createState() => _MatrbhoomiCardState();
}

class _MatrbhoomiCardState extends State<MatrbhoomiCard> {
  bool _isExpanded = false;
  bool _isSubmitting = false;
  bool _hasSubmittedLocally = false;

  String? _selectedKnown;
  String? _selectedAgreement;
  String? _selectedAuthorRelation;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  bool get _hasUserFeedback {
    if (_hasSubmittedLocally) return true;
    if (widget.currentUserId == null) return false;
    return widget.claim.communityFeedbacks.any(
      (f) => f.userId == widget.currentUserId,
    );
  }

  Future<void> _submitFeedback() async {
    final l10n = AppLocalizations.of(context)!;

    if (_selectedKnown == null &&
        _selectedAgreement == null &&
        _selectedAuthorRelation == null &&
        _commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one response before submitting.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await widget.communityService.submitHistoryFeedback(
      claimId: widget.claim.id,
      previouslyKnown: _selectedKnown,
      agreement: _selectedAgreement,
      comment: _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
      knowsAuthor: _selectedAuthorRelation,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      setState(() {
        _hasSubmittedLocally = true;
        _isExpanded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.matrbhoomiFeedbackSuccess),
          backgroundColor: Colors.green,
        ),
      );
      widget.onFeedbackSubmitted?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.communityService.errorMessage ?? 'Failed to submit feedback.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isVerified = widget.claim.isVerified;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isVerified
              ? Colors.green.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Category & Verified Badges
              Row(
                children: [
                  _CategoryChip(category: widget.claim.category),
                  const SizedBox(width: 8),
                  _StatusChip(status: widget.claim.status),
                  const Spacer(),
                  if (widget.claim.isFolklore)
                    Tooltip(
                      message: l10n.folkloreNote,
                      child: const Icon(Icons.auto_stories, size: 18, color: Colors.purple),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. Title & Body
              Text(
                widget.claim.title.original,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                widget.claim.body.original,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // 3. Attribution & Period Metadata
              if (widget.claim.sourceAttribution != null || widget.claim.timePeriod != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history_edu, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${widget.claim.timePeriod != null ? "[${widget.claim.timePeriod}] " : ""}${widget.claim.sourceAttribution ?? "Recorded by community contributor"}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // 4. Evidence count and submission date
              Row(
                children: [
                  Icon(Icons.attach_file, size: 14, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text('${widget.claim.evidenceCount} evidence', style: theme.textTheme.labelSmall),
                  if (widget.claim.communityFeedbacks.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.comment_outlined, size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.claim.communityFeedbacks.length} feedback',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    _formatDate(widget.claim.submittedAt),
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // 5. Community Corroboration / Feedback Section
              if (_hasUserFeedback) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.matrbhoomiFeedbackRecorded,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                InkWell(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(Icons.rate_review_outlined, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.matrbhoomiFeedbackPrompt,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),

                if (_isExpanded) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Feedback Question 1: Known before
                        Text(
                          l10n.matrbhoomiFeedbackQ1,
                          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text(l10n.matrbhoomiFeedbackQ1Yes),
                              selected: _selectedKnown == 'yes',
                              onSelected: (s) => setState(() => _selectedKnown = s ? 'yes' : null),
                            ),
                            ChoiceChip(
                              label: Text(l10n.matrbhoomiFeedbackQ1No),
                              selected: _selectedKnown == 'no',
                              onSelected: (s) => setState(() => _selectedKnown = s ? 'no' : null),
                            ),
                            ChoiceChip(
                              label: Text(l10n.matrbhoomiFeedbackQ1Partial),
                              selected: _selectedKnown == 'partial',
                              onSelected: (s) => setState(() => _selectedKnown = s ? 'partial' : null),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Feedback Question 2: Agreement
                        Text(
                          l10n.matrbhoomiFeedbackQ2,
                          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            ChoiceChip(
                              label: Text(l10n.matrbhoomiFeedbackQ2Agree),
                              selected: _selectedAgreement == 'agree',
                              onSelected: (s) => setState(() => _selectedAgreement = s ? 'agree' : null),
                            ),
                            ChoiceChip(
                              label: Text(l10n.matrbhoomiFeedbackQ2Disagree),
                              selected: _selectedAgreement == 'disagree',
                              onSelected: (s) => setState(() => _selectedAgreement = s ? 'disagree' : null),
                            ),
                            ChoiceChip(
                              label: Text(l10n.matrbhoomiFeedbackQ2NeedEvidence),
                              selected: _selectedAgreement == 'need_evidence',
                              onSelected: (s) => setState(() => _selectedAgreement = s ? 'need_evidence' : null),
                            ),
                            ChoiceChip(
                              label: Text(l10n.matrbhoomiFeedbackQ2NotSure),
                              selected: _selectedAgreement == 'not_sure',
                              onSelected: (s) => setState(() => _selectedAgreement = s ? 'not_sure' : null),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Feedback Question 3: Optional comment
                        Text(
                          l10n.matrbhoomiFeedbackQ3,
                          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _commentController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: l10n.matrbhoomiFeedbackQ3Hint,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Feedback Question 4: Know Author
                        Text(
                          l10n.matrbhoomiFeedbackQ4,
                          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            ChoiceChip(
                              label: Text(l10n.matrbhoomiFeedbackQ4Personally),
                              selected: _selectedAuthorRelation == 'personally',
                              onSelected: (s) => setState(() => _selectedAuthorRelation = s ? 'personally' : null),
                            ),
                            ChoiceChip(
                              label: Text(l10n.matrbhoomiFeedbackQ4ByName),
                              selected: _selectedAuthorRelation == 'by_name',
                              onSelected: (s) => setState(() => _selectedAuthorRelation = s ? 'by_name' : null),
                            ),
                            ChoiceChip(
                              label: Text(l10n.matrbhoomiFeedbackQ4NotKnown),
                              selected: _selectedAuthorRelation == 'not_known',
                              onSelected: (s) => setState(() => _selectedAuthorRelation = s ? 'not_known' : null),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isSubmitting ? null : _submitFeedback,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.send, size: 16),
                            label: Text(l10n.matrbhoomiFeedbackSubmit),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(_label, style: const TextStyle(fontSize: 10)),
      backgroundColor: _color.withValues(alpha: 0.15),
      side: BorderSide(color: _color, width: 0.5),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      visualDensity: VisualDensity.compact,
    );
  }

  String get _label => switch (category) {
        'HISTORICAL_RECORD' => 'History',
        'CURRENT_FACT' => 'Fact',
        'FOLKLORE' => 'Folklore',
        'PERSONAL_EXPERIENCE' => 'Experience',
        'PUBLIC_OPINION' => 'Opinion',
        'SURVEY_DATA' => 'Survey',
        'DISPUTED_CLAIM' => 'Disputed',
        _ => category,
      };

  Color get _color => switch (category) {
        'HISTORICAL_RECORD' => Colors.brown,
        'CURRENT_FACT' => Colors.blue,
        'FOLKLORE' => Colors.purple,
        'PERSONAL_EXPERIENCE' => Colors.teal,
        'PUBLIC_OPINION' => Colors.orange,
        'SURVEY_DATA' => Colors.indigo,
        'DISPUTED_CLAIM' => Colors.red,
        _ => Colors.grey,
      };
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _color, width: 0.5),
      ),
      child: Text(
        _label,
        style: TextStyle(fontSize: 10, color: _color, fontWeight: FontWeight.w600),
      ),
    );
  }

  String get _label => switch (status) {
        'draft' => 'Draft',
        'submitted' => 'Submitted',
        'under_review' => 'In Review',
        'verified' => 'Verified Fact',
        'partially_verified' => 'Partial',
        'unverified' => 'Unverified',
        'disputed' => 'Disputed',
        'insufficient_evidence' => 'Insufficient',
        'rejected' => 'Rejected',
        'archived' => 'Archived',
        _ => status,
      };

  Color get _color => switch (status) {
        'verified' => Colors.green,
        'partially_verified' => Colors.lightGreen,
        'unverified' => Colors.orange,
        'disputed' => Colors.red,
        'rejected' => Colors.red.shade900,
        'insufficient_evidence' => Colors.deepOrange,
        'archived' => Colors.grey,
        _ => Colors.blueGrey,
      };
}
