// lib/features/explore/presentation/view/explore_view.dart

import 'package:flutter/material.dart';

// This file was intentionally replaced on branch `feature/gist-hub-feed`.
// The Explore feature has been removed and replaced by the new Gist Hub.
// Keep this lightweight stub only to avoid import errors in other branches
// until you perform a full git rm locally or on main after merge.

class ExploreView extends StatelessWidget {
  const ExploreView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.info_outline, color: Colors.white70, size: 48),
              SizedBox(height: 12),
              Text(
                'Explore has been removed',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Use the Gist Hub instead (Gist Hub tab or /gist-hub route).',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
