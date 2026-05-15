import 'package:flutter/material.dart';
import 'package:money_tracking_app/model/user_model.dart';
import 'package:money_tracking_app/controller/services/firestore_service.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/widgets/glass_card.dart';
import 'package:money_tracking_app/view/utils/app_colors.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final FirestoreService _firestoreService = FirestoreService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // â”€â”€ AppBar â”€â”€
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
                    const Text(
                      'User Management',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    StreamBuilder<List<UserModel>>(
                      stream: _firestoreService.streamAllUsers(),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.length ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.walletAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$count Users',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.walletAccent,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // â”€â”€ Summary Cards â”€â”€
              StreamBuilder<List<UserModel>>(
                stream: _firestoreService.streamAllUsers(),
                builder: (context, snapshot) {
                  final users = snapshot.data ?? [];
                  final activeCount = users.where((u) => u.active).length;
                  final inactiveCount = users.where((u) => !u.active).length;
                  final adminCount = users
                      .where((u) => u.role == 'Admin')
                      .length;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _SummaryChip(
                          label: 'Active',
                          value: '$activeCount',
                          color: Colors.green,
                        ),
                        const SizedBox(width: 10),
                        _SummaryChip(
                          label: 'Inactive',
                          value: '$inactiveCount',
                          color: Colors.red,
                        ),
                        const SizedBox(width: 10),
                        _SummaryChip(
                          label: 'Admins',
                          value: '$adminCount',
                          color: Colors.purple,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // â”€â”€ Search Bar â”€â”€
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // â”€â”€ User List â”€â”€
              Expanded(
                child: StreamBuilder<List<UserModel>>(
                  stream: _firestoreService.streamAllUsers(),
                  builder: (context, snapshot) {
                    // Handle loading state
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Handle error state
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading users: ${snapshot.error}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }

                    // Handle empty state
                    final users = snapshot.data ?? [];
                    if (users.isEmpty) {
                      return const Center(
                        child: Text(
                          'No users found.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }

                    // Filter users based on search query
                    final filteredUsers = _searchQuery.isEmpty
                        ? users
                        : users
                              .where(
                                (u) =>
                                    u.name.toLowerCase().contains(
                                      _searchQuery.toLowerCase(),
                                    ) ||
                                    u.email.toLowerCase().contains(
                                      _searchQuery.toLowerCase(),
                                    ) ||
                                    u.role.toLowerCase().contains(
                                      _searchQuery.toLowerCase(),
                                    ),
                              )
                              .toList();

                    if (filteredUsers.isEmpty) {
                      return const Center(
                        child: Text(
                          'No users match your search.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: filteredUsers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        return GlassCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.walletAccent
                                    .withValues(alpha: 0.18),
                                child: Text(
                                  user.name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.walletAccent,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user.email,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black.withValues(alpha: 0.55),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        _RoleBadge(role: user.role),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: user.active
                                                ? Colors.green.withValues(alpha: 0.15)
                                                : Colors.red.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            user.active ? 'Active' : 'Inactive',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: user.active
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Actions
                              Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.info_outline_rounded,
                                      size: 20,
                                      color: AppColors.walletAccent,
                                    ),
                                    onPressed: () =>
                                        _showUserDetail(context, user),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(height: 6),
                                  IconButton(
                                    icon: Icon(
                                      user.active
                                          ? Icons.block_rounded
                                          : Icons.check_circle_outline_rounded,
                                      size: 20,
                                      color: user.active
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                    onPressed: () => _toggleUserStatus(user),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
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

  void _toggleUserStatus(UserModel user) async {
    try {
      await _firestoreService.toggleUserStatus(user.uid, !user.active);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User ${user.active ? 'deactivated' : 'activated'} successfully',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showUserDetail(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserDetailSheet(
        user: user,
        firestoreService: _firestoreService,
        onUserUpdated: () {
          // Trigger rebuild of parent StreamBuilder
          setState(() {});
        },
      ),
    );
  }
}

// â”€â”€ Helper Widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  Color get _color {
    switch (role) {
      case 'Admin':
        return Colors.purple;
      case 'Moderator':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _color,
        ),
      ),
    );
  }
}

class _UserDetailSheet extends StatefulWidget {
  final UserModel user;
  final FirestoreService firestoreService;
  final VoidCallback onUserUpdated;

  const _UserDetailSheet({
    required this.user,
    required this.firestoreService,
    required this.onUserUpdated,
  });

  @override
  State<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<_UserDetailSheet> {
  late String _selectedRole = widget.user.role;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.walletAccent.withValues(alpha: 0.18),
            child: Text(
              widget.user.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.walletAccent,
                fontSize: 24,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.user.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            widget.user.email,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Status',
            value: widget.user.active ? 'Active' : 'Inactive',
          ),
          _DetailRow(
            label: 'Joined',
            value:
                '${widget.user.joinedDate.day}/${widget.user.joinedDate.month}/${widget.user.joinedDate.year}',
          ),
          _DetailRow(
            label: 'Total Transactions',
            value: '${widget.user.transactionCount}',
          ),
          const SizedBox(height: 16),

          // Role Selection Dropdown
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<String>(
              isExpanded: true,
              underline: const SizedBox(),
              value: _selectedRole,
              items: const [
                DropdownMenuItem(value: 'User', child: Text('User')),
                DropdownMenuItem(value: 'Moderator', child: Text('Moderator')),
                DropdownMenuItem(value: 'Admin', child: Text('Admin')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedRole = value);
                }
              },
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    disabledBackgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateUserRole,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.walletAccent,
                    disabledBackgroundColor: AppColors.walletAccent.withValues(alpha: 
                      0.5,
                    ),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateUserRole() async {
    if (_selectedRole == widget.user.role) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.firestoreService.updateUserRole(
        widget.user.uid,
        _selectedRole,
      );
      if (mounted) {
        widget.onUserUpdated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User role updated to $_selectedRole'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
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
      ),
    );
  }
}
