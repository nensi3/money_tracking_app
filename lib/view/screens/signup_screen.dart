import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:money_tracking_app/controller/services/category_service.dart';
import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/view/utils/app_input_decorations.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/widgets/auth_form_card.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final CategoryService _categoryService = CategoryService();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  Future<void> signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'photoUrl': '',
            'createdAt': FieldValue.serverTimestamp(),
            'joinedDate': Timestamp.now(),
            'role': 'User',
            'active': true,
            'transactionCount': 0,
          });

      await _categoryService.ensureDefaultCategories(uid: credential.user!.uid);
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String message = "Signup failed";

      if (e.code == 'email-already-in-use') {
        message = "Email already exists";
      } else if (e.code == 'weak-password') {
        message = "Password must be at least 6 characters";
      } else if (e.code == 'invalid-email') {
        message = "Invalid email address";
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Something went wrong")));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 40,
                  ),
                  child: Center(
                    child: AuthFormCard(
                      padding: const EdgeInsets.all(22),
                      opacity: 0.8,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 60,
                              color: AppColors.walletAccent,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Create Account",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),

                            TextFormField(
                              controller: _nameController,
                              decoration: AppInputDecorations.auth(
                                label: "Full Name",
                                prefix: Icons.person_outline,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return "Enter full name";
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: AppInputDecorations.auth(
                                label: "Phone Number",
                                prefix: Icons.phone_outlined,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return "Enter phone number";
                                }
                                if (v.trim().length < 10) {
                                  return "Enter valid phone number";
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: AppInputDecorations.auth(
                                label: "Email",
                                prefix: Icons.email_outlined,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return "Enter email";
                                }
                                if (!v.contains('@')) {
                                  return "Enter valid email";
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _passwordController,
                              obscureText: _hidePassword,
                              decoration: AppInputDecorations.auth(
                                label: "Password",
                                prefix: Icons.lock_outline,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _hidePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _hidePassword = !_hidePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return "Enter password";
                                }
                                if (v.length < 6) {
                                  return "Minimum 6 characters";
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _hideConfirmPassword,
                              decoration: AppInputDecorations.auth(
                                label: "Confirm Password",
                                prefix: Icons.lock_outline,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _hideConfirmPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _hideConfirmPassword =
                                          !_hideConfirmPassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return "Confirm your password";
                                }
                                if (v != _passwordController.text) {
                                  return "Passwords do not match";
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _loading ? null : signup,
                                child: _loading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text("Create Account"),
                              ),
                            ),

                            const SizedBox(height: 10),

                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                    },
                              child: const Text(
                                "Already have an account? Login",
                              ),
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
