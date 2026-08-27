// lib/features/wallet/presentation/view/buy_cent_amount_view.dart
//
// Step 1 of the top-up flow: pick or enter a CP amount, then create the
// topup request via Supabase and move to BuyCentPaymentView for payment
// details.
//
// UNIT NOTE: the user picks an amount in CP (the display currency), but
// the backend RPC and the wallet's source of truth
// (wallets/{uid}.balanceCents, see ZtcWalletBridge) both work in RAW
// CENTS, where 1000 raw cents = 1 CP. Every value sent to the server —
// p_cent_amount in the RPC call, and the naira price preview — must be
// in raw cents, not CP. Only on-screen labels show CP.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'buy_cent_payment_view.dart';

class BuyCentAmountView extends StatefulWidget {
  const BuyCentAmountView({super.key});

  @override
  State<BuyCentAmountView> createState() => _BuyCentAmountViewState();
}

class _BuyCentAmountViewState extends State<BuyCentAmountView> {
  static const List<int> _presets = [500, 1000, 2500, 5000, 10000]; // in CP
  // Must match ZtcWalletBridge._centsPerUnit — 1000 raw cents = 1 CP.
  static const int _centsPerUnit = 1000;

  final _customController = TextEditingController();
  int? _selectedPreset;
  bool _isCustom = false;
  bool _isLoading = false;

  String? _accountNumber;
  String? _accountName;
  String? _paymentProvider;
  int _nairaPerCent = 1;

  @override
  void initState() {
    super.initState();
    _loadTopupConfig();
  }

  Future<void> _loadTopupConfig() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('topup').get();
      final data = doc.data();
      if (data != null && mounted) {
        setState(() {
          _accountNumber = data['accountNumber'] as String?;
          _accountName = data['accountName'] as String?;
          _paymentProvider = data['provider'] as String?;
          _nairaPerCent = (data['nairaPerCent'] is int)
              ? data['nairaPerCent'] as int
              : int.tryParse('${data['nairaPerCent']}') ?? 1;
        });
      }
    } catch (e) {
      debugPrint('Failed to load topup config: $e');
    }
  }

  /// The CP amount the user picked/typed — this is what's shown on screen.
  int get _selectedCp {
    if (_isCustom) return int.tryParse(_customController.text) ?? 0;
    return _selectedPreset ?? 0;
  }

  /// The raw-cent equivalent — this is what actually goes to the server
  /// (the RPC's p_cent_amount, and the naira price calculation).
  int get _selectedRawCents => _selectedCp * _centsPerUnit;

  Future<void> _continue() async {
    final cp = _selectedCp;
    if (cp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose or enter an amount first')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'Not authenticated';

      final result = await Supabase.instance.client
          .rpc('create_nigergram_cent_purchase', params: {'p_cent_amount': _selectedRawCents})
          .timeout(const Duration(seconds: 12));

      final row = (result as List).first;
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BuyCentPaymentView(
            requestId: row['id'].toString(),
            paymentCode: row['reference'] as String,
            cpAmount: cp,
            nairaPerCent: _nairaPerCent,
            accountName: _accountName,
            accountNumber: _accountNumber,
            paymentProvider: _paymentProvider,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), duration: const Duration(seconds: 6)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatCp(int cp) {
    return cp.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Naira preview mirrors the backend's default pricing (nairaAmount
    // defaults to centAmount * nairaPerCent, both in raw cents).
    final naira = _selectedRawCents * _nairaPerCent;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Fund Wallet',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'How much CP?',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Pick an amount or enter your own',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final preset in _presets)
                    _PresetChip(
                      label: '${_formatCp(preset)} CP',
                      selected: !_isCustom && _selectedPreset == preset,
                      onTap: () => setState(() {
                        _isCustom = false;
                        _selectedPreset = preset;
                        _customController.clear();
                      }),
                    ),
                  _PresetChip(
                    label: 'Other',
                    selected: _isCustom,
                    onTap: () => setState(() {
                      _isCustom = true;
                      _selectedPreset = null;
                    }),
                  ),
                ],
              ),
              if (_isCustom) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _customController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'Enter CP amount',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    filled: true,
                    fillColor: const Color(0xFF1A1A24),
                    suffixText: 'CP',
                    suffixStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const Spacer(),
              if (_selectedCp > 0)
                Container(
                  padding: const EdgeInsets.all(18),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF0050), Color(0xFF7B0033)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_formatCp(_selectedCp)} CP',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '≈ ₦${_formatCp(naira)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ElevatedButton(
                onPressed: _isLoading ? null : _continue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0050),
                  disabledBackgroundColor: const Color(0xFFFF0050).withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                      )
                    : const Text(
                        'Continue',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [Color(0xFFFF0050), Color(0xFF7B0033)])
              : null,
          color: selected ? null : const Color(0xFF1A1A24),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.grey.shade800,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade300,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
