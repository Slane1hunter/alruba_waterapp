import 'package:alruba_waterapp/features/sales/sale_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../../services/supabase_service.dart';
import 'logout_button.dart';

class DistributorHomePage extends ConsumerStatefulWidget {
  const DistributorHomePage({super.key});

  @override
  ConsumerState<DistributorHomePage> createState() =>
      _DistributorHomePageState();
}

class _DistributorHomePageState extends ConsumerState<DistributorHomePage> {
  late Future<Map<String, dynamic>> _dashboardFuture;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _fetchDashboardData();

    // Optional: Test customer RPC query
    Future<void> testCustomerQuery() async {
      final response = await SupabaseService.client.rpc(
        'get_customer_name',
        params: {
          'p_customer': '11111111-1111-1111-1111-111111111111',
          'p_user': SupabaseService.client.auth.currentUser!.id,
        },
      );
      debugPrint('Test customer RPC response: $response');
    }
    testCustomerQuery();
  }

  Future<Map<String, dynamic>> _fetchDashboardData() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) throw Exception('No logged-in user found');
    final userId = user.id;
    debugPrint('Current user id: $userId');

    final session = SupabaseService.client.auth.currentSession;
    debugPrint('Current session: $session');
    if (session != null) {
      final decoded = JwtDecoder.decode(session.accessToken);
      debugPrint('Decoded JWT sub: ${decoded["sub"]}');
    }
    debugPrint('Access token: ${session?.accessToken}');

    // Calculate today's date range
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final fromDate = startOfDay.toIso8601String();
    final toDate = endOfDay.toIso8601String();

    // --- Fetch Today's Sales using RPC ---
    final salesResponse = await SupabaseService.client.rpc(
      'get_distributor_sales',
      params: {
        'p_user': userId,
        'p_from_tz': fromDate,
        'p_to_tz': toDate,
      },
    );
    debugPrint('RPC get_distributor_sales response: $salesResponse');

    int todayGallons = 0;
    if (salesResponse is List) {
      for (final row in salesResponse) {
        todayGallons += (row['quantity'] ?? 0) as int;
      }
    }
    debugPrint("Today's gallons sold (RPC): $todayGallons");

    // --- Fetch Unpaid Sales using RPC ---
    final unpaidResponse = await SupabaseService.client.rpc(
      'get_distributor_unpaid_sales',
      params: {'p_user': userId},
    );
    debugPrint('RPC get_distributor_unpaid_sales response: $unpaidResponse');

    final Map<String, double> customerAmounts = {};
    if (unpaidResponse is List) {
      for (final row in unpaidResponse) {
        final custId = row['customer_id'] as String?;
        final amount = (row['total_unpaid'] as num).toDouble();
        if (custId == null) continue;
        customerAmounts[custId] = (customerAmounts[custId] ?? 0) + amount;
      }
    }
    debugPrint('Aggregated unpaid amounts (RPC): $customerAmounts');

    // --- Fetch Customer Names using the RPC function ---
    List<Map<String, dynamic>> unpaidList = [];
    for (final custId in customerAmounts.keys) {
      final customerResponse = await SupabaseService.client.rpc(
        'get_customer_name',
        params: {
          'p_customer': custId,
          'p_user': userId,
        },
      );
      String custName = 'Unknown';
      if (customerResponse is List && customerResponse.isNotEmpty) {
        custName = customerResponse[0]['name'] as String? ?? 'Unknown';
      }
      unpaidList.add({
        'customer_id': custId,
        'customer_name': custName,
        'unpaid_amount': customerAmounts[custId],
      });
    }

    return {
      'todayGallons': todayGallons,
      'unpaidList': unpaidList,
    };
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> pages = [
      _buildDashboard(),
      // Placeholder pages
      const Center(child: Text('Sales History (Coming Soon)')),
      const Center(child: Text('Profile (Coming Soon)')),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Distributor Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _dashboardFuture = _fetchDashboardData();
              });
            },
          ),
          const LogoutButton(),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Sales History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      // FloatingActionButton for navigation to the Make Sale page
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MakeSalePage()),
          );
        },
        label: const Text('Make a Sale'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDashboard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          debugPrint('Dashboard error: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final data = snapshot.data!;
        final todayGallons = data['todayGallons'] as int;
        final unpaidList = data['unpaidList'] as List<Map<String, dynamic>>;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Today's Gallons Sold Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.water_drop, size: 40, color: Colors.blue),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Today’s Gallons Sold',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '$todayGallons',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Unpaid Customers',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              unpaidList.isEmpty
                  ? const Center(child: Text('No unpaid sales!'))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: unpaidList.length,
                      itemBuilder: (context, index) {
                        final item = unpaidList[index];
                        final custId = item['customer_id'] as String;
                        final custName = item['customer_name'] as String;
                        final amount = item['unpaid_amount'] as double;
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: const Icon(Icons.person, size: 32),
                            title: Text(custName),
                            subtitle: Text('Unpaid: \$${amount.toStringAsFixed(2)}'),
                            trailing: ElevatedButton(
                              onPressed: () => _confirmPayment(custId, custName, amount),
                              child: const Text('Pay'),
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _markCustomerPaid(String customerId) async {
    final userId = SupabaseService.client.auth.currentUser!.id;
    final response = await SupabaseService.client
        .from('sales')
        .update({'payment_status': 'paid'})
        .eq('sold_by', userId)
        .eq('customer_id', customerId)
        .eq('payment_status', 'unpaid');
    if (response.error != null) {
      throw Exception(response.error!.message);
    }
  }

  Future<void> _confirmPayment(String customerId, String customerName, double amount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text('Mark \$${amount.toStringAsFixed(2)} as paid for $customerName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _markCustomerPaid(customerId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment updated successfully')),
        );
        // Refresh dashboard after update
        setState(() {
          _dashboardFuture = _fetchDashboardData();
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating payment: $e')),
        );
      }
    }
  }
}
