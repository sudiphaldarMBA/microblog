// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_service.dart';
import 'comments_sheet.dart';

class PostCard extends StatefulWidget {
  final dynamic post;

  final VoidCallback? onChanged;

  const PostCard({super.key, required this.post, this.onChanged});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _liked;
  late bool _saved;
  late bool _reposted;

  late int _likes;
  late int _comments;
  late int _reposts;
  late int _shares;

  bool _liking = false;
  bool _saving = false;
  bool _reposting = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();

    _syncFromPost();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.post != widget.post) {
      _syncFromPost();
    }
  }

  void _syncFromPost() {
    final post = widget.post;

    _liked = post["likedByMe"] == true;

    _saved = post["bookmarkedByMe"] == true;

    _reposted = post["repostedByMe"] == true;

    _likes = _toInt(post["likesCount"]);

    _comments = _toInt(post["commentsCount"]);

    _reposts = _toInt(post["repostsCount"]);

    _shares = _toInt(post["sharesCount"]);
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  String _username() {
    final author = widget.post["author"];

    return author?["username"]?.toString() ?? "user";
  }

  String _displayName() {
    final author = widget.post["author"];

    final display = author?["displayName"]?.toString().trim();

    if (display != null && display.isNotEmpty) {
      return display;
    }

    return _username();
  }

  String _content() {
    return widget.post["content"]?.toString() ?? "";
  }

  String _postId() {
    return widget.post["_id"]?.toString() ?? "";
  }

  String _formatTime(dynamic value) {
    if (value == null) {
      return "";
    }

    final date = DateTime.tryParse(value.toString());

    if (date == null) {
      return "";
    }

    final difference = DateTime.now().difference(date);

    if (difference.inSeconds < 60) {
      return "now";
    }

    if (difference.inMinutes < 60) {
      return "${difference.inMinutes}m";
    }

    if (difference.inHours < 24) {
      return "${difference.inHours}h";
    }

    if (difference.inDays < 7) {
      return "${difference.inDays}d";
    }

    if (difference.inDays < 365) {
      return "${date.day}/${date.month}";
    }

    return "${date.day}/${date.month}/${date.year}";
  }

  Future<void> _toggleLike() async {
    if (_liking) return;

    final oldLiked = _liked;
    final oldLikes = _likes;

    setState(() {
      _liking = true;
      _liked = !_liked;
      _likes = _liked ? _likes + 1 : (_likes > 0 ? _likes - 1 : 0);
    });

    try {
      final result = await ApiService.toggleLike(postId: _postId());

      if (!mounted) return;

      if (result["success"] == true && result["data"] != null) {
        final data = result["data"];

        setState(() {
          _liked = data["liked"] == true;

          _likes = _toInt(data["likesCount"]);
        });

        widget.onChanged?.call();
      } else {
        setState(() {
          _liked = oldLiked;
          _likes = oldLikes;
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _liked = oldLiked;
        _likes = oldLikes;
      });
    } finally {
      if (mounted) {
        setState(() {
          _liking = false;
        });
      }
    }
  }

  Future<void> _toggleBookmark() async {
    if (_saving) return;

    final oldSaved = _saved;

    setState(() {
      _saving = true;
      _saved = !_saved;
    });

    try {
      final result = await ApiService.toggleBookmark(postId: _postId());

      if (!mounted) return;

      if (result["success"] == true && result["data"] != null) {
        setState(() {
          _saved = result["data"]["bookmarked"] == true;
        });

        widget.onChanged?.call();
      } else {
        setState(() {
          _saved = oldSaved;
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _saved = oldSaved;
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _toggleRepost() async {
    if (_reposting) return;

    final oldReposted = _reposted;
    final oldCount = _reposts;

    setState(() {
      _reposting = true;
      _reposted = !_reposted;

      _reposts = _reposted ? _reposts + 1 : (_reposts > 0 ? _reposts - 1 : 0);
    });

    try {
      final result = await ApiService.repost(postId: _postId(), caption: '');

      if (!mounted) return;

      if (result["success"] == true && result["data"] != null) {
        final data = result["data"];

        setState(() {
          _reposted = data["reposted"] == true;

          _reposts = _toInt(data["repostsCount"]);
        });

        widget.onChanged?.call();
      } else {
        setState(() {
          _reposted = oldReposted;
          _reposts = oldCount;
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _reposted = oldReposted;
        _reposts = oldCount;
      });
    } finally {
      if (mounted) {
        setState(() {
          _reposting = false;
        });
      }
    }
  }

  Future<void> _sharePost() async {
    if (_sharing) return;

    setState(() {
      _sharing = true;
    });

    final display = _displayName();

    final username = _username();

    final content = _content();

    final shareText =
        "$display (@$username) on MicroBlog\n\n"
        "$content\n\n"
        "♥ $_likes"
        "   💬 $_comments"
        "   ↻ $_reposts"
        "   ↗ $_shares\n\n"
        "Shared from MicroBlog";

    try {
      await SharePlus.instance.share(
        ShareParams(text: shareText, subject: "MicroBlog post"),
      );

      try {
        final result = await ApiService.recordShare(postId: _postId());

        if (!mounted) return;

        if (result["success"] == true && result["data"] != null) {
          setState(() {
            _shares = _toInt(result["data"]["sharesCount"]);
          });
        }
      } catch (_) {}
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Unable to share post")));
    } finally {
      if (mounted) {
        setState(() {
          _sharing = false;
        });
      }
    }
  }

  Future<void> _openComments() async {
    final postId = _postId();

    if (postId.isEmpty) {
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return CommentsSheet(
          postId: postId,
          onCommentAdded: () {
            if (mounted) {
              setState(() {
                _comments++;
              });
            }

            widget.onChanged?.call();
          },
        );
      },
    );
  }

  Widget _avatar() {
    final author = widget.post["author"];

    final image = author?["avatarUrl"] ?? author?["profileImage"];

    if (image != null && image.toString().isNotEmpty) {
      return CircleAvatar(
        radius: 23,
        backgroundImage: NetworkImage(image.toString()),
      );
    }

    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF7C5CFF), Color(0xFF3B82F6)],
        ),
      ),
      child: const Icon(Icons.person_rounded, color: Colors.white),
    );
  }

  Widget _action({
    required IconData icon,
    required VoidCallback? onTap,
    int count = 0,
    Color? activeColor,
    bool active = false,
  }) {
    final color = active
        ? activeColor ?? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.68);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: SizedBox(
          height: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Text(
                  _formatCount(count),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int value) {
    if (value < 1000) {
      return value.toString();
    }

    if (value < 1000000) {
      final v = value / 1000;

      return "${v.toStringAsFixed(v >= 100 ? 0 : 1)}K";
    }

    final v = value / 1000000;

    return "${v.toStringAsFixed(v >= 100 ? 0 : 1)}M";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final postTime = _formatTime(widget.post["createdAt"]);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withOpacity(0.25)),
          bottom: BorderSide(color: theme.dividerColor.withOpacity(0.55)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _displayName(),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: Color(0xFF5D8CFF),
                        ),
                        if (postTime.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Text(
                            "· $postTime",
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.45,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      "@${_username()}",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.48),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.more_horiz_rounded,
                color: theme.colorScheme.onSurface.withOpacity(0.55),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Text(
            _content(),
            style: TextStyle(
              fontSize: 17,
              height: 1.45,
              color: theme.colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 12),

          Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)),

          Row(
            children: [
              _action(
                icon: _liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                count: _likes,
                active: _liked,
                activeColor: const Color(0xFFFF3D6E),
                onTap: _liking ? null : _toggleLike,
              ),

              _action(
                icon: Icons.chat_bubble_outline_rounded,
                count: _comments,
                onTap: _openComments,
              ),

              _action(
                icon: _reposted
                    ? Icons.repeat_on_rounded
                    : Icons.repeat_rounded,
                count: _reposts,
                active: _reposted,
                activeColor: const Color(0xFF19C37D),
                onTap: _reposting ? null : _toggleRepost,
              ),

              _action(
                icon: Icons.ios_share_rounded,
                count: _shares,
                onTap: _sharing ? null : _sharePost,
              ),

              _action(
                icon: _saved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                active: _saved,
                activeColor: const Color(0xFF5D8CFF),
                onTap: _saving ? null : _toggleBookmark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
