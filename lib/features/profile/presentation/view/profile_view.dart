// lib/features/profile/presentation/view/profile_view.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class ProfileView extends StatefulWidget {
  final String? userId;

  const ProfileView({super.key, this.userId});

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
  bool _isCurrentUser = true;
  bool _isUploadingContent = false;
  double _uploadProgress = 0.0;
  
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  // Low-Data Infrastructure Pagination Clamps
  final int _documentPaginationLimit = 18;
  DocumentSnapshot? _lastVideoDoc;
  bool _hasMoreVideos = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    final currentAuthUser = FirebaseAuth.instance.currentUser;
    _isCurrentUser = widget.userId == null || widget.userId == currentAuthUser?.uid;
    _tabController = TabController(length: _isCurrentUser ? 4 : 2, vsync: this);
    
    _loadProfileWorkspace();
    _scrollController.addListener(_onScrollPaginationCheck);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScrollPaginationCheck() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoadingMore && _hasMoreVideos && _tabController.index == 0) {
        _loadMoreVideos();
      }
    }
  }

  // Deep Architecture Query Loader
  Future<void> _loadProfileWorkspace() async {
    final currentAuthUser = FirebaseAuth.instance.currentUser;
    final targetUserId = widget.userId ?? currentAuthUser?.uid;
    if (targetUserId == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .get();

      final videosSnapshot = await FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: targetUserId)
          .where('isPrivate', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(_documentPaginationLimit)
          .get();

      final likeSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .collection('likes')
          .orderBy('timestamp', descending: true)
          .get();

      if (videosSnapshot.docs.isNotEmpty) {
        _lastVideoDoc = videosSnapshot.docs.last;
        _hasMoreVideos = videosSnapshot.docs.length == _documentPaginationLimit;
      } else {
        _hasMoreVideos = false;
      }

      if (_isCurrentUser) {
        final privateSnapshot = await FirebaseFirestore.instance
            .collection('videos')
            .where('userId', isEqualTo: targetUserId)
            .where('isPrivate', isEqualTo: true)
            .orderBy('timestamp', descending: true)
            .get();

        final bookmarkSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(targetUserId)
            .collection('bookmarks')
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
      } else {
        if (mounted) {
          setState(() {
            _userData = userDoc.data();
            _userVideos = videosSnapshot.docs;
            _likedVideos = likeSnapshot.docs;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Structural profile parsing exception: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreVideos() async {
    final currentAuthUser = FirebaseAuth.instance.currentUser;
    final targetUserId = widget.userId ?? currentAuthUser?.uid;
    if (targetUserId == null || _lastVideoDoc == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final videosSnapshot = await FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: targetUserId)
          .where('isPrivate', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastVideoDoc!)
          .limit(_documentPaginationLimit)
          .get();

      if (mounted) {
        setState(() {
          _userVideos.addAll(videosSnapshot.docs);
          _isLoadingMore = false;
          if (videosSnapshot.docs.isNotEmpty) {
            _lastVideoDoc = videosSnapshot.docs.last;
            _hasMoreVideos = videosSnapshot.docs.length == _documentPaginationLimit;
          } else {
            _hasMoreVideos = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Pagination error: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // Media Capture & Direct Cloud Storage Asset Streaming Engine
  Future<void> _executeMediaUploadPipeline(bool makePrivate) async {
    final currentAuthUser = FirebaseAuth.instance.currentUser;
    if (currentAuthUser == null) return;

    HapticFeedback.heavyImpact();
    final XFile? videoFile = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );

    if (videoFile == null) return;

    setState(() {
      _isUploadingContent = true;
      _uploadProgress = 0.1;
    });

    try {
      final String videoId = FirebaseFirestore.instance.collection('videos').doc().id;
      final File fileToUpload = File(videoFile.path);

      // Low-Data Safe compression/size evaluation mock anchor
      final Reference videoRef = FirebaseStorage.instance
          .ref()
          .child('users/${currentAuthUser.uid}/videos/$videoId.mp4');

      final UploadTask uploadTask = videoRef.putFile(
        fileToUpload,
        SettableMetadata(contentType: 'video/mp4'),
      );

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        if (mounted) {
          setState(() {
            _uploadProgress = 0.1 + (progress * 0.8);
          });
        }
      });

      await uploadTask;
      final String downloadUrl = await videoRef.getDownloadURL();

      // Institutional fallback thumbnail architecture mapping
      const String fallbackThumbnail = 'https://images.unsplash.com/photo-1611162617213-7d7a39e9b1d7?w=500&q=60';

      await FirebaseFirestore.instance.collection('videos').doc(videoId).set({
        'userId': currentAuthUser.uid,
        'videoUrl': downloadUrl,
        'thumbnailUrl': fallbackThumbnail,
        'isPrivate': makePrivate,
        'likeCount': 0,
        'commentCount': 0,
        'shareCount': 0,
        'viewCount': 0,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _loadProfileWorkspace();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NigerGram high-fidelity broadcast post synced successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Critical Upload Engine Failure: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Asset pipeline sync rejected: $e'), backgroundColor: const Color(0xFFFF0050)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingContent = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  Future<void> _updateCoverArtImage() async {
    final currentAuthUser = FirebaseAuth.instance.currentUser;
    if (currentAuthUser == null) return;

    HapticFeedback.mediumImpact();
    final XFile? imageFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (imageFile == null) return;

    setState(() => _isLoading = true);

    try {
      final Reference coverRef = FirebaseStorage.instance
          .ref()
          .child('users/${currentAuthUser.uid}/cover_art.jpg');

      await coverRef.putFile(File(imageFile.path));
      final String downloadUrl = await coverRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(currentAuthUser.uid).update({
        'coverUrl': downloadUrl,
      });

      await _loadProfileWorkspace();
    } catch (e) {
      debugPrint('Cover modification error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfileWorkspaceData(String name, String username, String bio, String insta, String youtube) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'displayName': name.trim(),
        'username': username.trim().toLowerCase(),
        'bio': bio.trim(),
        'instagramLink': insta.trim(),
        'youtubeLink': youtube.trim(),
      });
      await _loadProfileWorkspace();
    } catch (e) {
      rethrow;
    }
  }

  void _showCreatorAnalyticsOverlay() {
    HapticFeedback.mediumImpact();
    
    // Aggregation math evaluation matrices
    int videoCount = _userVideos.length + _privateVideos.length;
    int bookmarkCount = _bookmarkedVideos.length;
    int rawLikes = _userData?['totalLikes'] ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F12),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Icon(Icons.analytics_rounded, color: Color(0xFFFF0050), size: 22),
                  SizedBox(width: 8),
                  Text('Creator Analytics Engine', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Real-time ledger processing node metrics', style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAnalyticsCard('Total Creations', videoCount.toString(), Icons.video_collection_rounded),
                  _buildAnalyticsCard('Direct Likes', _formatMetrics(rawLikes), Icons.favorite_rounded),
                  _buildAnalyticsCard('Saves Cache', bookmarkCount.toString(), Icons.bookmark_rounded),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
                child: Row(
                  children: [
                    const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Data Preservation Mode Active: Content indexing is compressed to preserve cellular bandwidth.',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsCard(String title, String count, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
        child: Column(
          children: [
            Icon(icon, color: Colors.white54, size: 20),
            const SizedBox(height: 8),
            Text(count, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _showAdvancedEditSheet() {
    HapticFeedback.mediumImpact();
    final nameController = TextEditingController(text: _userData?['displayName'] ?? '');
    final usernameController = TextEditingController(text: _userData?['username'] ?? '');
    final bioController = TextEditingController(text: _userData?['bio'] ?? '');
    final instaController = TextEditingController(text: _userData?['instagramLink'] ?? '');
    final youtubeController = TextEditingController(text: _userData?['youtubeLink'] ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0F11),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 20),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 24),
                      const Text('Institutional Profile Sync', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(controller: nameController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _buildInputDecoration('Display Name'), validator: (v) => v!.isEmpty ? 'Field mandated' : null),
                      const SizedBox(height: 12),
                      TextFormField(controller: usernameController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _buildInputDecoration('Username Handle')),
                      const SizedBox(height: 12),
                      TextFormField(controller: bioController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _buildInputDecoration('Creator Biography'), maxLines: 2),
                      const SizedBox(height: 12),
                      TextFormField(controller: instaController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _buildInputDecoration('Instagram Link Sub-path')),
                      const SizedBox(height: 12),
                      TextFormField(controller: youtubeController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _buildInputDecoration('YouTube Channel Link Sub-path')),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: isSaving ? null : () async {
                          if (formKey.currentState!.validate()) {
                            setModalState(() => isSaving = true);
                            try {
                              await _updateProfileWorkspaceData(nameController.text, usernameController.text, bioController.text, instaController.text, youtubeController.text);
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              setModalState(() => isSaving = false);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF0050), padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Synchronize Profiles', style: TextStyle(color: Colors.white)),
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

  void _showMediaPostActionSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F12),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Publish Broadcast Node', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.public_rounded, color: Colors.greenAccent),
              title: const Text('Post to Global Public Feed', style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                _executeMediaUploadPipeline(false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline_rounded, color: Color(0xFFFF0050)),
              title: const Text('Post to Protected Encryption Cloud (Private)', style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                _executeMediaUploadPipeline(true);
              },
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      filled: true,
      fillColor: Colors.white.withOpacity(0.02),
      enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white10), borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFFF0050)), borderRadius: BorderRadius.circular(8)),
    );
  }

  String _formatMetrics(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Color(0xFFFF0050))));
    }

    final username = _userData?['username'] ?? 'nigergram_creator';
    final displayName = _userData?['displayName'] ?? 'NigerGram Creator';
    final bio = _userData?['bio'] ?? 'Naija Space Content Engine';
    final profilePicUrl = _userData?['profilePicUrl'];
    final coverUrl = _userData?['coverUrl'];
    final followers = _userData?['followers'] ?? 0;
    final following = _userData?['following'] ?? 0;
    final totalLikes = _userData?['totalLikes'] ?? 0;
    final instagramLink = _userData?['instagramLink'] ?? '';
    final youtubeLink = _userData?['youtubeLink'] ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            if (_isUploadingContent)
              Container(
                color: const Color(0xFFFF0050).withOpacity(0.2),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Color(0xFFFF0050), strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pushing high-fidelity components: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFFFF0050),
                onRefresh: _loadProfileWorkspace,
                child: NestedScrollView(
                  controller: _scrollController,
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Interactive Cover Art Canvas Section
                            GestureDetector(
                              onTap: _isCurrentUser ? _updateCoverArtImage : null,
                              child: Container(
                                height: 130,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900,
                                  image: coverUrl != null
                                      ? DecorationImage(image: NetworkImage(coverUrl), fit: BoxFit.cover)
                                      : null,
                                ),
                                child: coverUrl == null && _isCurrentUser
                                    ? const Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_a_photo_rounded, color: Colors.white34, size: 16),
                                            SizedBox(width: 8),
                                            Text('Upload Cover Art Branding', style: TextStyle(color: Colors.white34, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            // Profile Structural Meta-data Alignment layout
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                              child: Column(
                                children: [
                                  Transform.translate(
                                    offset: const Offset(0, -40),
                                    child: Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        Container(
                                          width: 90,
                                          height: 90,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.black, width: 4),
                                            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8)],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(45),
                                            child: profilePicUrl != null
                                                ? Image.network(profilePicUrl, fit: BoxFit.cover, errorBuilder: (context, e, s) => _buildPlaceholderAvatar())
                                                : _buildPlaceholderAvatar(),
                                          ),
                                        ),
                                        if (_isCurrentUser)
                                          GestureDetector(
                                            onTap: _showAdvancedEditSheet,
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: const BoxDecoration(color: Color(0xFFFF0050), shape: BoxShape.circle),
                                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Transform.translate(
                                    offset: const Offset(0, -24),
                                    child: Column(
                                      children: [
                                        Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                                        const SizedBox(height: 4),
                                        Text('@$username', style: const TextStyle(color: Colors.white60, fontSize: 13)),
                                        const SizedBox(height: 12),
                                        
                                        // Social Linking Infrastructure Hook Layer
                                        if (instagramLink.isNotEmpty || youtubeLink.isNotEmpty)
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              if (instagramLink.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                                  child: Chip(
                                                    backgroundColor: Colors.white.withOpacity(0.04),
                                                    avatar: const Icon(Icons.link_rounded, color: Colors.pinkAccent, size: 14),
                                                    label: Text(instagramLink, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                                  ),
                                                ),
                                              if (youtubeLink.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                                  child: Chip(
                                                    backgroundColor: Colors.white.withOpacity(0.04),
                                                    avatar: const Icon(Icons.play_circle_fill_rounded, color: Colors.red, size: 14),
                                                    label: Text(youtubeLink, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            _buildStatMetric(_formatMetrics(following), 'Following'),
                                            _buildVerticalDivider(),
                                            _buildStatMetric(_formatMetrics(followers), 'Followers'),
                                            _buildVerticalDivider(),
                                            _buildStatMetric(_formatMetrics(totalLikes), 'Likes'),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(bio, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4), textAlign: TextAlign.center),
                                        const SizedBox(height: 20),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: _isCurrentUser ? _showAdvancedEditSheet : () {},
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                                  decoration: BoxDecoration(
                                                    color: _isCurrentUser ? Colors.white.withOpacity(0.05) : const Color(0xFFFF0050),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: _isCurrentUser ? Colors.white12 : Colors.transparent),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      _isCurrentUser ? 'Edit Profile Profile' : 'Follow Base',
                                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (_isCurrentUser) ...[
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: _showCreatorAnalyticsOverlay,
                                                child: Container(
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white12)),
                                                  child: const Icon(Icons.analytics_outlined, color: Colors.white, size: 18),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: _showMediaPostActionSheet,
                                                child: Container(
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(color: const Color(0xFFFF0050).withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFFF0050).withOpacity(0.3))),
                                                  child: const Icon(Icons.add_a_photo_rounded, color: Color(0xFFFF0050), size: 18),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverAppBarDelegate(
                          TabBar(
                            controller: _tabController,
                            indicatorColor: Colors.white,
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.white38,
                            tabs: _isCurrentUser
                                ? const [
                                    Tab(icon: Icon(Icons.grid_on_rounded, size: 18)),
                                    Tab(icon: Icon(Icons.lock_outline_rounded, size: 18)),
                                    Tab(icon: Icon(Icons.bookmark_border_rounded, size: 18)),
                                    Tab(icon: Icon(Icons.favorite_border_rounded, size: 18)),
                                  ]
                                : const [
                                    Tab(icon: Icon(Icons.grid_on_rounded, size: 18)),
                                    Tab(icon: Icon(Icons.favorite_border_rounded, size: 18)),
                                  ],
                          ),
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabController,
                    children: _isCurrentUser
                        ? [
                            _buildVideoGrid(_userVideos, true),
                            _buildVideoGrid(_privateVideos, false),
                            _buildVideoGrid(_bookmarkedVideos, false),
                            _buildVideoGrid(_likedVideos, false),
                          ]
                        : [
                            _buildVideoGrid(_userVideos, false),
                            _buildVideoGrid(_likedVideos, false),
                          ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoGrid(List<QueryDocumentSnapshot> videoDocs, bool attachPaginationEngine) {
    if (videoDocs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_rounded, color: Colors.white24, size: 40),
            SizedBox(height: 12),
            Text('No Creations Tracked', style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(1),
      itemCount: videoDocs.length + (attachPaginationEngine && _isLoadingMore ? 1 : 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 1.5, mainAxisSpacing: 1.5, childAspectRatio: 0.72),
      itemBuilder: (context, index) {
        if (index == videoDocs.length) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF0050)));
        }

        final video = videoDocs[index].data() as Map<String, dynamic>;
        final String? thumbnailUrl = video['thumbnailUrl'];
        final int likes = video['likeCount'] ?? 0;
        final String videoId = videoDocs[index].id;

        return GestureDetector(
          onTap: () => context.push('/video-detail/$videoId'),
          child: Container(
            color: const Color(0xFF0F0F12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                thumbnailUrl != null
                    ? Image.network(thumbnailUrl, fit: BoxFit.cover, cacheWidth: 150, errorBuilder: (c, e, s) => _buildPlaceholderThumbnailGrid())
                    : _buildPlaceholderThumbnailGrid(),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87], stops: [0.7, 1.0]),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Row(
                    children: [
                      const Icon(Icons.favorite_rounded, color: Color(0xFFFF0050), size: 12),
                      const SizedBox(width: 4),
                      Text(_formatMetrics(likes), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderAvatar() => Container(color: Colors.grey.shade900, child: const Icon(Icons.person_rounded, color: Colors.white38));
  Widget _buildPlaceholderThumbnailGrid() => Container(color: const Color(0xFF151518), child: const Icon(Icons.play_arrow_rounded, color: Colors.white12));
  Widget _buildStatMetric(String count, String label) => Column(children: [Text(count, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11))]);
  Widget _buildVerticalDivider() => Container(height: 12, width: 1, color: Colors.white12, margin: const EdgeInsets.symmetric(horizontal: 16));
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: Colors.black, child: _tabBar);
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
