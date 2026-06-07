import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/constants/enums/router_enum.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BottomNavigationWidget extends StatelessWidget {
  const BottomNavigationWidget({required this.location, super.key, this.child, this.backgroundColor});

  final Widget? child;
  final String location;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      backgroundColor: backgroundColor,
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(splashColor: transparent, highlightColor: transparent),
        child: BottomNavigationBar(
          key: ValueKey(location),
          currentIndex: _calculateSelectedIndex(context),
          selectedItemColor: black,
          unselectedItemColor: black54,
          onTap: (index) => _onItemTapped(index, context),
          showSelectedLabels: false,
          showUnselectedLabels: false,
          selectedFontSize: 0,
          unselectedFontSize: 0,
          items: [
            BottomNavigationBarItem(
              label: '',
              icon: Icon(LucideIcons.house, size: context.sq(28)),
              activeIcon: Icon(LucideIcons.house, size: context.sq(28)),
            ),
            BottomNavigationBarItem(
              label: '',
              icon: Icon(LucideIcons.tvMinimalPlay, size: context.sq(28)),
              activeIcon: Icon(LucideIcons.tvMinimalPlay, size: context.sq(28)),
            ),
            BottomNavigationBarItem(
              label: '',
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(LucideIcons.plus, size: context.sq(24), color: Colors.white),
              ),
              activeIcon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(LucideIcons.plus, size: context.sq(24), color: Colors.white),
              ),
            ),
            BottomNavigationBarItem(
              label: '',
              icon: Icon(LucideIcons.circleUser, size: context.sq(28)),
              activeIcon: Icon(LucideIcons.circleUser, size: context.sq(28)),
            ),
          ],
        ),
      ),
    );
  }
}

int _calculateSelectedIndex(BuildContext context) {
  final String location = GoRouterState.of(context).uri.toString();
  if (location == RouterEnum.dashboardView.routeName) return 0;
  if (location == RouterEnum.videoFeedView.routeName) return 1;
  if (location == RouterEnum.profileView.routeName) return 3;
  return 0;
}

void _onItemTapped(int index, BuildContext context) {
  switch (index) {
    case 0:
      GoRouter.of(context).go(RouterEnum.dashboardView.routeName);
    case 1:
      GoRouter.of(context).go(RouterEnum.videoFeedView.routeName);
    case 2:
      GoRouter.of(context).push(RouterEnum.uploadView.routeName);
    case 3:
      GoRouter.of(context).go(RouterEnum.profileView.routeName);
  }
}
