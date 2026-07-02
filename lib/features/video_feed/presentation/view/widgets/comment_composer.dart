import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'comments_sheet.dart';

class CommentComposer extends StatefulWidget {
  final String videoId;
  final String? parentCommentId;
  final Function(CommentData) onCommentAdded;

  const CommentComposer({
    required this.videoId,
    required this.onCommentAdded,
    this.parentCommentId,
    super.key,
  });

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  late TextEditingController _textController;
  bool _isComposing = false;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _isComposing = _textController.text.trim().isNotEmpty;
    });
  }

  Future<void> _postComment() async {
    if (!_isComposing || _isPosting) return;

    final text = _textController.text.trim();
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('You must be logged in to comment')));
      return;
    }

    final commentId = const Uuid().v4();
    final now = DateTime.now();

    final optimisticComment = CommentData(
      id: commentId,
      userId: currentUser.uid,
      username: currentUser.displayName ?? 'Anonymous',
      avatarUrl: currentUser.photoURL ?? '',
      text: text,
      timestamp: now,
      likes: 0,
      replyCount: 0,
      isLikedByCurrentUser: false,
      parentCommentId: widget.parentCommentId,
    );

    widget.onCommentAdded(optimisticComment);

    _textController.clear();
    setState(() => _isPosting = true);

    try {
      final commentRef = FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .doc(commentId);

      await commentRef.set(optimisticComment.toFirestore());

      await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .update({'commentCount': FieldValue.increment(1)});

      if (widget.parentCommentId != null) {
        await FirebaseFirestore.instance
            .collection('videos')
            .doc(widget.videoId)
            .collection('comments')
            .doc(widget.parentCommentId)
            .update({'replyCount': FieldValue.increment(1)});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to post comment: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[900]
              : Colors.grey[100],
          border: Border(
            top: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]!
                  : Colors.grey[200]!,
            ),
          ),
        ),
        child: Center(
          child: Text(
            'Sign in to comment',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1a1a1a)
            : Colors.white,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]!
                : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[300],
            backgroundImage: currentUser.photoURL != null
                ? NetworkImage(currentUser.photoURL!)
                : null,
            child: currentUser.photoURL == null
                ? Icon(Icons.person, size: 16, color: Colors.grey[600])
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: !_isPosting,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100],
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedScale(
            scale: _isComposing ? 1.0 : 0.8,
            duration: const Duration(milliseconds: 200),
            child: _isPosting
                ? SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.blue),
                        ),
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: _isComposing ? _postComment : null,
                    child: Semantics(
                      button: true,
                      enabled: _isComposing && !_isPosting,
                      label: 'Post comment',
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _isComposing ? Colors.blue : Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.send,
                            size: 16,
                            color: _isComposing
                                ? Colors.white
                                : Colors.grey[600]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
