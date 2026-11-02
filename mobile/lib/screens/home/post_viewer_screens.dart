import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'home_video_player.dart';

// ==================================================================
// SHARED HELPERS
// ==================================================================

const Color _kAccent = Color(0xFFF91880);

/// Returns the live UI state of one post, owned by HomeScreen:
/// {liked, saved, likes, comments, reposts, shares, views}.
typedef PostStateReader = Map<String, dynamic> Function(String postId);

String _fmt(int value) {
  if (value >= 1000000) {
    final v = value / 1000000;
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}M';
  }

  if (value >= 1000) {
    final v = value / 1000;
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}K';
  }

  return '$value';
}

int _int(dynamic value) => value is num ? value.toInt() : 0;

Widget _avatarCircle(dynamic image, String name, double radius, bool dark) {
  final value = image?.toString().trim() ?? '';

  Widget fallback() {
    final trimmed = name.trim();

    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dark ? const Color(0xFF25282D) : const Color(0xFFE4E7EB),
      ),
      child: Text(
        trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: dark ? Colors.white : const Color(0xFF111318),
          fontSize: radius * .72,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  if (value.isEmpty) return fallback();

  final bytes = ApiService.dataUrlToBytes(value);

  final ImageProvider? provider = bytes != null
      ? MemoryImage(Uint8List.fromList(bytes))
      : (ApiService.normalizeImageUrl(value) != null
          ? NetworkImage(ApiService.normalizeImageUrl(value)!)
          : null);

  if (provider == null) return fallback();

  return ClipOval(
    child: Image(
      image: provider,
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback(),
    ),
  );
}

/// Slightly bolder outline icon (the Cupertino outline glyphs are thin).
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

// ==================================================================
// POST DETAIL (X-style full screen post)
// ==================================================================

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> author;
  final String content;
  final String media;
  final String videoMedia;
  final String location;
  final dynamic avatar;
  final dynamic createdAt;
  final String currentUserId;

  final PostStateReader readState;

  final Future<void> Function() onLike;
  final Future<void> Function() onComment;
  final Future<void> Function() onRepost;
  final Future<void> Function() onShare;
  final Future<void> Function() onBookmark;
  final VoidCallback onOpenAuthor;

  const PostDetailScreen({
    super.key,
    required this.postId,
    required this.author,
    required this.content,
    required this.media,
    required this.videoMedia,
    required this.location,
    required this.avatar,
    required this.createdAt,
    required this.currentUserId,
    required this.readState,
    required this.onLike,
    required this.onComment,
    required this.onRepost,
    required this.onShare,
    required this.onBookmark,
    required this.onOpenAuthor,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  bool _following = false;
  bool _followBusy = false;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color get _bg => _dark ? const Color(0xFF08090B) : Colors.white;
  Color get _text => _dark ? Colors.white : const Color(0xFF111318);
  Color get _muted => _dark ? const Color(0xFF9297A0) : const Color(0xFF737B86);
  Color get _divider =>
      _dark ? const Color(0xFF282B31) : const Color(0xFFE6E8EC);

  String get _authorId =>
      widget.author['_id']?.toString() ?? widget.author['id']?.toString() ?? '';

  bool get _isMe =>
      widget.currentUserId.isNotEmpty && _authorId == widget.currentUserId;

  String get _name {
    for (final key in ['displayName', 'name', 'fullName', 'username']) {
      final v = widget.author[key]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }

    return 'User';
  }

  String get _username => widget.author['username']?.toString().trim() ?? '';

  @override
  void initState() {
    super.initState();
    _loadFollowState();
  }

  Future<void> _loadFollowState() async {
    if (_authorId.isEmpty || _isMe) return;

    try {
      final result = await ApiService.getUserProfile(userId: _authorId);

      if (!mounted) return;

      final user = result['data']?['user'];

      if (result['success'] == true && user is Map) {
        setState(() {
          _following = user['isFollowing'] == true;
        });
      }
    } catch (error) {
      debugPrint('Follow state error: $error');
    }
  }

  Future<void> _toggleFollow() async {
    if (_followBusy || _authorId.isEmpty) return;

    final was = _following;

    setState(() {
      _followBusy = true;
      _following = !was;
    });

    try {
      final result = await ApiService.toggleFollow(userId: _authorId);

      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Unable to update follow');
      }

      final data = result['data'];

      if (mounted && data is Map && data['following'] is bool) {
        setState(() {
          _following = data['following'] as bool;
        });
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _following = was;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(error.toString().replaceFirst('Exception: ', '')),
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

  // Runs one of HomeScreen's actions, refreshing this screen right away
  // (optimistic state) and again once the action completes.
  Future<void> _run(Future<void> Function() action) async {
    final future = action();

    if (mounted) setState(() {});

    await future;

    if (mounted) setState(() {});
  }

  String _timeText() {
    final date = DateTime.tryParse(widget.createdAt?.toString() ?? '')
        ?.toLocal();

    if (date == null) return '';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$hour12:$minute $period · ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _image() {
    final text = widget.media;

    final bytes = ApiService.dataUrlToBytes(text);

    Widget child;

    if (bytes != null) {
      child = Image.memory(
        Uint8List.fromList(bytes),
        width: double.infinity,
        fit: BoxFit.fitWidth,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else {
      final url = ApiService.normalizeImageUrl(text);

      if (url == null) return const SizedBox.shrink();

      child = Image.network(
        url,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
    );
  }

  Widget _stat(int count, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: _fmt(count),
              style: TextStyle(
                color: _text,
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
            TextSpan(
              text: ' $label',
              style: TextStyle(color: _muted, fontSize: 14.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Center(child: _boldIcon(icon, 25, color)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.readState(widget.postId);

    final liked = state['liked'] == true;
    final saved = state['saved'] == true;

    final likes = _int(state['likes']);
    final comments = _int(state['comments']);
    final reposts = _int(state['reposts']);
    final shares = _int(state['shares']);
    final views = _int(state['views']);

    final followBg = _following
        ? Colors.transparent
        : (_dark ? Colors.white : Colors.black);

    final followFg = _following
        ? _text
        : (_dark ? Colors.black : Colors.white);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _text,
        title: Text(
          'Post',
          style: TextStyle(
            color: _text,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        shape: Border(bottom: BorderSide(color: _divider, width: 0.8)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // ------------------------------------------------------
          // AUTHOR + FOLLOW
          // ------------------------------------------------------
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onOpenAuthor,
                child: _avatarCircle(widget.avatar, _name, 24, _dark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onOpenAuthor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _text,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_username.isNotEmpty)
                        Text(
                          '@$_username',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _muted, fontSize: 14),
                        ),
                    ],
                  ),
                ),
              ),
              if (!_isMe && _authorId.isNotEmpty)
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: _followBusy ? null : _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: followBg,
                      foregroundColor: followFg,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: _following ? _divider : Colors.transparent,
                        ),
                      ),
                    ),
                    child: Text(
                      _following ? 'Following' : 'Follow',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),

          // ------------------------------------------------------
          // TEXT
          // ------------------------------------------------------
          if (widget.content.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              widget.content,
              style: TextStyle(color: _text, fontSize: 20, height: 1.4),
            ),
          ],

          // ------------------------------------------------------
          // LOCATION
          // ------------------------------------------------------
          if (widget.location.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: _muted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    widget.location,
                    style: TextStyle(color: _muted, fontSize: 14),
                  ),
                ),
              ],
            ),
          ],

          // ------------------------------------------------------
          // MEDIA
          // ------------------------------------------------------
          if (widget.media.isNotEmpty) _image(),

          if (widget.videoMedia.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: HomeVideoPlayer(videoData: widget.videoMedia),
              ),
            ),

          // ------------------------------------------------------
          // TIME + VIEWS
          // ------------------------------------------------------
          const SizedBox(height: 16),
          Text(
            [
              _timeText(),
              '${_fmt(views)} views',
            ].where((e) => e.isNotEmpty).join(' · '),
            style: TextStyle(color: _muted, fontSize: 14),
          ),

          Divider(height: 28, color: _divider),

          // ------------------------------------------------------
          // COUNTS
          // ------------------------------------------------------
          Wrap(
            runSpacing: 6,
            children: [
              _stat(reposts, 'Reposts'),
              _stat(likes, 'Likes'),
              _stat(comments, 'Comments'),
              _stat(shares, 'Shares'),
            ],
          ),

          Divider(height: 28, color: _divider),

          // ------------------------------------------------------
          // ACTIONS
          // ------------------------------------------------------
          Row(
            children: [
              _action(
                liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                liked ? _kAccent : _muted,
                () => _run(widget.onLike),
              ),
              _action(
                CupertinoIcons.bubble_left,
                _muted,
                () => _run(widget.onComment),
              ),
              _action(
                CupertinoIcons.arrow_2_squarepath,
                _muted,
                () => _run(widget.onRepost),
              ),
              _action(
                CupertinoIcons.arrowshape_turn_up_right,
                _muted,
                () => _run(widget.onShare),
              ),
              _action(
                saved ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
                saved ? _kAccent : _muted,
                () => _run(widget.onBookmark),
              ),
            ],
          ),

          Divider(height: 28, color: _divider),
        ],
      ),
    );
  }
}

