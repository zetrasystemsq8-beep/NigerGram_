import 'package:flutter/material.dart';
import 'package:nigergram/core/init/router/app_router.dart';
import 'package:nigergram/core/design_system/colors.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // We initialize the AppRouter here to manage the global state of navigation
    final appRouter = AppRouter();

    return MaterialApp.router(
      title: 'NigerGram',
      debugShowCheckedModeBanner: false,
      // Using the industrial-grade router configuration you provided
      routerConfig: appRouter.router,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: black,
        primaryColor: red, // Assuming red is defined in your colors.dart for Nigeria's flag theme
      ),
    );
  }
}
