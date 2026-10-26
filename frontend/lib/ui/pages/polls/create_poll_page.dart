import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/poll_repository.dart';
import '../../../services/auth_service.dart';
import '../../../services/poll_service.dart';
import '../auth/login_page.dart';
import 'poll_detail_page.dart';

class CreatePollPage extends StatefulWidget {
  final String? initialPersonName;
  final String? initialPersonRole;
  final String? initialPlaceId;
  final String? initialPlaceName;
  final String? initialTargetEntityId;
  final PollService? pollService;
  final AuthService? authService;

  const CreatePollPage({
    super.key,
    this.initialPersonName,
    this.initialPersonRole,
    this.initialPlaceId,
    this.initialPlaceName,
    this.initialTargetEntityId,
    this.pollService,
    this.authService,
  });

  @override
  State<CreatePollPage> createState() => _CreatePollPageState();
}

class _CreatePollPageState extends State<CreatePollPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _personNameController;
  late final TextEditingController _personRoleController;
  late final TextEditingController _placeNameController;
  late final TextEditingController _questionController;
  late final TextEditingController _descriptionController;
  late final PollService _pollService;

  int _durationDays = 30;
  bool _isLoading = false;
  String? _errorMessage;

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

    _personNameController = TextEditingController(text: widget.initialPersonName ?? '');
    _personRoleController = TextEditingController(text: widget.initialPersonRole ?? '');
    _placeNameController = TextEditingController(text: widget.initialPlaceName ?? '');

    final initialName = widget.initialPersonName ?? '';
    _questionController = TextEditingController(
      text: initialName.isNotEmpty
          ? 'What is your opinion on the work and conduct of $initialName?'
          : '',
    );
    _descriptionController = TextEditingController();

    _personNameController.addListener(_onPersonNameChanged);
  }

  void _onPersonNameChanged() {
    // If the question is empty or was auto-generated, keep it updated
    final name = _personNameController.text.trim();
    if (_questionController.text.isEmpty ||
        _questionController.text.startsWith('What is your opinion on the work and conduct of') ||
        _questionController.text.startsWith('आप')) {
      final isHindi = Localizations.localeOf(context).languageCode == 'hi';
      if (isHindi) {
        _questionController.text = name.isNotEmpty
            ? 'आप $name के कार्य और व्यवहार से संतुष्ट हैं या नहीं?'
            : '';
      } else {
        _questionController.text = name.isNotEmpty
            ? 'What is your opinion on the work and conduct of $name?'
            : '';
      }
    }
  }

  @override
  void dispose() {
    _personNameController.removeListener(_onPersonNameChanged);
    _personNameController.dispose();
    _personRoleController.dispose();
    _placeNameController.dispose();
    _questionController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitPoll() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final poll = await _pollService.createPoll(
      personName: _personNameController.text.trim(),
      personRole: _personRoleController.text.trim().isNotEmpty
          ? _personRoleController.text.trim()
          : null,
      placeId: widget.initialPlaceId,
      placeName: _placeNameController.text.trim().isNotEmpty
          ? _placeNameController.text.trim()
          : null,
      targetEntityId: widget.initialTargetEntityId,
      question: _questionController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      durationDays: _durationDays,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (poll != null) {
      final isHindi = Localizations.localeOf(context).languageCode == 'hi';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isHindi
                ? 'जनमत सर्वेक्षण सफलतापूर्वक शुरू कर दिया गया है!'
                : 'Public opinion poll started successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to the created poll details page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PollDetailPage(
            pollId: poll.id,
            initialPoll: poll,
            pollService: _pollService,
            authService: widget.authService,
          ),
        ),
      );
    } else {
      final rawError = _pollService.errorMessage ?? 'Failed to create poll';
      final isAuthError = rawError.contains('token') ||
          rawError.toLowerCase().contains('unauthorized') ||
          rawError.toLowerCase().contains('not authenticated') ||
          rawError.contains('401');
      setState(() {
        _errorMessage = isAuthError
            ? (Localizations.localeOf(context).languageCode == 'hi'
                ? 'आपका लॉगिन सत्र समाप्त हो गया है या आप लॉग इन नहीं हैं। जनमत सर्वेक्षण प्रकाशित करने के लिए कृपया पुनः लॉगिन करें।'
                : 'Your login session has expired or is missing. Please log in to publish this poll.')
            : rawError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isHindi ? 'नया जनमत सर्वेक्षण बनाएं' : 'Create Public Opinion Poll',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Guidelines Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isHindi
                            ? 'निष्पक्षता नियम: यह जनमत सर्वेक्षण किसी भी व्यक्ति (सरपंच, पंच, विधायक, सांसद, प्रधानमंत्री या जन-प्रतिनिधि) के लिए बनाया जा सकता है। कृपया प्रश्न को निष्पक्ष रखें और व्यक्तिगत आरोप न लगाएं।'
                            : 'Fairness Rule: This opinion poll can be opened for any public representative, community leader, or person. Please keep the wording neutral and free from unsubstantiated factual accusations.',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, size: 20, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      if (widget.authService != null &&
                          (_errorMessage!.contains('login') ||
                              _errorMessage!.contains('लॉगिन') ||
                              _errorMessage!.contains('token') ||
                              _errorMessage!.contains('401'))) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonalIcon(
                            key: const Key('poll_reauth_button'),
                            icon: const Icon(Icons.login, size: 16),
                            label: Text(isHindi ? 'लॉगिन करें' : 'Log In'),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LoginPage(
                                    authService: widget.authService!,
                                    onLoginSuccess: () {
                                      Navigator.of(context).pop();
                                      _submitPoll();
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 1. Person Name
              Text(
                isHindi ? 'व्यक्ति का नाम *' : "Person's Name *",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _personNameController,
                decoration: InputDecoration(
                  hintText: isHindi ? 'उदा. राम कुमार, सीता देवी' : 'e.g., Ram Kumar, Sita Devi',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 2) {
                    return isHindi
                        ? 'कृपया कम से कम 2 अक्षरों का नाम दर्ज करें'
                        : 'Please enter a valid name (at least 2 characters)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // 2. Role / Designation
              Text(
                isHindi ? 'पद / भूमिका (वैकल्पिक)' : 'Role / Designation (Optional)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _personRoleController,
                decoration: InputDecoration(
                  hintText: isHindi
                      ? 'उदा. सरपंच, वार्ड सदस्य, विधायक, सांसद, सामाजिक कार्यकर्ता'
                      : 'e.g., Sarpanch, Ward Member, MLA, MP, Social Worker',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 14),

              // 3. Place / Jurisdiction
              Text(
                isHindi ? 'स्थान / क्षेत्र (वैकल्पिक)' : 'Place / Jurisdiction (Optional)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _placeNameController,
                decoration: InputDecoration(
                  hintText: isHindi ? 'उदा. आमेर, जयपुर, राष्ट्रीय' : 'e.g., Amer Village, Jaipur, All India',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 14),

              // 4. Neutral Poll Question
              Text(
                isHindi ? 'सर्वेक्षण का निष्पक्ष प्रश्न *' : 'Neutral Poll Question *',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _questionController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: isHindi
                      ? 'उदा. आप [नाम] के कार्य और व्यवहार से संतुष्ट हैं या नहीं?'
                      : 'e.g., What is your opinion on the work and conduct of [Name]?',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  helperText: isHindi
                      ? 'प्रश्न को निष्पक्ष रखें ताकि नागरिक समर्थन या असंतोष दोनों व्यक्त कर सकें।'
                      : 'Keep the wording neutral so voters can express Like or Dislike.',
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 5) {
                    return isHindi
                        ? 'कृपया कम से कम 5 अक्षरों का प्रश्न दर्ज करें'
                        : 'Please enter a valid question (at least 5 characters)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // 5. Context / Description
              Text(
                isHindi ? 'संदर्भ या विवरण (वैकल्पिक)' : 'Context / Description (Optional)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: isHindi
                      ? 'इस पोल के संदर्भ में कोई अतिरिक्त जानकारी...'
                      : 'Additional context about this poll...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),

              // 6. Duration
              Text(
                isHindi ? 'सर्वेक्षण अवधि (दिन)' : 'Poll Duration',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                initialValue: _durationDays,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: [
                  DropdownMenuItem(value: 7, child: Text(isHindi ? '7 दिन (1 सप्ताह)' : '7 Days (1 Week)')),
                  DropdownMenuItem(value: 15, child: Text(isHindi ? '15 दिन (2 सप्ताह)' : '15 Days (2 Weeks)')),
                  DropdownMenuItem(value: 30, child: Text(isHindi ? '30 दिन (1 महीना)' : '30 Days (1 Month)')),
                  DropdownMenuItem(value: 60, child: Text(isHindi ? '60 दिन (2 महीने)' : '60 Days (2 Months)')),
                  DropdownMenuItem(value: 90, child: Text(isHindi ? '90 दिन (3 महीने)' : '90 Days (3 Months)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _durationDays = val);
                },
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _isLoading ? null : _submitPoll,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          isHindi ? 'जनमत सर्वेक्षण शुरू करें' : 'Start Public Opinion Poll',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
