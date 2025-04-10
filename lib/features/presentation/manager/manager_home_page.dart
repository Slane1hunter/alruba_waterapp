// lib/features/auth/presentation/manager/manager_home_page.dart
import 'package:alruba_waterapp/features/presentation/distrubutor/sale_form.dart';
import 'package:alruba_waterapp/features/presentation/manager/manager_reassing_customer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import Manager pages
import 'manager_dashboard_page.dart';
import 'manager_profile_page.dart';

class ManagerHomePage extends ConsumerStatefulWidget {
  const ManagerHomePage({super.key});

  @override
  ConsumerState<ManagerHomePage> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends ConsumerState<ManagerHomePage> {
  int _currentIndex = 0;

  // List of pages for the manager
  final List<Widget> _pages = const [
    ManagerDashboardPage(),
    MakeSalePage(),
    ManagerReassignCustomerPage(),
    ManagerProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Home'),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      // Centered FAB (if needed) – here you can add a common action for manager
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Example action: navigate to a walk-in sale page (if implemented)
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.dashboard),
                onPressed: () => setState(() => _currentIndex = 0),
              ),
              IconButton(
                icon: const Icon(Icons.list),
                onPressed: () => setState(() => _currentIndex = 1),
              ),
              IconButton(
                icon: const Icon(Icons.group_work),
                onPressed: () => setState(() => _currentIndex = 2),
              ),
              IconButton(
                icon: const Icon(Icons.person),
                onPressed: () => setState(() => _currentIndex = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
