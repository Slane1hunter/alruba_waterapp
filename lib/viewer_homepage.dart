import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class ViewerWaitingPage extends StatefulWidget {
  const ViewerWaitingPage({super.key});

  @override
  State<ViewerWaitingPage> createState() => _ViewerWaitingPageState();
}

class _ViewerWaitingPageState extends State<ViewerWaitingPage> {
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تسجيل الخروج: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              '.يتم مراجعة حسابك. الرجاء الانتظار للموافقة',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 30),
          if (_isLoggingOut)
            const CircularProgressIndicator()
          else
            ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                backgroundColor: Colors.redAccent,
              ),
              child: const Text(
                'تسجيل الخروج',
                style: TextStyle(fontSize: 16),
              ),
            ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}