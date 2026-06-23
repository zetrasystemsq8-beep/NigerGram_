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

      const String fallbackThumbnail = 'https://images.unsplash.com/photo-1611162617213-7d7a39e9b1d7?w=500&q=60';

      await FirebaseFirestore.instance.collection('videos').doc(videoId).set({
        'videoId': videoId,
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

    // Use a multi-field merge patch update to protect existing analytics metrics
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'displayName': name.trim(),
      'username': username.trim().toLowerCase(),
      'bio': bio.trim(),
      'instagramLink': insta.trim(),
      'youtubeLink': youtube.trim(),
    }, SetOptions(merge: true));

    await _loadProfileWorkspace();
  }

  String _formatMetrics(int num) {
    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(1)}M';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}K';
    }
    return num.toString();
  }

  void _showCreatorAnalyticsOverlay() {
    HapticFeedback.mediumImpact();
    
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
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom, left: 24, right: 24, top: 20),
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
                  StatefulBuilder(
                    builder: (statefulContext, setModalState) {
                      return ElevatedButton(
                        onPressed: isSaving ? null : () async {
                          if (formKey.currentState!.validate()) {
                            setModalState(() => isSaving = true);
                            try {
                              await _updateProfileWorkspaceData(
                                nameController.text, 
                                usernameController.text, 
                                bioController.text, 
                                instaController.text, 
                                youtubeController.text
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Sync Error: $e'), backgroundColor: Colors.red),
                                );
                              }
                              setModalState(() => isSaving = false);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF0050), 
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: isSaving 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                            : const Text('Synchronize Profiles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
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
      errorBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.redAccent), borderRadius: BorderRadius.circular(8)),
      focusedErrorBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.red), borderRadius: BorderRadius.circular(8)),
    );
  }

  void _executePlatformShareAction(String platform, String videoId) {
    HapticFeedback.lightImpact();
    final String shareUrl = "https://nigergram.app/video/$videoId";
    final String shareText = "Check out this video on NigerGram: $shareUrl";

    try {
      if (platform == 'whatsapp') {
        Clipboard.setData(ClipboardData(text: shareText));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied! Redirecting to WhatsApp...'), backgroundColor: Colors.green),
        );
      } else {
        Clipboard.setData(ClipboardData(text: shareText));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video link copied to clipboard workspace!'), backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      debugPrint('Share channel invocation mismatch: $e');
    }
  }

  Widget _buildVideoGrid(List<QueryDocumentSnapshot> videos) {
    if (videos.isEmpty) {
      return const Center(
        child: Text('No content nodes cached in this matrix.', style: TextStyle(color: Colors.white38, fontSize: 13)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      itemCount: videos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 0.75,
      ),
      itemBuilder: (context, index) {
        final data = videos[index].data() as Map<String, dynamic>;
        final thumb = data['thumbnailUrl'] ?? '';
        final videoId = data['videoId'] ?? '';

        return GestureDetector(
          onTap: () => context.push('/video-player/$videoId'),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(4),
              image: thumb.isNotEmpty ? DecorationImage(image: NetworkImage(thumb), fit: BoxFit.cover) : null,
            ),
            child: Stack(
              children: [
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Row(
                    children: [
                      const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 2),
                      Text(
                        _formatMetrics(data['viewCount'] ?? 0),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _executePlatformShareAction('whatsapp', videoId),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                      child: const Icon(Icons.share_rounded, color: Colors.greenAccent, size: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF09090B),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF0050))),
      );
    }

    final String displayName = _userData?['displayName'] ?? 'NigerGram Creator';
    final String username = '@${_userData?['username'] ?? 'username'}';
    final String bio = _userData?['bio'] ?? 'No biography written yet.';
    final String coverUrl = _userData?['coverUrl'] ?? '';
    final String profilePic = _userData?['profilePicUrl'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&q=80';

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Stack(
        children: [
          NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 180,
                  pinned: true,
                  backgroundColor: const Color(0xFF09090B),
                  flexibleSpace: FlexibleSpaceBar(
                    background: GestureDetector(
                      onTap: _isCurrentUser ? _updateCoverArtImage : null,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          coverUrl.isNotEmpty
                              ? Image.network(coverUrl, fit: BoxFit.cover)
                              : Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF1E1E24), Color(0xFF09090B)],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                          if (_isCurrentUser)
                            const Positioned(
                              top: 40,
                              right: 16,
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.black45,
                                child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -40),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              CircleAvatar(
                                radius: 44,
                                backgroundColor: const Color(0xFF09090B),
                                child: CircleAvatar(radius: 40, backgroundImage: NetworkImage(profilePic)),
                              ),
                              const Spacer(),
                              if (_isCurrentUser) ...[
                                IconButton(
                                  icon: const Icon(Icons.analytics_rounded, color: Colors.white70),
                                  onPressed: _showCreatorAnalyticsOverlay,
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _showAdvancedEditSheet,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.06),
                                    side: const BorderSide(color: Colors.white10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontSize: 13)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(username, style: const TextStyle(color: Color(0xFFFF0050), fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 12),
                              Text(bio, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.4)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _buildCounterStat(_formatMetrics(_userData?['following'] ?? 0), 'Following'),
                                  const SizedBox(width: 24),
                                  _buildCounterStat(_formatMetrics(_userData?['followers'] ?? 0), 'Followers'),
                                  const SizedBox(width: 24),
                                  _buildCounterStat(_formatMetrics(_userData?['totalLikes'] ?? 0), 'Likes'),
                                ],
                              ),
                            ],
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
                      indicatorColor: const Color(0xFFFF0050),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white38,
                      tabs: _isCurrentUser
                          ? const [
                              Tab(icon: Icon(Icons.grid_on_rounded, size: 20)),
                              Tab(icon: Icon(Icons.lock_outline_rounded, size: 20)),
                              Tab(icon: Icon(Icons.bookmark_outline_rounded, size: 20)),
                              Tab(icon: Icon(Icons.favorite_border_rounded, size: 20)),
                            ]
                          : const [
                              Tab(icon: Icon(Icons.grid_on_rounded, size: 20)),
                              Tab(icon: Icon(Icons.favorite_border_rounded, size: 20)),
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
                      _buildVideoGrid(_userVideos),
                      _buildVideoGrid(_privateVideos),
                      _buildVideoGrid(_bookmarkedVideos),
                      _buildVideoGrid(_likedVideos),
                    ]
                  : [
                      _buildVideoGrid(_userVideos),
                      _buildVideoGrid(_likedVideos),
                    ],
            ),
          ),
          if (_isUploadingContent)
            Container(
              color: Colors.black74,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(value: _uploadProgress, color: const Color(0xFFFF0050), backgroundColor: Colors.white10),
                      const SizedBox(height: 16),
                      Text(
                        'Pushing high-fidelity payload... ${( _uploadProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isCurrentUser
          ? FloatingActionButton(
              onPressed: _showMediaPostActionSheet,
              backgroundColor: const Color(0xFFFF0050),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            )
          : null,
    );
  }

  Widget _buildCounterStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overrides) {
    return Container(
      color: const Color(0xFF09090B),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
