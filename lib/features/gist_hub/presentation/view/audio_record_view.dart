// lib/features/gist_hub/presentation/view/audio_record_view.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:path_provider/path_provider.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/gist_hub/data/services/audio_service.dart';
import 'package:nigergram/features/gist_hub/domain/entities/audio_post_entity.dart';

const List<Map<String, dynamic>> _categoryOptions = [
  {'value': AudioCategory.educational, 'label': '📚 Educational'},
  {'value': AudioCategory.idea, 'label': '💡 Idea & Innovation'},
  {'value': AudioCategory.motivation, 'label': '🔥 Motivation'},
  {'value': AudioCategory.story, 'label': '📖 Story'},
  {'value': AudioCategory.original, 'label': '🎙️ Original'},
];

const List<Map<String, dynamic>> _permissionOptions = [
  {'value': AudioPermission.private, 'label': '🔒 Private', 'sub': 'Only you can use this audio'},
  {'value': AudioPermission.approvedUsers, 'label': '👥 Approved Users', 'sub': 'Only people you approve can reuse it'},
  {'value': AudioPermission.public, 'label': '🌍 Public', 'sub': 'Any NigerGram creator can reuse it'},
];

class AudioRecordView extends StatefulWidget {
  const AudioRecordView({super.key});

  @override
  State<AudioRecordView> createState() => _AudioRecordViewState();
}

enum _RecordStage { record, review, trim, details }

