// lib/features/video_feed/presentation/widgets/video_feed_view_user_info_section.dart
import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';

class VideoFeedViewUserInfoSection extends StatefulWidget {
  const VideoFeedViewUserInfoSection({
    required this.profileImageUrl,
    required this.username,
    required this.description,
    required this.soundName,
    required this.isVerified,
    required this.isFollowing,
    required this.isOwnVideo,
    required this.onFollowTap,
    super.key,
  });

  final String profileImageUrl;
  final String username;
  final String description;
  final String? soundName;
  final bool isVerified;
  final bool isFollowing;
  final bool isOwnVideo;
  final VoidCallback onFollowTap;

  @override
  State<VideoFeedViewUserInfoSection> createState() => _VideoFeedViewUserInfoSectionState();
}

class _VideoFeedViewUserInfoSectionState extends State<VideoFeedViewUserInfoSection> {
  bool _isExpanded = false;

  List<TextSpan> _parseDescription(String text) {
    final List<TextSpan> spans = [];
    final words = text.split(' ');

    for (var word in words) {
      if (word.startsWith('#') || word.startsWith('@')) {
        spans.add(
          TextSpan(
            text: '$word ',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: NGColors.accent,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(
          text: '$word ',
          style: TextStyle(
            color: NGColors.textSecondary,
          ),
        ));
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. User Identity Header with Verified Badge + Follow Button
        Row(
          children: [
            // Username + Verified Badge
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      '@${widget.username}',
                      style: TextStyle(
                        color: NGColors.textPrimary,
                        fontSize: context.fontSize(17),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        shadows: const [Shadow(blurRadius: 4, color: Colors.black45)],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (widget.isVerified)
                    Icon(
                      Icons.verified_rounded,
                      color: NGColors.verified,
                      size: context.sq(16),
                    ),
                ],
              ),
            ),
            
            if (!widget.isOwnVideo && !widget.isFollowing)
              GestureDetector(
                onTap: widget.onFollowTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: NGColors.accent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Follow',
                    style: TextStyle(
                      color: NGColors.textPrimary,
                      fontSize: context.fontSize(12),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            
            if (!widget.isOwnVideo && widget.isFollowing)
              Text(
                'Following',
                style: TextStyle(
                  color: NGColors.textMuted,
                  fontSize: context.fontSize(12),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        
        SizedBox(height: context.h(8)),

        // 2. Expandable RichText Caption Engine
        if (widget.description.isNotEmpty)
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuart,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    maxLines: _isExpanded ? 100 : 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(
                        color: NGColors.textSecondary,
                        fontSize: context.fontSize(15),
                        height: 1.3,
                        shadows: const [Shadow(blurRadius: 2, color: Colors.black26)],
                      ),
                      children: _parseDescription(widget.description),
                    ),
                  ),
                  if (!_isExpanded && widget.description.length > 60)
                    Padding(
                      padding: EdgeInsets.only(top: context.h(2)),
                      child: Text(
                        'See more',
                        style: TextStyle(
                          color: NGColors.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: context.fontSize(14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
        SizedBox(height: context.h(14)),

        // 3. Immersive Audio Track Marquee
        if (widget.soundName != null && widget.soundName!.isNotEmpty)
          _MusicMarqueeTicker(trackName: widget.soundName!),
      ],
    );
  }
}

/// A hardware-accelerated horizontal scrolling text ticker for audio information
class _MusicMarqueeTicker extends StatefulWidget {
  const _MusicMarqueeTicker({required this.trackName});
  final String trackName;

  @override
  State<_MusicMarqueeTicker> createState() => _MusicMarqueeTickerState();
}

class _MusicMarqueeTickerState extends State<_MusicMarqueeTicker> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() async {
    if (!_scrollController.hasClients) return;

    while (_scrollController.hasClients) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!_scrollController.hasClients) break;
      
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(seconds: 5),
        curve: Curves.linear,
      );
      
      if (!_scrollController.hasClients) break;
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.music_note_rounded,
          color: NGColors.textMuted,
          size: context.sq(18),
        ),
        SizedBox(width: context.w(8)),
        SizedBox(
          width: context.w(200),
          height: context.h(22),
          child: ListView.builder(
            shrinkWrap: true,  // ✅ FIXED: Added this line
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(right: context.w(40)),
                child: Text(
                  widget.trackName,
                  style: TextStyle(
                    color: NGColors.textSecondary,
                    fontSize: context.fontSize(14),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