// ==================================================================
// FULL SCREEN VIDEO FEED (tap a video post -> swipe up for more)
// ==================================================================

class VideoFeedScreen extends StatefulWidget {
  /// Each item: {id, post, videoData, name, username, avatar, content,
  /// author}.
  final List<Map<String, dynamic>> items;
  final int initialIndex;

  final PostStateReader readState;

  final Future<void> Function(String postId) onLike;
  final Future<void> Function(String postId) onComment;
  final Future<void> Function(Map<String, dynamic> post) onRepost;
  final Future<void> Function(Map<String, dynamic> post) onShare;
  final void Function(Map<String, dynamic> author) onOpenAuthor;

  const VideoFeedScreen({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.readState,
    required this.onLike,
    required this.onComment,
    required this.onRepost,
    required this.onShare,
    required this.onOpenAuthor,
  });

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();

    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    final future = action();

    if (mounted) setState(() {});

    await future;

    if (mounted) setState(() {});
  }

  Widget _side(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _boldIcon(icon, 30, color),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page(Map<String, dynamic> item) {
    final id = item['id'].toString();

    final post = Map<String, dynamic>.from(item['post'] as Map);

    final author = Map<String, dynamic>.from(item['author'] as Map);

    final state = widget.readState(id);

    final liked = state['liked'] == true;

    final name = item['name']?.toString() ?? '';
    final username = item['username']?.toString() ?? '';
    final content = item['content']?.toString() ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height,
            ),
            child: HomeVideoPlayer(
              key: ValueKey('feed-video-$id'),
              videoData: item['videoData'].toString(),
            ),
          ),
        ),

        // Bottom gradient for readable text.
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 240,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                ),
              ),
            ),
          ),
        ),

        // Author + caption + views.
        Positioned(
          left: 16,
          right: 84,
          bottom: 28,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onOpenAuthor(author),
                  child: Row(
                    children: [
                      _avatarCircle(item['avatar'], name, 18, true),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          username.isNotEmpty ? '$name  @$username' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (content.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      CupertinoIcons.eye,
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${_fmt(_int(state['views']))} views',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Right action column.
        Positioned(
          right: 10,
          bottom: 28,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _side(
                  liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  _fmt(_int(state['likes'])),
                  liked ? _kAccent : Colors.white,
                  () => _run(() => widget.onLike(id)),
                ),
                _side(
                  CupertinoIcons.bubble_left,
                  _fmt(_int(state['comments'])),
                  Colors.white,
                  () => _run(() => widget.onComment(id)),
                ),
                _side(
                  CupertinoIcons.arrow_2_squarepath,
                  _fmt(_int(state['reposts'])),
                  Colors.white,
                  () => _run(() => widget.onRepost(post)),
                ),
                _side(
                  CupertinoIcons.arrowshape_turn_up_right,
                  _fmt(_int(state['shares'])),
                  Colors.white,
                  () => _run(() => widget.onShare(post)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            scrollDirection: Axis.vertical,
            itemCount: widget.items.length,
            itemBuilder: (_, index) => _page(widget.items[index]),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}