class _AudioRecordViewState extends State<AudioRecordView> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _previewPlayer = AudioPlayer();
  final AudioService _service = AudioService();
  final TextEditingController _titleController = TextEditingController();

  _RecordStage _stage = _RecordStage.record;
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isPublishing = false;
  String? _recordedPath;
  int _recordedSeconds = 0;
  Timer? _recordTimer;

  AudioCategory _selectedCategory = AudioCategory.educational;
  AudioPermission _selectedPermission = AudioPermission.private;

  // --- Trim state ---
  PlayerController? _waveController;
  bool _waveReady = false;
  double _trimStartFraction = 0.0;
  double _trimEndFraction = 1.0;
  StreamSubscription<Duration>? _trimPositionSub;
  bool _isTrimPlaying = false;

  static const int _minTrimGapMs = 1000;

  @override
  void dispose() {
    _recordTimer?.cancel();
    _recorder.dispose();
    _previewPlayer.dispose();
    _titleController.dispose();
    _trimPositionSub?.cancel();
    _waveController?.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required to record audio.')),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
      path: path,
    );

    setState(() {
      _isRecording = true;
      _recordedSeconds = 0;
    });

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordedSeconds++);
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    _recordTimer?.cancel();

    if (path == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording failed. Please try again.')),
      );
      setState(() => _isRecording = false);
      return;
    }

    setState(() {
      _isRecording = false;
      _recordedPath = path;
      _stage = _RecordStage.review;
    });
  }

  Future<void> _togglePreview() async {
    if (_recordedPath == null) return;

    if (_isPlaying) {
      await _previewPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _previewPlayer.play(DeviceFileSource(_recordedPath!));
      setState(() => _isPlaying = true);
      _previewPlayer.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
    }
  }

  void _discardAndRerecord() {
    setState(() {
      _recordedPath = null;
      _recordedSeconds = 0;
      _stage = _RecordStage.record;
      _isPlaying = false;
    });
  }

  // --- Trim stage setup ---

  Future<void> _enterTrimStage() async {
    setState(() {
      _stage = _RecordStage.trim;
      _waveReady = false;
      _trimStartFraction = 0.0;
      _trimEndFraction = 1.0;
    });

    final controller = PlayerController();
    try {
      await controller.preparePlayer(
        path: _recordedPath!,
        shouldExtractWaveform: true,
        noOfSamples: 100,
      );
      if (!mounted) return;
      setState(() {
        _waveController = controller;
        _waveReady = true;
      });
    } catch (e) {
      // If waveform extraction fails on this platform/version, fall
      // back to a plain trim UI without a visual waveform — the drag
      // handles still work, just over a flat bar instead of a wave.
      if (!mounted) return;
      setState(() {
        _waveController = null;
        _waveReady = true;
      });
    }
  }

  int get _trimStartMs => (_trimStartFraction * _recordedSeconds * 1000).round();
  int get _trimEndMs => (_trimEndFraction * _recordedSeconds * 1000).round();

  void _onDragStartHandle(double dx, double width) {
    final fraction = (dx / width).clamp(0.0, _trimEndFraction - (_minTrimGapMs / (_recordedSeconds * 1000).clamp(1, double.infinity)));
    setState(() => _trimStartFraction = fraction.clamp(0.0, 1.0));
  }

  void _onDragEndHandle(double dx, double width) {
    final minGapFraction = _recordedSeconds > 0 ? _minTrimGapMs / (_recordedSeconds * 1000) : 0.0;
    final fraction = (dx / width).clamp(_trimStartFraction + minGapFraction, 1.0);
    setState(() => _trimEndFraction = fraction.clamp(0.0, 1.0));
  }

  Future<void> _playTrimmedPreview() async {
    if (_isTrimPlaying) {
      await _previewPlayer.pause();
      _trimPositionSub?.cancel();
      setState(() => _isTrimPlaying = false);
      return;
    }

    await _previewPlayer.play(DeviceFileSource(_recordedPath!));
    await _previewPlayer.seek(Duration(milliseconds: _trimStartMs));
    setState(() => _isTrimPlaying = true);

    _trimPositionSub?.cancel();
    _trimPositionSub = _previewPlayer.onPositionChanged.listen((pos) {
      if (pos.inMilliseconds >= _trimEndMs) {
        _previewPlayer.pause();
        if (mounted) setState(() => _isTrimPlaying = false);
      }
    });
  }

  void _confirmTrim() {
    _trimPositionSub?.cancel();
    _previewPlayer.stop();
    setState(() {
      _isTrimPlaying = false;
      _stage = _RecordStage.details;
    });
  }

  Future<void> _publish() async {
    if (_recordedPath == null) return;
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a title for your audio.')),
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      await _service.createAudioPost(
        audioFile: File(_recordedPath!),
        title: _titleController.text.trim(),
        category: _selectedCategory,
        permission: _selectedPermission,
        durationSeconds: _recordedSeconds,
        trimStartMs: _trimStartMs,
        trimEndMs: _trimEndMs,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not publish: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatMs(int ms) {
    final totalSeconds = (ms / 1000).round();
    return _formatDuration(totalSeconds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NGColors.background,
      appBar: AppBar(
        backgroundColor: NGColors.surface,
        title: const Text('🎙️ New Audio'),
      ),
      body: SafeArea(
        child: switch (_stage) {
          _RecordStage.record => _buildRecordStage(),
          _RecordStage.review => _buildReviewStage(),
          _RecordStage.trim => _buildTrimStage(),
          _RecordStage.details => _buildDetailsStage(),
        },
      ),
    );
  }

  Widget _buildRecordStage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: _isRecording ? Colors.red.withOpacity(0.15) : NGColors.accent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
              size: 64,
              color: _isRecording ? Colors.red : NGColors.accent,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _isRecording ? _formatDuration(_recordedSeconds) : 'Tap to start recording',
            style: TextStyle(
              color: NGColors.textPrimary,
              fontSize: _isRecording ? 32 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              icon: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white),
              label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.red : NGColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.graphic_eq_rounded, size: 72, color: NGColors.accent),
          const SizedBox(height: 20),
          Text(
            'Recorded ${_formatDuration(_recordedSeconds)}',
            style: TextStyle(color: NGColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 32),
          IconButton(
            iconSize: 56,
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              color: NGColors.accent,
            ),
            onPressed: _togglePreview,
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _discardAndRerecord,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Re-record'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await _previewPlayer.stop();
                    if (mounted) setState(() => _isPlaying = false);
                    await _enterTrimStage();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NGColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Trim & Continue', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrimStage() {
    if (!_waveReady) {
      return const Center(child: CircularProgressIndicator(color: NGColors.accent));
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trim your audio', style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            'Drag the handles to select what plays. Nothing outside this range is deleted.',
            style: TextStyle(color: NGColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return SizedBox(
                height: 90,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: NGColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _waveController != null
                            ? AudioFileWaveforms(
                                size: Size(width, 90),
                                playerController: _waveController!,
                                enableSeekGesture: false,
                                waveformType: WaveformType.long,
                                playerWaveStyle: PlayerWaveStyle(
                                  fixedWaveColor: NGColors.textMuted.withOpacity(0.4),
                                  liveWaveColor: NGColors.accent,
                                  spacing: 4,
                                ),
                              )
                            : Center(
                                child: Icon(Icons.graphic_eq_rounded, color: NGColors.textMuted, size: 40),
                              ),
                      ),
                    ),
                    // Dimmed regions outside the selected trim range
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: _trimStartFraction * width,
                      child: Container(color: NGColors.background.withOpacity(0.7)),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: (1 - _trimEndFraction) * width,
                      child: Container(color: NGColors.background.withOpacity(0.7)),
                    ),
                    // Start handle
                    Positioned(
                      left: (_trimStartFraction * width) - 10,
                      top: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (details) => _onDragStartHandle(details.localPosition.dx + (_trimStartFraction * width) - 10, width),
                        child: Container(
                          width: 20,
                          decoration: BoxDecoration(
                            color: NGColors.accent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.drag_indicator_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                    // End handle
                    Positioned(
                      left: (_trimEndFraction * width) - 10,
                      top: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (details) => _onDragEndHandle(details.localPosition.dx + (_trimEndFraction * width) - 10, width),
                        child: Container(
                          width: 20,
                          decoration: BoxDecoration(
                            color: NGColors.accent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.drag_indicator_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatMs(_trimStartMs), style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
              Text(
                'Selected: ${_formatMs(_trimEndMs - _trimStartMs)}',
                style: TextStyle(color: NGColors.accent, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(_formatMs(_trimEndMs), style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: IconButton(
              iconSize: 52,
              icon: Icon(
                _isTrimPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                color: NGColors.accent,
              ),
              onPressed: _playTrimmedPreview,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _confirmTrim,
              style: ElevatedButton.styleFrom(
                backgroundColor: NGColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Confirm Trim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Title', style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            maxLength: 100,
            style: TextStyle(color: NGColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. "How I built my first app"',
              filled: true,
              fillColor: NGColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          Text('Category', style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categoryOptions.map((opt) {
              final selected = opt['value'] == _selectedCategory;
              return ChoiceChip(
                label: Text(opt['label'] as String),
                selected: selected,
                selectedColor: NGColors.accent,
                labelStyle: TextStyle(color: selected ? Colors.white : NGColors.textPrimary),
                onSelected: (_) => setState(() => _selectedCategory = opt['value'] as AudioCategory),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text('Who can reuse this audio?', style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 10),
          ..._permissionOptions.map((opt) {
            final selected = opt['value'] == _selectedPermission;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: NGColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? NGColors.accent : Colors.transparent, width: 1.5),
              ),
              child: RadioListTile<AudioPermission>(
                value: opt['value'] as AudioPermission,
                groupValue: _selectedPermission,
                activeColor: NGColors.accent,
                title: Text(opt['label'] as String, style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text(opt['sub'] as String, style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
                onChanged: (value) => setState(() => _selectedPermission = value!),
              ),
            );
          }),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isPublishing ? null : _publish,
              style: ElevatedButton.styleFrom(
                backgroundColor: NGColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isPublishing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : const Text('🚀 Publish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
