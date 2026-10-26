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
    // Background polling every 20 seconds while user is viewing an active poll
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

  Future<void> _openVoteDialog(bool isLike) async {
    if (_poll == null) return;
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final reasons = isLike
        ? PollReasonOption.likeReasons
        : PollReasonOption.dislikeReasons;

    String selectedReasonKey = reasons.first.key;
    final explanationController = TextEditingController();

    // Pre-fill existing vote if updating same choice
    if (_poll!.userVote != null && _poll!.userVote!.choice == (isLike ? 'LIKE' : 'DISLIKE')) {
      selectedReasonKey = _poll!.userVote!.reasonKey;
      if (_poll!.userVote!.explanation != null) {
        explanationController.text = _poll!.userVote!.explanation!;
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

            // 2. Person Identity & Status Card
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            poll.personName.isNotEmpty ? poll.personName[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
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
                        // Live / Closed Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: poll.isActive ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: poll.isActive ? Colors.green : Colors.grey,
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
                                  color: poll.isActive ? Colors.green : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                poll.isActive
                                    ? (isHindi ? 'लाइव पोल' : 'LIVE')
                                    : (isHindi ? 'समाप्त' : 'CLOSED'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: poll.isActive ? Colors.green.shade800 : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    // Question
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
                    const SizedBox(height: 14),
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 3. Live Results Progress Bar
            Text(
              isHindi ? 'लाइव परिणाम / वर्तमान जनमत' : 'Live Aggregate Results',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildResultsBar(poll, isHindi, theme),
            const SizedBox(height: 20),

            // 4. Voting Section
            if (poll.isActive) ...[
              _buildVotingCard(poll, isHindi, theme),
              const SizedBox(height: 24),
            ] else ...[
              Container(
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
              ),
              const SizedBox(height: 24),
            ],

            // 5. Reasons Breakdown Section
            Text(
              isHindi ? 'नागरिकों की राय के प्रमुख कारण' : 'Why People Voted (Reasons Breakdown)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildReasonBreakdownTabs(poll, isHindi, theme),
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

  Widget _buildResultsBar(Poll poll, bool isHindi, ThemeData theme) {
    final likePct = poll.likePercentage;
    final dislikePct = poll.dislikePercentage;
    final total = poll.totalVotes;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
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
                  const Icon(Icons.thumb_up, size: 18, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                    '${likePct.toStringAsFixed(1)}% (${poll.likeCount})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Text(
                isHindi ? 'कुल मत: $total' : 'Total votes: $total',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Text(
                    '${dislikePct.toStringAsFixed(1)}% (${poll.dislikeCount})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.thumb_down, size: 18, color: Colors.red),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
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
