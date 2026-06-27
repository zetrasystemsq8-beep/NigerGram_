// lib/features/upload/presentation/view/video_editor_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_trimmer/video_trimmer.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:video_player/video_player.dart';

class VideoEditorScreen extends StatefulWidget {
  final File videoFile;

  const VideoEditorScreen({
    super.key,
    required this.videoFile,
  });

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  final Trimmer _trimmer = Trimmer();
  bool _isTrimming = false;
  bool _isPlaying = false;
  double _startValue = 0.0;
  double _endValue = 1.0;
  VideoPlayerController? _controller;
  File? _trimmedFile;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    await _trimmer.loadVideo(videoFile: widget.videoFile);
    _controller = _trimmer.videoPlayerController;
    setState(() {});
  }

  Future<void> _trimVideo() async {
    setState(() => _isTrimming = true);
    try {
      final trimmed = await _trimmer.trimVideo(
        startValue: _startValue,
        endValue: _endValue,
      );
      if (trimmed != null) {
        setState(() => _trimmedFile = File(trimmed.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Trim failed: $e'),
          backgroundColor: NGColors.error,
        ),
      );
    } finally {
      setState(() => _isTrimming = false);
    }
  }

  void _togglePlay() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  void _saveAndReturn() {
    final fileToReturn = _trimmedFile ?? widget.videoFile;
    Navigator.pop(context, fileToReturn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NGColors.background,
      appBar: AppBar(
        backgroundColor: NGColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: NGColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Video',
          style: TextStyle(
            color: NGColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _trimmedFile != null ? _saveAndReturn : null,
            child: Text(
              'Apply',
              style: TextStyle(
                color: _trimmedFile != null ? NGColors.accent : NGColors.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _controller == null
          ? const Center(
              child: CircularProgressIndicator(
                color: NGColors.accent,
              ),
            )
          : Column(
              children: [
                // Video Preview
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      Container(
                        color: NGColors.surface,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          ),
                        ),
                      ),
                      // Play/Pause Overlay
                      Center(
                        child: GestureDetector(
                          onTap: _togglePlay,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: NGColors.textPrimary,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tools Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: NGColors.surface,
                    border: Border(
                      top: BorderSide(
                        color: NGColors.divider,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildToolButton(
                        icon: Icons.cut,
                        label: 'Trim',
                        isActive: true,
                        onTap: () {},
                      ),
                      _buildToolButton(
                        icon: Icons.emoji_emotions,
                        label: 'Emoji',
                        isActive: false,
                        onTap: () {
                          // Will implement later
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Emoji feature coming soon'),
                            ),
                          );
                        },
                      ),
                      _buildToolButton(
                        icon: Icons.text_fields,
                        label: 'Text',
                        isActive: false,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Text overlay coming soon'),
                            ),
                          );
                        },
                      ),
                      _buildToolButton(
                        icon: Icons.filter,
                        label: 'Filter',
                        isActive: false,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Filters coming soon'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Trimmer Section
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: NGColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'Trim Video',
                            style: TextStyle(
                              color: NGColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          if (_trimmedFile != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: NGColors.success.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: NGColors.success.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                'Trimmed',
                                style: TextStyle(
                                  color: NGColors.success,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TrimmerView(
                        trimmer: _trimmer,
                        startValue: _startValue,
                        endValue: _endValue,
                        onStartValueChanged: (value) {
                          setState(() => _startValue = value);
                        },
                        onEndValueChanged: (value) {
                          setState(() => _endValue = value);
                        },
                        viewerHeight: 60,
                        viewerWidth: MediaQuery.of(context).size.width - 40,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _startValue = 0.0;
                                  _endValue = 1.0;
                                  _trimmedFile = null;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: NGColors.divider),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Reset',
                                style: TextStyle(
                                  color: NGColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isTrimming ? null : _trimVideo,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: NGColors.accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _isTrimming
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _trimmedFile != null
                                          ? 'Retrim'
                                          : 'Apply Trim',
                                      style: TextStyle(
                                        color: NGColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? NGColors.accent.withOpacity(0.15) : NGColors.surfaceLight,
              shape: BoxShape.circle,
              border: isActive
                  ? Border.all(color: NGColors.accent)
                  : null,
            ),
            child: Icon(
              icon,
              color: isActive ? NGColors.accent : NGColors.textMuted,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? NGColors.textPrimary : NGColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

// Helper TrimmerView widget
class TrimmerView extends StatelessWidget {
  final Trimmer trimmer;
  final double startValue;
  final double endValue;
  final Function(double) onStartValueChanged;
  final Function(double) onEndValueChanged;
  final double viewerHeight;
  final double viewerWidth;

  const TrimmerView({
    super.key,
    required this.trimmer,
    required this.startValue,
    required this.endValue,
    required this.onStartValueChanged,
    required this.onEndValueChanged,
    required this.viewerHeight,
    required this.viewerWidth,
  });

  @override
  Widget build(BuildContext context) {
    return TrimEditor(
      trimmer: trimmer,
      viewerHeight: viewerHeight,
      viewerWidth: viewerWidth,
      startValue: startValue,
      endValue: endValue,
      onStartValueChanged: onStartValueChanged,
      onEndValueChanged: onEndValueChanged,
    );
  }
}
