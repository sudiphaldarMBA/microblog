
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/api_service.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const Color _accent = Color(0xFFF91880);

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _phoneController =
      TextEditingController();

  final TextEditingController _otpController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _isEmailRecovery = true;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  String? _verificationId;
  String? _resetToken;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _background =>
      _isDark ? const Color(0xFF08090B) : const Color(0xFFF7F8FA);

  Color get _surface =>
      _isDark ? const Color(0xFF15171B) : Colors.white;

  Color get _secondarySurface =>
      _isDark ? const Color(0xFF202329) : const Color(0xFFF0F1F4);

  Color get _primaryText =>
      _isDark ? Colors.white : const Color(0xFF111318);

  Color get _secondaryText =>
      _isDark ? const Color(0xFF9297A0) : const Color(0xFF69707A);

  Color get _divider =>
      _isDark ? const Color(0xFF282B31) : const Color(0xFFE7E9ED);

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

Future<void> _requestEmailOtp() async {
  final email = _emailController.text.trim().toLowerCase();

  if (email.isEmpty || !email.contains('@')) {
    _showMessage('Enter a valid email address.');
    return;
  }

  setState(() => _isLoading = true);

  try {
    final response = await ApiService.requestPasswordReset(
      email: email,
    );

    if (!mounted) return;

    if (response['success'] == true) {
      setState(() {
        _otpSent = true;
        _otpVerified = false;
        _otpController.clear();
      });

      _showMessage(
        'If an eligible account exists, a verification code will be sent.',
      );
    } else {
      _showMessage(
        response['message'] ?? 'Unable to send verification code.',
      );
    }
  } catch (error) {
    if (!mounted) return;

    debugPrint('Email recovery request error: $error');
    _showMessage('Unable to send verification code. Please try again.');
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}


Future<void> _verifyEmailOtp() async {
  final otp = _otpController.text.trim();

  if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
    _showMessage('Enter the 6-digit OTP.');
    return;
  }

  setState(() => _isLoading = true);

  try {
    final response = await ApiService.verifyPasswordResetOtp(
      email: _emailController.text.trim().toLowerCase(),
      otp: otp,
    );

    if (!mounted) return;

    if (response['success'] == true &&
        response['resetToken'] != null) {
      setState(() {
        _resetToken = response['resetToken'].toString();
        _otpVerified = true;
      });

      _showMessage('Email verified successfully.');
    } else {
      _showMessage(
        response['message'] ?? 'Wrong OTP, try again.',
      );
    }
  } catch (error) {
    if (!mounted) return;

    debugPrint('Email OTP verification error: $error');
    _showMessage('OTP verification failed. Please try again.');
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}



Future<void> _requestPhoneOtp() async {
  final phoneNumber = _phoneController.text.trim();

  if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phoneNumber)) {
    _showMessage(
      'Enter a valid phone number with country code (example: +919876543210).',
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    final recoveryAuth = await _getRecoveryFirebaseAuth();

    await recoveryAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),

      verificationCompleted: (PhoneAuthCredential credential) async {
        await _completePhoneRecovery(credential);
      },

      verificationFailed: (FirebaseAuthException error) {
        if (!mounted) return;

        setState(() => _isLoading = false);
        _showMessage(_firebaseErrorMessage(error));
      },

      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;

        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
          _otpVerified = false;
          _isLoading = false;
          _otpController.clear();
        });

        _showMessage('Verification code sent to your phone.');
      },

      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
        debugPrint('Recovery phone OTP auto-retrieval timed out.');
      },
    );
  } on FirebaseAuthException catch (error) {
    if (!mounted) return;

    _showMessage(_firebaseErrorMessage(error));
    setState(() => _isLoading = false);
  } catch (error) {
    debugPrint('Phone recovery request error: $error');

    if (!mounted) return;

    _showMessage('Unable to send OTP. Please try again.');
    setState(() => _isLoading = false);
  }
}


String _firebaseErrorMessage(FirebaseAuthException error) {
  switch (error.code) {
    case 'invalid-phone-number':
      return 'The phone number is invalid.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'quota-exceeded':
      return 'SMS verification limit reached. Try again later.';
    case 'network-request-failed':
      return 'Network error. Check your internet connection.';
    default:
      return error.message ?? 'Phone verification failed.';
  }
}


Future<void> _verifyPhoneOtp() async {
  final otp = _otpController.text.trim();

  if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
    _showMessage('Enter the 6-digit OTP.');
    return;
  }

  if (_verificationId == null) {
    _showMessage('Please request a new verification code.');
    return;
  }

  setState(() => _isLoading = true);

  try {
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otp,
    );

    await _completePhoneRecovery(credential);
  } on FirebaseAuthException catch (error) {
    if (!mounted) return;

    _showMessage(_firebaseErrorMessage(error));
    setState(() => _isLoading = false);
  } catch (error) {
    debugPrint('Phone OTP verification error: $error');

    if (!mounted) return;

    _showMessage('OTP verification failed. Please try again.');
    setState(() => _isLoading = false);
  }
}

