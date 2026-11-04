import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'user_profile_screen.dart';

/// Shows who follows a user, or whom a user follows.
class FollowListScreen extends StatefulWidget {
  final String userId;

  /// true = Followers, false = Following.
  final bool followers;

  /// Used to avoid opening your own profile from the list.
  final String? myId;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.followers,
    this.myId,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  static const Color _accent = Color(0xFFF91880);

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color get _background =>
      _dark ? const Color(0xFF08090B) : const Color(0xFFF7F8FA);

  Color get _surface =>
      _dark ? const Color(0xFF15171B) : const Color(0xFFFFFFFF);

  Color get _text =>
      _dark ? const Color(0xFFFFFFFF) : const Color(0xFF111318);

  Color get _muted =>
      _dark ? const Color(0xFF9297A0) : const Color(0xFF737B86);

  Color get _divider =>
      _dark ? const Color(0xFF282B31) : const Color(0xFFE6E8EC);

  Color get _composer =>
      _dark ? const Color(0xFF202329) : const Color(0xFFF0F1F4);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService.getConnections(
        userId: widget.userId,
        followers: widget.followers,
      );

      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Unable to load list');
      }

      final raw = result['data']?['users'];

      final users = <Map<String, dynamic>>[];

      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            users.add(Map<String, dynamic>.from(item));
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _users = users;
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

  Widget _avatar(Map<String, dynamic> user, double size) {
    final value = user['avatar']?.toString().trim() ?? '';

    final name =
        (user['displayName'] ?? user['username'] ?? '?').toString().trim();

    Widget fallback() {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: _composer),
        child: Text(
          name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: _text,
            fontSize: size * .38,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    if (value.isEmpty) return fallback();

    final bytes = ApiService.dataUrlToBytes(value);

    if (bytes != null) {
      return ClipOval(
        child: Image.memory(
          Uint8List.fromList(bytes),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback(),
        ),
      );
    }

    final url = ApiService.normalizeImageUrl(value);

    if (url == null) return fallback();

    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }

  void _open(Map<String, dynamic> user) {
    final id = user['_id']?.toString() ?? user['id']?.toString() ?? '';

    if (id.isEmpty || id == widget.myId) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: id, initialUser: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.followers ? 'Followers' : 'Following';

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: _text),
        shape: Border(bottom: BorderSide(color: _divider, width: 0.8)),
        title: Text(
          title,
          style: TextStyle(
            color: _text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _load,
                          child: const Text(
                            'Try again',
                            style: TextStyle(color: _accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _users.isEmpty
                  ? Center(
                      child: Text(
                        widget.followers
                            ? 'No followers yet'
                            : 'Not following anyone yet',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: _accent,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _users.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: _divider),
                        itemBuilder: (context, index) {
                          final user = _users[index];

                          final name = (user['displayName'] ??
                                  user['username'] ??
                                  'User')
                              .toString();

                          final username = user['username']?.toString() ?? '';

                          final bio = user['bio']?.toString().trim() ?? '';

                          return InkWell(
                            onTap: () => _open(user),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _avatar(user, 46),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: _text,
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (username.isNotEmpty)
                                          Text(
                                            '@$username',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: _muted,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        if (bio.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            bio,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: _text,
                                              fontSize: 13.5,
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}