import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nigergram/core/init/router/custom_page_builder_widget.dart';
import 'package:nigergram/core/utils/constants/enums/router_enum.dart';
import 'package:nigergram/features/auth/presentation/view/login_page.dart';
import 'package:nigergram/features/auth/presentation/view/register_page.dart';
import 'package:nigergram/features/dashboard/presentation/view/dashboard_view.dart';
import 'package:nigergram/features/profile/presentation/view/profile_view.dart';
import 'package:nigergram/features/upload/presentation/view/upload_page.dart';
import 'package:nigergram/features/video_feed/presentation/view/video_feed_view.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

class AppRouter {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: FirebaseAuth.instance.currentUser != null
        ? RouterEnum.dashboardView.routeName
        : '/login',
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            customPageBuilderWidget(context, state, const LoginPage()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) =>
            customPageBuilderWidget(context, state, const RegisterPage()),
      ),
      GoRoute(
        path: RouterEnum.uploadView.routeName,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            customPageBuilderWidget(context, state, const UploadPage()),
      ),
      GoRoute(
        path: RouterEnum.dashboardView.routeName,
        pageBuilder: (context, state) =>
            customPageBuilderWidget(context, state, const DashboardView()),
      ),
      GoRoute(
        path: RouterEnum.videoFeedView.routeName,
        pageBuilder: (context, state) =>
            customPageBuilderWidget(context, state, const VideoFeedView()),
      ),
      GoRoute(
        path: RouterEnum.profileView.routeName,
        pageBuilder: (context, state) =>
            customPageBuilderWidget(context, state, const ProfileView()),
      ),
    ],
  );
}
