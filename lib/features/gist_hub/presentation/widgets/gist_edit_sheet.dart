// lib/features/gist_hub/presentation/widgets/gist_edit_sheet.dart
import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/gist_hub/data/services/gist_service.dart';

class GistEditSheet extends StatefulWidget {
  final String postId;
  final String currentContent;
  final GistService service;

  const GistEditSheet({
    super.key,
    required this.postId,
    required this.currentContent,
    required this.service,
  });

  @override
  State<GistEditSheet> createState() => _GistEditSheetState();
}

class _GistEditSheetState extends State<GistEditSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.currentContent;
  }

  Future<void> _saveEdit() async {
    final newContent = _controller.text.trim();
    if (newContent.isEmpty || newContent == widget.currentContent) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.service.updatePost(
        postId: widget.postId,
        newContent: newContent,
      );
      if (mounted) {
        Navigator.pop(context, true); // true = updated
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: NGColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: NGColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Edit Gist',
            style: TextStyle(
              color: NGColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 5,
            style: const TextStyle(color: NGColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Update your gist...',
              hintStyle: TextStyle(color: NGColors.textMuted),
              filled: true,
              fillColor: NGColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: NGColors.textMuted),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NGColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
