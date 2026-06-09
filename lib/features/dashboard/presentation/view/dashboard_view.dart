import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:nigergram/core/config/localization/app_localizations.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';

// Temporary placeholder containers to keep the shell compiled cleanly
class DashboardTabPlaceholder extends StatelessWidget {
  const DashboardTabPlaceholder({required this.name, super.key});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          name,
          style: TextStyle(color: Colors.white, fontSize: context.fontSize(18)),
        ),
      ),
    );
  }
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _currentIndex = 0;

  // Real-time navigation array managed by an IndexedStack to prevent tab destruction
  final List<Widget> _navigationPages = [
    const DashboardTabPlaceholder(name: 'Home Video Feed View'),
    const DashboardTabPlaceholder(name: 'Explore Discovery View'),
    const DashboardTabPlaceholder(name: 'Media Creation Overlay'),
    const DashboardTabPlaceholder(name: 'Inbox Messaging View'),
    const DashboardTabPlaceholder(name: 'User Profile View'),
  ];

  void _handleTabSelection(int index) {
    if (index == 2) {
      debugPrint('NigerGram Log: Intercepting core creation engine modal route.');
      return; 
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Underlying Active Content Stream
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: _navigationPages,
            ),
          ),

          // Translucent Premium Bottom Bar Layer
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
                          icon: Icons.grid_view_rounded, // Matches grid profile from Screenshot_20260608-192648.jpg
                          label: 'Explore',
                        ),
                        
                        // Centered Layered Create Button Custom Canvas Architecture
                        GestureDetector(
                          onTap: () => _handleTabSelection(2),
                          child: SizedBox(
                            width: context.w(48),
                            height: context.h(30),
                            child: Stack(
                              children: [
                                // Left Neon Magenta Accent Frame Shadow
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
                                // Right Neon Cyan Accent Frame Shadow
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
                                // Crisp High-Contrast Centered Cap Button
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
                          badgeNotificationCount: 13, // Fixed synchronization layout matching screen reference
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

  /// Adaptive, self-scaling layout tab component rendering tool
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
            
            // Scalable Alert Indicator Overlay Node
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
                  constraints: BoxConstraints(
                    minWidth: context.w(16),
                  ),
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
