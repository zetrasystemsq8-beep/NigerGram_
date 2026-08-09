import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/gist_hub/data/services/community_service.dart';
import 'package:nigergram/features/gist_hub/domain/entities/community_entity.dart';

class CreateCommunityView extends StatefulWidget {
  const CreateCommunityView({super.key});

  @override
  State<CreateCommunityView> createState() => _CreateCommunityViewState();
}

class _CreateCommunityViewState extends State<CreateCommunityView> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _service = CommunityService();

  CommunityType _type = CommunityType.group;
  List<String> _rules = List.from(RuleTemplates.templates['Standard']!);
  String _selectedTemplate = 'Standard';
  bool _isPrivate = false;
  bool _isCreating = false;

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your community a name')),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      final id = await _service.createCommunity(
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        type: _type,
        rules: _rules,
        isPrivate: _isPrivate,
      );
      if (mounted) {
        Navigator.pop(context, id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Community created!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NGColors.background,
      appBar: AppBar(
        backgroundColor: NGColors.surface,
        title: const Text('Create Community', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _create,
            child: Text(
              _isCreating ? 'Creating...' : 'Create (50 CP)',
              style: TextStyle(color: _isCreating ? Colors.grey : NGColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _typeButton('Group', CommunityType.group)),
                const SizedBox(width: 8),
                Expanded(child: _typeButton('Channel', CommunityType.channel)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _type == CommunityType.group
                  ? 'Group: everyone can post and discuss.'
                  : 'Channel: only owner/moderators post, members react & comment.',
              style: TextStyle(color: NGColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Community name',
                hintStyle: TextStyle(color: NGColors.textMuted),
                filled: true,
                fillColor: NGColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'What is this community about?',
                hintStyle: TextStyle(color: NGColors.textMuted),
                filled: true,
                fillColor: NGColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Rules', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: RuleTemplates.templates.keys.map((label) {
                final selected = label == _selectedTemplate;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _selectedTemplate = label;
                    _rules = List.from(RuleTemplates.templates[label]!);
                  }),
                  selectedColor: NGColors.accent,
                  backgroundColor: NGColors.surface,
                  labelStyle: TextStyle(color: selected ? Colors.white : NGColors.textMuted),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            ..._rules.asMap().entries.map((entry) {
              final idx = entry.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextFormField(
                  initialValue: entry.value,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: NGColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                      onPressed: () => setState(() => _rules.removeAt(idx)),
                    ),
                  ),
                  onChanged: (val) => _rules[idx] = val,
                ),
              );
            }),
            TextButton.icon(
              onPressed: () => setState(() => _rules.add('')),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add rule'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Switch(
                  value: _isPrivate,
                  onChanged: (v) => setState(() => _isPrivate = v),
                  activeColor: NGColors.accent,
                ),
                const SizedBox(width: 8),
                Text('Private (invite/approval only)', style: TextStyle(color: NGColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeButton(String label, CommunityType type) {
    final selected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? NGColors.accent : NGColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(label, style: TextStyle(color: selected ? Colors.white : NGColors.textMuted, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
