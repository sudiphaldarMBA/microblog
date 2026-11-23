import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import '../auth/forgot_password_screen.dart';
import '../../main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ============================================================
  // DESIGN HELPERS
  // ============================================================

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color get _background =>
      _dark ? const Color(0xFF08090B) : const Color(0xFFF7F8FA);

  Color get _surface =>
      _dark ? const Color(0xFF15171B) : const Color(0xFFFFFFFF);

  Color get _text => _dark ? const Color(0xFFFFFFFF) : const Color(0xFF111318);

  Color get _muted => _dark ? const Color(0xFF9297A0) : const Color(0xFF737B86);

  Color get _divider =>
      _dark ? const Color(0xFF282B31) : const Color(0xFFE6E8EC);

  static const Color _accent = Color(0xFFF91880);

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,

      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _surface,
        titleSpacing: 20,
        title: Text(
          "Settings",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: _text,
          ),
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            // Settings menu
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _buildSectionHeader("Account & System Hub"),

                  _buildMenuRow(
                    icon: CupertinoIcons.settings_solid,
                    title: "Settings and privacy",
                    onTap: () {
                      _navigateTo(context, const _SettingsAndPrivacySubmenu());
                    },
                  ),

                  _buildMenuRow(
                    icon: CupertinoIcons.question_circle,
                    title: "Help and support",
                    onTap: () {
                      _showComingSoon("Help and support");
                    },
                  ),
                ],
              ),
            ),

            // Dark Mode section
            Container(
              color: _surface,
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Icon(
                      _dark
                          ? CupertinoIcons.moon_fill
                          : CupertinoIcons.sun_max_fill,
                      color: _accent,
                      size: 22,
                    ),
                    title: Text(
                      _dark ? 'Dark mode' : 'Light mode',
                      style: TextStyle(
                        color: _text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: _dark,
                    onChanged: (enabled) async {
                      final selectedTheme = enabled
                          ? ThemeMode.dark
                          : ThemeMode.light;

                      themeNotifier.value = selectedTheme;

                      final prefs = await SharedPreferences.getInstance();

                      await prefs.setString(
                        'microblog_theme',
                        enabled ? 'dark' : 'light',
                      );
                    },
                  ),
                  Divider(color: _divider, height: 1),
                ],
              ),
            ),

            // LOG OUT
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: OutlinedButton(
                onPressed: _executeLogout,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  foregroundColor: _text,
                  side: BorderSide(color: _divider, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  "Log out",
                  style: TextStyle(
                    color: _text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: _muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  // ============================================================
  // MAIN MENU ROW
  // ============================================================

  Widget _buildMenuRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return Container(
      color: _surface,
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: _accent, size: 22),
            title: Text(
              title,
              style: TextStyle(
                color: _text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: subtitle != null
                ? Text(subtitle, style: TextStyle(color: _muted, fontSize: 13))
                : null,
            trailing: Icon(
              CupertinoIcons.chevron_forward,
              color: _muted,
              size: 16,
            ),
            onTap: onTap,
          ),
          Divider(height: 1, indent: 56, color: _divider),
        ],
      ),
    );
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _navigateTo(BuildContext context, Widget target) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => target));
  }

  // ============================================================
  // COMING SOON
  // ============================================================

  void _showComingSoon(String featureName) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("$featureName options will be configurable later"),
        ),
      );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  void _executeLogout() {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: _surface,
          title: Text(
            "Log out",
            style: TextStyle(color: _text, fontWeight: FontWeight.w700),
          ),
          content: Text(
            "Are you sure you want to log out of your MicroBlog profile?",
            style: TextStyle(color: _muted),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
              },
              child: Text("Cancel", style: TextStyle(color: _muted)),
            ),
            TextButton(
              onPressed: () async {
                // Close the confirmation dialog.
                Navigator.pop(dialogCtx);

                try {
                  // Clear the saved authentication token.
                  await ApiService.logout();

                  if (!mounted) return;

                  // Remove all previous screens and open Login.
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                } catch (error) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Logout failed: $error")),
                  );
                }
              },
              child: Text(
                "Log Out",
                style: TextStyle(color: _text, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ==================================================================
// LEVEL 2
// SETTINGS AND PRIVACY
// ==================================================================

class _SettingsAndPrivacySubmenu extends StatelessWidget {
  const _SettingsAndPrivacySubmenu();

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final Color background = dark
        ? const Color(0xFF08090B)
        : const Color(0xFFF7F8FA);

    final Color surface = dark ? const Color(0xFF090A0C) : Colors.white;

    final Color text = dark ? Colors.white : const Color(0xFF111111);

    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        iconTheme: IconThemeData(color: text),
        title: Text(
          "Settings & Privacy",
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _buildSubmenuRow(
            context,
            icon: CupertinoIcons.person_crop_circle_fill,
            title: "Settings",
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _SettingsDeepSubmenu()),
              );
            },
          ),

          _buildSubmenuRow(
            context,
            icon: CupertinoIcons.shield_fill,
            title: "Privacy Center",
            onTap: () {
              _showNotification(context, "Privacy Center Options Coming Later");
            },
          ),

          _buildSubmenuRow(
            context,
            icon: CupertinoIcons.globe,
            title: "Language",
            onTap: () {
              _showNotification(
                context,
                "Language Selection Configuration Later",
              );
            },
          ),
        ],
      ),
    );
  }
  }

  Widget _buildSubmenuRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: dark ? const Color(0xFF090A0C) : Colors.white,
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: const Color(0xFFF91880), size: 22),
            title: Text(
              title,
              style: TextStyle(
                color: dark ? Colors.white : const Color(0xFF111111),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Icon(
              CupertinoIcons.chevron_forward,
              color: dark ? const Color(0xFF8D939C) : const Color(0xFF69707A),
              size: 16,
            ),
            onTap: onTap,
          ),

          Divider(
            height: 1,
            indent: 56,
            color: dark ? const Color(0xFF202328) : const Color(0xFFE7E9ED),
          ),
        ],
      ),
    );
  }

  void _showNotification(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)),
      );
  }

