
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class HomeVideoPlayer extends StatefulWidget {
  final String videoData;

  const HomeVideoPlayer({
    super.key,
    required this.videoData,
  });

  @override
  State<HomeVideoPlayer> createState() => _HomeVideoPlayerState();
}

class _HomeVideoPlayerState extends State<HomeVideoPlayer> {
  VideoPlayerController? _controller;

  final Key _visibilityKey = UniqueKey();

  bool _initialized = false;
  bool _hasError = false;
  bool _isMuted = false;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(covariant HomeVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoData != widget.videoData) {
      final oldController = _controller;
      _controller = null;

      _initialized = false;
      _hasError = false;
      _isMuted = false;

      oldController?.dispose();
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    VideoPlayerController? controller;

    try {
      final value = widget.videoData.trim();

      if (value.isEmpty) {
        throw Exception('Video data is empty');
      }

      if (value.startsWith('data:video') || !value.startsWith('http')) {
        final base64Str = value.contains(',')
            ? value.split(',').last
            : value;

        final Uint8List bytes = base64Decode(base64Str);

        final tempDir = Directory.systemTemp;
        final tempPath = '${tempDir.path}/microblog_videos';
        final videoFolder = Directory(tempPath);

        if (!await videoFolder.exists()) {
          await videoFolder.create(recursive: true);
        }

        final videoFile = File(
          '$tempPath/vid_${DateTime.now().microsecondsSinceEpoch}.mp4',
        );

        await videoFile.writeAsBytes(bytes, flush: true);
        controller = VideoPlayerController.file(videoFile);
      } else {
        final uri = Uri.tryParse(value);

        if (uri == null ||
            (uri.scheme != 'http' && uri.scheme != 'https')) {
          throw Exception('Invalid video URL');
        }

        controller = VideoPlayerController.networkUrl(uri);
      }

      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1.0);

      if (!mounted) {
  await controller.dispose();
  return;
}

      // Do not play yet. Only the visibility callback decides
      // whether this video should be playing.
      _controller = controller;

      if (!mounted) return;

      setState(() {
        _initialized = true;
        _hasError = false;
      });

      await _syncPlayback();
    } catch (error) {
      debugPrint('Home Video Player Error: $error');

      if (controller != null) {
        if (identical(controller, _controller)) {
          _controller = null;
        }
        await controller.dispose();
      }

      if (mounted) {
        setState(() {
          _initialized = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _syncPlayback() async {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) return;

    try {
      if (_isVisible) {
        await controller.setVolume(_isMuted ? 0.0 : 1.0);
        if (!controller.value.isPlaying) {
          await controller.play();
        }
      } else {
        if (controller.value.isPlaying) {
          await controller.pause();
        }
      }

      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('Home video autoplay error: $error');
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visibleNow = info.visibleFraction >= 0.5;

    if (_isVisible == visibleNow) return;

    _isVisible = visibleNow;
    _syncPlayback();
  }

  Future<void> _toggleMute() async {
    final controller = _controller;

    if (controller == null || !_initialized) return;

    final newMutedState = !_isMuted;

    try {
      await controller.setVolume(newMutedState ? 0.0 : 1.0);

      if (!mounted) return;

      setState(() {
        _isMuted = newMutedState;
      });
    } catch (error) {
      debugPrint('Home video volume error: $error');
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;

    if (controller == null || !_initialized) return;

    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else if (_isVisible) {
        await controller.play();
      }

      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('Home video playback error: $error');
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;

    if (controller != null) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_hasError) {
      return Container(
        height: 240,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF17191C)
              : const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_camera_back_outlined,
              size: 42,
              color: isDark
                  ? const Color(0xFF8D939C)
                  : const Color(0xFF69707A),
            ),
            const SizedBox(height: 8),
            Text(
              'Playback Unavailable',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (!_initialized || _controller == null) {
      return Container(
        height: 240,
        width: double.infinity,
        color: isDark
            ? const Color(0xFF17191C)
            : const Color(0xFFF1F3F5),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Color(0xFF1D9BF0),
            ),
          ),
        ),
      );
    }

    final controller = _controller!;

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _onVisibilityChanged,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio > 0
              ? controller.value.aspectRatio
              : 16 / 9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: _togglePlayback,
                  child: VideoPlayer(controller),
                ),
              ),

              if (!controller.value.isPlaying)
                IgnorePointer(
                  child: CircleAvatar(
                    backgroundColor: Colors.black45,
                    radius: 28,
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),

              Positioned(
                bottom: 8,
                right: 8,
                child: Material(
                  color: Colors.black45,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: _isMuted ? 'Unmute video' : 'Mute video',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    onPressed: _toggleMute,
                    icon: Icon(
                      _isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
