import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/gist_hub/data/services/gist_service.dart';
import 'package:nigergram/features/gist_hub/presentation/widgets/gist_post_card.dart';
import 'package:nigergram/features/gist_hub/domain/entities/gist_post_entity.dart';
import 'package:nigergram/features/gist_hub/presentation/view/gist_create_post.dart';

class GistHubView extends StatefulWidget {
  const GistHubView({super.key});

  @override
  State<GistHubView> createState() => _GistHubViewState();
}

class _GistHubViewState extends State<GistHubView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GistService _service = GistService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NGColors.background,
      appBar: AppBar(
        backgroundColor: NGColors.surface,
        elevation: 0,
        title: const Text(
          'Gist Hub',
          style: TextStyle(
            color: NGColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: NGColors.accent,
          labelColor: NGColors.textPrimary,
          unselectedLabelColor: NGColors.textMuted,
          tabs: const [
            Tab(text: 'Latest'),
            Tab(text: 'Trending'),
            Tab(text: 'Polls'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeed('Latest'),
          _buildFeed('Trending'),
          _buildFeed('Polls'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: NGColors.accent,
        child: const Icon(Icons.create, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GistCreatePost()),
          ).then((_) => setState(() {}));
        },
      ),
    );
  }

  Widget _buildFeed(String filter) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.getGistFeedStream(filter: filter),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: NGColors.textMuted,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load feed',
                  style: TextStyle(
                    color: NGColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NGColors.accent,
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: NGColors.accent,
            ),
          );
        }

        final rawData = snapshot.data!;

        if (rawData.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  color: NGColors.textMuted,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'No gist yet',
                  style: TextStyle(
                    color: NGColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to drop gist!',
                  style: TextStyle(
                    color: NGColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        final posts = rawData.map((data) {
          return GistPostEntity.fromMap(data, data['id'] ?? '');
        }).toList();

        return RefreshIndicator(
          color: NGColors.accent,
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return GistPostCard(
                post: post,
                service: _service,
              );
            },
          ),
        );
      },
    );
  }
}
