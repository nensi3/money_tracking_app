import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:money_tracking_app/model/user_model.dart';
import 'package:money_tracking_app/controller/services/auth_service.dart';
import 'package:money_tracking_app/controller/services/category_service.dart';
import 'package:money_tracking_app/controller/services/firestore_service.dart';
import 'package:money_tracking_app/controller/services/mfa_service.dart';
import 'package:money_tracking_app/controller/services/notification_service.dart';
import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/view/utils/app_input_decorations.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/widgets/auth_form_card.dart';
import 'package:money_tracking_app/view/panels/user_panel/user_panel_screen.dart';
import 'maintenance_screen.dart';
import 'forgot_password_screen.dart';
import 'otp_verification_screen.dart';
import 'panels_dashboard_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? initialMessage;
  final bool adminOnly;

  const LoginScreen({super.key, this.initialMessage, this.adminOnly = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  final CategoryService _categoryService = CategoryService();
  final MFAService _mfaService = MFAService.instance;

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.initialMessage!),
            backgroundColor: Colors.red,
          ),
        );
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await NotificationService.instance.syncCurrentUserToken();
      if (credential.user != null) {
        await _updateLastLogin(credential.user!);
      }
      await _routeAfterLogin(credential.user);

      if (!mounted) return;
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';

      if (e.code == 'user-not-found') {
        message = 'No user found for this email';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email';
      } else if (e.code == 'invalid-credential') {
        message = 'Invalid email or password';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Something went wrong')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _isLoading = true);

    try {
      final user = await AuthService.instance.signInWithGoogle();

      if (user != null) {
        await _syncGoogleUserProfile(user);
        await NotificationService.instance.syncCurrentUserToken();
        await _updateLastLogin(user);
        await _routeAfterLogin(user);

        if (!mounted) return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google sign-in failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _routeAfterLogin(User? authUser) async {
    if (authUser == null || !mounted) return;
    final refreshed = FirebaseAuth.instance.currentUser ?? authUser;

    final isAdmin = await _firestoreService.isUserAdmin(
      refreshed.uid,
      email: refreshed.email,
    );

    if (widget.adminOnly && !isAdmin) {
      await AuthService.instance.logout();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This account is not an admin account.')),
      );
      return;
    }

    if (!mounted) return;

    final maintenanceMode = await _firestoreService.isMaintenanceModeEnabled();

    if (!mounted) return;

    // If user is Admin, check MFA status
    if (isAdmin) {
      final requiresMFA = await _mfaService.isMFAEnabled(refreshed.uid);

      if (!mounted) return;

      if (requiresMFA) {
        // Navigate to OTP verification screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OTPVerificationScreen(userId: refreshed.uid),
          ),
        );
        return;
      }

      // MFA is optional from settings. If it is disabled, continue to admin.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const PanelsDashboardScreen(initialPanel: PanelType.admin),
        ),
      );
      return;
    }

    if (maintenanceMode) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MaintenanceScreen()),
      );
      return;
    }

    try {
      await _categoryService.ensureDefaultCategories(uid: refreshed.uid);
    } catch (e) {
      print('âš ï¸ Failed to ensure default categories: $e');
    }

    // Non-admin users open the user panel.
    final nextPage = const UserPanelScreen();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextPage),
    );
  }

  Future<void> _syncGoogleUserProfile(User authUser) async {
    final existingUser = await _firestoreService.getUserById(authUser.uid);
    final photoUrl = (authUser.photoURL ?? '').trim();
    final displayName = (authUser.displayName ?? '').trim();

    if (existingUser == null) {
      await _firestoreService.setUser(
        UserModel(
          uid: authUser.uid,
          name: displayName.isNotEmpty
              ? displayName
              : (authUser.email ?? 'User').split('@').first,
          email: authUser.email ?? '',
          role: 'User',
          active: true,
          joinedDate: DateTime.now(),
          transactionCount: 0,
        ),
      );
    }

    if (photoUrl.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .set(
            {
              'photoUrl': photoUrl,
              'name': displayName.isNotEmpty ? displayName : null,
              'email': authUser.email,
            }..removeWhere((key, value) => value == null),
            SetOptions(merge: true),
          );
    }
  }

  Future<void> _updateLastLogin(User authUser) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .set({
            'lastLoginAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      print('âš ï¸ Failed to update lastLoginAt: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final welcomeTitle = widget.adminOnly ? 'Welcome Admin' : 'Welcome';
    final subtitle = widget.adminOnly
        ? 'Admin sign-in required to access the panel'
        : 'Login or create account to continue';

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
                            Text(
                              welcomeTitle,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                            if (widget.adminOnly) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Admin access required',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: AppInputDecorations.auth(
                                label: 'Email',
                                prefix: Icons.email_outlined,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter email';
                                }
                                if (!value.contains('@')) {
                                  return 'Enter valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: AppInputDecorations.auth(
                                label: 'Password',
                                prefix: Icons.lock_outline,
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter password';
                                }
                                if (value.trim().length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ForgotPasswordScreen(),
                                          ),
                                        );
                                      },
                                child: const Text('Forgot Password?'),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text('Login'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                icon: Image.asset(
                                  'assets/google_logo.png',
                                  height: 22,
                                ),
                                label: const Text('Continue with Google'),
                                onPressed: _isLoading ? null : _googleLogin,
                              ),
                            ),
                            if (!widget.adminOnly) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const SignupScreen(),
                                            ),
                                          );
                                        },
                                  child: const Text('Create Account'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: TextButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const LoginScreen(
                                                adminOnly: true,
                                              ),
                                            ),
                                          );
                                        },
                                  icon: const Icon(
                                    Icons.admin_panel_settings_rounded,
                                  ),
                                  label: const Text('Admin Login'),
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
            },
          ),
        ),
      ),
    );
  }
}
