import 'package:flutter/material.dart';
import 'package:money_tracking_app/controller/services/mfa_service.dart';
import 'package:money_tracking_app/controller/services/auth_service.dart';
import 'package:money_tracking_app/view/screens/mfa_setup_screen.dart';
import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/widgets/glass_card.dart';

class MFASettingsPage extends StatefulWidget {
  const MFASettingsPage({super.key});

  @override
  State<MFASettingsPage> createState() => _MFASettingsPageState();
}

class _MFASettingsPageState extends State<MFASettingsPage> {
  final _mfaService = MFAService.instance;
  final _authService = AuthService.instance;
  late Future<bool> _mfaEnabledFuture;

  @override
  void initState() {
    super.initState();
    _mfaEnabledFuture = _loadMFAStatus();
  }

  Future<bool> _loadMFAStatus() async {
    final currentUser = _authService.getCurrentUser();
    if (currentUser == null) return false;

    final isEnabled = await _mfaService.isMFAEnabled(currentUser.uid);
    return isEnabled;
  }

  Future<void> _disableMFA() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Disable Two-Factor Authentication?'),
        content: const Text(
          'Disabling MFA will make your admin account less secure. '
          'You can enable it again anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _mfaService.disableMFA();

      if (mounted) {
        setState(() {
          _mfaEnabledFuture = _loadMFAStatus();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Two-Factor Authentication disabled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error disabling MFA: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _displayBackupCodes() {
    final currentUser = _authService.getCurrentUser();
    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Backup Codes'),
        content: const Text(
          'If you lose access to your authenticator app, you can use these backup codes to sign in. '
          'Each code can only be used once.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: FutureBuilder<bool>(
                  future: _mfaEnabledFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading MFA status: ${snapshot.error}',
                        ),
                      );
                    }

                    final isMFAEnabled = snapshot.data ?? false;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'MFA Settings',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Header
                        const Text(
                          'Two-Factor Authentication (MFA)',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add an extra layer of security to your admin account',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                        const SizedBox(height: 24),

                        // Status Card
                        GlassCard(
                          borderRadius: 16,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [
                                  isMFAEnabled
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.orange.withValues(alpha: 0.2),
                                  isMFAEnabled
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.orange.withValues(alpha: 0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isMFAEnabled
                                        ? Colors.green.withValues(alpha: 0.3)
                                        : Colors.orange.withValues(alpha: 0.3),
                                  ),
                                  child: Icon(
                                    isMFAEnabled
                                        ? Icons.check_circle
                                        : Icons.info,
                                    color: isMFAEnabled
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isMFAEnabled
                                            ? 'Two-Factor Authentication is Enabled'
                                            : 'Two-Factor Authentication is Disabled',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isMFAEnabled
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isMFAEnabled
                                            ? 'Your account is protected with Google Authenticator'
                                            : 'Enable MFA to secure your admin account',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Information Card
                        GlassCard(
                          borderRadius: 16,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.blue.withValues(alpha: 0.1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.info,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'About MFA',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Two-Factor Authentication (2FA) adds an extra layer of security to your account. '
                                  'Even if someone has your password, they will need your authenticator app to log in.\n\n'
                                  'We use Google Authenticator (TOTP) which generates a unique 6-digit code every 30 seconds.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        if (isMFAEnabled) ...[
                          GlassCard(
                            borderRadius: 16,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Security Options',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _displayBackupCodes,
                                      icon: const Icon(Icons.vpn_key),
                                      label: const Text('View Backup Codes'),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: Colors.black26,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        foregroundColor: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _disableMFA,
                                      icon: const Icon(Icons.lock_open),
                                      label: const Text('Disable MFA'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.withValues(
                                          alpha: 0.8,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          GlassCard(
                            borderRadius: 16,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.purple.withValues(alpha: 0.2),
                                    Colors.blue.withValues(alpha: 0.2),
                                  ],
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Enable Two-Factor Authentication',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Protect your admin account with an additional verification step during login.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        _showEnableMFADialog();
                                      },
                                      icon: const Icon(Icons.security),
                                      label: const Text('Enable MFA'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.walletAccent,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // FAQ Section
                        GlassCard(
                          borderRadius: 16,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.black.withValues(alpha: 0.3),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'FAQ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildFAQItem(
                                  question: 'What apps can I use?',
                                  answer:
                                      'Google Authenticator, Microsoft Authenticator, Authy, and other TOTP-compatible apps.',
                                ),
                                _buildFAQItem(
                                  question: 'What if I lose my phone?',
                                  answer:
                                      'Use your backup codes to sign in. Each code can be used once.',
                                ),
                                _buildFAQItem(
                                  question: 'Can I disable MFA?',
                                  answer:
                                      'Yes, you can disable it anytime from this page.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem({required String question, required String answer}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _showEnableMFADialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enable Two-Factor Authentication?'),
        content: const Text(
          'You will need to set up Google Authenticator on your device. '
          'Make sure you have access to your phone before proceeding.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openMFASetup();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.walletAccent,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _openMFASetup() async {
    final currentUser = _authService.getCurrentUser();
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please login again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MFASetupScreen(
            email: (currentUser.email ?? 'admin').trim(),
            onMFAEnabled: () {
              if (!mounted) return;

              setState(() {
                _mfaEnabledFuture = _loadMFAStatus();
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Two-Factor Authentication enabled'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ),
      );

      if (mounted) {
        setState(() {
          _mfaEnabledFuture = _loadMFAStatus();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
