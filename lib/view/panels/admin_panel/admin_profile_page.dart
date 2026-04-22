import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:money_tracking_app/controller/services/firestore_service.dart';
import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/widgets/glass_card.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _firestoreService = FirestoreService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSavingProfile = false;
  bool _isChangingPassword = false;
  bool _hidePassword = true;
  String _role = 'admin';
  bool _active = true;
  DateTime? _joinedDate;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final profile = await _firestoreService.getUserById(user.uid);
    _role = (profile?.role ?? 'admin').trim();
    _active = profile?.active ?? true;
    _joinedDate = profile?.joinedDate;

    _nameController.text =
        (profile?.name ?? user.displayName ?? 'Administrator').trim();
    _emailController.text = (profile?.email ?? user.email ?? '').trim();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isSavingProfile = true);

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();

      await user.updateDisplayName(name);

      if (email != user.email) {
        await user.verifyBeforeUpdateEmail(email);
      }

      final existingProfile = await _firestoreService.getUserById(user.uid);
      if (existingProfile != null) {
        await _firestoreService.setUser(
          existingProfile.copyWith(name: name, email: email),
        );
      } else {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': name,
          'email': email,
          'role': 'admin',
          'active': true,
          'joinedDate': Timestamp.fromDate(DateTime.now()),
          'transactionCount': 0,
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            email == user.email
                ? 'Profile updated successfully.'
                : 'Profile saved. Check your inbox to verify the new email.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'requires-recent-login'
          ? 'Please log in again before changing email.'
          : 'Failed to update profile: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isChangingPassword = true);

    try {
      final email = user.email;
      if (email == null || email.isEmpty) {
        throw Exception('Current account email is unavailable.');
      }

      final oldPassword = _oldPasswordController.text.trim();
      final credential = EmailAuthProvider.credential(
        email: email,
        password: oldPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text.trim());
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'requires-recent-login'
          ? 'Please log in again before changing password.'
          : 'Failed to update password: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update password: $e')));
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = _auth.currentUser;
    final displayName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (authUser?.displayName?.trim().isNotEmpty == true
              ? authUser!.displayName!.trim()
              : 'Administrator');
    final email = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : (authUser?.email ?? 'No email');
    final role = _role.trim().isNotEmpty ? _role.trim() : 'admin';
    final uid = authUser?.uid ?? '';
    final heroTag = uid.isEmpty
        ? 'admin-profile-avatar'
        : 'admin-profile-avatar-$uid';

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GlassCard(
                            borderRadius: 26,
                            padding: const EdgeInsets.all(18),
                            opacity: 0.86,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.walletAccent.withValues(
                                      alpha: 0.18,
                                    ),
                                    Colors.white.withValues(alpha: 0.12),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(26),
                              ),
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        icon: const Icon(
                                          Icons.arrow_back_rounded,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Admin Profile',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _active
                                              ? Colors.green.withValues(
                                                  alpha: 0.14,
                                                )
                                              : Colors.red.withValues(
                                                  alpha: 0.14,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          _active ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: _active
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Hero(
                                        tag: heroTag,
                                        child: Container(
                                          width: 74,
                                          height: 74,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppColors.walletAccent,
                                                AppColors.walletAccent
                                                    .withValues(alpha: 0.72),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.walletAccent
                                                    .withValues(alpha: 0.22),
                                                blurRadius: 18,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            displayName.isNotEmpty
                                                ? displayName[0].toUpperCase()
                                                : 'A',
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              displayName,
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              email,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.72),
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: [
                                                _ProfileBadge(
                                                  icon: Icons.badge_outlined,
                                                  label: role,
                                                ),
                                                _ProfileBadge(
                                                  icon: Icons
                                                      .verified_user_outlined,
                                                  label:
                                                      (authUser
                                                              ?.emailVerified ??
                                                          false)
                                                      ? 'Email verified'
                                                      : 'Email pending',
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const _SectionHeader(
                            title: 'Account Details',
                            subtitle: 'Identity, access, and audit information',
                          ),
                          const SizedBox(height: 10),
                          GlassCard(
                            borderRadius: 24,
                            padding: const EdgeInsets.all(18),
                            opacity: 0.82,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ProfileDetailRow(
                                  label: 'UID',
                                  value: authUser?.uid ?? 'N/A',
                                ),
                                const SizedBox(height: 10),
                                _ProfileDetailRow(label: 'Role', value: role),
                                const SizedBox(height: 10),
                                _ProfileDetailRow(
                                  label: 'Account Status',
                                  value: _active ? 'Active' : 'Inactive',
                                ),
                                const SizedBox(height: 10),
                                _ProfileDetailRow(
                                  label: 'Email Verified',
                                  value: (authUser?.emailVerified ?? false)
                                      ? 'Yes'
                                      : 'No',
                                ),
                                const SizedBox(height: 10),
                                _ProfileDetailRow(
                                  label: 'Joined Date',
                                  value: _formatDate(_joinedDate),
                                ),
                                const SizedBox(height: 10),
                                _ProfileDetailRow(
                                  label: 'Last Sign In',
                                  value: _formatDate(
                                    authUser?.metadata.lastSignInTime,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const _SectionHeader(
                            title: 'Profile Edit',
                            subtitle: 'Update your admin profile details',
                          ),
                          const SizedBox(height: 10),
                          GlassCard(
                            borderRadius: 24,
                            padding: const EdgeInsets.all(18),
                            opacity: 0.82,
                            child: Form(
                              key: _profileFormKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextFormField(
                                    controller: _nameController,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: _fieldDecoration(
                                      labelText: 'Full Name',
                                      icon: Icons.person_outline,
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Name is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: _fieldDecoration(
                                      labelText: 'Email',
                                      icon: Icons.email_outlined,
                                    ),
                                    validator: (v) {
                                      final value = (v ?? '').trim();
                                      if (value.isEmpty ||
                                          !value.contains('@')) {
                                        return 'Enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: _GradientActionButton(
                                      onPressed: _isSavingProfile
                                          ? null
                                          : _saveProfile,
                                      label: 'Save Profile',
                                      isLoading: _isSavingProfile,
                                      gradientColors: [
                                        AppColors.walletAccent,
                                        AppColors.walletAccent.withValues(
                                          alpha: 0.72,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const _SectionHeader(
                            title: 'Security',
                            subtitle: 'Change your password with confirmation',
                          ),
                          const SizedBox(height: 10),
                          GlassCard(
                            borderRadius: 24,
                            padding: const EdgeInsets.all(18),
                            opacity: 0.82,
                            child: Form(
                              key: _passwordFormKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextFormField(
                                    controller: _oldPasswordController,
                                    obscureText: _hidePassword,
                                    decoration: _fieldDecoration(
                                      labelText: 'Old Password',
                                      icon: Icons.password_rounded,
                                      suffixIcon: IconButton(
                                        onPressed: () {
                                          setState(
                                            () =>
                                                _hidePassword = !_hidePassword,
                                          );
                                        },
                                        icon: Icon(
                                          _hidePassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                        ),
                                      ),
                                    ),
                                    validator: (v) {
                                      if ((v ?? '').trim().isEmpty) {
                                        return 'Old password is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _newPasswordController,
                                    obscureText: _hidePassword,
                                    decoration: _fieldDecoration(
                                      labelText: 'New Password',
                                      icon: Icons.lock_outline,
                                      suffixIcon: IconButton(
                                        onPressed: () {
                                          setState(
                                            () =>
                                                _hidePassword = !_hidePassword,
                                          );
                                        },
                                        icon: Icon(
                                          _hidePassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                        ),
                                      ),
                                    ),
                                    validator: (v) {
                                      final value = (v ?? '').trim();
                                      if (value.length < 6) {
                                        return 'Password must be at least 6 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _hidePassword,
                                    decoration: _fieldDecoration(
                                      labelText: 'Confirm Password',
                                      icon: Icons.lock_reset_outlined,
                                    ),
                                    validator: (v) {
                                      if ((v ?? '').trim() !=
                                          _newPasswordController.text.trim()) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: _GradientActionButton(
                                      onPressed: _isChangingPassword
                                          ? null
                                          : _changePassword,
                                      label: 'Update Password',
                                      isLoading: _isChangingPassword,
                                      gradientColors: const [
                                        Colors.deepOrange,
                                        Color(0xFFFF8A50),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String labelText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.74),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppColors.walletAccent, width: 1.5),
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    final d = dt.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _ProfileDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: onSurface.withValues(alpha: 0.64),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: onSurface.withValues(alpha: 0.68),
          ),
        ),
      ],
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProfileBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.walletAccent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final List<Color> gradientColors;

  const _GradientActionButton({
    required this.onPressed,
    required this.label,
    required this.isLoading,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: enabled
                  ? gradientColors
                  : [Colors.grey.shade400, Colors.grey.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (enabled ? gradientColors.first : Colors.grey)
                    .withValues(alpha: 0.22),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
