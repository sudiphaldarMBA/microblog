import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../screens/splash/splash_screen.dart';

class MicroBlogApp extends StatelessWidget {
  const MicroBlogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MicroBlog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}