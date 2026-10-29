
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../services/api_service.dart';
import '../../widgets/comments_sheet.dart';

class ShortsScreen extends StatefulWidget {
  const ShortsScreen({super.key});

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  static const Color _background = Colors.black;
  static const Color _accent = Color(0xFF1D9BF0);

  final PageController _pageController = PageController();
  final Set<String> _viewedThisSession = {};

  List<Map<String, dynamic>> _shorts = [];
  bool _loading = true;
  String? _error;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadShorts();
  }

  Future<void> _loadShorts() async {
    try {
      final result = await ApiService.getPosts();

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
          final currentIndex =
              _shorts.indexWhere((item) => _postId(item) == id);

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
        post['likesCount'] =
            (_count(post['likesCount']) + (wasLiked ? -1 : 1)).clamp(0, 1 << 30);
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
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _accent),
      );
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
        _recordView(index);
      },
      itemBuilder: (context, index) {
        final post = _shorts[index];

        return _ShortPage(
          key: ValueKey(_postId(post)),
          post: post,
          isActive: index == _activeIndex,
          username: _username(post),
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
            FilledButton(
              onPressed: onPressed,
              child: Text(buttonText),
            ),
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

  const _ShortPage({
    super.key,
    required this.post,
    required this.isActive,
    required this.username,
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
      final String base64Str =
          value.contains(',') ? value.split(',').last : value;

      final bytes = base64Decode(base64Str);

      final Directory tempDir = Directory.systemTemp;
      final String tempPath = '${tempDir.path}/microblog_videos';
      final Directory videoFolder = Directory(tempPath);

      if (!await videoFolder.exists()) {
        await videoFolder.create(recursive: true);
      }

      final String id =
          (widget.post['_id'] ?? widget.post['id'] ?? 'short').toString();

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

    if (controller == null || !controller.value.isInitialized) return;

    try {
      if (widget.isActive) {
        await controller.play();
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
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          )
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


Positioned(
  right: 23,
  bottom: 330,
  child: GestureDetector(
    onTap: () async {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) {
        return;
      }

      final newMutedState = !_isMuted;

      try {
        await controller.setVolume(newMutedState ? 0.0 : 1.0);

        if (!mounted) return;

        setState(() {
          _isMuted = newMutedState;
        });
      } catch (error) {
        debugPrint('Unable to change video volume: $error');
      }
    },
    child: CircleAvatar(
      radius: 18,
      backgroundColor: Colors.black54,
      child: Icon(
        _isMuted
            ? CupertinoIcons.speaker_slash_fill
            : CupertinoIcons.speaker_2_fill,
        color: Colors.white,
        size: 18,
      ),
    ),
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
              Text(
                '@${widget.username}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              if (widget.caption.trim().isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  widget.caption,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Compact, consistently aligned action rail.
        Positioned(
          right: 9,
          bottom: 24,
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
                const SizedBox(height: 15),
                _ShortAction(
                  icon: CupertinoIcons.eye,
                  label: _formatCount(widget.viewsCount),
                  onTap: null,
                ),
              ],
            ),
          ),
        ),
      ],
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
              Icon(icon, color: color, size: 25),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
