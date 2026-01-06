import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../widgets/auth_background.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _verifyFormKey = GlobalKey<FormState>();
  final _commitFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  _ForgotStage _stage = _ForgotStage.email;
  String? _ticket;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final ok = await ref
          .read(authProvider.notifier)
          .startForgotPasswordByEmail(_emailController.text.trim());

      if (!mounted) return;
      if (ok) {
        setState(() {
          _stage = _ForgotStage.verify;
          _codeController.text = '';
        });
      } else {
        final err = ref.read(authProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err ?? 'Failed to send verification code')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verify() async {
    if (!(_verifyFormKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final ticket =
          await ref.read(authProvider.notifier).verifyForgotPasswordByEmail(
                email: _emailController.text.trim(),
                code: _codeController.text.trim(),
              );

      if (!mounted) return;
      if (ticket != null && ticket.isNotEmpty) {
        setState(() {
          _ticket = ticket;
          _stage = _ForgotStage.commit;
          _newPasswordController.text = '';
          _confirmPasswordController.text = '';
          _showNewPassword = false;
          _showConfirmPassword = false;
        });
      } else {
        final err = ref.read(authProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err ?? 'Invalid verification code')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _commit() async {
    if (!(_commitFormKey.currentState?.validate() ?? false)) return;
    final ticket = _ticket;
    if (ticket == null || ticket.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Missing verification ticket. Please restart.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final ok = await ref.read(authProvider.notifier).commitForgotPassword(
            ticket: ticket,
            newPassword: _newPasswordController.text.trim(),
          );
      if (!mounted) return;

      if (ok) {
        setState(() => _stage = _ForgotStage.done);
      } else {
        final err = ref.read(authProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err ?? 'Failed to reset password')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: AuthBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back Button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Icon
                  Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Icon(
                      _stage == _ForgotStage.done
                          ? Icons.check_circle_outline
                          : Icons.lock_reset,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),

                  // Title
                  Text(
                    switch (_stage) {
                      _ForgotStage.email => 'Reset Password',
                      _ForgotStage.verify => 'Verify Email Code',
                      _ForgotStage.commit => 'Create New Password',
                      _ForgotStage.done => 'Password Reset',
                    },
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // Description
                  Text(
                    switch (_stage) {
                      _ForgotStage.email =>
                        'Enter your email address and we\'ll send you a 6-digit code.',
                      _ForgotStage.verify =>
                        'Enter the 6-digit code sent to ${_emailController.text.trim()}.',
                      _ForgotStage.commit =>
                        'Set a new password for your account.',
                      _ForgotStage.done =>
                        'Your password has been updated. Please sign in again.',
                    },
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  if (_stage == _ForgotStage.email) ...[
                    Form(
                      key: _emailFormKey,
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _start(),
                        decoration: InputDecoration(
                          labelText: l10n.email,
                          prefixIcon: const Icon(Icons.email_outlined),
                          helperText:
                              'Enter the email associated with your account',
                        ),
                        validator: (value) {
                          final v = (value ?? '').trim();
                          if (v.isEmpty) return 'Please enter your email';
                          if (!v.contains('@'))
                            return 'Please enter a valid email';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _start,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Send Code',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ] else if (_stage == _ForgotStage.verify) ...[
                    Form(
                      key: _verifyFormKey,
                      child: TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _verify(),
                        decoration: const InputDecoration(
                          labelText: 'Verification code',
                          prefixIcon: Icon(Icons.verified_outlined),
                          helperText: 'Enter the 6-digit code',
                        ),
                        validator: (value) {
                          final v = (value ?? '').trim();
                          if (v.length != 6) return 'Enter the 6-digit code';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _verify,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Verify Code',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _stage = _ForgotStage.email;
                                _codeController.text = '';
                              });
                            },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Change email'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isLoading ? null : _start,
                      child: const Text('Resend code'),
                    ),
                  ] else if (_stage == _ForgotStage.commit) ...[
                    Form(
                      key: _commitFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: !_showNewPassword,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'New password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                    () => _showNewPassword = !_showNewPassword),
                                icon: Icon(_showNewPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                              ),
                            ),
                            validator: (value) {
                              final v = (value ?? '').trim();
                              if (v.length < 6)
                                return 'Password must be at least 6 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: !_showConfirmPassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _commit(),
                            decoration: InputDecoration(
                              labelText: 'Confirm password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() =>
                                    _showConfirmPassword =
                                        !_showConfirmPassword),
                                icon: Icon(_showConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                              ),
                            ),
                            validator: (value) {
                              final v = (value ?? '').trim();
                              if (v != _newPasswordController.text.trim())
                                return 'Passwords do not match';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _commit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Reset Password',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ] else ...[
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Back to ${l10n.signIn}'),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Inline error from provider (if any)
                  if (authState.error != null &&
                      authState.error!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      authState.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],

                  if (_stage != _ForgotStage.done) ...[
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.of(context).pop(),
                      child: Text(
                        'Back to ${l10n.signIn}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary),
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

enum _ForgotStage { email, verify, commit, done }
