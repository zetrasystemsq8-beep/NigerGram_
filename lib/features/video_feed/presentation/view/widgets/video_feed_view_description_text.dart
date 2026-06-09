import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
  static const int _characterLimit = 90; // Premium 2-line visual baseline threshold

  @override
  Widget build(BuildContext context) {
    final bool isLongText = widget.text.length > _characterLimit;
    
    // Determine target display slice based on expansion state
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
              text: _isExpanded ? 'less' : 'more',
              style: TextStyle(
                color: white.withAlpha(200),
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

  /// High-performance institutional parsing engine that isolates words,
  /// identifying and highlighting hashtags and user handles dynamically.
  List<InlineSpan> _parseDescriptionContent(String fullText, BuildContext context) {
    final List<InlineSpan> spans = [];
    final List<String> words = fullText.split(' ');

    for (int i = 0; i < words.length; i++) {
      final String word = words[i];
      final bool isTag = word.startsWith('#') || word.startsWith('@');
      
      // Append a trailing space to all words except the absolute final item
      final String spacing = (i == words.length - 1) ? '' : ' ';

      spans.add(
        TextSpan(
          text: '$word$spacing',
          style: TextStyle(
            color: isTag ? const Color(0xFF58A6FF) : white, // Clean neon blue accent highlight for meta tags
            fontWeight: isTag ? FontWeight.w600 : FontWeight.normal,
            fontSize: context.fontSize(15),
            height: 1.4,
          ),
          // Ready-to-use hooks for feature expansion (e.g., clicking a hashtag to open discovery search)
          recognizer: isTag 
              ? (TapGestureRecognizer()..onTap = () => debugPrint('NigerGram Log: Tapped tag token: $word'))
              : null,
        ),
      );
    }
    return spans;
  }
}
