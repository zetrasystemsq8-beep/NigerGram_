import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nigergram/features/media/repository/media_repository.dart';

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

  double _qualitySlider = 1.0; // 0=Low,1=Medium,2=High

  @override
  void dispose() {
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 3),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a description'),
          backgroundColor: Colors.red,
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

      // Show an immediate snackbar so testers can see compression started
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Compression started — Media Engine ACTIVE'),
        duration: Duration(seconds: 2),
      ));

      // Use MediaRepository to compress on-device, upload in a single-shot, and
      // delete the original cached file after successful upload. Pass chosen quality.
      await _mediaRepository.compressUploadAndCleanup(
        _videoFile!,
        videoFileName,
        onCompressProgress: (p) {
          // Map compress progress to 0.05 -> 0.35
          setState(() => _uploadProgress = 0.05 + (p * 0.3));
        },
        onUploadProgress: (p) {
          // Map upload progress to 0.35 -> 1.0
          setState(() => _uploadProgress = 0.35 + (p * 0.65));
        },
        bucketName: 'videos',
        quality: _qualitySlider.toInt(),
      );

      // After successful upload, get public URL and create Firestore doc
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

      // Firestore document matches the absolute clean model schema
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
          const SnackBar(
            content: Text('🎉 Video posted to NigerGram!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.blur_on_rounded, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
            const Text(
              'ZETRA LAB ENGINE',
              style: TextStyle(
                color: Colors.white,
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
                  // Small active banner so it's obvious this build contains the new media engine
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Media Engine: ACTIVE — Compression & fast upload enabled',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  _buildVideoSelector(),
                  const SizedBox(height: 12),
                  // Compression quality slider (production UI)
                  Text('Compression quality', style: TextStyle(color: Colors.white, fontSize: 13)),
                  Slider(
                    value: _qualitySlider,
                    min: 0,
                    max: 2,
                    divisions: 2,
                    label: _qualityLabel(_qualitySlider.toInt()),
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
                        color: Colors.white.withOpacity(0.25),
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

  Widget _buildUploadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_upload, color: Colors.red, size: 80),
          const SizedBox(height: 24),
          const Text(
            'Uploading your video...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Optimizing compression assets for Naija 🇳🇬',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
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
                    backgroundColor: Colors.grey.shade800,
                    color: Colors.red,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_uploadProgress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSelector() {
    if (_videoFile != null) {
      return Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 50),
            const SizedBox(height: 8),
            const Text(
              'Video ready to post',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _videoFile = null),
              child: const Text('Change video',
                  style: TextStyle(color: Colors.red)),
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
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_library,
                    color: Colors.red.shade400, size: 50),
                const SizedBox(height: 12),
                const Text(
                  'Pick from Gallery',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'MP4, MOV up to 3 minutes',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 12),
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
              color: Colors.red,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  'Record a Video',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _descriptionController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            maxLength: 150,
            decoration: InputDecoration(
              hintText: 'Tell Naija what this video is about...',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              counterStyle: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tags',
          style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _tagController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '#naija #comedy #viral',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              prefixIcon:
                  Icon(Icons.tag, color: Colors.grey.shade600, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? Colors.red : Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.red
                          : Colors.grey.shade700,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.grey.shade400,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
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

  Widget _buildPostButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _videoFile == null ? null : _uploadVideo,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          disabledBackgroundColor: Colors.grey.shade800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Post to NigerGram 🇳🇬',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

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
