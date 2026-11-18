import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import 'package:share_plus/share_plus.dart';
import '../home/home_video_player.dart';

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

  final result = await ApiService.getComments(postId: postId);

  if (!mounted) return;

  if (result['success'] != true) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? 'Unable to load comments'),
      ),
    );
    return;
  }

  final rawComments = result['data']?['comments'];
  final comments = rawComments is List
      ? rawComments.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  final controller = TextEditingController();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      bool sending = false;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> sendComment() async {
            final text = controller.text.trim();
            if (text.isEmpty || sending) return;

            setSheetState(() => sending = true);

            try {
              final response = await ApiService.createComment(
                postId: postId,
                content: text,
              );

              if (response['success'] != true) {
                throw Exception(response['message'] ?? 'Unable to comment');
              }

              final created = response['data']?['comment'];
              if (created is Map) {
                setSheetState(() {
                  comments.add(Map<String, dynamic>.from(created));
                });
              }

              controller.clear();

              final currentCount = _num(post['commentsCount']);
              if (mounted) {
                setState(() {
                  post['commentsCount'] = currentCount + 1;
                });
              }
            } catch (error) {
              if (sheetContext.mounted) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(content: Text(error.toString())),
                );
              }
            } finally {
              if (sheetContext.mounted) {
                setSheetState(() => sending = false);
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 18,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * .65,
              child: Column(
                children: [
                  Text(
                    'Comments',
                    style: TextStyle(
                      color: _text,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: comments.isEmpty
                        ? Center(
                            child: Text(
                              'No comments yet',
                              style: TextStyle(color: _muted),
                            ),
                          )
                        : ListView.builder(
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              final comment = comments[index];
                              final author = comment['author'];
                              final name = author is Map
                                  ? (author['displayName'] ??
                                          author['username'] ??
                                          'User')
                                      .toString()
                                  : 'User';

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    color: _text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  (comment['content'] ?? '').toString(),
                                  style: TextStyle(color: _muted),
                                ),
                              );
                            },
                          ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          style: TextStyle(color: _text),
                          decoration: InputDecoration(
                            hintText: 'Write a comment...',
                            hintStyle: TextStyle(color: _muted),
                            filled: true,
                            fillColor: _background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: sending ? null : sendComment,
                        icon: sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(CupertinoIcons.paperplane_fill),
                        color: _accent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  controller.dispose();
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

  static const Color _accent = Color(0xFFF91880);
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
              fontWeight: FontWeight.w700,
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
          style: TextStyle(
  color: _muted,
  fontSize: 14,
  fontWeight: FontWeight.w700,
),
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
                              color: _accent,
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

Widget _buildMedia(Map<String, dynamic> source) {
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
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final image in images) _postImage(image),

        for (final video in videos)
          Padding(
            padding: EdgeInsets.only(top: images.isNotEmpty ? 10 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.black,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxVideoHeight,
                  ),
                  child: videoPlayer(video),
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
  final originalAuthor = repostOf?['author'];

  final author = post['author'];
  final authorMap = author is Map
      ? Map<String, dynamic>.from(author)
      : <String, dynamic>{};

  final originalAuthorMap = originalAuthor is Map
      ? Map<String, dynamic>.from(originalAuthor)
      : <String, dynamic>{};

  final content = (post['content'] ?? '').toString();

  final likeCount = post['likesCount'] is num
      ? _num(post['likesCount'])
      : (post['likes'] is List ? (post['likes'] as List).length : 0);

  final displayName = (authorMap['displayName'] ??
          authorMap['username'] ??
          _displayName)
      .toString();

  final username = (authorMap['username'] ?? _username).toString();

  final originalName = (originalAuthorMap['displayName'] ??
          originalAuthorMap['username'] ??
          'Original author')
      .toString();

  final originalUsername =
      (originalAuthorMap['username'] ?? '').toString();

  final liked = post['likedByMe'] == true;

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
                Icon(
                  CupertinoIcons.arrow_2_squarepath,
                  size: 15,
                  color: _muted,
                ),
                const SizedBox(width: 6),
                Text(
                  'Reposted by $displayName',
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
            _avatar(authorMap['avatar'], displayName, 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
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
                          '@$username',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _muted, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                  if (isRepost) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: _divider),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            originalName,
                            style: TextStyle(
                              color: _text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (originalUsername.isNotEmpty)
                            Text(
                              '@$originalUsername',
                              style: TextStyle(color: _muted, fontSize: 12),
                            ),
                          if ((repostOf?['content'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              repostOf!['content'].toString(),
                              style: TextStyle(color: _text, height: 1.4),
                            ),
                          ],
                          _buildMedia(repostOf!),
                        ],
                      ),
                    ),
                  ] else
                    _buildMedia(post),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _actionButton(
                        icon: liked
                            ? CupertinoIcons.heart_fill
                            : CupertinoIcons.heart,
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
                        icon: CupertinoIcons.share,
                        onTap: () => _shareProfilePost(post),
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

Widget _actionButton({
  required IconData icon,
  required VoidCallback onTap,
  int? count,
  Color? color,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: color ?? _muted),
          if (count != null) ...[
            const SizedBox(width: 5),
            Text(
              '$count',
              style: TextStyle(color: color ?? _muted, fontSize: 12),
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
    CupertinoIcons.chat_bubble,
  ];

  return Container(
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: _divider),
      ),
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
                  child: Icon(
                    icons[index],
                    size: 22,
                    color: selected ? _text : _muted,
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
      body: _loadingProfile
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

_profileTabs(),

if (_selectedTabIndex == 3
    ? _loadingCommentedPosts
    : _loadingPosts)
  const Padding(
    padding: EdgeInsets.all(32),
    child: Center(
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  ),

if (!(_selectedTabIndex == 3
        ? _loadingCommentedPosts
        : _loadingPosts) &&
    _visiblePosts.isEmpty)
  Padding(
    padding: const EdgeInsets.all(36),
    child: Center(
      child: Column(
        children: [
          Icon(
            _selectedTabIndex == 3
                ? CupertinoIcons.bubble_left
                : _selectedTabIndex == 2
                    ? CupertinoIcons.heart
                    : _selectedTabIndex == 1
                        ? CupertinoIcons.arrow_2_squarepath
                        : CupertinoIcons.doc_text,
            size: 32,
            color: _muted,
          ),
          const SizedBox(height: 12),
          Text(
            [
              'No posts yet',
              'No reposts yet',
              'No liked posts yet',
              'No commented posts yet',
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

if (!(_selectedTabIndex == 3
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
