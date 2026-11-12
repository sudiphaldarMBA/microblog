
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/app.dart';
import 'firebase_options.dart';

final ValueNotifier<ThemeMode> themeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.dark);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Load saved theme preference.
  final prefs = await SharedPreferences.getInstance();

  final savedTheme = prefs.getString('microblog_theme');

  themeNotifier.value = savedTheme == 'light'
      ? ThemeMode.light
      : ThemeMode.dark;

  runApp(const MicroBlogApp());
}
