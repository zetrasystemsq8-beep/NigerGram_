import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  Map<String, dynamic>? _userData;
  List<QueryDocumentSnapshot> _userVideos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );
    }

    final username = _userData?['username'] ?? 'NigerGram User';
    final bio = _userData?['bio'] ?? 'Naija Creator 🇳🇬';
    final followers = _userData?['followers'] ?? 0;
    final following = _userData?['following'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.black,
            pinned: true,
            title: Text(
              '@$username',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: _logout,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile picture
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red, width: 2),
                      color: Colors.grey.shade900,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Username
                  Text(
                    '@$username',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Bio
                  Text(
                    bio,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStat(_userVideos.length.toString(), 'Videos'),
                      const SizedBox(width: 40),
                      _buildStat(followers.toString(), 'Followers'),
                      const SizedBox(width: 40),
                      _buildStat(following.toString(), 'Following'),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Videos grid
          _userVideos.isEmpty
              ? SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.video_library,
                              color: Colors.grey.shade700, size: 60),
                          const SizedBox(height: 12),
                          Text(
                            'No videos yet',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap + to post your first video',
                            style: TextStyle(
                                color: Colors.grey.shade700, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final video = _userVideos[index].data()
                          as Map<String, dynamic>;
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const Icon(Icons.play_circle_outline,
                                color: Colors.white, size: 40),
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: Row(
                                children: [
                                  const Icon(Icons.favorite,
                                      color: Colors.white, size: 12),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${video['likeCount'] ?? 0}',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: _userVideos.length,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                    childAspectRatio: 0.6,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
      ],
    );
  }
}
