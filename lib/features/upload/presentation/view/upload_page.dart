// lib/features/upload/presentation/view/upload_view.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/media/repository/media_repository.dart';
import 'video_editor_screen.dart'; // ✅ IMPORT VIDEO EDITOR

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

  final MediaRepository _mediaRepository = MediaRepository();
  double _qualitySlider = 1.0;

  @override
  void dispose() {
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  // ===================== VIDEO PICKER (WITH EDITOR) =====================
  Future<void> _pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 3),
    );
    if (picked != null) {
      final file = File(picked.path);
      // ✅ Open editor immediately after picking
      final editedFile = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoEditorScreen(videoFile: file),
        ),
      );
      if (editedFile != null) {
        setState(() => _videoFile = editedFile);
      } else {
        // User cancelled editing, keep original
        setState(() => _videoFile = file);
      }
    }
  }

  // ===================== SUPABASE SESSION =====================
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

  // ===================== UPLOAD VIDEO =====================
  Future<void> _uploadVideo() async {
    if (_videoFile == null) return;
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please add a description'),
          backgroundColor: NGColors.error,
        ),
      );
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
      setState(() => _uploadProgress = 0.05);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final videoFileName = '${user.uid}_$timestamp.mp4';
      final supabase = Supabase.instance.client;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Compression started — Media Engine ACTIVE'),
          duration: const Duration(seconds: 2),
          backgroundColor: NGColors.accent,
        ),
      );

      await _mediaRepository.compressUploadAndCleanup(
        _videoFile!,
        videoFileName,
        onCompressProgress: (p) {
          setState(() => _uploadProgress = 0.05 + (p * 0.3));
        },
        onUploadProgress: (p) {
          setState(() => _uploadProgress = 0.35 + (p * 0.65));
        },
        bucketName: 'videos',
        quality: _qualitySlider.toInt(),
      );

      setState(() => _uploadProgress = 0.95);

      final videoUrl = supabase.storage.from('videos').getPublicUrl(videoFileName);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final username = userDoc.data()?['username'] ?? 'naija_creator';
      final profilePic = userDoc.data()?['profilePicUrl'] ?? '';

      final tags = _tagController.text
          .split(' ')
          .where((t) => t.startsWith('#'))
          .toList();

      await FirebaseFirestore.instance.collection('videos').add({
        'videoUrl': videoUrl,
        'description': _descriptionController.text.trim(),
        'userId': user.uid,
        'username': username,
        'profileImageUrl': profilePic,
        'likeCount': 0,
        'commentCount': 0,
        'shareCount': 0,
        'category': _selectedCategory,
        'tags': tags,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() => _uploadProgress = 1.0);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 Video posted to NigerGram!'),
            backgroundColor: NGColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: NGColors.error,
          ),
        );
      }
    }
  }

  // ===================== BUILD =====================
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: NGColors.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.blur_on_rounded, color: NGColors.textPrimary, size: 14),
            ),
            const SizedBox(width: 8),
            Text(
              'ZETRA LAB ENGINE',
              style: TextStyle(
                color: NGColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        centerTitle: true,
      ),
      body: _isUploading
          ? _buildUploadingScreen()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Media Engine Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: NGColors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: NGColors.accent.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      'Media Engine: ACTIVE — Compression & fast upload enabled',
                      style: TextStyle(
                        color: NGColors.textSecondary,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  _buildVideoSelector(),
                  const SizedBox(height: 12),
                  // Compression quality slider
                  Text(
                    'Compression quality',
                    style: TextStyle(
                      color: NGColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Slider(
                    value: _qualitySlider,
                    min: 0,
                    max: 2,
                    divisions: 2,
                    label: _qualityLabel(_qualitySlider.toInt()),
                    activeColor: NGColors.accent,
                    inactiveColor: NGColors.divider,
                    onChanged: (v) => setState(() => _qualitySlider = v),
                  ),
                  const SizedBox(height: 12),
                  _buildDescriptionField(),
                  const SizedBox(height: 16),
                  _buildTagsField(),
                  const SizedBox(height: 16),
                  _buildCategorySelector(),
                  const SizedBox(height: 32),
                  _buildPostButton(),
                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      "make from zetra lab",
                      style: TextStyle(
                        color: NGColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // ===================== UPLOADING SCREEN =====================
  Widget _buildUploadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_upload,
            color: NGColors.accent,
            size: 80,
          ),
          const SizedBox(height: 24),
          Text(
            'Uploading your video...',
            style: TextStyle(
              color: NGColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Optimizing compression assets for Naija 🇳🇬',
            style: TextStyle(
              color: NGColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: NGColors.surfaceLight,
                    color: NGColors.accent,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_uploadProgress * 100).toInt()}%',
                  style: TextStyle(
                    color: NGColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== VIDEO SELECTOR =====================
  Widget _buildVideoSelector() {
    if (_videoFile != null) {
      return Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: NGColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: NGColors.accent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              color: NGColors.success,
              size: 50,
            ),
            const SizedBox(height: 8),
            Text(
              'Video ready to post',
              style: TextStyle(
                color: NGColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _videoFile!.path.split('/').last.length > 30
                  ? '...${_videoFile!.path.split('/').last.substring(_videoFile!.path.split('/').last.length - 30)}'
                  : _videoFile!.path.split('/').last,
              style: TextStyle(
                color: NGColors.textMuted,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => setState(() => _videoFile = null),
                  child: Text(
                    'Change video',
                    style: TextStyle(color: NGColors.textMuted),
                  ),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () async {
                    final editedFile = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoEditorScreen(
                          videoFile: _videoFile!,
                        ),
                      ),
                    );
                    if (editedFile != null) {
                      setState(() => _videoFile = editedFile);
                    }
                  },
                  child: Text(
                    '✂️ Edit',
                    style: TextStyle(color: NGColors.accent),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () => _pickVideo(ImageSource.gallery),
          child: Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: NGColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: NGColors.divider,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.video_library,
                  color: NGColors.accent,
                  size: 50,
                ),
                const SizedBox(height: 12),
                Text(
                  'Pick from Gallery',
                  style: TextStyle(
                    color: NGColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'MP4, MOV up to 3 minutes',
                  style: TextStyle(
                    color: NGColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _pickVideo(ImageSource.camera),
          child: Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              color: NGColors.accent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.videocam,
                  color: NGColors.textPrimary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Record a Video',
                  style: TextStyle(
                    color: NGColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===================== DESCRIPTION FIELD =====================
  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: TextStyle(
            color: NGColors.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: NGColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _descriptionController,
            style: TextStyle(color: NGColors.textPrimary),
            maxLines: 3,
            maxLength: 150,
            decoration: InputDecoration(
              hintText: 'Tell Naija what this video is about...',
              hintStyle: TextStyle(color: NGColors.textMuted),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              counterStyle: TextStyle(color: NGColors.textMuted),
            ),
          ),
        ),
      ],
    );
  }

  // ===================== TAGS FIELD =====================
  Widget _buildTagsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: TextStyle(
            color: NGColors.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: NGColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _tagController,
            style: TextStyle(color: NGColors.textPrimary),
            decoration: InputDecoration(
              hintText: '#naija #comedy #viral',
              hintStyle: TextStyle(color: NGColors.textMuted),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              prefixIcon: Icon(
                Icons.tag,
                color: NGColors.textMuted,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===================== CATEGORY SELECTOR =====================
  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: TextStyle(
            color: NGColors.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = cat == _selectedCategory;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? NGColors.accent : NGColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? NGColors.accent : NGColors.divider,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected ? NGColors.textPrimary : NGColors.textMuted,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ===================== POST BUTTON =====================
  Widget _buildPostButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _videoFile == null ? null : _uploadVideo,
        style: ElevatedButton.styleFrom(
          backgroundColor: NGColors.accent,
          disabledBackgroundColor: NGColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          'Post to NigerGram 🇳🇬',
          style: TextStyle(
            color: NGColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ===================== QUALITY LABEL =====================
  String _qualityLabel(int q) {
    switch (q) {
      case 0:
        return 'Low';
      case 2:
        return 'High';
      default:
        return 'Medium';
    }
  }
}
