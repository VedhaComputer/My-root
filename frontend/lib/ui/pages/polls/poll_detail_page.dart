import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants.dart';
import '../../../core/network/api_client.dart';
import '../../../models/poll.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/poll_repository.dart';
import '../../../services/auth_service.dart';
import '../../../services/poll_service.dart';

class PollDetailPage extends StatefulWidget {
  final String pollId;
  final Poll? initialPoll;
  final PollService? pollService;
  final AuthService? authService;

  const PollDetailPage({
    super.key,
    required this.pollId,
    this.initialPoll,
    this.pollService,
    this.authService,
  });

  @override
  State<PollDetailPage> createState() => _PollDetailPageState();
}

class _PollDetailPageState extends State<PollDetailPage> {
  late final PollService _pollService;
  Poll? _poll;
  bool _isLoading = false;
  String? _errorMessage;
  int _breakdownTab = 0; // 0 = Like reasons, 1 = Dislike reasons
  Timer? _autoRefreshTimer;
  bool _isRefreshing = false;
  int _fetchGeneration = 0;

  @override
  void initState() {
    super.initState();
    final client = (widget.authService?.repository is AuthRepositoryImpl)
        ? (widget.authService!.repository as AuthRepositoryImpl).client
        : ApiClient();
    if (widget.authService?.tokens?.accessToken != null &&
        widget.authService!.tokens!.accessToken.isNotEmpty) {
      client.setAccessToken(widget.authService!.tokens!.accessToken);
    }
    _pollService = widget.pollService ??
        PollService(repository: PollRepositoryImpl(client: client));
    _poll = widget.initialPoll;
    _loadPoll();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && _poll != null && _poll!.isActive) {
        _silentRefresh();
      } else if (_poll != null && !_poll!.isActive) {
        _autoRefreshTimer?.cancel();
      }
    });
  }

  Future<void> _silentRefresh() async {
    if (!mounted || _isRefreshing || (_poll != null && !_poll!.isActive)) return;
    _isRefreshing = true;
    final gen = ++_fetchGeneration;

    try {
      final poll = await _pollService.fetchPollById(widget.pollId);
      if (mounted && gen == _fetchGeneration && poll != null) {
        setState(() {
          _poll = poll;
          if (!poll.isActive) {
            _autoRefreshTimer?.cancel();
          }
        });
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _loadPoll() async {
    final gen = ++_fetchGeneration;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final poll = await _pollService.fetchPollById(widget.pollId);
    if (!mounted || gen != _fetchGeneration) return;

    setState(() {
      _isLoading = false;
      if (poll != null) {
        _poll = poll;
        if (!poll.isActive) {
          _autoRefreshTimer?.cancel();
        }
      } else {
        _errorMessage = _pollService.errorMessage ?? 'Failed to load poll';
      }
    });
  }

  void _sharePoll() {
    if (_poll == null) return;
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final shareUrl = '${AppConstants.shareBaseUrl}/polls/${_poll!.id}';
    final textToShare = isHindi
        ? 'जनमत सर्वेक्षण: ${_poll!.question}\nअपना मत दर्ज करें और लाइव परिणाम देखें: $shareUrl'
        : 'Live Public Opinion Poll: ${_poll!.question}\nCast your opinion and view live results: $shareUrl';

    Clipboard.setData(ClipboardData(text: textToShare));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isHindi
              ? 'पोल लिंक क्लिपबोर्ड पर कॉपी हो गया!'
              : 'Poll share link copied to clipboard!',
        ),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: isHindi ? 'ठीक है' : 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  Future<void> _openVoteDialog(bool isLike, {String? questionId, String? personId}) async {
    if (_poll == null) return;
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final reasons = isLike
        ? PollReasonOption.likeReasons
        : PollReasonOption.dislikeReasons;

    String selectedReasonKey = reasons.first.key;
    final explanationController = TextEditingController();

    // Check existing vote for this target question
    PollVote? existingTargetVote;
    if (questionId != null) {
      existingTargetVote = _poll!.questions
          .where((q) => q.id == questionId)
          .firstOrNull
          ?.userVote ?? _poll!.userVotes[questionId];
    }
    existingTargetVote ??= _poll!.userVote;

    if (existingTargetVote != null && existingTargetVote.choice == (isLike ? 'LIKE' : 'DISLIKE')) {
      selectedReasonKey = existingTargetVote.reasonKey;
      if (existingTargetVote.explanation != null) {
        explanationController.text = existingTargetVote.explanation!;
      }
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isLike ? Icons.thumb_up : Icons.thumb_down,
                          color: isLike ? Colors.green : Colors.red,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isHindi
                                ? (isLike ? 'आप समर्थन क्यों करते हैं?' : 'आप असंतुष्ट क्यों हैं?')
                                : (isLike ? 'Why do you Like this person?' : 'Why do you Dislike this person?'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(modalCtx).pop(false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isHindi
                          ? 'कृपया अपना मुख्य कारण चुनें (यह आपकी व्यक्तिगत राय के रूप में दर्ज होगा):'
                          : 'Please choose your primary reason (recorded as your personal opinion):',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...reasons.map((r) {
                      final isSelected = selectedReasonKey == r.key;
                      return InkWell(
                        onTap: () {
                          setModalState(() {
                            selectedReasonKey = r.key;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isLike ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1))
                                : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? (isLike ? Colors.green : Colors.red)
                                  : Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                r.icon,
                                size: 18,
                                color: isSelected
                                    ? (isLike ? Colors.green : Colors.red)
                                    : Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  r.localized(isHindi),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? (isLike ? Colors.green : Colors.red)
                                        : Theme.of(context).colorScheme.outline,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? Center(
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isLike ? Colors.green : Colors.red,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Text(
                      isHindi
                          ? 'वैकल्पिक संक्षिप्त टिप्पणी (अधिकतम 500 अक्षर):'
                          : 'Optional explanation (max 500 characters):',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: explanationController,
                      maxLength: 500,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: isHindi
                            ? 'अपनी राय संक्षेप में लिखें...'
                            : 'Explain in your own words...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: isLike ? Colors.green : Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.of(modalCtx).pop(true),
                        child: Text(
                          isHindi ? 'अपना मत दर्ज करें' : 'Submit Your Opinion',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      final updated = await _pollService.castVote(
        pollId: _poll!.id,
        choice: isLike ? 'LIKE' : 'DISLIKE',
        reasonKey: selectedReasonKey,
        explanation: explanationController.text.trim().isNotEmpty
            ? explanationController.text.trim()
            : null,
        questionId: questionId,
        personId: personId,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (updated != null) {
          _poll = updated;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isHindi
                ? 'आपका मत सफलतापूर्वक दर्ज कर लिया गया है!'
                : 'Your opinion has been recorded successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _openReportDialog() async {
    if (_poll == null) return;
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    String selectedReason = 'defamation';
    final detailsController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            return AlertDialog(
              title: Text(isHindi ? 'पोल की रिपोर्ट करें' : 'Report Poll'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHindi
                          ? 'यदि यह पोल किसी नीति का उल्लंघन करता है तो कारण चुनें:'
                          : 'Select a reason if this poll violates platform guidelines:',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedReason,
                      items: [
                        DropdownMenuItem(
                          value: 'defamation',
                          child: Text(isHindi ? 'भ्रामक या मानहानिकारक' : 'Misleading or Defamatory'),
                        ),
                        DropdownMenuItem(
                          value: 'harassment',
                          child: Text(isHindi ? 'उत्पीड़न या व्यक्तिगत हमला' : 'Harassment or Personal Attack'),
                        ),
                        DropdownMenuItem(
                          value: 'hate_speech',
                          child: Text(isHindi ? 'घृणास्पद भाषण' : 'Hate Speech'),
                        ),
                        DropdownMenuItem(
                          value: 'false_identity',
                          child: Text(isHindi ? 'गलत पहचान या प्रतिरूपण' : 'False Identity or Impersonation'),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text(isHindi ? 'अन्य कारण' : 'Other Reason'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDState(() => selectedReason = val);
                      },
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailsController,
                      maxLength: 300,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'अतिरिक्त विवरण (वैकल्पिक)' : 'Additional details (optional)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dCtx).pop(false),
                  child: Text(isHindi ? 'रद्द करें' : 'Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dCtx).pop(true),
                  child: Text(isHindi ? 'रिपोर्ट भेजें' : 'Submit Report'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      final success = await _pollService.reportPoll(
        pollId: _poll!.id,
        reason: selectedReason,
        details: detailsController.text.trim().isNotEmpty
            ? detailsController.text.trim()
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? (isHindi ? 'रिपोर्ट दर्ज कर ली गई है।' : 'Report submitted for moderation review.')
                  : (_pollService.errorMessage ?? 'Report failed'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isHindi ? 'जनमत सर्वेक्षण' : 'Public Opinion Poll',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: isHindi ? 'पोल शेयर करें' : 'Share Poll',
            onPressed: _sharePoll,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isHindi ? 'रिफ्रेश करें' : 'Refresh Live Results',
            onPressed: _loadPoll,
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'report') _openReportDialog();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined, size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(isHindi ? 'रिपोर्ट करें' : 'Report Poll'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(theme, isHindi),
    );
  }

  Widget _buildBody(ThemeData theme, bool isHindi) {
    if (_isLoading && _poll == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _poll == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadPoll,
                icon: const Icon(Icons.refresh),
                label: Text(isHindi ? 'पुनः प्रयास करें' : 'Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_poll == null) {
      return const SizedBox.shrink();
    }

    final poll = _poll!;

    return RefreshIndicator(
      onRefresh: _loadPoll,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Mandatory Public Opinion Disclaimer Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 20, color: Colors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isHindi
                          ? 'सार्वजनिक सूचना: यह सर्वेक्षण केवल व्यक्तिगत जनमत और मतदाताओं की राय को दर्शाता है। यह कोई आधिकारिक चुनाव, वैज्ञानिक सर्वेक्षण या प्रमाणित तथ्य नहीं है।'
                          : 'Public Notice: This poll reflects individual voter opinions and public sentiment. It is not an official election, scientific survey, or verified finding of fact.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Purpose / Category Banner (if present)
            if (poll.purpose != null && poll.purpose!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.category_outlined, size: 16, color: theme.colorScheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${poll.category != null ? "[${poll.category}] " : ""}${poll.purpose!}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 2. Person Identity & Status Card
            _buildPersonCard(poll, isHindi, theme),
            const SizedBox(height: 20),

            // Top Share Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                key: const Key('poll_detail_top_share_button'),
                onPressed: _sharePoll,
                icon: const Icon(Icons.share, size: 18),
                label: Text(
                  isHindi ? 'यह पोल शेयर करें' : 'Share This Poll',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 3. Multi-Question or Single-Question Section
            if (poll.isMultiQuestion) ...[
              Text(
                isHindi ? 'सर्वेक्षण के प्रश्न (${poll.questions.length})' : 'Poll Questions (${poll.questions.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...poll.questions.asMap().entries.map((entry) {
                final idx = entry.key;
                final q = entry.value;
                return _buildQuestionCard(poll, q, idx, isHindi, theme);
              }),
            ] else ...[
              // Single Question Live Results Bar
              Text(
                isHindi ? 'लाइव परिणाम / वर्तमान जनमत' : 'Live Aggregate Results',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildResultsBar(
                likePct: poll.likePercentage,
                dislikePct: poll.dislikePercentage,
                likeCount: poll.likeCount,
                dislikeCount: poll.dislikeCount,
                total: poll.totalVotes,
                isHindi: isHindi,
                theme: theme,
              ),
              const SizedBox(height: 20),

              // Single Question Voting Section
              if (poll.isActive) ...[
                _buildVotingCard(poll, isHindi, theme),
                const SizedBox(height: 24),
              ] else ...[
                _buildClosedBanner(isHindi),
                const SizedBox(height: 24),
              ],

              // Single Question Reasons Breakdown Section
              Text(
                isHindi ? 'नागरिकों की राय के प्रमुख कारण' : 'Why People Voted (Reasons Breakdown)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildReasonBreakdownTabs(poll, isHindi, theme),
            ],

            const SizedBox(height: 30),

            // Share CTA
            Center(
              child: OutlinedButton.icon(
                onPressed: _sharePoll,
                icon: const Icon(Icons.share, size: 18),
                label: Text(isHindi ? 'पोल शेयर करें' : 'Share This Poll Link'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonAvatar(PollPerson person, ThemeData theme, {double radius = 24}) {
    if (person.photoUrl != null && person.photoUrl!.trim().isNotEmpty) {
      final rawUrl = person.photoUrl!.trim();
      final fullUrl = rawUrl.startsWith('/') ? '${AppConstants.baseUrl}$rawUrl' : rawUrl;
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          fullUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildAvatarFallback(person.name, theme, radius: radius),
        ),
      );
    }
    return _buildAvatarFallback(person.name, theme, radius: radius);
  }

  Widget _buildAvatarFallback(String name, ThemeData theme, {double radius = 24}) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.85,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildVerificationBadge(String status, bool isHindi, ThemeData theme) {
    switch (status) {
      case 'VERIFIED':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.green.shade400, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified, size: 12, color: Colors.green),
              const SizedBox(width: 4),
              Text(
                isHindi ? 'सत्यापित प्रोफाइल' : 'Verified Profile',
                style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      case 'DOCUMENTED':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.blue.shade300, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description_outlined, size: 12, color: Colors.blue),
              const SizedBox(width: 4),
              Text(
                isHindi ? 'प्रलेखित' : 'Documented',
                style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      case 'SELF_CLAIMED':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.orange.shade300, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_pin_outlined, size: 12, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                isHindi ? 'निर्माता घोषित' : 'Self-Claimed',
                style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      default:
        // Neutral unverified - never claim verified
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade400, width: 0.6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 12, color: Colors.grey.shade700),
              const SizedBox(width: 4),
              Text(
                isHindi ? 'अपुष्ट विवरण' : 'Unverified Details',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildPersonProfileDetails(PollPerson person, bool isHindi, ThemeData theme) {
    final hasWork = person.workBackground != null && person.workBackground!.trim().isNotEmpty;
    final hasPublicService = person.publicServiceHistory != null && person.publicServiceHistory!.trim().isNotEmpty;
    final hasEdu = person.education != null && person.education!.trim().isNotEmpty;
    final hasAch = person.achievements != null && person.achievements!.trim().isNotEmpty;
    final hasCaste = person.casteCommunity != null && person.casteCommunity!.trim().isNotEmpty;
    final hasRel = person.religion != null && person.religion!.trim().isNotEmpty;
    final hasSource = person.sourceReference != null && person.sourceReference!.trim().isNotEmpty;

    if (!hasWork && !hasPublicService && !hasEdu && !hasAch && !hasCaste && !hasRel && !hasSource) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          isHindi ? 'विस्तृत पृष्ठभूमि विवरण उपलब्ध नहीं कराया गया है।' : 'Detailed background details not provided.',
          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: theme.colorScheme.outline),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasWork) ...[
            _buildProfileDetailRow(
              Icons.work_outline,
              isHindi ? 'कार्यक्षेत्र एवं अनुभव' : 'Work Background & Experience',
              person.workBackground!.trim(),
              theme,
            ),
            const SizedBox(height: 8),
          ],
          if (hasPublicService) ...[
            _buildProfileDetailRow(
              Icons.volunteer_activism_outlined,
              isHindi ? 'जनसेवा एवं कार्य इतिहास' : 'Public-Service History & Work Done',
              person.publicServiceHistory!.trim(),
              theme,
            ),
            const SizedBox(height: 8),
          ],
          if (hasEdu) ...[
            _buildProfileDetailRow(
              Icons.school_outlined,
              isHindi ? 'शिक्षा / योग्यता' : 'Education / Qualification',
              person.education!.trim(),
              theme,
            ),
            const SizedBox(height: 8),
          ],
          if (hasAch) ...[
            _buildProfileDetailRow(
              Icons.emoji_events_outlined,
              isHindi ? 'उपलब्धियां एवं योगदान' : 'Achievements & Contributions',
              person.achievements!.trim(),
              theme,
            ),
            const SizedBox(height: 8),
          ],
          if (hasCaste || hasRel) ...[
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHindi
                        ? 'घोषित सामुदायिक विवरण (नागरिक द्वारा स्वेच्छा से घोषित):'
                        : 'Declared Community Info (Voluntarily declared by creator):',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (hasCaste)
                        Text(
                          '${isHindi ? "जाति/समुदाय: " : "Community: "}${person.casteCommunity!.trim()}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (hasRel)
                        Text(
                          '${isHindi ? "धर्म: " : "Religion: "}${person.religion!.trim()}',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (hasSource) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.link_outlined, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${isHindi ? "स्रोत संदर्भ: " : "Source Reference: "}${person.sourceReference!.trim()}',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String title, String body, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            body,
            style: const TextStyle(fontSize: 13, height: 1.3),
          ),
        ),
      ],
    );
  }

  Widget _buildIndividualPersonProfileCard(
    PollPerson person,
    Poll poll,
    bool isHindi,
    ThemeData theme, {
    int? personIndex,
  }) {
    final matchedQuestions = poll.questions.where((q) => q.personId == person.id).toList();

    return Card(
      key: Key('person_profile_card_${person.id.isNotEmpty ? person.id : (personIndex ?? 0)}'),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPersonAvatar(person, theme, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (person.designation != null || person.role != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          person.designation ?? person.role ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (person.officeContext != null && person.officeContext!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          person.officeContext!,
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                        ),
                      ],
                      if (person.placeName != null && person.placeName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.place_outlined, size: 12, color: theme.colorScheme.outline),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                person.placeName!,
                                style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                _buildVerificationBadge(person.verificationStatus, isHindi, theme),
              ],
            ),
            if (person.bio != null && person.bio!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  person.bio!.trim(),
                  style: TextStyle(fontSize: 12, height: 1.35, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
            _buildPersonProfileDetails(person, isHindi, theme),
            if (matchedQuestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.help_outline, size: 12, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      isHindi
                          ? 'इस व्यक्ति के मूल्यांकन हेतु प्रश्न: ${matchedQuestions.length}'
                          : 'Questions evaluating this person: ${matchedQuestions.length}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPersonCard(Poll poll, bool isHindi, ThemeData theme) {
    if (poll.isMultiPerson) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isHindi
                      ? 'मूल्यांकित व्यक्ति / प्रत्याशी प्रोफाइल (${poll.people.length})'
                      : 'Evaluated Persons / Candidates (${poll.people.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              _buildLiveStatusBadge(poll.isActive, isHindi),
            ],
          ),
          const SizedBox(height: 12),
          ...poll.people.asMap().entries.map((entry) {
            final idx = entry.key;
            final p = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildIndividualPersonProfileCard(p, poll, isHindi, theme, personIndex: idx),
            );
          }),
          if (poll.description != null && poll.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  poll.description!,
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ],
      );
    }

    // Single Person Card (Existing layout preserved + completed profile card details)
    final primaryPerson = poll.people.isNotEmpty
        ? poll.people.first
        : PollPerson(
            id: 'p0',
            name: poll.personName,
            role: poll.personRole,
            designation: poll.personRole,
            placeName: poll.placeName,
            photoUrl: poll.photoUrl,
          );

    return Card(
      key: Key('person_profile_card_${primaryPerson.id}'),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPersonAvatar(primaryPerson, theme, radius: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        poll.personName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      if (poll.personRole != null && poll.personRole!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          poll.personRole!,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (primaryPerson.officeContext != null && primaryPerson.officeContext!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          primaryPerson.officeContext!,
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                        ),
                      ],
                      if (poll.placeName != null && poll.placeName!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.place_outlined, size: 14, color: theme.colorScheme.outline),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                poll.placeName!,
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildLiveStatusBadge(poll.isActive, isHindi),
                    const SizedBox(height: 6),
                    _buildVerificationBadge(primaryPerson.verificationStatus, isHindi, theme),
                  ],
                ),
              ],
            ),
            if (primaryPerson.bio != null && primaryPerson.bio!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  primaryPerson.bio!,
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
            _buildPersonProfileDetails(primaryPerson, isHindi, theme),
            const Divider(height: 24),
            Text(
              poll.question,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            if (poll.description != null && poll.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                poll.description!,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStatusBadge(bool isActive, bool isHindi) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.green : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive
                ? (isHindi ? 'लाइव पोल' : 'LIVE')
                : (isHindi ? 'समाप्त' : 'CLOSED'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.green.shade800 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosedBanner(bool isHindi) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        isHindi
            ? 'यह जनमत सर्वेक्षण अब समाप्त हो चुका है। नए मत स्वीकार नहीं किए जा रहे हैं।'
            : 'This public opinion poll is now closed. No new votes can be accepted.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
      ),
    );
  }

  Widget _buildQuestionCard(
    Poll poll,
    PollQuestion q,
    int index,
    bool isHindi,
    ThemeData theme,
  ) {
    String? personLabel;
    if (q.personId != null) {
      final matchedPerson = poll.people.where((p) => p.id == q.personId).firstOrNull;
      if (matchedPerson != null) {
        personLabel = matchedPerson.name;
      }
    }

    final userVote = q.userVote ?? poll.userVotes[q.id];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (personLabel != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      personLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              q.text,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Question Results Bar
            _buildResultsBar(
              likePct: q.likePercentage,
              dislikePct: q.dislikePercentage,
              likeCount: q.likeCount,
              dislikeCount: q.dislikeCount,
              total: q.totalVotes,
              isHindi: isHindi,
              theme: theme,
            ),
            const SizedBox(height: 12),

            // Question Voting Action
            if (poll.isActive) ...[
              if (userVote != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: userVote.isLike
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        userVote.isLike ? Icons.check_circle : Icons.cancel,
                        color: userVote.isLike ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isHindi
                              ? 'आपकी राय: ${userVote.isLike ? "समर्थन" : "असंतोष"} (${PollReasonOption.lookupLabel(userVote.reasonKey, userVote.isLike, isHindi)})'
                              : 'Your vote: ${userVote.isLike ? "Like" : "Dislike"} (${PollReasonOption.lookupLabel(userVote.reasonKey, userVote.isLike, isHindi)})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openVoteDialog(!userVote.isLike, questionId: q.id, personId: q.personId),
                        child: Text(isHindi ? 'बदलें' : 'Change', style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          foregroundColor: Colors.green.shade800,
                          backgroundColor: Colors.green.withValues(alpha: 0.15),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.thumb_up, size: 16),
                        label: Text(isHindi ? 'समर्थन' : 'Like'),
                        onPressed: () => _openVoteDialog(true, questionId: q.id, personId: q.personId),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          foregroundColor: Colors.red.shade800,
                          backgroundColor: Colors.red.withValues(alpha: 0.15),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.thumb_down, size: 16),
                        label: Text(isHindi ? 'असंतोष' : 'Dislike'),
                        onPressed: () => _openVoteDialog(false, questionId: q.id, personId: q.personId),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultsBar({
    required double likePct,
    required double dislikePct,
    required int likeCount,
    required int dislikeCount,
    required int total,
    required bool isHindi,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.thumb_up, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    '${likePct.toStringAsFixed(1)}% ($likeCount)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Text(
                isHindi ? 'कुल मत: $total' : 'Total votes: $total',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Text(
                    '${dislikePct.toStringAsFixed(1)}% ($dislikeCount)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.thumb_down, size: 16, color: Colors.red),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: total == 0
                  ? Container(color: Colors.grey.shade300)
                  : Row(
                      children: [
                        if (likePct > 0)
                          Expanded(
                            flex: (likePct * 10).round(),
                            child: Container(color: Colors.green),
                          ),
                        if (dislikePct > 0)
                          Expanded(
                            flex: (dislikePct * 10).round(),
                            child: Container(color: Colors.red),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVotingCard(Poll poll, bool isHindi, ThemeData theme) {
    final userVote = poll.userVote;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.how_to_vote, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                isHindi ? 'अपनी राय व्यक्त करें' : 'Cast Your Opinion',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (userVote != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: userVote.isLike
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: userVote.isLike ? Colors.green : Colors.red,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    userVote.isLike ? Icons.check_circle : Icons.cancel,
                    color: userVote.isLike ? Colors.green : Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isHindi
                          ? 'आपने दर्ज किया: ${userVote.isLike ? "समर्थन (Like)" : "असंतोष (Dislike)"} — "${PollReasonOption.lookupLabel(userVote.reasonKey, userVote.isLike, isHindi)}"'
                          : 'You voted: ${userVote.isLike ? "Like" : "Dislike"} — "${PollReasonOption.lookupLabel(userVote.reasonKey, userVote.isLike, isHindi)}"',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openVoteDialog(true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    ),
                    child: Text(isHindi ? 'समर्थन बदलें' : 'Change to Like'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openVoteDialog(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: Text(isHindi ? 'असंतोष बदलें' : 'Change to Dislike'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.thumb_up, size: 18),
                    label: Text(
                      isHindi ? 'समर्थन (Like)' : 'Like',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _openVoteDialog(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.thumb_down, size: 18),
                    label: Text(
                      isHindi ? 'असंतोष (Dislike)' : 'Dislike',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _openVoteDialog(false),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReasonBreakdownTabs(Poll poll, bool isHindi, ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Center(
                  child: Text(
                    isHindi
                        ? 'समर्थन के कारण (${poll.likeCount})'
                        : 'Like Reasons (${poll.likeCount})',
                  ),
                ),
                selected: _breakdownTab == 0,
                selectedColor: Colors.green.withValues(alpha: 0.2),
                onSelected: (val) {
                  if (val) setState(() => _breakdownTab = 0);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: Center(
                  child: Text(
                    isHindi
                        ? 'असंतोष के कारण (${poll.dislikeCount})'
                        : 'Dislike Reasons (${poll.dislikeCount})',
                  ),
                ),
                selected: _breakdownTab == 1,
                selectedColor: Colors.red.withValues(alpha: 0.2),
                onSelected: (val) {
                  if (val) setState(() => _breakdownTab = 1);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_breakdownTab == 0)
          _buildReasonsList(poll.likeReasons, true, isHindi, theme)
        else
          _buildReasonsList(poll.dislikeReasons, false, isHindi, theme),
      ],
    );
  }

  Widget _buildReasonsList(
    List<PollReasonBreakdown> list,
    bool isLike,
    bool isHindi,
    ThemeData theme,
  ) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            isHindi ? 'अभी कोई कारण दर्ज नहीं है।' : 'No reason recorded yet.',
            style: TextStyle(color: theme.colorScheme.outline),
          ),
        ),
      );
    }

    return Column(
      children: list.map((item) {
        final label = PollReasonOption.lookupLabel(item.key, isLike, isHindi);
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${item.count} (${item.percentage.toStringAsFixed(1)}%)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isLike ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (item.percentage / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  color: isLike ? Colors.green : Colors.red,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
