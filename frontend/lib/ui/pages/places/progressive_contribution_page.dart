import 'package:flutter/material.dart';
import '../../../models/claim.dart';
import '../../../services/community_service.dart';

class ProgressiveContributionPage extends StatefulWidget {
  final String placeId;
  final String placeName;
  final CommunityService communityService;
  final Claim? existingDraft;
  final Claim? targetClaim; // Set when responding to an existing description
  final String? initialTopic;
  final VoidCallback? onBackToHome;

  const ProgressiveContributionPage({
    super.key,
    required this.placeId,
    required this.placeName,
    required this.communityService,
    this.existingDraft,
    this.targetClaim,
    this.initialTopic,
    this.onBackToHome,
  });

  @override
  State<ProgressiveContributionPage> createState() => _ProgressiveContributionPageState();
}

class _ProgressiveContributionPageState extends State<ProgressiveContributionPage> {
  int _currentSectionIndex = 0;
  String? _selectedChoice;
  bool _consentChecked = false;
  String? _activeDraftId;
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _periodController = TextEditingController();
  final TextEditingController _consentDetailsController = TextEditingController();

  bool get isResponding => widget.targetClaim != null;

  @override
  void initState() {
    super.initState();
    if (widget.targetClaim != null) {
      _selectedChoice = 'agreed';
      if (widget.targetClaim!.communityTopic != null) {
        final idx = _sections.indexWhere((s) => s['topic'] == widget.targetClaim!.communityTopic);
        if (idx != -1) {
          _currentSectionIndex = idx;
        }
      }
    }
    if (widget.existingDraft != null) {
      _activeDraftId = widget.existingDraft!.id;
      _answerController.text = widget.existingDraft!.body.original;
      _selectedChoice = widget.existingDraft!.userAgreementStatus;
      _sourceController.text = widget.existingDraft!.sourceAttribution ?? '';
      _periodController.text = widget.existingDraft!.timePeriod ?? '';
      _consentChecked = widget.existingDraft!.consentObtained;
      _consentDetailsController.text = widget.existingDraft!.consentDetails ?? '';

      // Determine matching section if topic matches
      if (widget.existingDraft!.communityTopic != null) {
        final idx = _sections.indexWhere((s) => s['topic'] == widget.existingDraft!.communityTopic);
        if (idx != -1) {
          _currentSectionIndex = idx;
        }
      }
    } else if (widget.initialTopic != null && widget.targetClaim == null) {
      final idx = _sections.indexWhere((s) => s['topic'] == widget.initialTopic);
      if (idx != -1) {
        _currentSectionIndex = idx;
      }
    }
  }

  final List<Map<String, dynamic>> _sections = [
    {
      'topic': 'identity',
      'title': '1. Our Place, Our Identity',
      'subtitle': 'Place introduction, historical naming, and community identity',
      'question': 'What is the local naming origin or traditional identity of this place?',
      'existingHint': 'Known historically as a community hub with rich agricultural roots.',
      'requiresConsent': false,
    },
    {
      'topic': 'history',
      'title': '2. Our History and Heritage',
      'subtitle': 'Founding stories, historical events, elders memories',
      'question': 'What are the founding stories or memorable historical events of this place?',
      'existingHint': 'Elders speak of founding during the 18th century near the riverbed.',
      'requiresConsent': false,
    },
    {
      'topic': 'culture',
      'title': '3. Culture and Traditions',
      'subtitle': 'Folklore, oral history, proverbs, local festivals and songs',
      'question': 'What local folktales, oral traditions, or annual community festivals are celebrated?',
      'existingHint': 'Annual harvest festival celebrated with traditional music and proverbs.',
      'requiresConsent': false,
    },
    {
      'topic': 'biography',
      'title': '4. People and Life Stories',
      'subtitle': 'Inspiring biographies and community contributions (Requires Consent)',
      'question': 'Who are the respected local figures whose life stories inspire the community?',
      'existingHint': 'Local teachers and community leaders who built the first public school.',
      'requiresConsent': true,
    },
    {
      'topic': 'facilities',
      'title': '5. Development and Facilities',
      'subtitle': 'Schools, roads, water, healthcare, public facilities and problems',
      'question': 'What are the main public facilities, development achievements, or pressing issues?',
      'existingHint': 'Primary health centre established in 2015; road connectivity upgraded in 2021.',
      'requiresConsent': false,
    },
    {
      'topic': 'leadership',
      'title': '6. Local Information & Administration',
      'subtitle': 'Population estimates, wards, elected representatives, sarpanch/mukhiya',
      'question': 'Who is the current village head / sarpanch / mukhiya and what is the estimated population?',
      'existingHint': 'Estimated population ~3,500 across 4 wards.',
      'requiresConsent': false,
    },
    {
      'topic': 'opinion',
      'title': '7. Community Opinions & Suggestions',
      'subtitle': 'Local beliefs, suggestions, and perspectives (Separated from facts)',
      'question': 'What are the community wishes, opinions, or suggestions for future development?',
      'existingHint': 'Residents suggest constructing a community library and solar street lights.',
      'requiresConsent': false,
    },
  ];

