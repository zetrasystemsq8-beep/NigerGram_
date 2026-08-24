import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/exchange/data/services/exchange_service.dart';

class ExchangeCreateView extends StatefulWidget {
  const ExchangeCreateView({super.key});

  @override
  State<ExchangeCreateView> createState() => _ExchangeCreateViewState();
}

class _ExchangeCreateViewState extends State<ExchangeCreateView> {
  final _service = ExchangeService();

  final _titleController = TextEditingController();
  final _oneLinerController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _fundingGoalController = TextEditingController();

  String? _category;
  ListingStage _stage = ListingStage.idea;
  String? _licenseType;
  bool _isSubmitting = false;
  String? _errorText;

  static const List<Map<String, dynamic>> _categories = [
    {'value': 'software', 'label': 'Software / Package', 'icon': Icons.code},
    {'value': 'design', 'label': 'Design', 'icon': Icons.brush_outlined},
    {'value': 'prototype', 'label': 'Prototype', 'icon': Icons.precision_manufacturing_outlined},
    {'value': 'research', 'label': 'Research', 'icon': Icons.science_outlined},
    {'value': 'digital_product', 'label': 'Digital Product', 'icon': Icons.shopping_bag_outlined},
    {'value': 'service', 'label': 'Service', 'icon': Icons.handshake_outlined},
    {'value': 'invention', 'label': 'Invention', 'icon': Icons.lightbulb_outline},
    {'value': 'dataset', 'label': 'Dataset / Resource', 'icon': Icons.dataset_outlined},
    {'value': 'other', 'label': 'Other', 'icon': Icons.more_horiz},
  ];

  static const List<Map<String, String>> _licenseOptions = [
    {'value': 'commercial', 'label': 'Commercial'},
    {'value': 'personal', 'label': 'Personal use'},
    {'value': 'open', 'label': 'Open / Free to use'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _oneLinerController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _fundingGoalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorText = null);

    if (_titleController.text.trim().isEmpty) {
      setState(() => _errorText = 'Give your listing a title.');
      return;
    }
    if (_category == null) {
      setState(() => _errorText = 'Pick a category.');
      return;
    }

    double? price;
    double? fundingGoal;

    if (_stage == ListingStage.product) {
      price = double.tryParse(_priceController.text.trim());
      if (_priceController.text.trim().isNotEmpty && price == null) {
        setState(() => _errorText = 'Price should be a number.');
        return;
      }
    }

    if (_stage == ListingStage.prototype) {
      fundingGoal = double.tryParse(_fundingGoalController.text.trim());
      if (_fundingGoalController.text.trim().isNotEmpty && fundingGoal == null) {
        setState(() => _errorText = 'Funding goal should be a number.');
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      await _service.createListing(
        title: _titleController.text.trim(),
        category: _category!,
        stage: _stage,
        oneLiner: _oneLinerController.text.trim().isEmpty ? null : _oneLinerController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        price: price,
        fundingGoal: fundingGoal,
        licenseType: _stage == ListingStage.product ? _licenseType : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing published to Exchange')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _errorText = 'Failed to publish: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 20),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: NGColors.textMuted),
        filled: true,
        fillColor: NGColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _stageOption(ListingStage stage, IconData icon, String label, String sub) {
    final selected = _stage == stage;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _stage = stage),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? NGColors.accent.withOpacity(0.15) : NGColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? NGColors.accent : NGColors.divider, width: selected ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: selected ? NGColors.accent : NGColors.textMuted),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      color: selected ? NGColors.accent : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(sub,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: NGColors.textMuted, fontSize: 9.5)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NGColors.background,
      appBar: AppBar(
        backgroundColor: NGColors.surface,
        title: const Text('Create Listing', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('What stage is this at?'),
            Row(
              children: [
                _stageOption(ListingStage.idea, Icons.lightbulb_outline, 'Idea', 'Looking for interest'),
                const SizedBox(width: 8),
                _stageOption(ListingStage.prototype, Icons.precision_manufacturing_outlined, 'Prototype',
                    'Seeking funding'),
                const SizedBox(width: 8),
                _stageOption(ListingStage.product, Icons.rocket_launch_outlined, 'Product', 'Ready to sell'),
              ],
            ),
            _sectionLabel('Title'),
            _textField(controller: _titleController, hint: 'e.g. FastAuth'),
            _sectionLabel('One-liner'),
            _textField(controller: _oneLinerController, hint: 'A short pitch, one sentence'),
            _sectionLabel('Description'),
            _textField(controller: _descriptionController, hint: 'Tell people more about it...', maxLines: 5),
            _sectionLabel('Category'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((c) {
                final selected = _category == c['value'];
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => _category = c['value'] as String),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? NGColors.accent.withOpacity(0.18) : NGColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? NGColors.accent : NGColors.divider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(c['icon'] as IconData, size: 14, color: selected ? NGColors.accent : NGColors.textMuted),
                        const SizedBox(width: 6),
                        Text(c['label'] as String,
                            style: TextStyle(
                                color: selected ? NGColors.accent : Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_stage == ListingStage.prototype) ...[
              _sectionLabel('Funding goal (₦)'),
              _textField(
                controller: _fundingGoalController,
                hint: 'e.g. 300000',
                keyboardType: TextInputType.number,
              ),
            ],
            if (_stage == ListingStage.product) ...[
              _sectionLabel('Price (₦)'),
              _textField(
                controller: _priceController,
                hint: 'e.g. 5000',
                keyboardType: TextInputType.number,
              ),
              _sectionLabel('License'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _licenseOptions.map((l) {
                  final selected = _licenseType == l['value'];
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _licenseType = l['value']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? NGColors.accent.withOpacity(0.18) : NGColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? NGColors.accent : NGColors.divider),
                      ),
                      child: Text(l['label']!,
                          style: TextStyle(
                              color: selected ? NGColors.accent : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (_errorText != null) ...[
              const SizedBox(height: 16),
              Text(_errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: NGColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Publish to Exchange', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
