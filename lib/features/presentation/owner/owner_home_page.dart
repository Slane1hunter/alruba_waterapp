
import 'package:alruba_waterapp/features/presentation/logout_button.dart';
import 'package:alruba_waterapp/features/presentation/owner/locations/location_list.dart';
import 'package:alruba_waterapp/features/presentation/owner/products/products_list.dart';
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
  final List<Widget> _pages = const [
    ProductListPage(),
    LocationListPage(),
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
    testAccess();
    // Fetch data on page initialization
  }

  Future<void> _fetchData() async {
    try {
      final productsResponse =
          await SupabaseService.client.from('products').select('*');
      debugPrint('Products response: $productsResponse');

      final locationsResponse =
          await SupabaseService.client.from('locations').select('*');
      debugPrint('Locations response: $locationsResponse');
    } catch (e) {
      debugPrint('Error fetching products or locations: ${e.toString()}');
    }
  }

  Future<void> testAccess() async {
    try {
      final productsResponse =
          await SupabaseService.client.from('products').select('*');
      debugPrint('Products response: $productsResponse');
    } catch (e) {
      debugPrint('Error fetching products: $e');
    }

    try {
      final locationsResponse =
          await SupabaseService.client.from('locations').select('*');
      debugPrint('Locations response: $locationsResponse');
    } catch (e) {
      debugPrint('Error fetching locations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
        actions: const [LogoutButton()],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (newIndex) => setState(() => _currentIndex = newIndex),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Locations',
          ),
        ],
      ),
    );
  }
}
