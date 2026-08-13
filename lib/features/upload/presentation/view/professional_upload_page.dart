import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:nigergram/core/utils/app_auth.dart';
import 'package:nigergram/features/media/repository/media_repository.dart';
import 'package:nigergram/features/media/presentation/pages/advanced_video_editor_page.dart';
import 'package:nigergram/features/media/presentation/pages/podcast_editor_page.dart';
import 'package:nigergram/features/media/models/video_edit_model.dart';
import 'package:nigergram/core/design_system/colors.dart';

/// Professional Innovation Upload Page (LinkedIn-Style)
/// For innovators to share breakthroughs, new laws, apps, processes, and services
class ProfessionalUploadPage extends StatefulWidget {
  const ProfessionalUploadPage({super.key});

  @override
  State<ProfessionalUploadPage> createState() => _ProfessionalUploadPageState();
}

class _ProfessionalUploadPageState extends State<ProfessionalUploadPage> {
  final _innovationTitleController = TextEditingController();
  final _problemStatementController = TextEditingController();
  final _impactDescriptionController = TextEditingController();
  final _researchLinkController = TextEditingController();
  final _tagsController = TextEditingController();

  File? _videoFile;
  bool _isUploading = false;
  double _uploadProgress = 0;

  String _selectedCategory = 'Technology';
  String _selectedInnovationType = 'App';
  String _contentType = 'video'; // 'video' or 'podcast'

  bool _autoSaveDrafts = true;
  DateTime? _lastSaveTime;

  VideoEditModel? _videoEditModel;
  VideoEditModel? _podcastEditModel;

  // Professional Categories (Industry Sectors)
  final List<String> _categories = [
    'Technology',
    'Healthcare',
    'Finance',
    'Education',
    'Transportation',
    'Agriculture',
    'Energy',
    'Legal',
    'Climate',
    'Manufacturing',
    'Retail',
    'Other'
  ];

  // Innovation Types
  final List<Map<String, dynamic>> _innovationTypes = [
    {'name': 'App/Software', 'icon': Icons.app_shortcut, 'description': 'Mobile or web application'},
    {'name': 'Law/Policy', 'icon': Icons.balance, 'description': 'Legal framework or policy'},
    {'name': 'Process/Method', 'icon': Icons.settings, 'description': 'New workflow or methodology'},
    {'name': 'Service', 'icon': Icons.handshake, 'description': 'New service or platform'},
    {'name': 'Research', 'icon': Icons.science, 'description': 'Research finding or study'},
    {'name': 'Hardware', 'icon': Icons.devices, 'description': 'Physical device or product'},
  ];

  final MediaRepository _mediaRepository = MediaRepository();

  @override
  void initState() {
    super.initState();
    _startAutoSave();
  }

  void _startAutoSave() {
    if (_autoSaveDrafts) {
      Future.doWhile(() async {
        await Future.delayed(const Duration(seconds: 30));
        if (mounted) {
          _saveDraft();
        }
        return mounted && _autoSaveDrafts;
      });
    }
  }

