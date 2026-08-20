import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Helper to strip trailing punctuation from tags/handles, e.g. "#tag," -> "tag"
  String _sanitizeToken(String token) {
    return token.replaceAll(RegExp(r'^[#@]+'), '') // remove leading #/@
                .replaceAll(RegExp(r'[^A-Za-z0-9_\-]$'), '') // trim trailing punctuation
                .trim();
  }

  /// High-performance institutional parsing engine that isolates words,
  /// identifying and highlighting hashtags and user handles dynamically.
  List<InlineSpan> _parseDescriptionContent(String fullText, BuildContext context) {
    final List<InlineSpan> spans = [];
    final List<String> words = fullText.split(' ');

    for (int i = 0; i < words.length; i++) {
      final String raw = words[i];
      final bool isTag = raw.startsWith('#') || raw.startsWith('@');

      // Append a trailing space to all words except the absolute final item
      final String spacing = (i == words.length - 1) ? '' : ' ';

      if (isTag) {
        final String sanitized = _sanitizeToken(raw);
        final bool isMention = raw.startsWith('@');

        spans.add(
          TextSpan(
            text: '$raw$spacing',
            style: TextStyle(
              color: const Color(0xFF58A6FF), // neon blue accent for meta tags
              fontWeight: FontWeight.w600,
              fontSize: context.fontSize(15),
              height: 1.4,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                // Provide tactile feedback
                HapticFeedback.selectionClick();

                if (sanitized.isEmpty) return;
                try {
                  if (isMention) {
                    // navigate to profile
                    context.push('/profile/$sanitized');
                  } else {
                    // navigate to discover with tag
                    context.push('/discover?tag=$sanitized');
                  }
                } catch (e) {
                  // In case navigation fails, log for diagnostics
                  debugPrint('Navigation error for token "$raw": $e');
                }
              },
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: '$raw$spacing',
            style: TextStyle(
              color: white,
              fontWeight: FontWeight.normal,
              fontSize: context.fontSize(15),
              height: 1.4,
            ),
            recognizer: null,
          ),
        );
      }
    }
    return spans;
  }
}
