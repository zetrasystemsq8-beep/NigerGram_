// lib/core/init/router/app_router.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nigergram/core/init/router/custom_page_builder_widget.dart';
import 'package:nigergram/core/utils/constants/enums/router_enum.dart';
import 'package:nigergram/features/auth/presentation/view/login_page.dart';
import 'package:nigergram/features/auth/presentation/view/register_page.dart';
import 'package:nigergram/features/dashboard/presentation/view/dashboard_view.dart';
import 'package:nigergram/features/profile/presentation/view/profile_view.dart';
import 'package:nigergram/features/upload/presentation/view/upload_page.dart';
import 'package:nigergram/features/video_feed/presentation/view/video_feed_view.dart';
import 'package:nigergram/features/video_feed/presentation/view/discover_feed_view.dart';
import 'package:nigergram/features/wallet/presentation/view/wallet_home_view.dart';
import 'package:nigergram/features/wallet/presentation/view/fund_wallet_view.dart';
import 'package:nigergram/features/wallet/presentation/view/withdraw_view.dart';
import 'package:nigergram/features/wallet/presentation/view/creator_earnings_view.dart';
import 'package:nigergram/features/gist_hub/presentation/view/gist_hub_view.dart';
// ❌ REMOVED: gist_create_post.dart - file doesn't exist yet
// ❌ REMOVED: gist_detail_view.dart - file doesn't exist yet

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

class AppRouter {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            return '/dashboard';
          } else {
            return '/login';
          }
        },
      ),
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
        path: '/dashboard',
        pageBuilder: (context, state) =>
            customPageBuilderWidget(context, state, const DashboardView()),
      ),
      GoRoute(
        path: '/video-feed',
        pageBuilder: (context, state) =>
            customPageBuilderWidget(context, state, const VideoFeedView()),
      ),
      GoRoute(
        path: '/video/:videoId',
        pageBuilder: (context, state) {
          final videoId = state.pathParameters['videoId']!;
          return customPageBuilderWidget(
            context,
            state,
            Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                iconTheme: const IconThemeData(color: Colors.white),
                title: const Text('Video', style: TextStyle(color: Colors.white)),
              ),
              body: Center(
                child: Text(
                  'Video: $videoId',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/video-detail/:videoId',
        pageBuilder: (context, state) {
          final videoId = state.pathParameters['videoId']!;
          return customPageBuilderWidget(
            context,
            state,
            Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                iconTheme: const IconThemeData(color: Colors.white),
                title: const Text('Video', style: TextStyle(color: Colors.white)),
              ),
              body: Center(
                child: Text(
                  'Video: $videoId',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/profile/:userId',
        pageBuilder: (context, state) {
          final userId = state.pathParameters['userId'] ??
              FirebaseAuth.instance.currentUser?.uid ?? '';
          return customPageBuilderWidget(
            context,
            state,
            ProfileView(userId: userId),
          );
        },
      ),
      GoRoute(
        path: '/profile',
        redirect: (context, state) {
          final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
          return '/profile/$userId';
        },
      ),
      GoRoute(
        path: '/upload',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            customPageBuilderWidget(context, state, const UploadPage()),
      ),
      GoRoute(
        path: '/gist-hub',
        pageBuilder: (context, state) =>
            customPageBuilderWidget(context, state, const GistHubView()),
      ),
      // TODO: Uncomment when gist_create_post.dart is created
      // GoRoute(
      //   path: '/gist/create',
      //   pageBuilder: (context, state) =>
      //       customPageBuilderWidget(context, state, const GistCreatePost()),
      // ),
      // TODO: Uncomment when gist_detail_view.dart is created
      // GoRoute(
      //   path: '/gist/:gistId',
      //   pageBuilder: (context, state) =>
      //       customPageBuilderWidget(context, state, const GistDetailView()),
      // ),
      GoRoute(
        path: '/discover',
        pageBuilder: (context, state) {
          final tag = state.uri.queryParameters['tag'] ?? '';
          return customPageBuilderWidget(
            context,
            state,
            DiscoverFeedView(tag: tag),
          );
        },
      ),
      GoRoute(
        path: '/wallet',
        pageBuilder: (context, state) =>
            customPageBuilderWidget(context, state, const WalletHomeView()),
      ),
      GoRoute(
        path: '/wallet/fund',
        pageBuilder: (context, state) =>
            customPageBuilderWidget(context, state, const FundWalletView()),
      ),
      GoRoute(
        path: '/wallet/withdraw',
        pageBuilder: (context, state) =>
            customPageBuilderWidget(context, state, const WithdrawView()),
      ),
      GoRoute(
        path: '/wallet/earnings',
        pageBuilder: (context, state) =>
            customPageBuilderWidget(context, state, const CreatorEarningsView()),
      ),
      GoRoute(
        path: '/:page',
        pageBuilder: (context, state) => customPageBuilderWidget(
          context,
          state,
          Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded,
                      color: Colors.grey.shade600, size: 80),
                  const SizedBox(height: 24),
                  const Text('404',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Page Not Found',
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 20)),
                  const SizedBox(height: 12),
                  Text(
                      'The page you are looking for does not exist.',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 14)),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/dashboard'),
                    icon: const Icon(Icons.home, color: Colors.white),
                    label: const Text('Go Home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
