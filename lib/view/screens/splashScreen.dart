import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:money_tracking_app/controller/services/auth_service.dart';
import 'package:money_tracking_app/controller/services/firestore_service.dart';
import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'maintenance_screen.dart';
import 'package:money_tracking_app/view/panels/user_panel/user_panel_screen.dart';
import 'login_screen.dart';
import 'panels_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _timer;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();

    _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);

    _timer = Timer(const Duration(seconds: 3), () {
      final user = FirebaseAuth.instance.currentUser;

      if (!mounted) return;

      _routeAfterSplash(user);
    });
  }

  Future<void> _routeAfterSplash(User? user) async {
    if (user == null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    await user.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser ?? user;

    final userDoc = await _firestoreService.getUserById(refreshedUser.uid);
    final isActive = userDoc?.active ?? true;

    if (!mounted) return;

    if (!isActive) {
      await AuthService.instance.logout();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(
            initialMessage: 'Your account has been deactivated by an admin.',
          ),
        ),
      );
      return;
    }

    final maintenanceMode = await _firestoreService.isMaintenanceModeEnabled();

    if (!mounted) return;

    final isAdmin = await _firestoreService.isUserAdmin(
      refreshedUser.uid,
      email: refreshedUser.email,
    );

    if (!mounted) return;

    if (maintenanceMode && !isAdmin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MaintenanceScreen()),
      );
      return;
    }

    if (isAdmin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const PanelsDashboardScreen(initialPanel: PanelType.admin),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const UserPanelScreen()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;

          return AppGradientBackground(
            colors: AppColors.splashPastelGradient,
            child: Stack(
              children: [
                _Blob(
                  progress: t,
                  color: Colors.white.withValues(alpha: 0.22),
                  size: 260,
                  baseOffset: const Offset(-80, -60),
                ),
                _Blob(
                  progress: 1 - t,
                  color: Colors.white.withValues(alpha: 0.18),
                  size: 320,
                  baseOffset: const Offset(220, 90),
                ),
                _Blob(
                  progress: t,
                  color: Colors.white.withValues(alpha: 0.16),
                  size: 240,
                  baseOffset: const Offset(40, 520),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 22,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 52,
                              color: AppColors.walletAccent,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            "Money Tracking",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: AppColors.splashTitle,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Smart spending â€¢ Better saving",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: SizedBox(
                              height: 8,
                              child: LinearProgressIndicator(
                                value: 0.2 + (0.8 * t),
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.6,
                                ),
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.walletAccent,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double progress;
  final Color color;
  final double size;
  final Offset baseOffset;

  const _Blob({
    required this.progress,
    required this.color,
    required this.size,
    required this.baseOffset,
  });

  @override
  Widget build(BuildContext context) {
    final dx = sin(progress * pi * 2) * 22;
    final dy = cos(progress * pi * 2) * 18;

    return Positioned(
      left: baseOffset.dx + dx,
      top: baseOffset.dy + dy,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
