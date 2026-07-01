// lib/features/gist_hub/presentation/view/gist_hub_view.dart
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
  int _totalGists = 0;

  // Pagination state per tab
  final Map<String, List<GistPostEntity>> _postsMap = {};
  final Map<String, DocumentSnapshot?> _lastDocMap = {};
  final Map<String, bool> _hasMoreMap = {};
  final Map<String, bool> _loadingMap = {};
  final Map<String, bool> _initialLoadingMap = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      // Load data when switching to a tab that hasn't loaded yet
      final filter = _getFilterForIndex(_tabController.index);
      if (!_postsMap.containsKey(filter)) {
        _loadInitial(filter);
      }
    });
    _loadGistCount();
    _loadInitial('trending');
  }

  String _getFilterForIndex(int index) {
    switch (index) {
      case 0: return 'trending';
      case 1: return 'latest';
      case 2: return 'polls';
      default: return 'latest';
    }
  }

  Future<void> _loadGistCount() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('gist_posts').get();
      setState(() {
        _totalGists = snap.docs.length;
      });
    } catch (_) {}
  }

  Future<void> _loadInitial(String filter) async {
    if (_initialLoadingMap[filter] == true) return;
    setState(() {
      _initialLoadingMap[filter] = true;
      _loadingMap[filter] = true;
    });

    try {
      final result = await _service.getGistsPaginated(filter: filter, limit: 10);
      final posts = result.posts.map((data) {
        return GistPostEntity.fromMap(data, data['id'] ?? '');
      }).toList();

      setState(() {
        _postsMap[filter] = posts;
        _lastDocMap[filter] = result.lastDocument;
        _hasMoreMap[filter] = result.hasMore;
        _initialLoadingMap[filter] = false;
        _loadingMap[filter] = false;
      });
    } catch (e) {
      setState(() {
        _initialLoadingMap[filter] = false;
        _loadingMap[filter] = false;
      });
    }
  }

  Future<void> _loadMore(String filter) async {
    if (_loadingMap[filter] == true || _hasMoreMap[filter] == false) return;
    if (_lastDocMap[filter] == null) return;

    setState(() {
      _loadingMap[filter] = true;
    });

    try {
      final result = await _service.getGistsPaginated(
        filter: filter,
        limit: 10,
        lastDoc: _lastDocMap[filter],
      );
      final newPosts = result.posts.map((data) {
        return GistPostEntity.fromMap(data, data['id'] ?? '');
      }).toList();

      setState(() {
        _postsMap[filter] = [...(_postsMap[filter] ?? []), ...newPosts];
        _lastDocMap[filter] = result.lastDocument;
        _hasMoreMap[filter] = result.hasMore;
        _loadingMap[filter] = false;
      });
    } catch (e) {
      setState(() {
        _loadingMap[filter] = false;
      });
    }
  }

  Future<void> _refreshFeed(String filter) async {
    _postsMap.remove(filter);
    _lastDocMap.remove(filter);
    _hasMoreMap.remove(filter);
    _loadingMap.remove(filter);
    _initialLoadingMap.remove(filter);
    await _loadInitial(filter);
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
              '🇳🇬 Gist Hub',
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
                    '$_totalGists Gists',
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
                Tab(text: '🔥 Trending'),
                Tab(text: '📰 Latest'),
                Tab(text: '📊 Polls'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeed('trending'),
          _buildFeed('latest'),
          _buildFeed('polls'),
        ],
      ),
      floatingActionButton: Padding(
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
              // Refresh the current tab
              final filter = _getFilterForIndex(_tabController.index);
              _refreshFeed(filter);
            });
          },
        ),
      ),
    );
  }

  Widget _buildFeed(String filter) {
    final posts = _postsMap[filter] ?? [];
    final isLoading = _initialLoadingMap[filter] == true;
    final isLoadingMore = _loadingMap[filter] == true && posts.isNotEmpty;
    final hasMore = _hasMoreMap[filter] ?? false;

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: NGColors.accent,
        ),
      );
    }

    if (posts.isEmpty) {
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
                  ? 'Nothing trending yet 🔥'
                  : filter == 'polls'
                      ? 'No polls yet 📊'
                      : 'No gist yet',
              style: TextStyle(
                color: NGColors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              filter == 'trending'
                  ? 'Be the first to start a trend!'
                  : filter == 'polls'
                      ? 'Create a poll and get opinions!'
                      : 'Drop your first gist now 🇳🇬',
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
                  _refreshFeed(filter);
                });
              },
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: const Text('Drop Gist'),
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

    return RefreshIndicator(
      color: NGColors.accent,
      backgroundColor: NGColors.surface,
      onRefresh: () => _refreshFeed(filter),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 100) {
            if (hasMore && !isLoadingMore) {
              _loadMore(filter);
            }
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          itemCount: posts.length + (isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == posts.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: CircularProgressIndicator(
                    color: NGColors.accent,
                    strokeWidth: 2,
                  ),
                ),
              );
            }
            final post = posts[index];
            return GistPostCard(
              post: post,
              service: _service,
              onPostDeleted: () {
                _loadGistCount();
                _refreshFeed(filter);
              },
              onPostUpdated: () {
                // Re-fetch this tab to reflect changes
                _refreshFeed(filter);
              },
            );
          },
        ),
      ),
    );
  }
}
