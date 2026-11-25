
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';

/// Settings > Settings and privacy > Password and security > Verification.
///
/// Also opened from the "Get verified" button on the profile.
class VerificationSelfieScreen extends StatefulWidget {
  const VerificationSelfieScreen({super.key});

  @override
  State<VerificationSelfieScreen> createState() =>
      _VerificationSelfieScreenState();
}

class _VerificationSelfieScreenState extends State<VerificationSelfieScreen> {
  static const Color _badgePink = Color(0xFFF91880);

  final ImagePicker _picker = ImagePicker();

  File? _selfie;

  bool _submitting = false;
  bool _loadingStatus = true;

  String _verificationStatus = 'not_submitted';
  String _rejectionReason = '';
  String? _statusError;

  DateTime? _submittedAt;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color get _background =>
      _dark ? const Color(0xFF08090B) : const Color(0xFFF7F8FA);
  Color get _surface => _dark ? const Color(0xFF15171B) : Colors.white;
  Color get _text => _dark ? Colors.white : const Color(0xFF111318);
  Color get _muted => _dark ? const Color(0xFF9297A0) : const Color(0xFF737B86);
  Color get _divider =>
      _dark ? const Color(0xFF282B31) : const Color(0xFFE6E8EC);
  Color get _icon => _dark ? Colors.white : Colors.black;
  Color get _onIcon => _dark ? Colors.black : Colors.white;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;

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

  Future<void> _loadVerificationStatus() async {
    if (mounted) {
      setState(() {
        _loadingStatus = true;
        _statusError = null;
      });
    }

    try {
      final result = await ApiService.getVerificationStatus();

      if (!mounted) return;

      if (result['success'] != true) {
        throw Exception(
          result['message'] ?? 'Unable to retrieve verification status',
        );
      }

      final status =
          result['verificationStatus']?.toString() ?? 'not_submitted';

      setState(() {
        _verificationStatus = const {
          'not_submitted',
          'pending',
          'verified',
          'rejected',
        }.contains(status)
            ? status
            : 'not_submitted';

        _rejectionReason =
            result['rejectionReason']?.toString() ?? '';

        _submittedAt = DateTime.tryParse(
          result['submittedAt']?.toString() ?? '',
        );

        _loadingStatus = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadingStatus = false;
        _statusError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _takeSelfie() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (picked == null || !mounted) return;

      setState(() => _selfie = File(picked.path));
    } catch (error) {
      debugPrint('Verification selfie camera error: $error');
      _snack('Unable to open the camera', error: true);
    }
  }

  Future<void> _submit() async {
    final file = _selfie;

    if (file == null || _submitting) return;

    setState(() => _submitting = true);

    try {
      final dataUrl = await ApiService.fileToDataUrl(file);

      final result = await ApiService.submitVerificationSelfie(
        selfie: dataUrl,
      );

      if (!mounted) return;

      if (result['success'] != true) {
        throw Exception(
          result['message'] ?? 'Unable to submit your application',
        );
      }

      final status =
          result['verificationStatus']?.toString() ?? 'pending';

      setState(() {
        // Submission is never treated as automatic verification.
        _verificationStatus =
            status == 'verified' ? 'pending' : status;

        _submittedAt = DateTime.tryParse(
          result['submittedAt']?.toString() ?? '',
        ) ?? DateTime.now();

        _rejectionReason = '';
        _selfie = null;
        _submitting = false;
      });

      _snack('Your verification application has been submitted.');
    } catch (error) {
      if (!mounted) return;

      setState(() => _submitting = false);

      _snack(
        error.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';

    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');

    return '$day/$month/${local.year}';
  }

  Widget _badge(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: _badgePink,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check_rounded,
        color: Colors.white,
        size: size * .7,
      ),
    );
  }

  Widget _statusIcon({
    required IconData icon,
    required Color color,
    double size = 76,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
      ),
      child: Icon(icon, color: color, size: size * .48),
    );
  }

  Widget _buildVerified() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _badge(84),
        const SizedBox(height: 22),
        Text(
          'You are verified',
          style: TextStyle(
            color: _text,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your account has been successfully verified. '
          'Your verified badge can now appear next to your name.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _muted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: _icon,
              foregroundColor: _onIcon,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: const Text(
              'Done',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPending() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _statusIcon(
              icon: CupertinoIcons.clock,
              color: const Color(0xFFE6A23C),
            ),
            const SizedBox(height: 22),
            Text(
              'Pending review',
              style: TextStyle(
                color: _text,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your selfie has been submitted successfully. '
              'Our team will review your application manually.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _divider),
              ),
              child: Column(
                children: [
                  Text(
                    'Expected review time',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Within 24 hours',
                    style: TextStyle(
                      color: _text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (_submittedAt != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Submitted on ${_formatDate(_submittedAt)}',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'You can leave this screen. Your application status '
              'will be updated here after the review is completed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _loadVerificationStatus,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _text,
                  side: BorderSide(color: _divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: const Text(
                  'Refresh status',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapture() {
    final selfie = _selfie;
    final isRejected = _verificationStatus == 'rejected';

    return ListView(
      children: [
        const SizedBox(height: 8),
        if (isRejected) ...[
          _statusIcon(
            icon: CupertinoIcons.xmark,
            color: Colors.red,
            size: 66,
          ),
          const SizedBox(height: 16),
          Text(
            'Application not approved',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You can submit a new selfie after addressing the feedback.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          if (_rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review feedback',
                    style: TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _rejectionReason,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 26),
        ],
        Center(
          child: Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _surface,
              border: Border.all(color: _divider, width: 1.4),
            ),
            child: ClipOval(
              child: selfie != null
                  ? Image.file(selfie, fit: BoxFit.cover)
                  : Icon(
                      CupertinoIcons.camera_viewfinder,
                      color: _icon,
                      size: 64,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          isRejected ? 'Submit a new selfie' : 'Verify with a selfie',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _text,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Take a clear selfie in good light, facing the camera. '
          'Your application will be reviewed manually.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _muted,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _submitting ? null : _takeSelfie,
            icon: Icon(
              CupertinoIcons.camera,
              color: _icon,
              size: 19,
            ),
            label: Text(
              selfie == null ? 'Take selfie' : 'Retake selfie',
              style: TextStyle(
                color: _text,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _icon, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: selfie == null || _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _icon,
              foregroundColor: _onIcon,
              disabledBackgroundColor: _icon.withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: _submitting
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      color: _onIcon,
                    ),
                  )
                : Text(
                    isRejected ? 'Resubmit application' : 'Submit for review',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_circle,
            color: _muted,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load verification status',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _statusError ?? 'Please try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loadVerificationStatus,
            style: FilledButton.styleFrom(
              backgroundColor: _icon,
              foregroundColor: _onIcon,
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingStatus) {
      return Center(
        child: CircularProgressIndicator(color: _badgePink),
      );
    }

    if (_statusError != null) {
      return _buildStatusError();
    }

    switch (_verificationStatus) {
      case 'pending':
        return _buildPending();

      case 'verified':
        return _buildVerified();

      case 'rejected':
      case 'not_submitted':
      default:
        return _buildCapture();
    }
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
          'Verification',
          style: TextStyle(
            color: _text,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildBody(),
        ),
      ),
    );
  }
}
