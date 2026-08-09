import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/gist_hub/data/services/bounty_service.dart';
import 'package:nigergram/features/gist_hub/domain/entities/bounty_entity.dart';

class CreateBountyView extends StatefulWidget {
  const CreateBountyView({super.key});

  @override
  State<CreateBountyView> createState() => _CreateBountyViewState();
}

class _CreateBountyViewState extends State<CreateBountyView> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _rewardController = TextEditingController();
  final _service = BountyService();

  String _category = bountyCategories.first;
  bool _isPosting = false;

  Future<void> _post() async {
    final reward = double.tryParse(_rewardController.text.trim());
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give your bounty a title')));
      return;
    }
    if (reward == null || reward <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid CP reward')));
      return;
    }

    setState(() => _isPosting = true);
    try {
      await _service.createBounty(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        category: _category,
        rewardCp: reward,
      );
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎯 Bounty posted!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NGColors.background,
      appBar: AppBar(
        backgroundColor: NGColors.surface,
        title: const Text('Post a Bounty', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _post,
            child: Text(
              _isPosting ? 'Posting...' : 'Post',
              style: TextStyle(color: _isPosting ? Colors.grey : NGColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'What do you need built?',
                hintStyle: TextStyle(color: NGColors.textMuted),
                filled: true,
                fillColor: NGColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Describe the task, requirements, deadline...',
                hintStyle: TextStyle(color: NGColors.textMuted),
                filled: true,
                fillColor: NGColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: bountyCategories.map((c) {
                final selected = c == _category;
                return ChoiceChip(
                  label: Text(c),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = c),
                  selectedColor: NGColors.accent,
                  backgroundColor: NGColors.surface,
                  labelStyle: TextStyle(color: selected ? Colors.white : NGColors.textMuted),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rewardController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Reward (CP)',
                hintStyle: TextStyle(color: NGColors.textMuted),
                prefixIcon: Icon(Icons.monetization_on_outlined, color: NGColors.accent),
                filled: true,
                fillColor: NGColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This CP is held immediately and only released once you mark the bounty complete.',
              style: TextStyle(color: NGColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
