import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'video_upload_service.dart';

class VideoCreationScreen extends StatefulWidget {
  const VideoCreationScreen({super.key});

  @override
  State<VideoCreationScreen> createState() => _VideoCreationScreenState();
}

class _VideoCreationScreenState extends State<VideoCreationScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();
  
  File? _selectedVideo;
  bool _isUploading =尊false;
  double _uploadProgress = 0.0;
  
  // Instance of our unified upload service
  late final VideoUploadService _uploadService;

  @override
  void initState() {
    super.initState();
    // Initialize your service here (pass your Firebase/Supabase instances)
    // _uploadService = VideoUploadService(...);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  /// High-Fidelity Gallery Picker
  Future<void> _pickVideoFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );
      
      if (pickedFile != null) {
        setState(() {
          _selectedVideo = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
    }
  }

  /// Triggers the entire institutional-grade pipeline
  Future<void> _startUploadPipeline() async {
    if (_selectedVideo == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    // Execute master compression and upload pipeline
    final success = await _uploadService.processAndUploadVideo(
      userId: 'current_user_id', // Replace with your auth state user ID
      rawVideoPath: _selectedVideo!.path,
      title: 'New Post',
      description: _captionController.text.trim(),
      onProgressUpdate: (progress) {
        setState(() {
          _uploadProgress = progress;
        });
      },
    );

    setState(() {
      _isUploading = false;
    });

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post published successfully!')),
        );
        Navigator.of(context).pop();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Immersive Full-Screen Canvas Viewport
          _selectedVideo == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.video_library_outlined, size: 80, color: Colors.white.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      const Text(
                        'Share your moment on NigerGram',
                        style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
              : Container(
                  color: Colors.black87,
                  child: Center(
                    child: Icon(Icons.play_circle_filled_rounded, size: 80, color: Colors.white.withOpacity(0.7)),
                  ),
                ),

          // Back Button Anchor
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: GestureDetector(
              onTap: () => _isUploading ? null : Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 26),
              ),
            ),
          ),

          // 2. Floating Side Control Panel (Premium Layout)
          if (_selectedVideo != null && !_isUploading)
            Positioned(
              right: 16,
              top: MediaQuery.of(context).size.height * 0.25,
              child: Column(
                children: [
                  _buildFloatingControlIcon(
                    icon: Icons.repeat,
                    label: 'Change',
                    onTap: _pickVideoFromGallery,
                  ),
                  const SizedBox(height: 20),
                  _buildFloatingControlIcon(
                    icon: Icons.closed_caption_off,
                    label: 'Captions',
                    onTap: () {},
                  ),
                ],
              ),
            ),

          // 3. Premium Glassmorphic Bottom Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).padding.bottom + 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.85), Colors.black],
                ),
              ),
              child: _selectedVideo == null
                  ? ElevatedButton(
                      onPressed: _pickVideoFromGallery,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Open Gallery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _captionController,
                          enabled: !_isUploading,
                          maxLines: 3,
                          maxLength: 150,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          decoration: InputDecoration(
                            hintText: 'Write a caption for NigerGram...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 15),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.08),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isUploading ? null : _startUploadPipeline,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF0050), // Vibrant Accent
                            disabledBackgroundColor: Colors.grey.shade800,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Post Video', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    ),
            ),
          ),

          // 4. Centralized HUD Processing & Upload Overlay
          if (_isUploading)
            Container(
              color: Colors.black70,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            value: _uploadProgress,
                            strokeWidth: 6,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0050)),
                            backgroundColor: Colors.white12,
                          ),
                        ),
                        Text(
                          '${(_uploadProgress * 180).toStringAsFixed(0)}%', // Scales progress clearly
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Optimizing & Publishing...',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Compressing video assets to preserve network data',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingControlIcon({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle, border: Border.all(color: Colors.white10)),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
