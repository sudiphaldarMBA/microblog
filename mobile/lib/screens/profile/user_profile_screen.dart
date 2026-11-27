import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../widgets/comments_sheet.dart';
import '../../widgets/verified_badge.dart';
import 'package:share_plus/share_plus.dart';
import '../home/home_video_player.dart';
import 'follow_list_screen.dart';

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

int _selectedTabIndex = 0;

List<Map<String, dynamic>> _commentedPosts = [];

bool _loadingCommentedPosts = true;

// Videos posted from the Shorts screen.
List<Map<String, dynamic>> _shortPosts = [];

bool _loadingShorts = true;

List<Map<String, dynamic>> get _profilePosts {
  return _posts.where((post) {
    final repost = post['repostOf'];
    return repost == null || repost == false;
  }).toList();
}

List<Map<String, dynamic>> get _profileReposts {
  return _posts.where((post) => post['repostOf'] is Map).toList();
}

List<Map<String, dynamic>> get _profileLikes {
  return _posts.where((post) {
    final likes = post['likes'];

    if (likes is! List) return false;

    return likes.any((like) {
      if (like is Map) {
        return (like['_id'] ?? like['id'])?.toString() ==
            widget.userId;
      }

      return like.toString() == widget.userId;
    });
  }).toList();
}

List<Map<String, dynamic>> get _visiblePosts {
  switch (_selectedTabIndex) {
    case 0:
      return _profilePosts;
    case 1:
      return _profileReposts;
    case 2:
      return _profileLikes;
    case 3:
      return _commentedPosts;
    case 4:
      return _shortPosts;
    default:
      return _profilePosts;
  }
}


bool _actionBusy = false;


String _postId(Map<String, dynamic> post) {
  return (post['_id'] ?? post['id'] ?? '').toString();
}

String _postAuthorId(Map<String, dynamic> post) {
  final author = post['author'];

  if (author is Map) {
    return (author['_id'] ?? author['id'] ?? '').toString();
  }

  return author?.toString() ?? '';
}

Future<void> _toggleLikePost(Map<String, dynamic> post) async {
  final postId = _postId(post);
  if (postId.isEmpty) return;

  final wasLiked = post['likedByMe'] == true;
  final oldCount = _num(post['likesCount']);

  setState(() {
    post['likedByMe'] = !wasLiked;
    post['likesCount'] = (oldCount + (wasLiked ? -1 : 1)).clamp(0, 1 << 31);
  });

  try {
    final result = await ApiService.toggleLike(postId: postId);

    if (result['success'] != true) {
      throw Exception(result['message'] ?? 'Unable to update like');
    }

    if (!mounted) return;

    final data = result['data'];
    if (data is Map) {
      setState(() {
        if (data['likedByMe'] is bool) {
          post['likedByMe'] = data['likedByMe'];
        } else if (data['liked'] is bool) {
          post['likedByMe'] = data['liked'];
        }

        if (data['likesCount'] is num) {
          post['likesCount'] = _num(data['likesCount']);
        }
      });
    }
  } catch (error) {
    if (!mounted) return;

    setState(() {
      post['likedByMe'] = wasLiked;
      post['likesCount'] = oldCount;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }
}

Future<void> _openPostComments(Map<String, dynamic> post) async {
  final postId = _postId(post);
  if (postId.isEmpty) return;

  int? latestCount;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.85,
        child: CommentsSheet(
          postId: postId,
          onCountChanged: (count) => latestCount = count,
        ),
      );
    },
  );

  if (!mounted) return;

  final newCount = latestCount;
  if (newCount != null) {
    setState(() {
      post['commentsCount'] = newCount;
    });
  }
}

