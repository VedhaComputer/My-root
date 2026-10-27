import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants.dart';
import '../../../core/network/api_client.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/poll_repository.dart';
import '../../../services/auth_service.dart';
import '../../../services/poll_service.dart';
import '../auth/login_page.dart';
import 'poll_detail_page.dart';

class _PersonFormData {
  final TextEditingController nameController;
  final TextEditingController roleController;
  final TextEditingController designationController;
  final TextEditingController officeContextController;
  final TextEditingController placeController;
  final TextEditingController photoUrlController;
  final TextEditingController workBackgroundController;
  final TextEditingController publicServiceHistoryController;
  final TextEditingController educationController;
  final TextEditingController achievementsController;
  final TextEditingController casteCommunityController;
  final TextEditingController religionController;
  final TextEditingController bioController;
  final TextEditingController sourceReferenceController;

  Uint8List? selectedImageBytes;
  String? selectedImageName;
  bool isUploadingPhoto = false;
  String? photoUploadError;

  _PersonFormData({
    String initialName = '',
    String initialRole = '',
    String initialDesignation = '',
    String initialOfficeContext = '',
    String initialPlace = '',
    String initialPhotoUrl = '',
    String initialWorkBackground = '',
    String initialPublicServiceHistory = '',
    String initialEducation = '',
    String initialAchievements = '',
    String initialCasteCommunity = '',
    String initialReligion = '',
    String initialBio = '',
    String initialSourceReference = '',
  })  : nameController = TextEditingController(text: initialName),
        roleController = TextEditingController(text: initialRole),
        designationController = TextEditingController(text: initialDesignation),
        officeContextController = TextEditingController(text: initialOfficeContext),
        placeController = TextEditingController(text: initialPlace),
        photoUrlController = TextEditingController(text: initialPhotoUrl),
        workBackgroundController = TextEditingController(text: initialWorkBackground),
        publicServiceHistoryController = TextEditingController(text: initialPublicServiceHistory),
        educationController = TextEditingController(text: initialEducation),
        achievementsController = TextEditingController(text: initialAchievements),
        casteCommunityController = TextEditingController(text: initialCasteCommunity),
        religionController = TextEditingController(text: initialReligion),
        bioController = TextEditingController(text: initialBio),
        sourceReferenceController = TextEditingController(text: initialSourceReference);

  void dispose() {
    nameController.dispose();
    roleController.dispose();
    designationController.dispose();
    officeContextController.dispose();
    placeController.dispose();
    photoUrlController.dispose();
    workBackgroundController.dispose();
    publicServiceHistoryController.dispose();
    educationController.dispose();
    achievementsController.dispose();
    casteCommunityController.dispose();
    religionController.dispose();
    bioController.dispose();
    sourceReferenceController.dispose();
  }
}

class _QuestionFormData {
  final TextEditingController textController;
  int? targetPersonIndex;

  _QuestionFormData({String initialText = '', this.targetPersonIndex})
      : textController = TextEditingController(text: initialText);

  void dispose() {
    textController.dispose();
  }
}

typedef ImagePickerCallback = Future<XFile?> Function();

class CreatePollPage extends StatefulWidget {
  final String? initialPersonName;
  final String? initialPersonRole;
  final String? initialPlaceId;
  final String? initialPlaceName;
  final String? initialTargetEntityId;
  final PollService? pollService;
  final AuthService? authService;
  final ImagePickerCallback? imagePickerOverride;

  const CreatePollPage({
    super.key,
    this.initialPersonName,
    this.initialPersonRole,
    this.initialPlaceId,
    this.initialPlaceName,
    this.initialTargetEntityId,
    this.pollService,
    this.authService,
    this.imagePickerOverride,
  });

  @override
  State<CreatePollPage> createState() => _CreatePollPageState();
}

class _CreatePollPageState extends State<CreatePollPage> {
  final _formKey = GlobalKey<FormState>();
  late final PollService _pollService;

  late final TextEditingController _purposeController;
  late final TextEditingController _categoryController;
  late final TextEditingController _descriptionController;

  final List<_PersonFormData> _people = [];
  final List<_QuestionFormData> _questions = [];

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

    _purposeController = TextEditingController();
    _categoryController = TextEditingController();
    _descriptionController = TextEditingController();

