import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';

/// Master Column orchestrating the right-side layout matrix
class VideoFeedViewInteractionButtons extends StatelessWidget {
  const VideoFeedViewInteractionButtons({
    required this.isLiked,
    required this.isBookmarked,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.onLikeTapped,
    super.key,
  });

  final bool isLiked;
  final bool isBookmarked;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final VoidCallback onLikeTapped;

  void _showCommentsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => _CommentSectionBottomSheet(initialCount: commentCount),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Creator Profile Node with Animated Follow Cap
        const _AnimatedProfileAvatarNode(
          avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
        ),
        SizedBox(height: context.h(20)),

        // 2. High-Fidelity Reactive Like Component
        VideoFeedViewInteractionButton(
          icon: Icons.favorite_rounded,
          count: likeCount,
          iconColor: isLiked ? const Color(0xFFFE2C55) : white,
          onTap: onLikeTapped,
        ),
        SizedBox(height: context.h(16)),

        // 3. Comment Component Node
        VideoFeedViewInteractionButton(
          icon: Icons.chat_bubble_rounded,
          count: commentCount,
          onTap: () {
            HapticFeedback.lightImpact();
            _showCommentsBottomSheet(context);
          },
        ),
        SizedBox(height: context.h(16)),

        // 4. Bookmark/Favorite Component Node
        _StatefulBookmarkButton(
          isBookmarked: isBookmarked,
          count: shareCount + 3400,
        ),
        SizedBox(height: context.h(16)),

        // 5. Share Core Action Hub
        VideoFeedViewInteractionButton(
          icon: Icons.reply_rounded,
          count: shareCount,
          onTap: () {
            HapticFeedback.mediumImpact();
            debugPrint('NigerGram Log: Fire modern multi-platform native share drawer.');
          },
        ),
      ],
    );
  }
}

/// Core Primitive UI Interactive Element wrapped in Spring Animation Pipelines
class VideoFeedViewInteractionButton extends StatefulWidget {
  const VideoFeedViewInteractionButton({
    required this.icon,
    required this.count,
    required this.onTap,
    this.iconColor = white,
    super.key,
  });

  final IconData icon;
  final int count;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  State<VideoFeedViewInteractionButton> createState() => _VideoFeedViewInteractionButtonState();
}

