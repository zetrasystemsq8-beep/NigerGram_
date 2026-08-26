import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/gist_hub/data/services/activity_service.dart';

class CommunityActivitiesTab extends StatefulWidget {
  final String communityId;
  const CommunityActivitiesTab({required this.communityId, super.key});

  @override
  State<CommunityActivitiesTab> createState() => _CommunityActivitiesTabState();
}

class _CommunityActivitiesTabState extends State<CommunityActivitiesTab> {
  final _service = ActivityService();

  static const Map<String, Map<String, dynamic>> _subtypeStyle = {
    'debate': {'emoji': '🔥', 'label': 'Debate', 'color': Color(0xFFFF7043)},
    'quick_battle': {'emoji': '⚡', 'label': 'Quick Battle', 'color': Color(0xFFFFCA28)},
    'quiz': {'emoji': '🧠', 'label': 'Quiz', 'color': Color(0xFF64B5F6)},
    'prediction': {'emoji': '🔮', 'label': 'Prediction', 'color': Color(0xFFBA68C8)},
    'goal': {'emoji': '🎯', 'label': 'Community Goal', 'color': Color(0xFF81C784)},
    'challenge': {'emoji': '🏆', 'label': 'Challenge', 'color': Color(0xFFFFD54F)},
    'announcement': {'emoji': '📢', 'label': 'Announcement', 'color': Color(0xFF4DB6AC)},
    'event': {'emoji': '🗓️', 'label': 'Event', 'color': Color(0xFFE57373)},
  };

  Map<String, dynamic> _styleFor(String subtype) =>
      _subtypeStyle[subtype] ?? {'emoji': '•', 'label': subtype, 'color': NGColors.accent};

