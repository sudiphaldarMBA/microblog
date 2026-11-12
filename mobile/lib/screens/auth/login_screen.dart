import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../services/api_service.dart';
import '../home/home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _rose = Color(0xFFF91880);

  // Google Sign-In must be initialized only once.
  static Future<void>? _googleInitialization;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _activeProvider;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // COMMON HELPERS
  // ------------------------------------------------------------

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _setLoading(bool loading, {String? provider}) {
    if (!mounted) return;

    setState(() {
      _isLoading = loading;
      _activeProvider = loading ? provider : null;
    });
  }

  void _openHome() {
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomeScreen()),
      (route) => false,
    );
  }

  String _firebaseErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-phone-number':
        return 'Please enter a valid phone number.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-verification-code':
        return 'The OTP you entered is incorrect.';
      case 'session-expired':
        return 'The OTP has expired. Please request a new one.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  // ------------------------------------------------------------
  // EMAIL + PASSWORD LOGIN
  // ------------------------------------------------------------

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    _setLoading(true, provider: 'email');

    try {
      final result = await ApiService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _openHome();
      } else {
        _showMessage(result['message'] ?? 'Login failed.');
      }
    } catch (error) {
      debugPrint('Email login error: $error');
      _showMessage('Unable to connect to the server.');
    } finally {
      _setLoading(false);
    }
  }

  // ------------------------------------------------------------
  // GOOGLE SIGN-IN
  // ------------------------------------------------------------

  Future<void> _googleLogin() async {
    _setLoading(true, provider: 'google');

    try {
      _googleInitialization ??= GoogleSignIn.instance.initialize();
      await _googleInitialization;

      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();

      final googleAuthentication = googleUser.authentication;
      final idToken = googleAuthentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          'Google did not return an ID token. Check your Firebase '
          'Google Sign-In configuration.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      await _completeFirebaseLogin(userCredential.user, provider: 'Google');
    } on FirebaseAuthException catch (error) {
      _showMessage(_firebaseErrorMessage(error));
    } catch (error) {
      final message = error.toString().toLowerCase();

      if (message.contains('cancel')) {
        return;
      }

      debugPrint('Google login error: $error');
      _showMessage('Google sign-in failed. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  // ------------------------------------------------------------
  // PHONE NUMBER LOGIN
  // ------------------------------------------------------------

  Future<void> _phoneLogin() async {
    final phoneController = TextEditingController(text: '+91');

    final phoneNumber = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Login with phone'),
          content: TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '+919876543210',
              helperText: 'Include your country code, e.g. +91',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final phone = phoneController.text.trim();

                if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid number with country code.'),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, phone);
              },
              child: const Text('Send OTP'),
            ),
          ],
        );
      },
    );

    phoneController.dispose();

    if (phoneNumber == null || !mounted) return;

    await _sendPhoneOtp(phoneNumber);
  }

  Future<void> _sendPhoneOtp(String phoneNumber) async {
    _setLoading(true, provider: 'phone');

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),

        // Android may verify the SMS automatically.
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signInWithPhoneCredential(credential);
        },

        verificationFailed: (FirebaseAuthException error) {
          _setLoading(false);
          _showMessage(_firebaseErrorMessage(error));
        },

        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;

          _setLoading(false);

          _showOtpDialog(
            verificationId: verificationId,
            phoneNumber: phoneNumber,
          );
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('Phone OTP auto-retrieval timed out.');
        },
      );
    } on FirebaseAuthException catch (error) {
      _showMessage(_firebaseErrorMessage(error));
      _setLoading(false);
    } catch (error) {
      debugPrint('Phone verification error: $error');
      _showMessage('Unable to send OTP. Please try again.');
      _setLoading(false);
    }
  }

  Future<void> _showOtpDialog({
    required String verificationId,
    required String phoneNumber,
  }) async {
    final otpController = TextEditingController();

    final otp = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Verify your phone'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter the verification code sent to $phoneNumber.'),
              const SizedBox(height: 18),
              TextField(
                controller: otpController,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: '6-digit OTP',
                  prefixIcon: Icon(Icons.password_outlined),
                  counterText: '',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final code = otpController.text.trim();

                if (code.length != 6) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Enter the 6-digit OTP.')),
                  );
                  return;
                }

                Navigator.pop(dialogContext, code);
              },
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );

    otpController.dispose();

    if (otp == null || !mounted) return;

    _setLoading(true, provider: 'phone');

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      await _signInWithPhoneCredential(credential);
    } on FirebaseAuthException catch (error) {
      _showMessage(_firebaseErrorMessage(error));
    } catch (error) {
      debugPrint('OTP verification error: $error');
      _showMessage('OTP verification failed. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _signInWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      _setLoading(true, provider: 'phone');

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      await _completeFirebaseLogin(userCredential.user, provider: 'Phone');
    } on FirebaseAuthException catch (error) {
      _showMessage(_firebaseErrorMessage(error));
    } catch (error) {
      debugPrint('Phone sign-in error: $error');
      _showMessage('Phone sign-in failed. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  // ------------------------------------------------------------
  // FIREBASE USER -> MICROBLOG BACKEND JWT
  // ------------------------------------------------------------

  Future<void> _completeFirebaseLogin(
    User? firebaseUser, {
    required String provider,
  }) async {
    if (firebaseUser == null) {
      _showMessage('$provider authentication did not return a user.');
      return;
    }

    final idToken = await firebaseUser.getIdToken();

    if (idToken == null || idToken.isEmpty) {
      _showMessage('Unable to obtain your Firebase authentication token.');
      return;
    }

    var result = await ApiService.firebaseLogin(idToken: idToken);

    // New Firebase accounts need a MicroBlog display name and username.
    if (result['needsProfileSetup'] == true) {
      if (!mounted) return;

      final profile = await _showProfileSetupDialog(
        suggestedName: firebaseUser.displayName ?? '',
        suggestedEmail: firebaseUser.email ?? '',
      );

      if (profile == null || !mounted) return;

      final refreshedToken = await firebaseUser.getIdToken();

      if (refreshedToken == null || refreshedToken.isEmpty) {
        _showMessage('Unable to refresh your authentication token.');
        return;
      }

      result = await ApiService.firebaseLogin(
        idToken: refreshedToken,
        displayName: profile['displayName'],
        username: profile['username'],
      );
    }

    if (!mounted) return;

    if (result['success'] == true && result['data']?['token'] != null) {
      _openHome();
    } else {
      _showMessage(
        result['message'] ?? 'Unable to complete your MicroBlog login.',
      );
    }
  }

  Future<Map<String, String>?> _showProfileSetupDialog({
    required String suggestedName,
    required String suggestedEmail,
  }) async {
    final nameController = TextEditingController(text: suggestedName);

    final suggestedUsername = suggestedEmail
        .split('@')
        .first
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');

    final usernameController = TextEditingController(
      text: suggestedUsername.length >= 3
          ? suggestedUsername.substring(
              0,
              suggestedUsername.length > 30 ? 30 : suggestedUsername.length,
            )
          : '',
    );

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Complete your profile'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Just one more step before joining MicroBlog.'),
                const SizedBox(height: 18),
                TextFormField(
                  controller: nameController,
                  maxLength: 50,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 3) {
                      return 'Enter at least 3 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: usernameController,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (value) {
                    final username = value?.trim() ?? '';

                    if (!RegExp(r'^[a-zA-Z0-9_]{3,30}$').hasMatch(username)) {
                      return 'Use 3–30 letters, numbers or _.';
                    }

                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;

                Navigator.pop(dialogContext, {
                  'displayName': nameController.text.trim(),
                  'username': usernameController.text.trim(),
                });
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    usernameController.dispose();

    return result;
  }

  // ------------------------------------------------------------
  // UI
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 18),

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
                          Icons.forum_rounded,
                          size: 34,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      'MicroBlog',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Welcome back!',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      'Connect with your community.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: secondaryText,
                      ),
                    ),

                    const SizedBox(height: 38),

                    // EMAIL
                    _fieldLabel('EMAIL', secondaryText),

                    const SizedBox(height: 9),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: _inputDecoration(
                        hint: 'Enter your email address',
                        icon: Icons.mail_outline_rounded,
                        fillColor: fieldColor,
                        colors: colors,
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';

                        if (email.isEmpty) {
                          return 'Please enter your email.';
                        }

                        if (!RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(email)) {
                          return 'Please enter a valid email.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 21),

                    // PASSWORD
                    _fieldLabel('PASSWORD', secondaryText),

                    const SizedBox(height: 9),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) {
                        if (!_isLoading) _login();
                      },
                      decoration:
                          _inputDecoration(
                            hint: 'Enter your password',
                            icon: Icons.lock_outline_rounded,
                            fillColor: fieldColor,
                            colors: colors,
                          ).copyWith(
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: secondaryText,
                              ),
                            ),
                          ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password.';
                        }

                        if (value.length < 8) {
                          return 'Password must be at least 8 characters.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 30),

                    // LOGIN BUTTON
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _login,
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
                        child: _isLoading && _activeProvider == 'email'
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 27),

                    // DIVIDER
                    Row(
                      children: [
                        Expanded(child: Divider(color: colors.outlineVariant)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          child: Text(
                            'OR CONTINUE WITH',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: secondaryText,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: colors.outlineVariant)),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // GOOGLE + PHONE
                    Row(
                      children: [
                        Expanded(
                          child: _socialButton(
                            label: 'Google',
                            icon: Icons.g_mobiledata_rounded,
                            isLoading:
                                _isLoading && _activeProvider == 'google',
                            colors: colors,
                            onPressed: _isLoading ? null : _googleLogin,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _socialButton(
                            label: 'Phone OTP',
                            icon: Icons.phone_android_rounded,
                            isLoading: _isLoading && _activeProvider == 'phone',
                            colors: colors,
                            onPressed: _isLoading ? null : _phoneLogin,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // REGISTER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: secondaryText,
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  );
                                },
                          style: TextButton.styleFrom(
                            foregroundColor: _rose,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: const Text(
                            'Create account',
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

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required Color fillColor,
    required ColorScheme colors,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
      prefixIcon: Icon(icon, color: colors.onSurfaceVariant, size: 21),
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

  Widget _socialButton({
    required String label,
    required IconData icon,
    required bool isLoading,
    required ColorScheme colors,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.onSurface,
          side: BorderSide(color: colors.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 23),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
