import 'package:flutter/material.dart';
import 'package:money_tracking_app/controller/services/mfa_service.dart';
import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'panels_dashboard_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String userId;
  final VoidCallback? onVerificationSuccess;
  final bool requiresBackupCode;

  const OTPVerificationScreen({
    super.key,
    required this.userId,
    this.onVerificationSuccess,
    this.requiresBackupCode = false,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final _mfaService = MFAService.instance;
  final _otpController = TextEditingController();
  final _backupCodeController = TextEditingController();
  bool _isVerifying = false;
  String? _errorMessage;
  bool _useBackupCode = false;

  Future<void> _handleVerificationSuccess() async {
    if (!mounted) return;

    if (widget.onVerificationSuccess != null) {
      widget.onVerificationSuccess!();
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            const PanelsDashboardScreen(initialPanel: PanelType.admin),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    _backupCodeController.dispose();
    super.dispose();
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter the verification code');
      return;
    }

    if (_otpController.text.length != 6) {
      setState(() => _errorMessage = 'Verification code must be 6 digits');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      print('ðŸ” OTP Verification started for user: ${widget.userId}');

      final mfaConfig = await _mfaService.getMFAConfig(widget.userId);
      if (mfaConfig == null) {
        throw Exception('MFA not configured');
      }

      print('ðŸ” MFA Config retrieved - isEnabled: ${mfaConfig.isEnabled}');

      final storedSecret = await _mfaService.getStoredSecret(widget.userId);
      print(
        'ðŸ” Stored secret from secure storage: ${storedSecret != null ? 'EXISTS' : 'NOT FOUND'}',
      );
      print(
        'ðŸ” Secret in Firestore: ${mfaConfig.secretKey != null ? 'EXISTS' : 'NOT FOUND'}',
      );

      final resolvedSecret = (storedSecret == null || storedSecret.isEmpty)
          ? (mfaConfig.secretKey ?? '')
          : storedSecret;

      if (resolvedSecret.isEmpty) {
        throw Exception('MFA secret not found');
      }

      print(
        'ðŸ” Using secret (first 8 chars): ${resolvedSecret.substring(0, 8)}...',
      );

      final isValid = _mfaService.verifyOTP(
        secret: resolvedSecret,
        code: _otpController.text,
      );

      if (!isValid) {
        if (mounted) {
          setState(
            () =>
                _errorMessage = 'Invalid verification code. Please try again.',
          );
        }
        return;
      }

      await _handleVerificationSuccess();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error verifying OTP: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _verifyBackupCode() async {
    if (_backupCodeController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter a backup code');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final isValid = await _mfaService.verifyBackupCode(
        uid: widget.userId,
        code: _backupCodeController.text,
      );

      if (!isValid) {
        if (mounted) {
          setState(
            () => _errorMessage = 'Invalid backup code. Please try again.',
          );
        }
        return;
      }

      await _handleVerificationSuccess();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error verifying backup code: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Header
                    const Icon(
                      Icons.security,
                      color: AppColors.walletAccent,
                      size: 50,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Verify Your Identity',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _useBackupCode
                          ? 'Enter your backup code'
                          : 'Enter the 6-digit code from Google Authenticator',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    // OTP Input Mode
                    if (!_useBackupCode) ...[
                      // Instructions
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: const Text(
                          'Open Google Authenticator and enter the 6-digit code shown for your account.',
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // OTP Code Input
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        enabled: !_isVerifying,
                        style: const TextStyle(
                          fontSize: 32,
                          letterSpacing: 12,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: '000000',
                          hintStyle: TextStyle(
                            color: Colors.black26,
                            fontSize: 32,
                            letterSpacing: 12,
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.75),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.walletAccent,
                              width: 2,
                            ),
                          ),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 30),
                    ] else ...[
                      // Backup Code Input
                      TextField(
                        controller: _backupCodeController,
                        keyboardType: TextInputType.number,
                        enabled: !_isVerifying,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter your 8-digit backup code',
                          hintStyle: const TextStyle(color: Colors.black38),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.75),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.walletAccent,
                              width: 2,
                            ),
                          ),
                          prefixIcon: const Icon(
                            Icons.vpn_key,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],

                    // Error Message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Verify Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isVerifying
                            ? null
                            : (_useBackupCode ? _verifyBackupCode : _verifyOTP),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.walletAccent,
                          disabledBackgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isVerifying
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                _useBackupCode
                                    ? 'Verify Backup Code'
                                    : 'Verify OTP',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Toggle Backup Code / OTP
                    TextButton(
                      onPressed: _isVerifying
                          ? null
                          : () {
                              setState(() {
                                _useBackupCode = !_useBackupCode;
                                _errorMessage = null;
                                _otpController.clear();
                                _backupCodeController.clear();
                              });
                            },
                      child: Text(
                        _useBackupCode
                            ? 'Use authenticator code instead?'
                            : 'Use backup code instead?',
                        style: const TextStyle(
                          color: AppColors.walletAccent,
                          fontSize: 14,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Two-Factor Authentication',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Your admin account requires two-factor authentication for security. Enter the code from your authenticator app to proceed.',
                            style: TextStyle(color: Colors.blue, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
