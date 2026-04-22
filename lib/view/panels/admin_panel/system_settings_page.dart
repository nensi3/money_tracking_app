import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/widgets/glass_card.dart';

class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  final DocumentReference<Map<String, dynamic>> _settingsRef = FirebaseFirestore
      .instance
      .collection('system_settings')
      .doc('global');

  static const Map<String, dynamic> _defaults = {
    'maintenanceMode': false,
    'emailNotifications': true,
    'pushNotifications': true,
    'twoFactorAuth': false,
    'autoApprove': false,
    'darkModeForced': false,
    'sessionTimeout': '30 min',
    'maxTransactionLimit': 'â‚¹5,000',
    'defaultCurrency': 'USD',
    'appVersion': '1.0.0',
    'buildNumber': '42',
    'environment': 'Production',
  };

  bool _saving = false;

  void _showPickerDialog({
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelected,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map(
                (opt) => ListTile(
                  title: Text(opt),
                  trailing: opt == current
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.walletAccent,
                        )
                      : null,
                  onTap: () {
                    onSelected(opt);
                    Navigator.pop(ctx);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  bool _boolSetting(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is bool) return value;
    final fallback = _defaults[key];
    return fallback is bool ? fallback : false;
  }

  String _stringSetting(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String && value.isNotEmpty) return value;
    final fallback = _defaults[key];
    return fallback is String ? fallback : '';
  }

  String _normalizeLimitDisplay(String value) {
    final text = value.trim();
    if (text.isEmpty || text.toLowerCase() == 'unlimited') {
      return 'Unlimited';
    }
    return text.replaceAll('4', 'â‚¹');
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    await _settingsRef.set({
      key: value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _saveAll() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      await _settingsRef.set({
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings synced to Firestore.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sync settings: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'System Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.save_rounded,
                        color: AppColors.walletAccent,
                      ),
                      onPressed: _saveAll,
                      tooltip: 'Sync Settings',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _settingsRef.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final data = {
                      ..._defaults,
                      ...(snapshot.data?.data() ?? <String, dynamic>{}),
                    };

                    final maintenanceMode = _boolSetting(
                      data,
                      'maintenanceMode',
                    );
                    final emailNotifications = _boolSetting(
                      data,
                      'emailNotifications',
                    );
                    final pushNotifications = _boolSetting(
                      data,
                      'pushNotifications',
                    );
                    final twoFactorAuth = _boolSetting(data, 'twoFactorAuth');
                    final autoApprove = _boolSetting(data, 'autoApprove');
                    final darkModeForced = _boolSetting(data, 'darkModeForced');
                    final sessionTimeout = _stringSetting(
                      data,
                      'sessionTimeout',
                    );
                    final maxTransactionLimit = _normalizeLimitDisplay(
                      _stringSetting(data, 'maxTransactionLimit'),
                    );
                    final defaultCurrency = _stringSetting(
                      data,
                      'defaultCurrency',
                    );
                    final appVersion = _stringSetting(data, 'appVersion');
                    final buildNumber = _stringSetting(data, 'buildNumber');
                    final environment = _stringSetting(data, 'environment');

                    final updatedAt = data['updatedAt'];
                    final lastUpdated = updatedAt is Timestamp
                        ? updatedAt
                              .toDate()
                              .toLocal()
                              .toString()
                              .split('.')
                              .first
                        : 'Not yet synced';

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        const _SectionHeader(
                          icon: Icons.tune_rounded,
                          title: 'App Configuration',
                        ),
                        GlassCard(
                          child: Column(
                            children: [
                              _SwitchTile(
                                icon: Icons.build_circle_rounded,
                                iconColor: Colors.orange,
                                title: 'Maintenance Mode',
                                subtitle: 'Temporarily disable app for users',
                                value: maintenanceMode,
                                onChanged: (v) =>
                                    _updateSetting('maintenanceMode', v),
                              ),
                              const _Divider(),
                              _SwitchTile(
                                icon: Icons.check_circle_rounded,
                                iconColor: Colors.green,
                                title: 'Auto-Approve Transactions',
                                subtitle:
                                    'Skip manual review for small amounts',
                                value: autoApprove,
                                onChanged: (v) =>
                                    _updateSetting('autoApprove', v),
                              ),
                              const _Divider(),
                              _SelectTile(
                                icon: Icons.attach_money_rounded,
                                iconColor: Colors.blue,
                                title: 'Max Transaction Limit',
                                value: maxTransactionLimit,
                                onTap: () => _showPickerDialog(
                                  title: 'Max Transaction Limit',
                                  options: ['â‚¹1,000', 'â‚¹5,000'],
                                  current: maxTransactionLimit,
                                  onSelected: (v) =>
                                      _updateSetting('maxTransactionLimit', v),
                                ),
                              ),
                              const _Divider(),
                              _SelectTile(
                                icon: Icons.currency_exchange_rounded,
                                iconColor: Colors.purple,
                                title: 'Default Currency',
                                value: defaultCurrency,
                                onTap: () => _showPickerDialog(
                                  title: 'Default Currency',
                                  options: ['USD', 'EUR', 'GBP', 'INR', 'JPY'],
                                  current: defaultCurrency,
                                  onSelected: (v) =>
                                      _updateSetting('defaultCurrency', v),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _SectionHeader(
                          icon: Icons.notifications_rounded,
                          title: 'Notifications',
                        ),
                        GlassCard(
                          child: Column(
                            children: [
                              _SwitchTile(
                                icon: Icons.email_rounded,
                                iconColor: Colors.blue,
                                title: 'Email Notifications',
                                subtitle: 'Send alerts via email',
                                value: emailNotifications,
                                onChanged: (v) =>
                                    _updateSetting('emailNotifications', v),
                              ),
                              const _Divider(),
                              _SwitchTile(
                                icon: Icons.notifications_active_rounded,
                                iconColor: Colors.orange,
                                title: 'Push Notifications',
                                subtitle: 'In-app and device push alerts',
                                value: pushNotifications,
                                onChanged: (v) =>
                                    _updateSetting('pushNotifications', v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _SectionHeader(
                          icon: Icons.security_rounded,
                          title: 'Security',
                        ),
                        GlassCard(
                          child: Column(
                            children: [
                              _SwitchTile(
                                icon: Icons.verified_user_rounded,
                                iconColor: Colors.green,
                                title: 'Two-Factor Authentication',
                                subtitle: 'Require 2FA for admin login',
                                value: twoFactorAuth,
                                onChanged: (v) =>
                                    _updateSetting('twoFactorAuth', v),
                              ),
                              const _Divider(),
                              _SelectTile(
                                icon: Icons.timer_rounded,
                                iconColor: Colors.red,
                                title: 'Session Timeout',
                                value: sessionTimeout,
                                onTap: () => _showPickerDialog(
                                  title: 'Session Timeout',
                                  options: [
                                    '15 min',
                                    '30 min',
                                    '1 hour',
                                    '4 hours',
                                    'Never',
                                  ],
                                  current: sessionTimeout,
                                  onSelected: (v) =>
                                      _updateSetting('sessionTimeout', v),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _SectionHeader(
                          icon: Icons.palette_rounded,
                          title: 'Display',
                        ),
                        GlassCard(
                          child: _SwitchTile(
                            icon: Icons.dark_mode_rounded,
                            iconColor: Colors.indigo,
                            title: 'Force Dark Mode',
                            subtitle: 'Override user display preferences',
                            value: darkModeForced,
                            onChanged: (v) =>
                                _updateSetting('darkModeForced', v),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _SectionHeader(
                          icon: Icons.info_rounded,
                          title: 'About',
                        ),
                        GlassCard(
                          child: Column(
                            children: [
                              _InfoTile(
                                label: 'App Version',
                                value: appVersion,
                              ),
                              const _Divider(),
                              _InfoTile(
                                label: 'Build Number',
                                value: buildNumber,
                              ),
                              const _Divider(),
                              _InfoTile(
                                label: 'Environment',
                                value: environment,
                              ),
                              const _Divider(),
                              _InfoTile(
                                label: 'Last Config Update',
                                value: lastUpdated,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _saveAll,
                            icon: const Icon(Icons.save_rounded),
                            label: Text(
                              _saving ? 'Saving...' : 'Sync Settings',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.walletAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.walletAccent),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.walletAccent,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.walletAccent,
        ),
      ],
    );
  }
}

class _SelectTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _SelectTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.walletAccent,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.walletAccent,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(height: 1, color: Colors.black.withValues(alpha: 0.07)),
    );
  }
}