  @override
  void dispose() {
    _answerController.dispose();
    _sourceController.dispose();
    _periodController.dispose();
    _consentDetailsController.dispose();
    super.dispose();
  }

  void _resetInput() {
    _selectedChoice = null;
    _consentChecked = false;
    _answerController.clear();
    _sourceController.clear();
    _periodController.clear();
    _consentDetailsController.clear();
  }

  Future<void> _submitCurrent(bool submitForReview) async {
    final section = _sections[_currentSectionIndex];
    final isRespondingMode = isResponding;
    final choice = isRespondingMode ? (_selectedChoice ?? 'agreed') : null;

    if (choice != 'dont_know') {
      final text = _answerController.text.trim();
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isRespondingMode
                  ? 'Please enter your response or choose "I do not know"'
                  : 'Please enter your contribution description',
            ),
          ),
        );
        return;
      }
      if (text.length < 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide more detail (at least 10 characters required)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (section['requiresConsent'] == true && !_consentChecked && choice != 'dont_know') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Privacy Safeguard: Consent confirmation is required for living person biographies'),
        ),
      );
      return;
    }

    final questionText = isRespondingMode && widget.targetClaim != null
        ? 'Response to: ${widget.targetClaim!.title.original}'
        : (section['question'] as String);

    final saved = await widget.communityService.saveProgressiveAnswer(
      locationId: widget.placeId,
      topic: section['topic'] as String,
      question: questionText,
      answer: choice == 'dont_know'
          ? 'I want to learn more about this topic.'
          : _answerController.text.trim(),
      userChoice: choice,
      source: _sourceController.text.trim().isNotEmpty ? _sourceController.text.trim() : null,
      period: _periodController.text.trim().isNotEmpty ? _periodController.text.trim() : null,
      consent: _consentChecked,
      consentNotes: _consentDetailsController.text.trim().isNotEmpty
          ? _consentDetailsController.text.trim()
          : null,
      existingDraftId: _activeDraftId,
    );

    if (saved == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.communityService.errorMessage ?? 'Failed to save contribution. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _activeDraftId = saved.id;

    if (submitForReview) {
      final submitSuccess = await widget.communityService.submitDraftForReview(saved.id);
      if (!mounted) return;
      if (!submitSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.communityService.errorMessage ??
                  'Saved as draft, but could not submit for review.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          submitForReview
              ? 'Contribution submitted for review!'
              : 'Saved as draft. You can resume anytime.',
        ),
        backgroundColor: Colors.green,
      ),
    );

    if (_currentSectionIndex < _sections.length - 1) {
      setState(() {
        _currentSectionIndex++;
        _resetInput();
      });
    } else {
      if (!mounted) return;
      _closeOrReturn();
    }
  }

  void _closeOrReturn() {
    if (widget.onBackToHome != null) {
      widget.onBackToHome!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final section = _sections[_currentSectionIndex];
    final isConsentRequired = section['requiresConsent'] == true;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBackToHome != null
            ? IconButton(
                key: const Key('return_to_home_button'),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Location',
                onPressed: widget.onBackToHome,
              )
            : null,
        title: Text(widget.onBackToHome != null ? 'Contribute' : 'Contribute: ${widget.placeName}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: (_currentSectionIndex + 1) / _sections.length,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Section ${_currentSectionIndex + 1} of ${_sections.length}',
                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 4),
              Text(
                section['title'] as String,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                section['subtitle'] as String,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 16),

              // Responding vs Fresh Writing separation
              if (isResponding) ...[
                // Existing knowledge card (Context from existing claim)
                Card(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Existing Community Record',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.targetClaim!.title.original,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.targetClaim!.body.original,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Question
                Text(
                  'How would you like to respond?',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      key: const Key('chip_response_agree'),
                      label: const Text('Agree & Expand'),
                      selected: _selectedChoice == 'agreed' || _selectedChoice == null,
                      onSelected: (val) {
                        setState(() => _selectedChoice = 'agreed');
                      },
                    ),
                    ChoiceChip(
                      key: const Key('chip_response_correction'),
                      label: const Text('Suggest Correction'),
                      selected: _selectedChoice == 'correction',
                      onSelected: (val) {
                        setState(() => _selectedChoice = 'correction');
                      },
                    ),
                    ChoiceChip(
                      key: const Key('chip_response_different_account'),
                      label: const Text('Different Account'),
                      selected: _selectedChoice == 'different_account',
                      onSelected: (val) {
                        setState(() => _selectedChoice = 'different_account');
                      },
                    ),
                    ChoiceChip(
                      key: const Key('chip_response_dont_know'),
                      label: const Text('I do not know / Want to learn'),
                      selected: _selectedChoice == 'dont_know',
                      onSelected: (val) {
                        setState(() => _selectedChoice = 'dont_know');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ] else ...[
                // Fresh Writing: Guiding topic question directly without response prompts/chips
                Text(
                  section['question'] as String,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
              ],

              if (!isResponding || _selectedChoice != 'dont_know') ...[
                // Response Input
                TextField(
                  key: const Key('contribution_answer_field'),
                  controller: _answerController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: isResponding
                        ? (_selectedChoice == 'correction' ? 'Suggested Correction' : 'Your Response / Account')
                        : 'Your Knowledge / Information',
                    hintText: isResponding
                        ? 'Share your perspective, correction, or expansion...'
                        : 'Share stories, memories, or factual details...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Source Attribution & Date/Time Traceability (Rule 8)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _sourceController,
                        decoration: InputDecoration(
                          labelText: 'Source (e.g., Elder memory, Gram Panchayat record)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _periodController,
                        decoration: InputDecoration(
                          labelText: 'Time Period / Year (e.g. 1970s, 2024)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Privacy & Consent Safeguards (Rule 6)
                if (isConsentRequired) ...[
                  Material(
                    color: Colors.amber.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.amber.shade400),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.privacy_tip, color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Consent & Privacy Requirement',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Publishing living people biographies requires explicit consent. Private contact details and unverified family trees are strictly forbidden.',
                            style: TextStyle(fontSize: 12),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'I confirm I have obtained explicit consent from the person or their authorized representative.',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: _consentChecked,
                            onChanged: (val) {
                              setState(() => _consentChecked = val ?? false);
                            },
                          ),
                          TextField(
                            controller: _consentDetailsController,
                            decoration: const InputDecoration(
                              labelText: 'Consent Scope / Verification Reference',
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],

              const SizedBox(height: 24),

              // Action Buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      if (_currentSectionIndex < _sections.length - 1) {
                        setState(() {
                          _currentSectionIndex++;
                          _resetInput();
                        });
                      } else {
                        _closeOrReturn();
                      }
                    },
                    child: const Text('Skip / Return Later'),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: widget.communityService.isLoading ? null : () => _submitCurrent(false),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save Draft'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: widget.communityService.isLoading ? null : () => _submitCurrent(true),
                        icon: const Icon(Icons.send),
                        label: const Text('Submit for Review'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
