import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/view/utils/app_input_decorations.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/widgets/auth_form_card.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;

  static final RegExp _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim().toLowerCase();
    const successMessage =
        'If this email is registered, check your inbox and spam folder.';

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'invalid-email' => 'Enter a valid email address',
        'user-not-found' => successMessage,
        'too-many-req  uests' => 'Too many attempts. Try again later.',
        'network-request-failed' =>
          'Network error. Check your connection and try again.',
        _ => 'Unable to send reset link',
      };

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Enter email';
    }

    if (!_emailRegExp.hasMatch(email)) {
      return 'Enter valid email';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 40,
                  ),
                  child: Center(
                    child: AuthFormCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 60,
                              color: AppColors.walletAccent,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Forgot Password',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Enter your email to receive a reset link',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              decoration: AppInputDecorations.auth(
                                label: 'Email',
                                prefix: Icons.email_outlined,
                              ),
                              validator: _validateEmail,
                              onFieldSubmitted: (_) {
                                if (!_isLoading) {
                                  _sendResetLink();
                                }
                              },
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _sendResetLink,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text('Send Reset Link'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                    },
                              child: const Text('Back to Login'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
