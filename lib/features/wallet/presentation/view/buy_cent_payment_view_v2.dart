// lib/features/wallet/presentation/view/buy_cent_payment_view.dart
//
// Step 2 of the top-up flow: show where to send the money and the
// reference code to include, let the user mark it paid, reflect live
// status straight from Supabase, and show support contact info pulled
// from app_support_contacts (editable anytime, no rebuild needed).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class BuyCentPaymentView extends StatefulWidget {
  final String requestId;
  final String paymentCode;
  final int cpAmount;
  final int nairaPerCent;
  final String? accountName;
  final String? accountNumber;
  final String? paymentProvider;

  const BuyCentPaymentView({
    super.key,
    required this.requestId,
    required this.paymentCode,
    required this.cpAmount,
    required this.nairaPerCent,
    this.accountName,
    this.accountNumber,
    this.paymentProvider,
  });

  @override
  State<BuyCentPaymentView> createState() => _BuyCentPaymentViewState();
}

class _BuyCentPaymentViewState extends State<BuyCentPaymentView> {
  // Must match ZtcWalletBridge._centsPerUnit — 1000 raw cents = 1 CP.
  static const int _centsPerUnit = 1000;
  static const String _appId = 'nigergram';

  bool _isMarking = false;
  late final Stream<List<Map<String, dynamic>>> _requestStream;

  Map<String, dynamic>? _supportContacts;

  @override
  void initState() {
    super.initState();
    _requestStream = Supabase.instance.client
        .from('cent_purchase_requests')
        .stream(primaryKey: ['id'])
        .eq('id', int.parse(widget.requestId));
    _loadSupportContacts();
  }

  Future<void> _loadSupportContacts() async {
    try {
      final row = await Supabase.instance.client
          .from('app_support_contacts')
          .select()
          .eq('app_id', _appId)
          .maybeSingle();
      if (mounted) setState(() => _supportContacts = row);
    } catch (e) {
      debugPrint('Failed to load support contacts: $e');
    }
  }

