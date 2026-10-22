import 'package:flutter/material.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../services/auth_service.dart';

class VerifyEmailPage extends StatefulWidget {
  final AuthService authService;
  final String? initialEmail;
  final VoidCallback? onVerificationSuccess;

  const VerifyEmailPage({
    super.key,
    required this.authService,
    this.initialEmail,
    this.onVerificationSuccess,
  });

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _tokenFormKey = GlobalKey<FormState>();
  final _resendFormKey = GlobalKey<FormState>();

  late final TextEditingController _tokenController;
  late final TextEditingController _emailController;

  bool _isVerifying = false;
  bool _isResending = false;
  bool _isVerified = false;

  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyToken() async {
    if (!_tokenFormKey.currentState!.validate()) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final token = _tokenController.text.trim();
    final result = await widget.authService.verifyEmail(token);

    if (!mounted) return;

    setState(() {
      _isVerifying = false;
    });

    if (result.isSuccess) {
      setState(() {
        _isVerified = true;
        _successMessage = result.data?.message.isNotEmpty == true
            ? result.data!.message
            : 'Email verified successfully. You can now sign in.';
      });
      if (widget.onVerificationSuccess != null) {
        widget.onVerificationSuccess!();
      }
    } else {
      setState(() {
        _errorMessage = result.failure?.message ?? 'Verification failed';
      });
    }
  }

  Future<void> _handleResendVerification() async {
    if (!_resendFormKey.currentState!.validate()) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final email = _emailController.text.trim();
    final result = await widget.authService.resendVerificationEmail(email);

    if (!mounted) return;

    setState(() {
      _isResending = false;
    });

    if (result.isSuccess) {
      setState(() {
        _successMessage = result.data?.message.isNotEmpty == true
            ? result.data!.message
            : 'If an unverified account exists with this email, verification instructions have been sent.';
      });
    } else {
      setState(() {
        _errorMessage = result.failure?.message ?? 'Failed to send verification link';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.verifyEmailTitle),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.verifyEmailTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.verifyEmailHelper,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_successMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: TextStyle(color: Colors.green.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: theme.colorScheme.onErrorContainer),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_isVerified) ...[
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.login),
                      label: Text(l10n.loginButton),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ] else ...[
                    // Section 1: Submit token
                    Form(
                      key: _tokenFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _tokenController,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleVerifyToken(),
                            decoration: InputDecoration(
                              labelText: l10n.verificationTokenLabel,
                              hintText: l10n.verificationTokenHint,
                              prefixIcon: const Icon(Icons.key_outlined),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return l10n.enterTokenError;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _isVerifying || _isResending ? null : _handleVerifyToken,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isVerifying
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(l10n.verifyEmailButton),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'OR',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Section 2: Resend verification email
                    Form(
                      key: _resendFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.resendVerificationTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleResendVerification(),
                            decoration: InputDecoration(
                              labelText: l10n.emailLabel,
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty || !value.contains('@')) {
                                return l10n.invalidEmailError;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _isVerifying || _isResending ? null : _handleResendVerification,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isResending
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(l10n.resendVerificationButton),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
