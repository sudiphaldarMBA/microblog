import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

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
      _dark ? const Color(0xFF050505) : const Color(0xFFF7F8FA);

  Color get _surface => _dark ? const Color(0xFF090A0C) : Colors.white;

  Color get _text => _dark ? Colors.white : const Color(0xFF111111);

  Color get _muted => _dark ? const Color(0xFF8D939C) : const Color(0xFF69707A);

  Color get _divider =>
      _dark ? const Color(0xFF202328) : const Color(0xFFE7E9ED);

  static const Color _blue = Color(0xFF1D9BF0);

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

                  _buildMenuRow(
                    icon: CupertinoIcons.brightness,
                    title: "Dark mode",
                    onTap: () {
                      _showComingSoon("Dark mode toggle");
                    },
                  ),
                ],
              ),
            ),

            // ====================================================
            // LOG OUT
            // ====================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: OutlinedButton(
                onPressed: _executeLogout,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(
                    color: _dark
                        ? Colors.redAccent.withValues(alpha: 0.5)
                        : Colors.redAccent,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Log out",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
            leading: Icon(
              icon,
              color: _dark ? _blue : const Color(0xFF69707A),
              size: 22,
            ),
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
              onPressed: () {
                Navigator.pop(dialogCtx);

                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text("Logging out..."),
                    ),
                  );
              },
              child: const Text(
                "Log Out",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
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
            leading: const Icon(CupertinoIcons.chevron_right),
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
            leading: Icon(icon, color: const Color(0xFF1D9BF0), size: 22),
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
}

// ==================================================================
// LEVEL 4
// MANAGE ACCOUNTS
// ==================================================================

class _ManageAccountsSubmenu extends StatelessWidget {
  const _ManageAccountsSubmenu();

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
          "Manage Accounts",
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
            icon: CupertinoIcons.clear_circled_solid,
            title: "Deactivation or deletion",
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const _DeactivationOrDeletionScreen(),
                ),
              );
            },
          ),

          _buildSubmenuRow(
            context,
            icon: CupertinoIcons.person_add_solid,
            title: "Add account",
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _AddAccountScreen()),
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
            leading: Icon(icon, color: const Color(0xFF1D9BF0), size: 22),
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
          ),

          _buildSubmenuRow(
            context,
            icon: CupertinoIcons.camera_viewfinder,
            title: "Verification selfie",
          ),

          _buildSubmenuRow(
            context,
            icon: CupertinoIcons.device_phone_portrait,
            title: "Where you're logged in",
          ),
        ],
      ),
    );
  }

  Widget _buildSubmenuRow(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: dark ? const Color(0xFF090A0C) : Colors.white,
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: const Color(0xFF1D9BF0), size: 22),
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
                    backgroundColor: const Color(0xFF1D9BF0),
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
