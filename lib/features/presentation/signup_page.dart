import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _loading = false;

  Future<void> _signUp() async {
    print('🔄 Starting sign-up process...');

    if (!_formKey.currentState!.validate()) {
      print('⚠️ Form is invalid');
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    setState(() => _loading = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) throw Exception('User creation failed');
      print('✅ Signup success. User ID: ${user.id}');

      await _insertProfileSafely(
        userId: user.id,
        firstName: firstName,
        lastName: lastName,
      );

      if (mounted) {
        print('🚀 Redirecting to /login');
        context.go('/login');
      }
    } catch (e, stackTrace) {
      print('❌ Signup error: $e');
      print('🪵 Stack trace:\n$stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إنشاء الحساب: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _insertProfileSafely({
    required String userId,
    required String firstName,
    required String lastName,
  }) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .insert({
            'user_id': userId,
            'first_name': firstName,
            'last_name': lastName,
            'role': 'viewer',
          })
          .select()
          .single();

      print('✅ Normal profile insert succeeded');
    } catch (e) {
      print('⚠️ Normal insert failed: $e');
      print('🔄 Attempting fallback method...');

      try {
        final result = await Supabase.instance.client.rpc(
          'create_user_profile',
          params: {
            'p_user_id': userId,
            'p_first_name': firstName,
            'p_last_name': lastName,
          },
        );

        print('✅ Fallback profile insert succeeded: $result');
      } catch (e2) {
        print('❌ Fallback also failed: $e2');
        rethrow;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'الاسم الأول'),
                validator: (val) => val?.isEmpty ?? true ? 'هذا الحقل مطلوب' : null,
              ),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'اسم العائلة'),
                validator: (val) => val?.isEmpty ?? true ? 'هذا الحقل مطلوب' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                keyboardType: TextInputType.emailAddress,
                validator: (val) => val?.isEmpty ?? true ? 'هذا الحقل مطلوب' : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
                obscureText: true,
                validator: (val) => (val?.length ?? 0) < 6 ? 'يجب أن تكون 6 أحرف على الأقل' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _signUp,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('إنشاء الحساب'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