Future<void> _repostProfilePost(Map<String, dynamic> post) async {
  final repostOf = post['repostOf'];
  final original = repostOf is Map
      ? Map<String, dynamic>.from(repostOf)
      : null;

  final targetId = original == null ? _postId(post) : _postId(original);
  if (targetId.isEmpty) return;

  final captionController = TextEditingController();

  final caption = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: _surface,
      title: Text('Repost', style: TextStyle(color: _text)),
      content: TextField(
        controller: captionController,
        maxLength: 300,
        maxLines: 3,
        style: TextStyle(color: _text),
        decoration: InputDecoration(
          hintText: 'Add a comment (optional)',
          hintStyle: TextStyle(color: _muted),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text('Cancel', style: TextStyle(color: _muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            dialogContext,
            captionController.text.trim(),
          ),
          child: Text('Repost', style: TextStyle(color: _accent)),
        ),
      ],
    ),
  );

  captionController.dispose();

  if (caption == null) return;

  try {
    final result = await ApiService.repost(
      postId: targetId,
      caption: caption,
    );

    if (result['success'] != true) {
      throw Exception(result['message'] ?? 'Unable to repost');
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Repost updated')),
    );

    await _loadPosts();
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }
}

Future<void> _shareProfilePost(Map<String, dynamic> post) async {
  final author = post['author'];
  final username = author is Map
      ? (author['username'] ?? '').toString()
      : '';

  final content = (post['content'] ?? '').toString().trim();

  final text = [
    if (username.isNotEmpty) '@$username on MicroBlog:',
    if (content.isNotEmpty) content,
    'Shared from MicroBlog',
  ].join('\n\n');

  await SharePlus.instance.share(
    ShareParams(
      text: text,
      subject: 'MicroBlog post',
    ),
  );
}

  // ============================================================
  // COLORS (same palette as the home / my profile screens)
  // ============================================================

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  /// Icons: black in light mode, white in dark mode.
  Color get _iconColor => _isDark ? Colors.white : Colors.black;

  Color get _background =>
      _isDark ? const Color(0xFF08090B) : const Color(0xFFF7F8FA);

  Color get _surface =>
      _isDark ? const Color(0xFF15171B) : const Color(0xFFFFFFFF);

  Color get _secondarySurface =>
      _isDark ? const Color(0xFF202329) : const Color(0xFFF0F1F4);

  Color get _text =>
      _isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111318);

  Color get _muted =>
      _isDark ? const Color(0xFF9297A0) : const Color(0xFF737B86);

  Color get _divider =>
      _isDark ? const Color(0xFF282B31) : const Color(0xFFE6E8EC);

  static const Color _accent = Color(0xFFF91880);
  static const Color _linkColor = Color(0xFF2563EB);

  Widget _boldIcon(IconData icon, double size, Color color) {
    return Icon(
      icon,
      size: size,
      color: color,
      shadows: [
        Shadow(color: color, offset: const Offset(.45, 0)),
        Shadow(color: color, offset: const Offset(-.45, 0)),
      ],
    );
  }

  String _formatCount(int value) {
    if (value < 1000) {
      return value < 0 ? '0' : value.toString();
    }

    if (value > 10000000) {
      return '10M+';
    }

    if (value >= 10000000) {
      return '10M';
    }

    if (value >= 1000000) {
      final number = value / 1000000;

      return '${number.toStringAsFixed(number == number.roundToDouble() ? 0 : 1)}M';
    }

    final number = value / 1000;

    return '${number.toStringAsFixed(number >= 100 || number == number.roundToDouble() ? 0 : 1)}K';
  }

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
  if (!mounted) return;

  setState(() {
    _error = null;
    _loadingProfile = true;
    _loadingPosts = true;
  });

  await Future.wait<void>([
  _loadProfile(),
  _loadPosts(),
  _loadCommentedPosts(),
  _loadShortPosts(),
]);
}

  
Future<void> _loadProfile() async {
  try {
    final result = await ApiService.getUserProfile(
      userId: widget.userId,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      throw Exception(
        result['message'] ?? 'Unable to load profile',
      );
    }

    final data = result['data'];
    final raw = data is Map ? data['user'] : null;

    if (raw is! Map) {
      throw Exception('Complete profile data was not returned');
    }

    final profile = Map<String, dynamic>.from(raw);

    // Verify that the backend returned the requested user's profile.
    final returnedId =
        (profile['_id'] ?? profile['id'])?.toString() ?? '';

    if (returnedId.isNotEmpty && returnedId != widget.userId) {
      throw Exception('The returned profile does not match this user');
    }

    setState(() {
      _user = profile;
      _error = null;
      _loadingProfile = false;
    });
  } catch (error) {
    if (!mounted) return;

    debugPrint('Load public profile error: $error');

    setState(() {
      // Never present partial navigation data as a complete profile.
      _user = null;
      _loadingProfile = false;
      _error = error.toString().replaceFirst('Exception: ', '');
    });
  }
}


