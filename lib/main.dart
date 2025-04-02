import 'package:alruba_waterapp/models/customer.dart';
import 'package:alruba_waterapp/models/offline_sale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// For Hive
import 'package:hive_flutter/hive_flutter.dart';

// Import your generated adapters if you haven't already
// e.g. 'sale.dart' and 'customer.dart' – assuming these models exist with Hive annotations
// import 'package:alruba_waterapp/models/sale.dart';
// import 'package:alruba_waterapp/models/customer.dart';

import 'constants/app_colors.dart';
import 'constants/app_text_styles.dart';
import 'features/auth/presentation/distributor_home_page.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/manager_home_page.dart';
import 'features/auth/presentation/owner/owner_home_page.dart';
import 'features/auth/presentation/signup_page.dart';
import 'providers/auth_provider.dart';
import 'providers/role_provider.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Initialize Hive
  await Hive.initFlutter();

  // 2) Register your Hive adapters
  // Example:
  // Hive.registerAdapter(SaleAdapter()); 
    Hive.registerAdapter(CustomerAdapter());
    Hive.registerAdapter(OfflineSaleAdapter());
    await Hive.openBox<OfflineSale>('offline_sales');



  // 3) Initialize Supabase
  await SupabaseService.initialize(
    url: 'https://iqjknqbjrbouicdanjjm.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlxamtucWJqcmJvdWljZGFuamptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDExOTg1MDAsImV4cCI6MjA1Njc3NDUwMH0.6aOm7o3FKypk72T6hXACsi0odzDsF9I-FLpo9krmDIM',
  );
  // 4) Run app with ProviderScope
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Water Distribution',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          headlineMedium: AppTextStyles.headline,
          bodyLarge: AppTextStyles.body,
        ),
      ),
      debugShowCheckedModeBanner: false,
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      routeInformationProvider: router.routeInformationProvider,
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull != null;
      final path = state.uri.path;

      if (!isAuthenticated && path != '/login' && path != '/signup') {
        return '/login';
      }
      if (isAuthenticated && (path == '/login' || path == '/signup')) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignUpPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => RoleBasedWrapper(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const RoleBasedHome(),
          ),
        ],
      ),
    ],
  );
});

class RoleBasedWrapper extends ConsumerWidget {
  final Widget child;
  const RoleBasedWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(roleProvider);

    return roleAsync.when(
      data: (role) => _buildLayout(role),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(authProvider.notifier).signOut();
          context.go('/login');
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }

  Widget _buildLayout(String role) {
    switch (role) {
      case 'owner':
        return const OwnerHomePage();
      case 'manager':
        return const ManagerHome();
      case 'distributor':
        return const DistributorHomePage();
      default:
        return const LoginPage();
    }
  }
}

class RoleBasedHome extends ConsumerWidget {
  const RoleBasedHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: const Center(child: Text('Welcome to Water Distribution')),
    );
  }
}
