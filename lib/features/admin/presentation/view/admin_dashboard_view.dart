// lib/features/admin/presentation/view/admin_dashboard_view.dart
//
// Lists pending/paid/processing top-up requests across all users and
// lets an admin approve or reject them. The passcode collected on
// AdminGateView is carried forward and sent with every approve/reject
// call, since those RPCs re-check it server-side on every call — not
// just once at login.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardView extends StatefulWidget {
  final String passcode;

  const AdminDashboardView({super.key, required this.passcode});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  late final Stream<List<Map<String, dynamic>>> _requestsStream;
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _requestsStream = Supabase.instance.client
        .from('cent_purchase_requests')
        .stream(primaryKey: ['id'])
        .order('created_at');
  }

  Future<void> _approve(int id) async {
    setState(() => _busyIds.add(id));
    try {
      await Supabase.instance.client.rpc('approve_cent_purchase', params: {
        'p_request_id': id,
        'p_passcode': widget.passcode,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Approved — wallet credited'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _reject(int id) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A24),
          title: const Text('Reject request', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'Reason (optional)', hintStyle: TextStyle(color: Colors.grey)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Reject', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (reason == null) return; // cancelled

    setState(() => _busyIds.add(id));
    try {
      await Supabase.instance.client.rpc('reject_cent_purchase', params: {
        'p_request_id': id,
        'p_reason': reason.isEmpty ? null : reason,
        'p_passcode': widget.passcode,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rejected'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  String _formatCp(num rawCents) {
    final cp = (rawCents / 1000).floor();
    return cp.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Pending Top-ups', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _requestsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF0050)));
          }

          final rows = snapshot.data!
              .where((r) => (r['status'] as String?) != 'approved' && (r['status'] as String?) != 'rejected')
              .toList();

          if (rows.isEmpty) {
            return const Center(
              child: Text('No pending requests', style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final id = row['id'] as int;
              final status = row['status'] as String? ?? 'pending';
              final reference = row['reference'] as String? ?? '';
              final cents = row['cent_amount'] as num? ?? 0;
              final busy = _busyIds.contains(id);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A24),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_formatCp(cents)} CP',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD84D).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(status,
                              style: const TextStyle(color: Color(0xFFFFD84D), fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Ref: $reference', style: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'monospace')),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: busy ? null : () => _reject(id),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: busy ? null : () => _approve(id),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: busy
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Approve', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
