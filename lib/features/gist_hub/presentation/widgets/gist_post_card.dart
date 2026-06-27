// lib/features/gist_hub/presentation/widgets/gist_post_card.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/gist_hub/domain/entities/gist_post_entity.dart';
import 'package:nigergram/features/gist_hub/data/services/gist_service.dart';
import 'package:nigergram/features/gist_hub/presentation/widgets/gist_comment_sheet.dart';
import 'package:nigergram/features/gist_hub/presentation/widgets/gist_hub_features.dart';

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
  bool _isSaved = false;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final Set<String> _reactedEmojis = {};

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _checkIfSaved();
  }

  void _checkIfSaved() async {
    if (_currentUserId.isNotEmpty) {
      final saved = await SaveGistFeature.isPostSaved(_currentUserId, _post.id);
      setState(() {
        _isSaved = saved;
      });
    }
  }

  void _addReaction(String emoji) {
    if (_reactedEmojis.contains(emoji)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already reacted with this emoji!'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() {
      _post.reactions[emoji] = (_post.reactions[emoji] ?? 0) + 1;
      _reactedEmojis.add(emoji);
    });
    
    widget.service.addReaction(
      postId: _post.id,
      emoji: emoji,
    ).catchError((e) {
      setState(() {
        _post.reactions[emoji] = (_post.reactions[emoji] ?? 0) - 1;
        _reactedEmojis.remove(emoji);
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
            _buildPremiumPoll(),
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
              // Comment Button with proper count display
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
                      _post.commentCount == 0
                          ? '0 Comments'
                          : '${_post.commentCount} ${_post.commentCount == 1 ? 'Comment' : 'Comments'}',
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
    final hasReacted = _reactedEmojis.contains(emoji);
    
    return GestureDetector(
      onTap: () => _addReaction(emoji),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: hasReacted 
              ? NGColors.accent.withOpacity(0.2) 
              : count > 0 
                  ? NGColors.accent.withOpacity(0.1) 
                  : NGColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: hasReacted || count > 0
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
                  color: hasReacted ? NGColors.accent : NGColors.textSecondary,
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

  // Premium Poll
  Widget _buildPremiumPoll() {
    final pollOptions = _post.pollOptions ?? [];
    final totalVotes = _post.pollVotes.values.fold(0, (sum, val) => sum + val);
    
    final bool hasVoted = _post.pollVoters.containsKey(_currentUserId);
    final int? votedIndex = hasVoted ? _post.pollVoters[_currentUserId] : null;
    
    String getTimeRemaining() {
      if (_post.expiresAt == null) return '7 days left';
      final expiry = _post.expiresAt!.toDate();
      final now = DateTime.now();
      final diff = expiry.difference(now);
      if (diff.inDays > 0) return '${diff.inDays}d left';
      if (diff.inHours > 0) return '${diff.inHours}h left';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m left';
      return 'Expired';
    }
    
    if (pollOptions.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: NGColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: NGColors.divider.withOpacity(0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '📊 Poll',
                style: TextStyle(
                  color: NGColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              if (totalVotes > 10)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: NGColors.accentGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: NGColors.accentGold.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.whatshot, color: NGColors.accentGold, size: 10),
                      SizedBox(width: 4),
                      Text(
                        'Hot',
                        style: TextStyle(
                          color: NGColors.accentGold,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: NGColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      color: NGColors.textMuted,
                      size: 10,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      getTimeRemaining(),
                      style: TextStyle(
                        color: NGColors.textMuted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Poll options
          ...pollOptions.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final votes = _post.pollVotes[index.toString()] ?? 0;
            final percentage = totalVotes > 0 ? (votes / totalVotes * 100) : 0;
            final bool isSelected = hasVoted && votedIndex == index;
            final bool isUnselected = hasVoted && votedIndex != index;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
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
                    
                    HapticFeedback.mediumImpact();
                    
                    widget.service.castVote(
                      postId: _post.id,
                      choiceIndex: index,
                    ).then((_) {
                      setState(() {
                        _post.pollVotes[index.toString()] = (_post.pollVotes[index.toString()] ?? 0) + 1;
                        _post.pollVoters[_currentUserId] = index;
                      });
                    }).catchError((e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to vote: ${e.toString()}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? NGColors.accent.withOpacity(0.12)
                          : isUnselected
                              ? NGColors.surfaceLight.withOpacity(0.5)
                              : NGColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? NGColors.accent
                            : NGColors.divider.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? NGColors.accent : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? NGColors.accent : NGColors.divider,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                option,
                                style: TextStyle(
                                  color: isSelected || isUnselected
                                      ? NGColors.textPrimary
                                      : NGColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                            Text(
                              '${percentage.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: isSelected ? NGColors.accent : NGColors.textMuted,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        if (totalVotes > 0) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: NGColors.surfaceLight,
                              color: isSelected ? NGColors.accent : Colors.grey.shade600,
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          
          if (totalVotes > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '$totalVotes vote${totalVotes > 1 ? 's' : ''}',
                style: TextStyle(
                  color: NGColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
