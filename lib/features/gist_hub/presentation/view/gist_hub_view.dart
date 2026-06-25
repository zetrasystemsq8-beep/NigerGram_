import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nigergram/features/gist_hub/data/services/gist_service.dart';
import 'package:nigergram/features/gist_hub/presentation/widgets/gist_post_card.dart';
import 'package:nigergram/features/gist_hub/domain/entities/gist_post_entity.dart';
import 'package:nigergram/features/profile/presentation/view/profile_view.dart';

class GistHubView extends StatefulWidget {
  const GistHubView({super.key});

  @override
  State<GistHubView> createState() => _GistHubViewState();
}

class _GistHubViewState extends State<GistHubView> {
  final GistService _service = GistService();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: NGColors.background,
        appBar: AppBar(
          backgroundColor: NGColors.surface,
          elevation: 0,
          title: const Text('Gist Hub'),
          bottom: TabBar(
            indicatorColor: NGColors.accent,
            tabs: const [
              Tab(text: 'Trending'),
              Tab(text: 'Latest'),
              Tab(text: 'Polls'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFeed('Trending'),
            _buildFeed('Latest'),
            _buildFeed('Polls'),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: NGColors.accent,
          child: const Icon(Icons.create),
          onPressed: () => GoRouter.of(context).push('/gist-hub/create'),
        ),
      ),
    );
  }

  Widget _buildFeed(String filter) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.getGistFeedStream(filter: filter),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Failed to load feed', style: TextStyle(color: NGColors.textSecondary)));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rawList = snap.data!;
        if (rawList.isEmpty) {
          return Center(child: Text('No posts', style: TextStyle(color: NGColors.textSecondary)));
        }

        final posts = rawList.map((m) {
          if (m is GistPostEntity) return m;
          final id = (m['id'] ?? '') as String;
          return GistPostEntity.fromJson(m as Map<String, dynamic>, id);
        }).toList();

        return RefreshIndicator(
          onRefresh: () async => Future.value(),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final p = posts[index];
              return GistPostCard(post: p, service: _service);
            },
          ),
        );
      },
    );
  }
}
