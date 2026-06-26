import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/gist_hub/data/services/gist_service.dart';

class GistCommentSheet extends StatefulWidget {
  final String postId;
  final GistService service;

  const GistCommentSheet({
    super.key,
    required this.postId,
    required this.service,
  });

  @override
  State<GistCommentSheet> createState() => _GistCommentSheetState();
}

class _GistCommentSheetState extends State<GistCommentSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  void _submitComment() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await widget.service.addComment(
        postId: widget.postId,
        text: text,
      );
      _commentController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💬 Comment added!'),
            backgroundColor: NGColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: NGColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: NGColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '💬 Comments',
            style: TextStyle(
              color: NGColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.service.getCommentsStream(widget.postId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading comments',
                      style: TextStyle(color: NGColors.textMuted),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: NGColors.accent),
                  );
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, color: NGColors.textMuted, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'No comments yet',
                          style: TextStyle(color: NGColors.textSecondary, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Be the first to comment!',
                          style: TextStyle(color: NGColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isAnonymous = data['isAnonymous'] ?? false;
                    final displayName = isAnonymous ? 'Anonymous' : (data['displayName'] ?? 'User');
                    final username = isAnonymous ? '' : (data['username'] ?? '');
                    final profilePic = data['profilePic'] ?? '';
                    final text = data['text'] ?? '';
                    final createdAt = data['createdAt'] as Timestamp?;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: NGColors.surfaceLight,
                            backgroundImage: isAnonymous || profilePic.isEmpty
                                ? null
                                : CachedNetworkImageProvider(profilePic),
                            child: isAnonymous || profilePic.isEmpty
                                ? Icon(Icons.person, color: NGColors.textMuted, size: 18)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        color: NGColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (!isAnonymous) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        username,
                                        style: TextStyle(
                                          color: NGColors.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDate(createdAt),
                                      style: TextStyle(
                                        color: NGColors.textMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  text,
                                  style: TextStyle(
                                    color: NGColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: const TextStyle(color: NGColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Write a comment...',
                    hintStyle: TextStyle(color: NGColors.textMuted),
                    filled: true,
                    fillColor: NGColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (_) => _submitComment(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: NGColors.accent,
                child: IconButton(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                  onPressed: _isLoading ? null : _submitComment,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
