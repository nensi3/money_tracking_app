import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:money_tracking_app/model/money_transaction.dart';
import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/view/widgets/glass_card.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';

class UserProfileTab extends StatefulWidget {
  const UserProfileTab({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<UserProfileTab> createState() => _UserProfileTabState();
}

class _UserProfileTabState extends State<UserProfileTab> {
  Future<void> _copyToClipboard({
    required String label,
    required String value,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('No user logged in'));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting &&
            !userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (userSnapshot.hasError) {
          return Center(
            child: Text('Failed to load profile: ${userSnapshot.error}'),
          );
        }

        final userData = userSnapshot.data?.data();
        final name = _stringValue(userData?['name'], fallback: 'User');
        final email = _stringValue(
          userData?['email'],
          fallback: user.email ?? 'No email',
        );
        final phone = _stringValue(userData?['phone'], fallback: 'Not added');
        final storedPhotoUrl = _stringValue(userData?['photoUrl']);
        final photoUrl = storedPhotoUrl.isNotEmpty
            ? storedPhotoUrl
            : (user.photoURL ?? '');

        final lastLoginRaw = userData?['lastLoginAt'];
        final lastLoginTime = _asDateTime(lastLoginRaw);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('transactions')
              .where('userId', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, transactionSnapshot) {
            if (transactionSnapshot.connectionState ==
                    ConnectionState.waiting &&
                !transactionSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (transactionSnapshot.hasError) {
              return Center(
                child: Text(
                  'Failed to load transaction stats: ${transactionSnapshot.error}',
                ),
              );
            }

            final transactions = (transactionSnapshot.data?.docs ?? [])
                .map((doc) => MoneyTransaction.fromDoc(doc))
                .toList();

            final approvedCount = transactions
                .where((transaction) => transaction.status == 'approved')
                .length;
            final pendingCount = transactions
                .where((transaction) => transaction.status == 'pending')
                .length;
            final rejectedCount = transactions
                .where((transaction) => transaction.status == 'rejected')
                .length;

            final lastTransactionDate = transactions.isEmpty
                ? 'No activity yet'
                : DateFormat(
                    'dd MMM yyyy, hh:mm a',
                  ).format(transactions.first.createdAt);
            final lastActivityText = lastLoginTime != null
                ? DateFormat('dd MMM yyyy, hh:mm a').format(lastLoginTime)
                : lastTransactionDate;

            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          'Profile',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage your personal details and account security.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black.withValues(alpha: 0.58),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ProfileHeroCard(
                          name: name,
                          email: email,
                          phone: phone,
                          photoUrl: photoUrl,
                          onEdit: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EditProfileScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _MiniStatTile(
                                label: 'Total',
                                value: '${transactions.length}',
                                icon: Icons.receipt_long_rounded,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MiniStatTile(
                                label: 'Approved',
                                value: '$approvedCount',
                                icon: Icons.check_circle_rounded,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MiniStatTile(
                                label: 'Pending',
                                value: '$pendingCount',
                                icon: Icons.hourglass_top_rounded,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        GlassCard(
                          borderRadius: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Account Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _AccountTile(
                                icon: Icons.mail_outline_rounded,
                                title: 'Email',
                                subtitle: email,
                                onCopy: () => _copyToClipboard(
                                  label: 'Email',
                                  value: email,
                                ),
                              ),
                              _AccountTile(
                                icon: Icons.phone_rounded,
                                title: 'Phone',
                                subtitle: phone,
                              ),
                              _AccountTile(
                                icon: Icons.perm_identity_rounded,
                                title: 'User ID',
                                subtitle: _shortUid(user.uid),
                                onCopy: () => _copyToClipboard(
                                  label: 'User ID',
                                  value: user.uid,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        GlassCard(
                          borderRadius: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Security & Activity',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.history_toggle_off_rounded,
                                    color: Colors.indigo,
                                  ),
                                ),
                                title: const Text(
                                  'Last Activity',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(lastActivityText),
                              ),
                              const Divider(height: 8),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.cancel_rounded,
                                    color: Colors.red,
                                  ),
                                ),
                                title: const Text(
                                  'Rejected Transactions',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text('$rejectedCount'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ChangePasswordScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.lock_reset_rounded),
                            label: const Text('Change Password'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: widget.onLogout,
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Logout'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withValues(
                                alpha: 0.9,
                              ),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _stringValue(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _shortUid(String uid) {
    if (uid.length <= 16) return uid;
    return '${uid.substring(0, 8)}...${uid.substring(uid.length - 6)}';
  }

  DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.name,
    required this.email,
    required this.phone,
    required this.photoUrl,
    required this.onEdit,
  });

  final String name;
  final String email;
  final String phone;
  final String photoUrl;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 18,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              AppColors.walletAccent.withValues(alpha: 0.18),
              Colors.blue.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ProfileAvatar(name: name, photoUrl: photoUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withValues(alpha: 0.64),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_rounded, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit Profile'),
                style: FilledButton.styleFrom(
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
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.name, required this.photoUrl});

  final String name;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(photoUrl);
    final canLoadNetwork =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;

    if (canLoadNetwork) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            photoUrl,
            width: 90,
            height: 90,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _InitialAvatar(name: name),
          ),
        ),
      );
    }

    return _InitialAvatar(name: name);
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? 'U'
        : name.trim().substring(0, 1).toUpperCase();

    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.walletAccent.withValues(alpha: 0.95),
            Colors.blue.withValues(alpha: 0.95),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _MiniStatTile extends StatelessWidget {
  const _MiniStatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 14,
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onCopy,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: AppColors.walletAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.walletAccent),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: onCopy == null
          ? null
          : IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Copy $title',
            ),
    );
  }
}
