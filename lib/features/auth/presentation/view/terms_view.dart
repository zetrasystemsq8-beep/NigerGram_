// lib/features/auth/presentation/view/terms_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nigergram/core/design_system/colors.dart';

class TermsView extends StatefulWidget {
  final String type;
  const TermsView({super.key, this.type = 'terms'});

  @override
  State<TermsView> createState() => _TermsViewState();
}

class _TermsViewState extends State<TermsView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NGColors.background,
      appBar: AppBar(
        backgroundColor: NGColors.surface,
        elevation: 0,
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('settings')
              .doc(widget.type == 'terms' ? 'terms' : 'privacy')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              return Text(
                data['title'] ?? (widget.type == 'terms' ? 'Terms & Conditions' : 'Privacy Policy'),
                style: const TextStyle(
                  color: NGColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              );
            }
            return const Text(
              'Loading...',
              style: TextStyle(color: NGColors.textPrimary),
            );
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: NGColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('settings')
            .doc(widget.type == 'terms' ? 'terms' : 'privacy')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: NGColors.accent),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: NGColors.textMuted, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load terms',
                    style: TextStyle(color: NGColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NGColors.accent,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: NGColors.textMuted, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Terms not found',
                    style: TextStyle(color: NGColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please contact support',
                    style: TextStyle(color: NGColors.textMuted),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final sections = data['sections'] as List? ?? [];
          final lastUpdated = data['lastUpdated'] ?? 'N/A';

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: NGColors.surface,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Last Updated: $lastUpdated',
                        style: TextStyle(
                          color: NGColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sections.length,
                  itemBuilder: (context, index) {
                    final section = sections[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section['title'] ?? '',
                            style: const TextStyle(
                              color: NGColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            section['content'] ?? '',
                            style: TextStyle(
                              color: NGColors.textSecondary,
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                          const Divider(color: NGColors.divider, height: 20),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
