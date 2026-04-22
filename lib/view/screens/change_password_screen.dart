import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/widgets/glass_card.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _submitting = false;
  bool _hideOldPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No user logged in.')));
      return;
    }

    final email = (user.email ?? '').trim();
    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This account cannot change password with old password authentication.',
          ),
        ),
      );
      return;
    }

    final hasPasswordProvider = user.providerData.any(
      (provider) => provider.providerId == 'password',
    );
    if (!hasPasswordProvider) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password change is not available for social sign-in only accounts.',
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final oldPassword = _oldPasswordController.text.trim();
      final newPassword = _newPasswordController.text.trim();

      final credential = EmailAuthProvider.credential(
        email: email,
        password: oldPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'Failed to update password: ${e.message ?? e.code}';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Old password is incorrect.';
      } else if (e.code == 'weak-password') {
        message = 'New password must be at least 6 characters.';
      } else if (e.code == 'requires-recent-login') {
        message = 'Please login again and then change your password.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update password: $e')));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Change Password',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use your current password to set a new one.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withValues(alpha: 0.58),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        borderRadius: 16,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _oldPasswordController,
                                obscureText: _hideOldPassword,
                                decoration: InputDecoration(
                                  labelText: 'Old Password',
                                  prefixIcon: const Icon(
                                    Icons.password_rounded,
                                  ),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _hideOldPassword = !_hideOldPassword;
                                      });
                                    },
                                    icon: Icon(
                                      _hideOldPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if ((value ?? '').trim().isEmpty) {
                                    return 'Old password is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _newPasswordController,
                                obscureText: _hideNewPassword,
                                decoration: InputDecoration(
                                  labelText: 'New Password',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                  ),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _hideNewPassword = !_hideNewPassword;
                                      });
                                    },
                                    icon: Icon(
                                      _hideNewPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  final input = (value ?? '').trim();
                                  if (input.length < 6) {
                                    return 'New password must be at least 6 characters';
                                  }
                                  if (input ==
                                      _oldPasswordController.text.trim()) {
                                    return 'New password must be different from old password';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _hideConfirmPassword,
                                decoration: InputDecoration(
                                  labelText: 'Confirm New Password',
                                  prefixIcon: const Icon(
                                    Icons.lock_reset_rounded,
                                  ),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _hideConfirmPassword =
                                            !_hideConfirmPassword;
                                      });
                                    },
                                    icon: Icon(
                                      _hideConfirmPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if ((value ?? '').trim() !=
                                      _newPasswordController.text.trim()) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _submitting ? null : _submit,
                                  icon: _submitting
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.check_rounded),
                                  label: Text(
                                    _submitting
                                        ? 'Updating...'
                                        : 'Update Password',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.walletAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
