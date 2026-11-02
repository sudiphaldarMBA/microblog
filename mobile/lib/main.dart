import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';

final ValueNotifier<ThemeMode> themeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.dark);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  final savedTheme = prefs.getString('microblog_theme');

  themeNotifier.value = savedTheme == 'light'
      ? ThemeMode.light
      : ThemeMode.dark;

  runApp(const MicroBlogApp());
}