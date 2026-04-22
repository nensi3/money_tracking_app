import 'package:flutter/material.dart';
import 'package:money_tracking_app/view/panels/admin_panel/admin_panel_screen.dart';
import 'package:money_tracking_app/controller/services/firestore_service.dart';

enum PanelType { admin }

class PanelsDashboardScreen extends StatefulWidget {
  final PanelType initialPanel;

  const PanelsDashboardScreen({super.key, this.initialPanel = PanelType.admin});

  @override
  State<PanelsDashboardScreen> createState() => _PanelsDashboardScreenState();
}

class _PanelsDashboardScreenState extends State<PanelsDashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  int _selectedPanel = 0;
  bool _isLoadingAccess = true;

  @override
  void initState() {
    super.initState();
    _loadPanelAccess();
  }

  Future<void> _loadPanelAccess() async {
    final isAdmin = await _firestoreService.isCurrentUserAdmin();
    if (!mounted) return;

    final resolvedIndex = _resolveInitialPanelIndex(
      isAdmin,
      widget.initialPanel,
    );

    setState(() {
      _selectedPanel = resolvedIndex;
      _isLoadingAccess = false;
    });
  }

  int _resolveInitialPanelIndex(bool isAdmin, PanelType requestedPanel) {
    return 0;
  }

  List<_PanelInfo> get panels {
    return const [
      _PanelInfo(
        title: 'Admin Panel',
        icon: Icons.admin_panel_settings_rounded,
        description: 'System administration & analytics',
      ),
    ];
  }

  List<Widget> get panelScreens {
    return const [AdminPanelScreen()];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final destinations = panels
        .map(
          (panel) =>
              NavigationDestination(icon: Icon(panel.icon), label: panel.title),
        )
        .toList();

    return Scaffold(
      body: IndexedStack(index: _selectedPanel, children: panelScreens),
      bottomNavigationBar: destinations.length >= 2
          ? NavigationBar(
              selectedIndex: _selectedPanel,
              onDestinationSelected: (index) {
                setState(() => _selectedPanel = index);
              },
              destinations: destinations,
            )
          : null,
    );
  }
}

class _PanelInfo {
  final String title;
  final IconData icon;
  final String description;

  const _PanelInfo({
    required this.title,
    required this.icon,
    required this.description,
  });
}
