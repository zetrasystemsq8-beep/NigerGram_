// Buy Cent view
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BuyCentView extends StatefulWidget {
  const BuyCentView({super.key});

  @override
  State<BuyCentView> createState() => _BuyCentViewState();
}

class _BuyCentViewState extends State<BuyCentView> {
  final _amountController = TextEditingController();
  bool _isLoading = false;
  String? _paymentCode;
  String? _requestId;

  // TODO: Replace with your Cloud Functions region+domain if different
  static const String functionsBase = 'https://us-central1-<YOUR_PROJECT>.cloudfunctions.net';

  // top-up config loaded from Firestore: collection 'config', doc 'topup'
  String? _accountNumber;
  String? _accountName;
  String? _paymentProvider;
  int _nairaPerCent = 1; // default conversion rate (1 Naira per cent)

  @override
  void initState() {
    super.initState();
    _loadTopupConfig();
  }

  Future<void> _loadTopupConfig() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('topup').get();
      final data = doc.data();
      if (data != null) {
        setState(() {
          _accountNumber = data['accountNumber'] as String?;
          _accountName = data['accountName'] as String?;
          _paymentProvider = data['provider'] as String?;
          _nairaPerCent = (data['nairaPerCent'] is int) ? data['nairaPerCent'] as int : int.tryParse('${data['nairaPerCent']}') ?? 1;
        });
      }
    } catch (e) {
      // Non-fatal: UI will still show but without account details
      debugPrint('Failed to load topup config: $e');
    }
  }

  Future<String> _idToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final token = await user.getIdToken(true);
    if (token == null) throw Exception('Failed to obtain ID token');
    return token;
  }

  String _formatNairaAmount(int cents) {
    final naira = cents * _nairaPerCent;
    return '₦$naira';
  }

  Future<void> _createTopup() async {
    setState(() => _isLoading = true);
    try {
      final cents = int.tryParse(_amountController.text) ?? 0;
      if (cents <= 0) throw 'Enter a valid cent amount';

      final idToken = await _idToken();
      final resp = await http.post(Uri.parse('$functionsBase/createTopup'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'centAmount': cents}));

      if (resp.statusCode != 201 && resp.statusCode != 200) {
        throw 'Server error: ${resp.body}';
      }

      final body = jsonDecode(resp.body);
      setState(() {
        _paymentCode = body['paymentCode'] as String?;
        _requestId = body['id'] as String?;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsPaid() async {
    if (_requestId == null) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not authenticated');

      final docRef = FirebaseFirestore.instance.collection('topup_requests').doc(_requestId);
      await docRef.update({
        'status': 'paid',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as paid. Admin will review.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to mark as paid: $e')));
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buy Cent')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cent amount (e.g. 500)'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _createTopup,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Create Payment'),
              ),
              const SizedBox(height: 16),
              if (_paymentCode != null) ...[
                const Text('Payment details', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Card(
                  color: const Color(0xFF0F0F14),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_paymentProvider != null)
                          Text('Provider: $_paymentProvider', style: const TextStyle(color: Colors.white)),
                        if (_accountName != null)
                          Text('Account name: $_accountName', style: const TextStyle(color: Colors.white)),
                        if (_accountNumber != null)
                          SelectableText('Account number: $_accountNumber', style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 8),
                        if (_amountController.text.isNotEmpty)
                          Text('Amount to pay: ${_formatNairaAmount(int.tryParse(_amountController.text) ?? 0)}', style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 8),
                        SelectableText('Payment code: $_paymentCode', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 12),
                        const Text('Send the exact amount to the account above and include the payment code in the transfer description.', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _markAsPaid,
                          child: const Text("I've Paid (mark for review)"),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // If paymentCode not created yet, show preview of account details so user knows where to pay
                const Text('Payment details', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Card(
                  color: const Color(0xFF0F0F14),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_paymentProvider != null)
                          Text('Provider: $_paymentProvider', style: const TextStyle(color: Colors.white)),
                        if (_accountName != null)
                          Text('Account name: $_accountName', style: const TextStyle(color: Colors.white)),
                        if (_accountNumber != null)
                          SelectableText('Account number: $_accountNumber', style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 8),
                        Text('Payment code will be generated when you tap "Create Payment".', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
