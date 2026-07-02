import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'comments_sheet.dart';

/// ⚙️ Comment actions menu (long-press)
/// Options:
/// - Copy comment text
/// - Delete comment (if owner)
/// - Report comment
class CommentActionsSheet extends StatefulWidget {
  final CommentData comment;
  final String videoId;

  const CommentActionsSheet({
    required this.comment,
    required this.videoId,
    super.key,
  });

  @override
  State<CommentActionsSheet> createState() => _CommentActionsSheetState();
}

class _CommentActionsSheetState extends State<CommentActionsSheet> {
  bool _isDeleting = false;
  bool _isReporting = false;

  Future<void> _deleteComment() async {
    if (_isDeleting) return;

    setState(() => _isDeleting = true);

    try {
      final commentRef = FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .doc(widget.comment.id);

      await commentRef.delete();

      await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .update({'commentCount': FieldValue.increment(-1)});

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete comment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _reportComment() async {
    if (_isReporting) return;

    setState(() => _isReporting = true);

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'type': 'comment',
        'commentId': widget.comment.id,
        'videoId': widget.videoId,
        'reportedBy': FirebaseAuth.instance.currentUser?.uid,
        'reason': 'inappropriate',
        'timestamp': Timestamp.now(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment reported')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to report comment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isReporting = false);
      }
    }
  }

  Future<void> _copyComment() async {
    final text = widget.comment.text;
    await Clipboard.setData(ClipboardData(text: text));

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment copied')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUserId == widget.comment.userId;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1a1a1a)
            : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text('Actions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          )),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _buildActionTile(
                  icon: Icons.content_copy,
                  label: 'Copy comment',
                  onTap: _copyComment,
                ),
                if (isOwner)
                  _buildActionTile(
                    icon: Icons.delete_outline,
                    label: 'Delete comment',
                    color: Colors.red,
                    onTap: _deleteComment,
                    isLoading: _isDeleting,
                  ),
                _buildActionTile(
                  icon: Icons.flag_outline,
                  label: 'Report comment',
                  color: Colors.orange,
                  onTap: _reportComment,
                  isLoading: _isReporting,
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    bool isLoading = false,
  }) {
    return Material(
      child: InkWell(
        onTap: isLoading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color ?? Colors.blue, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 16, color: color),
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
