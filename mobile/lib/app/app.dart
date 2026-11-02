
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../screens/splash/splash_screen.dart';
import '../main.dart';

class MicroBlogApp extends StatelessWidget {
  const MicroBlogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentThemeMode, child) {
        return MaterialApp(
          title: 'MicroBlog',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentThemeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
