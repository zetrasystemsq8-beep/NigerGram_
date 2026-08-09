import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/gist_hub/data/services/community_service.dart';
import 'package:nigergram/features/gist_hub/domain/entities/community_entity.dart';
import 'package:nigergram/features/gist_hub/presentation/view/create_community_view.dart';

class BrowseCommunitiesView extends StatefulWidget {
  const BrowseCommunitiesView({super.key});

  @override
  State<BrowseCommunitiesView> createState() => _BrowseCommunitiesViewState();
}

class _BrowseCommunitiesViewState extends State<BrowseCommunitiesView> {
  final _service = CommunityService();
  final _searchController = TextEditingController();
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NGColors.background,
      appBar: AppBar(
        backgroundColor: NGColors.surface,
        title: const Text('Communities', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateCommunityView()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search communities...',
                hintStyle: TextStyle(color: NGColors.textMuted),
                prefixIcon: Icon(Icons.search, color: NGColors.textMuted),
                filled: true,
                fillColor: NGColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _search = val),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CommunityEntity>>(
              stream: _service.browseStream(searchQuery: _search),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final communities = snapshot.data!;
                if (communities.isEmpty) {
                  return Center(
                    child: Text('No communities yet — create the first one!', style: TextStyle(color: NGColors.textMuted)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: communities.length,
                  itemBuilder: (context, index) {
                    final c = communities[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: NGColors.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: NGColors.accent.withOpacity(0.15),
                            child: Icon(
                              c.type == CommunityType.channel ? Icons.campaign_outlined : Icons.groups_outlined,
                              color: NGColors.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(
                                  '${c.memberCount} members • ${c.type == CommunityType.channel ? "Channel" : "Group"}',
                                  style: TextStyle(color: NGColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _service.joinCommunity(c.id),
                            child: const Text('Join'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
