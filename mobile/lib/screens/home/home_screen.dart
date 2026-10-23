import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../../services/api_service.dart';

import '../bookmark/bookmark_screen.dart';
import '../notifications/notifications_screen.dart';
import '../posts/create_post_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import 'repost_modal_sheet.dart';
import 'home_video_player.dart';



class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  // Shared brand accent keeps active actions and poll selections consistent.
  static const Color _accent = Color(0xFFF91880);

  bool get _dark =>
      Theme.of(context).brightness == Brightness.dark;

  Color get _background =>
      _dark
          ? const Color(0xFF050505)
          : const Color(0xFFF7F8FA);

  Color get _surface =>
      _dark
          ? const Color(0xFF090A0C)
          : Colors.white;

  Color get _text =>
      _dark
          ? Colors.white
          : const Color(0xFF111318);

  Color get _muted =>
      _dark
          ? const Color(0xFF8D939C)
          : const Color(0xFF69707A);

  Color get _divider =>
      _dark
          ? const Color(0xFF202328)
          : const Color(0xFFE7E9ED);

  Color get _composer =>
      _dark
          ? const Color(0xFF17191C)
          : const Color(0xFFF1F3F5);

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final ScrollController _scrollController =
      ScrollController();

  // ============================================================
  // STATE
  // ============================================================

  Map<String, dynamic>? _currentUser;

  List<dynamic> _posts = [];

  bool _loadingPosts = true;
  bool _loadingUser = true;

  bool _showBottomNavigation = true;


  double _lastScrollOffset = 0;

  int _currentNavigationIndex = 0;

  // ============================================================
  // LIKE STATE
  // ============================================================

  final Set<String> _likedPosts = {};

  final Set<String> _likeLoading = {};

  final Map<String, int> _likeCounts = {};

  // ============================================================
  // BOOKMARK STATE
  // ============================================================

  final Set<String> _bookmarkedPosts = {};

  final Set<String> _bookmarkLoading = {};

  // ============================================================
  // COMMENT STATE
  // ============================================================

  final Map<String, int> _commentCounts = {};

  // ============================================================
  // REPOST STATE
  // ============================================================

  final Map<String, int> _repostCounts = {};

  final Set<String> _repostLoading = {};

  // ============================================================
  // POLL STATE
  // ============================================================

  final Map<String, int> _pollSelectedOptions = {};

  final Map<String, List<int>> _pollVoteCounts = {};

  final Set<String> _pollVoting = {};

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(
      _handleScroll,
    );

    _loadUser();
    _loadPosts();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _scrollController.removeListener(
      _handleScroll,
    );

    _scrollController.dispose();

    super.dispose();
  }

  // ============================================================
  // SCROLL / BOTTOM NAVIGATION
  //
  // Scroll UP   -> hide bottom navigation
  // Scroll DOWN -> show bottom navigation
  // ============================================================

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final offset =
        _scrollController.offset;

    final direction =
        _scrollController
            .position
            .userScrollDirection;

    if ((offset - _lastScrollOffset).abs() < 2) {
      return;
    }

    _lastScrollOffset = offset;

    bool shouldShow;

    if (offset <= 5) {
      shouldShow = true;
    } else if (direction ==
        ScrollDirection.reverse) {
      // Feed moving upward.
      shouldShow = false;
    } else if (direction ==
        ScrollDirection.forward) {
      // Feed moving downward.
      shouldShow = true;
    } else {
      return;
    }

    if (!mounted) {
      return;
    }

    if (shouldShow !=
        _showBottomNavigation) {
      setState(() {
        _showBottomNavigation =
            shouldShow;
      });
    }
  }

  // ============================================================
  // USER
  // ============================================================

  Future<void> _loadUser() async {
    try {
      final user =
          await ApiService.getCurrentUser();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUser = user;
        _loadingUser = false;
      });
    } catch (error) {
      debugPrint(
        'Home user error: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingUser = false;
      });
    }
  }

  // ============================================================
  // INTEGER HELPER
  // ============================================================

  int _asInt(
    dynamic value, [
    int fallback = 0,
  ]) {
    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ??
          fallback;
    }

    return fallback;
  }

  // ============================================================
  // LOAD POSTS
  // ============================================================

  Future<void> _loadPosts() async {
    try {
      final result =
          await ApiService.getPosts();

      if (!mounted) {
        return;
      }

      if (result['success'] != true) {
        throw Exception(
          result['message'] ??
              'Unable to load posts',
        );
      }

      final raw =
          result['data']?['posts'];

      if (raw is! List) {
        throw Exception(
          'Posts data not found',
        );
      }

      final likes =
          <String, int>{};

      final comments =
          <String, int>{};

      final reposts =
          <String, int>{};

      final liked =
          <String>{};

      final bookmarked =
          <String>{};

      final pollSelections =
          <String, int>{};

      final pollCounts =
          <String, List<int>>{};

      for (final item in raw) {
        if (item is! Map) {
          continue;
        }

        final post =
            Map<String, dynamic>.from(
          item,
        );

        final id =
            post['_id']
                    ?.toString() ??
                '';

        if (id.isEmpty) {
          continue;
        }

        // --------------------------------------------------------
        // LIKES
        // --------------------------------------------------------

        likes[id] = _asInt(
          post['likesCount'],
          post['likes'] is List
              ? (post['likes'] as List)
                  .length
              : 0,
        );

        // --------------------------------------------------------
        // COMMENTS
        // --------------------------------------------------------

        comments[id] = _asInt(
          post['commentsCount'],
          post['comments'] is List
              ? (post['comments'] as List)
                  .length
              : 0,
        );

        // --------------------------------------------------------
        // REPOSTS
        // --------------------------------------------------------

        reposts[id] = _asInt(
          post['repostsCount'],
        );

        // --------------------------------------------------------
        // USER LIKE STATE
        // --------------------------------------------------------

        if (post['likedByMe'] == true ||
            post['isLiked'] == true) {
          liked.add(id);
        }

        // --------------------------------------------------------
        // USER BOOKMARK STATE
        // --------------------------------------------------------

        if (post['bookmarkedByMe'] == true ||
            post['isBookmarked'] == true ||
            post['savedByMe'] == true) {
          bookmarked.add(id);
        }

        // --------------------------------------------------------
        // POLL
        // --------------------------------------------------------

        final poll =
            post['poll'];

        if (poll is Map) {
          final pollMap =
              Map<String, dynamic>.from(
            poll,
          );

          final selected =
              pollMap['selectedOption'] ??
                  pollMap['selectedByMe'] ??
                  pollMap['userVote'];

          if (selected is num) {
            pollSelections[id] =
                selected.toInt();
          }

          final rawCounts =
              pollMap['voteCounts'] ??
                  pollMap['votes'] ??
                  pollMap['counts'];

          if (rawCounts is List) {
            pollCounts[id] =
                rawCounts
                    .map(
                      (value) =>
                          _asInt(value),
                    )
                    .toList();
          }
        }

        // --------------------------------------------------------
        // POLL DATA MAY ALSO EXIST DIRECTLY ON POST
        // --------------------------------------------------------

        final directSelected =
            post['selectedPollOption'] ??
                post['pollSelectedOption'];

        if (directSelected is num) {
          pollSelections[id] =
              directSelected.toInt();
        }

        final directCounts =
            post['pollVoteCounts'];

        if (directCounts is List) {
          pollCounts[id] =
              directCounts
                  .map(
                    (value) =>
                        _asInt(value),
                  )
                  .toList();
        }
      }

      setState(() {
        _posts =
            List<dynamic>.from(raw);

        _likeCounts
          ..clear()
          ..addAll(likes);

        _commentCounts
          ..clear()
          ..addAll(comments);

        _repostCounts
          ..clear()
          ..addAll(reposts);

        _likedPosts
          ..clear()
          ..addAll(liked);

        _bookmarkedPosts
          ..clear()
          ..addAll(bookmarked);

        _pollSelectedOptions
          ..clear()
          ..addAll(pollSelections);

        _pollVoteCounts
          ..clear()
          ..addAll(pollCounts);

        _loadingPosts = false;
      });
    } catch (error) {
      debugPrint(
        'Load posts error: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingPosts = false;
      });

      _showMessage(
        'Unable to load posts',
      );
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    await Future.wait([
      _loadUser(),
      _loadPosts(),
    ]);
  }

  // ============================================================
  // LIKE
  // ============================================================

  Future<void> _toggleLike(
    String postId,
  ) async {
    if (postId.isEmpty ||
        _likeLoading.contains(postId)) {
      return;
    }

    final oldLiked =
        _likedPosts.contains(postId);

    final oldCount =
        _likeCounts[postId] ?? 0;

    // Optimistic UI.
    if (mounted) {
      setState(() {
        _likeLoading.add(postId);

        if (oldLiked) {
          _likedPosts.remove(postId);

          _likeCounts[postId] =
              oldCount > 0
                  ? oldCount - 1
                  : 0;
        } else {
          _likedPosts.add(postId);

          _likeCounts[postId] =
              oldCount + 1;
        }
      });
    }

    try {
      final result =
          await ApiService.toggleLike(
        postId: postId,
      );

      if (result['success'] != true) {
        throw Exception(
          result['message'] ??
              'Unable to update like',
        );
      }

      final data =
          result['data'];

      if (data is Map &&
          mounted) {
        final serverLiked =
            data['liked'] ??
                data['isLiked'];

        final serverCount =
            data['likesCount'] ??
                data['likeCount'];

        setState(() {
          if (serverLiked is bool) {
            if (serverLiked) {
              _likedPosts.add(postId);
            } else {
              _likedPosts.remove(
                postId,
              );
            }
          }

          if (serverCount is num) {
            _likeCounts[postId] =
                serverCount.toInt();
          }
        });
      }
    } catch (error) {
      debugPrint(
        'Like error: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        if (oldLiked) {
          _likedPosts.add(postId);
        } else {
          _likedPosts.remove(postId);
        }

        _likeCounts[postId] =
            oldCount;
      });

      _showMessage(
        _friendlyError(
          error,
          'Unable to update like',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _likeLoading.remove(
            postId,
          );
        });
      }
    }
  }

  // ============================================================
  // BOOKMARK
  // ============================================================

  Future<void> _toggleBookmark(
    String postId,
  ) async {
    if (postId.isEmpty ||
        _bookmarkLoading.contains(postId)) {
      return;
    }

    final oldSaved =
        _bookmarkedPosts.contains(
      postId,
    );

    if (mounted) {
      setState(() {
        _bookmarkLoading.add(
          postId,
        );

        if (oldSaved) {
          _bookmarkedPosts.remove(
            postId,
          );
        } else {
          _bookmarkedPosts.add(
            postId,
          );
        }
      });
    }

    try {
      final result =
          await ApiService.toggleBookmark(
        postId: postId,
      );

      if (result['success'] != true) {
        throw Exception(
          result['message'] ??
              'Unable to update bookmark',
        );
      }

      final data =
          result['data'];

      if (data is Map &&
          mounted) {
        final saved =
            data['bookmarked'] ??
                data['saved'] ??
                data['isBookmarked'] ??
                data['savedByMe'];

        if (saved is bool) {
          setState(() {
            if (saved) {
              _bookmarkedPosts.add(
                postId,
              );
            } else {
              _bookmarkedPosts.remove(
                postId,
              );
            }
          });
        }
      }

      if (mounted) {
        _showMessage(
          oldSaved
              ? 'Removed from bookmarks'
              : 'Saved to bookmarks',
        );
      }
    } catch (error) {
      debugPrint(
        'Bookmark error: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        if (oldSaved) {
          _bookmarkedPosts.add(
            postId,
          );
        } else {
          _bookmarkedPosts.remove(
            postId,
          );
        }
      });

      _showMessage(
        _friendlyError(
          error,
          'Unable to update bookmark',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _bookmarkLoading.remove(
            postId,
          );
        });
      }
    }
  }

  // ============================================================
  // POLL
  // ============================================================

  Future<void> _votePoll(
    String postId,
    int optionIndex,
  ) async {
    if (postId.isEmpty ||
        _pollVoting.contains(postId)) {
      return;
    }

    final previousSelection =
        _pollSelectedOptions[postId];

    if (mounted) {
      setState(() {
        _pollVoting.add(postId);
      });
    }

    try {
      final result =
          await ApiService.votePoll(
        postId: postId,
        optionIndex: optionIndex,
      );

      if (result['success'] != true) {
        throw Exception(
          result['message'] ??
              'Unable to vote in poll',
        );
      }

      final data =
          result['data'];

      if (data is Map &&
          mounted) {
        final selected =
            data['selectedOption'] ??
                data['selected'] ??
                data['optionIndex'] ??
                data['userVote'];

        final counts =
            data['voteCounts'] ??
                data['votes'] ??
                data['counts'];

        setState(() {
          if (selected is num) {
            _pollSelectedOptions[
                    postId] =
                selected.toInt();
          } else {
            // Server did not return the selected
            // option, so use the option we clicked.
            _pollSelectedOptions[
                    postId] =
                optionIndex;
          }

          if (counts is List) {
            _pollVoteCounts[postId] =
                counts
                    .map(
                      (value) =>
                          _asInt(value),
                    )
                    .toList();
          } else {
            // Some APIs return only the updated
            // option. Update our local count.
            final existing =
                List<int>.from(
              _pollVoteCounts[
                      postId] ??
                  <int>[],
            );

            while (existing.length <=
                optionIndex) {
              existing.add(0);
            }

            if (previousSelection ==
                null) {
              existing[
                  optionIndex]++;

              _pollVoteCounts[
                      postId] =
                  existing;
            }
          }
        });
      }
    } catch (error) {
      debugPrint(
        'Poll vote error: $error',
      );

      if (mounted) {
        _showMessage(
          _friendlyError(
            error,
            'Unable to vote in poll',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _pollVoting.remove(
            postId,
          );
        });
      }
    }
  }

  // ============================================================
  // COMMENTS
  //
  // This implementation intentionally waits until the sheet
  // closes before updating the HomeScreen state.
  //
  // That avoids the Navigator/InheritedWidget lifecycle problem
  // behind:
  //
  // "_dependents.isEmpty': is not true"
  // ============================================================

  Future<void> _openComments(
    String postId,
  ) async {
    if (postId.isEmpty) {
      return;
    }

    List<dynamic> comments = [];

    try {
      final result =
          await ApiService.getComments(
        postId: postId,
      );

      if (result['success'] == true) {
        final raw =
            result['data']?['comments'];

        if (raw is List) {
          comments =
              List<dynamic>.from(raw);
        }
      }
    } catch (error) {
      debugPrint(
        'Get comments error: $error',
      );
    }

    if (!mounted) {
      return;
    }

    final result =
        await showModalBottomSheet<
            int?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _surface,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (
        sheetContext,
      ) {
        return _CommentsSheet(
          comments: comments,
          postId: postId,
          surfaceColor: _surface,
          backgroundColor: _background,
          textColor: _text,
          mutedColor: _muted,
          dividerColor: _divider,
          composerColor: _composer,
        );
      },
    );

    // IMPORTANT:
    // Only update HomeScreen after the modal has completely
    // disappeared from the widget tree.
    if (!mounted) {
      return;
    }

    if (result != null) {
      setState(() {
        _commentCounts[postId] =
            result;
      });
    }
  }

  // ============================================================
  // SHARE
  // ============================================================

  Future<void> _sharePost(
    Map<String, dynamic> post,
  ) async {
    final content =
        post['content']
                ?.toString()
                .trim() ??
            '';

    final authorRaw =
        post['author'];

    final author =
        authorRaw is Map
            ? Map<String, dynamic>.from(
                authorRaw,
              )
            : <String, dynamic>{};

    final name =
        _displayName(author);

    final username =
        _username(author);

    final postId =
        post['_id']?.toString();

    if (content.isEmpty &&
        (postId == null ||
            postId.isEmpty)) {
      return;
    }

    // ----------------------------------------------------------
    // RESOLVE MEDIA (repost-aware, same rule _postCard uses)
    // ----------------------------------------------------------

    final repostOfRaw = post['repostOf'];

    final repostOf =
        (repostOfRaw is Map && repostOfRaw.isNotEmpty)
            ? Map<String, dynamic>.from(repostOfRaw)
            : null;

    final isPlainRepost =
        repostOf != null && content.isEmpty;

    final dynamic rawImageMedia = isPlainRepost
        ? (repostOf['image'] ??
            repostOf['imageUrl'] ??
            repostOf['mediaUrl'])
        : (post['image'] ??
            post['imageUrl'] ??
            post['mediaUrl']);

    final dynamic rawVideoMedia = isPlainRepost
        ? (repostOf['video'] ?? repostOf['videoUrl'])
        : (post['video'] ?? post['videoUrl']);

    File? mediaFile;

    try {
      if (rawVideoMedia != null &&
          rawVideoMedia.toString().trim().isNotEmpty) {
        mediaFile = await _prepareShareMediaFile(
          rawVideoMedia,
          isVideo: true,
        );
      } else if (rawImageMedia != null &&
          rawImageMedia.toString().trim().isNotEmpty) {
        mediaFile = await _prepareShareMediaFile(
          rawImageMedia,
          isVideo: false,
        );
      }
    } catch (error) {
      debugPrint(
        'Prepare share media error: $error',
      );
      // Fall back to a text-only share below.
    }

    final buffer =
        StringBuffer();

    buffer.writeln(
      '$name${username.isNotEmpty ? ' @$username' : ''}',
    );

    if (content.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(content);
    }

    buffer.writeln();
    buffer.writeln(
      'Shared from MicroBlog',
    );

    if (postId != null &&
        postId.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(
        'Post ID: $postId',
      );
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: buffer.toString().trim(),
          subject: 'Post from MicroBlog',
          files: mediaFile != null ? [XFile(mediaFile.path)] : null,
        ),
      );
    } catch (error) {
      debugPrint(
        'Share error: $error',
      );

      if (mounted) {
        _showMessage(
          'Unable to share post',
        );
      }
    } finally {
      // The share sheet has finished using the temporary attachment.
      if (mediaFile != null) {
        try {
          if (await mediaFile.exists()) {
            await mediaFile.delete();
          }
          final parent = mediaFile.parent;
          if (await parent.exists()) {
            await parent.delete();
          }
        } catch (cleanupError) {
          debugPrint('Share temp-file cleanup error: $cleanupError');
        }
      }
    }
  }

  // ============================================================
  // PREPARE SHARE MEDIA FILE
  //
  // share_plus needs a real file on disk to attach a photo/video
  // to the share sheet — a bare URL or base64 string isn't
  // enough. This resolves either a data: URL or a network URL
  // down to bytes, then writes them to a temp file so they can
  // be attached via ShareParams.files.
  // ============================================================

  Future<File?> _prepareShareMediaFile(
    dynamic mediaValue, {
    required bool isVideo,
  }) async {
    final text = mediaValue?.toString().trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    List<int>? bytes;
    String extension = isVideo ? 'mp4' : 'jpg';

    if (text.startsWith('data:')) {
      final match = RegExp(
        r'^data:(image|video)/([\w.+-]+);base64,',
      ).firstMatch(text);

      final subtype = match?.group(2)?.toLowerCase();

      if (subtype != null && subtype.isNotEmpty) {
        extension = subtype == 'jpeg' ? 'jpg' : subtype;
      }

      bytes = ApiService.dataUrlToBytes(text);
    } else {
      final url = ApiService.normalizeImageUrl(text);

      if (url == null) {
        return null;
      }

      final uriPath = Uri.parse(url).path.toLowerCase();

      const knownExtensions = [
        'mp4',
        'mov',
        'webm',
        'm4v',
        'png',
        'gif',
        'webp',
        'jpg',
        'jpeg',
      ];

      for (final candidate in knownExtensions) {
        if (uriPath.endsWith('.$candidate')) {
          extension = candidate == 'jpeg' ? 'jpg' : candidate;
          break;
        }
      }

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        bytes = response.bodyBytes;
      }
    }

    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    final tempDir = await Directory.systemTemp.createTemp(
      'microblog_share',
    );

    final file = File(
      '${tempDir.path}/share_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );

    await file.writeAsBytes(bytes);

    return file;
  }

  // ============================================================
  // REPOST WITH CAPTION
  // ============================================================

  Future<void> _repost(
    Map<String, dynamic> post,
  ) async {
    final postId = post['_id']?.toString() ?? '';

    if (postId.isEmpty || _repostLoading.contains(postId)) {
      return;
    }

    final Color localSurface = _surface;
    final Color localText = _text;
    final Color localMuted = _muted;
    final Color localComposer = _composer;

    // 1. Invoke the sheet modal using the separate, imported widget definition
    final caption = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: localSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (sheetContext) {
        return RepostModalSheet(
          surfaceColor: localSurface,
          textColor: localText,
          mutedColor: localMuted,
          composerColor: localComposer,
        );
      },
    );

    // Stop execution flow cleanly if the modal is dismissed/cancelled
    if (caption == null) {
      return;
    }

    if (!mounted) return;

    // 2. Safe layout execution: Push operations out to the subsequent post-frame tick
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      setState(() {
        _repostLoading.add(postId);
      });

      try {
        final result = await ApiService.repost(
          postId: postId,
          caption: caption,
        );

        if (!mounted) return;

        if (result['success'] != true) {
          throw Exception(
            result['message'] ?? 'Unable to repost',
          );
        }

        final count = result['data']?['repostsCount'];

        setState(() {
          _repostCounts[postId] = count is num
              ? count.toInt()
              : (_repostCounts[postId] ?? 0) + 1;
        });

        _showMessage(
          caption.isEmpty ? 'Reposted successfully' : 'Reposted with caption',
        );
      } catch (error) {
        debugPrint('Repost error: $error');

        if (mounted) {
          _showMessage(
            _friendlyError(
              error,
              'Unable to repost',
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _repostLoading.remove(postId);
          });
        }
      }
    });
  }