    // Initial evaluated person
    final firstPerson = _PersonFormData(
      initialName: widget.initialPersonName ?? '',
      initialRole: widget.initialPersonRole ?? '',
      initialDesignation: widget.initialPersonRole ?? '',
      initialPlace: widget.initialPlaceName ?? '',
    );
    _people.add(firstPerson);

    // Initial question
    final initialName = widget.initialPersonName ?? '';
    final initialQ = initialName.isNotEmpty
        ? 'What is your opinion on the work and conduct of $initialName?'
        : '';
    _questions.add(_QuestionFormData(initialText: initialQ, targetPersonIndex: 0));

    firstPerson.nameController.addListener(_onFirstPersonNameChanged);
  }

  void _onFirstPersonNameChanged() {
    if (_questions.isEmpty) return;
    final name = _people.first.nameController.text.trim();
    final firstQ = _questions.first.textController;
    if (firstQ.text.isEmpty ||
        firstQ.text.startsWith('What is your opinion on the work and conduct of') ||
        firstQ.text.startsWith('आप')) {
      final isHindi = Localizations.localeOf(context).languageCode == 'hi';
      if (isHindi) {
        firstQ.text = name.isNotEmpty
            ? 'आप $name के कार्य और व्यवहार से संतुष्ट हैं या नहीं?'
            : '';
      } else {
        firstQ.text = name.isNotEmpty
            ? 'What is your opinion on the work and conduct of $name?'
            : '';
      }
    }
  }

  void _addPerson() {
    setState(() {
      _people.add(_PersonFormData());
    });
  }

  void _removePerson(int index) {
    if (_people.length <= 1) return;
    setState(() {
      final removed = _people.removeAt(index);
      removed.dispose();
      for (final q in _questions) {
        if (q.targetPersonIndex == index) {
          q.targetPersonIndex = null;
        } else if (q.targetPersonIndex != null && q.targetPersonIndex! > index) {
          q.targetPersonIndex = q.targetPersonIndex! - 1;
        }
      }
    });
  }

  void _addQuestion() {
    setState(() {
      _questions.add(_QuestionFormData(targetPersonIndex: null));
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length <= 1) return;
    setState(() {
      final removed = _questions.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _pickAndUploadPhoto(int index) async {
    final person = _people[index];
    try {
      final XFile? file;
      if (widget.imagePickerOverride != null) {
        file = await widget.imagePickerOverride!();
      } else {
        final picker = ImagePicker();
        file = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
      }
      if (file == null) return;
      final pickedFile = file;

      final bytes = await pickedFile.readAsBytes();
      if (bytes.isEmpty) return;

      final resolvedName = pickedFile.name.isNotEmpty ? pickedFile.name : 'photo.png';

      setState(() {
        person.selectedImageBytes = bytes;
        person.selectedImageName = resolvedName;
        person.isUploadingPhoto = true;
        person.photoUploadError = null;
      });

      final mimeType = pickedFile.mimeType ??
          (pickedFile.name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : (pickedFile.name.toLowerCase().endsWith('.webp')
                  ? 'image/webp'
                  : 'image/jpeg'));

      final photoUrl = await _pollService.uploadPersonPhoto(
        fileBytes: bytes,
        filename: pickedFile.name.isNotEmpty ? pickedFile.name : 'photo.jpg',
        mimeType: mimeType,
      );

      if (!mounted) return;

      if (photoUrl != null && photoUrl.isNotEmpty) {
        setState(() {
          person.photoUrlController.text = photoUrl;
          person.isUploadingPhoto = false;
          person.photoUploadError = null;
        });
      } else {
        final isHindi = Localizations.localeOf(context).languageCode == 'hi';
        setState(() {
          person.selectedImageBytes = null;
          person.selectedImageName = null;
          person.isUploadingPhoto = false;
          person.photoUploadError = _pollService.errorMessage ??
              (isHindi ? 'फोटो अपलोड करने में विफल' : 'Failed to upload photo');
        });
      }
    } catch (e) {
      if (!mounted) return;
      final isHindi = Localizations.localeOf(context).languageCode == 'hi';
      String errorMsg = isHindi
          ? 'फोटो चुनने या अपलोड करने में त्रुटि: $e'
          : 'Error picking or uploading photo: $e';
      if (e is PlatformException && e.code == 'channel-error') {
        errorMsg = isHindi
            ? 'फोटो पिकर प्लगइन कनेक्शन त्रुटि। कृपया ऐप को पुनः प्रारंभ (full restart) करें।'
            : 'Photo picker plugin connection error. Please restart the application to complete native plugin registration.';
      }
      setState(() {
        person.selectedImageBytes = null;
        person.selectedImageName = null;
        person.isUploadingPhoto = false;
        person.photoUploadError = errorMsg;
      });
    }
  }

  void _removePersonPhoto(int index) {
    setState(() {
      final person = _people[index];
      person.selectedImageBytes = null;
      person.selectedImageName = null;
      person.photoUrlController.clear();
      person.photoUploadError = null;
    });
  }

  Widget _buildPhotoUploadSection(
    _PersonFormData person,
    int index,
    ThemeData theme,
    bool isHindi,
  ) {
    final hasPhoto = (person.selectedImageBytes != null && person.selectedImageBytes!.isNotEmpty) ||
        person.photoUrlController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (person.isUploadingPhoto)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isHindi ? 'फोटो अपलोड हो रही है...' : 'Uploading photo...',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else if (hasPhoto)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: person.selectedImageBytes != null
                      ? Image.memory(
                          person.selectedImageBytes!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => CircleAvatar(
                            radius: 28,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(Icons.person, color: theme.colorScheme.onPrimaryContainer),
                          ),
                        )
                      : Image.network(
                          person.photoUrlController.text.trim().startsWith('/')
                              ? '${AppConstants.baseUrl}${person.photoUrlController.text.trim()}'
                              : person.photoUrlController.text.trim(),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => CircleAvatar(
                            radius: 28,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(Icons.person, color: theme.colorScheme.onPrimaryContainer),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.selectedImageName ??
                            (isHindi ? 'फोटो संलग्न है' : 'Photo attached'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          OutlinedButton.icon(
                            key: ValueKey('change_photo_button_$index'),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: Text(isHindi ? 'फोटो बदलें' : 'Change Photo'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _pickAndUploadPhoto(index),
                          ),
                          TextButton.icon(
                            key: ValueKey('remove_photo_button_$index'),
                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                            label: Text(
                              isHindi ? 'हटाएं' : 'Remove',
                              style: const TextStyle(color: Colors.red),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _removePersonPhoto(index),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              OutlinedButton.icon(
                key: ValueKey('upload_photo_button_$index'),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(isHindi ? 'फोटो अपलोड करें' : 'Upload Photo'),
                onPressed: () => _pickAndUploadPhoto(index),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isHindi ? 'JPG, PNG या WebP (अधिकतम 5MB)' : 'JPG, PNG or WebP (max 5MB)',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                ),
              ),
            ],
          ),
        if (person.photoUploadError != null) ...[
          const SizedBox(height: 6),
          Text(
            person.photoUploadError!,
            style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    if (_people.isNotEmpty) {
      _people.first.nameController.removeListener(_onFirstPersonNameChanged);
    }
    for (final p in _people) {
      p.dispose();
    }
    for (final q in _questions) {
      q.dispose();
    }
    _purposeController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitPoll() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final peoplePayload = _people.map((p) {
      return {
        'name': p.nameController.text.trim(),
        if (p.roleController.text.trim().isNotEmpty) 'role': p.roleController.text.trim(),
        if (p.designationController.text.trim().isNotEmpty)
          'designation': p.designationController.text.trim(),
        if (p.officeContextController.text.trim().isNotEmpty)
          'officeContext': p.officeContextController.text.trim(),
        if (p.placeController.text.trim().isNotEmpty)
          'placeName': p.placeController.text.trim(),
        if (widget.initialPlaceId != null) 'placeId': widget.initialPlaceId,
        if (widget.initialTargetEntityId != null) 'targetEntityId': widget.initialTargetEntityId,
        if (p.photoUrlController.text.trim().isNotEmpty)
          'photoUrl': p.photoUrlController.text.trim(),
        if (p.workBackgroundController.text.trim().isNotEmpty)
          'workBackground': p.workBackgroundController.text.trim(),
        if (p.publicServiceHistoryController.text.trim().isNotEmpty)
          'publicServiceHistory': p.publicServiceHistoryController.text.trim(),
        if (p.educationController.text.trim().isNotEmpty)
          'education': p.educationController.text.trim(),
        if (p.achievementsController.text.trim().isNotEmpty)
          'achievements': p.achievementsController.text.trim(),
        if (p.casteCommunityController.text.trim().isNotEmpty)
          'casteCommunity': p.casteCommunityController.text.trim(),
        if (p.religionController.text.trim().isNotEmpty)
          'religion': p.religionController.text.trim(),
        if (p.bioController.text.trim().isNotEmpty)
          'bio': p.bioController.text.trim(),
        if (p.sourceReferenceController.text.trim().isNotEmpty)
          'sourceReference': p.sourceReferenceController.text.trim(),
        'verificationStatus': 'UNVERIFIED',
      };
    }).toList();

    final questionsPayload = _questions.asMap().entries.map((entry) {
      final idx = entry.key;
      final q = entry.value;
      String? personIdRef;
      if (q.targetPersonIndex != null &&
          q.targetPersonIndex! >= 0 &&
          q.targetPersonIndex! < _people.length) {
        personIdRef = 'person_$idx';
      }
      return {
        'text': q.textController.text.trim(),
        'questionType': 'LIKE_DISLIKE',
        if (personIdRef != null) 'personId': personIdRef,
      };
    }).toList();

    final poll = await _pollService.createPoll(
      personName: _people.first.nameController.text.trim(),
      personRole: _people.first.roleController.text.trim().isNotEmpty
          ? _people.first.roleController.text.trim()
          : null,
      placeId: widget.initialPlaceId,
      placeName: _people.first.placeController.text.trim().isNotEmpty
          ? _people.first.placeController.text.trim()
          : null,
      targetEntityId: widget.initialTargetEntityId,
      question: _questions.first.textController.text.trim(),
      purpose: _purposeController.text.trim().isNotEmpty
          ? _purposeController.text.trim()
          : null,
      category: _categoryController.text.trim().isNotEmpty
          ? _categoryController.text.trim()
          : null,
      people: peoplePayload,
      questions: questionsPayload,
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
                            ? 'निष्पक्षता नियम: यह जनमत सर्वेक्षण एक या अधिक व्यक्तियों (सरपंच, पंच, वार्ड सदस्य, विधायक, सांसद, प्रधानमंत्री, सामाजिक कार्यकर्ता या अन्य प्रतिनिधि) के लिए बनाया जा सकता है। कृपया प्रश्न को निष्पक्ष रखें और व्यक्तिगत आरोप न लगाएं।'
                            : 'Fairness Rule: This opinion poll can evaluate one or multiple people (Sarpanch, Panch, Ward Member, MLA, MP, PM, Social Worker, Chairperson, or other persons). Please keep the wording neutral and free from unsubstantiated factual accusations.',
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

              // Poll Purpose & Category
              Text(
                isHindi ? 'सर्वेक्षण का उद्देश्य / श्रेणी (वैकल्पिक)' : 'Poll Purpose / Category (Optional)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _purposeController,
                decoration: InputDecoration(
                  hintText: isHindi
                      ? 'उदा. पंचायत विकास कार्य समीक्षा, चुनावी तुलना, जनसेवा मूल्यांकन'
                      : 'e.g., Panchayat Development Review, Candidate Comparison, Public Feedback',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // People Being Evaluated
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isHindi ? 'मूल्यांकन हेतु व्यक्ति / प्रतिनिधि' : 'Person(s) Being Evaluated',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  TextButton.icon(
                    onPressed: _addPerson,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: Text(isHindi ? '+ व्यक्ति जोड़ें' : '+ Add Person'),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              ...List.generate(_people.length, (index) {
                final person = _people[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isHindi
                                  ? 'व्यक्ति #${index + 1}'
                                  : 'Person #${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            if (_people.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                tooltip: isHindi ? 'हटाएं' : 'Remove',
                                onPressed: () => _removePerson(index),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Person Name
                        Text(
                          isHindi ? 'व्यक्ति का नाम *' : "Person's Name *",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: person.nameController,
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
                        const SizedBox(height: 10),
                        // Role / Designation
                        Text(
                          isHindi ? 'पद / भूमिका (वैकल्पिक)' : 'Role / Designation (Optional)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: person.roleController,
                          decoration: InputDecoration(
                            hintText: isHindi
                                ? 'उदा. सरपंच, वार्ड सदस्य, विधायक, सांसद, सामाजिक कार्यकर्ता'
                                : 'e.g., Sarpanch, Ward Member, MLA, MP, PM, Social Worker',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Office Context
                        Text(
                          isHindi ? 'वर्तमान पद संदर्भ (वैकल्पिक)' : 'Office / Term Context (Optional)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: person.officeContextController,
                          decoration: InputDecoration(
                            hintText: isHindi
                                ? 'उदा. वर्तमान कार्यकाल (2021-2026), पूर्व प्रतिनिधि, प्रत्याशी'
                                : 'e.g., Current Term (2021-2026), Candidate, Ex-Representative',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.history_edu),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Place
                        Text(
                          isHindi ? 'स्थान / क्षेत्र (वैकल्पिक)' : 'Place / Jurisdiction (Optional)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: person.placeController,
                          decoration: InputDecoration(
                            hintText: isHindi ? 'उदा. आमेर, जयपुर, राष्ट्रीय' : 'e.g., Amer Village, Jaipur, All India',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.place_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Photo Upload Control
                        Text(
                          isHindi ? 'फोटो (वैकल्पिक)' : 'Photo (Optional)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        _buildPhotoUploadSection(person, index, theme, isHindi),
                        const SizedBox(height: 12),

                        // Detailed Profile Fields Expansion
                        Theme(
                          data: theme.copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
                            title: Text(
                              isHindi
                                  ? 'विस्तृत प्रोफाइल विवरण (शिक्षा, कार्य, अनुभव, आदि)'
                                  : 'Detailed Profile Information (Work, Education, etc.)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            subtitle: Text(
                              isHindi
                                  ? 'पारदर्शी मूल्यांकन हेतु अतिरिक्त जानकारी जोड़ें'
                                  : 'Add optional background details for transparent evaluation',
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                            ),
                            children: [
                              // Bio / Description
                              Text(
                                isHindi ? 'संक्षिप्त परिचय / विवरण' : 'Short Biography / Profile Description',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: person.bioController,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  hintText: isHindi
                                      ? 'उदा. सामाजिक मुद्दों पर सक्रिय, जनहित कार्यों में अग्रणी'
                                      : 'e.g., Active in social causes and grassroots civic welfare',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  prefixIcon: const Icon(Icons.person_pin_outlined),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Work Background & Experience
                              Text(
                                isHindi ? 'कार्यक्षेत्र एवं अनुभव' : 'Work Background & Field Experience',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: person.workBackgroundController,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  hintText: isHindi
                                      ? 'उदा. 10 वर्ष कृषि एवं सहकारी समिति में प्रबंधन अनुभव'
                                      : 'e.g., 10 years in cooperative society management & agriculture',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  prefixIcon: const Icon(Icons.work_outline),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Public Service History & Work Performed
                              Text(
                                isHindi ? 'जनसेवा एवं कार्य इतिहास' : 'Public-Service History & Work Performed',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: person.publicServiceHistoryController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: isHindi
                                      ? 'उदा. गांव में पक्की सड़क, पेयजल पाइपलाइन और प्राथमिक स्वास्थ्य केंद्र निर्माण में योगदान'
                                      : 'e.g., Led village paved road project, water supply pipeline, and primary health clinic support',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  prefixIcon: const Icon(Icons.volunteer_activism_outlined),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Education / Qualification
                              Text(
                                isHindi ? 'शिक्षा / शैक्षणिक योग्यता' : 'Education / Qualification',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: person.educationController,
                                decoration: InputDecoration(
                                  hintText: isHindi
                                      ? 'उदा. स्नातकोत्तर (राजनीति विज्ञान), एल.एल.बी'
                                      : 'e.g., M.A. (Political Science), LL.B., Graduate',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  prefixIcon: const Icon(Icons.school_outlined),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Achievements & Contributions
                              Text(
                                isHindi ? 'प्रमुख उपलब्धियां एवं योगदान' : 'Notable Achievements & Contributions',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: person.achievementsController,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  hintText: isHindi
                                      ? 'उदा. आदर्श ग्राम पुरस्कार 2023, स्वच्छता अभियान में प्रथम स्थान'
                                      : 'e.g., Ideal Village Award 2023, Cleanliness Campaign 1st rank',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  prefixIcon: const Icon(Icons.emoji_events_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Privacy Notice for Optional Demographics
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.shade300),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.privacy_tip_outlined, size: 16, color: Colors.amber),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isHindi
                                            ? 'जाति/समुदाय एवं धर्म वैकल्पिक हैं। इन्हें केवल स्पष्ट रूप से घोषित या प्रमाणित होने पर ही दर्ज करें। कभी भी नाम या स्थान से अनुमान न लगाएं।'
                                            : 'Caste/community and religion are optional. Only enter explicitly declared or documented details. Never guess or infer.',
                                        style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Caste / Community
                              Text(
                                isHindi ? 'जाति / समुदाय (वैकल्पिक)' : 'Caste / Community (Optional)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: person.casteCommunityController,
                                decoration: InputDecoration(
                                  hintText: isHindi ? 'केवल यदि स्वेच्छा से घोषित हो' : 'Only if explicitly declared',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  prefixIcon: const Icon(Icons.people_outline),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Religion
                              Text(
                                isHindi ? 'धर्म (वैकल्पिक)' : 'Religion (Optional)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: person.religionController,
                                decoration: InputDecoration(
                                  hintText: isHindi ? 'केवल यदि स्वेच्छा से घोषित हो' : 'Only if explicitly declared',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  prefixIcon: const Icon(Icons.diversity_3_outlined),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Source Reference Citation
                              Text(
                                isHindi ? 'स्रोत संदर्भ / प्रमाणन संदर्भ' : 'Source Reference / Citation',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: person.sourceReferenceController,
                                decoration: InputDecoration(
                                  hintText: isHindi
                                      ? 'उदा. चुनाव आयोग हलफनामा 2024 / आधिकारिक पंचायत अभिलेख'
                                      : 'e.g., Election Commission Affidavit 2024 / Official Gazette',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  prefixIcon: const Icon(Icons.link_outlined),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),

              // Questions Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isHindi ? 'सर्वेक्षण के प्रश्न' : 'Poll Question(s)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  TextButton.icon(
                    onPressed: _addQuestion,
                    icon: const Icon(Icons.add_comment_outlined, size: 18),
                    label: Text(isHindi ? '+ प्रश्न जोड़ें' : '+ Add Question'),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              ...List.generate(_questions.length, (qIndex) {
                final q = _questions[qIndex];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isHindi
                                  ? 'प्रश्न #${qIndex + 1} *'
                                  : 'Question #${qIndex + 1} *',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            if (_questions.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                tooltip: isHindi ? 'हटाएं' : 'Remove',
                                onPressed: () => _removeQuestion(qIndex),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: q.textController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: isHindi
                                ? 'उदा. क्या आप इनके विकास कार्यों से संतुष्ट हैं?'
                                : 'e.g., Do you approve of their development work?',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            helperText: isHindi
                                ? 'प्रश्न निष्पक्ष रखें ताकि नागरिक समर्थन या असंतोष व्यक्त कर सकें।'
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
                        if (_people.length > 1) ...[
                          const SizedBox(height: 10),
                          DropdownButtonFormField<int?>(
                            initialValue: q.targetPersonIndex,
                            decoration: InputDecoration(
                              labelText: isHindi ? 'यह प्रश्न किस व्यक्ति पर लागू होता है?' : 'Evaluates Which Person?',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(isHindi ? 'सभी / सामान्य प्रश्न' : 'All / General Question'),
                              ),
                              ...List.generate(_people.length, (pIdx) {
                                final pName = _people[pIdx].nameController.text.trim();
                                return DropdownMenuItem<int?>(
                                  value: pIdx,
                                  child: Text(pName.isNotEmpty ? pName : 'Person #${pIdx + 1}'),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() => q.targetPersonIndex = val);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 14),

              // Context / Description
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

              // Flexible Duration (days, months, years)
              Text(
                isHindi ? 'सर्वेक्षण अवधि' : 'Poll Duration',
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
                  DropdownMenuItem(value: 180, child: Text(isHindi ? '180 दिन (6 महीने)' : '180 Days (6 Months)')),
                  DropdownMenuItem(value: 365, child: Text(isHindi ? '365 दिन (1 वर्ष)' : '365 Days (1 Year)')),
                  DropdownMenuItem(value: 730, child: Text(isHindi ? '730 दिन (2 वर्ष)' : '730 Days (2 Years)')),
                  DropdownMenuItem(value: 1825, child: Text(isHindi ? '1825 दिन (5 वर्ष)' : '1825 Days (5 Years)')),
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
