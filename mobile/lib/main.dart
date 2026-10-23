import 'package:flutter/material.dart';
import 'app/app.dart';

// GLOBAL VALUE NOTIFIER CONTROLLER
// This sits at the top level so your navigation drawer can access it directly.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(
  ThemeMode.dark,
);

void main() {
  runApp(const MicroBlogApp());
}
