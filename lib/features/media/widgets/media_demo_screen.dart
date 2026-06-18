// lib/features/media/widgets/media_demo_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../cubit/media_cubit.dart';

class MediaDemoScreen extends StatefulWidget {
  const MediaDemoScreen({Key? key}) : super(key: key);

  @override
  State<MediaDemoScreen> createState() => _MediaDemoScreenState();
}

class _MediaDemoScreenState extends State<MediaDemoScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _pickedFile;
  double _qualitySlider = 1.0; // 0 low, 1 medium, 2 high

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MediaCubit(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Media Compression & Upload Demo'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.video_library),
                label: const Text('Pick Video'),
              ),
              const SizedBox(height: 12),
              if (_pickedFile != null) ...[
                Text('Selected: ${_pickedFile!.path.split('/').last}'),
                const SizedBox(height: 12),
                Text('Compression quality'),
                Slider(
                  value: _qualitySlider,
                  min: 0,
                  max: 2,
                  divisions: 2,
                  label: _qualityLabel(_qualitySlider.toInt()),
                  onChanged: (v) => setState(() => _qualitySlider = v),
                ),
                const SizedBox(height: 12),
                BlocConsumer<MediaCubit, dynamic>(
                  listener: (context, state) {
                    if (state is MediaSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Upload complete — temp file deleted')));
                      setState(() => _pickedFile = null);
                    }
                    if (state is MediaFailure) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(state.message)));
                    }
                  },
                  builder: (context, state) {
                    double progress = 0.0;
                    String status = 'Idle';
                    if (state is MediaCompressing) {
                      progress = state.progress;
                      status = 'Compressing...';
                    } else if (state is MediaUploading) {
                      progress = state.progress;
                      status = 'Uploading...';
                    } else if (state is MediaSuccess) {
                      progress = 1.0;
                      status = 'Done';
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: () => context.read<MediaCubit>().compressAndUpload(
                              _pickedFile!, 'uploads/${DateTime.now().millisecondsSinceEpoch}.mp4',
                              quality: _qualitySlider.toInt()),
                          child: const Text('Compress & Upload (single-shot)'),
                        ),
                        const SizedBox(height: 12),
                        Text(status),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: progress),
                      ],
                    );
                  },
                ),
              ] else ...[
                const Text('No video selected'),
              ],
            ],
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

  Future<void> _pickVideo() async {
    final XFile? picked =
        await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 5));
    if (picked == null) return;
    setState(() {
      _pickedFile = File(picked.path);
    });
  }
}
