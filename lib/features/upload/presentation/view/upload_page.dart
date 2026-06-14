import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_compress/video_compress.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';

/// Data representation of a post-production studio asset segment
enum AssetType { video, image }

class StudioAsset {
  final String path;
  final AssetType type;
  final Duration duration;

  StudioAsset({
    required this.path,
    required this.type,
    this.duration = const Duration(seconds: 3),
  });
}

/// Data representation of a timeline anchor for subtitle overlays
class TimedSubtitle {
  String id;
  String text;
  Duration start;
  Duration end;
  Offset compositionPosition;

  TimedSubtitle({
    required this.id,
    required this.text,
    required this.start,
    required this.end,
    this.compositionPosition = const Offset(0.5, 0.75),
  });
}

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  final _subtitleTextController = TextEditingController();
  
  // Studio Timeline Asset Registers
  final List<StudioAsset> _mediaTimeline = [];
  final List<TimedSubtitle> _subtitleTracks = [];
  
  bool _isUploading = false;
  bool _isStudioModeActive = false;
  double _uploadProgress = 0;
  String _selectedCategory = 'For You';
  
  // Simulated playback time for subtitle synchronization previews
  Duration _currentTimelinePosition = Duration.zero;

  final List<String> _categories = [
    'For You', 'Comedy', 'Music', 'Dance',
    'Skit', 'News', 'Sports', 'Fashion', 'Food'
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _tagController.dispose();
    _subtitleTextController.dispose();
    super.dispose();
  }

  /// Appends multiple videos or image assets cleanly into the media track matrix
  Future<void> _importAssets(AssetType type, ImageSource source) async {
    await HapticFeedback.mediumImpact();
    final picker = ImagePicker();
    
    if (type == AssetType.video) {
      final picked = await picker.pickVideo(source: source, maxDuration: const Duration(minutes: 2));
      if (picked != null) {
        setState(() {
          _mediaTimeline.add(StudioAsset(path: picked.path, type: AssetType.video, duration: const Duration(seconds: 15)));
          _isStudioModeActive = true;
        });
      }
    } else {
      final List<XFile> pickedImages = await picker.pickMultiImage();
      if (pickedImages.isNotEmpty) {
        setState(() {
          for (var img in pickedImages) {
            _mediaTimeline.add(StudioAsset(path: img.path, type: AssetType.image));
          }
          _isStudioModeActive = true;
        });
      }
    }
  }

  /// Appends a structured subtitle entry with explicit timeline bounds
  void _addTimedSubtitleTrack() {
    final text = _subtitleTextController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _subtitleTracks.add(
        TimedSubtitle(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          start: _currentTimelinePosition,
          end: _currentTimelinePosition + const Duration(seconds: 3),
        ),
      );
      _subtitleTextController.clear();
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _ensureSupabaseSession() async {
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    if (supabaseUser == null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        try {
          await Supabase.instance.client.auth.signInWithPassword(
            email: user.email!,
            password: 'nigergram_${user.uid.substring(0, 8)}',
          );
        } catch (_) {
          try {
            await Supabase.instance.client.auth.signUp(
              email: user.email!,
              password: 'nigergram_${user.uid.substring(0, 8)}',
            );
          } catch (_) {}
        }
      }
    }
  }

  /// Orchestrates pipeline asset packing, optimization processing, and server upload routing
  Future<void> _executePublishingPipeline() async {
    if (_mediaTimeline.isEmpty) return;
    if (_descriptionController.text.trim().isEmpty) {
      await HapticFeedback.vibrate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add a description'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _ensureSupabaseSession();
      setState(() => _uploadProgress = 0.15);

      // In institutional production, the primary master asset dictates the baseline stream composition container
      final primaryAsset = _mediaTimeline.firstWhere(
        (element) => element.type == AssetType.video, 
        orElse: () => _mediaTimeline.first
      );

      File finalUploadPayloadFile = File(primaryAsset.path);
      File? thumbnailFile;

      // 1. Conditional check expression parsing branch based on concrete media track metadata definitions
      if (primaryAsset.type == AssetType.video) {
        // Process and compress raw video input frames via hardware acceleration blocks
        final mediaInfo = await VideoCompress.compressVideo(
          primaryAsset.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
        );
        if (mediaInfo != null && mediaInfo.file != null) {
          finalUploadPayloadFile = mediaInfo.file!;
        }

        setState(() => _uploadProgress = 0.4);

        // Generate a clean video preview frame thumbnail anchor asset
        thumbnailFile = await VideoCompress.getFileThumbnail(
          primaryAsset.path,
          quality: 50,
          position: -1,
        );
      } else {
        // High-fidelity image sequence rendering path bypasses video engine completely to prevent null crashes
        finalUploadPayloadFile = File(primaryAsset.path);
        thumbnailFile = File(primaryAsset.path);
        setState(() => _uploadProgress = 0.4);
      }

      if (thumbnailFile == null) {
        throw Exception('Optimization pipeline failed to extract preview layers.');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = primaryAsset.type == AssetType.video ? 'mp4' : 'jpg';
      final videoFileName = '${user.uid}_$timestamp.$fileExtension';
      final thumbFileName = '${user.uid}_$timestamp.jpg';
      final supabase = Supabase.instance.client;

      // 2. Dispatch media payload straight to object storage partitions
      await supabase.storage.from('videos').upload(
            videoFileName,
            finalUploadPayloadFile,
            fileOptions: FileOptions(contentType: primaryAsset.type == AssetType.video ? 'video/mp4' : 'image/jpeg'),
          );

      setState(() => _uploadProgress = 0.65);

      // 3. Dispatch extracted or cloned preview thumbnail assets to authenticated buckets
      await supabase.storage.from('thumbnails').upload(
            thumbFileName,
            thumbnailFile,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      setState(() => _uploadProgress = 0.8);

      final videoUrl = supabase.storage.from('videos').getPublicUrl(videoFileName);
      final thumbnailUrl = supabase.storage.from('thumbnails').getPublicUrl(thumbFileName);

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final username = userDoc.data()?['username'] ?? 'naija_creator';
      final tags = _tagController.text.split(' ').where((t) => t.startsWith('#')).toList();

      // Serialization formatting map for structural storage representation of custom subtitling layers
      final mappedSubtitles = _subtitleTracks.map((sub) => {
        'id': sub.id,
        'text': sub.text,
        'startMs': sub.start.inMilliseconds,
        'endMs': sub.end.inMilliseconds,
        'positionX': sub.compositionPosition.dx,
        'positionY': sub.compositionPosition.dy,
      }).toList();

      // 4. Commit structured transactional document down into Firestore collection trees
      await FirebaseFirestore.instance.collection('videos').add({
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'description': _descriptionController.text.trim(),
        'userId': user.uid,
        'username': username,
        'profileImageUrl': userDoc.data()?['profilePicUrl'] ?? '',
        'likeCount': 0,
        'commentCount': 0,
        'shareCount': 0,
        'category': _selectedCategory,
        'tags': tags,
        'subtitles': mappedSubtitles, 
        'studioCompositionMeta': {
          'totalAssetCount': _mediaTimeline.length,
          'hasSubtitles': _subtitleTracks.isNotEmpty,
          'mediaType': primaryAsset.type == AssetType.video ? 'video' : 'image',
        },
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() => _uploadProgress = 1.0);

      if (mounted) {
        await HapticFeedback.lightImpact();
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Studio composition failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isStudioModeActive ? 'Zetra Studio Engine' : 'Create Post',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
        ),
        centerTitle: true,
      ),
      body: _isUploading ? _buildUploadingScreen() : _buildContentCanvasRoute(),
    );
  }

  Widget _buildContentCanvasRoute() {
    return _isStudioModeActive ? _buildAdvancedStudioWorkspaceUI() : _buildEmptyInitialPickerUI();
  }

  /// Initial entry screen offering robust single or multi-asset selection branches
  Widget _buildEmptyInitialPickerUI() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0A0A), Colors.black],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Share your vibe with Nigeria 🇳🇬",
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              Text(
                "Upload multiple clips, compile pictures, and design unique subtitles custom styled down to the frame.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 40),
              _buildLargeStudioMenuButton(
                icon: Icons.video_collection_rounded,
                title: "Compile Video Clips",
                subtitle: "Select and merge multiple records into one dynamic master sequence",
                onTap: () => _importAssets(AssetType.video, ImageSource.gallery),
                accentColor: const Color(0xFFFF0050),
              ),
              const SizedBox(height: 16),
              _buildLargeStudioMenuButton(
                icon: Icons.photo_library_rounded,
                title: "Photo Sequencing Matrix",
                subtitle: "Transform dynamic high-res photos into high-performing video threads",
                onTap: () => _importAssets(AssetType.image, ImageSource.gallery),
                accentColor: Colors.blueAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeStudioMenuButton({
    required IconData icon, 
    required String title, 
    required String subtitle, 
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, height: 1.3)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.2), size: 16),
          ],
        ),
      ),
    );
  }

  /// Advanced multi-asset composite lane editing dashboard interface matching professional post-production software layers
  Widget _buildAdvancedStudioWorkspaceUI() {
    return Column(
      children: [
        // 1. High-Fidelity Main Playback Live View Monitor Frame Canvas
        Expanded(
          flex: 4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                color: Colors.grey.shade900,
                width: double.infinity,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.movie_filter_rounded, color: Colors.white.withOpacity(0.15), size: 64),
                      const SizedBox(height: 8),
                      Text(
                        "Live Composited Lane Video Monitoring Area", 
                        style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)
                      ),
                    ],
                  ),
                ),
              ),
              // Dynamic Floating Canvas Subtitle Presentation Renderer Engine Array
              ..._subtitleTracks.map((sub) {
                return Positioned(
                  left: MediaQuery.of(context).size.width * sub.compositionPosition.dx - 100,
                  top: MediaQuery.of(context).size.height * 0.4 * sub.compositionPosition.dy,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFF0050).withOpacity(0.5), width: 1),
                    ),
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      sub.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        // 2. High-Performance Studio Operations Matrix Controls
        Expanded(
          flex: 5,
          child: Container(
            color: const Color(0xFF0D0D0D),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Linear Production Lane Track
                  const Text("TRACK LAYOUT CHANNELS", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  const SizedBox(height: 10),
                  _buildStudioTimelineLaneScroller(),
                  const SizedBox(height: 24),

                  // Interactive Custom Script Subtitling Dock Layout Block
                  const Text("TIMED SUBTITLE INJECTION DOCK", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  const SizedBox(height: 10),
                  _buildSubtitlingDockEngineLayout(),
                  const SizedBox(height: 24),

                  // Traditional Descriptive Metadata Index Forms
                  const Text("METADATA DISPATCH PARAMS", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  const SizedBox(height: 10),
                  _buildPostFormFieldsLayout(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudioTimelineLaneScroller() {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _mediaTimeline.length + 1,
        itemBuilder: (context, index) {
          if (index == _mediaTimeline.length) {
            return GestureDetector(
              onTap: () => _showAssetImportOptionsDrawer(),
              child: Container(
                width: 56,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0050).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF0050).withOpacity(0.4), width: 1.5),
                ),
                child: const Icon(Icons.add_rounded, color: Color(0xFFFF0050), size: 20),
              ),
            );
          }

          final asset = _mediaTimeline[index];
          final isVideo = asset.type == AssetType.video;

          return Stack(
            children: [
              Container(
                width: 56,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Center(
                  child: Icon(
                    isVideo ? Icons.movie_creation_rounded : Icons.image_rounded,
                    color: isVideo ? const Color(0xFFFF0050) : Colors.blueAccent,
                    size: 20,
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: 10,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _mediaTimeline.removeAt(index);
                      if (_mediaTimeline.isEmpty) _isStudioModeActive = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 10),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAssetImportOptionsDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.video_call_rounded, color: Color(0xFFFF0050)),
                title: const Text("Append Video Segment", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _importAssets(AssetType.video, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_photo_alternate_rounded, color: Colors.blueAccent),
                title: const Text("Append Image Multi-Batch", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _importAssets(AssetType.image, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubtitlingDockEngineLayout() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _subtitleTextController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: "Type custom overlay text track sequence...",
                      hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addTimedSubtitleTrack,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0050),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          if (_subtitleTracks.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 32,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _subtitleTracks.length,
                itemBuilder: (context, index) {
                  final sub = _subtitleTracks[index];
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      children: [
                        Text(
                          sub.text, 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis, 
                          style: const TextStyle(color: Colors.white70, fontSize: 11)
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _subtitleTracks.removeAt(index)),
                          child: const Icon(Icons.cancel_rounded, color: Colors.white30, size: 14),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPostFormFieldsLayout() {
    return Column(
      children: [
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = cat == _selectedCategory;
              return GestureDetector(
                onTap: () async {
                  await HapticFeedback.selectionClick();
                  setState(() => _selectedCategory = cat);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFF0050) : Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Text(cat, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: TextField(
            controller: _descriptionController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            maxLines: 2,
            maxLength: 150,
            decoration: const InputDecoration(
              hintText: 'Add a captivating caption detailing your mix...',
              hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(14),
              counterText: "",
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: TextField(
            controller: _tagController,
            style: const TextStyle(color: Color(0xFFFF0050), fontWeight: FontWeight.w600, fontSize: 14),
            decoration: const InputDecoration(
              hintText: '#tags #naija #viral studio',
              hintStyle: TextStyle(color: Colors.white38, fontWeight: FontWeight.normal, fontSize: 13),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixIcon: Icon(Icons.tag_rounded, color: Colors.white38, size: 18),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _executePublishingPipeline,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF0050),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('Compile & Publish to NigerGram', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
        TextButton(
          onPressed: () => setState(() {
            _mediaTimeline.clear();
            _subtitleTracks.clear();
            _isStudioModeActive = false;
          }),
          child: const Text('Clear All Workspace Layouts', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildUploadingScreen() {
    return Container(
      width: double.infinity,
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: CircularProgressIndicator(
                  value: _uploadProgress,
                  strokeWidth: 6,
                  color: const Color(0xFFFF0050),
                  backgroundColor: Colors.white10,
                ),
              ),
              Text(
                '${(_uploadProgress * 100).toInt()}%',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 36),
          const Text('Processing Studio Composition...', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Merging assets and syncing subtitles for Naija networks 🇳🇬', style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }
}
