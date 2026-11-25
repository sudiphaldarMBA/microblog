import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import '../auth/forgot_password_screen.dart';
import '../../main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'verification_selfie_screen.dart';


// ==================================================================
// SHARED DESIGN HELPERS
// Icons / accents are now black (light mode) and white (dark mode).
// ==================================================================

class _SC {
  final bool dark;
  _SC.of(BuildContext context)
      : dark = Theme.of(context).brightness == Brightness.dark;

  Color get background =>
      dark ? const Color(0xFF08090B) : const Color(0xFFF7F8FA);
  Color get surface => dark ? const Color(0xFF15171B) : Colors.white;
  Color get text => dark ? Colors.white : const Color(0xFF111318);
  Color get muted => dark ? const Color(0xFF9297A0) : const Color(0xFF737B86);
  Color get divider => dark ? const Color(0xFF282B31) : const Color(0xFFE6E8EC);

  /// Icons and accents: white in dark mode, black in light mode.
  Color get icon => dark ? Colors.white : Colors.black;

  /// Text/icon colour used on top of a filled `icon`-coloured button.
  Color get onIcon => dark ? Colors.black : Colors.white;
}

void _snack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.red.shade700 : null,
        content: Text(message),
      ),
    );
}

void _push(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

/// One menu row (icon + title + chevron + divider).
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = _SC.of(context);

    return Container(
      color: c.surface,
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: c.icon, size: 22),
            title: Text(
              title,
              style: TextStyle(
                color: c.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: subtitle != null
                ? Text(subtitle!, style: TextStyle(color: c.muted, fontSize: 13))
                : null,
            trailing: Icon(
              CupertinoIcons.chevron_forward,
              color: c.muted,
              size: 16,
            ),
            onTap: onTap,
          ),
          Divider(height: 1, indent: 56, color: c.divider),
        ],
      ),
    );
  }
}

