// lib/features/gist_hub/presentation/widgets/gist_post_card.dart

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nigergram/features/gist_hub/data/services/gist_service.dart';
import 'package:nigergram/features/gist_hub/domain/entities/gist_post_entity.dart';
import 'package:nigergram/features/profile/presentation/view/profile_view.dart';

class GistPostCard extends StatefulWidget {
  final GistPostEntity post;
  final GistService service;

  const GistPostCard({super.key, required this.post, required this.service});

  @override
  State<GistPostCard> createState() => _GistPostCardState();
}

class _GistPostCardState extends State<GistPostCard> {
  late Map<String, int> _reactions;
  late Map<String, int> _pollVotes;
  bool _hasVoted = false;
  int? _votedChoice;

  @override
  void initState() {
    super.initState();
    _reactions = Map<String, int>.from(widget.post.reactions);
    _pollVotes = Map<String, int>.from(widget.post.pollVotes);
  }

  void _showSnack(String msg, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: NGColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
      backgroundColor: isSuccess ? NGColors.success : NGColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _onReactionTap(String emoji) async {
    try {
      setState(() {
        _reactions[emoji] = (_reactions[emoji] ?? 0) + 1;
      });
      await widget.service.addReaction(postId: widget.post.id, emoji: emoji);
    } catch (e) {
      print('addReaction error: $e');
      setState(() {
        _reactions[emoji] = (_reactions[emoji] ?? 1) - 1;
      });
      _showSnack('Failed to react', isSuccess: false);
    }
  }

  Future<void> _onPollChoiceTap(int index) async {
    if (_hasVoted) {
      _showSnack('You already voted', isSuccess: false);
      return;
    }
    try {
      setState(() {
        _pollVotes['$index'] = (_pollVotes['$index'] ?? 0) + 1;
        _hasVoted = true;
        _votedChoice = index;
      });
      await widget.service.castVote(postId: widget.post.id, choiceIndex: index);
    } catch (e) {
      print('castVote error: $e');
      setState(() {
        _pollVotes['$index'] = (_pollVotes['$index'] ?? 1) - 1;
        _hasVoted = false;
        _votedChoice = null;
      });
      _showSnack('Voting failed', isSuccess: false);
    }
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NGColors.background,
      builder: (ctx) {
        final TextEditingController _ctrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Column(
              children: [
                Container(
                  height: 4,
                  width: 60,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: NGColors.divider, borderRadius: BorderRadius.circular(4)),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: widget.service.getCommentsStream(widget.post.id),
                    builder: (context, snap) {
                      if (snap.hasError) return Center(child: Text('Failed to load comments', style: TextStyle(color: NGColors.textSecondary)));
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return Center(child: Text('No comments yet', style: TextStyle(color: NGColors.textSecondary)));
                      }
                      return ListView.separated(
                        reverse: false,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemBuilder: (context, index) {
                          final d = docs[index].data();
                          final createdAt = d['createdAt'];
                          final ts = createdAt is Timestamp ? createdAt.toDate() : DateTime.now();
                          return ListTile(
                            leading: d['profilePic'] != null && d['profilePic'].toString().isNotEmpty
                                ? CircleAvatar(backgroundImage: NetworkImage(d['profilePic']))
                                : CircleAvatar(child: Text((d['displayName']?.toString() ?? 'A')[0])),
                            title: Text(d['displayName']?.toString() ?? 'Unknown', style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.w700)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d['text']?.toString() ?? '', style: TextStyle(color: NGColors.textSecondary)),
                                SizedBox(height: 4),
                                Text('${ts.toLocal()}', style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
                              ],
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemCount: docs.length,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: const TextStyle(color: NGColors.textMuted),
                            filled: true,
                            fillColor: NGColors.surfaceLight,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: NGColors.accent),
                        onPressed: () async {
                          final text = _ctrl.text.trim();
                          if (text.isEmpty) return;
                          try {
                            await widget.service.addComment(postId: widget.post.id, text: text);
                            _ctrl.clear();
                            _showSnack('Comment added', isSuccess: true);
                          } catch (e) {
                            print('addComment error: $e');
                            _showSnack('Failed to add comment', isSuccess: false);
                          }
                        },
                        child: const Text('Send'),
                      ),
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

  void _onShare() {
    final summary = widget.post.content.isNotEmpty ? widget.post.content : (widget.post.type == 'image' ? 'Image Gist' : 'Check this gist');
    final shareText = '$summary\n\nView on NigerGram: https://nigergram.app/gist/${widget.post.id}';
    Share.share(shareText, subject: 'Check this Gist');
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final created = post.createdAt.toDate();
    final timeString = '${created.toLocal()}';

    return Card(
      color: NGColors.surface,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                post.isAnonymous || post.profilePic.isEmpty
                    ? CircleAvatar(backgroundColor: NGColors.divider, child: const Icon(Icons.person, color: Colors.white))
                    : CircleAvatar(backgroundImage: NetworkImage(post.profilePic)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.isAnonymous ? 'Anonymous' : post.displayName, style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.bold)),
                      Text(post.isAnonymous ? '' : '@${post.username}', style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                Text(timeString, style: TextStyle(color: NGColors.textMuted, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 12),
            // Content
            if (post.type == 'text' || post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(post.content, style: TextStyle(color: NGColors.textPrimary)),
              ),
            if (post.type == 'image' && post.imageUrl != null && post.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(height: 180, color: NGColors.surfaceLight, child: const Center(child: CircularProgressIndicator())),
                  errorWidget: (context, url, err) => Container(height: 180, color: NGColors.surfaceLight, child: const Center(child: Icon(Icons.broken_image))),
                ),
              ),
            if (post.type == 'poll' && (post.pollOptions?.length ?? 0) >= 2)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  children: [
                    for (var i = 0; i < 2; i++)
                      GestureDetector(
                        onTap: () => _onPollChoiceTap(i),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: _votedChoice == i ? NGColors.accent.withOpacity(0.15) : NGColors.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: NGColors.divider),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(post.pollOptions![i], style: TextStyle(color: NGColors.textPrimary))),
                              const SizedBox(width: 8),
                              Text('${_pollVotes['$i'] ?? 0}', style: TextStyle(color: NGColors.textMuted)),
                            ],
                          ),
                        ),
                      ),
                    // percentage bar
                    Builder(builder: (context) {
                      final a = (_pollVotes['0'] ?? 0);
                      final b = (_pollVotes['1'] ?? 0);
                      final total = (a + b);
                      final aPct = total == 0 ? 0.0 : (a / total);
                      final bPct = total == 0 ? 0.0 : (b / total);
                      return Row(
                        children: [
                          Expanded(
                            flex: (aPct * 100).round(),
                            child: Container(height: 6, color: NGColors.accent, margin: const EdgeInsets.only(right: 2)),
                          ),
                          Expanded(
                            flex: (bPct * 100).round(),
                            child: Container(height: 6, color: NGColors.surfaceLight, margin: const EdgeInsets.only(left: 2)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Emojis
                Row(
                  children: [
                    for (final emoji in ['😂', '😱', '👀', '🥴', '🇳🇬'])
                      GestureDetector(
                        onTap: () => _onReactionTap(emoji),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: NGColors.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Text('${_reactions[emoji] ?? 0}', style: TextStyle(color: NGColors.textMuted)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                // Action buttons
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _openComments,
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                      label: Text('${widget.post.commentCount}', style: TextStyle(color: NGColors.textPrimary)),
                    ),
                    IconButton(
                      onPressed: _onShare,
                      icon: const Icon(Icons.share, color: Colors.white),
                    ),
                  ],
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
