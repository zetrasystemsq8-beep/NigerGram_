// lib/features/video_feed/presentation/view/widgets/comments_viewer_bottom_sheet.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nigergram/features/video_feed/repository/interaction_repository.dart';

class CommentsViewerBottomSheet extends StatefulWidget {
  final String videoId;
  const CommentsViewerBottomSheet({required this.videoId, super.key});

  @override
  State<CommentsViewerBottomSheet> createState() => _CommentsViewerBottomSheetState();
}

class _CommentsViewerBottomSheetState extends State<CommentsViewerBottomSheet> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final InteractionRepository _interactionRepo = InteractionRepository();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Pagination settings
  static const int pageSize = 50;
  DocumentSnapshot? _lastDoc;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isPostingComment = false;
  final List<QueryDocumentSnapshot> _items = [];

  StreamSubscription<QuerySnapshot>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 120) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    if (!_hasMore) return;
    if (mounted) setState(() => _isLoadingMore = true);
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
      debugPrint('❌ Failed to load initial comments: $e');
      _hasMore = false;
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoadingMore || _lastDoc == null) return;
    if (mounted) setState(() => _isLoadingMore = true);
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
      debugPrint('❌ Failed to load more comments: $e');
      _hasMore = false;
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _subscribeRealtime() {
    final coll = _firestore
        .collection('videos')
        .doc(widget.videoId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .limit(200);
    _realtimeSub = coll.snapshots().listen(
      (snapshot) {
        if (mounted) {
          setState(() {
            _items.clear();
            _items.addAll(snapshot.docs);
            if (_items.isNotEmpty) _lastDoc = _items.last;
            _hasMore = snapshot.docs.length >= pageSize;
          });
        }
      },
      onError: (e) {
        debugPrint('⚠️ Realtime comments stream error: $e');
      },
    );
  }

  Future<void> _postComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to comment'), backgroundColor: Colors.redAccent),
        );
      }
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_isPostingComment) return;
    
    if (mounted) setState(() => _isPostingComment = true);

    try {
      String? userAvatar;
      String usernameFallback = 'NigerGram User';
      
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;
          userAvatar = data['profilePicUrl'] as String?;
          if (data['username'] != null && (data['username'] as String).isNotEmpty) {
            usernameFallback = data['username'] as String;
          } else if (data['displayName'] != null && (data['displayName'] as String).isNotEmpty) {
            usernameFallback = data['displayName'] as String;
          }
        }
      } catch (e) {
        debugPrint('Profile fetch exception inside comment node: $e');
      }

      if (!usernameFallback.startsWith('@') && usernameFallback != 'NigerGram User') {
        usernameFallback = '@$usernameFallback';
      }

      await _interactionRepo.addComment(
        widget.videoId,
        user.uid,
        usernameFallback,
        text,
        userAvatar: userAvatar,
      );

      if (mounted) _controller.clear();

      await Future.delayed(const Duration(milliseconds: 150));
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      debugPrint('❌ Post error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e'), backgroundColor: const Color(0xFFFF0050)),
        );
      }
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
  }

  String _formatTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Widget _buildInputArea() {
    return Container(
      color: const Color(0xFF0F0F12),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _isPostingComment ? null : _postComment(),
              enabled: !_isPostingComment,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Write a comment...',
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
            onPressed: _isPostingComment ? null : _postComment,
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_items.isEmpty && !_isLoadingMore) {
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
        final username = data['username'] as String? ?? 'User';
        final userAvatar = data['userAvatar'] as String? ?? '';
        final text = data['text'] as String? ?? '';
        final ts = data['createdAt'] as Timestamp?;
        final time = ts != null ? ts.toDate() : null;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white10,
              backgroundImage: userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
              child: userAvatar.isEmpty 
                  ? Text(
                      username.isNotEmpty ? username.replaceFirst('@', '')[0].toUpperCase() : 'U', 
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ) 
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text, 
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
                  ),
                  if (time != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(time),
                      style: const TextStyle(fontSize: 10, color: Colors.white38),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

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
                Expanded(
                  child: _buildCommentsList(),
                ),
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
