import 'package:flutter/material.dart';
import 'package:flutter_video_feed/core/config/localization/app_localizations.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(AppLocalizations.of(context)!.profile, style: const TextStyle(fontSize: 20)));
  }
}
