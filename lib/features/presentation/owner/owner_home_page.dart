import 'package:alruba_waterapp/features/presentation/logout_button.dart';
import 'package:alruba_waterapp/features/presentation/manager/Gallon_transaction_status_page.dart';
import 'package:alruba_waterapp/features/presentation/manager/manager_dashboard_page.dart';
import 'package:alruba_waterapp/features/presentation/owner/expenses/expense_list_page.dart';
import 'package:alruba_waterapp/features/presentation/owner/owner_dashboard_page.dart';
import 'package:alruba_waterapp/features/presentation/owner/owner_management_page.dart';
import 'package:alruba_waterapp/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OwnerHomePage extends ConsumerStatefulWidget {
  const OwnerHomePage({super.key});

  @override
  ConsumerState<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends ConsumerState<OwnerHomePage> {
  int _currentIndex = 0;
  bool _isLoading = false;
  final List<Widget> _pages = [
    const OwnerManagementPage(),
    const ExpensesScreen(),
    const ManagerDashboardPage(),
    const GallonTransactionStatusPage(),
    const DailySalesPage(),
   //const OwnerMonthlyFinancePage()
  ];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    if (mounted) setState(() => _isLoading = true);
    
    try {
      final responses = await Future.wait([
        SupabaseService.client.from('products').select('*'),
        SupabaseService.client.from('locations').select('*'),
      ]);

      debugPrint('Products: ${responses[0]}');
      debugPrint('Locations: ${responses[1]}');
    } catch (e) {
      _showErrorSnackbar('Failed to load data: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackbar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: const [LogoutButton()],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildEnhancedNavBar(context),
    );
  }

  BottomNavigationBar _buildEnhancedNavBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Colors.grey.shade600,
      selectedLabelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
      ),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      iconSize: 28,
      onTap: (index) => setState(() => _currentIndex = index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined),
          activeIcon: Icon(Icons.inventory_2),
          label: 'Products',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined),
          activeIcon: Icon(Icons.receipt_long),
          label: 'Expenses',
        ),
        
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_bag_outlined),
          activeIcon: Icon(Icons.shopping_bag),
          label: 'Sales',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.local_drink_outlined),
          activeIcon: Icon(Icons.local_drink),
          label: 'Gallons',
        ),
         BottomNavigationBarItem(
          icon: Icon(Icons.sell_outlined,),
          activeIcon: Icon(Icons.sell),
          label: 'Profit',
        ),
      ],
    );
  }
}