/// Reusable page: app bar with back arrow + list of children.
class _SubPage extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SubPage({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = _SC.of(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.surface,
        iconTheme: IconThemeData(color: c.text),
        title: Text(
          title,
          style: TextStyle(
            color: c.text,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: children,
      ),
    );
  }
}

// ==================================================================
// LEVEL 1 — MAIN SETTINGS SCREEN
// ==================================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final c = _SC.of(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.surface,
        titleSpacing: 20,
        title: Text(
          "Settings",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: c.text,
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
                  _buildSectionHeader(c, "Account & System Hub"),

                  _MenuRow(
                    icon: CupertinoIcons.settings_solid,
                    title: "Settings and privacy",
                    onTap: () => _push(context, const _SettingsAndPrivacyScreen()),
                  ),

                  _MenuRow(
                    icon: CupertinoIcons.question_circle,
                    title: "Help and support",
                    onTap: () => _push(context, const _HelpAndSupportScreen()),
                  ),

                  _MenuRow(
                    icon: CupertinoIcons.doc_text,
                    title: "Privacy policy",
                    onTap: () => _push(context, const _PrivacyPolicyScreen()),
                  ),

                  _MenuRow(
                    icon: CupertinoIcons.globe,
                    title: "Languages",
                    onTap: () => _push(context, const _LanguagesScreen()),
                  ),
                ],
              ),
            ),

            // Dark / Light mode
            Container(
              color: c.surface,
              child: Column(
                children: [
                  Divider(color: c.divider, height: 1),
                  SwitchListTile(
                    secondary: Icon(
                      c.dark
                          ? CupertinoIcons.moon_fill
                          : CupertinoIcons.sun_max_fill,
                      color: c.icon,
                      size: 22,
                    ),
                    title: Text(
                      c.dark ? 'Dark mode' : 'Light mode',
                      style: TextStyle(
                        color: c.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    activeThumbColor: c.icon,
                    activeTrackColor: c.icon.withValues(alpha: 0.35),
                    value: c.dark,
                    onChanged: (enabled) async {
                      themeNotifier.value =
                          enabled ? ThemeMode.dark : ThemeMode.light;

                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(
                        'microblog_theme',
                        enabled ? 'dark' : 'light',
                      );
                    },
                  ),
                  Divider(color: c.divider, height: 1),
                ],
              ),
            ),

            // Log out
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: OutlinedButton(
                onPressed: _executeLogout,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  foregroundColor: c.text,
                  side: BorderSide(color: c.icon, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  "Log out",
                  style: TextStyle(
                    color: c.text,
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

  Widget _buildSectionHeader(_SC c, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: c.muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  void _executeLogout() {
    final c = _SC.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: c.surface,
          title: Text(
            "Log out",
            style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
          ),
          content: Text(
            "Are you sure you want to log out of your MicroBlog profile?",
            style: TextStyle(color: c.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text("Cancel", style: TextStyle(color: c.muted)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);

                try {
                  await ApiService.logout();

                  if (!mounted) return;

                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                } catch (error) {
                  if (!mounted) return;
                  _snack(context, "Logout failed: $error", error: true);
                }
              },
              child: Text(
                "Log Out",
                style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ==================================================================
// LEVEL 2 — SETTINGS AND PRIVACY
//   • Manage accounts
//   • Password and security
// ==================================================================

class _SettingsAndPrivacyScreen extends StatelessWidget {
  const _SettingsAndPrivacyScreen();

  @override
  Widget build(BuildContext context) {
    return _SubPage(
      title: "Settings & Privacy",
      children: [
        _MenuRow(
          icon: CupertinoIcons.person_2_fill,
          title: "Manage accounts",
          onTap: () => _push(context, const _ManageAccountsScreen()),
        ),
        _MenuRow(
          icon: CupertinoIcons.lock_shield_fill,
          title: "Password and security",
          onTap: () => _push(context, const _PasswordAndSecurityScreen()),
        ),
      ],
    );
  }
}

// ==================================================================
// LEVEL 3 — MANAGE ACCOUNTS
//   • Account information
//   • Deactivation or deletion
//   • Add another account
// ==================================================================

class _ManageAccountsScreen extends StatelessWidget {
  const _ManageAccountsScreen();

  @override
  Widget build(BuildContext context) {
    return _SubPage(
      title: "Manage accounts",
      children: [
        _MenuRow(
          icon: CupertinoIcons.person_crop_circle,
          title: "Account information",
          onTap: () => _snack(context, "Account information is coming soon"),
        ),
        _MenuRow(
          icon: CupertinoIcons.person_crop_circle_badge_xmark,
          title: "Deactivation or deletion",
          onTap: () => _push(context, const _DeactivationOrDeletionScreen()),
        ),
        _MenuRow(
          icon: CupertinoIcons.person_crop_circle_badge_plus,
          title: "Add another account",
          onTap: () => _push(context, const _AddAccountScreen()),
        ),
      ],
    );
  }
}

// ==================================================================
// LEVEL 3 — PASSWORD AND SECURITY
//   • Verification
//   • Where you're logged in
//   • Change password
// ==================================================================

class _PasswordAndSecurityScreen extends StatelessWidget {
  const _PasswordAndSecurityScreen();

  @override
  Widget build(BuildContext context) {
    return _SubPage(
      title: "Password & Security",
      children: [
        _MenuRow(
  icon: CupertinoIcons.camera_viewfinder,
  title: "Verification",
  subtitle: "Request or manage your verified badge",
  onTap: () => _push(
    context,
    const VerificationSelfieScreen(),
  ),
),
        _MenuRow(
          icon: CupertinoIcons.device_phone_portrait,
          title: "Where you're logged in",
          onTap: () => _push(context, const _LoggedInDevicesScreen()),
        ),
        _MenuRow(
          icon: CupertinoIcons.padlock_solid,
          title: "Change password",
          onTap: () => _push(context, const _ChangePasswordScreen()),
        ),
      ],
    );
  }
}

// ==================================================================
// LEVEL 2 — HELP AND SUPPORT
//   • Report a problem
//   • Contact us
// ==================================================================

class _HelpAndSupportScreen extends StatelessWidget {
  const _HelpAndSupportScreen();

  @override
  Widget build(BuildContext context) {
    return _SubPage(
      title: "Help & Support",
      children: [
        _MenuRow(
          icon: CupertinoIcons.exclamationmark_bubble,
          title: "Report a problem",
          onTap: () => _snack(context, "Report a problem is coming soon"),
        ),
        _MenuRow(
          icon: CupertinoIcons.mail,
          title: "Contact us",
          onTap: () => _snack(context, "Contact us is coming soon"),
        ),
      ],
    );
  }
}

// ==================================================================
// LEVEL 2 — LANGUAGES
//   • App language
// ==================================================================

class _LanguagesScreen extends StatelessWidget {
  const _LanguagesScreen();

  @override
  Widget build(BuildContext context) {
    return _SubPage(
      title: "Languages",
      children: [
        _MenuRow(
          icon: CupertinoIcons.textformat,
          title: "App language",
          subtitle: "English",
          onTap: () => _snack(context, "Language selection is coming soon"),
        ),
      ],
    );
  }
}

// ==================================================================
// LEVEL 2 — PRIVACY POLICY
// ==================================================================

class _PrivacyPolicyScreen extends StatelessWidget {
  const _PrivacyPolicyScreen();

  @override
  Widget build(BuildContext context) {
    final c = _SC.of(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.surface,
        iconTheme: IconThemeData(color: c.text),
        title: Text(
          "MicroBlog Privacy Policy",
          style: TextStyle(
            color: c.text,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _snack(context, "PDF download is coming soon"),
              icon: Icon(CupertinoIcons.arrow_down_doc, color: c.icon, size: 20),
              label: Text(
                "Download PDF",
                style: TextStyle(
                  color: c.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.icon, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.divider),
            ),
            child: Text(
              // TODO: replace with your real privacy policy text.
              "Privacy policy text will appear here.",
              style: TextStyle(color: c.muted, fontSize: 14, height: 1.6),
            ),
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
    final c = _SC.of(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.surface,
        iconTheme: IconThemeData(color: c.text),
        title: Text(
          "Deactivation or deletion",
          style: TextStyle(
            color: c.text,
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
    final c = _SC.of(context);

    return Card(
      color: c.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _snack(context, "Initiating $title confirmation flow"),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDestructive ? Colors.redAccent : c.text,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.35),
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

  InputDecoration _decoration(_SC c, String label, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: c.muted),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.icon, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _SC.of(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.surface,
        iconTheme: IconThemeData(color: c.text),
        title: Text(
          "Add another account",
          style: TextStyle(
            color: c.text,
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
                  color: c.text,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: c.text),
                cursorColor: c.icon,
                decoration: _decoration(c, "Email address or mobile number"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: TextStyle(color: c.text),
                cursorColor: c.icon,
                decoration: _decoration(
                  c,
                  "Password",
                  suffix: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? CupertinoIcons.eye
                          : CupertinoIcons.eye_slash,
                      color: c.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => _snack(
                    context,
                    "Multiple account login will be connected later",
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.icon,
                    foregroundColor: c.onIcon,
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
                onPressed: () =>
                    _snack(context, "Password recovery will be configured later"),
                child: Text(
                  "Forgotten password?",
                  style: TextStyle(color: c.muted),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => _snack(
                    context,
                    "Account creation will be connected later",
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: c.icon),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "Create new account",
                    style: TextStyle(
                      color: c.text,
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

// ==================================================================
// WHERE YOU'RE LOGGED IN
// ==================================================================

class _LoggedInDevicesScreen extends StatefulWidget {
  const _LoggedInDevicesScreen();

  @override
  State<_LoggedInDevicesScreen> createState() => _LoggedInDevicesScreenState();
}

class _LoggedInDevicesScreenState extends State<_LoggedInDevicesScreen> {
  bool _loading = true;
  bool _processing = false;

  String? _error;
  List<Map<String, dynamic>> _sessions = [];

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
        throw Exception(response['message'] ?? 'Unable to load login sessions');
      }

      final data = response['data'];
      final rawSessions = data is Map ? data['sessions'] : null;

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

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final c = _SC.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(title, style: TextStyle(color: c.text)),
        content: Text(message, style: TextStyle(color: c.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: TextStyle(color: c.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              action,
              style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<void> _revokeSession(Map<String, dynamic> session) async {
    final sessionId = session['sessionId']?.toString() ?? '';

    if (sessionId.isEmpty || _processing) return;

    final ok = await _confirm(
      title: 'Sign out this device?',
      message: 'This device will no longer be able to access your account.',
      action: 'Sign out',
    );

    if (!ok || !mounted) return;

    setState(() => _processing = true);

    try {
      final response = await ApiService.revokeSession(sessionId: sessionId);

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Unable to sign out device');
      }

      if (!mounted) return;

      _snack(context, 'Device signed out successfully');
      await _loadSessions();
    } catch (error) {
      if (!mounted) return;
      _snack(context, error.toString().replaceFirst('Exception: ', ''),
          error: true);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _revokeOtherSessions() async {
    if (_processing) return;

    final otherSessions =
        _sessions.where((session) => session['isCurrent'] != true).length;

    if (otherSessions == 0) return;

    final ok = await _confirm(
      title: 'Log out of other devices?',
      message: 'You will be signed out of $otherSessions other '
          'device(s). Your current device will remain logged in.',
      action: 'Log out',
    );

    if (!ok || !mounted) return;

    setState(() => _processing = true);

    try {
      final response = await ApiService.revokeOtherSessions();

      if (response['success'] != true) {
        throw Exception(
          response['message'] ?? 'Unable to log out other devices',
        );
      }

      if (!mounted) return;

      final data = response['data'];
      final count = data is Map ? data['revokedCount'] ?? 0 : 0;

      _snack(context, '$count other device(s) signed out');
      await _loadSessions();
    } catch (error) {
      if (!mounted) return;
      _snack(context, error.toString().replaceFirst('Exception: ', ''),
          error: true);
    } finally {
      if (mounted) setState(() => _processing = false);
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

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final c = _SC.of(context);

    final isCurrent = session['isCurrent'] == true;
    final deviceName = session['deviceName']?.toString().trim();
    final deviceType = session['deviceType']?.toString() ?? 'unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: c.icon.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(_deviceIcon(deviceType), color: c.icon, size: 24),
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
                    color: c.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  deviceType[0].toUpperCase() + deviceType.substring(1),
                  style: TextStyle(color: c.muted, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  'Last active: ${_formatDate(session['lastActiveAt'])}',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
                if (isCurrent) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: c.icon.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'CURRENT DEVICE',
                      style: TextStyle(
                        color: c.text,
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
              onPressed: _processing ? null : () => _revokeSession(session),
              child: Text(
                'Sign out',
                style: TextStyle(
                  color: c.text,
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
    final c = _SC.of(context);

    final otherSessions =
        _sessions.where((session) => session['isCurrent'] != true).length;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.surface,
        iconTheme: IconThemeData(color: c.text),
        title: Text(
          "Where you're logged in",
          style: TextStyle(
            color: c.text,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading || _processing ? null : _loadSessions,
            icon: Icon(CupertinoIcons.refresh, color: c.text),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.icon))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_circle,
                          color: c.icon,
                          size: 42,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: c.text),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadSessions,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.icon,
                            foregroundColor: c.onIcon,
                          ),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: c.icon,
                  onRefresh: _loadSessions,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(18),
                    children: [
                      Text(
                        'Your login activity',
                        style: TextStyle(
                          color: c.text,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'These are the devices currently signed '
                        'in to your MicroBlog account.',
                        style: TextStyle(
                          color: c.muted,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'ACTIVE DEVICES (${_sessions.length})',
                        style: TextStyle(
                          color: c.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 13),
                      if (_sessions.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: c.divider),
                          ),
                          child: Text(
                            'No active login sessions found.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: c.muted),
                          ),
                        )
                      else
                        ..._sessions.map(_buildSessionCard),
                      if (otherSessions > 0) ...[
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                _processing ? null : _revokeOtherSessions,
                            icon: Icon(
                              CupertinoIcons.square_arrow_right,
                              size: 18,
                              color: c.icon,
                            ),
                            label: Text(
                              'Log out of all other devices',
                              style: TextStyle(color: c.text),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: c.icon),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15),
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
                          color: c.muted,
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

// ==================================================================
// CHANGE PASSWORD
// ==================================================================

class _ChangePasswordScreen extends StatefulWidget {
  const _ChangePasswordScreen();

  @override
  State<_ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<_ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
        _snack(
          context,
          result['message']?.toString() ?? 'Password changed successfully.',
        );

        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        Navigator.of(context).pop();
      } else {
        _snack(
          context,
          result['message']?.toString() ?? 'Unable to change password.',
          error: true,
        );
      }
    } catch (error) {
      if (!mounted) return;
      _snack(context, 'Unable to change password. Please try again.',
          error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPasswordField({
    required _SC c,
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
            color: c.text,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        TextFormField(
          controller: controller,
          obscureText: !visible,
          cursorColor: c.icon,
          style: TextStyle(color: c.text, fontSize: 15),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: c.muted),
            filled: true,
            fillColor: c.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 17,
            ),
            suffixIcon: IconButton(
              onPressed: onVisibilityChanged,
              icon: Icon(
                visible ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                color: c.muted,
                size: 20,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: c.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: c.icon, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _SC.of(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.surface,
        iconTheme: IconThemeData(color: c.text),
        title: Text(
          'Change password',
          style: TextStyle(
            color: c.text,
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
                    color: c.icon.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.lock_shield_fill,
                    color: c.icon,
                    size: 31,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Keep your account secure',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.text,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a strong password that you do not use '
                'on other websites or apps.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 30),

              _buildPasswordField(
                c: c,
                label: 'Current password',
                hint: 'Enter your current password',
                controller: _currentPasswordController,
                visible: _showCurrentPassword,
                onVisibilityChanged: () => setState(
                  () => _showCurrentPassword = !_showCurrentPassword,
                ),
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
                  onPressed: () => _push(context, const ForgotPasswordScreen()),
                  style: TextButton.styleFrom(
                    foregroundColor: c.text,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                  ),
                  child: Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: c.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              _buildPasswordField(
                c: c,
                label: 'New password',
                hint: 'Enter your new password',
                controller: _newPasswordController,
                visible: _showNewPassword,
                onVisibilityChanged: () =>
                    setState(() => _showNewPassword = !_showNewPassword),
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
                c: c,
                label: 'Confirm new password',
                hint: 'Re-enter your new password',
                controller: _confirmPasswordController,
                visible: _showConfirmPassword,
                onVisibilityChanged: () => setState(
                  () => _showConfirmPassword = !_showConfirmPassword,
                ),
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
                style: TextStyle(color: c.muted, fontSize: 12),
              ),

              const SizedBox(height: 30),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.icon,
                    disabledBackgroundColor: c.icon.withValues(alpha: 0.4),
                    foregroundColor: c.onIcon,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: c.onIcon,
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