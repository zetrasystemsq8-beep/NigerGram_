// lib/features/upload/presentation/view/video_editor_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_trimmer/video_trimmer.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:video_player/video_player.dart';

// ===================== OVERLAY ITEM MODEL =====================
class OverlayItem {
  final String id;
  final String type; // 'emoji' or 'text'
  final String content;
  final double x;
  final double y;
  final double scale;
  final double rotation;
  final Color? textColor;
  final double? fontSize;

  OverlayItem({
    required this.id,
    required this.type,
    required this.content,
    this.x = 0.5,
    this.y = 0.5,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.textColor,
    this.fontSize,
  });

  OverlayItem copyWith({
    String? id,
    String? type,
    String? content,
    double? x,
    double? y,
    double? scale,
    double? rotation,
    Color? textColor,
    double? fontSize,
  }) {
    return OverlayItem(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      textColor: textColor ?? this.textColor,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}

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

  // ===================== OVERLAY STATE =====================
  final List<OverlayItem> _overlays = [];
  String _selectedTool = 'trim'; // 'trim', 'emoji', 'text'
  final TextEditingController _textController = TextEditingController();
  Color _selectedTextColor = Colors.white;
  double _selectedFontSize = 24;

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

  void _addEmoji(String emoji) {
    setState(() {
      _overlays.add(
        OverlayItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'emoji',
          content: emoji,
          x: 0.5,
          y: 0.5,
          scale: 1.0,
        ),
      );
    });
  }

