import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nigergram/core/config/localization/app_localizations.dart';
import 'package:nigergram/core/utils/constants/enums/router_enum.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';
import 'package:nigergram/features/video_feed/presentation/view/video_feed_view.dart';
import 'package:nigergram/features/profile/presentation/view/profile_view.dart';
import 'package:nigergram/features/gist_hub/presentation/view/gist_hub_view.dart';
import 'package:nigergram/features/inbox/presentation/view/inbox_view.dart'; // ✅ ADD THIS

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _currentIndex = 0;

  late final List<Widget> _navigationPages = [
    const VideoFeedView(),
    const GistHubView(),
    const SizedBox(),
    const InboxView(), // ✅ CHANGED: Replaced _InboxPlaceholder
    const ProfileView(),
  ];

  void _handleTabSelection(int index) {
    if (index == 2) {
      context.push(RouterEnum.uploadView.routeName);
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: _navigationPages,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
                child: Container(
                  height: context.h(84),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(150),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withAlpha(20),
                        width: 0.5,
                      ),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: context.w(8)),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavigationTabItem(
                          index: 0,
                          icon: Icons.home_filled,
                          label: localizations?.dashboard ?? 'Home',
                        ),
                        _buildNavigationTabItem(
                          index: 1,
                          icon: Icons.grid_view_rounded,
                          label: 'Gist Hub',
                        ),
                        GestureDetector(
                          onTap: () => _handleTabSelection(2),
                          child: SizedBox(
                            width: context.w(48),
                            height: context.h(30),
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: context.w(38),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFE2C55),
                                      borderRadius: BorderRadius.circular(context.w(8)),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: context.w(38),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF23F6E4),
                                      borderRadius: BorderRadius.circular(context.w(8)),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Container(
                                    width: context.w(40),
                                    height: context.h(30),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(context.w(8)),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.black,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _buildNavigationTabItem(
                          index: 3,
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'Inbox',
                        ),
                        _buildNavigationTabItem(
                          index: 4,
                          icon: Icons.person_outline_rounded,
                          label: 'Me',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTabItem({
    required int index,
    required IconData icon,
    required String label,
    int badgeNotificationCount = 0,
  }) {
    final bool isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () => _handleTabSelection(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: context.w(60),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              spacing: context.h(4),
              children: [
                Icon(
                  icon,
                  color: isActive ? Colors.white : Colors.white.withAlpha(150),
                  size: context.sq(26),
                ),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white.withAlpha(150),
                    fontSize: context.fontSize(10),
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (badgeNotificationCount > 0)
              Positioned(
                top: context.h(-4),
                right: context.w(2),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.w(5),
                    vertical: context.h(1),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFE2C55),
                    borderRadius: BorderRadius.circular(context.w(10)),
                  ),
                  constraints: BoxConstraints(minWidth: context.w(16)),
                  child: Text(
                    badgeNotificationCount.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: context.fontSize(9),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ✅ REMOVED _InboxPlaceholder - no longer needed
