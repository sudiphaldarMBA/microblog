import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../services/api_service.dart';
import '../../widgets/comments_sheet.dart';
import '../profile/profile_screen.dart';
import '../profile/user_profile_screen.dart';

class ShortsScreen extends StatefulWidget {
  const ShortsScreen({super.key});

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  static const Color _background = Colors.black;
  static const Color _accent = Color(0xFF1D9BF0);
  static const Color _pink = Color(0xFFF91880);

  final PageController _pageController = PageController();
  final Set<String> _viewedThisSession = {};

  List<Map<String, dynamic>> _shorts = [];
  bool _loading = true;
  String? _error;
  int _activeIndex = 0;

  String _myId = '';
  bool _publishing = false;

  // True while another screen (for example a profile) is open on top,
  // so the Short stops playing in the background.
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _loadShorts();
  }

  Future<void> _loadMe() async {
    try {
      final me = await ApiService.getCurrentUser();
      _myId = (me['_id'] ?? me['id'] ?? '').toString();
    } catch (_) {}
  }

  Map<String, dynamic> _authorOf(Map<String, dynamic> post) {
    final author = post['author'];
    return author is Map ? Map<String, dynamic>.from(author) : {};
  }

  String _displayName(Map<String, dynamic> post) {
    final author = _authorOf(post);
    final name = author['displayName']?.toString().trim() ?? '';
    return name.isNotEmpty ? name : _username(post);
  }

  Future<void> _openAuthor(Map<String, dynamic> post) async {
    final author = _authorOf(post);
    final authorId = (author['_id'] ?? author['id'] ?? '').toString();

    if (authorId.isEmpty) return;

    setState(() => _paused = true);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => authorId == _myId
            ? const ProfileScreen()
            : UserProfileScreen(userId: authorId, initialUser: author),
      ),
    );

    if (!mounted) return;

    setState(() => _paused = false);
  }

  // ------------------------------------------------------------
  // CREATE A SHORT (camera icon)
  // ------------------------------------------------------------

  Future<void> _createShort() async {
    if (_publishing) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF15171B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        Widget option(IconData icon, String label, ImageSource value) {
          return ListTile(
            leading: Icon(icon, color: _pink, size: 24),
            title: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            onTap: () => Navigator.pop(sheetContext, value),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF282B31),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              option(
                CupertinoIcons.videocam,
                'Record a video',
                ImageSource.camera,
              ),
              option(
                CupertinoIcons.photo_on_rectangle,
                'Choose from gallery',
                ImageSource.gallery,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (source == null || !mounted) return;

    try {
      final XFile? video = await ImagePicker().pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 100),
      );

      if (video == null || !mounted) return;

      final caption = await _askCaption();

      if (caption == null || !mounted) return;

      setState(() => _publishing = true);

      final data = await ApiService.fileToDataUrl(File(video.path));

      final result = await ApiService.createPost(
        content: caption,
        video: data,
        isShort: true,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _showMessage('Short posted');
        await _loadShorts();
      } else {
        _showMessage(result['message']?.toString() ?? 'Unable to post Short');
      }
    } catch (error) {
      debugPrint('Create Short error: $error');
      _showMessage('Unable to post Short');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<String?> _askCaption() {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF15171B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'New Short',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: TextField(
            controller: controller,
            maxLength: 300,
            maxLines: 3,
            minLines: 1,
            cursorColor: _pink,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Write a caption...',
              hintStyle: TextStyle(color: Color(0xFF9297A0)),
              counterStyle: TextStyle(color: Color(0xFF9297A0)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text(
                'Post',
                style: TextStyle(
                  color: _pink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadShorts() async {
    try {
      final result = await ApiService.getShorts();

      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Unable to load videos');
      }

      final rawPosts = result['data']?['posts'];

      final videos = <Map<String, dynamic>>[];

      if (rawPosts is List) {
        for (final item in rawPosts) {
          if (item is! Map) continue;

          final post = Map<String, dynamic>.from(item);
          final video = post['video']?.toString().trim() ?? '';

          if (video.isNotEmpty) {
            videos.add(post);
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _shorts = videos;
        _loading = false;
        _error = null;
      });

      if (videos.isNotEmpty) {
        _recordView(0);
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _postId(Map<String, dynamic> post) {
    return (post['_id'] ?? post['id'] ?? '').toString();
  }

  String _username(Map<String, dynamic> post) {
    final author = post['author'];

    if (author is Map) {
      final name = author['username']?.toString();
      final displayName = author['displayName']?.toString();

      if (name != null && name.trim().isNotEmpty) return name;
      if (displayName != null && displayName.trim().isNotEmpty) {
        return displayName;
      }
    }

    return 'user';
  }

  String _caption(Map<String, dynamic> post) {
    final content = post['content']?.toString().trim() ?? '';
    return content.isEmpty ? ' ' : content;
  }

  int _count(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _recordView(int index) async {
    if (index < 0 || index >= _shorts.length) return;

    final post = _shorts[index];
    final id = _postId(post);

    if (id.isEmpty || !_viewedThisSession.add(id)) return;

    try {
      final result = await ApiService.recordView(postId: id);

      if (!mounted || result['success'] != true) return;

      final serverCount = result['data']?['viewsCount'];

      if (serverCount != null) {
        setState(() {
          final currentIndex = _shorts.indexWhere(
            (item) => _postId(item) == id,
          );

          if (currentIndex != -1) {
            _shorts[currentIndex]['viewsCount'] = _count(serverCount);
          }
        });
      } else {
        setState(() {
          post['viewsCount'] = _count(post['viewsCount']) + 1;
        });
      }
    } catch (error) {
      debugPrint('Unable to record Short view: $error');
    }
  }

  Future<void> _toggleLike(int index) async {
    final post = _shorts[index];
    final id = _postId(post);

    if (id.isEmpty) return;

    try {
      final result = await ApiService.toggleLike(postId: id);

      if (!mounted) return;

      if (result['success'] != true) {
        _showMessage(result['message']?.toString() ?? 'Unable to like post');
        return;
      }

      setState(() {
        final wasLiked = post['likedByMe'] == true;
        post['likedByMe'] = !wasLiked;
        post['likesCount'] = (_count(post['likesCount']) + (wasLiked ? -1 : 1))
            .clamp(0, 1 << 30);
      });
    } catch (error) {
      _showMessage('Unable to update like');
      debugPrint('Short like error: $error');
    }
  }

  Future<void> _toggleBookmark(int index) async {
    final post = _shorts[index];
    final id = _postId(post);

    if (id.isEmpty) return;

    try {
      final result = await ApiService.toggleBookmark(postId: id);

      if (!mounted) return;

      if (result['success'] != true) {
        _showMessage(
          result['message']?.toString() ?? 'Unable to update bookmark',
        );
        return;
      }

      setState(() {
        post['bookmarkedByMe'] = !(post['bookmarkedByMe'] == true);
      });

      _showMessage(
        post['bookmarkedByMe'] == true
            ? 'Short bookmarked'
            : 'Bookmark removed',
      );
    } catch (error) {
      _showMessage('Unable to update bookmark');
      debugPrint('Short bookmark error: $error');
    }
  }

  void _openComments(Map<String, dynamic> post) {
    final id = _postId(post);
    if (id.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(postId: id),
    );
  }

  Future<void> _sharePost(Map<String, dynamic> post) async {
    final id = _postId(post);
    final text = [
      '@${_username(post)}',
      _caption(post).trim(),
      if (id.isNotEmpty) 'MicroBlog post: $id',
    ].where((part) => part.trim().isNotEmpty).join('\n\n');

    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (error) {
      _showMessage('Unable to share this Short');
      debugPrint('Short share error: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildBody()),

            // Compact header.
            Positioned(
              top: 8,
              left: 16,
              right: 12,
              child: Row(
                children: [
                  const Text(
                    'Shorts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Create Short',
                    visualDensity: VisualDensity.compact,
                    onPressed: _createShort,
                    icon: const Icon(
                      CupertinoIcons.camera,
                      color: _pink,
                      size: 23,
                      shadows: [
                        Shadow(color: _pink, offset: Offset(.45, 0)),
                        Shadow(color: _pink, offset: Offset(-.45, 0)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh Shorts',
                    visualDensity: VisualDensity.compact,
                    onPressed: _loadShorts,
                    icon: const Icon(
                      CupertinoIcons.refresh,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ],
              ),
            ),

            if (_publishing)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: _pink),
                      SizedBox(height: 14),
                      Text(
                        'Posting your Short...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }

    if (_error != null) {
      return _emptyState(
        icon: CupertinoIcons.wifi_exclamationmark,
        title: 'Could not load Shorts',
        subtitle: _error!,
        buttonText: 'Try again',
        onPressed: _loadShorts,
      );
    }

    if (_shorts.isEmpty) {
      return _emptyState(
        icon: CupertinoIcons.play_rectangle,
        title: 'No videos yet',
        subtitle: 'Posts containing videos will appear here.',
        buttonText: 'Refresh',
        onPressed: _loadShorts,
      );
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: _shorts.length,
      onPageChanged: (index) {
        setState(() => _activeIndex = index);
      },
      itemBuilder: (context, index) {
        final post = _shorts[index];

        return _ShortPage(
          key: ValueKey(_postId(post)),
          post: post,
          isActive: index == _activeIndex && !_paused,
          username: _username(post),
          displayName: _displayName(post),
          avatar: _authorOf(post)['avatar'],
          onOpenAuthor: () => _openAuthor(post),
          caption: _caption(post),
          likesCount: _count(post['likesCount']),
          commentsCount: _count(post['commentsCount']),
          viewsCount: _count(post['viewsCount']),
          isLiked: post['likedByMe'] == true,
          isBookmarked: post['bookmarkedByMe'] == true,
          onLike: () => _toggleLike(index),
          onComment: () => _openComments(post),
          onShare: () => _sharePost(post),
          onBookmark: () => _toggleBookmark(index),
          onPlaybackStarted: () => _recordView(index),
        );
      },
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 54),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: onPressed, child: Text(buttonText)),
          ],
        ),
      ),
    );
  }
}

class _ShortPage extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isActive;
  final String username;
  final String displayName;
  final dynamic avatar;
  final VoidCallback onOpenAuthor;
  final String caption;
  final int likesCount;
  final int commentsCount;
  final int viewsCount;
  final bool isLiked;
  final bool isBookmarked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onBookmark;
  final VoidCallback onPlaybackStarted;

  const _ShortPage({
    super.key,
    required this.post,
    required this.isActive,
    required this.username,
    required this.displayName,
    required this.avatar,
    required this.onOpenAuthor,
    required this.caption,
    required this.likesCount,
    required this.commentsCount,
    required this.viewsCount,
    required this.isLiked,
    required this.isBookmarked,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onBookmark,
    required this.onPlaybackStarted,
  });

  @override
  State<_ShortPage> createState() => _ShortPageState();
}

class _ShortPageState extends State<_ShortPage> {
  VideoPlayerController? _controller;
  bool _initializing = true;
  bool _failed = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant _ShortPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isActive != widget.isActive) {
      _syncPlayback();
    }
  }

  Future<void> _initializeVideo() async {
    VideoPlayerController? controller;

    try {
      final String value = widget.post['video']?.toString().trim() ?? '';

      if (value.isEmpty) {
        throw Exception('Video data is empty');
      }

      // Match the video-source handling used by HomeVideoPlayer.
      if (value.startsWith('data:video') || !value.startsWith('http')) {
        final String base64Str = value.contains(',')
            ? value.split(',').last
            : value;

        final bytes = base64Decode(base64Str);

        final Directory tempDir = Directory.systemTemp;
        final String tempPath = '${tempDir.path}/microblog_videos';
        final Directory videoFolder = Directory(tempPath);

        if (!await videoFolder.exists()) {
          await videoFolder.create(recursive: true);
        }

        final String id = (widget.post['_id'] ?? widget.post['id'] ?? 'short')
            .toString();

        final File videoFile = File(
          '$tempPath/short_${id}_${DateTime.now().microsecondsSinceEpoch}.mp4',
        );

        await videoFile.writeAsBytes(bytes, flush: true);

        controller = VideoPlayerController.file(videoFile);
      } else {
        // HTTP and HTTPS video URLs.
        final Uri? videoUri = Uri.tryParse(value);

        if (videoUri == null ||
            (videoUri.scheme != 'http' && videoUri.scheme != 'https')) {
          throw Exception('Invalid video URL');
        }

        controller = VideoPlayerController.networkUrl(videoUri);
      }

      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_isMuted ? 0.0 : 1.0);
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _controller = controller;

      setState(() {
        _initializing = false;
        _failed = false;
      });

      // Play only the currently visible Short.
      await _syncPlayback();
    } catch (error) {
      debugPrint('Short video initialization error: $error');

      if (controller != null) {
        if (identical(controller, _controller)) {
          _controller = null;
        }

        await controller.dispose();
      }

      if (mounted) {
        setState(() {
          _initializing = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _syncPlayback() async {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    try {
      if (widget.isActive) {
        await controller.play();

        if (mounted && controller.value.isPlaying) {
          widget.onPlaybackStarted();
        }
      } else {
        await controller.pause();
      }
    } catch (error) {
      debugPrint('Short playback error: $error');
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else if (widget.isActive) {
      await controller.play();
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF101318)),

        if (controller != null && controller.value.isInitialized)
          GestureDetector(
            onTap: _togglePlayback,
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio > 0
                    ? controller.value.aspectRatio
                    : 9 / 16,
                child: VideoPlayer(controller),
              ),
            ),
          )
        else if (_initializing)
          const Center(child: CircularProgressIndicator(color: Colors.white))
        else
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.video_camera,
                  size: 54,
                  color: Colors.white70,
                ),
                const SizedBox(height: 10),
                Text(
                  _failed ? 'Unable to play this video' : 'Video unavailable',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

        if (controller != null &&
            controller.value.isInitialized &&
            !controller.value.isPlaying)
          Center(
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.play_fill,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),

        // Bottom gradient improves caption readability.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 230,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Creator and caption.
        Positioned(
          left: 16,
          right: 84,
          bottom: 25,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onOpenAuthor,
                child: Row(
                  children: [
                    _avatar(widget.avatar, widget.displayName, 18),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.username.isNotEmpty
                            ? '${widget.displayName}  @${widget.username}'
                            : widget.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.caption.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  widget.caption,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                '${_formatCount(widget.viewsCount)} views',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),

        // Compact, consistently aligned action rail.
        Positioned(
          right: 9,
          bottom: 84,
          child: SizedBox(
            width: 62,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ShortAction(
                  icon: widget.isLiked
                      ? CupertinoIcons.heart_fill
                      : CupertinoIcons.heart,
                  color: widget.isLiked
                      ? const Color(0xFFF91880)
                      : Colors.white,
                  label: _formatCount(widget.likesCount),
                  onTap: widget.onLike,
                ),
                const SizedBox(height: 15),
                _ShortAction(
                  icon: CupertinoIcons.bubble_left,
                  label: _formatCount(widget.commentsCount),
                  onTap: widget.onComment,
                ),
                const SizedBox(height: 15),
                _ShortAction(
                  icon: CupertinoIcons.arrowshape_turn_up_right,
                  label: 'Share',
                  onTap: widget.onShare,
                ),
                const SizedBox(height: 15),
                _ShortAction(
                  icon: widget.isBookmarked
                      ? CupertinoIcons.bookmark_fill
                      : CupertinoIcons.bookmark,
                  color: widget.isBookmarked
                      ? const Color(0xFF1D9BF0)
                      : Colors.white,
                  label: 'Save',
                  onTap: widget.onBookmark,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatar(dynamic image, String name, double radius) {
    final value = image?.toString().trim() ?? '';

    Widget fallback() {
      final trimmed = name.trim();

      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF25282D),
        child: Text(
          trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * .8,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    if (value.isEmpty) return fallback();

    final bytes = ApiService.dataUrlToBytes(value);
    final url = bytes == null ? ApiService.normalizeImageUrl(value) : null;

    if (bytes == null && url == null) return fallback();

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF25282D),
      backgroundImage: bytes != null
          ? MemoryImage(bytes) as ImageProvider
          : NetworkImage(url!),
      onBackgroundImageError: (_, __) {},
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }
}

class _ShortAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ShortAction({
    required this.icon,
    required this.label,
    this.color = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 21,
                shadows: [
                  Shadow(color: color, offset: const Offset(.45, 0)),
                  Shadow(color: color, offset: const Offset(-.45, 0)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}