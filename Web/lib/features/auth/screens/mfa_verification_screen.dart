import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../../../core/providers/auth_provider.dart';
import '../../../core/routing/app_router.dart';
import '../widgets/auth_background.dart';

class MfaVerificationScreen extends ConsumerStatefulWidget {
  final int userId;
  const MfaVerificationScreen({super.key, required this.userId});

  @override
  ConsumerState<MfaVerificationScreen> createState() => _MfaVerificationScreenState();
}

class _MfaVerificationScreenState extends ConsumerState<MfaVerificationScreen> {
  final _codeControllers = List.generate(6, (index) => TextEditingController());
  final _focusNodes = List.generate(6, (index) => FocusNode());
  
  bool _isLoading = false;
  String _verificationCode = '';
  Timer? _timer;
  int _secondsRemaining = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    for (final controller in _codeControllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  void _onCodeChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    
    _updateVerificationCode();
  }

  void _updateVerificationCode() {
    _verificationCode = _codeControllers.map((c) => c.text).join();
    if (_verificationCode.length == 6) {
      _verifyCode();
    }
  }

  Future<void> _verifyCode() async {
    if (_verificationCode.length != 6) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await ref.read(authProvider.notifier).verifyEmail(widget.userId, _verificationCode);
      if (success && mounted) {
        context.go(AppRoutes.signin);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resendCode() {
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _startTimer();
    
    // Clear current code
    for (final controller in _codeControllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
    
    // Here you would call the resend API
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification code sent!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      onPressed: () => context.goBack(),
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
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Icon(
                      Icons.security,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  
                  // Title
                  Text(
                    'Verify Your Email',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Description
                  Text(
                    'Enter the 6-digit verification code sent to your email.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Code Input Fields
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 50,
                        child: TextFormField(
                          controller: _codeControllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onChanged: (value) => _onCodeChanged(index, value),
                        ),
                      );
                    }),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Verify Button
                  ElevatedButton(
                    onPressed: _isLoading || _verificationCode.length != 6 ? null : _verifyCode,
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
                          'Verify Email',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  
                  // Error Message
                  if (authState.error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Theme.of(context).colorScheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authState.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Resend Code
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Didn't receive the code? ",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (_canResend)
                        TextButton(
                          onPressed: _resendCode,
                          child: const Text('Resend'),
                        )
                      else
                        Text(
                          'Resend in ${_secondsRemaining}s',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // No demo code; rely on backend email code
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
