// lib/features/wallet/presentation/view/buy_cent_payment_view.dart
//
// Step 2 of the top-up flow: show where to send the money and the
// reference code to include, let the user mark it paid, and reflect
// live status (pending -> paid -> processing -> approved/rejected)
// straight from the topup_requests document.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nigergram/core/utils/app_auth.dart';

class BuyCentPaymentView extends StatefulWidget {
  final String requestId;
  final String paymentCode;
  final int centAmount;
  final int nairaPerCent;
  final String? accountName;
  final String? accountNumber;
  final String? paymentProvider;

  const BuyCentPaymentView({
    super.key,
    required this.requestId,
    required this.paymentCode,
    required this.centAmount,
    required this.nairaPerCent,
    this.accountName,
    this.accountNumber,
    this.paymentProvider,
  });

  @override
  State<BuyCentPaymentView> createState() => _BuyCentPaymentViewState();
}

class _BuyCentPaymentViewState extends State<BuyCentPaymentView> {
  bool _isMarking = false;

  Future<void> _markAsPaid() async {
    setState(() => _isMarking = true);
    try {
      final uid = AppAuth.uid;
      if (uid.isEmpty) throw Exception('Not authenticated');

      await FirebaseFirestore.instance
          .collection('topup_requests')
          .doc(widget.requestId)
          .update({
        'status': 'paid',
        'updatedAt': FieldValue.serverTimestamp(),
      });
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
    final naira = widget.centAmount * widget.nairaPerCent;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Complete Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('topup_requests')
              .doc(widget.requestId)
              .snapshots(),
          builder: (context, snapshot) {
            final status = snapshot.data?.data()?['status'] as String? ?? 'pending';
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

                  // Reference code "ticket" — the signature element of this screen
                  _ReferenceTicket(
                    code: widget.paymentCode,
                    onCopy: _copyCode,
                    amountLabel: '${_formatCp(widget.centAmount)} CP',
                    nairaLabel: '₦${_formatCp(naira)}',
                  ),

                  const SizedBox(height: 20),

                  // Bank / provider details
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
