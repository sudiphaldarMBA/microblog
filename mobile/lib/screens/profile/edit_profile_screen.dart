import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const EditProfileScreen({super.key, required this.user});

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
      final result = await ApiService.updateProfile(
        displayName: name,
        username: username,
        email: email,
        bio: _bioController.text,
        location: _locationController.text,
        website: _websiteController.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final raw = result['data']?['user'];

        final updatedUser = raw is Map
            ? Map<String, dynamic>.from(raw)
            : {
                ...widget.user,
                'displayName': name,
                'username': username,
                'email': email,
                'bio': _bioController.text.trim(),
                'location': _locationController.text.trim(),
                'website': _websiteController.text.trim(),
              };

        Navigator.pop(context, updatedUser);

        return;
      }

      _showMessage(result['message']?.toString() ?? 'Unable to save profile');
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
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
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
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
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: colors.primary),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save changes',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }
}
