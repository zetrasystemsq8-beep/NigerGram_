import 'package:nigergram/features/explore/presentation/view/explore_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ExploreView extends StatefulWidget {
  const ExploreView({super.key});

  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _trendingVideos = [];
  bool _isSearching = false;
  bool _isLoading = true;
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All', 'Comedy', 'Music', 'Dance',
    'Skit', 'News', 'Sports', 'Fashion', 'Food'
  ];

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('videos')
          .orderBy('likeCount', descending: true)
          .limit(20);

      if (_selectedCategory != 'All') {
        query = FirebaseFirestore.instance
            .collection('videos')
            .where('category', isEqualTo: _selectedCategory)
            .orderBy('timestamp', descending: true)
            .limit(20);
      }

      final snapshot = await query.get();
      setState(() {
        _trendingVideos = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('username', isLessThan: '${query.toLowerCase()}z')
          .limit(10)
          .get();

      final videosSnapshot = await FirebaseFirestore.instance
          .collection('videos')
          .where('description', isGreaterThanOrEqualTo: query)
          .where('description', isLessThan: '${query}z')
          .limit(10)
          .get();

      setState(() {
        _searchResults = [
          ...usersSnapshot.docs.map((doc) =>
              {'type': 'user', 'id': doc.id, ...doc.data()}),
          ...videosSnapshot.docs.map((doc) =>
              {'type': 'video', 'id': doc.id, ...doc.data() as Map<String, dynamic>}),
        ];
      });
    } catch (e) {
      setState(() => _searchResults = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: 'Search creators, videos...',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              _search('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            // Categories
            if (!_isSearching) ...[
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = cat == _selectedCategory;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = cat;
                          _isLoading = true;
                        });
                        _loadTrending();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.red : Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade400,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Trending in Naija 🇳🇬',
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Content
            Expanded(
              child: _isSearching
                  ? _buildSearchResults()
                  : _buildTrendingGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: Colors.grey.shade700, size: 60),
            const SizedBox(height: 12),
            Text(
              'No results found',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final isUser = result['type'] == 'user';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isUser ? Colors.red : Colors.grey.shade700,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isUser ? Icons.person : Icons.play_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUser
                          ? '@${result['username'] ?? 'unknown'}'
                          : result['description'] ?? 'No description',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isUser ? 'Creator' : 'Video',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade700,
                size: 14,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrendingGrid() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.red),
      );
    }

    if (_trendingVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library, color: Colors.grey.shade700, size: 60),
            const SizedBox(height: 12),
            Text(
              'No videos yet in this category',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 0.6,
      ),
      itemCount: _trendingVideos.length,
      itemBuilder: (context, index) {
        final video = _trendingVideos[index];
        return Container(
          color: Colors.grey.shade900,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Icon(Icons.play_circle_outline,
                  color: Colors.white54, size: 36),
              Positioned(
                bottom: 4,
                left: 4,
                right: 4,
                child: Row(
                  children: [
                    const Icon(Icons.favorite,
                        color: Colors.white, size: 11),
                    const SizedBox(width: 2),
                    Text(
                      '${video['likeCount'] ?? 0}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        '@${video['username'] ?? ''}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 9),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
