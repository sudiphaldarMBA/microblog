import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/api_service.dart';
import '../home/home_video_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:visibility_detector/visibility_detector.dart';

class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({super.key});

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color get _background =>
      _dark ? const Color(0xFF050505) : const Color(0xFFF7F8FA);

  Color get _surface => _dark ? const Color(0xFF090A0C) : Colors.white;

  Color get _text => _dark ? Colors.white : const Color(0xFF111111);

  Color get _secondary =>
      _dark ? const Color(0xFF8D939C) : const Color(0xFF69707A);

  Color get _divider =>
      _dark ? const Color(0xFF202328) : const Color(0xFFE7E9ED);

  static const Color _blue = Color(0xFF1D9BF0);
  static const Color _red = Color(0xFFF91880);

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = true;

  List<dynamic> _savedPosts = [];

  final Set<String> _savedPostIds = {};

  final Set<String> _likedPosts = {};

  final Map<String, int> _likeCounts = {};

  final Set<String> _likingPosts = {};

  final Set<String> _viewedPostIds = {};

  final Set<String> _recordingPostIds = {};

  final Map<String, int> _viewCounts = {};

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
  }

  // ============================================================
  // LOAD SAVED POSTS
  // ============================================================

  Future<void> _loadSavedPosts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final result = await ApiService.getBookmarks();

      if (!mounted) return;

      if (result["success"] != true) {
        throw Exception(result["message"] ?? "Unable to load bookmarks");
      }

      dynamic rawPosts;

      final data = result["data"];

      if (data is Map) {
        rawPosts = data["posts"] ?? data["bookmarks"] ?? data["items"];
      }

      if (rawPosts is! List) {
        rawPosts = [];
      }

      final posts = List<dynamic>.from(rawPosts);

      final ids = <String>{};
      final likes = <String, int>{};
      final liked = <String>{};

      for (final raw in posts) {
        if (raw is! Map) continue;

        final post = Map<String, dynamic>.from(raw);

        final id = post["_id"]?.toString() ?? "";

        if (id.isEmpty) continue;

        ids.add(id);

        final likesCount = post["likesCount"];

        if (likesCount is num) {
          likes[id] = likesCount.toInt();
        } else if (post["likes"] is List) {
          likes[id] = (post["likes"] as List).length;
        } else {
          likes[id] = 0;
        }

        if (post["likedByMe"] == true) {
          liked.add(id);
        }
      }

      setState(() {
        _savedPosts = posts;

        _savedPostIds
          ..clear()
          ..addAll(ids);

        _likeCounts
          ..clear()
          ..addAll(likes);

        _likedPosts
          ..clear()
          ..addAll(liked);

        _isLoading = false;
      });
    } catch (error) {
      debugPrint("Load bookmarks error: $error");

      if (!mounted) return;

      setState(() {
        _savedPosts = [];
        _savedPostIds.clear();
        _likeCounts.clear();
        _likedPosts.clear();
        _isLoading = false;
      });

      _showMessage(error.toString().replaceFirst("Exception: ", ""));
    }
  }

  Future<void> _recordPostView(String postId) async {
    if (postId.isEmpty ||
        _viewedPostIds.contains(postId) ||
        _recordingPostIds.contains(postId)) {
      return;
    }

    _recordingPostIds.add(postId);

    try {
      final result = await ApiService.recordView(postId: postId);

      if (!mounted || result['success'] != true) return;

      final data = result['data'];
      final count = data is Map ? data['viewsCount'] : null;

      if (count is num) {
        setState(() {
          _viewCounts[postId] = count.toInt();

          for (final item in _savedPosts) {
            if (item is Map && item['_id']?.toString() == postId) {
              item['viewsCount'] = count.toInt();
              break;
            }
          }
        });
      }

      _viewedPostIds.add(postId);
    } catch (error) {
      debugPrint('Unable to record Bookmark view: $error');
    } finally {
      _recordingPostIds.remove(postId);
    }
  }

  // ============================================================
  // REMOVE BOOKMARK
  // ============================================================

  Future<void> _removeBookmark(String postId) async {
    try {
      final result = await ApiService.toggleBookmark(postId: postId);

      if (!mounted) return;

      if (result["success"] != true) {
        throw Exception(result["message"] ?? "Unable to remove bookmark");
      }

      setState(() {
        _savedPostIds.remove(postId);

        _savedPosts.removeWhere((post) => post["_id"]?.toString() == postId);

        _likeCounts.remove(postId);
        _likedPosts.remove(postId);
      });

      _showMessage("Removed from saved", durationMs: 900);
    } catch (error) {
      debugPrint("Remove Bookmark Error: $error");

      if (!mounted) return;

      _showMessage(error.toString().replaceFirst("Exception: ", ""));
    }
  }

  // ============================================================
  // LIKE / UNLIKE
  // ============================================================

  Future<void> _toggleLike(String postId) async {
    if (_likingPosts.contains(postId)) {
      return;
    }

    final bool wasLiked = _likedPosts.contains(postId);

    final int oldCount = _likeCounts[postId] ?? 0;

    setState(() {
      _likingPosts.add(postId);

      if (wasLiked) {
        _likedPosts.remove(postId);

        _likeCounts[postId] = oldCount > 0 ? oldCount - 1 : 0;
      } else {
        _likedPosts.add(postId);

        _likeCounts[postId] = oldCount + 1;
      }
    });

    try {
      final result = await ApiService.toggleLike(postId: postId);

      if (!mounted) return;

      if (result["success"] == true && result["data"] != null) {
        final data = result["data"];

        final bool liked = data["liked"] == true;

        final int serverCount = data["likesCount"] is num
            ? (data["likesCount"] as num).toInt()
            : (_likeCounts[postId] ?? oldCount);

        setState(() {
          if (liked) {
            _likedPosts.add(postId);
          } else {
            _likedPosts.remove(postId);
          }

          _likeCounts[postId] = serverCount;
        });
      } else {
        _restoreLikeState(postId, wasLiked, oldCount);

        _showMessage(result["message"] ?? "Unable to update like");
      }
    } catch (error) {
      debugPrint("Toggle Like Error: $error");

      if (!mounted) return;

      _restoreLikeState(postId, wasLiked, oldCount);

      _showMessage("Unable to update like");
    } finally {
      if (!mounted) return;

      setState(() {
        _likingPosts.remove(postId);
      });
    }
  }

  void _restoreLikeState(String postId, bool wasLiked, int oldCount) {
    if (!mounted) return;

    setState(() {
      if (wasLiked) {
        _likedPosts.add(postId);
      } else {
        _likedPosts.remove(postId);
      }

      _likeCounts[postId] = oldCount;
    });
  }

  // ============================================================
  // SHARE
  // ============================================================

  Future<void> _sharePost(dynamic post) async {
    final content = post["content"]?.toString() ?? "";

    final author = post["author"];

    String username = "user";

    if (author is Map && author["username"] != null) {
      username = author["username"].toString();
    }

    final shareText = "@$username on MicroBlog\n\n$content";

    try {
      await SharePlus.instance.share(
        ShareParams(text: shareText, subject: "Post from MicroBlog"),
      );
    } catch (error) {
      debugPrint("Share Saved Post Error: $error");

      if (!mounted) return;

      _showMessage("Unable to share post");
    }
  }

  // ============================================================
  // COMMENTS
  // ============================================================

  Future<void> _openComments(String postId) async {
    final TextEditingController commentController = TextEditingController();

    List<dynamic> comments = [];

    bool isSending = false;

    try {
      final result = await ApiService.getComments(postId: postId);

      if (result["success"] == true) {
        final raw = result["data"]?["comments"];

        if (raw is List) {
          comments = List<dynamic>.from(raw);
        }
      }
    } catch (error) {
      debugPrint("Get Comments Error: $error");
    }

    if (!mounted) {
      commentController.dispose();
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _surface,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> sendComment() async {
              final content = commentController.text.trim();

              if (content.isEmpty || isSending) {
                return;
              }

              setSheetState(() {
                isSending = true;
              });

              try {
                final result = await ApiService.createComment(
                  postId: postId,
                  content: content,
                );

                if (result["success"] != true) {
                  throw Exception(result["message"] ?? "Unable to add comment");
                }

                if (!sheetContext.mounted) {
                  return;
                }

                final newComment = result["data"]?["comment"];

                setSheetState(() {
                  if (newComment != null) {
                    comments.add(newComment);
                  }

                  commentController.clear();
                });
              } catch (error) {
                debugPrint("Create Comment Error: $error");

                if (!sheetContext.mounted) {
                  return;
                }

                ScaffoldMessenger.of(sheetContext).hideCurrentSnackBar();

                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      error.toString().replaceFirst("Exception: ", ""),
                    ),
                  ),
                );
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() {
                    isSending = false;
                  });
                }
              }
            }

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.78,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _secondary.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 10, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Comments",
                              style: TextStyle(
                                color: _text,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                            },
                            icon: Icon(Icons.close_rounded, color: _text),
                          ),
                        ],
                      ),
                    ),

                    Divider(height: 1, color: _divider),

                    Expanded(
                      child: comments.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 42,
                                    color: _secondary,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "No comments yet",
                                    style: TextStyle(
                                      color: _secondary,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.all(16),
                              itemCount: comments.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final raw = comments[index];

                                if (raw is! Map) {
                                  return const SizedBox.shrink();
                                }

                                final comment = Map<String, dynamic>.from(raw);

                                final rawAuthor = comment["author"];

                                final author = rawAuthor is Map
                                    ? Map<String, dynamic>.from(rawAuthor)
                                    : <String, dynamic>{};

                                final displayName = _displayName(author);

                                final username = _username(author);

                                final content =
                                    comment["content"]?.toString() ?? "";

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _avatar(
                                      image: author["avatar"],
                                      name: displayName,
                                      radius: 20,
                                    ),

                                    const SizedBox(width: 10),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  displayName,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: _text,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),

                                              if (username.isNotEmpty) ...[
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    "@$username",
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: _secondary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),

                                          const SizedBox(height: 5),

                                          Text(
                                            content,
                                            style: TextStyle(
                                              color: _text,
                                              fontSize: 15,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),

                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      decoration: BoxDecoration(
                        color: _surface,
                        border: Border(top: BorderSide(color: _divider)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commentController,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 300,
                              style: TextStyle(color: _text),
                              decoration: InputDecoration(
                                counterText: "",
                                hintText: "Write a comment...",
                                hintStyle: TextStyle(color: _secondary),
                                filled: true,
                                fillColor: _dark
                                    ? const Color(0xFF17191C)
                                    : const Color(0xFFF1F3F5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(22),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 11,
                                ),
                              ),
                              textInputAction: TextInputAction.newline,
                            ),
                          ),

                          const SizedBox(width: 8),

                          Material(
                            color: isSending ? _secondary : _blue,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: isSending ? null : sendComment,
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Center(
                                  child: isSending
                                      ? const SizedBox(
                                          width: 19,
                                          height: 19,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.arrow_upward_rounded,
                                          color: Colors.white,
                                          size: 21,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    commentController.dispose();
  }

  // ============================================================
  // MEDIA
  // ============================================================

  Widget _media(String url) {
    if (url.startsWith("data:image/")) {
      final bytes = ApiService.dataUrlToBytes(url);

      if (bytes != null) {
        return Image.memory(
          Uint8List.fromList(bytes),
          width: double.infinity,
          height: 260,
          fit: BoxFit.cover,
        );
      }
    }

    final cleanUrl = ApiService.normalizeImageUrl(url);

    if (cleanUrl == null) {
      return const SizedBox.shrink();
    }

    return Image.network(
      cleanUrl,
      width: double.infinity,
      height: 260,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) {
        return Container(
          height: 260,
          color: Colors.black12,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, size: 32),
          ),
        );
      },
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _avatar({
    required dynamic image,
    required String name,
    double radius = 20,
  }) {
    final value = image?.toString().trim() ?? "";

    Widget fallback() {
      final trimmed = name.trim();

      final first = trimmed.isNotEmpty
          ? trimmed.substring(0, 1).toUpperCase()
          : "?";

      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _dark ? const Color(0xFF25282D) : const Color(0xFFE4E7EB),
        ),
        alignment: Alignment.center,
        child: Text(
          first,
          style: TextStyle(
            color: _text,
            fontSize: radius * 0.75,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (value.isEmpty) {
      return fallback();
    }

    if (value.startsWith("data:image/")) {
      final bytes = ApiService.dataUrlToBytes(value);

      if (bytes != null) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: Colors.transparent,
          backgroundImage: MemoryImage(Uint8List.fromList(bytes)),
        );
      }

      return fallback();
    }

    final url = ApiService.normalizeImageUrl(value);

    if (url == null) {
      return fallback();
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.transparent,
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (_, _) {},
    );
  }

  // ============================================================
  // AUTHOR NAME HELPERS
  // ============================================================

  String _displayName(Map<String, dynamic> author) {
    final display = author["displayName"]?.toString().trim();

    if (display != null && display.isNotEmpty) {
      return display;
    }

    final username = author["username"]?.toString().trim();

    if (username != null && username.isNotEmpty) {
      return username;
    }

    return "User";
  }

  String _username(Map<String, dynamic> author) {
    return author["username"]?.toString().trim() ?? "";
  }

  // ============================================================
  // POST TIME
  // ============================================================

  String _timeAgo(dynamic value) {
    if (value == null) return "";

    try {
      final date = DateTime.parse(value.toString()).toLocal();

      final diff = DateTime.now().difference(date);

      if (diff.isNegative || diff.inSeconds < 60) {
        return "now";
      }

      if (diff.inMinutes < 60) {
        return "${diff.inMinutes}m";
      }

      if (diff.inHours < 24) {
        return "${diff.inHours}h";
      }

      if (diff.inDays < 7) {
        return "${diff.inDays}d";
      }

      if (diff.inDays < 30) {
        return "${diff.inDays ~/ 7}w";
      }

      if (diff.inDays < 365) {
        return "${diff.inDays ~/ 30}mo";
      }

      return "${diff.inDays ~/ 365}y";
    } catch (_) {
      return "";
    }
  }

  // ============================================================
  // POST MENU
  // ============================================================

  void _showPostMenu(String postId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.bookmark_remove_outlined, color: _text),
                title: Text(
                  "Remove from saved",
                  style: TextStyle(color: _text),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);

                  _removeBookmark(postId);
                },
              ),

              ListTile(
                leading: Icon(Icons.flag_outlined, color: _text),
                title: Text("Report post", style: TextStyle(color: _text)),
                onTap: () {
                  Navigator.pop(sheetContext);

                  _showMessage("Report feature coming soon");
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {int durationMs = 3000}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: durationMs),
          content: Text(message),
        ),
      );
  }

  // ============================================================
  // POST CARD
  // ============================================================

  Widget _buildPost(dynamic post) {
    final String postId = post["_id"]?.toString() ?? "";
    final int viewsCount =
        _viewCounts[postId] ??
        (post['viewsCount'] is num
            ? (post['viewsCount'] as num).toInt()
            : int.tryParse(post['viewsCount']?.toString() ?? '') ?? 0);

    final rawAuthor = post["author"];

    final author = rawAuthor is Map
        ? Map<String, dynamic>.from(rawAuthor)
        : <String, dynamic>{};

    final displayName = _displayName(author);

    final username = _username(author);

    final content = post["content"]?.toString() ?? "";

    // ----------------------------------------------------------
    // IMAGE
    // ----------------------------------------------------------

    final String media = post["image"]?.toString().trim() ?? "";

    // ----------------------------------------------------------
    // VIDEO
    // ----------------------------------------------------------

    final String videoMedia = post["video"]?.toString().trim() ?? "";

    // ----------------------------------------------------------
    // POLL
    // ----------------------------------------------------------

    final poll = post["poll"] is Map
        ? Map<String, dynamic>.from(post["poll"])
        : null;

    final bool isLiked = _likedPosts.contains(postId);

    final bool isLiking = _likingPosts.contains(postId);

    final int likeCount =
        _likeCounts[postId] ??
        (post["likesCount"] is num ? (post["likesCount"] as num).toInt() : 0);

    final int commentCount = post["commentsCount"] is num
        ? (post["commentsCount"] as num).toInt()
        : 0;

    final String postTime = _timeAgo(post["createdAt"]);

    return VisibilityDetector(
      key: Key('bookmark-view-$postId'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction >= 0.15) {
          _recordPostView(postId);
        }
      },
      child: Container(
        color: _surface,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _avatar(
                    image: author["avatar"],
                    name: displayName,
                    radius: 21,
                  ),

                  const SizedBox(width: 11),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ------------------------------------------------
                        // AUTHOR ROW
                        // ------------------------------------------------
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: _text,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),

                                  const SizedBox(height: 2),

                                  Row(
                                    children: [
                                      if (username.isNotEmpty)
                                        Flexible(
                                          child: Text(
                                            "@$username",
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: _secondary,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        ),

                                      if (username.isNotEmpty &&
                                          postTime.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          "•",
                                          style: TextStyle(
                                            color: _secondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],

                                      Text(
                                        postTime,
                                        style: TextStyle(
                                          color: _secondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: postId.isEmpty
                                    ? null
                                    : () => _showPostMenu(postId),
                                icon: Icon(
                                  Icons.more_horiz_rounded,
                                  color: _secondary,
                                  size: 21,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // ------------------------------------------------
                        // TEXT
                        // ------------------------------------------------
                        if (content.isNotEmpty)
                          Text(
                            content,
                            style: TextStyle(
                              color: _text,
                              fontSize: 16,
                              height: 1.42,
                            ),
                          ),

                        // ------------------------------------------------
                        // IMAGE
                        // ------------------------------------------------
                        if (media.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _media(media),
                            ),
                          ),

                        // ------------------------------------------------
                        // VIDEO
                        // ------------------------------------------------
                        if (videoMedia.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: HomeVideoPlayer(videoData: videoMedia),
                            ),
                          ),

                        // ------------------------------------------------
                        // POLL
                        // ------------------------------------------------
                        if (poll != null) _buildPollPreview(poll, postId),

                        const SizedBox(height: 13),

                        // ------------------------------------------------
                        // ACTION BAR
                        // ------------------------------------------------
                        Row(
                          children: [
                            Expanded(
                              child: _actionButton(
                                icon: isLiked
                                    ? CupertinoIcons.heart_fill
                                    : CupertinoIcons.heart,
                                count: likeCount,
                                color: isLiked ? _red : _secondary,
                                loading: isLiking,
                                onTap: postId.isEmpty
                                    ? null
                                    : () => _toggleLike(postId),
                              ),
                            ),

                            Expanded(
                              child: _actionButton(
                                icon: CupertinoIcons.bubble_left,
                                count: commentCount,
                                color: _secondary,
                                onTap: postId.isEmpty
                                    ? null
                                    : () => _openComments(postId),
                              ),
                            ),

                            Expanded(
                              child: _actionButton(
                                icon: CupertinoIcons.arrowshape_turn_up_right,
                                count: 0,
                                color: _secondary,
                                onTap: () => _sharePost(post),
                              ),
                            ),

                            Expanded(
                              child: _actionButton(
                                icon: CupertinoIcons.bookmark_fill,
                                count: 0,
                                color: _blue,
                                onTap: postId.isEmpty
                                    ? null
                                    : () => _removeBookmark(postId),
                                showCount: false,
                              ),
                            ),
                            Expanded(
                              child: _actionButton(
                                icon: CupertinoIcons.eye,
                                count: viewsCount,
                                color: _secondary,
                                onTap: null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: _divider),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // POLL PREVIEW
  // ============================================================

  Widget _buildPollPreview(Map<String, dynamic> poll, String postId) {
    final rawOptions = poll["options"];

    if (rawOptions is! List || rawOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    final options = rawOptions.map((option) => option.toString()).toList();

    final duration = poll["durationDays"];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: _divider),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.poll_outlined, color: _secondary, size: 19),
              const SizedBox(width: 7),
              Text(
                "Poll",
                style: TextStyle(
                  color: _text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          ...List.generate(options.length, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 7),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: _dark
                    ? const Color(0xFF17191C)
                    : const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                options[index],
                style: TextStyle(color: _text, fontSize: 14),
              ),
            );
          }),

          if (duration != null)
            Text(
              "Poll duration: $duration day${duration == 1 ? "" : "s"}",
              style: TextStyle(color: _secondary, fontSize: 12.5),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTION BUTTON
  // ============================================================

  Widget _actionButton({
    required IconData icon,
    required int count,
    required Color color,
    required VoidCallback? onTap,
    bool loading = false,
    bool showCount = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: color.withValues(alpha: 0.15),
        highlightColor: color.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              loading
                  ? SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  : Icon(icon, size: 21, color: color),

              if (showCount) ...[
                const SizedBox(width: 5),

                Text(
                  count.toString(),
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _blue.withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.bookmark_border_rounded,
                size: 40,
                color: _blue,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              "No saved posts",
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: _text,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Posts you save will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _secondary),
            ),
          ],
        ),
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
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _surface,
        titleSpacing: 20,

        title: Row(
          children: [
            Text(
              "Saved",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: _text,
              ),
            ),

            const SizedBox(width: 8),

            const Icon(CupertinoIcons.bookmark_fill, size: 20, color: _blue),
          ],
        ),

        actions: [
          IconButton(
            onPressed: _loadSavedPosts,
            icon: Icon(Icons.refresh_rounded, color: _text),
          ),

          const SizedBox(width: 4),
        ],
      ),

      body: SafeArea(
        child: RefreshIndicator(
          color: _blue,
          onRefresh: _loadSavedPosts,

          child: _isLoading
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(
                      height: 300,
                      child: Center(
                        child: CircularProgressIndicator(color: _blue),
                      ),
                    ),
                  ],
                )
              : _savedPosts.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.65,
                      child: _buildEmptyState(),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 30),
                  itemCount: _savedPosts.length,
                  itemBuilder: (context, index) {
                    return _buildPost(_savedPosts[index]);
                  },
                ),
        ),
      ),
    );
  }
}
