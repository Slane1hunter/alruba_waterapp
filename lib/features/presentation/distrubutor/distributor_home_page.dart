import 'package:alruba_waterapp/features/presentation/distrubutor/distrubutor_profile_page.dart';
import 'package:alruba_waterapp/features/presentation/distrubutor/sales/widgets/distributor_sales_page.dart';
import 'package:alruba_waterapp/features/presentation/distrubutor/sales/widgets/sales_queue_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alruba_waterapp/services/supabase_service.dart';

// Import your sales pages
import 'package:alruba_waterapp/features/auth/presentation/distrubutor/sales/sale_form.dart';

class DistributorHomePage extends ConsumerStatefulWidget {
  const DistributorHomePage({super.key});

  @override
  ConsumerState<DistributorHomePage> createState() => _DistributorHomePageState();
}

class _DistributorHomePageState extends ConsumerState<DistributorHomePage> {
  late Future<Map<String, dynamic>> _dashboardFuture;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _fetchDashboardData();
    // _testCustomerQuery(); // Optional: remove if not needed
  }

  /// Fetch data for the dashboard
  Future<Map<String, dynamic>> _fetchDashboardData() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) throw Exception('No logged-in user found');
    final userId = user.id;

    // Calculate today’s date range
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final fromDate = startOfDay.toIso8601String();
    final toDate = endOfDay.toIso8601String();

    // 1) Today’s Sales (using a custom RPC)
    final salesResponse = await SupabaseService.client.rpc(
      'get_distributor_sales',
      params: {
        'p_user': userId,
        'p_from_tz': fromDate,
        'p_to_tz': toDate,
      },
    );
    int todayGallons = 0;
    if (salesResponse is List) {
      for (final row in salesResponse) {
        todayGallons += (row['quantity'] ?? 0) as int;
      }
    }

    // 2) Unpaid sales
    final unpaidResponse = await SupabaseService.client.rpc(
      'get_distributor_unpaid_sales',
      params: {'p_user': userId},
    );
    final Map<String, double> customerAmounts = {};
    if (unpaidResponse is List) {
      for (final row in unpaidResponse) {
        final custId = row['customer_id'] as String?;
        final amount = (row['total_unpaid'] as num).toDouble();
        if (custId == null) continue;
        customerAmounts[custId] = (customerAmounts[custId] ?? 0) + amount;
      }
    }

    // 3) For each unpaid, get the name
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

  Future<void> _markCustomerPaid(String customerId) async {
    final userId = SupabaseService.client.auth.currentUser!.id;
    final response = await SupabaseService.client
        .from('sales')
        .update({'payment_status': 'paid'})
        .eq('sold_by', userId)
        .eq('customer_id', customerId)
        .eq('payment_status', 'unpaid')
        .select()
        .maybeSingle();

    if (response == null) {
      throw Exception("Update failed: No response returned.");
    }
    if (response is Map<String, dynamic> && response.containsKey('error') && response['error'] != null) {
      throw Exception(response['error']['message']);
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
        // Refresh the dashboard after payment update
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

  @override
  Widget build(BuildContext context) {
    // Define the pages
    final pages = [
      _buildDashboard(),                // Dashboard page
      const DistributorSalesPage(),     // My Sales page with filters & search
      const SalesQueuePage(),           // Queue page
      const DistributorProfilePage(),   // Profile page
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
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MakeSalePage()),
          ).then((_) {
            // Automatically refresh when returning from the sale form
            setState(() {
              _dashboardFuture = _fetchDashboardData();
            });
          });
        },
        child: const Icon(Icons.add, size: 32),
        backgroundColor: Colors.blueAccent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        elevation: 10,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.dashboard, size: 28, color: Colors.blueAccent),
                onPressed: () => setState(() => _currentIndex = 0),
              ),
              IconButton(
                icon: const Icon(Icons.list, size: 28, color: Colors.blueAccent),
                onPressed: () => setState(() => _currentIndex = 1),
              ),
              const SizedBox(width: 48), // space for the centered FAB
              IconButton(
                icon: const Icon(Icons.cloud_queue, size: 28, color: Colors.blueAccent),
                onPressed: () => setState(() => _currentIndex = 2),
              ),
              IconButton(
                icon: const Icon(Icons.person, size: 28, color: Colors.blueAccent),
                onPressed: () => setState(() => _currentIndex = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // The main dashboard UI
  Widget _buildDashboard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final data = snapshot.data!;
        final todayGallons = data['todayGallons'] as int;
        final unpaidList = data['unpaidList'] as List<Map<String, dynamic>>;

        return SingleChildScrollView(
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Row(
                    children: [
                      const Icon(Icons.water_drop, size: 50, color: Colors.blue),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Today's Gallons Sold",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$todayGallons',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueAccent,
                            ),
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
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              unpaidList.isEmpty
                  ? const Center(child: Text('No unpaid sales!', style: TextStyle(fontSize: 18)))
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
                            leading: const Icon(Icons.person, size: 36, color: Colors.blueAccent),
                            title: Text(
                              custName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            subtitle: Text('Unpaid: \$${amount.toStringAsFixed(2)}'),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                              ),
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
}
