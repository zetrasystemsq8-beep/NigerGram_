import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/exchange/data/services/exchange_service.dart';
import 'package:nigergram/features/exchange/presentation/view/exchange_create_view.dart';
import 'package:nigergram/features/exchange/presentation/view/exchange_detail_view.dart';

IconData categoryIcon(String? category) {
  switch (category) {
    case 'software':
      return Icons.code;
    case 'design':
      return Icons.brush_outlined;
    case 'prototype':
      return Icons.precision_manufacturing_outlined;
    case 'research':
      return Icons.science_outlined;
    case 'digital_product':
      return Icons.shopping_bag_outlined;
    case 'service':
      return Icons.handshake_outlined;
    case 'invention':
      return Icons.lightbulb_outline;
    case 'dataset':
      return Icons.dataset_outlined;
    default:
      return Icons.more_horiz;
  }
}

String categoryLabel(String? category) {
  switch (category) {
    case 'software':
      return 'Software';
    case 'design':
      return 'Design';
    case 'prototype':
      return 'Prototype';
    case 'research':
      return 'Research';
    case 'digital_product':
      return 'Digital Product';
    case 'service':
      return 'Service';
    case 'invention':
      return 'Invention';
    case 'dataset':
      return 'Dataset';
    default:
      return 'Other';
  }
}

class ExchangeBrowseView extends StatefulWidget {
  const ExchangeBrowseView({super.key});

  @override
  State<ExchangeBrowseView> createState() => _ExchangeBrowseViewState();
}

class _ExchangeBrowseViewState extends State<ExchangeBrowseView> {
  final _service = ExchangeService();
  ListingStage? _filter;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.browseListings(stage: _filter);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _service.browseListings(stage: _filter);
    });
    await _future;
  }

  void _setFilter(ListingStage? stage) {
    setState(() {
      _filter = stage;
      _future = _service.browseListings(stage: _filter);
    });
  }

  String _relativeTime(String? iso) {
    if (iso == null) return '';
    final date = DateTime.tryParse(iso);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _filterChip(String label, ListingStage? stage) {
    final selected = _filter == stage;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _setFilter(stage),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? NGColors.accent : NGColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? NGColors.accent : NGColors.divider),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : NGColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _stageBadge(String? stage) {
    IconData icon;
    Color color;
    String label;
    switch (stage) {
      case 'prototype':
        icon = Icons.precision_manufacturing_outlined;
        color = const Color(0xFF64B5F6);
        label = 'PROTOTYPE';
        break;
      case 'product':
        icon = Icons.rocket_launch_outlined;
        color = const Color(0xFF81C784);
        label = 'PRODUCT';
        break;
      default:
        icon = Icons.lightbulb_outline;
        color = const Color(0xFFFFB74D);
        label = 'IDEA';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.16), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold)),
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
        title: const Text('Exchange', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: NGColors.accent,
        icon: const Icon(Icons.add),
        label: const Text('Create'),
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExchangeCreateView()),
          );
          if (created == true) _reload();
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('All', null),
                  _filterChip('💡 Idea', ListingStage.idea),
                  _filterChip('🧪 Prototype', ListingStage.prototype),
                  _filterChip('🚀 Product', ListingStage.product),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Text('Failed to load: ${snapshot.error}',
                                style: TextStyle(color: NGColors.textMuted)),
                          ),
                        ),
                      ],
                    );
                  }
                  final listings = snapshot.data ?? [];
                  if (listings.isEmpty) {
                    return ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 80),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.storefront_outlined, size: 40, color: NGColors.textMuted.withOpacity(0.6)),
                                const SizedBox(height: 10),
                                Text('Nothing here yet', style: TextStyle(color: NGColors.textMuted)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    itemCount: listings.length,
                    itemBuilder: (context, index) {
                      final item = listings[index];
                      final stage = item['stage'] as String?;
                      final category = item['category'] as String?;
                      final price = item['price'];
                      final fundingGoal = item['funding_goal'];
                      final fundingRaised = item['funding_raised'];

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExchangeDetailView(listingId: item['id'] as String),
                            ),
                          );
                          _reload();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: NGColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _stageBadge(stage),
                                  const Spacer(),
                                  Text(_relativeTime(item['created_at'] as String?),
                                      style: TextStyle(color: NGColors.textMuted, fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text((item['title'] ?? '').toString(),
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              if ((item['one_liner'] ?? '').toString().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text((item['one_liner']).toString(),
                                    style: TextStyle(color: NGColors.textSecondary, fontSize: 13)),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(categoryIcon(category), size: 13, color: NGColors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(categoryLabel(category),
                                      style: TextStyle(color: NGColors.textMuted, fontSize: 11.5)),
                                  const Spacer(),
                                  if (stage == 'product' && price != null)
                                    Text('₦${price.toString()}',
                                        style: const TextStyle(
                                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  if (stage == 'prototype' && fundingGoal != null)
                                    Text('₦${fundingRaised ?? 0} / ₦$fundingGoal',
                                        style: TextStyle(
                                            color: NGColors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('by @${(item['owner_name'] ?? 'user').toString()}',
                                  style: TextStyle(color: NGColors.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