// ==================================================================
// LEVEL 3
// ACCOUNT SETTINGS
// ==================================================================

class _SettingsDeepSubmenu extends StatelessWidget {
  const _SettingsDeepSubmenu();

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final Color background = dark
        ? const Color(0xFF050505)
        : const Color(0xFFF7F8FA);

    final Color surface = dark ? const Color(0xFF090A0C) : Colors.white;

    final Color text = dark ? Colors.white : const Color(0xFF111111);

    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        iconTheme: IconThemeData(color: text),
        title: Text(
          "Account Settings",
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _buildSubmenuRow(
            context,
            icon: CupertinoIcons.person_2_fill,
            title: "Manage accounts",
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const _ManageAccountsSubmenu(),
                ),
              );
            },
          ),

          _buildSubmenuRow(
            context,
            icon: CupertinoIcons.lock_shield_fill,
            title: "Password and security",
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const _PasswordAndSecuritySubmenu(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  
  
  Widget _buildSubmenuRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: dark ? const Color(0xFF090A0C) : Colors.white,
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              icon,
              color: const Color(0xFFF91880),
              size: 22,
            ),
            title: Text(
              title,
              style: TextStyle(
                color: dark ? Colors.white : const Color(0xFF111111),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Icon(
              CupertinoIcons.chevron_forward,
              color: dark
                  ? const Color(0xFF8D939C)
                  : const Color(0xFF69707A),
              size: 16,
            ),
            onTap: onTap,
          ),
          Divider(
            height: 1,
            indent: 56,
            color: dark
                ? const Color(0xFF202328)
                : const Color(0xFFE7E9ED),
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// LEVEL 4
// MANAGE ACCOUNTS
// ==================================================================

class _ManageAccountsSubmenu extends StatelessWidget {
  const _ManageAccountsSubmenu();

  
@override
Widget build(BuildContext context) {
  final bool dark =
      Theme.of(context).brightness == Brightness.dark;

  final Color background = dark
      ? const Color(0xFF050505)
      : const Color(0xFFF7F8FA);

  final Color surface =
      dark ? const Color(0xFF090A0C) : Colors.white;

  final Color text =
      dark ? Colors.white : const Color(0xFF111111);

  return Scaffold(
    backgroundColor: background,

    appBar: AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: surface,
      iconTheme: IconThemeData(color: text),
      title: Text(
        "Password & Security",
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    ),

    body: ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        _buildSubmenuRow(
          context,
          icon: CupertinoIcons.padlock_solid,
          title: "Change password",
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const _ChangePasswordScreen(),
              ),
            );
          },
        ),

        _buildSubmenuRow(
          context,
          icon: CupertinoIcons.camera_viewfinder,
          title: "Verification selfie",
          onTap: () {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text(
                    "Verification selfie setup is coming next.",
                  ),
                ),
              );
          },
        ),

        _buildSubmenuRow(
          context,
          icon: CupertinoIcons.device_phone_portrait,
          title: "Where you're logged in",
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const _LoggedInDevicesScreen(),
              ),
            );
          },
        ),
      ],
    ),
  );
}

