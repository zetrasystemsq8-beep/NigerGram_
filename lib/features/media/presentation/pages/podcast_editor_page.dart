import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:nigergram/features/media/models/video_edit_model.dart';
import 'package:nigergram/core/design_system/colors.dart';

/// Podcast Editor - Specialized editor for innovators to create podcasts
/// Features: Multi-track audio, Voiceover recording, Episode metadata, Auto-captions
class PodcastEditorPage extends StatefulWidget {
  final String? videoPath;
  final VideoEditModel? initialEdit;

  const PodcastEditorPage({
    this.videoPath,
    this.initialEdit,
    super.key,
  });

  @override
  State<PodcastEditorPage> createState() => _PodcastEditorPageState();
}

class _PodcastEditorPageState extends State<PodcastEditorPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late VideoEditModel _podcastModel;

  // Podcast Metadata
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _guestNamesController = TextEditingController();
  bool _autoGenerateCaptions = true;
  String _selectedLanguage = 'English';

  // Audio Tracks for Podcast
  List<AudioTrack> _audioTracks = [];
  int _selectedAudioTrackIndex = -1;

  // Recording State
  bool _isRecording = false;
  double _recordingDuration = 0;

  // Intro/Outro Templates
  final List<Map<String, dynamic>> _templates = [
    {
      'name': 'Tech Startup',
      'intro': 'Welcome to Tech Innovation Hour...',
      'outro': 'Thanks for listening! Follow us on...',
    },
    {
      'name': 'Healthcare',
      'intro': 'Innovation in Healthcare Podcast...',
      'outro': 'Tune in next week for...',
    },
    {
      'name': 'Business',
      'intro': 'The Innovation Chronicles...',
      'outro': 'Subscribe for more episodes...',
    },
  ];

  // Episode Quality Presets
  final List<Map<String, dynamic>> _qualityPresets = [
    {'name': 'Podcast (128kbps)', 'bitrate': 128},
    {'name': 'Standard (192kbps)', 'bitrate': 192},
    {'name': 'High (320kbps)', 'bitrate': 320},
  ];

  String _selectedQuality = 'Standard (192kbps)';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _podcastModel = widget.initialEdit ??
        VideoEditModel(
          videoPath: widget.videoPath ?? '',
          audioTracks: [],
        );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _guestNamesController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Add new audio track (voiceover, guest, music)
  void _addAudioTrack(String label) {
    final newTrack = AudioTrack(
      id: const Uuid().v4(),
      audioPath: 'temp/audio_${DateTime.now().toString()}',
      startTime: 0,
      duration: 0,
      label: label,
      volume: label.contains('Music') ? 0.3 : 1.0,
    );
    setState(() {
      _audioTracks.add(newTrack);
      _podcastModel = _podcastModel.copyWith(audioTracks: _audioTracks);
    });
  }

  // Remove audio track
  void _removeAudioTrack(String trackId) {
    setState(() {
      _audioTracks.removeWhere((track) => track.id == trackId);
      _podcastModel = _podcastModel.copyWith(audioTracks: _audioTracks);
    });
  }

  // Update audio track volume
  void _updateTrackVolume(String trackId, double volume) {
    setState(() {
      for (var track in _audioTracks) {
        if (track.id == trackId) {
          final index = _audioTracks.indexOf(track);
          _audioTracks[index] = track.copyWith(volume: volume);
        }
      }
      _podcastModel = _podcastModel.copyWith(audioTracks: _audioTracks);
    });
  }

  // Mute/Unmute track
  void _toggleMuteTrack(String trackId) {
    setState(() {
      for (var track in _audioTracks) {
        if (track.id == trackId) {
          final index = _audioTracks.indexOf(track);
          _audioTracks[index] = track.copyWith(isMuted: !track.isMuted);
        }
      }
      _podcastModel = _podcastModel.copyWith(audioTracks: _audioTracks);
    });
  }

  // Add subtitle/caption
  void _addSubtitle() {
    showDialog(
      context: context,
      builder: (ctx) {
        final textController = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A24),
          title: const Text(
            'Add Caption',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: textController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter caption text...',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              filled: true,
              fillColor: Colors.grey.shade800,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                if (textController.text.isNotEmpty) {
                  final newSubtitle = Subtitle(
                    id: const Uuid().v4(),
                    text: textController.text,
                    startTime: 0,
                    endTime: 5,
                    language: _selectedLanguage,
                  );
                  setState(() {
                    _podcastModel = _podcastModel.copyWith(
                      subtitles: [..._podcastModel.subtitles, newSubtitle],
                    );
                  });
                  Navigator.pop(ctx);
                }
              },
              child:
                  const Text('Add', style: TextStyle(color: NGColors.accent)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Podcast Editor',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: NGColors.accent),
            onPressed: () => Navigator.pop(context, _podcastModel),
          ),
        ],
      ),
      body: Column(
        children: [
          // INFO BANNER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: NGColors.accent.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(color: NGColors.accent.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info, color: NGColors.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Professional podcast creation for innovators',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // TABS
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.info_outline), text: 'Episode Info'),
              Tab(icon: Icon(Icons.multitrack_audio), text: 'Audio Mix'),
              Tab(icon: Icon(Icons.closed_caption), text: 'Captions'),
              Tab(icon: Icon(Icons.settings), text: 'Settings'),
            ],
            labelColor: NGColors.accent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: NGColors.accent,
          ),

          // TAB CONTENT
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEpisodeInfoTab(),
                _buildAudioMixTab(),
                _buildCaptionsTab(),
                _buildSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // EPISODE INFO TAB
  Widget _buildEpisodeInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Episode Information',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          const Text('Episode Title',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g., Innovation in Healthcare 2024',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Description
          const Text('Episode Description',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe your innovation and key points...',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Guest Names
          const Text('Guest Names (optional)',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _guestNamesController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Separate with commas: John Doe, Jane Smith',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
                prefixIcon: const Icon(Icons.people, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Templates
          const Text('Quick Start Templates',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._templates.map((template) {
            return GestureDetector(
              onTap: () {
                _titleController.text = template['name'];
                _descriptionController.text = template['intro'];
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Template "${template['name']}" applied'),
                    duration: const Duration(milliseconds: 500),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_outline,
                        color: NGColors.accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Click to apply',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.grey, size: 16),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // AUDIO MIX TAB
  Widget _buildAudioMixTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Audio Tracks',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),

          // Add Track Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () => _addAudioTrack('Voiceover'),
                icon: const Icon(Icons.mic),
                label: const Text('Voiceover'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _addAudioTrack('Guest'),
                icon: const Icon(Icons.person),
                label: const Text('Guest'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () => _addAudioTrack('Background Music'),
                icon: const Icon(Icons.music_note),
                label: const Text('Music'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _addAudioTrack('Sound Effects'),
                icon: const Icon(Icons.speaker),
                label: const Text('SFX'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Audio Tracks List
          if (_audioTracks.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.no_sound, color: Colors.grey, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'No audio tracks yet\nAdd voiceovers, music & more',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._audioTracks.asMap().entries.map((entry) {
              final index = entry.key;
              final track = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Track Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getTrackIcon(track.label),
                              color: NGColors.accent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.label ?? 'Audio Track',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Track ${index + 1}',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                track.isMuted
                                    ? Icons.volume_off
                                    : Icons.volume_up,
                                color: Colors.white,
                                size: 18,
                              ),
                              onPressed: () => _toggleMuteTrack(track.id),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red, size: 18),
                              onPressed: () => _removeAudioTrack(track.id),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Volume Slider
                    Row(
                      children: [
                        Text(
                          'Vol: ${(track.volume * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: track.volume,
                            min: 0,
                            max: 1,
                            activeColor: NGColors.accent,
                            inactiveColor: Colors.grey.shade700,
                            onChanged: (value) =>
                                _updateTrackVolume(track.id, value),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  // CAPTIONS TAB
  Widget _buildCaptionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Captions & Subtitles',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),

          // Auto-Generate Option
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade900.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade800),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _autoGenerateCaptions,
                  activeColor: Colors.blue,
                  onChanged: (value) {
                    setState(() => _autoGenerateCaptions = value ?? false);
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🤖 Auto-Generate Captions',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'AI-powered speech-to-text (Powered by Google Speech-to-Text)',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Language Selection
          const Text('Caption Language',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _selectedLanguage,
              isExpanded: true,
              dropdownColor: Colors.grey.shade800,
              underline: Container(),
              items: ['English', 'Spanish', 'French', 'Portuguese', 'German']
                  .map((lang) => DropdownMenuItem(
                        value: lang,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(lang,
                              style:
                                  const TextStyle(color: Colors.white)),
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedLanguage = value ?? 'English');
              },
            ),
          ),
          const SizedBox(height: 20),

          // Manual Captions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Manual Captions',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addSubtitle,
                icon: const Icon(Icons.add),
                label: const Text('Add Caption'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NGColors.accent,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_podcastModel.subtitles.isEmpty)
            Text(
              'No captions added yet',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            )
          else
            ..._podcastModel.subtitles.map((subtitle) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subtitle.text,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${subtitle.startTime.toStringAsFixed(1)}s - ${subtitle.endTime.toStringAsFixed(1)}s',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _podcastModel = _podcastModel.copyWith(
                            subtitles: _podcastModel.subtitles
                                .where((s) => s.id != subtitle.id)
                                .toList(),
                          );
                        });
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  // SETTINGS TAB
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Podcast Settings',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),

          // Audio Quality
          const Text('Audio Quality',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _selectedQuality,
              isExpanded: true,
              dropdownColor: Colors.grey.shade800,
              underline: Container(),
              items: _qualityPresets
                  .map((preset) => DropdownMenuItem(
                        value: preset['name'],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                preset['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Bitrate: ${preset['bitrate']} kbps',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedQuality = value ?? _selectedQuality);
              },
            ),
          ),
          const SizedBox(height: 20),

          // Export Options
          const Text(
            'Export Options',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade900.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade800),
            ),
            child: Row(
              children: [
                const Icon(Icons.download, color: Colors.green, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Export as MP3 or WAV',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Ready to upload to podcast platforms',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Additional Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NGColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: NGColors.accent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '💡 Pro Tips',
                  style: TextStyle(
                    color: NGColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Use multiple audio tracks for better control over each voice\n'
                  '• Add background music at 30-40% volume for better pacing\n'
                  '• Auto-generate captions for accessibility\n'
                  '• Test audio levels before final export',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTrackIcon(String? label) {
    if (label == null) return Icons.audio_file;
    if (label.contains('Voiceover')) return Icons.mic;
    if (label.contains('Guest')) return Icons.person;
    if (label.contains('Music')) return Icons.music_note;
    if (label.contains('Effects')) return Icons.speaker;
    return Icons.audio_file;
  }
}
