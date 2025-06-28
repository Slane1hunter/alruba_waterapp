// lib/features/presentation/owner/owner_home_page.dart

import 'package:alruba_waterapp/features/presentation/distrubutor/sale_form.dart';
import 'package:alruba_waterapp/features/presentation/distrubutor/sales/widgets/sales_queue_page.dart';
import 'package:alruba_waterapp/features/presentation/owner/admin_profiles_page.dart';
import 'package:alruba_waterapp/features/presentation/owner/users_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alruba_waterapp/features/presentation/logout_button.dart';
import 'package:alruba_waterapp/features/presentation/manager/Gallon_transaction_status_page.dart';
import 'package:alruba_waterapp/features/presentation/manager/manager_dashboard_page.dart';
import 'package:alruba_waterapp/features/presentation/owner/expenses/expense_list_page.dart';
import 'package:alruba_waterapp/features/presentation/owner/owner_dashboard_page.dart';
import 'package:alruba_waterapp/features/presentation/owner/owner_management_page.dart';
import 'package:alruba_waterapp/services/supabase_service.dart';



/*=============================================================================
 *  OWNER HOME PAGE
 *============================================================================*/
class OwnerHomePage extends ConsumerStatefulWidget {
  const OwnerHomePage({super.key});

  @override
  ConsumerState<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends ConsumerState<OwnerHomePage> {
  /* -------------------------------------------------------------------------
   * BOTTOM‑NAV ITEMS (index‑based navigation)
   * -----------------------------------------------------------------------*/
  int _currentIndex = 0;
  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.inventory_2_outlined, label: 'Products'),
    _NavItem(icon: Icons.receipt_long_outlined, label: 'Expenses'),
    _NavItem(icon: Icons.shopping_bag_outlined, label: 'Sales'),
    _NavItem(icon: Icons.local_drink_outlined, label: 'Gallons'),
    _NavItem(icon: Icons.sell_outlined, label: 'Profit'),
  ];

  final List<Widget> _pages = const [
    OwnerManagementPage(),
    ExpensesScreen(),
    ManagerDashboardPage(),
    GallonTransactionStatusPage(),
    OwnerDashboardPage(),
  ];

  /* -------------------------------------------------------------------------
   * DRAWER ITEMS (completely independent screens)
   * -----------------------------------------------------------------------*/
  final List<_DrawerEntry> _drawerItems = const [
    _DrawerEntry(icon: Icons.add_circle_outline_sharp, label: ' Make Sales', page: MakeSalePage()),
    _DrawerEntry(icon: Icons.query_builder, label: 'Sales queue', page: SalesQueuePage()),
    _DrawerEntry(icon: Icons.person, label: 'Profiles', page: AdminProfilesPage()),
    //_DrawerEntry(icon: Icons.dashboard, label: 'Workers dashboard', page: OwnerDashboardPage2()),
  ];

  /* -------------------------------------------------------------------------
   * LOADING OVERLAY
   * -----------------------------------------------------------------------*/
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchInitialData());
  }

  Future<void> _fetchInitialData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      await Future.wait([
        SupabaseService.client.from('products').select('*'),
        SupabaseService.client.from('locations').select('*'),
      ]);
    } catch (e) {
      _showErrorSnackbar('Failed to load data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackbar(String message) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
        );
      });

  /* -------------------------------------------------------------------------
   * BUILD
   * -----------------------------------------------------------------------*/
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      /* ---------------- AppBar ---------------- */
      appBar: AppBar(
        title: const Text('Owner Home', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),

      /* ---------------- Drawer ---------------- */
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cs.primary, cs.secondary]),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text('Owner Panel', style: TextStyle(color: cs.onPrimary, fontSize: 20)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _drawerItems.length,
                itemBuilder: (_, i) {
                  final d = _drawerItems[i];
                  return ListTile(
                    leading: Icon(d.icon),
                    title: Text(d.label),
                    onTap: () {
                      Navigator.pop(context); // close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => d.page),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 0),
            const Padding(
              padding: EdgeInsets.all(12),
              child: LogoutButton(fullWidth: true),
            ),
          ],
        ),
      ),

      /* ---------------- Body with overlay ---------------- */
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _pages),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              ),
            ),
        ],
      ),

      /* ---------------- Bottom Navigation ---------------- */
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: cs.surface,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurface.withOpacity(.6),
        showUnselectedLabels: true,
        elevation: 8,
        items: [
          for (final item in _navItems)
            BottomNavigationBarItem(icon: Icon(item.icon), label: item.label),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------
 * SMALL STRUCTS
 * -----------------------------------------------------------------------*/
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _DrawerEntry {
  final IconData icon;
  final String label;
  final Widget page;
  const _DrawerEntry({required this.icon, required this.label, required this.page});
}