  Future<void> _saveDraft() async {
    try {
      final user = AppAuth.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .collection('drafts')
          .doc('innovation_${DateTime.now().toIso8601String()}')
          .set({
        'title': _innovationTitleController.text,
        'problemStatement': _problemStatementController.text,
        'impact': _impactDescriptionController.text,
        'category': _selectedCategory,
        'innovationType': _selectedInnovationType,
        'contentType': _contentType,
        'tags': _tagsController.text,
        'researchLink': _researchLinkController.text,
        'videoEdits': _videoEditModel?.toString(),
        'podcastEdits': _podcastEditModel?.toString(),
        'savedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _lastSaveTime = DateTime.now());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📝 Draft auto-saved'),
            duration: Duration(milliseconds: 500),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('Draft save error: $e');
    }
  }

  @override
  void dispose() {
    _innovationTitleController.dispose();
    _problemStatementController.dispose();
    _impactDescriptionController.dispose();
    _researchLinkController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 5),
    );
    if (picked != null) {
      setState(() => _videoFile = File(picked.path));
    }
  }

  Future<void> _openVideoEditor() async {
    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a video first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push<VideoEditModel>(
      context,
      MaterialPageRoute(
        builder: (context) => AdvancedVideoEditorPage(
          videoPath: _videoFile!.path,
          initialEdit: _videoEditModel,
        ),
      ),
    );

    if (result != null) {
      setState(() => _videoEditModel = result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Video edited successfully'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _openPodcastEditor() async {
    final result = await Navigator.push<VideoEditModel>(
      context,
      MaterialPageRoute(
        builder: (context) => PodcastEditorPage(
          videoPath: _videoFile?.path,
          initialEdit: _podcastEditModel,
        ),
      ),
    );

    if (result != null) {
      setState(() => _podcastEditModel = result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Podcast configured successfully'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _uploadInnovation() async {
    if (_innovationTitleController.text.trim().isEmpty) {
      _showError('Please enter an innovation title');
      return;
    }

    if (_problemStatementController.text.trim().isEmpty) {
      _showError('Please describe the problem this innovation solves');
      return;
    }

    if (_videoFile == null && _contentType == 'video') {
      _showError('Please select a video to upload');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final user = AppAuth.currentUser;
      if (user == null) {
        _showError('User not authenticated');
        return;
      }

      setState(() => _uploadProgress = 0.05);

      // Get user profile data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .get();

      final username = userDoc.data()?['username'] ?? 'innovator';
      final profilePic = userDoc.data()?['profilePicUrl'] ?? '';

      // Handle video upload
      String? videoKey;
      String? videoUrl;
      if (_videoFile != null && _contentType == 'video') {
        videoKey = MediaRepository.generateVideoKey(user.id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Compressing and uploading video...'),
          duration: Duration(seconds: 2),
        ));

        await _mediaRepository.compressUploadAndCleanup(
          _videoFile!,
          videoKey,
          onCompressProgress: (p) {
            setState(() => _uploadProgress = 0.05 + (p * 0.35));
          },
          onUploadProgress: (p) {
            setState(() => _uploadProgress = 0.4 + (p * 0.5));
          },
          quality: 1, // Medium quality
        );

        videoUrl = 'https://supabase.example.com/videos/$videoKey';
      }

      setState(() => _uploadProgress = 0.9);

      // Parse tags
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      // Create innovation document
      final innovationData = {
        'title': _innovationTitleController.text.trim(),
        'problemStatement': _problemStatementController.text.trim(),
        'impact': _impactDescriptionController.text.trim(),
        'category': _selectedCategory,
        'innovationType': _selectedInnovationType,
        'contentType': _contentType,
        'videoKey': videoKey,
        'videoUrl': videoUrl,
        'userId': user.id,
        'username': username,
        'profileImageUrl': profilePic,
        'tags': tags,
        'researchLink': _researchLinkController.text.trim().isNotEmpty
            ? _researchLinkController.text.trim()
            : null,
        'videoEdits': _videoEditModel != null ? _videoEditModel.toString() : null,
        'podcastEdits': _podcastEditModel != null ? _podcastEditModel.toString() : null,
        'likeCount': 0,
        'commentCount': 0,
        'shareCount': 0,
        'viewCount': 0,
        'timestamp': FieldValue.serverTimestamp(),
        'isVerified': false,
        'status': 'published', // pending, published, archived
      };

      // Upload to Firestore
      await FirebaseFirestore.instance.collection('innovations').add(innovationData);

      setState(() => _uploadProgress = 1.0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚀 Innovation published successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Clear form
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      _showError('Upload failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
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
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Share Innovation',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          if (_lastSaveTime != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  'Saved',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isUploading
          ? _buildUploadingScreen()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // INFO BANNER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: NGColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: NGColors.accent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb, color: NGColors.accent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Share your breakthrough innovation with the world',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // CONTENT TYPE SELECTOR
                  const Text(
                    'Content Type',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _contentType = 'video'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _contentType == 'video'
                                  ? NGColors.accent
                                  : Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.video_camera_back,
                                  color: _contentType == 'video'
                                      ? Colors.black
                                      : Colors.white70,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Video',
                                  style: TextStyle(
                                    color: _contentType == 'video'
                                        ? Colors.black
                                        : Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _contentType = 'podcast'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _contentType == 'podcast'
                                  ? NGColors.accent
                                  : Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.mic,
                                  color: _contentType == 'podcast'
                                      ? Colors.black
                                      : Colors.white70,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Podcast',
                                  style: TextStyle(
                                    color: _contentType == 'podcast'
                                        ? Colors.black
                                        : Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // INNOVATION TITLE
                  _buildTextField(
                    'Innovation Title',
                    _innovationTitleController,
                    'What is your innovation called?',
                    maxLines: 2,
                    icon: Icons.lightbulb,
                  ),
                  const SizedBox(height: 16),

                  // CATEGORY & TYPE ROW
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Industry Sector',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade900,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedCategory,
                                isExpanded: true,
                                dropdownColor: Colors.grey.shade800,
                                underline: Container(),
                                items: _categories
                                    .map((cat) => DropdownMenuItem(
                                          value: cat,
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Text(cat,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                )),
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(
                                      () => _selectedCategory = value ?? _selectedCategory);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Innovation Type',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade900,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedInnovationType,
                                isExpanded: true,
                                dropdownColor: Colors.grey.shade800,
                                underline: Container(),
                                items: _innovationTypes
                                    .map((type) => DropdownMenuItem(
                                          value: type['name'],
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Text(type['name'],
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                )),
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() =>
                                      _selectedInnovationType = value ?? _selectedInnovationType);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // PROBLEM STATEMENT
                  _buildTextField(
                    'Problem Statement',
                    _problemStatementController,
                    'What problem does this innovation solve?',
                    maxLines: 3,
                    icon: Icons.warning_amber,
                  ),
                  const SizedBox(height: 16),

                  // IMPACT DESCRIPTION
                  _buildTextField(
                    'Impact & Benefits',
                    _impactDescriptionController,
                    'Who benefits? How does it create change?',
                    maxLines: 3,
                    icon: Icons.trending_up,
                  ),
                  const SizedBox(height: 16),

                  // RESEARCH LINK
                  _buildTextField(
                    'Research/Reference Link (Optional)',
                    _researchLinkController,
                    'https://example.com/research-paper',
                    icon: Icons.link,
                  ),
                  const SizedBox(height: 16),

                  // TAGS
                  _buildTextField(
                    'Tags',
                    _tagsController,
                    '#innovation, #tech, #breakthrough',
                    icon: Icons.tag,
                  ),
                  const SizedBox(height: 20),

                  // MEDIA SECTION
                  _buildMediaSection(),
                  const SizedBox(height: 20),

                  // EDITOR BUTTONS
                  if (_videoFile != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openVideoEditor,
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit Video'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openPodcastEditor,
                            icon: const Icon(Icons.mic),
                            label: const Text('Add Audio'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // PUBLISH BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _videoFile == null ? null : _uploadInnovation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NGColors.accent,
                        disabledBackgroundColor: Colors.grey.shade800,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Publish Innovation 🚀',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade600),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
              prefixIcon: icon != null
                  ? Icon(icon, color: Colors.grey.shade600, size: 18)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaSection() {
    if (_videoFile != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NGColors.accent, width: 2),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 50),
            const SizedBox(height: 12),
            const Text(
              'Video Ready to Post',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _videoFile!.path.split('/').last,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _videoFile = null),
              child: const Text('Change video',
                  style: TextStyle(color: NGColors.accent)),
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
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_library,
                    color: NGColors.accent.withOpacity(0.7), size: 50),
                const SizedBox(height: 12),
                const Text(
                  'Pick from Gallery',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'MP4, MOV up to 5 minutes',
                  style: TextStyle(
                    color: Colors.grey.shade500,
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
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam, color: Colors.black, size: 28),
                SizedBox(width: 12),
                Text(
                  'Record Innovation Video',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
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

  Widget _buildUploadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_upload, color: NGColors.accent, size: 80),
          const SizedBox(height: 24),
          const Text(
            'Publishing Your Innovation...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Optimizing and uploading media 🚀',
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
                    color: NGColors.accent,
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
}
