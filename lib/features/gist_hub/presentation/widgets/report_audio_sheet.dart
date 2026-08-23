// lib/features/gist_hub/presentation/widgets/report_audio_sheet.dart
import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/gist_hub/data/services/audio_service.dart';

const List<String> audioReportReasons = [
  'Copyright infringement',
  'Impersonation',
  'Harassment',
  'Misleading content',
  'Voice misuse',
  'AI/deepfake misuse',
  'Other abuse',
];

class ReportAudioSheet extends StatefulWidget {
  const ReportAudioSheet({required this.audioId, super.key});

  final String audioId;

  static Future<bool?> show(BuildContext context, String audioId) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportAudioSheet(audioId: audioId),
    );
  }

  @override
  State<ReportAudioSheet> createState() => _ReportAudioSheetState();
}

class _ReportAudioSheetState extends State<ReportAudioSheet> {
  final AudioService _service = AudioService();
  final TextEditingController _detailsController = TextEditingController();
  String? _selectedReason;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a reason for reporting.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _service.reportAudio(
        audioId: widget.audioId,
        reason: _selectedReason!,
        details: _detailsController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit report: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: NGColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              Text(
                'Report this audio',
                style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              ...audioReportReasons.map((reason) {
                final selected = reason == _selectedReason;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: NGColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? NGColors.accent : Colors.transparent, width: 1.5),
                  ),
                  child: RadioListTile<String>(
                    value: reason,
                    groupValue: _selectedReason,
                    activeColor: NGColors.accent,
                    title: Text(reason, style: TextStyle(color: NGColors.textPrimary, fontSize: 14)),
                    onChanged: (value) => setState(() => _selectedReason = value),
                  ),
                );
              }),
              const SizedBox(height: 12),
              TextField(
                controller: _detailsController,
                maxLines: 3,
                style: TextStyle(color: NGColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Additional details (optional)',
                  hintStyle: TextStyle(color: NGColors.textMuted),
                  filled: true,
                  fillColor: NGColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text('Submit Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
