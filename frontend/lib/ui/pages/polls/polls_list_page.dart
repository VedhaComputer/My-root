import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants.dart';
import '../../../core/network/api_client.dart';
import '../../../models/poll.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/poll_repository.dart';
import '../../../services/auth_service.dart';
import '../../../services/poll_service.dart';
import 'create_poll_page.dart';
import 'poll_detail_page.dart';

class PollsListPage extends StatefulWidget {
  final PollService? pollService;
  final AuthService? authService;
  final String? initialSearch;

  const PollsListPage({
    super.key,
    this.pollService,
    this.authService,
    this.initialSearch,
  });

  @override
  State<PollsListPage> createState() => _PollsListPageState();
}

class _PollsListPageState extends State<PollsListPage> {
  late final PollService _pollService;
  late final TextEditingController _searchController;
  String _selectedFilter = 'ALL'; // 'ALL', 'ACTIVE', 'CLOSED'
  bool _isLoading = false;

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
    _searchController = TextEditingController(text: widget.initialSearch ?? '');
    _loadPolls();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPolls() async {
    setState(() => _isLoading = true);
    final status = _selectedFilter == 'ALL' ? null : _selectedFilter;
    final search = _searchController.text.trim().isNotEmpty
        ? _searchController.text.trim()
        : null;

    await _pollService.fetchPolls(status: status, search: search);
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _sharePoll(Poll poll) {
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final shareUrl = '${AppConstants.shareBaseUrl}/polls/${poll.id}';
    final textToShare = isHindi
        ? 'जनमत सर्वेक्षण: ${poll.question}\nअपना मत दर्ज करें और लाइव परिणाम देखें: $shareUrl'
        : 'Live Public Opinion Poll: ${poll.question}\nCast your opinion and view live results: $shareUrl';

    Clipboard.setData(ClipboardData(text: textToShare));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isHindi
              ? 'पोल लिंक क्लिपबोर्ड पर कॉपी हो गया!'
              : 'Poll share link copied to clipboard!',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isHindi ? 'लाइव जनमत सर्वेक्षण' : 'Live Opinion Polls',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isHindi ? 'रिफ्रेश करें' : 'Refresh',
            onPressed: _loadPolls,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(isHindi ? 'नया पोल बनाएं' : 'Start a Poll'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CreatePollPage(
                pollService: _pollService,
                authService: widget.authService,
              ),
            ),
          ).then((_) => _loadPolls());
        },
      ),
      body: Column(
        children: [
          // Search & Filter header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: isHindi
                        ? 'नाम, पद या प्रश्न खोजें...'
                        : 'Search person, role, or question...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _loadPolls();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (_) => _loadPolls(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildFilterChip('ALL', isHindi ? 'सभी' : 'All'),
                    const SizedBox(width: 8),
                    _buildFilterChip('ACTIVE', isHindi ? 'सक्रिय (लाइव)' : 'Live / Active'),
                    const SizedBox(width: 8),
                    _buildFilterChip('CLOSED', isHindi ? 'समाप्त' : 'Closed'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Polls List
          Expanded(
            child: _buildPollsList(theme, isHindi),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedFilter = value);
          _loadPolls();
        }
      },
    );
  }

  Widget _buildPollsList(ThemeData theme, bool isHindi) {
    if (_isLoading && _pollService.polls.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final polls = _pollService.polls;

    if (polls.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.how_to_vote_outlined, size: 54, color: theme.colorScheme.outline),
              const SizedBox(height: 12),
              Text(
                isHindi
                    ? 'कोई जनमत सर्वेक्षण नहीं मिला'
                    : 'No public opinion polls found',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                isHindi
                    ? 'किसी भी जन-प्रतिनिधि या व्यक्ति के लिए नया पोल शुरू करें।'
                    : 'Start a new public opinion poll for any person or representative.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(isHindi ? 'पहला पोल शुरू करें' : 'Start First Poll'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreatePollPage(
                        pollService: _pollService,
                        authService: widget.authService,
                      ),
                    ),
                  ).then((_) => _loadPolls());
                },
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPolls,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: polls.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final poll = polls[index];
          return _buildPollCard(poll, theme, isHindi);
        },
      ),
    );
  }

  Widget _buildPollCard(Poll poll, ThemeData theme, bool isHindi) {
    final likePct = poll.likePercentage;
    final dislikePct = poll.dislikePercentage;
    final total = poll.totalVotes;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PollDetailPage(
                pollId: poll.id,
                initialPoll: poll,
                pollService: _pollService,
                authService: widget.authService,
              ),
            ),
          ).then((_) => _loadPolls());
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Person name, role, status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      poll.personName.isNotEmpty ? poll.personName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poll.personName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (poll.personRole != null && poll.personRole!.isNotEmpty) ...[
                          Text(
                            poll.personRole!,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (poll.isMultiPerson || poll.isMultiQuestion || poll.purpose != null) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (poll.purpose != null && poll.purpose!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    poll.purpose!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              if (poll.isMultiPerson)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isHindi ? '${poll.people.length} व्यक्ति' : '${poll.people.length} People',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              if (poll.isMultiQuestion)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isHindi ? '${poll.questions.length} प्रश्न' : '${poll.questions.length} Questions',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onTertiaryContainer,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: poll.isActive
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: poll.isActive ? Colors.green : Colors.grey,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      poll.isActive
                          ? (isHindi ? 'लाइव' : 'LIVE')
                          : (isHindi ? 'समाप्त' : 'CLOSED'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: poll.isActive ? Colors.green.shade800 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Question
              Text(
                poll.question,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),

              // Results Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
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
              const SizedBox(height: 8),

              // Counts and Share Button footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.thumb_up, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        '${likePct.toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.thumb_down, size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        '${dislikePct.toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '($total ${isHindi ? "मत" : "votes"})',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    key: Key('poll_share_btn_${poll.id}'),
                    icon: const Icon(Icons.share, size: 14),
                    label: Text(
                      isHindi ? 'शेयर' : 'Share',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _sharePoll(poll),
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
