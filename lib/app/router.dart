import 'package:alruba_waterapp/features/presentation/distrubutor/distributor_home_page.dart';
import 'package:alruba_waterapp/features/presentation/login_page.dart';
import 'package:alruba_waterapp/features/presentation/manager/manager_home_page.dart';
import 'package:alruba_waterapp/features/presentation/owner/owner_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/role_provider.dart';

final router = GoRouter(
  redirect: (context, state) {
    final authState = ProviderScope.containerOf(context).read(authStateProvider);
    return authState.when(
      data: (user) => user == null ? '/login' : null,
      loading: () => null,
      error: (_, __) => '/login',
    );
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    ShellRoute(
      builder: (context, state, child) => RoleBasedLayout(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    ),
  ],
);

class RoleBasedLayout extends ConsumerWidget {
  final Widget child;
  
  const RoleBasedLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);
    
    return role.when(
      data: (role) => _buildRoleLayout(role),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) {
        // Fixed error handler
        ref.read(authProvider.notifier).signOut();
        return const LoginPage();
      },
    );
  }

  Widget _buildRoleLayout(String role) {
    switch (role) {
      case 'owner':
        return const OwnerHomePage();
      case 'manager':
        return const ManagerHomePage();
      case 'distributor':
        return const DistributorHomePage();
      default:
        return const LoginPage();
    }
  }
}