class _VideoFeedViewInteractionButtonState extends State<VideoFeedViewInteractionButton> with SingleTickerProviderStateMixin {
  late final AnimationController _scaleAnimationController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.elasticIn)), weight: 50),
    ]).animate(_scaleAnimationController);
  }

  @override
  void dispose() {
    _scaleAnimationController.dispose();
    super.dispose();
  }

  String _formatMetricCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  void _executeInteractionSequence() {
    HapticFeedback.lightImpact();
    _scaleAnimationController.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _executeInteractionSequence,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Icon(
              widget.icon,
              color: widget.iconColor,
              size: context.sq(38),
              shadows: const [
                Shadow(
                  color: Colors.black38,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          SizedBox(height: context.h(3)),
          Text(
            _formatMetricCount(widget.count),
            style: TextStyle(
              color: white,
              fontSize: context.fontSize(12.5),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatefulBookmarkButton extends StatefulWidget {
  const _StatefulBookmarkButton({required this.isBookmarked, required this.count});
  final bool isBookmarked;
  final int count;

  @override
  State<_StatefulBookmarkButton> createState() => _StatefulBookmarkButtonState();
}

class _StatefulBookmarkButtonState extends State<_StatefulBookmarkButton> {
  late bool _innerBookmarkState;
  late int _innerCount;

  @override
  void initState() {
    super.initState();
    _innerBookmarkState = widget.isBookmarked;
    _innerCount = widget.count;
  }

  @override
  Widget build(BuildContext context) {
    return VideoFeedViewInteractionButton(
      icon: Icons.bookmark_rounded,
      count: _innerCount,
      iconColor: _innerBookmarkState ? const Color(0xFFFACE15) : white,
      onTap: () {
        setState(() {
          _innerBookmarkState = !_innerBookmarkState;
          _innerCount = _innerBookmarkState ? _innerCount + 1 : _innerCount - 1;
        });
      },
    );
  }
}

class _AnimatedProfileAvatarNode extends StatefulWidget {
  const _AnimatedProfileAvatarNode({required this.avatarUrl});
  final String avatarUrl;

  @override
  State<_AnimatedProfileAvatarNode> createState() => _AnimatedProfileAvatarNodeState();
}

class _AnimatedProfileAvatarNodeState extends State<_AnimatedProfileAvatarNode> with SingleTickerProviderStateMixin {
  bool _isFollowing = false;
  late final AnimationController _badgeHideController;
  late final Animation<double> _badgeScaleAnimation;

  @override
  void initState() {
    super.initState();
    _badgeHideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _badgeScaleAnimation = CurveTween(curve: Curves.easeIn).animate(_badgeHideController);
  }

  @override
  void dispose() {
    _badgeHideController.dispose();
    super.dispose();
  }

  void _triggerFollowAction() {
    HapticFeedback.mediumImpact();
    _badgeHideController.forward().then((_) {
      setState(() => _isFollowing = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.w(52),
      height: context.h(58),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: context.sq(48),
            height: context.sq(48),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.network(
                widget.avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) => const Icon(Icons.person, color: white),
              ),
            ),
          ),
          if (!_isFollowing)
            Positioned(
              bottom: context.h(4),
              child: ScaleTransition(
                scale: _badgeScaleAnimation,
                child: GestureDetector(
                  onTap: _triggerFollowAction,
                  child: Container(
                    width: context.sq(22),
                    height: context.sq(22),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFE2C55),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add,
                      color: white,
                      size: context.sq(16),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// High-Fidelity, Dark-Themed TikTok-Style Sliding Comment Drawer Portfolio Component
class _CommentSectionBottomSheet extends StatefulWidget {
  const _CommentSectionBottomSheet({required this.initialCount});
  final int initialCount;

  @override
  State<_CommentSectionBottomSheet> createState() => _CommentSectionBottomSheetState();
}

class _CommentSectionBottomSheetState extends State<_CommentSectionBottomSheet> {
  final TextEditingController _commentTextController = TextEditingController();
  final List<_CommentItemData> _localCommentsList = [];
  late int _totalCommentsCounter;
  bool _canPostComment = false;

  @override
  void initState() {
    super.initState();
    _totalCommentsCounter = widget.initialCount;
    _commentTextController.addListener(_onCommentTextChanged);
    _populateHighFidelityMockDataset();
  }

  @override
  void dispose() {
    _commentTextController.removeListener(_onCommentTextChanged);
    _commentTextController.dispose();
    super.dispose();
  }

  void _onCommentTextChanged() {
    final hasText = _commentTextController.text.trim().isNotEmpty;
    if (hasText != _canPostComment) {
      setState(() => _canPostComment = hasText);
    }
  }

  void _populateHighFidelityMockDataset() {
    _localCommentsList.addAll([
      _CommentItemData(
        username: 'chinedu_okafor',
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        commentText: 'Omo, this comedy timing is completely top tier! base build is too solid 😭😭😂',
        timestamp: '2h',
        likeCount: 1420,
      ),
      _CommentItemData(
        username: 'funke_vibes',
        avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
        commentText: 'Naija creators are not playing this year! The soundtrack choice was elite 🔥🇳🇬',
        timestamp: '5h',
        likeCount: 845,
      ),
      _CommentItemData(
        username: 'tunde_king',
        avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
        commentText: 'The low-data optimization footprint on this stream layout is crazy smooth.',
        timestamp: '1d',
        likeCount: 310,
      ),
    ]);
  }

  void _submitCommentForm() {
    final cleanedText = _commentTextController.text.trim();
    if (cleanedText.isEmpty) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _localCommentsList.insert(
        0,
        _CommentItemData(
          username: 'naija_creator',
          avatarUrl: '',
          commentText: cleanedText,
          timestamp: 'Just now',
          likeCount: 0,
        ),
      );
      _totalCommentsCounter++;
      _commentTextController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardBuffer = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: context.h(520) + keyboardBuffer,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Structural Sheet Drag Node Handle Indicator
            SizedBox(height: context.h(8)),
            Container(
              width: context.w(40),
              height: context.h(4),
              decoration: BoxDecoration(
                color: white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Dynamic Header Node Orchestration Matrix
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.w(16), vertical: context.h(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(width: context.w(24)), // Equalizer Spacer Alignment Shield
                  Text(
                    '$_totalCommentsCounter comments',
                    style: TextStyle(
                      color: white,
                      fontSize: context.fontSize(13.5),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close_rounded,
                      color: white,
                      size: context.sq(22),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF262626), height: 1),

            // Main Core Scrollable Workspace Feed Thread List View
            Expanded(
              child: _localCommentsList.isEmpty
                  ? Center(
                      child: Text(
                        'No comments yet. Start the conversation!',
                        style: TextStyle(color: white.withOpacity(0.5), fontSize: context.fontSize(14)),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.only(
                        left: context.w(16),
                        right: context.w(16),
                        top: context.h(12),
                        bottom: context.h(24),
                      ),
                      itemCount: _localCommentsList.length,
                      itemBuilder: (context, index) {
                        return _CommentListItemRow(data: _localCommentsList[index]);
                      },
                    ),
            ),

            // Fixed Structural Stick-to-Bottom Premium Keyboard Dock Anchor Panel
            const Divider(color: Color(0xFF262626), height: 1),
            Container(
              padding: EdgeInsets.only(
                left: context.w(16),
                right: context.w(16),
                top: context.h(10),
                bottom: context.h(12) + keyboardBuffer,
              ),
              color: const Color(0xFF1E1E1E),
              child: Row(
                children: [
                  Container(
                    width: context.sq(36),
                    height: context.sq(36),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3A3A3A),
                      border: Border.all(color: white.withOpacity(0.1), width: 1),
                    ),
                    child: const ClipOval(
                      child: Icon(Icons.person, color: white, size: 20),
                    ),
                  ),
                  SizedBox(width: context.w(12)),
                  Expanded(
                    child: Container(
                      height: context.h(40),
                      padding: EdgeInsets.symmetric(horizontal: context.w(14)),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D2D2D),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _commentTextController,
                        style: TextStyle(color: white, fontSize: context.fontSize(14)),
                        maxLines: 1,
                        cursorColor: const Color(0xFFFE2C55),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submitCommentForm(),
                        decoration: InputDecoration(
                          hintText: 'Add comment for Naija content...',
                          hintStyle: TextStyle(color: white.withOpacity(0.4), fontSize: context.fontSize(14)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: context.h(11)),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: context.w(12)),
                  GestureDetector(
                    onTap: _canPostComment ? _submitCommentForm : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(horizontal: context.w(12), vertical: context.h(8)),
                      child: Icon(
                        Icons.send_rounded,
                        color: _canPostComment ? const Color(0xFFFE2C55) : white.withOpacity(0.3),
                        size: context.sq(22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Specialized View Layer row primitive mapping individual comment structures
class _CommentListItemRow extends StatefulWidget {
  const _CommentListItemRow({required this.data});
  final _CommentItemData data;

  @override
  State<_CommentListItemRow> createState() => _CommentListItemRowState();
}

class _CommentListItemRowState extends State<_CommentListItemRow> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.h(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: context.sq(34),
            height: context.sq(34),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF262626),
              border: Border.all(color: white.withOpacity(0.1), width: 1),
            ),
            child: ClipOval(
              child: Image.network(
                widget.data.avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) => const Icon(Icons.person, color: white, size: 18),
              ),
            ),
          ),
          SizedBox(width: context.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.data.username,
                  style: TextStyle(
                    color: white.withOpacity(0.6),
                    fontSize: context.fontSize(12),
                    fontWeight: FontWeight.w640,
                  ),
                ),
                SizedBox(height: context.h(4)),
                Text(
                  widget.data.commentText,
                  style: TextStyle(
                    color: white,
                    fontSize: context.fontSize(13.5),
                    height: 1.3,
                  ),
                ),
                SizedBox(height: context.h(6)),
                Text(
                  widget.data.timestamp,
                  style: TextStyle(
                    color: white.withOpacity(0.4),
                    fontSize: context.fontSize(11),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.w(12)),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                widget.data.isLikedByCurrentUser = !widget.data.isLikedByCurrentUser;
                if (widget.data.isLikedByCurrentUser) {
                  widget.data.likeCount++;
                } else {
                  widget.data.likeCount--;
                }
              });
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.data.isLikedByCurrentUser ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: widget.data.isLikedByCurrentUser ? const Color(0xFFFE2C55) : white.withOpacity(0.4),
                  size: context.sq(16),
                ),
                SizedBox(height: context.h(2)),
                Text(
                  widget.data.likeCount > 0 ? widget.data.likeCount.toString() : '',
                  style: TextStyle(
                    color: white.withOpacity(0.4),
                    fontSize: context.fontSize(10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Structured Object Data Payload Model specifically targeting localized Comment attributes
class _CommentItemData {
  _CommentItemData({
    required this.username,
    required this.avatarUrl,
    required this.commentText,
    required this.timestamp,
    required this.likeCount,
    this.isLikedByCurrentUser = false,
  });

  final String username;
  final String avatarUrl;
  final String commentText;
  final String timestamp;
  int likeCount;
  bool isLikedByCurrentUser;
}
