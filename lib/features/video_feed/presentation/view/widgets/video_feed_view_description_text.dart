// lib/features/video_feed/presentation/widgets/video_feed_view_description_text.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';

class VideoFeedViewDescriptionText extends StatefulWidget {
  const VideoFeedViewDescriptionText({required this.text, super.key});

  final String text;

  @override
  State<VideoFeedViewDescriptionText> createState() => _VideoFeedViewDescriptionTextState();
}

class _VideoFeedViewDescriptionTextState extends State<VideoFeedViewDescriptionText> {
  bool _isExpanded = false;
  static const int _characterLimit = 90;

  @override
  Widget build(BuildContext context) {
    final bool isLongText = widget.text.length > _characterLimit;
    
    final String displayText = (_isExpanded || !isLongText)
        ? widget.text
        : '${widget.text.substring(0, _characterLimit)}...';

    return RichText(
      text: TextSpan(
        children: [
          ..._parseDescriptionContent(displayText, context),
          if (isLongText) ...[
            const TextSpan(text: ' '),
            TextSpan(
              text: _isExpanded ? ' less' : ' more',
              style: TextStyle(
                color: NGColors.accent, // ✅ Emerald Green
                fontWeight: FontWeight.bold,
                fontSize: context.fontSize(15),
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
            ),
          ],
        ],
      ),
    );
  }

  List<InlineSpan> _parseDescriptionContent(String fullText, BuildContext context) {
    final List<InlineSpan> spans = [];
    final List<String> words = fullText.split(' ');

    for (int i = 0; i < words.length; i++) {
      final String word = words[i];
      final bool isHashtag = word.startsWith('#');
      final bool isMention = word.startsWith('@');
      final bool isTag = isHashtag || isMention;
      
      final String spacing = (i == words.length - 1) ? '' : ' ';

      spans.add(
        TextSpan(
          text: '$word$spacing',
          style: TextStyle(
            color: isTag ? NGColors.accent : NGColors.textPrimary, // ✅ Emerald Green for tags
            fontWeight: isTag ? FontWeight.w600 : FontWeight.normal,
            fontSize: context.fontSize(15),
            height: 1.4,
          ),
          recognizer: isTag 
              ? (TapGestureRecognizer()
                ..onTap = () {
                  if (isHashtag) {
                    // 🔥 Navigate to Discover with hashtag
                    final tag = word.substring(1); // Remove #
                    context.push('/discover?tag=$tag');
                  } else if (isMention) {
                    // 🔥 Navigate to user profile
                    final username = word.substring(1); // Remove @
                    context.push('/profile/$username');
                  }
                })
              : null,
        ),
      );
    }
    return spans;
  }
}
