import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/gist_hub/data/services/gist_service.dart';
import 'package:nigergram/features/gist_hub/presentation/widgets/gist_post_card.dart';
import 'package:nigergram/features/gist_hub/domain/entities/gist_post_entity.dart';
import 'package:nigergram/features/gist_hub/presentation/view/gist_create_post.dart';
import 'package:nigergram/features/gist_hub/presentation/view/browse_communities_view.dart';
import 'package:nigergram/features/gist_hub/presentation/view/browse_bounties_view.dart';
import 'package:nigergram/features/gist_hub/presentation/view/browse_audio_view.dart';
import 'package:nigergram/features/exchange/presentation/view/exchange_browse_view.dart';

class GistHubView extends StatefulWidget {
  const GistHubView({super.key});

  @override
  State<GistHubView> createState() => _GistHubViewState();
}

class _GistHubViewState extends State<GistHubView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GistService _service = GistService();
  int _totalGists = 0;

  // Created exactly once per filter, in initState, and reused for the
  // lifetime of this State object — prevents the "Stream has already
  // been listened to" crash caused by re-creating these streams on
  // every rebuild (see GistService.getGistFeedStream, which now also
  // wraps everything in .asBroadcastStream() as a second layer of
  // protection).
  late final Stream<List<Map<String, dynamic>>> _trendingStream;
  late final Stream<List<Map<String, dynamic>>> _latestStream;
  late final Stream<List<Map<String, dynamic>>> _pollsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);

    _trendingStream = _service.getGistFeedStream(filter: 'trending');
    _latestStream = _service.getGistFeedStream(filter: 'latest');
    _pollsStream = _service.getGistFeedStream(filter: 'polls');

    _loadGistCount();
  }

  Future<void> _loadGistCount() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('gist_posts').get();
      setState(() {
        _totalGists = snap.docs.length;
      });
    } catch (_) {}
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
        toolbarHeight: 70,
        title: Row(
          children: [
            const Text(
              '🔨 The Forge',
              style: TextStyle(
                color: NGColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: NGColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: NGColors.accent.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    color: NGColors.accent,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_totalGists Builds',
                    style: TextStyle(
                      color: NGColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: NGColors.accent,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: NGColors.textPrimary,
              unselectedLabelColor: NGColors.textMuted,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: '🔥 Heating Up'),
                Tab(text: '📰 Latest'),
                Tab(text: '📊 Polls'),
                Tab(text: '👥 Communities'),
                Tab(text: '🎯 Bounties'),
                Tab(text: '🎙️ Audio'),
                Tab(text: '💱 Exchange'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeed('trending', _trendingStream),
          _buildFeed('latest', _latestStream),
          _buildFeed('polls', _pollsStream),
          const BrowseCommunitiesView(),
          const BrowseBountiesView(),
          const BrowseAudioView(),
          const ExchangeBrowseView(),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          // The generic "Drop Gist" FAB only makes sense on the first 3
          // tabs — Communities, Bounties, Audio, and now Exchange each
          // manage their own "+"/record button inside their own view instead.
          if (_tabController.index >= 3) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 100.0),
            child: FloatingActionButton(
              backgroundColor: NGColors.accent,
              elevation: 8,
              child: const Icon(Icons.add, color: Colors.white, size: 30),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GistCreatePost()),
                ).then((_) {
                  _loadGistCount();
                  setState(() {});
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeed(String filter, Stream<List<Map<String, dynamic>>> stream) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: NGColors.textMuted,
                  size: 56,
                ),
                const SizedBox(height: 16),
                Text(
                  'Can\'t load feed right now',
                  style: TextStyle(
                    color: NGColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check your connection and try again',
                  style: TextStyle(
                    color: NGColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NGColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
                  filter == 'trending'
                      ? Icons.whatshot_outlined
                      : filter == 'polls'
                          ? Icons.poll_outlined
                          : Icons.chat_bubble_outline,
                  color: NGColors.textMuted,
                  size: 56,
                ),
                const SizedBox(height: 16),
                Text(
                  filter == 'trending'
                      ? 'Nothing heating up yet 🔥'
                      : filter == 'polls'
                          ? 'No polls yet 📊'
                          : 'Nothing here yet',
                  style: TextStyle(
                    color: NGColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  filter == 'trending'
                      ? 'Be the first to start something!'
                      : filter == 'polls'
                          ? 'Create a poll and get opinions!'
                          : 'Share what you\'re building 🔨',
                  style: TextStyle(
                    color: NGColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const GistCreatePost()),
                    ).then((_) {
                      _loadGistCount();
                      setState(() {});
                    });
                  },
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: const Text('Post to the Forge'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NGColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
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
          backgroundColor: NGColors.surface,
          onRefresh: () async {
            _loadGistCount();
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 100),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return GistPostCard(
                post: post,
                service: _service,
                onPostDeleted: () {
                  _loadGistCount();
                  setState(() {});
                },
              );
            },
          ),
        );
      },
    );
  }
}
