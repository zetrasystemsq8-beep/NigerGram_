// lib/features/profile/presentation/view/profile_view.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _userData;
  List<QueryDocumentSnapshot> _userVideos = [];
  List<QueryDocumentSnapshot> _privateVideos = [];
  List<QueryDocumentSnapshot> _bookmarkedVideos = [];
  List<QueryDocumentSnapshot> _likedVideos = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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

      // Load public videos
      final videosSnapshot = await FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: user.uid)
          .where('isPrivate', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .get();

      // Load private videos
      final privateSnapshot = await FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: user.uid)
          .where('isPrivate', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .get();

      // Load bookmarked videos
      final bookmarkSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bookmarks')
          .orderBy('timestamp', descending: true)
          .get();

      // Load liked videos
      final likeSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('likes')
          .orderBy('timestamp', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _userData = userDoc.data();
          _userVideos = videosSnapshot.docs;
          _privateVideos = privateSnapshot.docs;
          _bookmarkedVideos = bookmarkSnapshot.docs;
          _likedVideos = likeSnapshot.docs;
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
    HapticFeedback.mediumImpact();
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go('/login');
  }

  Future<void> _updateProfileData(String newName, String newUsername, String newBio) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Sanitize input strings for production database safety
    final cleanName = newName.trim();
    final cleanUsername = newUsername.trim().toLowerCase();
    final cleanBio = newBio.trim();

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'displayName': cleanName,
        'username': cleanUsername,
        'bio': cleanBio,
      });

      await _loadProfile();
    } catch (e) {
      debugPrint('Database write failure: $e');
      rethrow;
    }
  }

  void _showEditProfileSheet() {
    HapticFeedback.mediumImpact();

    final currentUsername = _userData?['username'] ?? '';
    final currentDisplayName = _userData?['displayName'] ?? '';
    final currentBio = _userData?['bio'] ?? '';

    final nameController = TextEditingController(text: currentDisplayName);
    final usernameController = TextEditingController(text: currentUsername);
    final bioController = TextEditingController(text: currentBio);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0F11),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Form Header Accent Handle Bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Edit Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          // Subtle production branding badge inside operational views
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF0050).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ZETRA LAB',
                              style: TextStyle(
                                color: Color(0xFFFF0050),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Name input matrix field
                      const Text(
                        'Name',
                        style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        maxLength: 30,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        decoration: _buildInputDecoration('Enter your display name'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Name cannot be blank' : null,
                      ),
                      const SizedBox(height: 16),
                      // Handle configuration frame
                      const Text(
                        'Username',
                        style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: usernameController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        maxLength: 20,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]')),
                        ],
                        decoration: _buildInputDecoration('Enter raw username handle'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Username handle is mandatory';
                          if (v.trim().length < 3) return 'Handle requires 3 or more characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Creator bio editor frame
                      const Text(
                        'Bio',
                        style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: bioController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        maxLines: 3,
                        maxLength: 80,
                        decoration: _buildInputDecoration('Tell NigerGram about yourself...'),
                      ),
                      const SizedBox(height: 24),
                      // Safe atomic operation save layout triggers
                      ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (formKey.currentState!.validate()) {
                                  setModalState(() => isSaving = true);
                                  HapticFeedback.mediumImpact();
                                  try {
                                    await _updateProfileData(
                                      nameController.text,
                                      usernameController.text,
                                      bioController.text,
                                    );
                                    if (context.mounted) Navigator.pop(context);
                                  } catch (e) {
                                    setModalState(() => isSaving = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Failed synchronization engine routine.'),
                                        backgroundColor: Color(0xFFFF0050),
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF0050),
                          disabledBackgroundColor: const Color(0xFFFF0050).withOpacity(0.4),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
      filled: true,
      fillColor: Colors.white.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white10),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFFF0050), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent, width: 15),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF0050),
            strokeWidth: 3,
          ),
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
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 22),
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFFF0050),
          backgroundColor: Colors.grey.shade900,
          onRefresh: _loadProfile,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Column(
                      children: [
                        // Avatar View Layout with edit overlay badge
                        Center(
                          child: Stack(
                            children: [
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFFF0050), width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF0050).withOpacity(0.15),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    )
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(48),
                                    child: profilePicUrl != null
                                        ? Image.network(
                                            profilePicUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              color: Colors.grey.shade900,
                                              child: const Icon(Icons.person_rounded, color: Colors.white38, size: 50),
                                            ),
                                          )
                                        : Container(
                                            color: Colors.grey.shade900,
                                            child: const Icon(Icons.person_rounded, color: Colors.white38, size: 50),
                                          ),
                                  ),
                                ),
                              ),
                              // Edit badge overlay
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFFF0050),
                                    border: Border.all(color: Colors.black, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Username Handle Display
                        Text(
                          '@$username',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Verification Status Badge Indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0050).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, color: Color(0xFFFF0050), size: 14),
                              SizedBox(width: 4),
                              Text(
                                'NigerGram Creator',
                                style: TextStyle(
                                  color: Color(0xFFFF0050),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Stats Aggregation Layout - Following, Followers, Likes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatMetric(following.toString(), 'Following'),
                            _buildVerticalDivider(),
                            _buildStatMetric(followers.toString(), 'Followers'),
                            _buildVerticalDivider(),
                            _buildStatMetric(totalLikes.toString(), 'Likes'),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Creator Bio
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            bio,
                            style: const TextStyle(
                              color: Color(0xCCFFFFFF), // Smooth high-fidelity 80% opacity white
                              fontSize: 13,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // High Fidelity Functional Quick Action Row
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _showEditProfileSheet,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white12),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white.withOpacity(0.05),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Edit profile',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white12),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.white.withOpacity(0.05),
                                ),
                                child: const Icon(
                                  Icons.bookmark_border_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Master Branding Footnote Layout Component
                        const Text(
                          'FROM ZETRA LAB',
                          style: TextStyle(
                            color: Colors.white10,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.white,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorWeight: 1.5,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white38,
                      dividerColor: Colors.white10,
                      onTap: (_) => HapticFeedback.lightImpact(),
                      tabs: const [
                        Tab(icon: Icon(Icons.grid_on_rounded, size: 20), text: 'My Videos'),
                        Tab(icon: Icon(Icons.lock_outline_rounded, size: 20), text: 'Private'),
                        Tab(icon: Icon(Icons.bookmark_border_rounded, size: 20), text: 'Bookmarks'),
                        Tab(icon: Icon(Icons.favorite_border_rounded, size: 20), text: 'Liked'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: My Videos - 3-column layout with post thumbnails and local like counts
                _userVideos.isEmpty
                    ? _buildEmptyStateView('No videos published yet', 'Your uploaded content will appear right here.')
                    : GridView.builder(
                        padding: const EdgeInsets.all(1),
                        itemCount: _userVideos.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 1.5,
                          mainAxisSpacing: 1.5,
                          childAspectRatio: 0.72,
                        ),
                        itemBuilder: (context, index) {
                          final video = _userVideos[index].data() as Map<String, dynamic>;
                          final String? thumbnailUrl = video['thumbnailUrl'];
                          final int likes = video['likeCount'] ?? 0;
                          final String videoId = _userVideos[index].id;

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              context.push('/video-detail/$videoId');
                            },
                            child: Container(
                              color: const Color(0xFF0A0A0A),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  thumbnailUrl != null
                                      ? Image.network(
                                          thumbnailUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => _buildPlaceholderThumbnailGrid(),
                                        )
                                      : _buildPlaceholderThumbnailGrid(),
                                  // Premium Dark Vignette Gradient Bottom Cover
                                  Positioned.fill(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black45,
                                            Colors.black87,
                                          ],
                                          stops: [0.6, 0.85, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Like count overlay
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    right: 8,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.favorite_rounded, color: Color(0xFFFE2C55), size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatMetrics(likes),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
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

                // Tab 2: Private Videos - securely hidden from public views
                _privateVideos.isEmpty
                    ? _buildEmptyStateView('No private videos', 'Your private content will appear right here.')
                    : GridView.builder(
                        padding: const EdgeInsets.all(1),
                        itemCount: _privateVideos.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 1.5,
                          mainAxisSpacing: 1.5,
                          childAspectRatio: 0.72,
                        ),
                        itemBuilder: (context, index) {
                          final video = _privateVideos[index].data() as Map<String, dynamic>;
                          final String? thumbnailUrl = video['thumbnailUrl'];
                          final String videoId = _privateVideos[index].id;

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              context.push('/video-detail/$videoId');
                            },
                            child: Container(
                              color: const Color(0xFF0A0A0A),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  thumbnailUrl != null
                                      ? Image.network(
                                          thumbnailUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => _buildPlaceholderThumbnailGrid(),
                                        )
                                      : _buildPlaceholderThumbnailGrid(),
                                  // Dark overlay with lock icon
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.5),
                                            Colors.black.withOpacity(0.9),
                                          ],
                                          stops: const [0.6, 0.85, 1.0],
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.lock_rounded,
                                          color: Colors.white.withOpacity(0.5),
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                // Tab 3: Bookmarked Videos - saved collections
                _bookmarkedVideos.isEmpty
                    ? _buildEmptyStateView('No bookmarks yet', 'Save videos to your bookmarks collection.')
                    : GridView.builder(
                        padding: const EdgeInsets.all(1),
                        itemCount: _bookmarkedVideos.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 1.5,
                          mainAxisSpacing: 1.5,
                          childAspectRatio: 0.72,
                        ),
                        itemBuilder: (context, index) {
                          final bookmarkData = _bookmarkedVideos[index].data() as Map<String, dynamic>;
                          final String? thumbnailUrl = bookmarkData['thumbnailUrl'];
                          final String videoId = bookmarkData['videoId'] ?? '';

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              if (videoId.isNotEmpty) context.push('/video-detail/$videoId');
                            },
                            child: Container(
                              color: const Color(0xFF0A0A0A),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  thumbnailUrl != null
                                      ? Image.network(
                                          thumbnailUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => _buildPlaceholderThumbnailGrid(),
                                        )
                                      : _buildPlaceholderThumbnailGrid(),
                                  Positioned.fill(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black45,
                                            Colors.black87,
                                          ],
                                          stops: [0.6, 0.85, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    right: 8,
                                    child: const Icon(
                                      Icons.bookmark_rounded,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                // Tab 4: Liked Videos - historical video feed log of items liked by this user
                _likedVideos.isEmpty
                    ? _buildEmptyStateView('No liked videos yet', 'Your liked videos will appear here.')
                    : GridView.builder(
                        padding: const EdgeInsets.all(1),
                        itemCount: _likedVideos.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 1.5,
                          mainAxisSpacing: 1.5,
                          childAspectRatio: 0.72,
                        ),
                        itemBuilder: (context, index) {
                          final likeData = _likedVideos[index].data() as Map<String, dynamic>;
                          final String? thumbnailUrl = likeData['thumbnailUrl'];
                          final String videoId = likeData['videoId'] ?? '';

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              if (videoId.isNotEmpty) context.push('/video-detail/$videoId');
                            },
                            child: Container(
                              color: const Color(0xFF0A0A0A),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  thumbnailUrl != null
                                      ? Image.network(
                                          thumbnailUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => _buildPlaceholderThumbnailGrid(),
                                        )
                                      : _buildPlaceholderThumbnailGrid(),
                                  Positioned.fill(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black45,
                                            Colors.black87,
                                          ],
                                          stops: [0.6, 0.85, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    right: 8,
                                    child: const Icon(
                                      Icons.favorite_rounded,
                                      color: Color(0xFFFE2C55),
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatMetric(String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 14,
      width: 1,
      color: Colors.white12,
    );
  }

  Widget _buildPlaceholderThumbnailGrid() {
    return Container(
      color: Colors.grey.shade900,
      child: Center(
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0x40000000),
          ),
          padding: const EdgeInsets.all(8),
          child: const Icon(Icons.movie_filter_rounded, color: Colors.white12, size: 24),
        ),
      ),
    );
  }

  Widget _buildEmptyStateView(String title, String description) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.video_library_outlined, color: Colors.white38, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
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

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.black,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
