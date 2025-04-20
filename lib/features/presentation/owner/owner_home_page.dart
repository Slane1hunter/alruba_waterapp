import 'package:alruba_waterapp/features/presentation/logout_button.dart';
import 'package:alruba_waterapp/features/presentation/owner/expenses/expense_list_page.dart';
import 'package:alruba_waterapp/features/presentation/owner/owner_management_page.dart';
import 'package:alruba_waterapp/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Home screen shown to “Owner” users.
/// Two tabs:
///   1. Products / management
///   2. Expenses
class OwnerHomePage extends ConsumerStatefulWidget {
  const OwnerHomePage({super.key});

  @override
  ConsumerState<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends ConsumerState<OwnerHomePage> {
  int _currentIndex = 0;

  /// We keep the pages _const_ so Flutter can
  /// short‑circuit rebuilds when switching tabs.
  static const _pages = <Widget>[
    OwnerManagementPage(),
    ExpensesScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _preloadReferenceData();   // fetch reference look‑up tables once
    _sanityCheckAccess();      // quick RLS sanity check (optional)
  }

  /* ---------------------------------------------------------------------------
   *  Internal helpers
   * ------------------------------------------------------------------------ */

  /// Fetches products & locations concurrently.
  Future<void> _preloadReferenceData() async {
    try {
      await Future.wait([
        SupabaseService.client.from('products').select(),
        SupabaseService.client.from('locations').select(),
      ]);
      //  You could cache these responses inside a Riverpod provider
      //  for the rest of the app to read; omitted to keep parity
      //  with your original logic.
    } catch (err, st) {
      debugPrint('Preload failed: $err\n$st');
    }
  }

  /// Fires two “dummy” selects to confirm the owner has access to tables.
  Future<void> _sanityCheckAccess() async {
    for (final table in ['products', 'locations']) {
      try {
        await SupabaseService.client.from(table).select().limit(1);
      } catch (e) {
        debugPrint('❌  Access check failed for `$table`: $e');
      }
    }
  }

  /* ---------------------------------------------------------------------------
   *  UI
   * ------------------------------------------------------------------------ */

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner dashboard'),
        actions: const [LogoutButton()],
      ),

      // Keeps both pages alive; fast tab‑switching
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      bottomNavigationBar: NavigationBar(           // Material‑3 bottom bar
        height: 64,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
        ],
      ),
    );
  }
}