  Future<void> _markAsPaid() async {
    setState(() => _isMarking = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await Supabase.instance.client.rpc(
        'mark_cent_purchase_paid',
        params: {'p_request_id': int.parse(widget.requestId)},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to mark as paid: $e')));
    } finally {
      if (mounted) setState(() => _isMarking = false);
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.paymentCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reference code copied'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _callNumber(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _emailAddress(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  String _formatCp(int cp) {
    return cp.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  }

  _StatusInfo _statusInfo(String status) {
    switch (status) {
      case 'pending':
        return _StatusInfo('Awaiting your transfer', const Color(0xFFFFD84D), Icons.schedule_rounded);
      case 'paid':
        return _StatusInfo('Received — under review', const Color(0xFFFFD84D), Icons.hourglass_top_rounded);
      case 'processing':
        return _StatusInfo('Processing your top-up', const Color(0xFFFFD84D), Icons.autorenew_rounded);
      case 'approved':
        return _StatusInfo('Approved — balance credited', const Color(0xFF3DDC84), Icons.check_circle_rounded);
      case 'rejected':
        return _StatusInfo('Rejected — contact support', const Color(0xFFFF4D4D), Icons.cancel_rounded);
      default:
        return _StatusInfo(status, Colors.grey, Icons.info_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawCents = widget.cpAmount * _centsPerUnit;
    final naira = rawCents * widget.nairaPerCent;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Complete Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _requestStream,
          builder: (context, snapshot) {
            final rows = snapshot.data;
            final status = (rows != null && rows.isNotEmpty)
                ? (rows.first['status'] as String? ?? 'pending')
                : 'pending';
            final info = _statusInfo(status);
            final isFinal = status == 'approved' || status == 'rejected';

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Live status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: info.color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: info.color.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(info.icon, color: info.color, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            info.label,
                            style: TextStyle(color: info.color, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _ReferenceTicket(
                    code: widget.paymentCode,
                    onCopy: _copyCode,
                    amountLabel: '${_formatCp(widget.cpAmount)} CP',
                    nairaLabel: '₦${_formatCp(naira)}',
                  ),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A24),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Send to', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        if (widget.paymentProvider != null)
                          _DetailRow(label: 'Provider', value: widget.paymentProvider!),
                        if (widget.accountName != null)
                          _DetailRow(label: 'Account name', value: widget.accountName!),
                        if (widget.accountNumber != null)
                          _DetailRow(label: 'Account number', value: widget.accountNumber!, mono: true),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'Include the reference code above in your transfer description so we can match your payment.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
                  ),

                  const SizedBox(height: 16),

                  // Pending / processing time notice — always shown pre-approval
                  if (!isFinal)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Colors.blueAccent, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Confirmation may take a little time after you send payment. Please be patient — your balance updates automatically once approved.',
                              style: TextStyle(color: Colors.white70, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Warning + support contact card, sourced from Supabase
                  if (_supportContacts != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_supportContacts!['warning_message'] != null)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _supportContacts!['warning_message'] as String,
                                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 12),
                          const Text(
                            'Need help? Contact us',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          if (_supportContacts!['ceo_phone'] != null)
                            _ContactRow(
                              icon: Icons.phone_rounded,
                              label: 'CEO: ${_supportContacts!['ceo_phone']}',
                              onTap: () => _callNumber(_supportContacts!['ceo_phone'] as String),
                            ),
                          if (_supportContacts!['assistant_phone'] != null)
                            _ContactRow(
                              icon: Icons.phone_rounded,
                              label: 'Assistance: ${_supportContacts!['assistant_phone']}',
                              onTap: () => _callNumber(_supportContacts!['assistant_phone'] as String),
                            ),
                          if (_supportContacts!['support_email'] != null)
                            _ContactRow(
                              icon: Icons.email_rounded,
                              label: _supportContacts!['support_email'] as String,
                              onTap: () => _emailAddress(_supportContacts!['support_email'] as String),
                            ),
                          if (_supportContacts!['secondary_email'] != null)
                            _ContactRow(
                              icon: Icons.email_rounded,
                              label: _supportContacts!['secondary_email'] as String,
                              onTap: () => _emailAddress(_supportContacts!['secondary_email'] as String),
                            ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  if (!isFinal)
                    ElevatedButton(
                      onPressed: (status == 'paid' || _isMarking) ? null : _markAsPaid,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF0050),
                        disabledBackgroundColor: const Color(0xFFFF0050).withOpacity(0.35),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isMarking
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                            )
                          : Text(
                              status == 'paid' ? 'Marked as paid' : "I've Paid",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    )
                  else
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Back to Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
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

class _StatusInfo {
  final String label;
  final Color color;
  final IconData icon;
  _StatusInfo(this.label, this.color, this.icon);
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  const _DetailRow({required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          SelectableText(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ContactRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// The signature element of this screen: a perforated "ticket" card that
/// holds the reference code, echoing a real payment receipt stub so the
/// code reads as something to copy and use, not just another line of text.
class _ReferenceTicket extends StatelessWidget {
  final String code;
  final VoidCallback onCopy;
  final String amountLabel;
  final String nairaLabel;

  const _ReferenceTicket({
    required this.code,
    required this.onCopy,
    required this.amountLabel,
    required this.nairaLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD84D).withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(amountLabel, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(nairaLabel, style: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          CustomPaint(
            painter: _DashedLinePainter(color: Colors.grey.shade800),
            size: const Size(double.infinity, 1),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'REFERENCE CODE',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        code,
                        style: const TextStyle(
                          color: Color(0xFFFFD84D),
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onCopy,
                      icon: const Icon(Icons.copy_rounded, color: Color(0xFFFFD84D)),
                      tooltip: 'Copy code',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => oldDelegate.color != color;
}