Future<void> _loadPosts() async {
  try {
    final result = await ApiService.getPosts();

    if (!mounted) return;

    if (result['success'] != true) {
      throw Exception(
        result['message'] ?? 'Unable to load posts',
      );
    }

    final raw = result['data']?['posts'];
    final list = <Map<String, dynamic>>[];

    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;

        final post = Map<String, dynamic>.from(item);
        final author = post['author'];

        final authorId = author is Map
            ? (author['_id'] ?? author['id'])?.toString() ?? ''
            : author?.toString() ?? '';

        if (authorId == widget.userId) {
          list.add(post);
        }
      }
    }

    if (!mounted) return;

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


Future<void> _loadShortPosts() async {
  try {
    final result = await ApiService.getShorts(userId: widget.userId);

    if (!mounted) return;

    final raw = result['data']?['posts'];

    final posts = result['success'] == true && raw is List
        ? raw
            .whereType<Map>()
            .map((post) => Map<String, dynamic>.from(post))
            .toList()
        : <Map<String, dynamic>>[];

    setState(() {
      _shortPosts = posts;
      _loadingShorts = false;
    });
  } catch (error) {
    debugPrint('Load user shorts error: $error');

    if (!mounted) return;

    setState(() {
      _shortPosts = [];
      _loadingShorts = false;
    });
  }
}

