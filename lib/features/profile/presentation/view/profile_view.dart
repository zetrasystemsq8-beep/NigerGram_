import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _userData;
  List<QueryDocumentSnapshot> _userVideos = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final videosSnapshot = await FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _userData = userDoc.data();
          _userVideos = videosSnapshot.docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading Zetra profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF0050)),
        ),
      );
    }

    final username = _userData?['username'] ?? 'nigergram_creator';
    final displayName = _userData?['displayName'] ?? 'NigerGram User';
    final bio = _userData?['bio'] ?? 'Naija Creator 🇳🇬';
    final profilePicUrl = _userData?['profilePicUrl'];
    final followers = _userData?['followers'] ?? 0;
    final following = _userData?['following'] ?? 0;
    final totalLikes = _userData?['totalLikes'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.whiteEfficacy, size: 22),
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Core Profile Identity Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  // High-fidelity Avatar with Neon Border
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFF0050), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF0050).withOpacity(0.2),
                          blurRadius: 12,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(48),
                      child: profilePicUrl != null
                          ? Image.network(profilePicUrl, fit: BoxFit.cover)
                          : Container(
                              color: Colors.grey.shade900,
                              child: const Icon(Icons.person_rounded, color: Colors.white54, size: 50),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Handle Name
                  Text(
                    '@$username',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Professional Metric Counter Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatMetric(following.toString(), 'Following'),
                      _buildDivider(),
                      _buildStatMetric(followers.toString(), 'Followers'),
                      _buildDivider(),
                      _buildStatMetric(totalLikes.toString(), 'Likes'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Clean Bio Content
                  Text(
                    bio,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Sleek Custom Action Row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {}, // Route to Edit Screen later
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white12),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            backgroundColor: Colors.white.withOpacity(0.04),
                          ),
                          child: const Text('Edit profile', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white12),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white.withOpacity(0.04),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.bookmark_border_rounded, color: Colors.white),
                          onPressed: () {},
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 2. High-Fidelity Tab Indicator Bar
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 2,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              tabs: const [
                Tab(icon: Icon(Icons.grid_on_rounded, size: 22)),
                Tab(icon: Icon(Icons.favorite_border_rounded, size: 22)),
              ],
            ),

            // 3. Immersive Content Grid Viewports
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // First Tab: User Personal Video Gallery
                  _userVideos.isEmpty
                      ? _buildEmptyStateView()
                      : GridView.builder(
                          padding: const EdgeInsets.all(2),
                          itemCount: _userVideos.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                            childAspectRatio: 0.68,
                          ),
                          itemBuilder: (context, index) {
                            final video = _userVideos[index].data() as Map<String, dynamic>;
                            final String? thumbnailUrl = video['thumbnailUrl'];
                            final int views = video['views'] ?? 0;

                            return GestureDetector(
                              onTap: () {
                                // Navigate to fullscreen video player feed
                              },
                              child: Container(
                                color: Colors.grey.shade900,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // High-Fidelity Video Preview Thumbnail Asset
                                    thumbnailUrl != null
                                        ? Image.network(thumbnailUrl, fit: BoxFit.cover)
                                        : Container(
                                            color: Colors.grey.shade900,
                                            child: const Icon(Icons.movie_creation_outlined, color: Colors.white24),
                                          ),
                                    
                                    // Bottom Gradient Shield for readable metric text overlay
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                                            stops: const [0.7, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // Live View Counter Badge (TikTok Spec)
                                    Positioned(
                                      bottom: 6,
                                      left: 6,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                                          const SizedBox(width: 1),
                                          Text(
                                            _formatMetrics(views),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  
                  // Second Tab: Liked/Bookmarked Videos Placeholder
                  _buildSavedSectionPlaceholder(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatMetric(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 0.2),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 12,
      width: 1,
      color: Colors.white12,
      margin: const EdgeInsets.symmetric(horizontal: 24),
    );
  }

  Widget _buildEmptyStateView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, color: Colors.white24, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No videos published yet',
              style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your uploaded contents will appear right here.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedSectionPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded, color: Colors.white24, size: 36),
          const SizedBox(height: 12),
          const Text(
            'This user\'s liked videos are private',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _formatMetrics(int num) {
    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(1)}M';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}K';
    }
    return num.toString();
  }
}
