import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'comment_item.dart';
import 'comment_composer.dart';

/// 🎬 TikTok-quality comments sheet with modular architecture
/// Features:
/// - Smooth animations for list transitions
/// - Real-time Firestore sync
/// - Optimistic comment posting
/// - Reply thread expand/collapse
/// - Performance optimizations (const constructors, RepaintBoundary)
class CommentsSheet extends StatefulWidget {
  final String videoId;
  final int initialCommentCount;

  const CommentsSheet({
    required this.videoId,
    required this.initialCommentCount,
    super.key,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  late ScrollController _scrollController;
  late List<CommentData> _pendingComments;
  late Map<String, CommentData> _commentCache;
  late Set<String> _expandedReplies;
  late Map<String, bool> _likeOptimisticStates;
  int _commentCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _pendingComments = [];
    _commentCache = {};
    _expandedReplies = {};
    _likeOptimisticStates = {};
    _commentCount = widget.initialCommentCount;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// ✅ Optimistic comment posting
  /// Adds comment to UI immediately, then syncs to Firestore
  void _onCommentAdded(CommentData comment) {
    setState(() {
      _pendingComments.insert(0, comment);
      _commentCount++;
    });

    // Smooth scroll to top to show new comment
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onLikeToggled(String commentId, bool isLiked) {
    setState(() {
      _likeOptimisticStates[commentId] = isLiked;
    });
  }

  void _onReplyCountUpdated(String commentId, int newCount) {
    setState(() {
      if (_commentCache.containsKey(commentId)) {
        _commentCache[commentId]!.replyCount = newCount;
      }
    });
  }

  void _toggleRepliesExpanded(String commentId) {
    setState(() {
      if (_expandedReplies.contains(commentId)) {
        _expandedReplies.remove(commentId);
      } else {
        _expandedReplies.add(commentId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF111111)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(),
              Expanded(
                child: _buildCommentsList(scrollController),
              ),
              CommentComposer(
                videoId: widget.videoId,
                onCommentAdded: _onCommentAdded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() => Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[700]
                : Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Semantics(
              label: 'Comments section',
              child: Text(
                'Comments',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Semantics(
              label: 'Total comments: $_commentCount',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _commentCount.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildCommentsList(ScrollController scrollController) =>
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('videos')
            .doc(widget.videoId)
            .collection('comments')
            .where('parentCommentId', isNull: true) // ✅ Top-level comments only
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _pendingComments.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final comments = snapshot.data?.docs ?? [];
          final allComments = [
            ..._pendingComments,
            ...comments
                .map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final commentId = doc.id;
                  if (!_commentCache.containsKey(commentId)) {
                    _commentCache[commentId] = CommentData.fromFirestore(data, commentId);
                  }
                  return _commentCache[commentId]!;
                })
                .toList()
                .where((c) => !_pendingComments.any((p) => p.id == c.id))
                .toList(),
          ];

          if (allComments.isEmpty) {
            return Center(
              child: Semantics(
                label: 'No comments yet',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      size: 48,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[600]
                          : Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No comments yet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            controller: scrollController,
            itemCount: allComments.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final comment = allComments[index];
              final isExpanded = _expandedReplies.contains(comment.id);

              // ✅ Performance optimization: Prevent unnecessary rebuilds
              return RepaintBoundary(
                key: ValueKey(comment.id),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: CommentItem(
                    comment: comment,
                    videoId: widget.videoId,
                    isExpanded: isExpanded,
                    onToggleExpanded: () => _toggleRepliesExpanded(comment.id),
                    onLikeToggled: (isLiked) =>
                        _onLikeToggled(comment.id, isLiked),
                    onReplyCountUpdated: (newCount) =>
                        _onReplyCountUpdated(comment.id, newCount),
                  ),
                ),
              );
            },
          );
        },
      );
}

/// 📊 Reusable comment data model
/// Converts between Firestore docs and UI representation
class CommentData {
  final String id;
  final String userId;
  final String username;
  final String avatarUrl;
  final String text;
  final DateTime timestamp;
  int likes;
  int replyCount;
  bool isLikedByCurrentUser;
  final bool isVerified;
  final bool isCreator;
  final bool isPinned;
  final String? parentCommentId;

  CommentData({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.text,
    required this.timestamp,
    this.likes = 0,
    this.replyCount = 0,
    this.isLikedByCurrentUser = false,
    this.isVerified = false,
    this.isCreator = false,
    this.isPinned = false,
    this.parentCommentId,
  });

  /// ✅ Creates CommentData from Firestore document
  /// Handles all field name variations
  factory CommentData.fromFirestore(Map<String, dynamic> data, String commentId) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return CommentData(
      id: commentId,
      userId: data['userId'] ?? '',
      username: data['username'] ?? 'Anonymous',
      avatarUrl: data['userAvatar'] ?? '',
      text: data['text'] ?? '',
      // ✅ Handles both 'createdAt' and 'timestamp' field names
      timestamp: ((data['createdAt'] ?? data['timestamp']) as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: (data['likeCount'] as num?)?.toInt() ?? 0,
      replyCount: (data['replyCount'] as num?)?.toInt() ?? 0,
      isLikedByCurrentUser:
          ((data['likedBy'] as List?)?.contains(currentUserId)) ?? false,
      isVerified: data['isVerified'] ?? false,
      isCreator: data['isCreator'] ?? false,
      isPinned: data['isPinned'] ?? false,
      parentCommentId: data['parentCommentId'],
    );
  }

  /// ✅ Converts to Firestore document format
  Map<String, dynamic> toFirestore() => {
        'id': id,
        'userId': userId,
        'username': username,
        'userAvatar': avatarUrl,
        'text': text,
        'createdAt': Timestamp.fromDate(timestamp),
        'timestamp': Timestamp.fromDate(timestamp), // Backward compatibility
        'likeCount': likes,
        'replyCount': replyCount,
        'isVerified': isVerified,
        'isCreator': isCreator,
        'isPinned': isPinned,
        if (parentCommentId != null) 'parentCommentId': parentCommentId,
      };
}
