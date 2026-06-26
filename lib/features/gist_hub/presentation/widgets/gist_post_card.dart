import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/gist_hub/domain/entities/gist_post_entity.dart';
import 'package:nigergram/features/gist_hub/data/services/gist_service.dart';
import 'package:nigergram/features/gist_hub/presentation/widgets/gist_comment_sheet.dart';

class GistPostCard extends StatefulWidget {
  final GistPostEntity post;
  final GistService service;
  final VoidCallback? onPostDeleted;

  const GistPostCard({
    super.key,
    required this.post,
    required this.service,
    this.onPostDeleted,
  });

  @override
  State<GistPostCard> createState() => _GistPostCardState();
}

class _GistPostCardState extends State<GistPostCard> {
  late GistPostEntity _post;
  bool _isDeleting = false;

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
    final shareText = '${_post.content}\n\n🇳🇬 View on NigerGram: https://nigergram.app/gist/${_post.id}';
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

  int get _totalReactions => _post.reactions.values.fold(0, (sum, val) => sum + val);

  Widget _buildBadge() {
    if (_totalReactions >= 20) {
      return Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFF6B00)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.emoji_events, color: Colors.white, size: 12),
            SizedBox(width: 4),
            Text(
              'HOT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else if (_totalReactions >= 10) {
      return Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: NGColors.accent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NGColors.accent.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.whatshot, color: NGColors.accent, size: 12),
            SizedBox(width: 4),
            Text(
              'TRENDING',
              style: TextStyle(
                color: NGColors.accent,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else if (_totalReactions >= 5) {
      return Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.auto_awesome, color: Colors.green, size: 10),
            SizedBox(width: 4),
            Text(
              'POPULAR',
              style: TextStyle(
                color: Colors.green,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NGColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _totalReactions >= 20
              ? const Color(0xFFFFD700).withOpacity(0.2)
              : Colors.transparent,
          width: 1,
        ),
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
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        _post.isAnonymous ? 'Anonymous' : _post.displayName,
                        style: const TextStyle(
                          color: NGColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!_post.isAnonymous) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '@${_post.username}',
                          style: TextStyle(
                            color: NGColors.textMuted,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    _buildBadge(),
                  ],
                ),
              ),
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
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),

          // Image
          if (_post.imageUrl != null && _post.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: _post.imageUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 220,
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
          if (_post.type == 'poll' && (_post.pollOptions?.isNotEmpty ?? false))
            _buildPoll(),
          const SizedBox(height: 12),

          // Reactions & Actions
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
              // Comment Button
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => GistCommentSheet(
                      postId: _post.id,
                      service: widget.service,
                    ),
                  );
                },
                child: Row(
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
          color: count > 0 ? NGColors.accent.withOpacity(0.1) : NGColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: count > 0
              ? Border.all(color: NGColors.accent.withOpacity(0.3))
              : null,
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
                count > 99 ? '99+' : count.toString(),
                style: TextStyle(
                  color: count > 0 ? NGColors.accent : NGColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPoll() {
    final pollOptions = _post.pollOptions ?? [];
    final totalVotes = _post.pollVotes.values.fold(0, (sum, val) => sum + val);
    
    if (pollOptions.isEmpty) return const SizedBox.shrink();
    
    return Column(
      children: [
        ...pollOptions.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final votes = _post.pollVotes[index.toString()] ?? 0;
          final percentage = totalVotes > 0 ? (votes / totalVotes * 100) : 0;
          final hasVoted = _post.pollVotes.containsKey(index.toString());
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () {
                if (hasVoted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('You already voted!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  return;
                }
                
                widget.service.castVote(
                  postId: _post.id,
                  choiceIndex: index,
                ).then((_) {
                  setState(() {
                    _post.pollVotes[index.toString()] = votes + 1;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Voted: $option'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }).catchError((e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to vote, try again'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: hasVoted ? NGColors.accent.withOpacity(0.15) : NGColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: hasVoted
                      ? Border.all(color: NGColors.accent, width: 1.5)
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option,
                        style: TextStyle(
                          color: hasVoted ? NGColors.accent : NGColors.textPrimary,
                          fontSize: 14,
                          fontWeight: hasVoted ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 50,
                      height: 22,
                      decoration: BoxDecoration(
                        color: hasVoted ? NGColors.accent : NGColors.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${percentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: hasVoted ? Colors.white : NGColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 4),
        Text(
          '${totalVotes > 0 ? totalVotes : 0} votes • ${totalVotes > 0 ? (totalVotes == 1 ? '1 person voted' : '$totalVotes people voted') : 'Be the first to vote'}',
          style: TextStyle(
            color: NGColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
