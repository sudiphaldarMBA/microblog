import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';

/// Public profile of another user: cover, photo, details, Follow button
/// and that person's posts.
class UserProfileScreen extends StatefulWidget {
  final String userId;

  /// Optional basic info (for example the post author) shown instantly
  /// while the full profile loads.
  final Map<String, dynamic>? initialUser;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.initialUser,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _user;

  List<Map<String, dynamic>> _posts = [];

  bool _loadingProfile = true;
  bool _loadingPosts = true;
  bool _followBusy = false;

  String? _error;

  // ============================================================
  // COLORS
  // ============================================================

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _background =>
      _isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

  Color get _surface =>
      _isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFFFFFF);

  Color get _secondarySurface =>
      _isDark ? const Color(0xFF16181C) : const Color(0xFFF3F4F6);

  Color get _text =>
      _isDark ? const Color(0xFFF5F5F5) : const Color(0xFF111111);

  Color get _muted =>
      _isDark ? const Color(0xFF71767B) : const Color(0xFF687078);

  Color get _divider =>
      _isDark ? const Color(0xFF2F3336) : const Color(0xFFE5E7EB);

  static const Color _linkColor = Color(0xFF2563EB);

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();

    if (widget.initialUser != null) {
      _user = Map<String, dynamic>.from(widget.initialUser!);
    }

    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
    });

    await Future.wait([
      _loadProfile(),
      _loadPosts(),
    ]);
  }

  Future<void> _loadProfile() async {
    try {
      final result = await ApiService.getUserProfile(
        userId: widget.userId,
      );

      if (!mounted) return;

      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Unable to load profile');
      }

      final raw = result['data']?['user'];

      if (raw is! Map) {
        throw Exception('Profile data not found');
      }

      setState(() {
        _user = Map<String, dynamic>.from(raw);
        _loadingProfile = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadingProfile = false;

        // Keep showing the basic info we already have, if any.
        if (_user == null) {
          _error = error.toString().replaceFirst('Exception: ', '');
        }
      });
    }
  }

  Future<void> _loadPosts() async {
    try {
      final result = await ApiService.getPosts();

      if (!mounted) return;

      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Unable to load posts');
      }

      final raw = result['data']?['posts'];

      final list = <Map<String, dynamic>>[];

      if (raw is List) {
        for (final item in raw) {
          if (item is! Map) continue;

          final post = Map<String, dynamic>.from(item);

          final author = post['author'];

          final authorId = author is Map
              ? (author['_id'] ?? author['id'])?.toString()
              : author?.toString();

          if (authorId == widget.userId) {
            list.add(post);
          }
        }
      }

      setState(() {
        _posts = list;
        _loadingPosts = false;
      });
    } catch (error) {
      debugPrint('Load user posts error: $error');

      if (!mounted) return;

      setState(() {
        _loadingPosts = false;
      });
    }
  }

  // ============================================================
  // FOLLOW
  // ============================================================

  bool get _isFollowing => _user?['isFollowing'] == true;

  bool get _isMe => _user?['isMe'] == true;

  int get _followersCount => (_user?['followersCount'] as num?)?.toInt() ?? 0;

  int get _followingCount => (_user?['followingCount'] as num?)?.toInt() ?? 0;

  Future<void> _toggleFollow() async {
    if (_followBusy || _user == null) return;

    final wasFollowing = _isFollowing;

    // Optimistic update.
    setState(() {
      _followBusy = true;
      _user = {
        ..._user!,
        'isFollowing': !wasFollowing,
        'followersCount':
            (_followersCount + (wasFollowing ? -1 : 1)).clamp(0, 1 << 31),
      };
    });

    try {
      final result = await ApiService.toggleFollow(
        userId: widget.userId,
      );

      if (!mounted) return;

      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Unable to update follow');
      }

      final data = result['data'];

      setState(() {
        _user = {
          ..._user!,
          if (data is Map && data['following'] is bool)
            'isFollowing': data['following'],
          if (data is Map && data['followersCount'] is num)
            'followersCount': data['followersCount'],
        };
      });
    } catch (error) {
      if (!mounted) return;

      // Roll back.
      setState(() {
        _user = {
          ..._user!,
          'isFollowing': wasFollowing,
          'followersCount': wasFollowing
              ? _followersCount + 1
              : (_followersCount - 1).clamp(0, 1 << 31),
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _followBusy = false;
        });
      }
    }
  }

  // ============================================================
  // USER DATA
  // ============================================================

  String _field(String key) => _user?[key]?.toString().trim() ?? '';

  String get _username => _field('username');

  String get _displayName {
    final name = _field('displayName');

    return name.isNotEmpty ? name : (_username.isNotEmpty ? _username : 'User');
  }

  String get _initial =>
      _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'U';

  String get _joinedText {
    final date = DateTime.tryParse(_field('createdAt'))?.toLocal();

    if (date == null) return '';

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return 'Joined ${months[date.month - 1]} ${date.year}';
  }

  String get _dobText {
    final date = DateTime.tryParse(_field('dateOfBirth'))?.toLocal();

    if (date == null) return '';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ============================================================
  // IMAGES
  // ============================================================

  ImageProvider? _provider(dynamic value) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty) return null;

    if (text.startsWith('data:image/')) {
      final bytes = ApiService.dataUrlToBytes(text);

      return bytes == null ? null : MemoryImage(Uint8List.fromList(bytes));
    }

    final url = ApiService.normalizeImageUrl(text);

    return url == null ? null : NetworkImage(url);
  }

  Widget _avatar(dynamic value, String name, double size) {
    final provider = _provider(value);

    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _secondarySurface,
      ),
      clipBehavior: Clip.antiAlias,
      child: provider == null
          ? Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: _text,
                  fontSize: size * .4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : Image(
              image: provider,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: _text,
                    fontSize: size * .4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
    );
  }

  void _openPhoto(dynamic value) {
    final provider = _provider(value);

    if (provider == null) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image(image: provider, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _openWebsite() async {
    var value = _field('website');

    if (value.isEmpty) return;

    if (!value.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      value = 'https://$value';
    }

    final uri = Uri.tryParse(value);

    var opened = false;

    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (error) {
        debugPrint('Open website error: $error');
      }
    }

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Unable to open this link'),
        ),
      );
    }
  }

  String _timeAgo(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();

    if (date == null) return '';

    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';

    return '${date.day}/${date.month}/${date.year}';
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _meta(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: _text.withOpacity(.78)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _muted,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _count(int count, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: _text,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: _muted, fontSize: 14),
        ),
      ],
    );
  }

  Widget _cover() {
    final provider = _provider(_user?['coverPhoto']);

    return GestureDetector(
      onTap: () => _openPhoto(_user?['coverPhoto']),
      child: SizedBox(
        width: double.infinity,
        height: 170,
        child: provider == null
            ? Container(color: _secondarySurface)
            : Image(
                image: provider,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: _secondarySurface),
              ),
      ),
    );
  }

  Widget _followButton() {
    final following = _isFollowing;

    final bg = following
        ? Colors.transparent
        : (_isDark ? Colors.white : Colors.black);

    final fg = following ? _text : (_isDark ? Colors.black : Colors.white);

    return SizedBox(
      height: 38,
      child: ElevatedButton(
        onPressed: _followBusy ? null : _toggleFollow,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg.withOpacity(.6),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: following ? _divider : Colors.transparent,
            ),
          ),
        ),
        child: Text(
          following ? 'Following' : 'Follow',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _header() {
    final bio = _field('bio');
    final location = _field('location');
    final website = _field('website');

    // The cover sits behind; the content starts 126px down so the
    // avatar overlaps the cover's bottom edge. A Stack (instead of a
    // transform) keeps taps on the overlapping part working.
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 170,
          child: _cover(),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 126),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => _openPhoto(_user?['avatar']),
                      child: Container(
                        width: 94,
                        height: 94,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _background,
                          shape: BoxShape.circle,
                        ),
                        child: _avatar(_user?['avatar'], _displayName, 86),
                      ),
                    ),
                    const Spacer(),
                    if (!_isMe && _user != null) _followButton(),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        _displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _text,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (_username.isNotEmpty)
                      Flexible(
                        child: Text(
                          '@$_username',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _muted, fontSize: 14),
                        ),
                      ),
                  ],
                ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    bio,
                    style: TextStyle(
                      color: _text,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
                if (location.isNotEmpty || _dobText.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 7,
                    children: [
                      if (location.isNotEmpty)
                        _meta(CupertinoIcons.location_solid, location),
                      if (_dobText.isNotEmpty)
                        _meta(Icons.cake_rounded, _dobText),
                    ],
                  ),
                ],
                if (_joinedText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _meta(Icons.calendar_month_rounded, _joinedText),
                ],
                if (website.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openWebsite,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          size: 18,
                          color: _linkColor,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            website,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _linkColor,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    _count(_followingCount, 'Following'),
                    const SizedBox(width: 20),
                    _count(_followersCount, 'Followers'),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: _divider)),
                  ),
                  child: Text(
                    'Posts',
                    style: TextStyle(
                      color: _text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // POSTS
  // ============================================================

  Widget _postImage(dynamic value) {
    final provider = _provider(value);

    if (provider == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image(
          image: provider,
          width: double.infinity,
          height: 240,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, int count) {
    return Padding(
      padding: const EdgeInsets.only(right: 22),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _muted),
          const SizedBox(width: 5),
          Text('$count', style: TextStyle(color: _muted, fontSize: 13)),
        ],
      ),
    );
  }

  int _num(dynamic value) => value is num ? value.toInt() : 0;

  Widget _postCard(Map<String, dynamic> post) {
    final repostOf = post['repostOf'] is Map
        ? Map<String, dynamic>.from(post['repostOf'])
        : null;

    final isRepost = repostOf != null;

    final content = (post['content'] ?? '').toString();

    final image = (post['image'] ?? '').toString().trim().isNotEmpty
        ? post['image']
        : repostOf?['image'];

    final likeCount = post['likesCount'] is num
        ? _num(post['likesCount'])
        : (post['likes'] is List ? (post['likes'] as List).length : 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRepost)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(CupertinoIcons.arrow_2_squarepath,
                      size: 15, color: _muted),
                  const SizedBox(width: 6),
                  Text(
                    'Reposted',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(_user?['avatar'], _displayName, 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '@$_username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _muted, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('•', style: TextStyle(color: _muted)),
                        const SizedBox(width: 6),
                        Text(
                          _timeAgo(post['createdAt']),
                          style: TextStyle(color: _muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                    if (content.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        content,
                        style: TextStyle(
                          color: _text,
                          fontSize: 15.5,
                          height: 1.42,
                        ),
                      ),
                    ],
                    _postImage(image),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _statItem(CupertinoIcons.heart, likeCount),
                        _statItem(
                          CupertinoIcons.bubble_left,
                          _num(post['commentsCount']),
                        ),
                        _statItem(
                          CupertinoIcons.arrow_2_squarepath,
                          _num(post['repostsCount']),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _text,
        title: Text(
          _user == null ? 'Profile' : _displayName,
          style: TextStyle(
            color: _text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _user == null && _loadingProfile
          ? Center(child: CircularProgressIndicator(color: _text))
          : _user == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error ?? 'Unable to load profile',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _loadingProfile = true;
                              _loadingPosts = true;
                            });
                            _load();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: _text,
                  backgroundColor: _surface,
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _header(),
                      if (_loadingPosts)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_posts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'No posts yet',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._posts.map(_postCard),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }
}