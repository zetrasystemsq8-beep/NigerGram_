// lib/features/video_feed/presentation/view/widgets/comments_viewer_bottom_sheet.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nigergram/features/video_feed/repository/interaction_repository.dart';

class CommentsViewerBottomSheet extends StatefulWidget {
  final String videoId;
  const CommentsViewerBottomSheet({required this.videoId, super.key});

  @override
  State<CommentsViewerBottomSheet> createState() => _CommentsViewerBottomSheetState();
}

class _CommentsViewerBottomSheetState extends State<CommentsViewerBottomSheet> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  final InteractionRepository _interactionRepo = InteractionRepository();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Pagination
  static const int pageSize = 50;
  DocumentSnapshot? _lastDoc;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isPostingComment = false;
  bool _isInitialLoading = true;
  final List<QueryDocumentSnapshot> _items = [];

  // Reply state
  final Set<String> _expandedComments = {};
  final Map<String, TextEditingController> _replyControllers = {};
  final Map<String, bool> _isReplying = {};

  // Upload state
  bool _isUploadingImage = false;

  // Subscriptions
  StreamSubscription<QuerySnapshot>? _realtimeSub;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _disposed = true;
    _realtimeSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    for (final c in _replyControllers.values) c.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 120) {
      _loadMore();
    }
  }

  // ========== DATA LOADING ==========
  Future<void> _loadInitial() async {
    if (!_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final q = _firestore
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .limit(pageSize);
      final snap = await q.get();
      if (snap.docs.isNotEmpty) {
        _items.clear();
        _items.addAll(snap.docs);
        _lastDoc = snap.docs.last;
        _hasMore = snap.docs.length == pageSize;
      } else {
        _hasMore = false;
        _items.clear();
      }
    } catch (e) {
      debugPrint('❌ Failed to load comments: $e');
      _hasMore = false;
    } finally {
      if (mounted) setState(() {
        _isLoadingMore = false;
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoadingMore || _lastDoc == null || _isInitialLoading) return;
    setState(() => _isLoadingMore = true);
    try {
      final q = _firestore
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(pageSize);
      final snap = await q.get();
      if (snap.docs.isNotEmpty) {
        _items.addAll(snap.docs);
        _lastDoc = snap.docs.last;
        _hasMore = snap.docs.length == pageSize;
      } else {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint('❌ Failed to load more: $e');
      _hasMore = false;
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // ========== REALTIME UPDATES (Fixed) ==========
  void _subscribeRealtime() {
    final coll = _firestore
        .collection('videos')
        .doc(widget.videoId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .limit(200);
    _realtimeSub = coll.snapshots().listen(
      (snapshot) {
        if (_disposed || !mounted) return;

        // ✅ Full replace – ensures likeCount, text, imageUrl updates are reflected
        setState(() {
          _items.clear();
          _items.addAll(snapshot.docs);
          if (_items.isNotEmpty) _lastDoc = _items.last;
          _hasMore = snapshot.docs.length >= pageSize;
        });
      },
      onError: (e) => debugPrint('⚠️ Realtime error: $e'),
    );
  }

  // ========== USER INFO ==========
  Future<({String username, String? avatar})> _fetchUserInfo(String uid) async {
    String usernameFallback = 'NigerGram User';
    String? avatar;
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        avatar = data['profilePicUrl'] as String?;
        final uname = data['username'] as String?;
        if (uname != null && uname.isNotEmpty) {
          usernameFallback = uname;
        } else if (data['displayName'] != null && (data['displayName'] as String).isNotEmpty) {
          usernameFallback = data['displayName'] as String;
        }
      }
    } catch (e) {
      debugPrint('Profile fetch error: $e');
    }
    if (!usernameFallback.startsWith('@') && usernameFallback != 'NigerGram User') {
      usernameFallback = '@$usernameFallback';
    }
    return (username: usernameFallback, avatar: avatar);
  }

  // ========== POST TEXT COMMENT ==========
  Future<void> _postTextComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Please sign in to comment');
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_isPostingComment) return;

    setState(() => _isPostingComment = true);
    try {
      final userInfo = await _fetchUserInfo(user.uid);

      // ✅ Use transaction for consistency
      await _firestore.runTransaction((transaction) async {
        final videoRef = _firestore.collection('videos').doc(widget.videoId);
        final commentRef = videoRef.collection('comments').doc();

        transaction.set(commentRef, {
          'userId': user.uid,
          'username': userInfo.username,
          'userAvatar': userInfo.avatar ?? '',
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
          'likeCount': 0,
          'replyCount': 0, // ✅ New field for reply count
        });

        transaction.update(videoRef, {
          'commentCount': FieldValue.increment(1),
        });
      });

      _controller.clear();

      await Future.delayed(const Duration(milliseconds: 150));
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      debugPrint('❌ Post error: $e');
      _showSnackBar('Failed to post comment: $e');
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
  }

  // ========== IMAGE COMMENT ==========
  Future<void> _pickImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Please sign in to comment');
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );
    if (image == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final bytes = await image.readAsBytes();
      final fileName = 'comment_${DateTime.now().millisecondsSinceEpoch}_${user.uid}.jpg';
      final storagePath = 'comment_images/$fileName';

      await _supabase.storage.from('images').uploadBinary(
        storagePath,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );
      final imageUrl = _supabase.storage.from('images').getPublicUrl(storagePath);

      await _postCommentWithImage(imageUrl, storagePath, user.uid);

      setState(() => _isUploadingImage = false);
    } catch (e) {
      debugPrint('❌ Image upload error: $e');
      setState(() => _isUploadingImage = false);
      _showSnackBar('Failed to upload image: $e');
    }
  }

  Future<void> _postCommentWithImage(String imageUrl, String storagePath, String uid) async {
    final text = _controller.text.trim();

    setState(() => _isPostingComment = true);
    try {
      final userInfo = await _fetchUserInfo(uid);

      await _firestore.runTransaction((transaction) async {
        final videoRef = _firestore.collection('videos').doc(widget.videoId);
        final commentRef = videoRef.collection('comments').doc();

        transaction.set(commentRef, {
          'userId': uid,
          'username': userInfo.username,
          'userAvatar': userInfo.avatar ?? '',
          'text': text,
          'imageUrl': imageUrl,
          'storagePath': storagePath,
          'createdAt': FieldValue.serverTimestamp(),
          'likeCount': 0,
          'replyCount': 0, // ✅ New field
        });

        transaction.update(videoRef, {
          'commentCount': FieldValue.increment(1),
        });
      });

      _controller.clear();

      await Future.delayed(const Duration(milliseconds: 150));
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      debugPrint('❌ Post with image error: $e');
      try {
        await _supabase.storage.from('images').remove([storagePath]);
      } catch (_) {}
      rethrow;
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
  }

  // ========== LIKE (Optimistic) ==========
  Future<void> _toggleLike(String commentId, bool currentlyLiked) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Sign in to like comments');
      return;
    }

    final commentRef = _firestore
        .collection('videos')
        .doc(widget.videoId)
        .collection('comments')
        .doc(commentId);

    final likeDocRef = commentRef.collection('likes').doc(user.uid);

    // ✅ Optimistic update – will be corrected by realtime stream if transaction fails
    try {
      await _firestore.runTransaction((transaction) async {
        final commentSnap = await transaction.get(commentRef);
        if (!commentSnap.exists) return;

        final likeSnap = await transaction.get(likeDocRef);
        final likeExists = likeSnap.exists;

        if (currentlyLiked && likeExists) {
          transaction.delete(likeDocRef);
          transaction.update(commentRef, {'likeCount': FieldValue.increment(-1)});
        } else if (!currentlyLiked && !likeExists) {
          transaction.set(likeDocRef, {
            'userId': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(commentRef, {'likeCount': FieldValue.increment(1)});
        }
        // If state is inconsistent, do nothing – realtime stream will correct UI
      });
    } catch (e) {
      debugPrint('❌ Like toggle error: $e');
    }
  }

  // ========== REPLY (with replyCount) ==========
  Future<void> _addReply(String commentId, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Sign in to reply');
      return;
    }
    if (text.trim().isEmpty) return;

    final commentRef = _firestore
        .collection('videos')
        .doc(widget.videoId)
        .collection('comments')
        .doc(commentId);

    final replyRef = commentRef.collection('replies');

    try {
      final userInfo = await _fetchUserInfo(user.uid);

      await _firestore.runTransaction((transaction) async {
        final commentSnap = await transaction.get(commentRef);
        if (!commentSnap.exists) return;

        transaction.set(replyRef.doc(), {
          'userId': user.uid,
          'username': userInfo.username,
          'userAvatar': userInfo.avatar ?? '',
          'text': text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        // ✅ Increment replyCount on the comment
        transaction.update(commentRef, {
          'replyCount': FieldValue.increment(1),
        });
      });

      _replyControllers[commentId]?.clear();
      setState(() => _isReplying[commentId] = false);
    } catch (e) {
      debugPrint('❌ Reply error: $e');
      _showSnackBar('Failed to post reply');
    }
  }

  // ========== HELPERS ==========
  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  String _formatTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  // ========== UI ==========
  Widget _buildInputArea() {
    return Container(
      color: const Color(0xFF0F0F12),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: _isUploadingImage
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Color(0xFFFF0050), strokeWidth: 2),
                  )
                : const Icon(Icons.image_outlined, color: Colors.white54),
            onPressed: _isUploadingImage ? null : _pickImage,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _postTextComment(),
              enabled: !_isPostingComment && !_isUploadingImage,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: _isUploadingImage ? 'Uploading image...' : 'Write a comment...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.04),
              ),
              minLines: 1,
              maxLines: 4,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: _isPostingComment
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Color(0xFFFF0050), strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, color: Color(0xFFFF0050)),
            onPressed: _isPostingComment ? null : _postTextComment,
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_isInitialLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF0050), strokeWidth: 2),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'No comments yet — be first!',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      reverse: false,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: _hasMore ? _items.length + 1 : _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(color: Color(0xFFFF0050), strokeWidth: 2)),
          );
        }
        final doc = _items[index];
        final data = doc.data() as Map<String, dynamic>;
        final replyCount = data['replyCount'] as int? ?? 0;

        return _CommentItem(
          commentId: doc.id,
          username: data['username'] as String? ?? 'User',
          userAvatar: data['userAvatar'] as String? ?? '',
          text: data['text'] as String? ?? '',
          imageUrl: data['imageUrl'] as String?,
          time: (data['createdAt'] as Timestamp?)?.toDate(),
          likeCount: data['likeCount'] as int? ?? 0,
          replyCount: replyCount, // ✅ Pass replyCount
          videoId: widget.videoId,
          onLikeToggle: _toggleLike,
          onReplySubmitted: _addReply,
          isExpanded: _expandedComments.contains(doc.id),
          onToggleExpand: () {
            setState(() {
              if (_expandedComments.contains(doc.id)) {
                _expandedComments.remove(doc.id);
              } else {
                _expandedComments.add(doc.id);
              }
            });
          },
          replyController: _replyControllers.putIfAbsent(doc.id, () => TextEditingController()),
          isReplying: _isReplying[doc.id] ?? false,
          onReplyToggle: (replying) {
            setState(() => _isReplying[doc.id] = replying);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F12),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: FractionallySizedBox(
            heightFactor: 0.85,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Comments',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Colors.white10),
                Expanded(child: _buildCommentsList()),
                const Divider(height: 1, color: Colors.white10),
                _buildInputArea(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// COMMENT ITEM WIDGET
// ============================================================

class _CommentItem extends StatefulWidget {
  final String commentId;
  final String username;
  final String userAvatar;
  final String text;
  final String? imageUrl;
  final DateTime? time;
  final int likeCount;
  final int replyCount; // ✅ New
  final String videoId;
  final Future<void> Function(String, bool) onLikeToggle;
  final Future<void> Function(String, String) onReplySubmitted;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final TextEditingController replyController;
  final bool isReplying;
  final Function(bool) onReplyToggle;

  const _CommentItem({
    required this.commentId,
    required this.username,
    required this.userAvatar,
    required this.text,
    this.imageUrl,
    required this.time,
    required this.likeCount,
    required this.replyCount,
    required this.videoId,
    required this.onLikeToggle,
    required this.onReplySubmitted,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.replyController,
    required this.isReplying,
    required this.onReplyToggle,
  });

  @override
  State<_CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<_CommentItem> {
  bool _isLiked = false;
  bool _isLikeProcessing = false;
  StreamSubscription<DocumentSnapshot>? _likeStatusSub;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _listenToLikeStatus();
  }

  void _listenToLikeStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final likeDoc = FirebaseFirestore.instance
        .collection('videos')
        .doc(widget.videoId)
        .collection('comments')
        .doc(widget.commentId)
        .collection('likes')
        .doc(user.uid);
    _likeStatusSub = likeDoc.snapshots().listen((snap) {
      if (_disposed || !mounted) return;
      setState(() => _isLiked = snap.exists);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _likeStatusSub?.cancel();
    super.dispose();
  }

  void _showFullScreenImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: Navigator.of(context).pop,
          child: Stack(
            children: [
              Center(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(color: Color(0xFFFF0050)),
                  errorWidget: (_, __, ___) => const Icon(Icons.error, color: Colors.white54),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: GestureDetector(
                  onTap: Navigator.of(context).pop,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  void _handleLike() async {
    if (_isLikeProcessing) return;

    // ✅ Optimistic update
    setState(() => _isLiked = !_isLiked);
    setState(() => _isLikeProcessing = true);

    try {
      await widget.onLikeToggle(widget.commentId, _isLiked);
    } catch (_) {
      // Revert on failure (realtime stream will also correct it)
      if (mounted) setState(() => _isLiked = !_isLiked);
    } finally {
      if (mounted) setState(() => _isLikeProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white10,
              backgroundImage: widget.userAvatar.isNotEmpty ? NetworkImage(widget.userAvatar) : null,
              child: widget.userAvatar.isEmpty
                  ? Text(
                      widget.username.isNotEmpty ? widget.username.replaceFirst('@', '')[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.username,
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      if (widget.time != null)
                        Text(
                          _formatTime(widget.time!),
                          style: const TextStyle(fontSize: 10, color: Colors.white38),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.text,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
                  ),
                  if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _showFullScreenImage(widget.imageUrl!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: widget.imageUrl!,
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 150,
                            color: Colors.white10,
                            child: const Center(
                              child: CircularProgressIndicator(color: Color(0xFFFF0050), strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            height: 150,
                            color: Colors.white10,
                            child: const Center(
                              child: Icon(Icons.broken_image, color: Colors.white38, size: 40),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _handleLike,
                        child: Row(
                          children: [
                            Icon(
                              _isLiked ? Icons.favorite : Icons.favorite_border,
                              color: _isLiked ? Colors.red : Colors.white54,
                              size: 18,
                            ),
                            if (widget.likeCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${widget.likeCount}',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => widget.onReplyToggle(!widget.isReplying),
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (widget.isReplying)
          Padding(
            padding: const EdgeInsets.only(left: 50, top: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.replyController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Write a reply...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                    ),
                    onSubmitted: (text) {
                      if (text.trim().isNotEmpty) {
                        widget.onReplySubmitted(widget.commentId, text);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFFFF0050), size: 20),
                  onPressed: () {
                    final text = widget.replyController.text.trim();
                    if (text.isNotEmpty) {
                      widget.onReplySubmitted(widget.commentId, text);
                    }
                  },
                ),
              ],
            ),
          ),
        // ✅ Use replyCount instead of FutureBuilder
        if (!widget.isExpanded && widget.replyCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 50, top: 4),
            child: GestureDetector(
              onTap: widget.onToggleExpand,
              child: Text(
                'View ${widget.replyCount} ${widget.replyCount == 1 ? 'reply' : 'replies'}',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        if (widget.isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 50, top: 8),
            child: _ReplyList(
              videoId: widget.videoId,
              commentId: widget.commentId,
              // ✅ Pass replyCount for pagination
              replyCount: widget.replyCount,
            ),
          ),
        if (widget.isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 50, top: 2),
            child: GestureDetector(
              onTap: widget.onToggleExpand,
              child: Text(
                'Hide replies',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// REPLY LIST (With Pagination)
// ============================================================

class _ReplyList extends StatefulWidget {
  final String videoId;
  final String commentId;
  final int replyCount;

  const _ReplyList({
    required this.videoId,
    required this.commentId,
    required this.replyCount,
  });

  @override
  State<_ReplyList> createState() => _ReplyListState();
}

class _ReplyListState extends State<_ReplyList> {
  static const int pageSize = 20;
  StreamSubscription<QuerySnapshot>? _realtimeSub;
  final List<QueryDocumentSnapshot> _replies = [];
  DocumentSnapshot? _lastReplyDoc;
  bool _hasMoreReplies = true;
  bool _isLoadingMoreReplies = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _subscribeReplies();
  }

  void _subscribeReplies() {
    final query = FirebaseFirestore.instance
        .collection('videos')
        .doc(widget.videoId)
        .collection('comments')
        .doc(widget.commentId)
        .collection('replies')
        .orderBy('createdAt', descending: false)
        .limit(pageSize);

    _realtimeSub = query.snapshots().listen((snap) {
      if (_disposed || !mounted) return;
      setState(() {
        _replies.clear();
        _replies.addAll(snap.docs);
        if (_replies.isNotEmpty) {
          _lastReplyDoc = _replies.last;
          _hasMoreReplies = _replies.length >= pageSize && _replies.length < widget.replyCount;
        } else {
          _hasMoreReplies = false;
        }
      });
    });
  }

  void _loadMoreReplies() async {
    if (!_hasMoreReplies || _isLoadingMoreReplies || _lastReplyDoc == null) return;
    setState(() => _isLoadingMoreReplies = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .doc(widget.commentId)
          .collection('replies')
          .orderBy('createdAt', descending: false)
          .startAfterDocument(_lastReplyDoc!)
          .limit(pageSize)
          .get();

      if (mounted) {
        setState(() {
          _replies.addAll(snap.docs);
          if (_replies.isNotEmpty) {
            _lastReplyDoc = _replies.last;
          }
          _hasMoreReplies = snap.docs.length >= pageSize && _replies.length < widget.replyCount;
        });
      }
    } catch (e) {
      debugPrint('❌ Load more replies error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMoreReplies = false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _realtimeSub?.cancel();
    super.dispose();
  }

  String _formatTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    if (_replies.isEmpty) {
      return const SizedBox.shrink();
    }

    final items = List<Widget>.from(_replies.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white10,
              backgroundImage: (data['userAvatar'] as String? ?? '').isNotEmpty
                  ? NetworkImage(data['userAvatar'] as String)
                  : null,
              child: (data['userAvatar'] as String? ?? '').isEmpty
                  ? Text(
                      ((data['username'] as String? ?? 'User').isNotEmpty
                          ? (data['username'] as String).replaceFirst('@', '')[0].toUpperCase()
                          : 'U'),
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['username'] as String? ?? 'User',
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data['text'] as String? ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  if (data['createdAt'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatTime((data['createdAt'] as Timestamp).toDate()),
                      style: const TextStyle(fontSize: 9, color: Colors.white38),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }));

    // Add loader at the end if more replies exist
    if (_hasMoreReplies) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: GestureDetector(
              onTap: _loadMoreReplies,
              child: Text(
                _isLoadingMoreReplies ? 'Loading...' : 'Load more replies',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(children: items);
  }
}
