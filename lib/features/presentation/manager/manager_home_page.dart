import 'package:alruba_waterapp/features/presentation/owner/owner_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alruba_waterapp/features/presentation/distrubutor/sales/widgets/sales_queue_page.dart';
import 'package:alruba_waterapp/features/presentation/manager/gallon_transaction_status_page.dart';
import 'package:alruba_waterapp/features/presentation/manager/customer_details_page.dart';
import 'package:alruba_waterapp/features/presentation/manager/manager_profile_page.dart';
import 'package:alruba_waterapp/features/presentation/manager/manager_dashboard_page.dart';

// Import the new combined page for products/locations (or any page you want to open)

class ManagerHomePage extends ConsumerStatefulWidget {
  const ManagerHomePage({super.key});

  @override
  ConsumerState<ManagerHomePage> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends ConsumerState<ManagerHomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ManagerDashboardPage(),
    SalesQueuePage(),
    GallonTransactionStatusPage(),
    CustomerDetailsPage(),
    ManagerProfilePage(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard, label: 'Dashboard'),
    _NavItem(icon: Icons.queue, label: 'Queue'),
    _NavItem(icon: Icons.local_drink, label: 'Gallon'),
    _NavItem(icon: Icons.group, label: 'Customers'),
    _NavItem(icon: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Home'),
        centerTitle: true,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      // FAB now goes to the new combined page (OwnerManagementPage) for demonstration
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: FloatingActionButton.extended(
          backgroundColor: theme.colorScheme.primary,
          icon: const Icon(Icons.settings),
          label: const Text('Manage'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const OwnerManagementPage(),
              ),
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: (index) => setState(() => _currentIndex = index),
        items: _navItems.map((navItem) {
          return BottomNavigationBarItem(
            icon: Icon(navItem.icon),
            label: navItem.label,
          );
        }).toList(),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