  void _addTextOverlay() {
    if (_textController.text.trim().isEmpty) return;
    setState(() {
      _overlays.add(
        OverlayItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'text',
          content: _textController.text.trim(),
          x: 0.5,
          y: 0.5,
          scale: 1.0,
          textColor: _selectedTextColor,
          fontSize: _selectedFontSize,
        ),
      );
    });
    _textController.clear();
  }

  void _removeOverlay(String id) {
    setState(() {
      _overlays.removeWhere((item) => item.id == id);
    });
  }

  void _updateOverlayPosition(String id, double x, double y) {
    setState(() {
      final index = _overlays.indexWhere((item) => item.id == id);
      if (index != -1) {
        _overlays[index] = _overlays[index].copyWith(x: x, y: y);
      }
    });
  }

  void _updateOverlayScale(String id, double scale) {
    setState(() {
      final index = _overlays.indexWhere((item) => item.id == id);
      if (index != -1) {
        _overlays[index] = _overlays[index].copyWith(scale: scale);
      }
    });
  }

  void _saveAndReturn() {
    final fileToReturn = _trimmedFile ?? widget.videoFile;
    Navigator.pop(context, fileToReturn);
  }

  // ===================== EMOJI PICKER BOTTOM SHEET =====================
  void _showEmojiPicker() {
    final List<String> emojis = [
      '😂', '😍', '🔥', '💯', '🥺', '😭', '❤️', '🙏',
      '🇳🇬', '🎉', '✨', '💪', '👀', '🤣', '😱', '🥰',
      '😎', '🤔', '💀', '👏', '🙌', '💖', '😘', '🥳',
      '😊', '🤗', '😇', '🤩', '😤', '😒', '💔', '😡',
      '👊', '🤝', '👍', '👎', '✌️', '🤞', '👌', '💯',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: NGColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Emoji',
              style: TextStyle(
                color: NGColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  childAspectRatio: 1,
                ),
                itemCount: emojis.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      _addEmoji(emojis[index]);
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: NGColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          emojis[index],
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== TEXT OVERLAY BOTTOM SHEET =====================
  void _showTextOverlaySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NGColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Text Overlay',
                style: TextStyle(
                  color: NGColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _textController,
                style: TextStyle(color: NGColors.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Type your text...',
                  hintStyle: TextStyle(color: NGColors.textMuted),
                  filled: true,
                  fillColor: NGColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              // Text Color Picker
              Text(
                'Color',
                style: TextStyle(color: NGColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildColorChip(Colors.white),
                    _buildColorChip(Colors.black),
                    _buildColorChip(Colors.red),
                    _buildColorChip(Colors.green),
                    _buildColorChip(Colors.blue),
                    _buildColorChip(Colors.yellow),
                    _buildColorChip(Colors.purple),
                    _buildColorChip(Colors.orange),
                    _buildColorChip(Colors.pink),
                    _buildColorChip(NGColors.accent),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Font Size Slider
              Text(
                'Size: ${_selectedFontSize.toInt()}',
                style: TextStyle(color: NGColors.textSecondary, fontSize: 14),
              ),
              Slider(
                value: _selectedFontSize,
                min: 14,
                max: 60,
                activeColor: NGColors.accent,
                inactiveColor: NGColors.divider,
                onChanged: (v) => setState(() => _selectedFontSize = v),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _addTextOverlay();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NGColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Add Text',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorChip(Color color) {
    return GestureDetector(
      onTap: () => setState(() => _selectedTextColor = color),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: _selectedTextColor == color
                ? NGColors.accent
                : NGColors.divider,
            width: _selectedTextColor == color ? 3 : 1,
          ),
        ),
      ),
    );
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
            onPressed: _trimmedFile != null || _overlays.isNotEmpty
                ? _saveAndReturn
                : null,
            child: Text(
              'Apply',
              style: TextStyle(
                color: _trimmedFile != null || _overlays.isNotEmpty
                    ? NGColors.accent
                    : NGColors.textMuted,
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
                // Video Preview with Overlays
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
                      // ===================== OVERLAY RENDERER =====================
                      ..._overlays.map((item) {
                        return Positioned(
                          left: item.x * MediaQuery.of(context).size.width - 50,
                          top: item.y * (MediaQuery.of(context).size.height * 0.6) - 50,
                          child: GestureDetector(
                            onTap: () => _removeOverlay(item.id),
                            onPanUpdate: (details) {
                              _updateOverlayPosition(
                                item.id,
                                (item.x + details.delta.dx / MediaQuery.of(context).size.width)
                                    .clamp(0.0, 1.0),
                                (item.y + details.delta.dy / (MediaQuery.of(context).size.height * 0.6))
                                    .clamp(0.0, 1.0),
                              );
                            },
                            onScaleUpdate: (details) {
                              _updateOverlayScale(
                                item.id,
                                (item.scale * details.scale).clamp(0.5, 3.0),
                              );
                            },
                            child: Transform.scale(
                              scale: item.scale,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: item.type == 'emoji'
                                    ? Text(
                                        item.content,
                                        style: const TextStyle(fontSize: 40),
                                      )
                                    : Text(
                                        item.content,
                                        style: TextStyle(
                                          color: item.textColor ?? Colors.white,
                                          fontSize: item.fontSize ?? 24,
                                          fontWeight: FontWeight.bold,
                                          shadows: const [
                                            Shadow(
                                              color: Colors.black87,
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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
                      // Overlay count badge
                      if (_overlays.isNotEmpty)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: NGColors.accent.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_overlays.length} overlays',
                              style: TextStyle(
                                color: NGColors.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
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
                        isActive: _selectedTool == 'trim',
                        onTap: () => setState(() => _selectedTool = 'trim'),
                      ),
                      _buildToolButton(
                        icon: Icons.emoji_emotions,
                        label: 'Emoji',
                        isActive: _selectedTool == 'emoji',
                        onTap: () {
                          setState(() => _selectedTool = 'emoji');
                          _showEmojiPicker();
                        },
                      ),
                      _buildToolButton(
                        icon: Icons.text_fields,
                        label: 'Text',
                        isActive: _selectedTool == 'text',
                        onTap: () {
                          setState(() => _selectedTool = 'text');
                          _showTextOverlaySheet();
                        },
                      ),
                      _buildToolButton(
                        icon: Icons.delete_outline,
                        label: 'Clear All',
                        isActive: false,
                        onTap: () {
                          if (_overlays.isNotEmpty) {
                            setState(() => _overlays.clear());
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // Trim Section (only when trim is active)
                if (_selectedTool == 'trim')
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
                        TrimEditor(
                          trimmer: _trimmer,
                          viewerHeight: 60,
                          viewerWidth: MediaQuery.of(context).size.width - 40,
                          startValue: _startValue,
                          endValue: _endValue,
                          onStartValueChanged: (value) {
                            setState(() => _startValue = value);
                          },
                          onEndValueChanged: (value) {
                            setState(() => _endValue = value);
                          },
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
    _textController.dispose();
    super.dispose();
  }
}

// ===================== TRIM EDITOR WIDGET =====================
class TrimEditor extends StatelessWidget {
  final Trimmer trimmer;
  final double startValue;
  final double endValue;
  final Function(double) onStartValueChanged;
  final Function(double) onEndValueChanged;
  final double viewerHeight;
  final double viewerWidth;

  const TrimEditor({
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
    return Container(
      height: viewerHeight + 40,
      child: Row(
        children: [
          Expanded(
            child: TrimViewer(
              trimmer: trimmer,
              startValue: startValue,
              endValue: endValue,
              viewerHeight: viewerHeight,
              viewerWidth: viewerWidth,
              onStartValueChanged: onStartValueChanged,
              onEndValueChanged: onEndValueChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class TrimViewer extends StatefulWidget {
  final Trimmer trimmer;
  final double startValue;
  final double endValue;
  final Function(double) onStartValueChanged;
  final Function(double) onEndValueChanged;
  final double viewerHeight;
  final double viewerWidth;

  const TrimViewer({
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
  State<TrimViewer> createState() => _TrimViewerState();
}

class _TrimViewerState extends State<TrimViewer> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.viewerHeight + 40,
      child: Stack(
        children: [
          // Video preview frames
          Container(
            height: widget.viewerHeight,
            decoration: BoxDecoration(
              color: NGColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: widget.trimmer.videoPlayerController != null &&
                    widget.trimmer.videoPlayerController!.value.isInitialized
                ? TrimVideoWidget(
                    trimmer: widget.trimmer,
                    startValue: widget.startValue,
                    endValue: widget.endValue,
                    onStartValueChanged: widget.onStartValueChanged,
                    onEndValueChanged: widget.onEndValueChanged,
                    viewerHeight: widget.viewerHeight,
                    viewerWidth: widget.viewerWidth,
                  )
                : Center(
                    child: CircularProgressIndicator(
                      color: NGColors.accent,
                      strokeWidth: 2,
                    ),
                  ),
          ),
          // Left handle
          Positioned(
            left: widget.startValue * widget.viewerWidth - 10,
            top: 0,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                final newValue = (widget.startValue + details.delta.dx / widget.viewerWidth)
                    .clamp(0.0, widget.endValue - 0.02);
                widget.onStartValueChanged(newValue);
              },
              child: Container(
                width: 20,
                height: widget.viewerHeight,
                decoration: BoxDecoration(
                  color: NGColors.accent.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.drag_handle,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
          // Right handle
          Positioned(
            left: widget.endValue * widget.viewerWidth - 10,
            top: 0,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                final newValue = (widget.endValue + details.delta.dx / widget.viewerWidth)
                    .clamp(widget.startValue + 0.02, 1.0);
                widget.onEndValueChanged(newValue);
              },
              child: Container(
                width: 20,
                height: widget.viewerHeight,
                decoration: BoxDecoration(
                  color: NGColors.accent.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.drag_handle,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
          // Trimmed region highlight
          Positioned(
            left: widget.startValue * widget.viewerWidth,
            top: 0,
            width: (widget.endValue - widget.startValue) * widget.viewerWidth,
            height: widget.viewerHeight,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: NGColors.accent,
                  width: 2,
                ),
                color: NGColors.accent.withOpacity(0.05),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TrimVideoWidget extends StatelessWidget {
  final Trimmer trimmer;
  final double startValue;
  final double endValue;
  final Function(double) onStartValueChanged;
  final Function(double) onEndValueChanged;
  final double viewerHeight;
  final double viewerWidth;

  const TrimVideoWidget({
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: NGColors.surfaceLight,
        child: Center(
          child: AspectRatio(
            aspectRatio: 2,
            child: VideoPlayer(trimmer.videoPlayerController!),
          ),
        ),
      ),
    );
  }
}
