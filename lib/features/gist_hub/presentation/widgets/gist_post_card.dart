import 'package:nigergram/core/design_system/colors.dart';
// lib/features/gist_hub/presentation/widgets/gist_post_card.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/gist_hub/domain/entities/gist_post_entity.dart';
import 'package:nigergram/features/gist_hub/data/services/gist_service.dart';

class GistPostCard extends StatefulWidget {
  final GistPostEntity post;
  final GistService service;

  const GistPostCard({
    super.key,
    required this.post,
    required this.service,
  });

  @override
  State<GistPostCard> createState() => _GistPostCardState();
}

class _GistPostCardState extends State<GistPostCard> {
  late GistPostEntity _post;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  void _addReaction(String emoji) {
    setState(() {
      _post.reactions[emoji] = (_post.reactions[emoji] ?? 0) + 1;
    });
    widget.service.addReaction(
      postId: _post.id,
      emoji: emoji,
    ).catchError((e) {
      setState(() {
        _post.reactions[emoji] = (_post.reactions[emoji] ?? 0) - 1;
      });
    });
  }

  void _sharePost() {
    final shareText = '${_post.content}\n\nView on NigerGram: https://nigergram.app/gist/${_post.id}';
    Share.share(shareText, subject: 'Check this Gist');
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NGColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Info
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: NGColors.surfaceLight,
                backgroundImage: _post.isAnonymous || _post.profilePic.isEmpty
                    ? null
                    : CachedNetworkImageProvider(_post.profilePic),
                child: _post.isAnonymous || _post.profilePic.isEmpty
                    ? const Icon(Icons.person, color: NGColors.textMuted, size: 20)
                    : null,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _post.isAnonymous ? 'Anonymous' : _post.displayName,
                    style: const TextStyle(
                      color: NGColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _post.isAnonymous ? 'Anonymous' : '@${_post.username}',
                    style: TextStyle(
                      color: NGColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                _formatDate(_post.createdAt),
                style: TextStyle(
                  color: NGColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Content
          Text(
            _post.content,
            style: const TextStyle(
              color: NGColors.textPrimary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // Image
          if (_post.imageUrl != null && _post.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: _post.imageUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 200,
                placeholder: (context, url) => Container(
                  color: NGColors.surfaceLight,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: NGColors.accent,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: NGColors.surfaceLight,
                  child: const Icon(Icons.error, color: NGColors.textMuted),
                ),
              ),
            ),
          const SizedBox(height: 12),

          // Poll
          if (_post.type == 'poll' && _post.pollOptions.isNotEmpty)
            _buildPoll(),
          const SizedBox(height: 12),

          // Reactions
          Row(
            children: [
              _buildReactionButton('😂'),
              const SizedBox(width: 4),
              _buildReactionButton('😱'),
              const SizedBox(width: 4),
              _buildReactionButton('👀'),
              const SizedBox(width: 4),
              _buildReactionButton('🥴'),
              const SizedBox(width: 4),
              _buildReactionButton('🇳🇬'),
              const Spacer(),
              // Comment Count
              Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    color: NGColors.textMuted,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_post.commentCount}',
                    style: TextStyle(
                      color: NGColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Share Button
              GestureDetector(
                onTap: _sharePost,
                child: const Icon(
                  Icons.share_outlined,
                  color: NGColors.textMuted,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReactionButton(String emoji) {
    final count = _post.reactions[emoji] ?? 0;
    return GestureDetector(
      onTap: () => _addReaction(emoji),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: NGColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 14),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  color: NGColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPoll() {
    final totalVotes = _post.pollVotes.values.fold(0, (sum, val) => sum + val);
    return Column(
      children: [
        ..._post.pollOptions.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final votes = _post.pollVotes[index.toString()] ?? 0;
          final percentage = totalVotes > 0 ? (votes / totalVotes * 100) : 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                if (_post.pollVotes.keys.contains(index.toString())) return;
                widget.service.castVote(
                  postId: _post.id,
                  choiceIndex: index,
                ).then((_) {
                  setState(() {
                    _post.pollVotes[index.toString()] = votes + 1;
                  });
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: NGColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option,
                        style: TextStyle(
                          color: NGColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: NGColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
        Text(
          '${totalVotes} votes',
          style: TextStyle(
            color: NGColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
