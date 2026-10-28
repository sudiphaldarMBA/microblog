
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class ShortsScreen extends StatefulWidget {
  const ShortsScreen({super.key});

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  static const Color _background = Colors.black;
  static const Color _accent = Color(0xFF1D9BF0);

  final PageController _pageController = PageController();
  final Set<int> _likedShorts = {};

  // Temporary placeholders until the backend video-post format is connected.
  final List<Map<String, String>> _shorts = [
    {
      'username': 'microblog',
      'caption': 'Welcome to MicroBlog Shorts! 🎬',
    },
    {
      'username': 'microblog',
      'caption': 'Your next favorite short video belongs here.',
    },
  ];

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
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _shorts.length,
              itemBuilder: (context, index) {
                final short = _shorts[index];
                final isLiked = _likedShorts.contains(index);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: const Color(0xFF101318),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.play_rectangle,
                            size: 76,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'MicroBlog Shorts',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Video preview',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),

                    // Caption and creator details.
                    Positioned(
                      left: 16,
                      right: 88,
                      bottom: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${short['username'] ?? 'user'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            short['caption'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Actions on the right.
                    Positioned(
                      right: 16,
                      bottom: 35,
                      child: Column(
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                if (isLiked) {
                                  _likedShorts.remove(index);
                                } else {
                                  _likedShorts.add(index);
                                }
                              });
                            },
                            icon: Icon(
                              isLiked
                                  ? CupertinoIcons.heart_fill
                                  : CupertinoIcons.heart,
                              color: isLiked
                                  ? const Color(0xFFF91880)
                                  : Colors.white,
                              size: 34,
                            ),
                          ),
                          Text(
                            '${isLiked ? 1 : 0}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 20),
                          const Icon(
                            CupertinoIcons.chat_bubble,
                            color: Colors.white,
                            size: 30,
                          ),
                          const SizedBox(height: 20),
                          const Icon(
                            CupertinoIcons.arrowshape_turn_up_right,
                            color: Colors.white,
                            size: 30,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            // Header.
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  const Text(
                    'Shorts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      CupertinoIcons.camera,
                      color: Colors.white,
                      size: 26,
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
}