// ============================================================
// POST CARD (PERMANENT REPOST MEDIA SYNCHRONIZATION FIX)
// ============================================================

Widget _postCard(Map<String, dynamic> post) {
  final id = post['_id']?.toString() ?? '';

  // ----------------------------------------------------------
  // REPOST DETECTION
  // ----------------------------------------------------------

  final repostAuthorRaw = post['author'];

  final repostAuthor = repostAuthorRaw is Map
      ? Map<String, dynamic>.from(repostAuthorRaw)
      : <String, dynamic>{};

  final repostOfRaw = post['repostOf'];

  final repostOf = (repostOfRaw is Map && repostOfRaw.isNotEmpty)
      ? Map<String, dynamic>.from(repostOfRaw)
      : null;

  final repostCaption = post['content']?.toString().trim() ?? '';

  final isRepost = repostOf != null;

  final isQuoteRepost = isRepost && repostCaption.isNotEmpty;

  final isPlainRepost = isRepost && !isQuoteRepost;

  final Map<String, dynamic> author;
  final String content;

  final dynamic rawImageMedia;
  final dynamic rawVideoMedia;

  if (isPlainRepost) {
    final originalAuthorRaw = repostOf['author'];

    author = originalAuthorRaw is Map
        ? Map<String, dynamic>.from(originalAuthorRaw)
        : <String, dynamic>{};

    content = repostOf['content']?.toString() ?? '';

    // Pull media from original post.
    rawImageMedia = repostOf['image'] ??
        repostOf['imageUrl'] ??
        repostOf['mediaUrl'];

    rawVideoMedia = repostOf['video'] ?? repostOf['videoUrl'];
  } else {
    author = repostAuthor;

    content = post['content']?.toString() ?? '';

    // Pull media directly from post.
    rawImageMedia =
        post['image'] ?? post['imageUrl'] ?? post['mediaUrl'];

    rawVideoMedia = post['video'] ?? post['videoUrl'];
  }

  final name = _displayName(author);

  final username = _username(author);

  // ----------------------------------------------------------
  // AVATAR RE-MAPPING
  // ----------------------------------------------------------

  final String currentUserId =
      _currentUser?['_id']?.toString() ??
      _currentUser?['id']?.toString() ??
      '';

  final String postAuthorId =
      author['_id']?.toString() ??
      author['id']?.toString() ??
      '';

  dynamic displayedAvatar = author['avatar'];

  if (currentUserId.isNotEmpty && postAuthorId == currentUserId) {
    displayedAvatar = _currentUser?['avatar'];
  }

  final liked = _likedPosts.contains(id);

  final saved = _bookmarkedPosts.contains(id);

  final String media = rawImageMedia?.toString().trim() ?? '';

  final String videoMedia = rawVideoMedia?.toString().trim() ?? '';

  final location = post['location']?.toString().trim() ?? '';

  final poll = post['poll'] is Map
      ? Map<String, dynamic>.from(post['poll'])
      : null;

  final likes = _likeCounts[id] ?? 0;

  final comments = _commentCounts[id] ?? 0;

  final reposts =
      _repostCounts[id] ?? _asInt(post['repostsCount']);

  return Container(
    color: _surface,
    child: Column(
      children: [
        // ------------------------------------------------------
        // REPOST LABEL
        // ------------------------------------------------------

        if (isRepost)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              10,
              16,
              0,
            ),
            child: Row(
              children: [
                const SizedBox(width: 34),

                Icon(
                  CupertinoIcons.arrow_2_squarepath,
                  size: 15,
                  color: _muted,
                ),

                const SizedBox(width: 6),

                Flexible(
                  child: Text(
                    '${_displayName(repostAuthor)} reposted',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ------------------------------------------------------
        // POST BODY
        // ------------------------------------------------------

        Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            14,
            16,
            10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(
                displayedAvatar,
                name,
                21,
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
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              // Full name
                              Text(
                                name,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _text,
                                  fontSize: 15.5,
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),

                              const SizedBox(height: 2),

                              // Username + time
                              Row(
                                children: [
                                  if (username.isNotEmpty)
                                    Flexible(
                                      child: Text(
                                        '@$username',
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _muted,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),

                                  if (username.isNotEmpty) ...[
                                    const SizedBox(width: 6),

                                    Text(
                                      '•',
                                      style: TextStyle(
                                        color: _muted,
                                      ),
                                    ),

                                    const SizedBox(width: 6),
                                  ],

                                  Text(
                                    _timeAgo(
                                      post['createdAt'],
                                    ),
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Options
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          onPressed: () {
                            _showPostOptions(post);
                          },
                          icon: Icon(
                            Icons.more_horiz_rounded,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),

                    // ------------------------------------------------
                    // TEXT CONTENT
                    // ------------------------------------------------

                    if (content.trim().isNotEmpty) ...[
                      const SizedBox(height: 7),

                      Text(
                        content,
                        style: TextStyle(
                          color: _text,
                          fontSize: 16,
                          height: 1.42,
                        ),
                      ),
                    ],

                    // ------------------------------------------------
                    // QUOTE REPOST EMBED
                    // ------------------------------------------------

                    if (isQuoteRepost)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 10,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _divider,
                            ),
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _avatar(
                                    repostOf['author']
                                            is Map
                                        ? repostOf['author']
                                        : <String, dynamic>{},
                                    _displayName(
                                      repostOf['author']
                                              is Map
                                          ? Map<String,
                                              dynamic>.from(
                                              repostOf[
                                                  'author'],
                                            )
                                          : <String,
                                              dynamic>{},
                                    ),
                                    13,
                                  ),

                                  const SizedBox(width: 7),

                                  Flexible(
                                    child: Text(
                                      _displayName(
                                        repostOf['author']
                                                is Map
                                            ? Map<String,
                                                dynamic>.from(
                                                repostOf[
                                                    'author'],
                                              )
                                            : <String,
                                                dynamic>{},
                                      ),
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _text,
                                        fontSize: 13.5,
                                        fontWeight:
                                            FontWeight.w700,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 4),

                                  Text(
                                    _timeAgo(
                                      repostOf[
                                          'createdAt'],
                                    ),
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),

                              if (repostOf['content']
                                      ?.toString()
                                      .trim()
                                      .isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 6),

                                Text(
                                  repostOf['content']
                                      .toString(),
                                  maxLines: 4,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _text,
                                    fontSize: 14.5,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                    // ------------------------------------------------
                    // LOCATION
                    // ------------------------------------------------

                    if (location.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: _muted,
                            ),

                            const SizedBox(width: 4),

                            Flexible(
                              child: Text(
                                location,
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ------------------------------------------------
                    // IMAGE MEDIA
                    // ------------------------------------------------

                    if (media.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 10),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(16),
                          child: _media(media),
                        ),
                      ),

                    // ------------------------------------------------
                    // VIDEO MEDIA
                    // ------------------------------------------------

                    if (videoMedia.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 10),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(16),
                          child: HomeVideoPlayer(
                            videoData: videoMedia,
                          ),
                        ),
                      ),

                    // ------------------------------------------------
                    // POLL
                    // ------------------------------------------------

                    if (poll != null)
                      _pollPreview(
                        poll,
                        id,
                      ),

                    const SizedBox(height: 8),

                    // ------------------------------------------------
                    // ACTION BAR
                    // ------------------------------------------------

                    Row(
                      children: [
                        // Like — outline heart, filled pink when active.
                        _actionButton(
                          icon: liked
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          count: likes,
                          color: liked ? _accent : _muted,
                          active: liked,
                          loading: _likeLoading.contains(id),
                          label: liked ? 'Unlike' : 'Like',
                          onTap: () => _toggleLike(id),
                        ),

                        // Comment — simple outline bubble.
                        _actionButton(
                          icon: CupertinoIcons.bubble_left,
                          count: comments,
                          color: _muted,
                          label: 'Comments',
                          onTap: () => _openComments(id),
                        ),

                        // Repost — intentionally preserve the existing glyph and behavior.
                        _actionButton(
                          icon: CupertinoIcons.arrow_2_squarepath,
                          count: reposts,
                          color: _muted,
                          loading: _repostLoading.contains(id),
                          label: 'Repost',
                          onTap: () => _repost(post),
                        ),

                        // Share — minimal outline arrow in the same Cupertino family.
                        _actionButton(
                          icon: CupertinoIcons.arrowshape_turn_up_right,
                          count: 0,
                          color: _muted,
                          showCount: false,
                          label: 'Share',
                          onTap: () => _sharePost(post),
                        ),

                        // Bookmark — intentionally preserve the existing glyph and behavior.
                        _actionButton(
                          icon: saved
                              ? CupertinoIcons.bookmark_fill
                              : CupertinoIcons.bookmark,
                          count: 0,
                          color: saved ? _accent : _muted,
                          active: saved,
                          loading: _bookmarkLoading.contains(id),
                          showCount: false,
                          label: saved ? 'Remove bookmark' : 'Save bookmark',
                          onTap: () => _toggleBookmark(id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Divider(
          height: 1,
          color: _divider,
        ),
      ],
    ),
  );
}


    // ============================================================
  // POST ACTION BUTTON
  // Each action receives an equal-width slot. The icon and count areas
  // have fixed dimensions so toggles and count changes don't move siblings.
  // ============================================================

  Widget _actionButton({
    required IconData icon,
    required int count,
    required Color color,
    required String label,
    required VoidCallback? onTap,
    bool active = false,
    bool loading = false,
    bool showCount = true,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: 36,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 120),
                      child: loading
                          ? SizedBox(
                              key: const ValueKey<String>('action-loading'),
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: color,
                              ),
                            )
                          : Icon(
                              icon,
                              key: ValueKey<IconData>(icon),
                              size: 21,
                              color: color,
                            ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  SizedBox(
                    width: 22,
                    height: 18,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: showCount && count > 0
                          ? FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _formatCount(count),
                                maxLines: 1,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10.5,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MEDIA
  // ============================================================

  Widget _media(
    dynamic value,
  ) {
    final text =
        value.toString().trim();

    final bytes =
        ApiService.dataUrlToBytes(
      text,
    );

    if (bytes != null) {
      return Image.memory(
        Uint8List.fromList(
          bytes,
        ),
        width:
            double.infinity,
        height: 280,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) {
          return const SizedBox
              .shrink();
        },
      );
    }

    final url =
        ApiService.normalizeImageUrl(
      text,
    );

    if (url == null) {
      return const SizedBox.shrink();
    }

    return Image.network(
      url,
      width:
          double.infinity,
      height: 280,
      fit: BoxFit.cover,
      errorBuilder:
          (_, __, ___) {
        return const SizedBox
            .shrink();
      },
    );
  }

  // ============================================================
  // POLL UI
  // ============================================================

  Widget _pollPreview(
    Map<String, dynamic> poll,
    String postId,
  ) {
    final options =
        poll['options'] is List
            ? List<dynamic>.from(
                poll['options'],
              )
            : <dynamic>[];

    if (options.length < 2) {
      return const SizedBox.shrink();
    }

    final selected =
        _pollSelectedOptions[
            postId];

    final counts =
        _pollVoteCounts[postId];

    final totalVotes =
        counts == null
            ? 0
            : counts.fold<int>(
                0,
                (
                  sum,
                  value,
                ) =>
                    sum + value,
              );

    final voting =
        _pollVoting.contains(
      postId,
    );

    final hasVoted =
        selected != null;

    return Container(
      margin:
          const EdgeInsets.only(
        top: 10,
      ),
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color: _composer,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: Column(
        children: [
          for (
            int index = 0;
            index < options.length &&
                index < 4;
            index++
          )
            Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 8,
              ),
              child: InkWell(
                onTap:
                    voting
                        ? null
                        : hasVoted
                            ? null
                            : () {
                                _votePoll(
                                  postId,
                                  index,
                                );
                              },
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
                child: Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        selected ==
                                index
                            ? _accent
                                .withOpacity(
                                .10,
                              )
                            : Colors
                                .transparent,
                    border:
                        Border.all(
                      color:
                          selected ==
                                  index
                              ? _accent
                              : _divider,
                      width:
                          selected ==
                                  index
                              ? 1.4
                              : 1,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      13,
                    ),
                  ),
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child:
                                Text(
                              options[
                                      index]
                                  .toString(),
                              style:
                                  TextStyle(
                                color:
                                    _text,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                          ),
                          if (selected ==
                              index)
                            const Icon(
                              Icons
                                  .check_circle_rounded,
                              color:
                                  _accent,
                              size:
                                  20,
                            ),
                        ],
                      ),

                      if (counts !=
                              null &&
                          index <
                              counts
                                  .length) ...[
                        const SizedBox(
                          height: 8,
                        ),
                        ClipRRect(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                          child:
                              LinearProgressIndicator(
                            minHeight:
                                5,
                            value:
                                totalVotes ==
                                        0
                                    ? 0
                                    : counts[
                                            index] /
                                        totalVotes,
                            backgroundColor:
                                _divider,
                            valueColor:
                                AlwaysStoppedAnimation<
                                    Color>(
                              _accent,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          totalVotes ==
                                  0
                              ? '0 votes'
                              : '${counts[index]} votes',
                          style:
                              TextStyle(
                            color:
                                _muted,
                            fontSize:
                                12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          if (voting)
            const Padding(
              padding:
                  EdgeInsets.only(
                top: 3,
              ),
              child:
                  LinearProgressIndicator(
                minHeight: 2,
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // MODERN X-STYLE FLAT BOTTOM NAVIGATION
  // Completely eliminates old pink layers and misaligned elements
  // ============================================================
  Widget _bottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border(
          top: BorderSide(
            color: _divider,
            width: 0.5, // Thin, sharp line indicator matching X app layout
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56, // Clean, industry-standard modern layout elevation tracking
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bottomNavItem(
                icon: CupertinoIcons.house,
                activeIcon: CupertinoIcons.house_fill,
                index: 0,
              ),
              _bottomNavItem(
                icon: CupertinoIcons.search,
                activeIcon: CupertinoIcons.search,
                index: 1,
              ),
              _buildCreateNavButton(),
              _bottomNavItem(
                icon: CupertinoIcons.bookmark,
                activeIcon: CupertinoIcons.bookmark_fill,
                index: 3,
              ),
              _bottomNavItem(
                icon: CupertinoIcons.settings,
                activeIcon: CupertinoIcons.settings_solid,
                index: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NAV ITEM (PERFECT GRAPHIC AND ALIGNMENT ACCENT INDEX)
  // ============================================================
  Widget _bottomNavItem({
    required IconData icon,
    required IconData activeIcon,
    required int index,
  }) {
    final bool active = _currentNavigationIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onBottomNavigationTap(index),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Icon(
            active ? activeIcon : icon,
            size: 24, // Optimized pixel balance grid shape
            color: active ? _text : _muted, // Seamless transition without arbitrary color codes
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FLAT LOGIC FAB ACCENT BUTTON (+)
  // ============================================================
  Widget _buildCreateNavButton() {
    return Expanded(
      child: Center(
        child: InkWell(
          onTap: () async => await _openCreatePost(),
          borderRadius: BorderRadius.circular(99),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _text, // Uses pure black in light mode, pure white in dark mode
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.add,
              size: 22,
              color: _surface, // Inverts directly onto background space seamlessly
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM NAV ACTION
  // ============================================================

  Future<void>
      _onBottomNavigationTap(
    int index,
  ) async {
    if (index == 0) {
      if (!mounted) {
        return;
      }

      setState(() {
        _currentNavigationIndex =
            0;
      });

      if (_scrollController
          .hasClients) {
        _scrollController.animateTo(
          0,
          duration:
              const Duration(
            milliseconds: 250,
          ),
          curve:
              Curves.easeOutCubic,
        );
      }

      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _currentNavigationIndex =
          index;
    });

    switch (index) {
      case 1:
        await Navigator.of(
          context,
        ).push(
          MaterialPageRoute(
            builder: (_) =>
                const SearchScreen(),
          ),
        );
        break;

      case 3:
        await Navigator.of(
          context,
        ).push(
          MaterialPageRoute(
            builder: (_) =>
                const BookmarkScreen(),
          ),
        );

        // Refresh posts when returning
        // so bookmark state is synchronized.
        if (mounted) {
          await _loadPosts();
        }
        break;

      case 4:
        await Navigator.of(
          context,
        ).push(
          MaterialPageRoute(
            builder: (_) =>
                const SettingsScreen(),
          ),
        );
        break;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _currentNavigationIndex =
          0;
    });
  }

  // ============================================================
  // CREATE POST
  // ============================================================

  Future<void>
      _openCreatePost() async {
    await Navigator.of(
      context,
    ).push(
      MaterialPageRoute(
        builder: (_) =>
            const CreatePostScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _currentNavigationIndex =
          0;
    });

    await _loadPosts();
  }

  // ============================================================
  // PROFILE NAVIGATION (UPDATED FOR IMAGE SYNCHRONIZATION)
  // ============================================================

  bool _openingProfile = false;

Future<void> _openProfile() async {
  if (!mounted || _openingProfile) return;

  _openingProfile = true;

  try {
    // Wait until the current tap/navigation frame is completely finished.
    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) return;

    final navigator = Navigator.of(context);

    // Schedule the push after Flutter finishes the current frame.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    if (!mounted) return;

    final profileChanged = await navigator.push(
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(),
      ),
    );

    if (!mounted) return;

    if (profileChanged == true) {
      await _loadUser();
      await _loadPosts();
    }
  } catch (error) {
    debugPrint('Open Profile Error: $error');
  } finally {
    _openingProfile = false;
  }
}

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  Future<void>
      _openNotifications() async {
    await Navigator.of(
      context,
    ).push(
      MaterialPageRoute(
        builder: (_) =>
            const NotificationsScreen(),
      ),
    );
  }

  // ============================================================
  // POST OPTIONS
  // ============================================================

  void _showPostOptions(
    Map<String, dynamic> post,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      showDragHandle: true,
      builder: (
        sheetContext,
      ) {
        return SafeArea(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    Icon(
                  Icons
                      .link_rounded,
                  color: _text,
                ),
                title:
                    Text(
                  'Copy post ID',
                  style:
                      TextStyle(
                    color: _text,
                  ),
                ),
                onTap: () {
                  final postId = post['_id']?.toString() ?? '';
                  Navigator.pop(sheetContext);
                  if (postId.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: postId));
                    _showMessage('Post ID copied');
                  } else {
                    _showMessage('Post ID is unavailable');
                  }
                },
              ),
              ListTile(
                leading:
                    Icon(
                  Icons
                      .flag_outlined,
                  color: _text,
                ),
                title:
                    Text(
                  'Report post',
                  style:
                      TextStyle(
                    color: _text,
                  ),
                ),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _showMessage(
                    'Report feature coming soon',
                  );
                },
              ),
              const SizedBox(
                height: 8,
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _avatar(
    dynamic image,
    String name,
    double radius,
  ) {
    final value =
        image
                ?.toString()
                .trim() ??
            '';

    Widget fallback() {
      final trimmed =
          name.trim();

      final letter =
          trimmed.isEmpty
              ? '?'
              : trimmed
                  .substring(
                    0,
                    1,
                  )
                  .toUpperCase();

      return Container(
        width:
            radius * 2,
        height:
            radius * 2,
        alignment:
            Alignment.center,
        decoration:
            BoxDecoration(
          shape:
              BoxShape.circle,
          color:
              _dark
                  ? const Color(
                      0xFF25282D,
                    )
                  : const Color(
                      0xFFE4E7EB,
                    ),
        ),
        child:
            Text(
          letter,
          style:
              TextStyle(
            color: _text,
            fontSize:
                radius * .72,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      );
    }

    if (value.isEmpty) {
      return fallback();
    }

    final bytes =
        ApiService.dataUrlToBytes(
      value,
    );

    if (bytes != null) {
      return CircleAvatar(
        radius:
            radius,
        backgroundColor:
            Colors.transparent,
        backgroundImage:
            MemoryImage(
          Uint8List.fromList(
            bytes,
          ),
        ),
      );
    }

    final url =
        ApiService.normalizeImageUrl(
      value,
    );

    if (url == null) {
      return fallback();
    }

    return CircleAvatar(
      radius:
          radius,
      backgroundColor:
          Colors.transparent,
      backgroundImage:
          NetworkImage(
        url,
      ),
      onBackgroundImageError:
          (
        _,
        __,
      ) {},
    );
  }

  // ============================================================
  // DISPLAY NAME
  // ============================================================

  String _displayName(
    Map<String, dynamic> user,
  ) {
    final displayName =
        user['displayName']
                ?.toString()
                .trim() ??
            '';

    if (displayName.isNotEmpty) {
      return displayName;
    }

    final name =
        user['name']
                ?.toString()
                .trim() ??
            '';

    if (name.isNotEmpty) {
      return name;
    }

    final fullName =
        user['fullName']
                ?.toString()
                .trim() ??
            '';

    if (fullName.isNotEmpty) {
      return fullName;
    }

    final username =
        user['username']
                ?.toString()
                .trim() ??
            '';

    if (username.isNotEmpty) {
      return username;
    }

    return 'User';
  }

  // ============================================================
  // USERNAME
  // ============================================================

  String _username(
    Map<String, dynamic> user,
  ) {
    return user['username']
            ?.toString()
            .trim() ??
        '';
  }

  // ============================================================
  // TIME AGO
  // ============================================================

  String _timeAgo(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    DateTime? date;

    if (value is DateTime) {
      date = value;
    } else {
      date =
          DateTime.tryParse(
        value.toString(),
      );
    }

    if (date == null) {
      return '';
    }

    final now =
        DateTime.now();

    final difference =
        now.difference(
      date.toLocal(),
    );

    if (difference.isNegative) {
      return 'now';
    }

    if (difference.inSeconds <
        60) {
      return 'now';
    }

    if (difference.inMinutes <
        60) {
      return '${difference.inMinutes}m';
    }

    if (difference.inHours <
        24) {
      return '${difference.inHours}h';
    }

    if (difference.inDays <
        7) {
      return '${difference.inDays}d';
    }

    if (difference.inDays <
        365) {
      final weeks =
          difference.inDays ~/ 7;

      return '${weeks}w';
    }

    final years =
        difference.inDays ~/ 365;

    return '${years}y';
  }

  // ============================================================
  // COUNT FORMAT
  // ============================================================

  String _formatCount(
    int value,
  ) {
    if (value < 1000) {
      return value.toString();
    }

    if (value < 1000000) {
      final number =
          value / 1000;

      if (number >= 100) {
        return '${number.toStringAsFixed(0)}K';
      }

      if (number >= 10) {
        return '${number.toStringAsFixed(1)}K';
      }

      return '${number.toStringAsFixed(1)}K';
    }

    final number =
        value / 1000000;

    if (number >= 100) {
      return '${number.toStringAsFixed(0)}M';
    }

    return '${number.toStringAsFixed(1)}M';
  }

  // ============================================================
  // FRIENDLY ERROR
  // ============================================================

  String _friendlyError(
    dynamic error,
    String fallback,
  ) {
    final message =
        error
                ?.toString()
                .replaceFirst(
                  'Exception: ',
                  '',
                )
                .trim() ??
            '';

    if (message.isEmpty) {
      return fallback;
    }

    return message;
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(message),
        behavior:
            SnackBarBehavior
                .floating,
        duration:
            const Duration(
          seconds: 2,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          _background,

      extendBody: true,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor:
            _surface,
        surfaceTintColor:
            Colors.transparent,
        elevation: 0,
        scrolledUnderElevation:
            0,
        centerTitle: true,

        leading:
            IconButton(
          tooltip:
              'Profile',
          onPressed: () {
  debugPrint('HOME PROFILE BUTTON TAPPED');
  _openProfile();
},
          icon:
              _loadingUser
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child:
                          CircularProgressIndicator(
                        strokeWidth:
                            2,
                        color:
                            _muted,
                      ),
                    )
                  : _avatar(
                      _currentUser?[
                          'avatar'],
                      _displayName(
                        _currentUser ??
                            {},
                      ),
                      16,
                    ),
        ),

        title:
            Text(
          'MicroBlog',
          style:
              TextStyle(
            color: _text,
            fontSize: 20,
            fontWeight:
                FontWeight.w900,
            letterSpacing:
                -.4,
          ),
        ),

        actions: [
          IconButton(
            tooltip:
                'Notifications',
            onPressed:
                _openNotifications,
            icon:
                Icon(
              Icons
                  .notifications_none_rounded,
              color: _text,
              size: 25,
            ),
          ),
        ],
      ),

      // ========================================================
      // FEED
      // ========================================================

      body:
          RefreshIndicator(
        color: _accent,
        onRefresh:
            _refresh,
        child:
            CustomScrollView(
          controller:
              _scrollController,
          physics:
              const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (_loadingPosts)
              const SliverFillRemaining(
                hasScrollBody:
                    false,
                child:
                    Center(
                  child:
                      CircularProgressIndicator(
                    color:
                        _accent,
                  ),
                ),
              )
            else if (_posts.isEmpty)
              SliverFillRemaining(
                hasScrollBody:
                    false,
                child:
                    Center(
                  child:
                      Column(
                    mainAxisSize:
                        MainAxisSize
                            .min,
                    children: [
                      Icon(
                        Icons
                            .dynamic_feed_outlined,
                        size: 46,
                        color:
                            _muted,
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      Text(
                        'No posts yet',
                        style:
                            TextStyle(
                          color:
                              _muted,
                          fontSize:
                              16,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate:
                    SliverChildBuilderDelegate(
                  (
                    context,
                    index,
                  ) {
                    final raw =
                        _posts[
                            index];

                    if (raw
                        is! Map) {
                      return const SizedBox
                          .shrink();
                    }

                    return _postCard(
                      Map<String,
                          dynamic>.from(
                        raw,
                      ),
                    );
                  },
                  childCount:
                      _posts.length,
                ),
              ),

            const SliverToBoxAdapter(
              child:
                  SizedBox(
                height: 100,
              ),
            ),
          ],
        ),
      ),

      // ========================================================
      // BOTTOM NAVIGATION
      //
      // When hidden, this is NULL.
      // Therefore Flutter gives the feed that entire area.
      // ========================================================

      bottomNavigationBar:
          _showBottomNavigation
              ? _bottomNavigation()
              : null,
    );
  }
}

// ==================================================================
// COMMENTS SHEET
//
// Separate widget prevents the comments modal from holding onto
// HomeScreen's inherited dependencies while it is being dismissed.
// ==================================================================

class _CommentsSheet
    extends StatefulWidget {
  final List<dynamic> comments;

  final String postId;

  final Color surfaceColor;
  final Color backgroundColor;
  final Color textColor;
  final Color mutedColor;
  final Color dividerColor;
  final Color composerColor;

  const _CommentsSheet({
    required this.comments,
    required this.postId,
    required this.surfaceColor,
    required this.backgroundColor,
    required this.textColor,
    required this.mutedColor,
    required this.dividerColor,
    required this.composerColor,
  });

  @override
  State<_CommentsSheet> createState() =>
      _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  late final TextEditingController _controller;
  late List<dynamic> _comments;

  Map<String, dynamic>? _replyTo;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _comments = List<dynamic>.from(widget.comments);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ============================================================
  // COMMENT COUNT (INCLUDES REPLIES)
  // ============================================================

  int _countComments(List<dynamic> comments) {
    var count = 0;
    for (final raw in comments) {
      if (raw is Map) {
        count++;
        final replies = raw['replies'];
        if (replies is List) {
          count += _countComments(List<dynamic>.from(replies));
        }
      }
    }
    return count;
  }

  // ============================================================
  // ADD A NEW REPLY TO ITS PARENT IN THE EXISTING COMMENT TREE
  // ============================================================

  bool _appendReplyToParent(
    List<dynamic> comments,
    String parentId,
    dynamic reply,
  ) {
    for (final raw in comments) {
      if (raw is! Map) continue;

      final id = raw['_id']?.toString() ?? '';
      if (id == parentId) {
        final replies = raw['replies'];
        if (replies is List) {
          replies.add(reply);
        } else {
          raw['replies'] = <dynamic>[reply];
        }
        return true;
      }

      final nested = raw['replies'];
      if (nested is List &&
          _appendReplyToParent(
            List<dynamic>.from(nested),
            parentId,
            reply,
          )) {
        return true;
      }
    }
    return false;
  }

  // ============================================================
  // SEND COMMENT OR REPLY
  // ============================================================

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final parentId = _replyTo?['_id']?.toString();

    setState(() {
      _sending = true;
    });

    try {
      final result = await ApiService.createComment(
        postId: widget.postId,
        content: text,
        parentId: parentId,
      );

      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Unable to add comment');
      }

      final rawComment = result['data']?['comment'];
      if (rawComment == null) {
        throw Exception('Comment was not returned by the server');
      }

      final comment = rawComment is Map
          ? Map<String, dynamic>.from(rawComment)
          : null;
      if (comment == null) {
        throw Exception('Invalid comment response from the server');
      }

      if (!mounted) return;

      setState(() {
        if (parentId != null && parentId.isNotEmpty) {
          final added = _appendReplyToParent(_comments, parentId, comment);
          if (!added) {
            // If the parent is unexpectedly absent from the local tree,
            // keep the returned comment visible rather than losing it.
            _comments.add(comment);
          }
        } else {
          _comments.add(comment);
        }

        _controller.clear();
        _replyTo = null;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

// Update a comment or reply inside the local nested list.
bool _replaceCommentInTree(
  List<dynamic> comments,
  String commentId,
  String content,
  Map<String, dynamic>? serverComment,
) {
  for (final raw in comments) {
    if (raw is! Map) continue;

    if ((raw["_id"]?.toString() ?? "") == commentId) {
      if (serverComment != null) {
        raw.addAll(serverComment);
      }

      raw["content"] = content;
      raw["updatedAt"] =
          serverComment?["updatedAt"] ??
          DateTime.now().toIso8601String();

      return true;
    }

    final replies = raw["replies"];

    if (replies is List &&
        _replaceCommentInTree(
          replies,
          commentId,
          content,
          serverComment,
        )) {
      return true;
    }
  }

  return false;
}

// Remove a comment or reply from the local nested list.
bool _removeCommentFromTree(
  List<dynamic> comments,
  String commentId,
) {
  for (var i = 0; i < comments.length; i++) {
    final raw = comments[i];
    if (raw is! Map) continue;

    if ((raw["_id"]?.toString() ?? "") == commentId) {
      comments.removeAt(i);
      return true;
    }

    final replies = raw["replies"];

    if (replies is List &&
        _removeCommentFromTree(replies, commentId)) {
      return true;
    }
  }

  return false;
}

// Read the author ID regardless of whether author is populated.
String _commentAuthorId(Map<String, dynamic> comment) {
  final author = comment["author"];

  if (author is Map) {
    return author["_id"]?.toString() ??
        author["id"]?.toString() ??
        "";
  }

  return author?.toString() ?? "";
}

// Show the edit dialog and save the change to the backend.
Future<void> _editComment(
  Map<String, dynamic> comment,
) async {
  final commentId = comment["_id"]?.toString() ?? "";
  if (commentId.isEmpty) return;

  final controller = TextEditingController(
    text: comment["content"]?.toString() ?? "",
  );

  final editedText = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Edit comment"),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 2,
        maxLines: 5,
        maxLength: 300,
        decoration: const InputDecoration(
          hintText: "Write your comment...",
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();

            if (value.isNotEmpty) {
              Navigator.pop(dialogContext, value);
            }
          },
          child: const Text("Save"),
        ),
      ],
    ),
  );

  controller.dispose();

  if (!mounted ||
      editedText == null ||
      editedText.trim().isEmpty) {
    return;
  }

  if (editedText.trim() ==
      (comment["content"]?.toString() ?? "").trim()) {
    return;
  }

  try {
    final result = await ApiService.updateComment(
      postId: widget.postId,
      commentId: commentId,
      content: editedText.trim(),
    );

    if (!mounted) return;

    if (result["success"] != true) {
      throw Exception(
        result["message"] ?? "Unable to edit comment",
      );
    }

    final data = result["data"];
    final rawUpdated =
        data is Map ? data["comment"] : null;

    final updated = rawUpdated is Map
        ? Map<String, dynamic>.from(rawUpdated)
        : null;

    setState(() {
      _replaceCommentInTree(
        _comments,
        commentId,
        editedText.trim(),
        updated,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Comment updated")),
    );
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.toString().replaceFirst("Exception: ", ""),
        ),
      ),
    );
  }
}

// Confirm deletion, then remove the comment and its replies.
Future<void> _deleteComment(
  Map<String, dynamic> comment,
) async {
  final commentId = comment["_id"]?.toString() ?? "";
  if (commentId.isEmpty) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Delete comment?"),
      content: const Text(
        "This comment and its replies will be deleted. "
        "This action cannot be undone.",
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(dialogContext, false),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(dialogContext, true),
          child: const Text(
            "Delete",
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );

  if (!mounted || confirmed != true) return;

  try {
    final result = await ApiService.deleteComment(
      postId: widget.postId,
      commentId: commentId,
    );

    if (!mounted) return;

    if (result["success"] != true) {
      throw Exception(
        result["message"] ?? "Unable to delete comment",
      );
    }

    setState(() {
      _removeCommentFromTree(_comments, commentId);

      if (_replyTo?["_id"]?.toString() == commentId) {
        _replyTo = null;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Comment deleted")),
    );
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.toString().replaceFirst("Exception: ", ""),
        ),
      ),
    );
  }
}

  // ============================================================
  // AUTHOR HELPERS
  // ============================================================

  String _displayName(Map<String, dynamic> user) {
    final displayName = user['displayName']?.toString().trim() ?? '';
    if (displayName.isNotEmpty) return displayName;

    final name = user['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;

    final fullName = user['fullName']?.toString().trim() ?? '';
    if (fullName.isNotEmpty) return fullName;

    final username = user['username']?.toString().trim() ?? '';
    if (username.isNotEmpty) return username;

    return 'User';
  }

  String _username(Map<String, dynamic> user) {
    return user['username']?.toString().trim() ?? '';
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _avatar(dynamic image, String name, double radius) {
    final value = image?.toString().trim() ?? '';
    final trimmedName = name.trim();
    final letter = trimmedName.isEmpty ? '?' : trimmedName.substring(0, 1).toUpperCase();

    Widget fallback() {
      return Container(
        width: radius * 2,
        height: radius * 2,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.composerColor,
        ),
        child: Text(
          letter,
          style: TextStyle(
            color: widget.textColor,
            fontSize: radius * .72,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    if (value.isEmpty) return fallback();

    final bytes = ApiService.dataUrlToBytes(value);
    if (bytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(Uint8List.fromList(bytes)),
      );
    }

    final url = ApiService.normalizeImageUrl(value);
    if (url == null) return fallback();

    return CircleAvatar(
      radius: radius,
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (_, _) {},
    );
  }

  // ============================================================
  // BUILD A COMMENT AND ITS NESTED REPLIES
  // ============================================================

  Widget _buildComment(dynamic raw, {int depth = 0}) {
    final comment = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};

    final authorRaw = comment['author'];
    final author = authorRaw is Map
        ? Map<String, dynamic>.from(authorRaw)
        : <String, dynamic>{};

    final name = _displayName(author);
    final username = _username(author);
    final content = comment['content']?.toString() ?? '';
    final replies = comment['replies'] is List
        ? List<dynamic>.from(comment['replies'] as List)
        : <dynamic>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(author['avatar'], name, 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: widget.textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (username.isNotEmpty)
                    Text(
                      '@$username',
                      style: TextStyle(
                        color: widget.mutedColor,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 5),
                  Text(
                    content,
                    style: TextStyle(
                      color: widget.textColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _replyTo = comment;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(40, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      alignment: Alignment.centerLeft,
                    ),
                    child: Text(
                      'Reply',
                      style: TextStyle(
                        color: widget.mutedColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 26, top: 8),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: widget.dividerColor,
                    width: 1.5,
                  ),
                ),
              ),
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                children: [
                  for (int i = 0; i < replies.length; i++) ...[
                    _buildComment(replies[i], depth: depth + 1),
                    if (i != replies.length - 1)
                      const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .78,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: widget.mutedColor.withValues(alpha: .4),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Comments',
                      style: TextStyle(
                        color: widget.textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop(_countComments(_comments));
                    },
                    icon: Icon(Icons.close_rounded, color: widget.textColor),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: widget.dividerColor),
            Expanded(
              child: _comments.isEmpty
                  ? Center(
                      child: Text(
                        'No comments yet',
                        style: TextStyle(color: widget.mutedColor),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _comments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (_, index) => _buildComment(_comments[index]),
                    ),
            ),
            if (_replyTo != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                color: widget.surfaceColor,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to ${_displayName(
                          _replyTo!['author'] is Map
                              ? Map<String, dynamic>.from(_replyTo!['author'])
                              : <String, dynamic>{},
                        )}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.mutedColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cancel reply',
                      onPressed: () {
                        setState(() {
                          _replyTo = null;
                        });
                      },
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: widget.mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: EdgeInsets.fromLTRB(
                14,
                10,
                14,
                MediaQuery.of(context).viewInsets.bottom + 10,
              ),
              decoration: BoxDecoration(
                color: widget.surfaceColor,
                border: Border(top: BorderSide(color: widget.dividerColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      style: TextStyle(color: widget.textColor),
                      decoration: InputDecoration(
                        hintText: _replyTo == null
                            ? 'Write a comment...'
                            : 'Write a reply...',
                        hintStyle: TextStyle(color: widget.mutedColor),
                        filled: true,
                        fillColor: widget.composerColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _sendComment,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2D78),
                      foregroundColor: Colors.white,
                    ),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
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
