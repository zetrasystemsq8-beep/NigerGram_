import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nigergram/core/config/localization/app_localizations.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/di/dependency_injector.dart';
import 'package:nigergram/core/init/router/app_router.dart';
import 'package:nigergram/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:nigergram/features/video_feed/presentation/bloc/video_feed_cubit.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final appRouter = getIt<AppRouter>();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          lazy: false,
          create: (_) => getIt<VideoFeedCubit>(),
        ),
        BlocProvider(
          create: (_) => AuthCubit(),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter.router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: NGColors.background,
          primaryColor: NGColors.accent,
        ),
      ),
    );
  }
}
