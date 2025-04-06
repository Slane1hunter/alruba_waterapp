import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../services/supabase_service.dart';
import 'signup_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

 Future<void> _handleLogin() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _isLoading = true);

  try {
    final response = await SupabaseService.client.auth.signInWithPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (response.user == null) throw Exception('Authentication failed');
    
    // Add this navigation logic
    final role = await _fetchUserRole(response.user!.id);
    
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      _getRouteForRole(role),
    );
    
  } on AuthException catch (e) {
    _showError(e.message);
  } catch (e) {
    _showError(e.toString());
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

// Add these helper methods
Future<String> _fetchUserRole(String userId) async {
  final response = await SupabaseService.client
    .from('profiles')
    .select('role')
    .eq('user_id', userId)
    .single();

  return response['role'] as String;
}

String _getRouteForRole(String role) {
  switch (role) {
    case 'owner':
      return '/owner-dashboard';
    case 'manager':
      return '/manager-dashboard';
    case 'distributor':
      return '/distributor-dashboard';
    default:
      return '/home';
  }
}

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Water Distribution',
                style: AppTextStyles.headline.copyWith(fontSize: 32),
              ),
              const SizedBox(height: 40),
              _buildEmailField(),
              const SizedBox(height: 16),
              _buildPasswordField(),
              const SizedBox(height: 24),
              _buildLoginButton(),
              if (_isLoading) ...[
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
              ],
              TextButton(
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const SignUpPage()),
  ),
  child: const Text('Create Account'),
)
            ],
            
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: const InputDecoration(
        labelText: 'Email',
        hintText: 'Enter your email',
      ),
      validator: (value) => value!.isEmpty ? 'Please enter email' : null,
      keyboardType: TextInputType.emailAddress,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: true,
      decoration: const InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your password',
      ),
      validator: (value) => value!.isEmpty ? 'Please enter password' : null,
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleLogin,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        minimumSize: const Size(double.infinity, 50),
      ),
      child: const Text('Sign In', style: AppTextStyles.button),
    );
   
  }

  

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

}