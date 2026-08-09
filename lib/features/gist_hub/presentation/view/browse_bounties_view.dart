import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/app_auth.dart';
import 'package:nigergram/features/gist_hub/data/services/bounty_service.dart';
import 'package:nigergram/features/gist_hub/domain/entities/bounty_entity.dart';
import 'package:nigergram/features/gist_hub/presentation/view/create_bounty_view.dart';

class BrowseBountiesView extends StatefulWidget {
  const BrowseBountiesView({super.key});

  @override
  State<BrowseBountiesView> createState() => _BrowseBountiesViewState();
}

class _BrowseBountiesViewState extends State<BrowseBountiesView> {
  final _service = BountyService();

  Color _statusColor(BountyStatus s) {
    switch (s) {
      case BountyStatus.open:
        return Colors.green;
      case BountyStatus.inProgress:
        return Colors.amber;
      case BountyStatus.completed:
        return Colors.blue;
      case BountyStatus.cancelled:
        return Colors.grey;
    }
  }

  String _statusLabel(BountyStatus s) {
    switch (s) {
      case BountyStatus.open:
        return 'Open';
      case BountyStatus.inProgress:
        return 'Claimed';
      case BountyStatus.completed:
        return 'Completed';
      case BountyStatus.cancelled:
        return 'Cancelled';
    }
  }

  Future<void> _handleAction(BountyEntity b) async {
    final uid = AppAuth.uid;
    try {
      if (b.status == BountyStatus.open && b.posterId != uid) {
        await _service.claimBounty(b.id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bounty claimed! Get building.')));
      } else if (b.status == BountyStatus.inProgress && b.posterId == uid) {
        await _service.markComplete(b.id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment released! 🎉')));
      } else if (b.status == BountyStatus.open && b.posterId == uid) {
        await _service.cancelBounty(b.id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bounty cancelled, CP refunded')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppAuth.uid;

    return Scaffold(
      backgroundColor: NGColors.background,
      appBar: AppBar(
        backgroundColor: NGColors.surface,
        title: const Text('Bounties', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateBountyView())),
          ),
        ],
      ),
      body: StreamBuilder<List<BountyEntity>>(
        stream: _service.browseStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final bounties = snapshot.data!;
          if (bounties.isEmpty) {
            return Center(child: Text('No bounties yet — post the first one!', style: TextStyle(color: NGColors.textMuted)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bounties.length,
            itemBuilder: (context, index) {
              final b = bounties[index];
              final isPoster = b.posterId == uid;
              final canClaim = b.status == BountyStatus.open && !isPoster;
              final canComplete = b.status == BountyStatus.inProgress && isPoster;
              final canCancel = b.status == BountyStatus.open && isPoster;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: NGColors.surface, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(b.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _statusColor(b.status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_statusLabel(b.status), style: TextStyle(color: _statusColor(b.status), fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(b.description, style: TextStyle(color: NGColors.textMuted, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.monetization_on_outlined, size: 16, color: NGColors.accent),
                        const SizedBox(width: 4),
                        Text('${b.rewardCp.toStringAsFixed(0)} CP', style: TextStyle(color: NGColors.accent, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Text('by @${b.posterUsername}', style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
                        if (b.claimedByUsername != null) ...[
                          const SizedBox(width: 12),
                          Text('claimed by @${b.claimedByUsername}', style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
                        ],
                      ],
                    ),
                    if (canClaim || canComplete || canCancel) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _handleAction(b),
                          style: ElevatedButton.styleFrom(backgroundColor: NGColors.accent),
                          child: Text(
                            canClaim ? 'Claim this bounty' : canComplete ? 'Mark complete & pay' : 'Cancel & refund',
                          ),
                        ),
                      ),
                    ],
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
