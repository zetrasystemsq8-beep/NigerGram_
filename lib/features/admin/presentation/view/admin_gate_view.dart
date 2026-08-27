// lib/features/admin/presentation/view/admin_gate_view.dart
//
// First screen of the admin flow. Nothing here is the real security
// boundary — that's enforced server-side in Postgres (is_admin() +
// verify_admin_passcode()). This screen just collects the passcode
// and asks Supabase to check it; a wrong build-time constant or a
// decompiled APK can't get past the server-side check.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_dashboard_view.dart';

class AdminGateView extends StatefulWidget {
  const AdminGateView({super.key});

  @override
  State<AdminGateView> createState() => _AdminGateViewState();
}

class _AdminGateViewState extends State<AdminGateView> {
  final _passcodeController = TextEditingController();
  bool _isChecking = false;
  String? _error;

  Future<void> _submit() async {
    final passcode = _passcodeController.text;
    if (passcode.isEmpty) return;

    setState(() {
      _isChecking = true;
      _error = null;
    });

    try {
      final ok = await Supabase.instance.client
          .rpc('verify_admin_passcode', params: {'p_passcode': passcode}) as bool;

      if (!mounted) return;

      if (ok) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminDashboardView(passcode: passcode),
          ),
        );
      } else {
        setState(() => _error = 'Incorrect passcode');
      }
    } catch (e) {
  if (!mounted) return;
  setState(() => _error = '$e');
    
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Admin', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.admin_panel_settings_rounded, color: Colors.white54, size: 48),
            const SizedBox(height: 24),
            TextField(
              controller: _passcodeController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Admin passcode',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1A1A24),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isChecking ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0050),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isChecking
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Enter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
