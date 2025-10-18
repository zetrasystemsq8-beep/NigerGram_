import 'package:flutter/material.dart';
import 'package:flutter_video_feed/core/config/localization/app_localizations.dart';
import 'package:flutter_video_feed/core/utils/extensions/context_size_extensions.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppLocalizations.of(context)!.dashboard,
        style: TextStyle(fontSize: context.fontSize(20)),
      ),
    );
  }
}