Future<void> _loadCommentedPosts() async {
  if (!mounted) return;

  setState(() {
    _loadingCommentedPosts = true;
  });

  try {
    final result = await ApiService.getUserCommentedPosts(
      userId: widget.userId,
    );

    if (result['success'] != true) {
      throw Exception(
        result['message'] ?? 'Unable to load commented posts',
      );
    }

    final raw = result['data']?['posts'];

    final posts = raw is List
        ? raw
            .whereType<Map>()
            .map((post) => Map<String, dynamic>.from(post))
            .toList()
        : <Map<String, dynamic>>[];

    if (!mounted) return;

    setState(() {
      _commentedPosts = posts;
      _loadingCommentedPosts = false;
    });
  } catch (error) {
    debugPrint('Load user commented posts error: $error');

    if (!mounted) return;

    setState(() {
      _commentedPosts = [];
      _loadingCommentedPosts = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.toString().replaceFirst('Exception: ', ''),
        ),
      ),
    );
  }
}

  // ============================================================
  // FOLLOW
  // ============================================================

  bool get _isFollowing => _user?['isFollowing'] == true;

  bool get _isMe => _user?['isMe'] == true;

  bool _flagVerified(Map<dynamic, dynamic>? user) {
    if (user == null) return false;

    return user['isVerified'] == true ||
        user['verified'] == true ||
        user['verificationStatus']?.toString().toLowerCase() == 'verified';
  }

  /// Is the person whose profile this is verified?
  bool get _isVerified => _flagVerified(_user);


  /// Business accounts only.
  bool _isBusinessAccount(Map<dynamic, dynamic>? user) {
    return user?['accountType']?.toString().toLowerCase() == 'business';
  }

  bool get _isBusiness => _isBusinessAccount(_user);

  Widget _businessBadge({double fontSize = 11}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _accent.withOpacity(0.65),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.business_outlined,
            size: fontSize + 3,
            color: _accent,
          ),
          const SizedBox(width: 4),
          Text(
            'Business',
            style: TextStyle(
              color: _accent,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }


  /// Is this post author verified? (Posts shown here by the profile owner
  /// use the profile's own verification state.)
  bool _authorVerified(Map<String, dynamic> author) {
    final id = (author['_id'] ?? author['id'] ?? '').toString();

    if (id.isNotEmpty && id == widget.userId && _isVerified) return true;

    return _flagVerified(author);
  }

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
        Icon(icon, size: 17, color: _iconColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _muted,
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _count(int count, String label, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatCount(count),
              style: TextStyle(
                color: _text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: _muted,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openConnections({required bool followers}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowListScreen(
          userId: widget.userId,
          followers: followers,
        ),
      ),
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
            ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _accent.withOpacity(_isDark ? .30 : .18),
                      _secondarySurface,
                    ],
                  ),
                ),
              )
            : Image(
                image: provider,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _accent.withOpacity(_isDark ? .30 : .18),
                      _secondarySurface,
                    ],
                  ),
                ),
              ),
              ),
      ),
    );
  }

  Widget _followButton() {
    final following = _isFollowing;

    return SizedBox(
      height: 34,
      child: ElevatedButton(
        onPressed: _followBusy ? null : _toggleFollow,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: following ? Colors.transparent : _text,
          foregroundColor: following
              ? _text
              : (_isDark ? Colors.black : Colors.white),
          disabledBackgroundColor: following ? Colors.transparent : _text,
          disabledForegroundColor: (following
                  ? _text
                  : (_isDark ? Colors.black : Colors.white))
              .withOpacity(.6),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: following ? _divider : Colors.transparent,
              width: 1.4,
            ),
          ),
        ),
        child: Text(
          following ? 'Following' : 'Follow',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
        ),
      ),
    );
  }

  Widget _header() {
    final bio = _field('bio');
    final location = _field('location');
    final website = _field('website');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover photo with the profile photo overlapping its bottom edge.
        SizedBox(
          height: 170 + 48,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 170,
                child: _cover(),
              ),
              Positioned(
                left: 16,
                top: 170 - 44,
                child: GestureDetector(
                  onTap: () => _openPhoto(_user?['avatar']),
                  child: Container(
                    width: 92,
                    height: 92,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _background,
                      shape: BoxShape.circle,
                    ),
                    child: _avatar(_user?['avatar'], _displayName, 84),
                  ),
                ),
              ),
              if (!_isMe && _user != null)
                Positioned(right: 16, top: 170 + 8, child: _followButton()),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _text,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.4,
                      ),
                    ),
                  ),
                  if (_isVerified) ...[
                  const SizedBox(width: 6),
                  const VerifiedBadge(size: 16),
                  ],
                  if (_isBusiness) ...[
                  const SizedBox(width: 7),
                  _businessBadge(),
                  ],
                  const SizedBox(width: 8),
                  if (_username.isNotEmpty)
                    Flexible(
                      child: Text(
                        '@$_username',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  bio,
                  style: TextStyle(color: _text, fontSize: 15, height: 1.4),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (location.isNotEmpty)
                    _meta(CupertinoIcons.location_solid, location),
                  if (_dobText.isNotEmpty) _meta(Icons.cake_rounded, _dobText),
                  if (_joinedText.isNotEmpty)
                    _meta(Icons.calendar_month_rounded, _joinedText),
                ],
              ),
              if (website.isNotEmpty) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openWebsite,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link_rounded, size: 18, color: _iconColor),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          website,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _linkColor,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
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
                  _count(
                    _followingCount,
                    'Following',
                    () => _openConnections(followers: false),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: _accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  _count(
                    _followersCount,
                    'Followers',
                    () => _openConnections(followers: true),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // POSTS
  // ============================================================

  int _num(dynamic value) => value is num ? value.toInt() : 0;

  List<String> _mediaList(dynamic list, dynamic single) {
    final items = <String>[];

    if (list is List) {
      for (final item in list) {
        final value = item?.toString().trim() ?? '';

        if (value.isNotEmpty) items.add(value);
      }
    }

    if (items.isEmpty) {
      final value = single?.toString().trim() ?? '';

      if (value.isNotEmpty) items.add(value);
    }

    return items;
  }

  Widget _buildPostImage(String value, {double height = 260}) {
    final provider = _provider(value);

    if (provider == null) {
      return Container(
        height: 180,
        width: double.infinity,
        color: _secondarySurface,
        child: Icon(CupertinoIcons.photo, color: _muted, size: 32),
      );
    }

    return Image(
      image: provider,
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: 180,
        width: double.infinity,
        color: _secondarySurface,
        child: Icon(CupertinoIcons.photo, color: _muted, size: 32),
      ),
    );
  }

  Widget _buildMedia(Map<String, dynamic> source, {double imageHeight = 260}) {
    final images = _mediaList(
      source['images'],
      source['image'] ?? source['imageUrl'] ?? source['mediaUrl'],
    );

    final videos = _mediaList(
      source['videos'],
      source['video'] ?? source['videoUrl'],
    );

    if (images.isEmpty && videos.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxVideoHeight = MediaQuery.of(context).size.height * .6;

    Widget videoPlayer(String data) {
      return ClipRect(
        child: OverflowBox(
          minHeight: 0,
          maxHeight: double.infinity,
          alignment: Alignment.center,
          child: HomeVideoPlayer(videoData: data),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          if (images.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: images.length > 1
                  ? _MediaPager(
                      height: imageHeight + 40,
                      children: [
                        for (final item in images)
                          _buildPostImage(item, height: imageHeight + 40),
                      ],
                    )
                  : _buildPostImage(images.first, height: imageHeight),
            ),
          if (videos.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: images.isNotEmpty ? 10 : 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.black,
                  child: videos.length > 1
                      ? _MediaPager(
                          height: maxVideoHeight,
                          children: [
                            for (final item in videos)
                              Center(child: videoPlayer(item)),
                          ],
                        )
                      : ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: maxVideoHeight,
                          ),
                          child: videoPlayer(videos.first),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> post) {
    final repostOf = post['repostOf'] is Map
        ? Map<String, dynamic>.from(post['repostOf'])
        : null;

    final isRepost = repostOf != null;

    final author = post['author'];

    final authorMap = author is Map
        ? Map<String, dynamic>.from(author)
        : <String, dynamic>{};

    final content = (post['content'] ?? '').toString();

    final likeCount = post['likesCount'] is num
        ? _num(post['likesCount'])
        : (post['likes'] is List ? (post['likes'] as List).length : 0);

    final displayName =
        (authorMap['displayName'] ?? authorMap['username'] ?? _displayName)
            .toString();

    final username = (authorMap['username'] ?? _username).toString();

    final liked = post['likedByMe'] == true;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _divider, width: .6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRepost)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  _boldIcon(CupertinoIcons.arrow_2_squarepath, 15, _muted),
                  const SizedBox(width: 6),
                  Text(
                    'Reposted',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

          // HEADER
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(authorMap['avatar'], displayName, 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _text,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (_authorVerified(authorMap)) ...[
                          const SizedBox(width: 4),
                          const VerifiedBadge(size: 15),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '@$username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _muted, fontSize: 13.5),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('•', style: TextStyle(color: _muted)),
                        const SizedBox(width: 6),
                        Text(
                          _timeAgo(post['createdAt']),
                          style: TextStyle(color: _muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (content.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              content,
              style: TextStyle(color: _text, fontSize: 15.5, height: 1.42),
            ),
          ],

          if (!isRepost) _buildMedia(post),

          if (isRepost) ...[
            const SizedBox(height: 10),
            _quotedPost(repostOf),
          ],

          const SizedBox(height: 6),

          // ACTIONS (same icons / size as my profile and home)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _actionButton(
                icon: liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                color: liked ? _accent : _muted,
                count: likeCount,
                onTap: () => _toggleLikePost(post),
              ),
              _actionButton(
                icon: CupertinoIcons.bubble_left,
                count: _num(post['commentsCount']),
                onTap: () => _openPostComments(post),
              ),
              _actionButton(
                icon: CupertinoIcons.arrow_2_squarepath,
                count: _num(post['repostsCount']),
                onTap: () => _repostProfilePost(post),
              ),
              _actionButton(
                icon: CupertinoIcons.arrowshape_turn_up_right,
                count: _num(post['sharesCount']),
                onTap: () => _shareProfilePost(post),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quotedPost(Map<String, dynamic> original) {
    final authorRaw = original['author'];

    final author = authorRaw is Map
        ? Map<String, dynamic>.from(authorRaw)
        : <String, dynamic>{};

    final name = (author['displayName'] ?? author['username'] ?? 'User')
        .toString();

    final username = (author['username'] ?? '').toString();

    final content = (original['content'] ?? '').toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: _divider),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(author['avatar'], name, 28),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_authorVerified(author)) ...[
                const SizedBox(width: 4),
                const VerifiedBadge(size: 14),
              ],
              if (username.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '@$username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
          if (content.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              content,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _text, fontSize: 14, height: 1.35),
            ),
          ],
          _buildMedia(original, imageHeight: 190),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required VoidCallback onTap,
    int? count,
    Color? color,
  }) {
    final tint = color ?? _muted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _boldIcon(icon, 21, tint),
            if (count != null && count > 0) ...[
              const SizedBox(width: 5),
              Text(
                _formatCount(count),
                style: TextStyle(
                  color: tint,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _profileTabs() {
    const icons = [
      CupertinoIcons.doc_text,
      CupertinoIcons.arrow_2_squarepath,
      CupertinoIcons.heart,
      CupertinoIcons.bubble_left,
      CupertinoIcons.play_rectangle,
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _divider)),
      ),
      child: Row(
        children: List.generate(icons.length, (index) {
          final selected = _selectedTabIndex == index;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _selectedTabIndex = index;
                });
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: _boldIcon(
                      selected && index == 2
                          ? CupertinoIcons.heart_fill
                          : icons[index],
                      22,
                      selected ? _accent : _muted,
                    ),
                  ),
                  Container(
                    height: 3,
                    width: 42,
                    decoration: BoxDecoration(
                      color: selected ? _accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
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
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: _text,
        shape: Border(bottom: BorderSide(color: _divider, width: 0.8)),
        title: Text(
          _user == null ? 'Profile' : _displayName,
          style: TextStyle(
            color: _text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator(color: _accent))
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
                  color: _accent,
                  backgroundColor: _surface,
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      
_header(),

_profileTabs(),

if (_selectedTabIndex == 4
    ? _loadingShorts
    : _selectedTabIndex == 3
        ? _loadingCommentedPosts
        : _loadingPosts)
  const Padding(
    padding: EdgeInsets.all(32),
    child: Center(
      child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
    ),
  ),

if (!(_selectedTabIndex == 4
        ? _loadingShorts
        : _selectedTabIndex == 3
            ? _loadingCommentedPosts
            : _loadingPosts) &&
    _visiblePosts.isEmpty)
  Padding(
    padding: const EdgeInsets.all(36),
    child: Center(
      child: Column(
        children: [
          _boldIcon(
            _selectedTabIndex == 4
                ? CupertinoIcons.play_rectangle
                : _selectedTabIndex == 3
                ? CupertinoIcons.bubble_left
                : _selectedTabIndex == 2
                    ? CupertinoIcons.heart
                    : _selectedTabIndex == 1
                        ? CupertinoIcons.arrow_2_squarepath
                        : CupertinoIcons.doc_text,
            32,
            _muted,
          ),
          const SizedBox(height: 12),
          Text(
            [
              'No posts yet',
              'No reposts yet',
              'No liked posts yet',
              'No commented posts yet',
              'No shorts yet',
            ][_selectedTabIndex],
            style: TextStyle(
              color: _muted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ),
  ),

if (!(_selectedTabIndex == 4
        ? _loadingShorts
        : _selectedTabIndex == 3
            ? _loadingCommentedPosts
            : _loadingPosts) &&
    _visiblePosts.isNotEmpty)
  ..._visiblePosts.map(_postCard),

const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }
}

// ==================================================================
// MEDIA PAGER (1/N, 2/N ... badge when there is more than one item)
// ==================================================================

class _MediaPager extends StatefulWidget {
  final double height;
  final List<Widget> children;

  const _MediaPager({required this.height, required this.children});

  @override
  State<_MediaPager> createState() => _MediaPagerState();
}

class _MediaPagerState extends State<_MediaPager> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final total = widget.children.length;

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          PageView(
            onPageChanged: (value) => setState(() => _page = value),
            children: widget.children,
          ),
          if (total > 1)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_page + 1}/$total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}