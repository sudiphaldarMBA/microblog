import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../screens/splash/splash_screen.dart';
import '../main.dart'; // Import themeNotifier from main.dart

class MicroBlogApp extends StatelessWidget {
  const MicroBlogApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to changes in the global theme notifier state
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentThemeMode, _) {
        return MaterialApp(
          title: 'MicroBlog',
          debugShowCheckedModeBanner: false,

          // Connect our new explicit black and white profiles
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentThemeMode,

          home: const SplashScreen(),
        );
      },
    );
  }
}
