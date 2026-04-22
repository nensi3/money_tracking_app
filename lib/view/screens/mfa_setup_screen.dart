import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:money_tracking_app/controller/services/mfa_service.dart';
import 'package:money_tracking_app/model/mfa_model.dart';
import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';

class MFASetupScreen extends StatefulWidget {
  final String email;
  final VoidCallback onMFAEnabled;

  const MFASetupScreen({
    super.key,
    required this.email,
    required this.onMFAEnabled,
  });

  @override
  State<MFASetupScreen> createState() => _MFASetupScreenState();
}

class _MFASetupScreenState extends State<MFASetupScreen> {
  final _mfaService = MFAService.instance;
  final _verificationController = TextEditingController();
  late Future<_MFASetupData> _setupFuture;
  bool _isVerifying = false;
  bool _showBackupCodes = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupFuture = _generateTOTPSetup();
  }

  Future<_MFASetupData> _generateTOTPSetup() async {
    final setup = await _mfaService.generateTOTPSecret(
      email: widget.email,
      appName: 'Money Tracking App',
    );
    return _MFASetupData(setup);
  }

  Future<void> _verifyAndEnable() async {
    if (_verificationController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter the verification code');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final setupData = await _setupFuture;
      final isValid = _mfaService.verifyOTP(
        secret: setupData.setup.secret,
        code: _verificationController.text,
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

      // Enable MFA
      await _mfaService.enableMFA(
        secret: setupData.setup.secret,
        backupCodes: setupData.setup.backupCodes,
      );

      if (mounted) {
        setState(() => _showBackupCodes = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error enabling MFA: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  void _continueToDashboard() {
    Navigator.of(context).pop();
    widget.onMFAEnabled();
  }

  @override
  void dispose() {
    _verificationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: FutureBuilder<_MFASetupData>(
              future: _setupFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 600,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error generating QR code: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final setupData = snapshot.data!;
                final setup = setupData.setup;

                if (_showBackupCodes) {
                  return _buildBackupCodesView(setup.backupCodes);
                }

                return Column(
                  children: [
                    // Header
                    const SizedBox(height: 20),
                    const Text(
                      'Set Up Two-Factor Authentication',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Secure your Admin account with Google Authenticator',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),

                    // Step 1: Download App
                    _buildStepCard(
                      number: '1',
                      title: 'Download Google Authenticator',
                      description:
                          'Install the app on your smartphone if not already done',
                      icon: Icons.download,
                    ),
                    const SizedBox(height: 20),

                    // Step 2: Scan QR Code
                    _buildStepCard(
                      number: '2',
                      title: 'Scan QR Code',
                      description: 'Use Google Authenticator to scan this code',
                      icon: Icons.qr_code_scanner,
                    ),
                    const SizedBox(height: 20),

                    // QR Code Display
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: 250,
                        height: 250,
                        child: CustomPaint(
                          painter: QrPainter(
                            data: setup.otpauthUrl,
                            version: QrVersions.auto,
                            gapless: false,
                            emptyColor: Colors.white,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Manual Entry Alternative
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Can\'t scan? Enter manually:',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            setup.secret,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              fontFamily: 'Courier',
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Step 3: Enter Code
                    _buildStepCard(
                      number: '3',
                      title: 'Enter Verification Code',
                      description:
                          'Type the 6-digit code from your authenticator',
                      icon: Icons.security,
                    ),
                    const SizedBox(height: 20),

                    // Verification Code Input
                    TextField(
                      controller: _verificationController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      enabled: !_isVerifying,
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 8,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: '000000',
                        hintStyle: TextStyle(
                          color: Colors.black26,
                          fontSize: 24,
                          letterSpacing: 8,
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

                    // Error Message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],

                    const SizedBox(height: 30),

                    // Verify Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isVerifying ? null : _verifyAndEnable,
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
                            : const Text(
                                'Verify & Enable MFA',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Cancel Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isVerifying
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.black26),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String number,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.walletAccent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupCodesView(List<String> backupCodes) {
    return Column(
      children: [
        const SizedBox(height: 30),
        const Icon(Icons.check_circle, color: Colors.green, size: 60),
        const SizedBox(height: 20),
        const Text(
          'MFA Enabled Successfully!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Save your backup codes in a safe place',
          style: TextStyle(fontSize: 14, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),

        // Backup Codes Display
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Keep these codes safe. You can use them if you lose access to your authenticator.',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 3,
                ),
                itemCount: backupCodes.length,
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Center(
                      child: SelectableText(
                        backupCodes[index],
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Courier',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        // Continue Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _continueToDashboard,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.walletAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Continue to Admin Dashboard',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _MFASetupData {
  final TOTPSetup setup;

  _MFASetupData(this.setup);
}
