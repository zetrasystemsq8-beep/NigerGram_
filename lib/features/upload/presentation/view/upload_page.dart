import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_compress/video_compress.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  File? _videoFile;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String _selectedCategory = 'For You';

  final List<String> _categories = [
    'For You', 'Comedy', 'Music', 'Dance',
    'Skit', 'News', 'Sports', 'Fashion', 'Food'
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(ImageSource source) async {
    await HapticFeedback.mediumImpact();
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 2),
    );
    if (picked != null) {
      setState(() => _videoFile = File(picked.path));
    }
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

  Future<void> _uploadVideo() async {
    if (_videoFile == null) return;
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
      
      setState(() => _uploadProgress = 0.1);

      // 1. Compress raw video payload
      final mediaInfo = await VideoCompress.compressVideo(
        _videoFile!.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
      );

      // 2. Generate thumbnail preview image
      final thumbnailFile = await VideoCompress.getFileThumbnail(
        _videoFile!.path,
        quality: 50,
        position: -1,
      );

      if (mediaInfo == null || mediaInfo.file == null || thumbnailFile == null) {
        throw Exception('Optimization pipeline failed to process media assets.');
      }

      setState(() => _uploadProgress = 0.3);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final videoFileName = '${user.uid}_$timestamp.mp4';
      final thumbFileName = '${user.uid}_$timestamp.jpg';
      final supabase = Supabase.instance.client;

      // 3. Upload Compressed Video
      await supabase.storage.from('videos').upload(
            videoFileName,
            mediaInfo.file!,
            fileOptions: const FileOptions(contentType: 'video/mp4'),
          );

      setState(() => _uploadProgress = 0.6);

      // 4. Upload Thumbnail Image
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

      // 5. Commit structured payload to Firestore
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
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
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
        title: const Text(
          'Create Post',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5),
        ),
        centerTitle: true,
      ),
      body: _isUploading ? _buildUploadingScreen() : _buildEditorUI(),
    );
  }

  Widget _buildEditorUI() {
    return Stack(
      children: [
        Positioned.fill(
          child: _videoFile != null
              ? Container(
                  color: Colors.grey.shade900,
                  child: const Center(
                    child: Icon(Icons.play_circle_filled_rounded, color: Colors.white24, size: 80),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.grey.shade900, Colors.black],
                    ),
                  ),
                ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.95)],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_videoFile == null) _buildEmptyPicker() else _buildPostForm(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPicker() {
    return Column(
      children: [
        const Text(
          "Share your vibe with Nigeria 🇳🇬",
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            Expanded(
              child: _actionButton(
                icon: Icons.video_library_rounded,
                label: "Gallery",
                onTap: () => _pickVideo(ImageSource.gallery),
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _actionButton(
                icon: Icons.videocam_rounded,
                label: "Camera",
                onTap: () => _pickVideo(ImageSource.camera),
                color: const Color(0xFFFF0050),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionButton({required IconData icon, required String label, required VoidCallback onTap, required Color color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: color == Colors.white.withOpacity(0.1) ? Border.all(color: Colors.white10) : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPostForm() {
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
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: TextField(
            controller: _descriptionController,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            maxLines: 2,
            maxLength: 150,
            decoration: const InputDecoration(
              hintText: 'Add a caption...',
              hintStyle: TextStyle(color: Colors.white38),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
              counterText: "",
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: TextField(
            controller: _tagController,
            style: const TextStyle(color: Color(0xFFFF0050), fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: '#tags #naija #viral',
              hintStyle: TextStyle(color: Colors.white38, fontWeight: FontWeight.normal),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: Icon(Icons.tag_rounded, color: Colors.white38, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton(
            onPressed: _uploadVideo,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF0050),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
            child: const Text('Share to NigerGram', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _videoFile = null),
          child: const Text('Retake Video', style: TextStyle(color: Colors.white54, fontSize: 13)),
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
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: _uploadProgress,
                  strokeWidth: 8,
                  color: const Color(0xFFFF0050),
                  backgroundColor: Colors.white10,
                ),
              ),
              Text(
                '${(_uploadProgress * 100).toInt()}%',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 40),
          const Text('Publishing Content...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Optimizing for Naija networks 🇳🇬', style: TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }
}
