import 'package:flutter/material.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../services/auth_service.dart';

class PasswordResetPage extends StatefulWidget {
  final AuthService authService;
  final String? initialEmail;
  final VoidCallback? onResetSuccess;

  const PasswordResetPage({
    super.key,
    required this.authService,
    this.initialEmail,
    this.onResetSuccess,
  });

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _requestFormKey = GlobalKey<FormState>();
  final _confirmFormKey = GlobalKey<FormState>();

  late final TextEditingController _emailController;
  late final TextEditingController _tokenController;
  late final TextEditingController _newPasswordController;

  bool _obscurePassword = true;
  bool _isRequesting = false;
  bool _isConfirming = false;
  bool _isResetSuccess = false;

  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    _tokenController = TextEditingController();
    _newPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestReset() async {
    if (!_requestFormKey.currentState!.validate()) return;

    setState(() {
      _isRequesting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final email = _emailController.text.trim();
    final result = await widget.authService.requestPasswordReset(email);

    if (!mounted) return;

    setState(() {
      _isRequesting = false;
    });

    if (result.isSuccess) {
      setState(() {
        _successMessage = result.data?.message.isNotEmpty == true
            ? result.data!.message
            : 'If an account exists with this email, password reset instructions have been sent.';
      });
    } else {
      setState(() {
        _errorMessage = result.failure?.message ?? 'Failed to send password reset instructions';
      });
    }
  }

  Future<void> _handleConfirmReset() async {
    if (!_confirmFormKey.currentState!.validate()) return;

    setState(() {
      _isConfirming = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final token = _tokenController.text.trim();
    final newPassword = _newPasswordController.text;

    final result = await widget.authService.resetPassword(token, newPassword);

    if (!mounted) return;

    setState(() {
      _isConfirming = false;
    });

    if (result.isSuccess) {
      setState(() {
        _isResetSuccess = true;
        _successMessage = result.data?.message.isNotEmpty == true
            ? result.data!.message
            : 'Password reset successful. Please log in with your new password.';
      });
      if (widget.onResetSuccess != null) {
        widget.onResetSuccess!();
      }
    } else {
      setState(() {
        _errorMessage = result.failure?.message ?? 'Password reset failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.passwordResetTitle),
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
                    Icons.lock_reset_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.passwordResetTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
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

                  if (_isResetSuccess) ...[
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.login),
                      label: Text(l10n.loginButton),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ] else ...[
                    // Step 1: Request Reset
                    Form(
                      key: _requestFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleRequestReset(),
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
                          FilledButton(
                            onPressed: _isRequesting || _isConfirming ? null : _handleRequestReset,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isRequesting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(l10n.requestResetButton),
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
                            'ENTER TOKEN',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.resetPasswordHelper,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Step 2: Confirm Reset
                    Form(
                      key: _confirmFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _tokenController,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: l10n.resetTokenLabel,
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
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleConfirmReset(),
                            decoration: InputDecoration(
                              labelText: l10n.newPasswordLabel,
                              prefixIcon: const Icon(Icons.lock_reset_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.length < 8) {
                                return l10n.shortPasswordError;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _isRequesting || _isConfirming ? null : _handleConfirmReset,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isConfirming
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(l10n.confirmResetButton),
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
