import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nigergram/core/init/router/custom_page_builder_widget.dart';
import 'package:nigergram/core/utils/constants/enums/router_enum.dart';
import 'package:nigergram/features/auth/presentation/view/login_page.dart';
import 'package:nigergram/features/auth/presentation/view/verification_page.dart';
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

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

class AppRouter {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: _resolveInitialLocation(),
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            customPageBuilderWidget(context, state, const LoginPage()),
      ),
      GoRoute(
        path: '/verify',
        pageBuilder: (context, state) =>
            customPageBuilderWidget(context, state, const VerificationPage()),
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
      GoRoute(
        path: '/gist-hub',
        pageBuilder: (context, state) =>
            customPageBuilderWidget(context, state, const GistHubView()),
      ),
      // TODO: Uncomment when gist_create_post.dart is created
      // GoRoute(
      //   path: '/gist-hub/create',
      //   pageBuilder: (context, state) =>
      //       customPageBuilderWidget(context, state, const GistCreatePost()),
      // ),
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
                  'Loading video: $videoId',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        },
      ),
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
    ],
  );

  /// Determines the initial route purely from Supabase's session state,
  /// since Firebase Auth no longer exists in this app.
  static String _resolveInitialLocation() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return '/login';
    if (user.emailConfirmedAt == null) return '/verify';
    return RouterEnum.dashboardView.routeName;
  }
}
