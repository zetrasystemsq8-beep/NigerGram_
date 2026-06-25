import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/gist_hub/data/services/gist_service.dart';

class GistCreatePost extends StatefulWidget {
  const GistCreatePost({super.key});

  @override
  State<GistCreatePost> createState() => _GistCreatePostState();
}

class _GistCreatePostState extends State<GistCreatePost> {
  final TextEditingController _contentController = TextEditingController();
  final GistService _service = GistService();
  
  String _postType = 'text'; // text, image, poll
  File? _imageFile;
  final List<TextEditingController> _pollControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _isAnonymous = false;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }

  Future<void> _submitPost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      File? imageFile;
      if (_imageFile != null) {
        imageFile = _imageFile;
      }

      List<String>? pollOptions;
      if (_postType == 'poll') {
        final option1 = _pollControllers[0].text.trim();
        final option2 = _pollControllers[1].text.trim();
        if (option1.isEmpty || option2.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill both poll options')),
          );
          setState(() => _isLoading = false);
          return;
        }
        pollOptions = [option1, option2];
      }

      await _service.createPost(
        type: _postType,
        content: _contentController.text.trim(),
        imageFile: imageFile,
        pollOptions: pollOptions,
        isAnonymous: _isAnonymous,
      );
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gist posted! 🎉')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NGColors.background,
      appBar: AppBar(
        backgroundColor: NGColors.surface,
        title: const Text(
          'Drop Gist',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitPost,
            child: Text(
              _isLoading ? 'Posting...' : 'Post',
              style: TextStyle(
                color: _isLoading ? Colors.grey : NGColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post Type Buttons
            Row(
              children: [
                _buildTypeButton('Text', 'text'),
                const SizedBox(width: 8),
                _buildTypeButton('Image', 'image'),
                const SizedBox(width: 8),
                _buildTypeButton('Poll', 'poll'),
              ],
            ),
            const SizedBox(height: 16),

            // Content Input
            TextField(
              controller: _contentController,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'What\'s the gist?',
                hintStyle: TextStyle(color: NGColors.textMuted),
                filled: true,
                fillColor: NGColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Image Picker
            if (_postType == 'image') ...[
              if (_imageFile != null)
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: FileImage(_imageFile!),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => _imageFile = null),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: NGColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NGColors.divider),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate, color: NGColors.textMuted),
                        SizedBox(height: 8),
                        Text(
                          'Tap to add image',
                          style: TextStyle(color: NGColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],

            // Poll Options
            if (_postType == 'poll') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _pollControllers[0],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Option 1',
                  hintStyle: TextStyle(color: NGColors.textMuted),
                  filled: true,
                  fillColor: NGColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pollControllers[1],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Option 2',
                  hintStyle: TextStyle(color: NGColors.textMuted),
                  filled: true,
                  fillColor: NGColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Anonymous Toggle
            Row(
              children: [
                Switch(
                  value: _isAnonymous,
                  onChanged: (val) => setState(() => _isAnonymous = val),
                  activeColor: NGColors.accent,
                ),
                Text(
                  'Post anonymously',
                  style: TextStyle(
                    color: _isAnonymous ? NGColors.accent : NGColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, String type) {
    final isSelected = _postType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _postType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? NGColors.accent : NGColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : NGColors.textMuted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
