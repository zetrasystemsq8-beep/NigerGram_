import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';

class VideoFeedViewUserInfoSection extends StatefulWidget {
  const VideoFeedViewUserInfoSection({
    required this.profileImageUrl,
    required this.username,
    required this.description,
    super.key,
  });

  final String profileImageUrl;
  final String username;
  final String description;

  @override
  State<VideoFeedViewUserInfoSection> createState() => _VideoFeedViewUserInfoSectionState();
}

class _VideoFeedViewUserInfoSectionState extends State<VideoFeedViewUserInfoSection> {
  bool _isExpanded = false;

  /// High-fidelity parser to style hashtags and mentions differently than standard caption text
  List<TextSpan> _parseDescription(String text) {
    final List<TextSpan> spans = [];
    final words = text.split(' ');

    for (var word in words) {
      if (word.startsWith('#') || word.startsWith('@')) {
        spans.add(
          TextSpan(
            text: '$word ',
            style: const TextStyle(
              fontWeight: FontWeight.w800, // Thicker weight for interactive tokens
              color: white,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: '$word '));
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
        // 1. User Identity Header with Verified Badge
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '@${widget.username}',
              style: TextStyle(
                color: white,
                fontSize: context.fontSize(17),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                shadows: const [Shadow(blurRadius: 4, color: Colors.black45)],
              ),
            ),
            SizedBox(width: context.w(6)),
            // Institutional 'Verified' checkmark integration
            Icon(
              Icons.verified,
              color: const Color(0xFF20D5EC), // Vibrant sky-blue verified tint
              size: context.sq(16),
            ),
          ],
        ),
        SizedBox(height: context.h(8)),

        // 2. Expandable RichText Caption Engine
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
                      color: white.withAlpha(240),
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
                        color: white,
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
        const _MusicMarqueeTicker(trackName: 'Zetra Original Audio - @toluwani'),
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
    // Delay initialization to ensure layout is painted before starting loop
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() async {
    if (!_scrollController.hasClients) return;

    while (_scrollController.hasClients) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!_scrollController.hasClients) break;
      
      // Perform seamless linear crawl across the axis
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(seconds: 5),
        curve: Curves.linear,
      );
      
      if (!_scrollController.hasClients) break;
      
      // Instant reset to origin for infinite loop feel
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
        Icon(Icons.music_note_rounded, color: white, size: context.sq(18)),
        SizedBox(width: context.w(8)),
        SizedBox(
          width: context.w(200), // Constraint boundary for the marquee channel
          height: context.h(22),
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(right: context.w(40)),
                child: Text(
                  widget.trackName,
                  style: TextStyle(
                    color: white,
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
