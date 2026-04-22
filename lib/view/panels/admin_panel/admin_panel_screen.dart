import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:money_tracking_app/view/widgets/glass_card.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/controller/services/auth_service.dart';
import 'package:money_tracking_app/controller/services/firestore_service.dart';
import 'package:money_tracking_app/model/money_transaction.dart';
import 'package:money_tracking_app/model/user_model.dart';
import 'package:money_tracking_app/view/utils/currency_utils.dart';
import 'user_management_page.dart';
import 'admin_profile_page.dart';
import 'admin_category_management_page.dart';
import 'package:money_tracking_app/view/screens/admin/admin_approve_transactions_page.dart';
import 'view_analytics_page.dart';
import 'system_settings_page.dart';
import 'mfa_settings_page.dart';
import 'package:money_tracking_app/view/screens/login_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestoreService = FirestoreService();
  final _authService = AuthService.instance;
  late Future<UserModel?> _adminProfileFuture;
  bool _isCheckingAccess = true;
  bool _hasAdminAccess = false;

  @override
  void initState() {
    super.initState();
    _adminProfileFuture = _loadAdminProfile();
    _checkAdminAccess();
  }

  Future<UserModel?> _loadAdminProfile() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;
    return _firestoreService.getUserById(currentUser.uid);
  }

  Future<void> _checkAdminAccess() async {
    final hasAccess = await _firestoreService.isCurrentUserAdmin();
    if (!mounted) return;

    setState(() {
      _hasAdminAccess = hasAccess;
      _isCheckingAccess = false;
    });
  }

  Future<void> _logout() async {
    try {
      await _authService.logout();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_hasAdminAccess) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Admin privileges are required to open this panel.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: StreamBuilder<List<MoneyTransaction>>(
            stream: _firestoreService.streamTransactions(),
            builder: (context, snapshot) {
              final transactions = snapshot.data ?? [];
              final totalTransactions = transactions.length;
              final pendingTransactions = transactions
                  .where((t) => t.status.toLowerCase() == 'pending')
                  .length;
              final totalRevenue = transactions
                  .where((t) => t.type == 'income')
                  .fold<double>(0, (sum, t) => sum + t.amount);

              return StreamBuilder<List<UserModel>>(
                stream: _firestoreService.streamAllUsers(),
                builder: (context, usersSnapshot) {
                  final users = usersSnapshot.data ?? const <UserModel>[];
                  final totalUsers = users.length;
                  final activeUsers = users.where((u) => u.active).length;
                  final activeRate = totalUsers == 0
                      ? 100
                      : ((activeUsers / totalUsers) * 100).round();

                  return StreamBuilder<Map<String, dynamic>>(
                    stream: _firestoreService.streamResolvedSystemSettings(),
                    builder: (context, settingsSnapshot) {
                      final settings =
                          settingsSnapshot.data ??
                          FirestoreService.systemSettingsDefaults;
                      final defaultCurrency = normalizeCurrencyCode(
                        settings['defaultCurrency'],
                      );
                      final maintenanceMode =
                          settings['maintenanceMode'] == true;
                      final systemHealthText = maintenanceMode
                          ? 'MAINT'
                          : '$activeRate%';
                      final systemHealthColor = maintenanceMode
                          ? Colors.orange
                          : Colors.red;

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GlassCard(
                              borderRadius: 24,
                              padding: const EdgeInsets.all(18),
                              opacity: 0.82,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.walletAccent.withValues(
                                        alpha: 0.18,
                                      ),
                                      Colors.white.withValues(alpha: 0.14),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 54,
                                          height: 54,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppColors.walletAccent,
                                                AppColors.walletAccent
                                                    .withValues(alpha: 0.7),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.walletAccent
                                                    .withValues(alpha: 0.22),
                                                blurRadius: 18,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.admin_panel_settings_rounded,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Admin Dashboard',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      height: 1.0,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Overview, quick actions, and live system controls',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  height: 1.35,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.72),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.walletAccent
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: const Text(
                                            'Admin',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.walletAccent,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            '$activeRate% healthy',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          tooltip: 'Admin Profile',
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const AdminProfilePage(),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.account_circle_rounded,
                                            color: AppColors.walletAccent,
                                            size: 30,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Logout',
                                          onPressed: _logout,
                                          icon: const Icon(
                                            Icons.logout_rounded,
                                            color: Colors.redAccent,
                                            size: 26,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const _SectionHeader(
                              title: 'Overview',
                              subtitle: 'Live snapshot of the system',
                            ),
                            const SizedBox(height: 12),
                            FutureBuilder<UserModel?>(
                              future: _adminProfileFuture,
                              builder: (context, profileSnapshot) {
                                return _AdminProfileCard(
                                  authUser: _auth.currentUser,
                                  profile: profileSnapshot.data,
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                            GridView.builder(
                              itemCount: 4,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 14,
                                    childAspectRatio: 1.12,
                                  ),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemBuilder: (context, index) {
                                switch (index) {
                                  case 0:
                                    return _StatCard(
                                      title: 'Total Users',
                                      value: '$totalUsers',
                                      subtitle: 'Registered accounts',
                                      trendLabel: 'â†‘',
                                      icon: Icons.people_rounded,
                                      color: Colors.blue,
                                    );
                                  case 1:
                                    return _StatCard(
                                      title: 'Transactions',
                                      value: '$totalTransactions',
                                      subtitle: 'All ledger entries',
                                      trendLabel: 'â†‘',
                                      icon: Icons.swap_horiz_rounded,
                                      color: Colors.green,
                                    );
                                  case 2:
                                    return _StatCard(
                                      title: 'Revenue',
                                      value: formatCurrency(
                                        totalRevenue,
                                        currencyCode: defaultCurrency,
                                      ),
                                      subtitle:
                                          'Income total â€¢ $defaultCurrency',
                                      trendLabel: 'â†‘',
                                      icon: Icons.trending_up_rounded,
                                      color: Colors.orange,
                                    );
                                  default:
                                    return _StatCard(
                                      title: 'System Health',
                                      value: systemHealthText,
                                      subtitle: 'Operational status',
                                      trendLabel: maintenanceMode ? '!' : 'â—',
                                      icon: Icons.favorite_rounded,
                                      color: systemHealthColor,
                                    );
                                }
                              },
                            ),
                            const SizedBox(height: 18),
                            const _SectionHeader(
                              title: 'Management Actions',
                              subtitle: 'Quick Actions',
                            ),
                            const SizedBox(height: 12),
                            GlassCard(
                              borderRadius: 24,
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  _AdminAction(
                                    icon: Icons.group_add_rounded,
                                    title: 'User Management',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const UserManagementPage(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _AdminAction(
                                    icon: Icons.check_circle_rounded,
                                    title: 'Approve Transactions',
                                    badgeCount: pendingTransactions,
                                    highlightPending: pendingTransactions > 0,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const AdminApproveTransactionsPage(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _AdminAction(
                                    icon: Icons.analytics_rounded,
                                    title: 'View Analytics',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ViewAnalyticsPage(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _AdminAction(
                                    icon: Icons.security_rounded,
                                    title: 'System Settings',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const SystemSettingsPage(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _AdminAction(
                                    icon: Icons.shield_rounded,
                                    title: 'MFA Settings',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const MFASettingsPage(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _AdminAction(
                                    icon: Icons.category_rounded,
                                    title: 'Category Management',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const AdminCategoryManagementPage(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final String? trendLabel;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    this.trendLabel,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.96),
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              if (trendLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withValues(alpha: 0.12)),
                  ),
                  child: Text(
                    trendLabel!,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: onSurface,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: onSurface.withValues(alpha: 0.66),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminAction extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int badgeCount;
  final bool highlightPending;

  const _AdminAction({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badgeCount = 0,
    this.highlightPending = false,
  });

  @override
  State<_AdminAction> createState() => _AdminActionState();
}

class _AdminActionState extends State<_AdminAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) {
            setState(() => _pressed = true);
          },
          onTapUp: (_) {
            setState(() => _pressed = false);
          },
          onTapCancel: () {
            setState(() => _pressed = false);
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.highlightPending
                  ? Colors.red.withValues(alpha: isDark ? 0.22 : 0.12)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.72)),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
              border: widget.highlightPending
                  ? Border.all(color: Colors.red.withValues(alpha: 0.3))
                  : Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.highlightPending
                          ? [
                              Colors.redAccent,
                              Colors.red.withValues(alpha: 0.7),
                            ]
                          : [
                              AppColors.walletAccent,
                              AppColors.walletAccent.withValues(alpha: 0.72),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (widget.highlightPending
                                    ? Colors.redAccent
                                    : AppColors.walletAccent)
                                .withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: onSurface,
                    ),
                  ),
                ),
                if (widget.badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Text(
                      '${widget.badgeCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                if (widget.badgeCount > 0) const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: AppColors.walletAccent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminProfileCard extends StatelessWidget {
  final User? authUser;
  final UserModel? profile;

  const _AdminProfileCard({required this.authUser, required this.profile});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final uid = authUser?.uid ?? '';
    final heroTag = uid.isEmpty
        ? 'admin-profile-avatar'
        : 'admin-profile-avatar-$uid';

    final displayName = profile?.name.trim().isNotEmpty == true
        ? profile!.name.trim()
        : (authUser?.displayName?.trim().isNotEmpty == true
              ? authUser!.displayName!.trim()
              : 'Administrator');
    final email = profile?.email.trim().isNotEmpty == true
        ? profile!.email.trim()
        : (authUser?.email ?? 'No email');
    final role = profile?.role.trim().isNotEmpty == true
        ? profile!.role.trim()
        : 'Admin';
    final isActive = profile?.active ?? true;
    final shortUid = uid.length > 10 ? '${uid.substring(0, 10)}...' : uid;
    final initials = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : 'A';

    return GlassCard(
      borderRadius: 24,
      opacity: 0.78,
      padding: const EdgeInsets.all(18),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.walletAccent.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Profile',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Hero(
                  tag: heroTag,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.walletAccent,
                          AppColors.walletAccent.withValues(alpha: 0.75),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.walletAccent.withValues(alpha: 0.22),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 13,
                          color: onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withValues(alpha: 0.14)
                        : Colors.red.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: (isActive ? Colors.green : Colors.red)
                            .withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isActive ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ProfileMetaChip(
                  icon: Icons.badge_outlined,
                  label: 'Role: $role',
                ),
                _ProfileMetaChip(
                  icon: Icons.verified_user_outlined,
                  label: 'UID: ${shortUid.isEmpty ? 'N/A' : shortUid}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProfileMetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.7),
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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: onSurface,
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
