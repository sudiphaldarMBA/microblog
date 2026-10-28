import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const EditProfileScreen({
    super.key,
    required this.user,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _bioController;
  late final TextEditingController _locationController;
  late final TextEditingController _websiteController;

  bool _saving = false;
  DateTime? _dateOfBirth;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.user['displayName']?.toString() ?? '',
    );

    _usernameController = TextEditingController(
      text: widget.user['username']?.toString() ?? '',
    );

    _emailController = TextEditingController(
      text: widget.user['email']?.toString() ?? '',
    );

    _bioController = TextEditingController(
      text: widget.user['bio']?.toString() ?? '',
    );

    _locationController = TextEditingController(
      text: widget.user['location']?.toString() ?? '',
    );

    _websiteController = TextEditingController(
      text: widget.user['website']?.toString() ?? '',
    );

    final rawDob = (
      widget.user['dateOfBirth'] ??
      widget.user['dob'] ??
      ''
    ).toString().trim();

    if (rawDob.isEmpty) {
      _dateOfBirth = null;
    } else {
      final parsed = DateTime.tryParse(rawDob);

      _dateOfBirth = parsed == null
          ? null
          : DateTime(parsed.year, parsed.month, parsed.day);
    }

    debugPrint('DOB RECEIVED BY EDIT PROFILE: "$rawDob"');
    debugPrint(
      'DOB INITIALIZED: ${_dateOfBirth == null ? "null" : _dobIso(_dateOfBirth!)}',
    );
  }

  String _dobIso(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  String _dobLabel() {
    final date = _dateOfBirth;

    if (date == null) return '';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ??
          DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Date of birth',
    );

    if (picked != null && mounted) {
      setState(() {
        _dateOfBirth = DateTime(
          picked.year,
          picked.month,
          picked.day,
        );
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _websiteController.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || username.isEmpty || email.isEmpty) {
      _showMessage('Name, username and email are required');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final dobToSend =
          _dateOfBirth == null ? '' : _dobIso(_dateOfBirth!);

      debugPrint('DOB SENT TO API: "$dobToSend"');

      final result = await ApiService.updateProfile(
        displayName: name,
        username: username,
        email: email,
        bio: _bioController.text.trim(),
        location: _locationController.text.trim(),
        website: _websiteController.text.trim(),
        dateOfBirth: dobToSend,
      );

      debugPrint('DOB SAVE SUCCESS: ${result['success']}');
      debugPrint('DOB SAVE MESSAGE: ${result['message']}');
      debugPrint(
        'DOB SAVE DATE: ${result['data']?['user']?['dateOfBirth']}',
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final raw = result['data']?['user'];

        final Map<String, dynamic> updatedUser;

        if (raw is Map) {
          updatedUser = Map<String, dynamic>.from(raw);
        } else {
          // Fallback if the API response does not include the user object.
          updatedUser = {
            ...widget.user,
            'displayName': name,
            'username': username,
            'email': email,
            'bio': _bioController.text.trim(),
            'location': _locationController.text.trim(),
            'website': _websiteController.text.trim(),
            'dateOfBirth': dobToSend,
          };
        }

        debugPrint(
          'DOB RETURNED TO PROFILE: "${updatedUser['dateOfBirth']}"',
        );

        Navigator.pop(context, updatedUser);
        return;
      }

      _showMessage(
        result['message']?.toString() ?? 'Unable to save profile',
      );
    } catch (error) {
      debugPrint('EDIT PROFILE SAVE ERROR: $error');

      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final buttonBackground =
        isDark ? Colors.white : Colors.black;
    final buttonForeground =
        isDark ? Colors.black : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _field(
              controller: _nameController,
              label: 'Name',
              hint: 'Your display name',
              icon: Icons.person_outline,
            ),
            _field(
              controller: _usernameController,
              label: 'Username',
              hint: 'username',
              icon: Icons.alternate_email,
            ),
            _field(
              controller: _emailController,
              label: 'Email',
              hint: 'name@example.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            _field(
              controller: _bioController,
              label: 'Bio',
              hint: 'Tell people about yourself',
              icon: Icons.notes_outlined,
              maxLines: 4,
              maxLength: 160,
            ),
            _field(
              controller: _locationController,
              label: 'Location',
              hint: 'City or area',
              icon: Icons.location_on_outlined,
              maxLength: 100,
            ),
            _field(
              controller: _websiteController,
              label: 'Website',
              hint: 'https://example.com',
              icon: Icons.language_outlined,
              keyboardType: TextInputType.url,
              maxLength: 200,
            ),
            _dobField(),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: buttonBackground,
                  foregroundColor: buttonForeground,
                  disabledBackgroundColor:
                      buttonBackground.withOpacity(0.6),
                  disabledForegroundColor: buttonForeground,
                ),
                child: _saving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: buttonForeground,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save changes',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dobField() {
    final label = _dobLabel();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: _pickDateOfBirth,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Date of birth',
            prefixIcon: const Icon(Icons.cake_outlined),
            suffixIcon: _dateOfBirth == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _dateOfBirth = null;
                      });
                    },
                  ),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: Text(
            label.isEmpty ? 'Select date' : label,
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }
}