  String _summaryFor(Map<String, dynamic> a) {
    switch (a['type']) {
      case 'poll':
        final options = List<Map<String, dynamic>>.from(a['options'] ?? []);
        final total = options.fold<int>(0, (s, o) => s + (o['votes'] as int));
        return '$total votes';
      case 'goal':
        return '${a['currentCount'] ?? 0} / ${a['targetCount'] ?? 0}';
      case 'announcement':
        return a['location'] ?? 'Announcement';
      default:
        return '';
    }
  }

  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NGColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CreateActivitySheet(communityId: widget.communityId, service: _service),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: NGColors.accent,
        icon: const Icon(Icons.add),
        label: const Text('Start Something'),
        onPressed: _openCreateSheet,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _service.getActivitiesStream(widget.communityId, activeOnly: false),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: NGColors.accent));
          }
          final activities = snapshot.data!;
          if (activities.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_circle_outline, size: 40, color: NGColors.textMuted.withOpacity(0.6)),
                const SizedBox(height: 10),
                Text('No activities yet', style: TextStyle(color: NGColors.textMuted)),
                const SizedBox(height: 4),
                Text('Tap "Start Something" to create the first one', style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
              ]),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final a = activities[index];
              final style = _styleFor(a['subtype']);
              final color = style['color'] as Color;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: NGColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Row(children: [
                  Text(style['emoji'] as String, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('${style['label']} · ${_summaryFor(a)}', style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
                    ]),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

class _CreateActivitySheet extends StatefulWidget {
  final String communityId;
  final ActivityService service;
  const _CreateActivitySheet({required this.communityId, required this.service});

  @override
  State<_CreateActivitySheet> createState() => _CreateActivitySheetState();
}

class _CreateActivitySheetState extends State<_CreateActivitySheet> {
  String _type = 'poll';
  String _subtype = 'debate';
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetController = TextEditingController(text: '100');
  final _locationController = TextEditingController();
  final List<TextEditingController> _optionControllers = [TextEditingController(), TextEditingController()];
  DateTime? _eventDate;
  bool _isSubmitting = false;
  String? _error;

  static const Map<String, List<Map<String, String>>> _subtypesByType = {
    'poll': [
      {'value': 'debate', 'emoji': '🔥', 'label': 'Debate'},
      {'value': 'quick_battle', 'emoji': '⚡', 'label': 'Quick Battle'},
      {'value': 'quiz', 'emoji': '🧠', 'label': 'Quiz'},
      {'value': 'prediction', 'emoji': '🔮', 'label': 'Prediction'},
    ],
    'goal': [
      {'value': 'goal', 'emoji': '🎯', 'label': 'Community Goal'},
      {'value': 'challenge', 'emoji': '🏆', 'label': 'Challenge'},
    ],
    'announcement': [
      {'value': 'announcement', 'emoji': '📢', 'label': 'Announcement'},
      {'value': 'event', 'emoji': '🗓️', 'label': 'Event'},
    ],
  };

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _locationController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _setType(String type) {
    setState(() {
      _type = type;
      _subtype = _subtypesByType[type]!.first['value']!;
    });
  }

  void _addOption() {
    if (_optionControllers.length >= 5) return;
    setState(() => _optionControllers.add(TextEditingController()));
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'Give it a title');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.service.createActivity(
        communityId: widget.communityId,
        type: _type,
        subtype: _subtype,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        pollOptions: _type == 'poll'
            ? _optionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList()
            : null,
        targetCount: _type == 'goal' ? int.tryParse(_targetController.text.trim()) : null,
        eventDate: _type == 'announcement' ? _eventDate : null,
        location: _type == 'announcement' && _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _typeChip(String type, String label, IconData icon) {
    final selected = _type == type;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _setType(type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? NGColors.accent.withOpacity(0.15) : NGColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? NGColors.accent : NGColors.divider),
          ),
          child: Column(children: [
            Icon(icon, size: 18, color: selected ? NGColors.accent : NGColors.textMuted),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: selected ? NGColors.accent : NGColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String hint, {TextInputType? keyboardType, int maxLines = 1}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: NGColors.background, borderRadius: BorderRadius.circular(10)),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: NGColors.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtypes = _subtypesByType[_type]!;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: NGColors.textMuted, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Start Something', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              Row(children: [
                _typeChip('poll', 'Poll', Icons.how_to_vote_outlined),
                _typeChip('goal', 'Goal', Icons.flag_outlined),
                _typeChip('announcement', 'Announce', Icons.campaign_outlined),
              ]),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: subtypes.map((s) {
                  final selected = _subtype == s['value'];
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _subtype = s['value']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? NGColors.accent.withOpacity(0.18) : NGColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? NGColors.accent : NGColors.divider),
                      ),
                      child: Text('${s['emoji']} ${s['label']}',
                          style: TextStyle(color: selected ? NGColors.accent : Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              _field(_titleController, 'Title'),
              _field(_descriptionController, 'Description (optional)', maxLines: 3),
              if (_type == 'poll') ...[
                const SizedBox(height: 4),
                ..._optionControllers.asMap().entries.map((e) => _field(e.value, 'Option ${e.key + 1}')),
                if (_optionControllers.length < 5)
                  TextButton.icon(
                    onPressed: _addOption,
                    icon: const Icon(Icons.add, size: 16, color: NGColors.accent),
                    label: const Text('Add option', style: TextStyle(color: NGColors.accent)),
                  ),
              ],
              if (_type == 'goal') _field(_targetController, 'Target number', keyboardType: TextInputType.number),
              if (_type == 'announcement') ...[
                _field(_locationController, 'Location (optional)'),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _eventDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: NGColors.background, borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Icon(Icons.calendar_today_outlined, size: 16, color: NGColors.textMuted),
                      const SizedBox(width: 8),
                      Text(
                        _eventDate == null ? 'Pick a date (optional)' : '${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year}',
                        style: TextStyle(color: _eventDate == null ? NGColors.textMuted : Colors.white),
                      ),
                    ]),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: NGColors.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
            ]),
          );
        },
      ),
    );
  }
}
