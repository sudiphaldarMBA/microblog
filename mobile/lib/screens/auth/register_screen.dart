import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const Color _rose = Color(0xFFF91880);

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // REGISTER
  // ------------------------------------------------------------

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.register(
        displayName: _displayNameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Registration successful! Please log in.'),
            ),
          );

        Navigator.pop(context);
      } else {
        _showMessage(response['message']?.toString() ?? 'Registration failed.');
      }
    } catch (error) {
      debugPrint('Registration error: $error');

      if (!mounted) return;

      _showMessage('Unable to connect to the server.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  // ------------------------------------------------------------
  // INPUT DECORATION
  // ------------------------------------------------------------

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required Color fillColor,
    required Color secondaryText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: secondaryText, fontSize: 14),
      prefixIcon: Icon(icon, color: secondaryText, size: 21),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _rose, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  Widget _fieldLabel(String label, Color color) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        color: color,
      ),
    );
  }

  Widget _passwordVisibilityButton({
    required bool isVisible,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: isVisible ? 'Hide password' : 'Show password',
      onPressed: onPressed,
      icon: Icon(
        isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final isDark = theme.brightness == Brightness.dark;

    final secondaryText = colors.onSurfaceVariant;

    final fieldColor = isDark
        ? const Color(0xFF202329)
        : const Color(0xFFF0F1F4);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back to login',
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Create Account',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),

                    // BRAND
                    Center(
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          color: _rose,
                          borderRadius: BorderRadius.circular(21),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 34,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      'Join MicroBlog',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Create your account and join the community.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: secondaryText,
                      ),
                    ),

                    const SizedBox(height: 34),

                    // DISPLAY NAME
                    _fieldLabel('DISPLAY NAME', secondaryText),

                    const SizedBox(height: 9),

                    TextFormField(
                      controller: _displayNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      maxLength: 50,
                      decoration: _inputDecoration(
                        hint: 'Enter your full name',
                        icon: Icons.badge_outlined,
                        fillColor: fieldColor,
                        secondaryText: secondaryText,
                      ).copyWith(counterText: ''),
                      validator: (value) {
                        final text = value?.trim() ?? '';

                        if (text.isEmpty) {
                          return 'Please enter your display name.';
                        }

                        if (text.length < 3) {
                          return 'Name must be at least 3 characters.';
                        }

                        if (text.length > 50) {
                          return 'Name cannot exceed 50 characters.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 19),

                    // USERNAME
                    _fieldLabel('USERNAME', secondaryText),

                    const SizedBox(height: 9),

                    TextFormField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      maxLength: 30,
                      decoration: _inputDecoration(
                        hint: 'Choose a unique username',
                        icon: Icons.alternate_email_rounded,
                        fillColor: fieldColor,
                        secondaryText: secondaryText,
                      ).copyWith(counterText: ''),
                      validator: (value) {
                        final text = value?.trim() ?? '';

                        if (text.isEmpty) {
                          return 'Please enter a username.';
                        }

                        if (!RegExp(r'^[a-zA-Z0-9_]{3,30}$').hasMatch(text)) {
                          return 'Use 3–30 letters, numbers or underscores.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 19),

                    // EMAIL
                    _fieldLabel('EMAIL ADDRESS', secondaryText),

                    const SizedBox(height: 9),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: _inputDecoration(
                        hint: 'you@example.com',
                        icon: Icons.mail_outline_rounded,
                        fillColor: fieldColor,
                        secondaryText: secondaryText,
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';

                        if (text.isEmpty) {
                          return 'Please enter your email.';
                        }

                        if (!RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(text)) {
                          return 'Please enter a valid email.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 19),

                    // PASSWORD
                    _fieldLabel('PASSWORD', secondaryText),

                    const SizedBox(height: 9),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: _inputDecoration(
                        hint: 'At least 8 characters',
                        icon: Icons.lock_outline_rounded,
                        fillColor: fieldColor,
                        secondaryText: secondaryText,
                        suffixIcon: _passwordVisibilityButton(
                          isVisible: !_obscurePassword,
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        final text = value ?? '';

                        if (text.isEmpty) {
                          return 'Please enter a password.';
                        }

                        if (text.length < 8) {
                          return 'Password must be at least 8 characters.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 19),

                    // CONFIRM PASSWORD
                    _fieldLabel('CONFIRM PASSWORD', secondaryText),

                    const SizedBox(height: 9),

                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) {
                        if (!_isLoading) _register();
                      },
                      decoration: _inputDecoration(
                        hint: 'Enter your password again',
                        icon: Icons.lock_reset_rounded,
                        fillColor: fieldColor,
                        secondaryText: secondaryText,
                        suffixIcon: _passwordVisibilityButton(
                          isVisible: !_obscureConfirmPassword,
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        final text = value ?? '';

                        if (text.isEmpty) {
                          return 'Please confirm your password.';
                        }

                        if (text != _passwordController.text) {
                          return 'Passwords do not match.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 30),

                    // CREATE ACCOUNT
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _register,
                        style: FilledButton.styleFrom(
                          backgroundColor: _rose,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _rose.withValues(
                            alpha: 0.55,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // LOGIN NAVIGATION
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'Already have an account?',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: secondaryText,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: _rose,
                            padding: const EdgeInsets.symmetric(horizontal: 7),
                          ),
                          child: const Text(
                            'Login',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