Widget _buildSubmenuRow(
  BuildContext context, {
  required IconData icon,
  required String title,
  required VoidCallback onTap,
}) {
  final bool dark =
      Theme.of(context).brightness == Brightness.dark;

  return Container(
    color: dark
        ? const Color(0xFF090A0C)
        : Colors.white,
    child: Column(
      children: [
        ListTile(
          leading: Icon(
            icon,
            color: const Color(0xFFF91880),
            size: 22,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: dark
                  ? Colors.white
                  : const Color(0xFF111111),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Icon(
            CupertinoIcons.chevron_forward,
            color: dark
                ? const Color(0xFF8D939C)
                : const Color(0xFF69707A),
            size: 16,
          ),
          onTap: onTap,
        ),

        Divider(
          height: 1,
          indent: 56,
          color: dark
              ? const Color(0xFF202328)
              : const Color(0xFFE7E9ED),
        ),
      ],
    ),
  );
}
}

// ==================================================================
// LEVEL 4
// PASSWORD AND SECURITY
// ==================================================================

class _PasswordAndSecuritySubmenu extends StatelessWidget {
  const _PasswordAndSecuritySubmenu();

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final Color background = dark
        ? const Color(0xFF050505)
        : const Color(0xFFF7F8FA);

    final Color surface = dark ? const Color(0xFF090A0C) : Colors.white;

