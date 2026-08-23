import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/app_auth.dart';
import 'package:nigergram/features/exchange/data/services/exchange_service.dart';
import 'package:nigergram/features/exchange/presentation/view/exchange_browse_view.dart' show categoryIcon, categoryLabel;

class ExchangeDetailView extends StatefulWidget {
  final String listingId;
  const ExchangeDetailView({required this.listingId, super.key});

  @override
  State<ExchangeDetailView> createState() => _ExchangeDetailViewState();
}

class _ExchangeDetailViewState extends State<ExchangeDetailView> {
  final _service = ExchangeService();
  final _overviewIdController = TextEditingController();

  Map<String, dynamic>? _listing;
  Map<String, dynamic>? _overview;
  Map<String, dynamic>? _tribunalStatus;
  bool _isLoading = true;
  bool _isAttaching = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _overviewIdController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final listing = await _service.getListing(widget.listingId);
      Map<String, dynamic>? overview;
      Map<String, dynamic>? tribunalStatus;

      final overviewId = listing?['overview_id'] as String?;
      if (overviewId != null) {
        overview = await _service.getCrucibleOverview(overviewId);
        tribunalStatus = await _service.getTribunalStatus(overviewId);
      }

      if (mounted) {
        setState(() {
          _listing = listing;
          _overview = overview;
          _tribunalStatus = tribunalStatus;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = '$e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _attachOverview() async {
    final id = _overviewIdController.text.trim();
    if (id.isEmpty) return;
    setState(() => _isAttaching = true);
    try {
      await _service.attachCrucibleOverview(widget.listingId, id);
      _overviewIdController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Crucible proof attached')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _isAttaching = false);
    }
  }

  Future<void> _expressInterest() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NGColors.surface,
        title: const Text('Express Interest', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Optional message to the creator...',
            hintStyle: TextStyle(color: NGColors.textMuted),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: NGColors.accent),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.recordInteraction(
        listingId: widget.listingId,
        type: 'interest',
        message: controller.text.trim().isEmpty ? null : controller.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Interest sent to the creator')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _support(double? fundingGoal) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NGColors.surface,
        title: const Text('Support this Prototype', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Amount in CP',
            hintStyle: TextStyle(color: NGColors.textMuted),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: NGColors.accent),
            child: const Text('Support'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final amount = double.tryParse(controller.text.trim());
    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount')),
        );
      }
      return;
    }

    try {
      await _service.recordInteraction(listingId: widget.listingId, type: 'support', amount: amount);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support recorded — thank you')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _buy(double? price) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NGColors.surface,
        title: const Text('Confirm Purchase', style: TextStyle(color: Colors.white)),
        content: Text('Buy this for ₦${price ?? 0}?', style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: NGColors.accent),
            child: const Text('Buy'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.recordInteraction(listingId: widget.listingId, type: 'purchase', amount: price);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase complete')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Widget _badgeCard({
    required IconData icon,
    required Color color,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NGColors.background,
      appBar: AppBar(
        backgroundColor: NGColors.surface,
        title: const Text('Listing', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Text('Failed to load: $_loadError', style: TextStyle(color: NGColors.textMuted)),
                )
              : _listing == null
                  ? Center(child: Text('Listing not found', style: TextStyle(color: NGColors.textMuted)))
                  : _buildContent(),
    );
  }

  Widget _buildContent() {
    final listing = _listing!;
    final isOwner = listing['owner_id'] == AppAuth.uid;
    final stage = listing['stage'] as String?;
    final category = listing['category'] as String?;
    final price = (listing['price'] as num?)?.toDouble();
    final fundingGoal = (listing['funding_goal'] as num?)?.toDouble();
    final fundingRaised = (listing['funding_raised'] as num?)?.toDouble() ?? 0;
    final hasOverview = _overview != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(categoryIcon(category), size: 15, color: NGColors.accent),
              const SizedBox(width: 6),
              Text(categoryLabel(category),
                  style: TextStyle(color: NGColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('by @${(listing['owner_name'] ?? 'user').toString()}',
                  style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Text((listing['title'] ?? '').toString(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
          if ((listing['one_liner'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(listing['one_liner'].toString(),
                style: TextStyle(color: NGColors.textSecondary, fontSize: 14.5, height: 1.4)),
          ],
          if ((listing['description'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(listing['description'].toString(),
                style: TextStyle(color: NGColors.textSecondary, fontSize: 13.5, height: 1.5)),
          ],
          const SizedBox(height: 20),

          // Verification
          if (hasOverview) ...[
            _badgeCard(
              icon: Icons.local_fire_department,
              color: Colors.deepOrange,
              title: 'Crucible Tested',
              child: Text(
                (_overview!['executive_summary'] ?? _overview!['one_liner'] ?? 'Passed Crucible pressure testing.')
                    .toString(),
                style: TextStyle(color: NGColors.textSecondary, fontSize: 13, height: 1.4),
              ),
            ),
            if (_tribunalStatus == null)
              _badgeCard(
                icon: Icons.balance,
                color: NGColors.textMuted,
                title: 'Not yet reviewed by Tribunal',
                child: Text(
                  'The creator can submit this Overview to Tribunal for expert review.',
                  style: TextStyle(color: NGColors.textMuted, fontSize: 12.5),
                ),
              )
            else if (_tribunalStatus!['status'] == 'in_progress')
              _badgeCard(
                icon: Icons.balance,
                color: const Color(0xFF64B5F6),
                title: 'Under Tribunal Review',
                child: Text(
                  '${_tribunalStatus!['review_count']} expert review(s) submitted so far.',
                  style: TextStyle(color: NGColors.textSecondary, fontSize: 12.5),
                ),
              )
            else
              _badgeCard(
                icon: Icons.balance,
                color: const Color(0xFF81C784),
                title: 'Tribunal Reviewed',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((_tribunalStatus!['final_verdict'] ?? '').toString(),
                        style: TextStyle(color: NGColors.textSecondary, fontSize: 13, height: 1.4)),
                    if (_tribunalStatus!['confidence_level'] != null) ...[
                      const SizedBox(height: 6),
                      Text('Confidence: ${_tribunalStatus!['confidence_level']}',
                          style: TextStyle(color: NGColors.textMuted, fontSize: 11.5)),
                    ],
                  ],
                ),
              ),
          ] else if (isOwner) ...[
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: NGColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: NGColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Want to prove it?',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Complete a pressure test in Crucible, then paste the Overview ID here.',
                      style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _overviewIdController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Overview ID',
                            hintStyle: TextStyle(color: NGColors.textMuted),
                            filled: true,
                            fillColor: NGColors.background,
                            border:
                                OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isAttaching ? null : _attachOverview,
                        style: ElevatedButton.styleFrom(backgroundColor: NGColors.accent),
                        child: _isAttaching
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Attach'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Stage-specific action
          if (stage == 'idea')
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _expressInterest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: NGColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                icon: const Icon(Icons.emoji_objects_outlined),
                label: const Text('Express Interest', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          else if (stage == 'prototype') ...[
            if (fundingGoal != null && fundingGoal > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (fundingRaised / fundingGoal).clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: NGColors.surface,
                  color: NGColors.accent,
                ),
              ),
              const SizedBox(height: 6),
              Text('₦$fundingRaised raised of ₦$fundingGoal goal',
                  style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _support(fundingGoal),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NGColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                icon: const Icon(Icons.volunteer_activism_outlined),
                label: const Text('Support', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ] else if (stage == 'product')
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _buy(price),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NGColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: Text(price != null ? 'Buy for ₦$price' : 'Buy',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
