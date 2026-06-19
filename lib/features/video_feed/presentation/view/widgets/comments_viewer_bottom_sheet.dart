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
  static const int pageSize = 20;
  DocumentSnapshot? _lastDoc;
  bool _isLoadingMore = false;
  bool _hasMore = true;
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
    setState(() => _isLoadingMore = true);
    final q = _firestore
        .collection('videos')
        .doc(widget.videoId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
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
    setState(() => _isLoadingMore = false);
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoadingMore || _lastDoc == null) return;
    setState(() => _isLoadingMore = true);
    final q = _firestore
        .collection('videos')
        .doc(widget.videoId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
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
    setState(() => _isLoadingMore = false);
  }

  void _subscribeRealtime() {
    // Listen for live changes and merge them into the list.
    final coll = _firestore
        .collection('videos')
        .doc(widget.videoId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .limit(200);
    _realtimeSub = coll.snapshots().listen(
      (snapshot) {
        // Replace local cache with new order (keeps realtime authoritative)
        setState(() {
          _items.clear();
          _items.addAll(snapshot.docs);
          if (_items.isNotEmpty) _lastDoc = _items.last;
          _hasMore = snapshot.docs.length == pageSize;
        });
      },
      onError: (e) {
        // Ignore realtime errors; UI still works with manual pagination
        debugPrint('Realtime comments stream error: $e');
      },
    );
  }

  Future<void> _postComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to comment')));
      }
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Immediately clear input (optimistic UX)
    _controller.clear();

    try {
      await _interactionRepo.addComment(
        widget.videoId,
        user.uid,
        user.displayName ?? user.email ?? 'User',
        text,
      );
      // Scroll to top to show latest (server timestamp ordering)
      await Future.delayed(const Duration(milliseconds: 200));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post comment: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _buildCommentsList(),
              ),
              const Divider(height: 1),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_items.isEmpty && !_isLoadingMore) {
      return const Center(child: Text('No comments yet — be first!'));
    }

    return ListView.separated(
      controller: _scrollController,
      reverse: false,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final doc = _items[index];
        final data = doc.data() as Map<String, dynamic>;
        final username = data['username'] as String? ?? 'User';
        final text = data['text'] as String? ?? '';
        final ts = data['timestamp'] as Timestamp?;
        final time = ts != null ? ts.toDate() : null;

        return ListTile(
          leading: CircleAvatar(
            child: Text(username.isNotEmpty ? username[0].toUpperCase() : 'U'),
          ),
          title: Text(
            username,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text),
              if (time != null)
                Text(
                  _formatTime(time),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: _hasMore ? _items.length + 1 : _items.length,
    );
  }

  String _formatTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Widget _buildInputArea() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _postComment(),
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[900],
                ),
                minLines: 1,
                maxLines: 4,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send_rounded),
              onPressed: _postComment,
            ),
          ],
        ),
      ),
    );
  }
}
