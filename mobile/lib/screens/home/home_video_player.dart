import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class HomeVideoPlayer extends StatefulWidget {
  final String videoData;

  const HomeVideoPlayer({super.key, required this.videoData});

  @override
  State<HomeVideoPlayer> createState() => _HomeVideoPlayerState();
}

class _HomeVideoPlayerState extends State<HomeVideoPlayer> {
  VideoPlayerController? _controller;

  bool _initialized = false;
  bool _hasError = false;

  // Videos start muted by default.
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final String value = widget.videoData.trim();

      if (value.isEmpty) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
        return;
      }

      // --------------------------------------------------------
      // CASE 1: BASE64 / DATA URL VIDEO
      // --------------------------------------------------------
      if (value.startsWith('data:video') || !value.startsWith('http')) {
        final String base64Str = value.contains(',')
            ? value.split(',').last
            : value;

        final Uint8List bytes = base64Decode(base64Str);

        final Directory tempDir = Directory.systemTemp;

        final String tempPath = '${tempDir.path}/microblog_videos';

        final Directory videoFolder = Directory(tempPath);

        if (!await videoFolder.exists()) {
          await videoFolder.create(recursive: true);
        }

        final File videoFile = File(
          '$tempPath/vid_${DateTime.now().microsecondsSinceEpoch}.mp4',
        );

        await videoFile.writeAsBytes(bytes, flush: true);

        _controller = VideoPlayerController.file(videoFile);
      }
      // --------------------------------------------------------
      // CASE 2: HTTP / HTTPS VIDEO URL
      // --------------------------------------------------------
      else {
        final Uri? videoUri = Uri.tryParse(value);

        if (videoUri != null) {
          _controller = VideoPlayerController.networkUrl(videoUri);
        }
      }

      // --------------------------------------------------------
      // INITIALIZE VIDEO CONTROLLER
      // --------------------------------------------------------
      if (_controller != null) {
        await _controller!.initialize();

        await _controller!.setLooping(true);

        // Start muted.
        await _controller!.setVolume(_isMuted ? 0.0 : 1.0);

        if (mounted) {
          setState(() {
            _initialized = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      }
    } catch (error) {
      debugPrint('Home Video Player Error: $error');

      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // MUTE / UNMUTE
  // ------------------------------------------------------------
  void _toggleMute() {
    if (_controller == null || !_initialized) {
      return;
    }

    setState(() {
      _isMuted = !_isMuted;
    });

    _controller!.setVolume(_isMuted ? 0.0 : 1.0);
  }

  // ------------------------------------------------------------
  // DISPOSE
  // ------------------------------------------------------------
  @override
  void dispose() {
    _controller?.pause();
    _controller?.dispose();

    super.dispose();
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // ----------------------------------------------------------
    // PLAYBACK ERROR
    // ----------------------------------------------------------
    if (_hasError) {
      return Container(
        height: 240,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF17191C) : const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_camera_back_outlined,
              size: 42,
              color: isDark ? const Color(0xFF8D939C) : const Color(0xFF69707A),
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

    // ----------------------------------------------------------
    // LOADING
    // ----------------------------------------------------------
    if (!_initialized || _controller == null) {
      return Container(
        height: 240,
        width: double.infinity,
        color: isDark ? const Color(0xFF17191C) : const Color(0xFFF1F3F5),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1D9BF0)),
          ),
        ),
      );
    }

    // ----------------------------------------------------------
    // VIDEO PLAYER
    // ----------------------------------------------------------
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // --------------------------------------------------
            // VIDEO
            // Tap video to Play / Pause
            // --------------------------------------------------
            GestureDetector(
              onTap: () {
                setState(() {
                  if (_controller!.value.isPlaying) {
                    _controller!.pause();
                  } else {
                    _controller!.play();
                  }
                });
              },
              child: VideoPlayer(_controller!),
            ),

            // --------------------------------------------------
            // PLAY BUTTON
            // Shown when video is paused
            // --------------------------------------------------
            if (!_controller!.value.isPlaying)
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

            // --------------------------------------------------
            // MUTE / UNMUTE BUTTON
            // --------------------------------------------------
            Positioned(
              bottom: 12,
              right: 12,
              child: GestureDetector(
                onTap: _toggleMute,
                child: CircleAvatar(
                  backgroundColor: Colors.black26,
                  radius: 18,
                  child: Icon(
                    _isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
