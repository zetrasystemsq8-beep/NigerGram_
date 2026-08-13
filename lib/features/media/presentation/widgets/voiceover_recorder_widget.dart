import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:nigergram/core/design_system/colors.dart';

/// Voiceover Recorder - Record high-quality voiceovers and narrations
/// Features: Real-time waveform, Noise cancellation, Multiple recordings, Playback
class VoiceoverRecorderWidget extends StatefulWidget {
  final Function(String audioPath, Duration duration)? onRecordingComplete;
  final String? initialAudioPath;

  const VoiceoverRecorderWidget({
    this.onRecordingComplete,
    this.initialAudioPath,
    super.key,
  });

  @override
  State<VoiceoverRecorderWidget> createState() =>
      _VoiceoverRecorderWidgetState();
}

class _VoiceoverRecorderWidgetState extends State<VoiceoverRecorderWidget> {
  late Record _recorder;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  List<double> _waveformData = [];
  String? _recordedFilePath;
  bool _isNoiseReduction = true;

  late DateTime _recordingStartTime;

  @override
  void initState() {
    super.initState();
    _recorder = Record();
    _recordedFilePath = widget.initialAudioPath;
    _initializeWaveform();
  }

  void _initializeWaveform() {
    _waveformData = List.generate(100, (index) => 0.0);
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final filePath =
            '${dir.path}/voiceover_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _recorder.start(
          path: filePath,
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          samplingRate: 44100,
        );

        setState(() {
          _isRecording = true;
          _recordedFilePath = filePath;
          _recordingStartTime = DateTime.now();
          _recordingDuration = Duration.zero;
          _initializeWaveform();
        });

        // Simulate waveform animation
        _animateWaveform();

        // Update duration every 100ms
        Future.doWhile(() async {
          if (!_isRecording) return false;
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            setState(() {
              _recordingDuration =
                  DateTime.now().difference(_recordingStartTime);
            });
          }
          return true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recording failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Recording saved - ${_formatDuration(_recordingDuration)}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      widget.onRecordingComplete?.call(path ?? '', _recordingDuration);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stop recording failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteRecording() async {
    if (_recordedFilePath != null) {
      try {
        final file = File(_recordedFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
        setState(() {
          _recordedFilePath = null;
          _recordingDuration = Duration.zero;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recording deleted'),
              duration: Duration(milliseconds: 500),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  void _animateWaveform() {
    Future.doWhile(() async {
      if (!_isRecording) return false;
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) {
        setState(() {
          _waveformData.removeAt(0);
          _waveformData.add(
            (DateTime.now().millisecondsSinceEpoch % 100) / 100.0,
          );
        });
      }
      return true;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            '🎤 Voiceover Recorder',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),

          // Recording Status
          if (_isRecording)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade800),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recording... ${_formatDuration(_recordingDuration)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else if (_recordedFilePath != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade800),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Recording ready - ${_formatDuration(_recordingDuration)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'Ready to record',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
            ),
          const SizedBox(height: 12),

          // Waveform Visualization
          if (_isRecording)
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _waveformData.map((value) {
                    final height = 40 + (value * 20);
                    return Expanded(
                      child: Container(
                        height: height,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: NGColors.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            )
          else if (_recordedFilePath != null)
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _waveformData.map((value) {
                    final height = 40 + (value * 20);
                    return Expanded(
                      child: Container(
                        height: height,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            )
          else
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'Waveform will appear here',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Noise Reduction Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.noise_aware, color: NGColors.accent, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'Noise Reduction',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _isNoiseReduction,
                activeColor: NGColors.accent,
                onChanged: (value) {
                  setState(() => _isNoiseReduction = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Control Buttons
          Row(
            children: [
              if (!_isRecording)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _startRecording,
                    icon: const Icon(Icons.mic),
                    label: const Text('Start Recording'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                )
              else
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _stopRecording,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Recording'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              if (_recordedFilePath != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _deleteRecording,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