    final Color text = dark ? Colors.white : const Color(0xFF111111);

    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        iconTheme: IconThemeData(color: text),
        title: Text(
          "Password & Security",
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          
          _buildSubmenuRow(
            context,
            icon: CupertinoIcons.padlock_solid,
            title: "Change password",
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const _ChangePasswordScreen(),
                ),
              );
            },
          ),

          _buildSubmenuRow(
            context,
            icon: CupertinoIcons.camera_viewfinder,
            title: "Verification selfie",
            onTap: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Verification selfie setup is coming next.",
                    ),
                  ),
                );
            },
          ),

          _buildSubmenuRow(
            context,
            icon: CupertinoIcons.device_phone_portrait,
            title: "Where you're logged in",
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const _LoggedInDevicesScreen(),
                ),
              );
            },
          ),

        ],
      ),
    );
  }

  Widget _buildSubmenuRow(
  BuildContext context, {
  required IconData icon,
  required String title,
  required VoidCallback onTap,
}) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: dark ? const Color(0xFF090A0C) : Colors.white,
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: const Color(0xFFF91880), size: 22),
            title: Text(
              title,
              style: TextStyle(
                color: dark ? Colors.white : const Color(0xFF111111),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Icon(
              CupertinoIcons.chevron_forward,
              color: dark ? const Color(0xFF8D939C) : const Color(0xFF69707A),
              size: 16,
            ),
                        onTap: () {
              if (title == "Where you're logged in") {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const _LoggedInDevicesScreen(),
                  ),
                );
                return;
              }

              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text("$title configuration view setup later"),
                  ),
                );
            },
          ),

          Divider(
            height: 1,
            indent: 56,
            color: dark ? const Color(0xFF202328) : const Color(0xFFE7E9ED),
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// DEACTIVATION / DELETION
// ==================================================================

class _DeactivationOrDeletionScreen extends StatelessWidget {
  const _DeactivationOrDeletionScreen();

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final Color background = dark ? const Color(0xFF050505) : Colors.white;

    final Color surface = dark ? const Color(0xFF090A0C) : Colors.white;

    final Color text = dark ? Colors.white : const Color(0xFF111111);

    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        iconTheme: IconThemeData(color: text),
        title: Text(
          "Deactivate or Delete",
          style: TextStyle(
            color: text,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildActionCard(
            context,
            title: "Deactivate account",
            description:
                "Temporarily hide your profile content and feed shares from MicroBlog view networks.",
          ),

          const SizedBox(height: 16),

          _buildActionCard(
            context,
            title: "Delete account",
            description:
                "Permanently erase your account database instance, authorization token keys, and uploaded posts.",
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String description,
    bool isDestructive = false,
  }) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final Color cardColor = dark
        ? const Color(0xFF17191C)
        : const Color(0xFFF1F3F5);

    final Color normalText = dark ? Colors.white : Colors.black;

    final Color muted = dark
        ? const Color(0xFF8D939C)
        : const Color(0xFF69707A);

    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                content: Text("Initiating $title confirmation flow"),
              ),
            );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDestructive ? Colors.redAccent : normalText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                description,
                style: TextStyle(color: muted, fontSize: 13.5, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// ADD ACCOUNT
// ==================================================================

class _AddAccountScreen extends StatefulWidget {
  const _AddAccountScreen();

  @override
  State<_AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<_AddAccountScreen> {
  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final Color background = dark ? const Color(0xFF050505) : Colors.white;

    final Color surface = dark ? const Color(0xFF090A0C) : Colors.white;

    final Color text = dark ? Colors.white : const Color(0xFF111111);

    final Color muted = dark
        ? const Color(0xFF8D939C)
        : const Color(0xFF69707A);

    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        iconTheme: IconThemeData(color: text),
        title: Text(
          "Add Account",
          style: TextStyle(
            color: text,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              Text(
                "Log in to Another Account",
                style: TextStyle(
                  color: text,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: text),
                decoration: InputDecoration(
                  labelText: "Email address or mobile number",
                  labelStyle: TextStyle(color: muted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: dark
                          ? const Color(0xFF30343A)
                          : const Color(0xFFD7DADF),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: TextStyle(color: text),
                decoration: InputDecoration(
                  labelText: "Password",
                  labelStyle: TextStyle(color: muted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: dark
                          ? const Color(0xFF30343A)
                          : const Color(0xFFD7DADF),
                    ),
                  ),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? CupertinoIcons.eye
                          : CupertinoIcons.eye_slash,
                      color: muted,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text(
                            "Multiple account login will be connected later",
                          ),
                        ),
                      );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF91880),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Log in",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text(
                          "Password recovery will be configured later",
                        ),
                      ),
                    );
                },
                child: const Text(
                  "Forgotten password?",
                  style: TextStyle(color: Color(0xFF1D9BF0)),
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text(
                            "Account creation will be connected later",
                          ),
                        ),
                      );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1D9BF0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Create new account",
                    style: TextStyle(
                      color: Color(0xFF1D9BF0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}


class _LoggedInDevicesScreen extends StatefulWidget {
  const _LoggedInDevicesScreen();

  @override
  State<_LoggedInDevicesScreen> createState() =>
      _LoggedInDevicesScreenState();
}

class _LoggedInDevicesScreenState
    extends State<_LoggedInDevicesScreen> {
  bool _loading = true;
  bool _processing = false;

  String? _error;
  List<Map<String, dynamic>> _sessions = [];

  bool get _dark =>
      Theme.of(context).brightness == Brightness.dark;

  Color get _background =>
      _dark ? const Color(0xFF08090B) : const Color(0xFFF7F8FA);

  Color get _surface =>
      _dark ? const Color(0xFF15171B) : Colors.white;

  Color get _text =>
      _dark ? Colors.white : const Color(0xFF111318);

  Color get _muted =>
      _dark ? const Color(0xFF9297A0) : const Color(0xFF737B86);

  Color get _divider =>
      _dark ? const Color(0xFF282B31) : const Color(0xFFE6E8EC);

  static const Color _accent = Color(0xFFF91880);

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await ApiService.getSessions();

      if (response['success'] != true) {
        throw Exception(
          response['message'] ?? 'Unable to load login sessions',
        );
      }

      final data = response['data'];

      final rawSessions = data is Map
          ? data['sessions']
          : null;

      final sessions = rawSessions is List
          ? rawSessions
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;

      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _revokeSession(
    Map<String, dynamic> session,
  ) async {
    final sessionId = session['sessionId']?.toString() ?? '';

    if (sessionId.isEmpty || _processing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        title: Text(
          'Sign out this device?',
          style: TextStyle(color: _text),
        ),
        content: Text(
          'This device will no longer be able to access your account.',
          style: TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: _muted),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text(
              'Sign out',
              style: TextStyle(color: _accent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);

    try {
      final response = await ApiService.revokeSession(
        sessionId: sessionId,
      );

      if (response['success'] != true) {
        throw Exception(
          response['message'] ?? 'Unable to sign out device',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device signed out successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadSessions();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _revokeOtherSessions() async {
    if (_processing) return;

    final otherSessions = _sessions
        .where((session) => session['isCurrent'] != true)
        .length;

    if (otherSessions == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        title: Text(
          'Log out of other devices?',
          style: TextStyle(color: _text),
        ),
        content: Text(
          'You will be signed out of $otherSessions other '
          'device(s). Your current device will remain logged in.',
          style: TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: _muted),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text(
              'Log out',
              style: TextStyle(color: _accent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);

    try {
      final response = await ApiService.revokeOtherSessions();

      if (response['success'] != true) {
        throw Exception(
          response['message'] ??
              'Unable to log out other devices',
        );
      }

      if (!mounted) return;

      final data = response['data'];
      final count = data is Map
          ? data['revokedCount'] ?? 0
          : 0;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count other device(s) signed out'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadSessions();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  IconData _deviceIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'mobile':
        return CupertinoIcons.device_phone_portrait;
      case 'tablet':
        return Icons.tablet_android;
      case 'desktop':
        return CupertinoIcons.desktopcomputer;
      case 'web':
        return CupertinoIcons.globe;
      default:
        return CupertinoIcons.device_laptop;
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Unknown';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return 'Unknown';

    final difference = DateTime.now().difference(date.toLocal());

    if (difference.isNegative || difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  Widget _buildSessionCard(
    Map<String, dynamic> session,
  ) {
    final isCurrent = session['isCurrent'] == true;

    final deviceName =
        session['deviceName']?.toString().trim();

    final deviceType =
        session['deviceType']?.toString() ?? 'unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              _deviceIcon(deviceType),
              color: _accent,
              size: 24,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName == null || deviceName.isEmpty
                      ? 'Unknown device'
                      : deviceName,
                  style: TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  deviceType[0].toUpperCase() +
                      deviceType.substring(1),
                  style: TextStyle(
                    color: _muted,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Last active: ${_formatDate(session['lastActiveAt'])}',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                  ),
                ),

                if (isCurrent) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'CURRENT DEVICE',
                      style: TextStyle(
                        color: _accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (!isCurrent)
            TextButton(
              onPressed: _processing
                  ? null
                  : () => _revokeSession(session),
              child: const Text(
                'Sign out',
                style: TextStyle(
                  color: _accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final otherSessions = _sessions
        .where((session) => session['isCurrent'] != true)
        .length;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _surface,
        iconTheme: IconThemeData(color: _text),
        title: Text(
          "Where you're logged in",
          style: TextStyle(
            color: _text,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading || _processing
                ? null
                : _loadSessions,
            icon: Icon(
              CupertinoIcons.refresh,
              color: _text,
            ),
          ),
        ],
      ),

      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: _accent,
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_circle,
                          color: _accent,
                          size: 42,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _text),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadSessions,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: _accent,
                  onRefresh: _loadSessions,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(18),
                    children: [
                      Text(
                        'Your login activity',
                        style: TextStyle(
                          color: _text,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 7),

                      Text(
                        'These are the devices currently signed '
                        'in to your MicroBlog account.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 22),

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'ACTIVE DEVICES (${_sessions.length})',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 13),

                      if (_sessions.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _divider),
                          ),
                          child: Text(
                            'No active login sessions found.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted),
                          ),
                        )
                      else
                        ..._sessions.map(_buildSessionCard),

                      if (otherSessions > 0) ...[
                        const SizedBox(height: 18),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _processing
                                ? null
                                : _revokeOtherSessions,
                            icon: const Icon(
                              CupertinoIcons.square_arrow_right,
                              size: 18,
                            ),
                            label: const Text(
                              'Log out of all other devices',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _accent,
                              side: const BorderSide(
                                color: _accent,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      Text(
                        'If you see a device you do not recognize, '
                        'sign it out and consider changing your password.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}


class _ChangePasswordScreen extends StatefulWidget {
  const _ChangePasswordScreen({super.key});

  @override
  State<_ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState
    extends State<_ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;

  static const Color _accent = Color(0xFFF91880);

  bool get _dark =>
      Theme.of(context).brightness == Brightness.dark;

  Color get _background =>
      _dark ? const Color(0xFF08090B) : const Color(0xFFF7F8FA);

  Color get _surface =>
      _dark ? const Color(0xFF15171B) : Colors.white;

  Color get _text =>
      _dark ? Colors.white : const Color(0xFF111318);

  Color get _muted =>
      _dark ? const Color(0xFF9297A0) : const Color(0xFF737B86);

  Color get _border =>
      _dark ? const Color(0xFF282B31) : const Color(0xFFE6E8EC);

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? Colors.red.shade700 : _accent,
          content: Text(message),
        ),
      );
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _showMessage(
          result['message']?.toString() ??
              'Password changed successfully.',
        );

        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        Navigator.of(context).pop();
      } else {
        _showMessage(
          result['message']?.toString() ??
              'Unable to change password.',
          error: true,
        );
      }
    } catch (error) {
      _showMessage(
        'Unable to change password. Please try again.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildPasswordField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool visible,
    required VoidCallback onVisibilityChanged,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _text,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        TextFormField(
          controller: controller,
          obscureText: !visible,
          style: TextStyle(
            color: _text,
            fontSize: 15,
          ),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _muted),
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 17,
            ),
            suffixIcon: IconButton(
              onPressed: onVisibilityChanged,
              icon: Icon(
                visible
                    ? CupertinoIcons.eye_slash
                    : CupertinoIcons.eye,
                color: _muted,
                size: 20,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(
                color: _accent,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _surface,
        iconTheme: IconThemeData(color: _text),
        title: Text(
          'Change password',
          style: TextStyle(
            color: _text,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.lock_shield_fill,
                    color: _accent,
                    size: 31,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Keep your account secure',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _text,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Choose a strong password that you do not use '
                'on other websites or apps.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 30),

              _buildPasswordField(
                label: 'Current password',
                hint: 'Enter your current password',
                controller: _currentPasswordController,
                visible: _showCurrentPassword,
                onVisibilityChanged: () {
                  setState(() {
                    _showCurrentPassword = !_showCurrentPassword;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter your current password';
                  }
                  return null;
                },
              
                 ),

              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const ForgotPasswordScreen(),
    ),
  );
},
                  style: TextButton.styleFrom(
                    foregroundColor: _accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                  ),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              _buildPasswordField(
                label: 'New password',
                hint: 'Enter your new password',
                controller: _newPasswordController,
                visible: _showNewPassword,
                onVisibilityChanged: () {
                  setState(() {
                    _showNewPassword = !_showNewPassword;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter a new password';
                  }

                  if (value.length < 8) {
                    return 'Password must contain at least 8 characters';
                  }

                  if (value.length > 128) {
                    return 'Password must not exceed 128 characters';
                  }

                  if (value == _currentPasswordController.text) {
                    return 'New password must differ from current password';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              _buildPasswordField(
                label: 'Confirm new password',
                hint: 'Re-enter your new password',
                controller: _confirmPasswordController,
                visible: _showConfirmPassword,
                onVisibilityChanged: () {
                  setState(() {
                    _showConfirmPassword = !_showConfirmPassword;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirm your new password';
                  }

                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              Text(
                'Your password must be at least 8 characters long.',
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    disabledBackgroundColor:
                        _accent.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save new password',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
