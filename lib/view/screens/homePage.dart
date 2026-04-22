import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:money_tracking_app/controller/providers/user_transactions_provider.dart';
import 'package:money_tracking_app/controller/services/firestore_service.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/widgets/summary_card.dart';
import 'package:money_tracking_app/view/widgets/transaction_card.dart';
import 'add_transaction_screen.dart';
import 'package:money_tracking_app/view/panels/budget_reports_panel/budget_reports_screen.dart';
import 'maintenance_screen.dart';
import 'login_screen.dart';
import 'user_profile_tab.dart';
import 'user_stats_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _service = FirestoreService();
  int _navIndex = 0;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userStatusSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _settingsSub;
  bool _isHandlingDeactivation = false;
  bool _isHandlingMaintenance = false;
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _watchUserStatus();
    _watchMaintenanceMode();
  }

  void _watchUserStatus() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _userStatusSub = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .listen((snapshot) async {
          if (!mounted || _isHandlingDeactivation) return;

          final isActive = snapshot.data()?['active'] != false;
          if (isActive) return;

          _isHandlingDeactivation = true;
          await FirebaseAuth.instance.signOut();

          if (!mounted) return;

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const LoginScreen(
                initialMessage:
                    'Your account has been deactivated by an admin.',
              ),
            ),
            (route) => false,
          );
        });
  }

  void _watchMaintenanceMode() {
    _settingsSub = _service.streamSystemSettings().listen((snapshot) async {
      if (!mounted || _isHandlingMaintenance) return;

      final maintenanceMode = snapshot.data()?['maintenanceMode'] == true;
      if (!maintenanceMode) return;

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final isAdmin = await _service.isUserAdmin(
        currentUser.uid,
        email: currentUser.email,
      );

      if (!mounted || isAdmin) return;

      _isHandlingMaintenance = true;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MaintenanceScreen()),
        (route) => false,
      );
    });
  }

  @override
  void dispose() {
    _userStatusSub?.cancel();
    _settingsSub?.cancel();
    super.dispose();
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();

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
      ).showSnackBar(const SnackBar(content: Text('Logout failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: _navIndex == 0
              ? _buildHomeTab()
              : _navIndex == 1
              ? _buildStatsTab()
              : _buildProfileTab(),
        ),
      ),
      floatingActionButton: _navIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddTransactionScreen(),
                  ),
                );

                if (created == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaction saved successfully.'),
                    ),
                  );
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Please log in to view transactions.'));
    }

    return ChangeNotifierProvider(
      create: (_) => UserTransactionsProvider(userId: userId),
      child: Consumer<UserTransactionsProvider>(
        builder: (context, txProvider, _) {
          if (txProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (txProvider.error != null) {
            return Center(child: Text(txProvider.error!));
          }

          final list = txProvider.transactions;
          final income = txProvider.totalIncome;
          final expense = txProvider.totalExpense;
          final balance = txProvider.balance;

          return Column(
            children: [
              const SizedBox(height: 14),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Money Tracking',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SummaryCard(
                        title: 'Balance',
                        value: _currencyFormat.format(balance),
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SummaryCard(
                        title: 'Expense',
                        value: _currencyFormat.format(expense),
                        icon: Icons.trending_down_rounded,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Approved Income: ${_currencyFormat.format(income)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BudgetReportsPanelScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.pie_chart_rounded),
                        label: const Text('Budget & Reports'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: Colors.black.withValues(alpha: 0.12),
                          ),
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: txProvider.refresh,
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(26),
                        topRight: Radius.circular(26),
                      ),
                    ),
                    child: list.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 120),
                              Center(
                                child: Text(
                                  'No transactions yet.\nTap + to add one.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            itemCount: list.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final t = list[i];
                              return TransactionCard(
                                transaction: t,
                                onDelete: () async {
                                  final shouldDelete = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: const Text('Delete Transaction'),
                                      content: const Text(
                                        'Are you sure you want to delete this transaction?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            dialogContext,
                                            false,
                                          ),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            dialogContext,
                                            true,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (shouldDelete != true) return;

                                  try {
                                    await _service.deleteTransaction(t.id);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Transaction deleted.'),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Delete failed: $e'),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsTab() {
    return UserStatsTab();
  }

  Widget _buildProfileTab() {
    return UserProfileTab(onLogout: _logout);
  }
}
