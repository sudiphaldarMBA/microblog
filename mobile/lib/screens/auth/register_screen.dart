import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  final TextEditingController _displayNameController = TextEditingController();

  final TextEditingController _usernameController = TextEditingController();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

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

      if (!mounted) {
        return;
      }

      if (response["success"] == true) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text("Registration successful!"),
            ),
          );

        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(
                response["message"]?.toString() ?? "Registration failed",
              ),
            ),
          );
      }
    } catch (error) {
      debugPrint("Registration Error: $error");

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text("Unable to connect to the server."),
          ),
        );
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // FIELD
  // ============================================================

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Create Account",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                const Icon(Icons.person_add_rounded, size: 80),

                const SizedBox(height: 20),

                const Text(
                  "Create Account",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 8),

                Text(
                  "Join the MicroBlog community",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),

                const SizedBox(height: 35),

                // ------------------------------------------------
                // DISPLAY NAME
                // ------------------------------------------------
                _buildField(
                  controller: _displayNameController,
                  label: "Display Name",
                  hint: "Your name",
                  icon: Icons.badge_outlined,
                  validator: (value) {
                    final text = value?.trim() ?? "";

                    if (text.isEmpty) {
                      return "Please enter your display name";
                    }

                    if (text.length < 3) {
                      return "Display name must be at least 3 characters";
                    }

                    if (text.length > 50) {
                      return "Display name cannot exceed 50 characters";
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // ------------------------------------------------
                // USERNAME
                // ------------------------------------------------
                _buildField(
                  controller: _usernameController,
                  label: "Username",
                  hint: "Choose a username",
                  icon: Icons.person_outline_rounded,
                  validator: (value) {
                    final text = value?.trim() ?? "";

                    if (text.isEmpty) {
                      return "Please enter your username";
                    }

                    if (text.length < 3) {
                      return "Username must be at least 3 characters";
                    }

                    if (text.length > 30) {
                      return "Username cannot exceed 30 characters";
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // ------------------------------------------------
                // EMAIL
                // ------------------------------------------------
                _buildField(
                  controller: _emailController,
                  label: "Email",
                  hint: "you@example.com",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final text = value?.trim() ?? "";

                    if (text.isEmpty) {
                      return "Please enter your email";
                    }

                    if (!text.contains("@")) {
                      return "Please enter a valid email";
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // ------------------------------------------------
                // PASSWORD
                // ------------------------------------------------
                _buildField(
                  controller: _passwordController,
                  label: "Password",
                  hint: "At least 8 characters",
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                  validator: (value) {
                    final text = value ?? "";

                    if (text.isEmpty) {
                      return "Please enter a password";
                    }

                    if (text.length < 8) {
                      return "Password must be at least 8 characters";
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // ------------------------------------------------
                // CONFIRM PASSWORD
                // ------------------------------------------------
                _buildField(
                  controller: _confirmPasswordController,
                  label: "Confirm Password",
                  hint: "Enter password again",
                  icon: Icons.lock_reset_rounded,
                  obscureText: true,
                  validator: (value) {
                    final text = value ?? "";

                    if (text.isEmpty) {
                      return "Please confirm your password";
                    }

                    if (text != _passwordController.text) {
                      return "Passwords do not match";
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // ------------------------------------------------
                // REGISTER BUTTON
                // ------------------------------------------------
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Create Account",
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),

                const SizedBox(height: 15),

                OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.pop(context);
                        },
                  child: const Text("Already have an account? Login"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