void _showMessage(String message) {
  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

Future<FirebaseAuth> _getRecoveryFirebaseAuth() async {
  FirebaseApp recoveryApp;

  try {
    recoveryApp = Firebase.app('microblog-password-recovery');
  } on FirebaseException {
    recoveryApp = await Firebase.initializeApp(
      name: 'microblog-password-recovery',
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  return FirebaseAuth.instanceFor(app: recoveryApp);
}

Future<void> _completePhoneRecovery(
  PhoneAuthCredential credential,
) async {
  if (mounted) {
    setState(() => _isLoading = true);
  }

  FirebaseAuth? recoveryAuth;

  try {
    recoveryAuth = await _getRecoveryFirebaseAuth();

    final userCredential = await recoveryAuth.signInWithCredential(
      credential,
    );

    final firebaseUser = userCredential.user;

    if (firebaseUser == null) {
      throw Exception('Phone verification failed.');
    }

    final idToken = await firebaseUser.getIdToken(true);

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Unable to obtain Firebase verification token.');
    }

    final response = await ApiService.verifyPasswordResetPhone(
      idToken: idToken,
    );

    if (!mounted) return;

    if (response['success'] == true &&
        response['resetToken'] != null) {
      setState(() {
        _resetToken = response['resetToken'].toString();
        _otpVerified = true;
      });

      _showMessage('Phone number verified successfully.');
    } else {
      _showMessage(
        response['message'] ?? 'Phone verification failed.',
      );
    }
  } on FirebaseAuthException catch (error) {
    if (!mounted) return;

    _showMessage(_firebaseErrorMessage(error));
  } catch (error) {
    debugPrint('Phone recovery completion error: $error');

    if (!mounted) return;

    _showMessage('Unable to verify phone number. Please try again.');
  } finally {
    if (recoveryAuth != null) {
      try {
        await recoveryAuth.signOut();
      } catch (error) {
        debugPrint('Recovery Firebase sign-out error: $error');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}


Future<void> _submitNewPassword() async {
  final password = _passwordController.text;
  final confirmPassword = _confirmPasswordController.text;

  if (_resetToken == null || _resetToken!.isEmpty) {
    _showMessage('Please verify your identity again.');
    return;
  }

  if (password.length < 8) {
    _showMessage('Password must be at least 8 characters long.');
    return;
  }

  if (password.length > 128) {
    _showMessage('Password cannot exceed 128 characters.');
    return;
  }

  if (password != confirmPassword) {
    _showMessage('Passwords do not match.');
    return;
  }

  setState(() => _isLoading = true);

  try {
    final response = await ApiService.resetPassword(
      resetToken: _resetToken!,
      newPassword: password,
    );

    if (!mounted) return;

    if (response['success'] == true) {
      _passwordController.clear();
      _confirmPasswordController.clear();

      _showMessage(
        'Password reset successfully. Please log in again.',
      );

      await Future.delayed(const Duration(milliseconds: 700));

      if (!mounted) return;

      Navigator.of(context).pop();
    } else {
      _showMessage(
        response['message'] ?? 'Unable to reset your password.',
      );
    }
  } catch (error) {
    if (!mounted) return;

    debugPrint('Password reset submission error: $error');
    _showMessage('Unable to reset password. Please try again.');
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}


Widget _buildMethodCard({
  required String title,
  required String subtitle,
  required IconData icon,
  required bool selected,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: _isLoading ? null : onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected
            ? _accent.withValues(alpha: 0.08)
            : _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? _accent : _divider,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: selected ? _accent : _secondaryText,
            size: 23,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: _primaryText,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: _secondaryText,
              fontSize: 11,
            ),
          ),
        ],
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _primaryText,
        elevation: 0,
        title: Text(
          'Forgot password',
          style: TextStyle(
            color: _primaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      
body: SafeArea(
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        Text(
          'Recover your account',
          style: TextStyle(
            color: _primaryText,
            fontSize: 25,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          'Choose how you want to verify your identity and reset your password.',
          style: TextStyle(
            color: _secondaryText,
            fontSize: 14,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 30),

        Text(
          'Choose recovery method',
          style: TextStyle(
            color: _primaryText,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: _buildMethodCard(
                title: 'Email',
                subtitle: 'Get a verification code',
                icon: Icons.email_outlined,
                selected: _isEmailRecovery,
                onTap: () {
                  setState(() {
                    _isEmailRecovery = true;
                    _otpSent = false;
                    _otpVerified = false;
                    _verificationId = null;
                    _resetToken = null;
                    _otpController.clear();
                  });
                },
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _buildMethodCard(
                title: 'Phone',
                subtitle: 'Verify with SMS',
                icon: Icons.phone_android_outlined,
                selected: !_isEmailRecovery,
                onTap: () {
                  setState(() {
                    _isEmailRecovery = false;
                    _otpSent = false;
                    _otpVerified = false;
                    _verificationId = null;
                    _resetToken = null;
                    _otpController.clear();
                  });
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        Text(
          _isEmailRecovery ? 'Email address' : 'Phone number',
          style: TextStyle(
            color: _primaryText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 10),

        TextField(
          controller: _isEmailRecovery
              ? _emailController
              : _phoneController,
          keyboardType: _isEmailRecovery
              ? TextInputType.emailAddress
              : TextInputType.phone,
          enabled: !_otpSent,
          style: TextStyle(color: _primaryText),
          decoration: InputDecoration(
            hintText: _isEmailRecovery
                ? 'Enter your registered email'
                : 'Example: +919876543210',
            hintStyle: TextStyle(color: _secondaryText),
            prefixIcon: Icon(
              _isEmailRecovery
                  ? Icons.email_outlined
                  : Icons.phone_outlined,
              color: _secondaryText,
            ),
            filled: true,
            fillColor: _secondarySurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: _accent,
                width: 1.4,
              ),
            ),
          ),
        ),


if (_otpSent && !_otpVerified) ...[
  const SizedBox(height: 22),

  Text(
    'Verification code',
    style: TextStyle(
      color: _primaryText,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
  ),

  const SizedBox(height: 10),

  TextField(
    controller: _otpController,
    keyboardType: TextInputType.number,
    maxLength: 6,
    style: TextStyle(
      color: _primaryText,
      letterSpacing: 5,
      fontWeight: FontWeight.w700,
    ),
    decoration: InputDecoration(
      hintText: 'Enter 6-digit OTP',
      hintStyle: TextStyle(
        color: _secondaryText,
        letterSpacing: 0,
      ),
      counterText: '',
      prefixIcon: Icon(
        Icons.password_outlined,
        color: _secondaryText,
      ),
      filled: true,
      fillColor: _secondarySurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _accent,
          width: 1.4,
        ),
      ),
    ),
  ),
],

if (_otpVerified) ...[
  const SizedBox(height: 22),

  Text(
    'Create new password',
    style: TextStyle(
      color: _primaryText,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
  ),

  const SizedBox(height: 10),

  TextField(
    controller: _passwordController,
    obscureText: !_passwordVisible,
    style: TextStyle(color: _primaryText),
    decoration: InputDecoration(
      hintText: 'Enter new password',
      hintStyle: TextStyle(color: _secondaryText),
      prefixIcon: Icon(
        Icons.lock_outline,
        color: _secondaryText,
      ),
      suffixIcon: IconButton(
        onPressed: () {
          setState(() => _passwordVisible = !_passwordVisible);
        },
        icon: Icon(
          _passwordVisible
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: _secondaryText,
        ),
      ),
      filled: true,
      fillColor: _secondarySurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _accent,
          width: 1.4,
        ),
      ),
    ),
  ),

  const SizedBox(height: 16),

  TextField(
    controller: _confirmPasswordController,
    obscureText: !_confirmPasswordVisible,
    style: TextStyle(color: _primaryText),
    decoration: InputDecoration(
      hintText: 'Confirm new password',
      hintStyle: TextStyle(color: _secondaryText),
      prefixIcon: Icon(
        Icons.lock_outline,
        color: _secondaryText,
      ),
      suffixIcon: IconButton(
        onPressed: () {
          setState(() {
            _confirmPasswordVisible = !_confirmPasswordVisible;
          });
        },
        icon: Icon(
          _confirmPasswordVisible
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: _secondaryText,
        ),
      ),
      filled: true,
      fillColor: _secondarySurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _accent,
          width: 1.4,
        ),
      ),
    ),
  ),

  const SizedBox(height: 10),

  Text(
    'Password must contain between 8 and 128 characters.',
    style: TextStyle(
      color: _secondaryText,
      fontSize: 12,
    ),
  ),
],

        const SizedBox(height: 24),

        
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _isLoading
                ? null
                : () {
                    if (_otpVerified) {
                      _submitNewPassword();
                    } else if (_otpSent) {
                      if (_isEmailRecovery) {
                        _verifyEmailOtp();
                      } else {
                        _verifyPhoneOtp();
                      }
                    } else {
                      if (_isEmailRecovery) {
                        _requestEmailOtp();
                      } else {
                        _requestPhoneOtp();
                      }
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _accent.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _otpVerified
                        ? 'Reset password'
                        : _otpSent
                            ? 'Verify OTP'
                            : 'Continue',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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