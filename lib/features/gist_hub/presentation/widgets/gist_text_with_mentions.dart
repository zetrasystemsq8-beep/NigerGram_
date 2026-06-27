// lib/features/gist_hub/presentation/widgets/gist_text_with_mentions.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:nigergram/core/design_system/colors.dart';

class GistTextWithMentions extends StatelessWidget {
  const GistTextWithMentions({
    required this.text,
    this.maxLines = 10,
    this.fontSize = 15,
    this.textAlign = TextAlign.start,
    this.onMentionTap,
    super.key,
  });

  final String text;
  final int maxLines;
  final double fontSize;
  final TextAlign textAlign;
  final Function(String username)? onMentionTap;

  @override
  Widget build(BuildContext context) {
    final List<TextSpan> spans = _parseText(text, context);

    return RichText(
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          color: NGColors.textSecondary,
          fontSize: fontSize,
          height: 1.5,
        ),
        children: spans,
      ),
    );
  }

  List<TextSpan> _parseText(String text, BuildContext context) {
    final List<TextSpan> spans = [];
    final RegExp mentionRegex = RegExp(r'@(\w+)');

    int lastMatchEnd = 0;
    final matches = mentionRegex.allMatches(text);

    for (final match in matches) {
      // Text before the mention
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
          ),
        );
      }

      // The mention itself
      final username = match.group(1)!;
      spans.add(
        TextSpan(
          text: '@$username',
          style: TextStyle(
            color: NGColors.accent,
            fontWeight: FontWeight.w600,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              if (onMentionTap != null) {
                onMentionTap!(username);
              } else {
                // ✅ FIXED: Use GoRouter
                GoRouter.of(context).push('/profile/$username');
              }
            },
        ),
      );

      lastMatchEnd = match.end;
    }

    // Remaining text after the last mention
    if (lastMatchEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastMatchEnd),
        ),
      );
    }

    return spans;
  }
}
