import 'package:alruba_waterapp/features/presentation/logout_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alruba_waterapp/services/supabase_service.dart';

class DistributorProfilePage extends ConsumerWidget {
  const DistributorProfilePage({super.key});

  // Fetch the role from the "profiles" table
  Future<String> _fetchRole() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return 'Unknown';
    final response = await SupabaseService.client
        .from('profiles')
        .select('role')
        .eq('user_id', user.id)
        .maybeSingle();
    if (response != null && response.isNotEmpty) {
      return response['role'] as String? ?? 'Unknown';
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = SupabaseService.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: user == null
            ? const Center(child: Text('No user logged in.'))
            : FutureBuilder<String>(
                future: _fetchRole(),
                builder: (context, snapshot) {
                  String role = 'Unknown';
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    role = 'Loading...';
                  } else if (snapshot.hasData) {
                    role = snapshot.data!;
                  }
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Profile avatar with user initial
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blueAccent,
                          child: Text(
                            user.email?.substring(0, 1).toUpperCase() ?? '',
                            style: const TextStyle(
                                fontSize: 40, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'User Information',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.email, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        user.email ?? 'No Email',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.person, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Role: $role',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Logout Button placed at the bottom of the profile page
                        const Center(
                          child: LogoutButton(fullWidth: false),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
