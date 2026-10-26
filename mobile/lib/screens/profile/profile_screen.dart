import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../bookmark/bookmark_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // COLORS
  // ============================================================

  bool get _isDark =>
      Theme.of(context).brightness == Brightness.dark;

  Color get _background => _isDark
      ? const Color(0xFF000000)
      : const Color(0xFFFFFFFF);

  Color get _surface => _isDark
      ? const Color(0xFF0A0A0A)
      : const Color(0xFFFFFFFF);

  Color get _secondarySurface => _isDark
      ? const Color(0xFF16181C)
      : const Color(0xFFF3F4F6);

  Color get _text => _isDark
      ? const Color(0xFFF5F5F5)
      : const Color(0xFF111111);

  Color get _muted => _isDark
      ? const Color(0xFF71767B)
      : const Color(0xFF687078);

  Color get _divider => _isDark
      ? const Color(0xFF2F3336)
      : const Color(0xFFE5E7EB);

  static const Color _accent = Color(0xFF1D9BF0);
  static const Color _likeColor = Color(0xFFF91880);

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = true;
  bool _isLoadingPosts = false;

  Map<String, dynamic>? _user;

  int _savedPostsCount = 0;
  int _followersCount = 0;
  int _followingCount = 0;

  File? _pendingProfilePhoto;
  File? _pendingCoverPhoto;

  bool _uploadingAvatar = false;
  bool _uploadingCover = false;

  final ImagePicker _imagePicker = ImagePicker();

  late TabController _tabController;

  List<Map<String, dynamic>> _allPosts = [];

  bool _postsLoaded = false;

  int _activeTab = 0;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 4,
      vsync: this,
    );

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        return;
      }

      if (!mounted) return;

      setState(() {
        _activeTab = _tabController.index;
      });

      _loadPostsIfNeeded();
    });

    _loadProfile();

    // Load posts right away so the Posts tab is filled on first open
    // (previously posts only loaded after switching tabs / reloading).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadPostsIfNeeded();
    });

    // Android can lose the selected gallery item if the activity
    // is recreated while the system picker is open.
    _recoverLostPickerData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD PROFILE
  // ============================================================

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final result = await ApiService.getMe();

      Map<String, dynamic>? user;

      if (result["success"] == true &&
          result["data"] is Map &&
          result["data"]["user"] is Map) {
        user = Map<String, dynamic>.from(
          result["data"]["user"],
        );
      }

      int savedCount = 0;

      try {
        final prefs =
            await SharedPreferences.getInstance();

        final savedPosts =
            prefs.getStringList("saved_posts") ??
                <String>[];

        savedCount = savedPosts.length;
      } catch (error) {
        debugPrint(
          "Load Saved Count Error: $error",
        );
      }

      if (!mounted) return;

      setState(() {
        _user = user;
        _savedPostsCount = savedCount;

        _followersCount = _readCount(
          user?["followersCount"],
          user?["followers"],
        );

        _followingCount = _readCount(
          user?["followingCount"],
          user?["following"],
        );

        _isLoading = false;
      });
    } catch (error) {
      debugPrint(
        "Load Profile Error: $error",
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            error
                .toString()
                .contains("Authentication token")
                ? "Please login again"
                : "Unable to load profile",
          ),
        ),
      );
    }
  }

  // ============================================================
  // READ COUNT
  // ============================================================

  int _readCount(
    dynamic primary,
    dynamic fallback,
  ) {
    if (primary is num) {
      return primary.toInt();
    }

    if (fallback is List) {
      return fallback.length;
    }

    if (fallback is num) {
      return fallback.toInt();
    }

    return 0;
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refreshProfile() async {
    await _loadProfile();

    if (_postsLoaded) {
      await _loadAllPosts(force: true);
    }
  }

  // ============================================================
  // BASIC USER DATA
  // ============================================================

  String get _username {
    final value =
        _user?["username"]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }

    return "User";
  }

  String get _displayName {
    final value =
        _user?["displayName"]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }

    return _username;
  }

  String get _email {
    return _user?["email"]?.toString() ?? "";
  }

  String get _bio {
    return _user?["bio"]?.toString().trim() ?? "";
  }

  String get _location {
    return _user?["location"]?.toString().trim() ?? "";
  }

  /// Date of birth, shown as "12 May 1995". Empty when the user
  /// model has no `dateOfBirth` yet.
  String get _dobText {
    final raw = (_user?["dateOfBirth"] ??
            _user?["dob"])
        ?.toString()
        .trim();

    if (raw == null || raw.isEmpty) {
      return "";
    }

    final date =
        DateTime.tryParse(raw)?.toLocal();

    if (date == null) return "";

    const months = [
      "Jan", "Feb", "Mar", "Apr",
      "May", "Jun", "Jul", "Aug",
      "Sep", "Oct", "Nov", "Dec",
    ];

    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

  String get _website {
    return _user?["website"]?.toString().trim() ?? "";
  }

  String get _userId {
    return _user?["_id"]?.toString() ??
        _user?["id"]?.toString() ??
        "";
  }

  String get _initials {
    final name = _displayName.trim();

    if (name.isEmpty) {
      return "U";
    }

    final parts =
        name.split(RegExp(r"\s+"));

    if (parts.length >= 2) {
      return (
        parts[0][0] +
        parts[1][0]
      ).toUpperCase();
    }

    return name[0].toUpperCase();
  }

  String _formatJoinedDate() {
    final createdAt = _user?["createdAt"];

    if (createdAt == null) {
      return "MicroBlog member";
    }

    final date = DateTime.tryParse(
      createdAt.toString(),
    );

    if (date == null) {
      return "MicroBlog member";
    }

    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];

    return "Joined ${months[date.month - 1]} ${date.year}";
  }

  // ============================================================
  // LOST IMAGE PICKER DATA
  // ============================================================

  Future<void> _recoverLostPickerData() async {
    try {
      final response =
          await _imagePicker.retrieveLostData();

      if (response.isEmpty) {
        return;
      }

      final files = response.files;

      if (files == null || files.isEmpty) {
        return;
      }

      final file = files.first;

      // There is no reliable way to know whether the lost picker
      // operation belonged to avatar or cover after an activity
      // recreation, so profile photo is the safe default.
      await _processSelectedImage(
        file,
        isAvatar: true,
      );
    } catch (error) {
      debugPrint(
        "Recover Lost Picker Data Error: $error",
      );
    }
  }

  // ============================================================
  // PICK PROFILE PHOTO
  // ============================================================

  Future<void> _pickProfilePhoto() async {
    try {
      final XFile? pickedFile =
          await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 2000,
      );

      if (pickedFile == null) {
        return;
      }

      await _processSelectedImage(
        pickedFile,
        isAvatar: true,
      );
    } catch (error) {
      debugPrint(
        "Pick Profile Photo Error: $error",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Unable to select profile photo",
          ),
        ),
      );
    }
  }

  // ============================================================
  // PICK COVER PHOTO
  // ============================================================

  Future<void> _pickCoverPhoto() async {
    try {
      final XFile? pickedFile =
          await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 2500,
      );

      if (pickedFile == null) {
        return;
      }

      await _processSelectedImage(
        pickedFile,
        isAvatar: false,
      );
    } catch (error) {
      debugPrint(
        "Pick Cover Photo Error: $error",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Unable to select cover photo",
          ),
        ),
      );
    }
  }

  // ============================================================
  // CROP SELECTED IMAGE
  // ============================================================

  Future<File?> _cropImage(
    XFile pickedFile, {
    required bool isAvatar,
  }) async {
    try {
      final CroppedFile? cropped =
          await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        compressQuality: 90,
        maxWidth: isAvatar ? 1200 : 2000,
        maxHeight: isAvatar ? 1200 : 1000,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: isAvatar
                ? "Crop profile photo"
                : "Crop cover photo",
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            activeControlsWidgetColor:
                _accent,
            initAspectRatio: isAvatar
                ? CropAspectRatioPreset.square
                : CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: isAvatar
                ? "Crop profile photo"
                : "Crop cover photo",
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
          ),
        ],
      );

      if (cropped == null) {
        return null;
      }

      return File(cropped.path);
    } catch (error) {
      debugPrint(
        "Crop Image Error: $error",
      );

      if (!mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Unable to crop this photo",
          ),
        ),
      );

      return null;
    }
  }

  // ============================================================
  // PROCESS SELECTED IMAGE
  // ============================================================

  Future<void> _processSelectedImage(
    XFile pickedFile, {
    required bool isAvatar,
  }) async {
    final croppedFile = await _cropImage(
      pickedFile,
      isAvatar: isAvatar,
    );

    if (croppedFile == null) {
      return;
    }

    if (!mounted) return;

    if (isAvatar) {
      setState(() {
        _pendingProfilePhoto = croppedFile;
        _uploadingAvatar = true;
      });
    } else {
      setState(() {
        _pendingCoverPhoto = croppedFile;
        _uploadingCover = true;
      });
    }

    try {
      final dataUrl =
          await ApiService.fileToDataUrl(
        croppedFile,
      );

      final result =
          isAvatar
              ? await ApiService.updateProfile(
                  avatar: dataUrl,
                )
              : await ApiService.updateProfile(
                  coverPhoto: dataUrl,
                );

      if (!mounted) return;

      if (result["success"] != true) {
        throw Exception(
          result["message"] ??
              "Unable to update photo",
        );
      }

      final updatedUser =
          result["data"] is Map &&
                  result["data"]["user"] is Map
              ? Map<String, dynamic>.from(
                  result["data"]["user"],
                )
              : null;

      setState(() {
        if (updatedUser != null) {
          _user = updatedUser;
        } else {
          _user = {
            ...?_user,
            if (isAvatar)
              "avatar": dataUrl
            else
              "coverPhoto": dataUrl,
          };
        }

        if (isAvatar) {
          _pendingProfilePhoto = null;
          _uploadingAvatar = false;
        } else {
          _pendingCoverPhoto = null;
          _uploadingCover = false;
        }
      });

      await _askSharePhotoToFeed(
        dataUrl: dataUrl,
        isAvatar: isAvatar,
      );
    } catch (error) {
      debugPrint(
        "Upload Profile Photo Error: $error",
      );

      if (!mounted) return;

      setState(() {
        if (isAvatar) {
          _pendingProfilePhoto = null;
          _uploadingAvatar = false;
        } else {
          _pendingCoverPhoto = null;
          _uploadingCover = false;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            error
                .toString()
                .replaceFirst(
                  "Exception: ",
                  "",
                ),
          ),
        ),
      );
    }
  }

  // ============================================================
  // SHARE PHOTO TO FEED
  // ============================================================

  Future<void> _askSharePhotoToFeed({
  required String dataUrl,
  required bool isAvatar,
}) async {
  if (!mounted) return;

  final shouldShare = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: _surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(24),
      ),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Share to feed?",
                style: TextStyle(
                  color: _text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isAvatar
                    ? "Would you like to share your new profile photo with your followers?"
                    : "Would you like to share your new cover photo with your followers?",
                style: TextStyle(
                  color: _muted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(
                          sheetContext,
                          false,
                        );
                      },
                      child: const Text("Not now"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(
                          sheetContext,
                          true,
                        );
                      },
                      child: const Text("Share"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  if (shouldShare != true) {
    return;
  }

  // Let the bottom-sheet route finish closing before
  // opening the next dialog.
  await Future<void>.delayed(
    const Duration(milliseconds: 200),
  );

  if (!mounted) return;

  await _showPhotoCaptionDialog(
    dataUrl: dataUrl,
    isAvatar: isAvatar,
  );
}

// ============================================================
// PHOTO CAPTION
// ============================================================

Future<void> _showPhotoCaptionDialog({
  required String dataUrl,
  required bool isAvatar,
}) async {
  final controller = TextEditingController(
    text: isAvatar
        ? "I updated my profile photo."
        : "I updated my cover photo.",
  );

  final caption = await showDialog<String?>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: _surface,
        title: Text(
          "Share to feed",
          style: TextStyle(
            color: _text,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 500,
          style: TextStyle(
            color: _text,
          ),
          decoration: InputDecoration(
            hintText: "Write a caption...",
            hintStyle: TextStyle(
              color: _muted,
            ),
            filled: true,
            fillColor: _secondarySurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: Text(
              "Cancel",
              style: TextStyle(
                color: _muted,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _text,
              foregroundColor: _background,
            ),
            onPressed: () {
              Navigator.pop(
                dialogContext,
                controller.text.trim(),
              );
            },
            child: const Text(
              "Post",
            ),
          ),
        ],
      );
    },
  );

  // IMPORTANT:
  // Do not dispose the controller immediately after the dialog
  // closes. The dialog's widget tree may still be tearing down.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    controller.dispose();
  });

  if (caption == null) {
    return;
  }

  if (!mounted) {
    return;
  }

  await _publishPhotoToFeed(
    caption: caption.trim(),
    dataUrl: dataUrl,
  );
}

  // ============================================================
  // PUBLISH PHOTO TO FEED
  // ============================================================

  Future<void> _publishPhotoToFeed({
    required String caption,
    required String dataUrl,
  }) async {
    try {
      final result =
          await ApiService.createPost(
        content: caption,
        image: dataUrl,
      );

      if (!mounted) return;

      if (result["success"] != true) {
        throw Exception(
          result["message"] ??
              "Unable to share photo",
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior:
              SnackBarBehavior.floating,
          content: Text(
            "Photo shared to your feed",
          ),
        ),
      );

      if (_postsLoaded) {
        await _loadAllPosts(
          force: true,
        );
      }
    } catch (error) {
      debugPrint(
        "Share Profile Photo Error: $error",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          content: Text(
            error
                .toString()
                .replaceFirst(
                  "Exception: ",
                  "",
                ),
          ),
        ),
      );
    }
  }

  // ============================================================
  // EDIT PROFILE
  // ============================================================

  Future<void> _openEditProfile() async {
    final updatedUser =
        await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditProfileScreen(
          user: _user ?? {},
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (updatedUser is Map) {
      // Some versions of the edit screen return the whole API
      // payload ({user: {...}}) instead of the user itself.
      final map =
          Map<String, dynamic>.from(
        updatedUser,
      );

      setState(() {
        _user = map["user"] is Map
            ? Map<String, dynamic>.from(
                map["user"],
              )
            : map;
      });
    }

    // Always re-sync with the server so username, link, counts and
    // every other field reflect what was actually saved.
    await _loadProfile();
  }

  // ============================================================
  // FULL SCREEN PHOTO VIEWER
  // ============================================================

  ImageProvider? _photoProvider({
    required bool isAvatar,
  }) {
    final pending = isAvatar
        ? _pendingProfilePhoto
        : _pendingCoverPhoto;

    if (pending != null) {
      return FileImage(pending);
    }

    final value = _user?[isAvatar
                ? "avatar"
                : "coverPhoto"]
            ?.toString()
            .trim() ??
        "";

    if (value.isEmpty) return null;

    if (value.startsWith("data:image/")) {
      final bytes =
          ApiService.dataUrlToBytes(value);

      return bytes == null
          ? null
          : MemoryImage(
              Uint8List.fromList(bytes),
            );
    }

    final normalized =
        ApiService.normalizeImageUrl(value);

    return normalized == null
        ? null
        : NetworkImage(normalized);
  }

  void _openPhotoViewer({
    required bool isAvatar,
  }) {
    final provider =
        _photoProvider(isAvatar: isAvatar);

    if (provider == null) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) =>
            Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor:
                Colors.black,
            foregroundColor:
                Colors.white,
            elevation: 0,
          ),
          body: GestureDetector(
            onTap: () =>
                Navigator.of(context)
                    .pop(),
            child: Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image(
                  image: provider,
                  fit: BoxFit.contain,
                  errorBuilder:
                      (_, __, ___) =>
                          const Icon(
                    Icons
                        .broken_image_outlined,
                    color:
                        Colors.white54,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
        ),
        transitionsBuilder:
            (_, animation, __, child) =>
                FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  // ============================================================
  // SAVED POSTS
  // ============================================================

  Future<void> _openSavedPosts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const BookmarkScreen(),
      ),
    );

    if (!mounted) return;

    await _loadProfile();
  }

  // ============================================================
  // LOAD POSTS
  // ============================================================

  Future<void> _loadPostsIfNeeded() async {
    if (_postsLoaded ||
        _isLoadingPosts) {
      return;
    }

    await _loadAllPosts();
  }

  Future<void> _loadAllPosts({
    bool force = false,
  }) async {
    if (_isLoadingPosts) {
      return;
    }

    if (_postsLoaded && !force) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoadingPosts = true;
    });

    try {
      final result =
          await ApiService.getPosts();

      if (result["success"] != true) {
        throw Exception(
          result["message"] ??
              "Unable to load posts",
        );
      }

      final rawPosts =
          result["data"]?["posts"];

      final List<Map<String, dynamic>>
          parsed = [];

      if (rawPosts is List) {
        for (final raw in rawPosts) {
          if (raw is Map) {
            parsed.add(
              Map<String, dynamic>.from(
                raw,
              ),
            );
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _allPosts = parsed;
        _postsLoaded = true;
        _isLoadingPosts = false;
      });
    } catch (error) {
      debugPrint(
        "Load Profile Posts Error: $error",
      );

      if (!mounted) return;

      setState(() {
        _isLoadingPosts = false;
        _postsLoaded = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          content: Text(
            error
                .toString()
                .replaceFirst(
                  "Exception: ",
                  "",
                ),
          ),
        ),
      );
    }
  }

  // ============================================================
  // TAB POSTS
  // ============================================================

  List<Map<String, dynamic>>
      get _profilePosts {
    return _allPosts.where((post) {
      final author =
          post["author"];

      final authorId =
          author is Map
              ? author["_id"]?.toString()
              : author?.toString();

      final repostOf =
          post["repostOf"];

      return authorId == _userId &&
          repostOf == null;
    }).toList();
  }

  // ============================================================
  // TAB REPOSTS
  // ============================================================

  List<Map<String, dynamic>>
      get _profileReposts {
    return _allPosts.where((post) {
      final author =
          post["author"];

      final authorId =
          author is Map
              ? author["_id"]?.toString()
              : author?.toString();

      return authorId == _userId &&
          post["repostOf"] != null;
    }).toList();
  }

  // ============================================================
  // TAB LIKES
  // ============================================================

  List<Map<String, dynamic>>
      get _profileLikes {
    return _allPosts.where((post) {
      if (post["likedByMe"] == true) {
        return true;
      }

      final likes =
          post["likes"];

      if (likes is! List) {
        return false;
      }

      return likes.any(
        (id) =>
            id?.toString() == _userId,
      );
    }).toList();
  }

  // ============================================================
  // TAB COMMENTS
  // ============================================================

  Future<List<Map<String, dynamic>>>
      _loadCommentedPosts() async {
    try {
      final result =
          await ApiService
              .getMyCommentedPosts();

      if (result["success"] != true) {
        throw Exception(
          result["message"] ??
              "Unable to load commented posts",
        );
      }

      final rawPosts =
          result["data"]?["posts"];

      final List<Map<String, dynamic>>
          posts = [];

      if (rawPosts is List) {
        for (final raw in rawPosts) {
          if (raw is Map) {
            posts.add(
              Map<String, dynamic>.from(
                raw,
              ),
            );
          }
        }
      }

      return posts;
    } catch (error) {
      debugPrint(
        "Load Commented Posts Error: $error",
      );

      return [];
    }
  }

  // ============================================================
  // BUILD ACTIVE TAB
  // ============================================================

  Widget _buildActivityTab() {
    if (_activeTab == 3) {
      return FutureBuilder<
          List<Map<String, dynamic>>>(
        future: _loadCommentedPosts(),
        builder:
            (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Padding(
              padding:
                  EdgeInsets.all(40),
              child: Center(
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            );
          }

          final posts =
              snapshot.data ?? [];

          return _buildPostList(
            posts,
            emptyTitle:
                "No comments yet",
            emptySubtitle:
                "Posts you comment on will appear here.",
          );
        },
      );
    }

    List<Map<String, dynamic>> posts;

    switch (_activeTab) {
      case 1:
        posts = _profileReposts;
        break;

      case 2:
        posts = _profileLikes;
        break;

      case 0:
      default:
        posts = _profilePosts;
        break;
    }

    if (_isLoadingPosts || !_postsLoaded) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      );
    }

    return _buildPostList(
      posts,
      emptyTitle: _activeTab == 0
          ? "No posts yet"
          : _activeTab == 1
              ? "No reposts yet"
              : "No liked posts yet",
      emptySubtitle:
          _activeTab == 0
              ? "Your posts will appear here."
              : _activeTab == 1
                  ? "Your reposts will appear here."
                  : "Posts you like will appear here.",
    );
  }

  // ============================================================
  // POST LIST
  // ============================================================

  Widget _buildPostList(
    List<Map<String, dynamic>> posts, {
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    if (posts.isEmpty) {
      return Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 28,
          vertical: 45,
        ),
        child: Column(
          children: [
            Icon(
              _activeTab == 0
                  ? CupertinoIcons
                      .doc_text
                  : _activeTab == 1
                      ? CupertinoIcons
                          .arrow_2_squarepath
                      : _activeTab == 2
                          ? CupertinoIcons
                              .heart
                          : CupertinoIcons
                              .bubble_left,
              size: 34,
              color: _muted,
            ),
            const SizedBox(
              height: 14,
            ),
            Text(
              emptyTitle,
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: _text,
                fontSize: 18,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 6,
            ),
            Text(
              emptySubtitle,
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: posts.map(
        (post) {
          return _buildPostCard(
            post,
          );
        },
      ).toList(),
    );
  }

  // ============================================================
  // POST CARD
  // ============================================================

  Widget _buildPostCard(
    Map<String, dynamic> post,
  ) {
    final authorRaw =
        post["author"];

    final author =
        authorRaw is Map
            ? Map<String, dynamic>.from(
                authorRaw,
              )
            : <String, dynamic>{};

    final displayName =
        author["displayName"]
                ?.toString()
                .trim()
                .isNotEmpty ==
            true
            ? author["displayName"]
                .toString()
            : author["username"]
                    ?.toString() ??
                "User";

    final username =
        author["username"]
                ?.toString() ??
            "user";

    final content =
        post["content"]
                ?.toString() ??
            "";

    final image =
        post["image"]
                ?.toString()
                .trim() ??
            "";

    final postId =
        post["_id"]?.toString() ??
            "";

    final likeCount =
        post["likesCount"] is num
            ? (post["likesCount"]
                    as num)
                .toInt()
            : post["likes"] is List
                ? (post["likes"]
                        as List)
                    .length
                : 0;

    final commentCount =
        post["commentsCount"]
                is num
            ? (post["commentsCount"]
                    as num)
                .toInt()
            : 0;

    final repostCount =
        post["repostsCount"]
                is num
            ? (post["repostsCount"]
                    as num)
                .toInt()
            : 0;

    final liked =
        post["likedByMe"] == true ||
            _containsId(
              post["likes"],
              _userId,
            );

    final isRepost =
        post["repostOf"] != null;

    final repostOf =
        post["repostOf"];

    final authorId =
        authorRaw is Map
            ? (authorRaw["_id"] ??
                    authorRaw["id"])
                ?.toString()
            : authorRaw?.toString();

    final isMine = authorId != null &&
        authorId.isNotEmpty &&
        authorId == _userId;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        12,
      ),
      decoration:
          BoxDecoration(
        color: _surface,
        border: Border(
          bottom: BorderSide(
            color: _divider,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          if (isRepost)
            Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 8,
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons
                        .arrow_2_squarepath,
                    size: 15,
                    color: _muted,
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Text(
                    "Reposted",
                    style:
                        TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildSmallAvatar(
                author,
              ),
              const SizedBox(
                width: 10,
              ),
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
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                TextStyle(
                              color:
                                  _text,
                              fontSize:
                                  14,
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Flexible(
                          child: Text(
                            "@$username",
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                TextStyle(
                              color:
                                  _muted,
                              fontSize:
                                  13,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Text(
                          "· ${_timeAgo(post["createdAt"])}",
                          style:
                              TextStyle(
                            color:
                                _muted,
                            fontSize:
                                12,
                          ),
                        ),
                        const Spacer(),
                        if (isMine)
                          GestureDetector(
                            behavior:
                                HitTestBehavior
                                    .opaque,
                            onTap: () =>
                                _confirmDeletePost(
                              postId,
                              isRepost:
                                  isRepost,
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets
                                      .only(
                                left: 8,
                                bottom: 2,
                              ),
                              child: Icon(
                                CupertinoIcons
                                    .ellipsis,
                                size: 20,
                                color:
                                    _muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (content
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 6,
                      ),
                      Text(
                        content,
                        style:
                            TextStyle(
                          color:
                              _text,
                          fontSize:
                              15.5,
                          height:
                              1.42,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          if (image.isNotEmpty) ...[
            const SizedBox(
              height: 12,
            ),
            _buildPostImage(
              image,
            ),
          ],

          if (repostOf
              is Map) ...[
            const SizedBox(
              height: 10,
            ),
            _buildQuotedPost(
              Map<String,
                  dynamic>.from(
                repostOf,
              ),
            ),
          ],

          const SizedBox(
            height: 8,
          ),

          Row(
            children: [
              _postAction(
                icon: liked
                    ? CupertinoIcons
                        .heart_fill
                    : CupertinoIcons
                        .heart,
                count:
                    likeCount,
                color: liked
                    ? _likeColor
                    : _muted,
                onTap: () =>
                    _toggleLike(
                  postId,
                ),
              ),
              _postAction(
                icon:
                    CupertinoIcons
                        .bubble_left,
                count:
                    commentCount,
                onTap: () =>
                    _openComments(
                  postId,
                ),
              ),
              _postAction(
                icon:
                    CupertinoIcons
                        .arrow_2_squarepath,
                count:
                    repostCount,
                onTap: null,
              ),
              _postAction(
                // Same share icon used on the home feed, for
                // visual consistency across screens.
                icon:
                    CupertinoIcons
                        .share,
                count: null,
                onTap: () =>
                    _sharePost(
                  post,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DELETE POST / REPOST
  // ============================================================

  Future<void> _confirmDeletePost(
    String postId, {
    required bool isRepost,
  }) async {
    if (postId.isEmpty) return;

    final label =
        isRepost ? "repost" : "post";

    final action =
        await showModalBottomSheet<
            bool>(
      context: context,
      backgroundColor: _surface,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              24,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  "Delete $label?",
                  style: TextStyle(
                    color: _text,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Text(
                  isRepost
                      ? "This repost will be removed from your profile and the home feed."
                      : "This post will be removed from your profile and the home feed, along with its comments and any reposts of it.",
                  style: TextStyle(
                    color: _muted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                Row(
                  children: [
                    Expanded(
                      child:
                          OutlinedButton(
                        onPressed: () =>
                            Navigator.pop(
                          sheetContext,
                          false,
                        ),
                        child: Text(
                          "Cancel",
                          style:
                              TextStyle(
                            color: _text,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child:
                          ElevatedButton(
                        style: ElevatedButton
                            .styleFrom(
                          backgroundColor:
                              Colors
                                  .redAccent,
                          foregroundColor:
                              Colors
                                  .white,
                        ),
                        onPressed: () =>
                            Navigator.pop(
                          sheetContext,
                          true,
                        ),
                        child:
                            const Text(
                          "Delete",
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action != true || !mounted) {
      return;
    }

    try {
      final result =
          await ApiService.deletePost(
        postId: postId,
      );

      if (result["success"] != true) {
        throw Exception(
          result["message"] ??
              "Unable to delete $label",
        );
      }

      final deleted = <String>{postId};

      final ids =
          result["data"]?["deletedIds"];

      if (ids is List) {
        deleted.addAll(
          ids.map((e) => e.toString()),
        );
      }

      if (!mounted) return;

      setState(() {
        _allPosts.removeWhere(
          (p) => deleted.contains(
            p["_id"]?.toString(),
          ),
        );
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          content: Text(
            "${label[0].toUpperCase()}${label.substring(1)} deleted",
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          content: Text(
            error
                .toString()
                .replaceFirst(
                  "Exception: ",
                  "",
                ),
          ),
        ),
      );
    }
  }

  // ============================================================
  // QUOTED REPOST
  // ============================================================

  Widget _buildQuotedPost(
    Map<String, dynamic> post,
  ) {
    final authorRaw =
        post["author"];

    final author =
        authorRaw is Map
            ? Map<String, dynamic>.from(
                authorRaw,
              )
            : <String, dynamic>{};

    final name =
        author["displayName"]
                ?.toString() ??
            author["username"]
                ?.toString() ??
            "User";

    final username =
        author["username"]
                ?.toString() ??
            "user";

    final content =
        post["content"]
                ?.toString() ??
            "";

    final image =
        post["image"]
                ?.toString()
                .trim() ??
            "";

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        border: Border.all(
          color: _divider,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSmallAvatar(
                author,
                28,
              ),
              const SizedBox(
                width: 8,
              ),
              Expanded(
                child: Text(
                  "$name  @$username",
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      TextStyle(
                    color: _text,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (content
              .trim()
              .isNotEmpty) ...[
            const SizedBox(
              height: 8,
            ),
            Text(
              content,
              maxLines: 5,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  TextStyle(
                color: _text,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ],
          if (image.isNotEmpty) ...[
            const SizedBox(
              height: 9,
            ),
            _buildPostImage(
              image,
              height: 190,
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // POST IMAGE
  // ============================================================

  Widget _buildPostImage(
    String value, {
    double height = 260,
  }) {
    if (value.startsWith(
      "data:image/",
    )) {
      final bytes =
          ApiService.dataUrlToBytes(
        value,
      );

      if (bytes != null) {
        return ClipRRect(
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          child: Image.memory(
            Uint8List.fromList(
              bytes,
            ),
            width: double.infinity,
            height: height,
            fit: BoxFit.cover,
            errorBuilder:
                (_, __, ___) =>
                    _imageError(),
          ),
        );
      }
    }

    final normalized =
        ApiService.normalizeImageUrl(
      value,
    );

    if (normalized != null) {
      return ClipRRect(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        child: Image.network(
          normalized,
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) =>
                  _imageError(),
        ),
      );
    }

    return _imageError();
  }

  Widget _imageError() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration:
          BoxDecoration(
        color: _secondarySurface,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: Icon(
        CupertinoIcons
            .photo,
        color: _muted,
        size: 32,
      ),
    );
  }

  // ============================================================
  // POST ACTION
  // ============================================================

  Widget _postAction({
    required IconData icon,
    required int? count,
    required VoidCallback? onTap,
    Color? color,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior:
            HitTestBehavior.opaque,
        child: Padding(
          padding:
              const EdgeInsets
                  .symmetric(
            vertical: 6,
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .start,
            children: [
              Icon(
                icon,
                size: 19,
                color:
                    color ?? _muted,
              ),
              if (count != null &&
                  count > 0) ...[
                const SizedBox(
                  width: 5,
                ),
                Text(
                  count.toString(),
                  style:
                      TextStyle(
                    color:
                        color ?? _muted,
                    fontSize: 12,
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
  // LIKE
  // ============================================================

  Future<void> _toggleLike(
    String postId,
  ) async {
    if (postId.isEmpty) {
      return;
    }

    try {
      final result =
          await ApiService.toggleLike(
        postId: postId,
      );

      if (!mounted) return;

      if (result["success"] == true) {
        await _loadAllPosts(
          force: true,
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              result["message"] ??
                  "Unable to update like",
            ),
          ),
        );
      }
    } catch (error) {
      debugPrint(
        "Toggle Like Error: $error",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "Unable to update like",
          ),
        ),
      );
    }
  }

  // ============================================================
  // COMMENTS
  // ============================================================

  Future<void> _openComments(
    String postId,
  ) async {
    if (postId.isEmpty) {
      return;
    }

    final controller =
        TextEditingController();

    List<dynamic> comments = [];

    bool loading = true;
    bool sending = false;

    try {
      final result =
          await ApiService.getComments(
        postId: postId,
      );

      if (result["success"] == true) {
        final raw =
            result["data"]?["comments"];

        if (raw is List) {
          comments =
              List<dynamic>.from(
            raw,
          );
        }
      }
    } catch (error) {
      debugPrint(
        "Get Comments Error: $error",
      );
    }

    loading = false;

    if (!mounted) {
      controller.dispose();
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _background,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
            context,
            setModalState,
          ) {
            Future<void>
                sendComment() async {
              final text =
                  controller.text
                      .trim();

              if (text.isEmpty ||
                  sending) {
                return;
              }

              setModalState(() {
                sending = true;
              });

              try {
                final result =
                    await ApiService
                        .createComment(
                  postId: postId,
                  content: text,
                );

                if (result["success"] ==
                    true) {
                  final comment =
                      result["data"]
                          ?["comment"];

                  if (comment !=
                      null) {
                    setModalState(() {
                      comments.add(
                        comment,
                      );

                      controller.clear();
                    });
                  }
                } else {
                  ScaffoldMessenger.of(
                    sheetContext,
                  ).showSnackBar(
                    SnackBar(
                      content: Text(
                        result[
                                "message"] ??
                            "Unable to add comment",
                      ),
                    ),
                  );
                }
              } catch (error) {
                debugPrint(
                  "Create Comment Error: $error",
                );

                if (!sheetContext
                    .mounted) {
                  return;
                }

                ScaffoldMessenger.of(
                  sheetContext,
                ).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Unable to add comment",
                    ),
                  ),
                );
              } finally {
                if (sheetContext
                    .mounted) {
                  setModalState(() {
                    sending = false;
                  });
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding:
                    EdgeInsets.only(
                  bottom:
                      MediaQuery.of(
                    sheetContext,
                  ).viewInsets.bottom,
                ),
                child: SizedBox(
                  height:
                      MediaQuery.of(
                            sheetContext,
                          ).size.height *
                          0.78,
                  child: Column(
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets
                                .fromLTRB(
                          18,
                          14,
                          10,
                          12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Comments",
                                style:
                                    TextStyle(
                                  color:
                                      _text,
                                  fontSize:
                                      20,
                                  fontWeight:
                                      FontWeight
                                          .w800,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed:
                                  () {
                                Navigator.pop(
                                  sheetContext,
                                );
                              },
                              icon:
                                  Icon(
                                CupertinoIcons
                                    .xmark,
                                color:
                                    _text,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        color:
                            _divider,
                      ),
                      Expanded(
                        child: loading
                            ? Center(
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                  color:
                                      _text,
                                ),
                              )
                            : comments
                                    .isEmpty
                                ? Center(
                                    child:
                                        Text(
                                      "No comments yet.\nBe the first to comment.",
                                      textAlign:
                                          TextAlign
                                              .center,
                                      style:
                                          TextStyle(
                                        color:
                                            _muted,
                                        fontSize:
                                            14,
                                      ),
                                    ),
                                  )
                                : ListView
                                    .builder(
                                    padding:
                                        const EdgeInsets
                                            .all(
                                      16,
                                    ),
                                    itemCount:
                                        comments
                                            .length,
                                    itemBuilder:
                                        (
                                      context,
                                      index,
                                    ) {
                                      final raw =
                                          comments[
                                              index];

                                      if (raw
                                          is! Map) {
                                        return const SizedBox
                                            .shrink();
                                      }

                                      final comment =
                                          Map<String,
                                              dynamic>.from(
                                        raw,
                                      );

                                      final author =
                                          comment[
                                              "author"];

                                      final username =
                                          author
                                                  is Map
                                              ? author[
                                                      "username"]
                                                  ?.toString() ??
                                                  "User"
                                              : "User";

                                      final content =
                                          comment[
                                                  "content"]
                                              ?.toString() ??
                                              "";

                                      return Padding(
                                        padding:
                                            const EdgeInsets
                                                .only(
                                          bottom:
                                              14,
                                        ),
                                        child:
                                            Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start,
                                          children: [
                                            _buildSmallAvatar(
                                              author
                                                      is Map
                                                  ? Map<String,
                                                      dynamic>.from(
                                                      author,
                                                    )
                                                  : <String,
                                                      dynamic>{},
                                              34,
                                                  
                                            ),
                                            const SizedBox(
                                              width:
                                                  10,
                                            ),
                                            Expanded(
                                              child:
                                                  Container(
                                                padding:
                                                    const EdgeInsets
                                                        .all(
                                                  12,
                                                ),
                                                decoration:
                                                    BoxDecoration(
                                                  color:
                                                      _secondarySurface,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    15,
                                                  ),
                                                ),
                                                child:
                                                    Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      username,
                                                      style:
                                                          TextStyle(
                                                        color:
                                                            _text,
                                                        fontSize:
                                                            13,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height:
                                                          5,
                                                    ),
                                                    Text(
                                                      content,
                                                      style:
                                                          TextStyle(
                                                        color:
                                                            _text,
                                                        fontSize:
                                                            14,
                                                        height:
                                                            1.35,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                      ),
                      Container(
                        padding:
                            const EdgeInsets
                                .fromLTRB(
                          14,
                          8,
                          14,
                          12,
                        ),
                        decoration:
                            BoxDecoration(
                          color: _background,
                          border:
                              Border(
                            top:
                                BorderSide(
                              color:
                                  _divider,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child:
                                  TextField(
                                controller:
                                    controller,
                                maxLength:
                                    300,
                                minLines:
                                    1,
                                maxLines:
                                    4,
                                style:
                                    TextStyle(
                                  color:
                                      _text,
                                ),
                                decoration:
                                    InputDecoration(
                                  hintText:
                                      "Write a comment...",
                                  hintStyle:
                                      TextStyle(
                                    color:
                                        _muted,
                                  ),
                                  counterText:
                                      "",
                                  filled:
                                      true,
                                  fillColor:
                                      _secondarySurface,
                                  border:
                                      OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                      22,
                                    ),
                                    borderSide:
                                        BorderSide.none,
                                  ),
                                  contentPadding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal:
                                        16,
                                    vertical:
                                        12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            GestureDetector(
                              onTap: sending
                                  ? null
                                  : sendComment,
                              child:
                                  Container(
                                width: 46,
                                height: 46,
                                decoration:
                                    BoxDecoration(
                                  color:
                                      _text,
                                  shape:
                                      BoxShape
                                          .circle,
                                ),
                                child:
                                    sending
                                        ? const Padding(
                                            padding:
                                                EdgeInsets.all(
                                              13,
                                            ),
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth:
                                                  2,
                                              color:
                                                  Colors.white,
                                            ),
                                          )
                                        : Icon(
                                            CupertinoIcons
                                                .arrow_up,
                                            color:
                                                _background,
                                          ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();

    if (_postsLoaded) {
      await _loadAllPosts(
        force: true,
      );
    }
  }

  // ============================================================
  // SHARE POST
  // ============================================================

  Future<void> _sharePost(
    Map<String, dynamic> post,
  ) async {
    final content =
        post["content"]
                ?.toString() ??
            "";

    final author =
        post["author"];

    final username =
        author is Map
            ? author["username"]
                    ?.toString() ??
                "User"
            : "User";

    final text =
        "$username on MicroBlog:\n\n"
        "$content\n\n"
        "Shared from MicroBlog";

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text.trim(),
          subject:
              "MicroBlog post",
        ),
      );
    } catch (error) {
      debugPrint(
        "Share Post Error: $error",
      );
    }
  }

  // ============================================================
  // CONTAINS ID
  // ============================================================

  bool _containsId(
    dynamic list,
    String id,
  ) {
    if (list is! List) {
      return false;
    }

    return list.any(
      (item) =>
          item?.toString() == id,
    );
  }

  // ============================================================
  // TIME AGO
  // ============================================================

  String _timeAgo(dynamic value) {
    if (value == null) {
      return "";
    }

    final date =
        DateTime.tryParse(
      value.toString(),
    );

    if (date == null) {
      return "";
    }

    final now = DateTime.now();

    final difference =
        now.difference(
      date.toLocal(),
    );

    if (difference.inSeconds <
        60) {
      return "now";
    }

    if (difference.inMinutes <
        60) {
      return "${difference.inMinutes}m";
    }

    if (difference.inHours <
        24) {
      return "${difference.inHours}h";
    }

    if (difference.inDays <
        7) {
      return "${difference.inDays}d";
    }

    if (difference.inDays <
        365) {
      return "${date.day}/${date.month}";
    }

    return "${date.day}/${date.month}/${date.year}";
  }

  // ============================================================
  // SMALL AVATAR
  // ============================================================

  Widget _buildSmallAvatar(
    [Map<String, dynamic>? user,
    double size = 40,]
  ) {
    final data =
        user ?? _user ?? {};

    final avatar =
        data["avatar"]
                ?.toString()
                .trim() ??
            "";

    final displayName =
        data["displayName"]
                ?.toString()
                .trim() ??
            data["username"]
                ?.toString()
                .trim() ??
            "U";

    String initials = "U";

    if (displayName.isNotEmpty) {
      final parts =
          displayName.split(
        RegExp(r"\s+"),
      );

      if (parts.length >= 2) {
        initials = (
          parts[0][0] +
          parts[1][0]
        ).toUpperCase();
      } else {
        initials =
            displayName[0]
                .toUpperCase();
      }
    }

    Widget fallback() {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: _secondarySurface,
    ),
    alignment: Alignment.center,
    child: Text(
      initials,
      style: TextStyle(
        color: _text,
        fontSize: size * .32,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

    if (avatar.startsWith(
      "data:image/",
    )) {
      final bytes =
          ApiService.dataUrlToBytes(
        avatar,
      );

      if (bytes != null) {
        return ClipOval(
          child: Image.memory(
            Uint8List.fromList(
              bytes,
            ),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder:
                (_, __, ___) =>
                    fallback(),
          ),
        );
      }
    }

    if (avatar.isNotEmpty) {
      final normalized =
          ApiService.normalizeImageUrl(
        avatar,
      );

      if (normalized != null) {
        return ClipOval(
          child: Image.network(
            normalized,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder:
                (_, __, ___) =>
                    fallback(),
          ),
        );
      }
    }

    return fallback();
  }

  // ============================================================
  // PROFILE IMAGE
  // ============================================================

  Widget _buildProfileImage({
    double size = 112,
  }) {
    Widget wrap(
      Widget child,
    ) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipOval(
              child: child,
            ),
            if (_uploadingAvatar)
              ClipOval(
                child:
                    Container(
                  color: Colors.black
                      .withOpacity(
                    .45,
                  ),
                  child:
                      const Center(
                    child:
                        SizedBox(
                      width: 24,
                      height: 24,
                      child:
                          CircularProgressIndicator(
                        strokeWidth:
                            2.4,
                        color:
                            Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (_pendingProfilePhoto !=
        null) {
      return wrap(
        Image.file(
          _pendingProfilePhoto!,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) =>
                  _buildInitialAvatar(
            size,
          ),
        ),
      );
    }

    final avatar =
        _user?["avatar"]
                ?.toString()
                .trim() ??
            "";

    if (avatar.startsWith(
      "data:image/",
    )) {
      final bytes =
          ApiService.dataUrlToBytes(
        avatar,
      );

      if (bytes != null) {
        return wrap(
          Image.memory(
            Uint8List.fromList(
              bytes,
            ),
            fit: BoxFit.cover,
            errorBuilder:
                (_, __, ___) =>
                    _buildInitialAvatar(
              size,
            ),
          ),
        );
      }
    }

    if (avatar.isNotEmpty) {
      final normalized =
          ApiService.normalizeImageUrl(
        avatar,
      );

      if (normalized != null) {
        return wrap(
          Image.network(
            normalized,
            fit: BoxFit.cover,
            errorBuilder:
                (_, __, ___) =>
                    _buildInitialAvatar(
              size,
            ),
          ),
        );
      }
    }

    return _buildInitialAvatar(
      size,
    );
  }

  // ============================================================
  // INITIAL AVATAR
  // ============================================================

  Widget _buildInitialAvatar(
    double size,
  ) {
    return Container(
      width: size,
      height: size,
      color: _secondarySurface,
      alignment:
          Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: _text,
          fontSize:
              size * .30,
          fontWeight:
              FontWeight.w800,
        ),
      ),
    );
  }

  // ============================================================
  // COVER PHOTO
  // ============================================================

  Widget _buildCoverPhoto() {
    Widget image;

    if (_pendingCoverPhoto !=
        null) {
      image = Image.file(
        _pendingCoverPhoto!,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) =>
                _defaultCover(),
      );
    } else {
      final cover =
          _user?["coverPhoto"]
                  ?.toString()
                  .trim() ??
              "";

      if (cover.startsWith(
        "data:image/",
      )) {
        final bytes =
            ApiService.dataUrlToBytes(
          cover,
        );

        image = bytes != null
            ? Image.memory(
                Uint8List.fromList(
                  bytes,
                ),
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) =>
                        _defaultCover(),
              )
            : _defaultCover();
      } else if (cover.isNotEmpty) {
        final normalized =
            ApiService.normalizeImageUrl(
          cover,
        );

        image = normalized !=
                null
            ? Image.network(
                normalized,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) =>
                        _defaultCover(),
              )
            : _defaultCover();
      } else {
        image = _defaultCover();
      }
    }

    return SizedBox(
      width: double.infinity,
      height: 190,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () =>
                _openPhotoViewer(
              isAvatar: false,
            ),
            child: image,
          ),
          if (_uploadingCover)
            Container(
              color: Colors.black
                  .withOpacity(
                .45,
              ),
              child:
                  const Center(
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color:
                      Colors.white,
                ),
              ),
            ),
          Positioned(
            right: 14,
            bottom: 14,
            child:
                _circleButton(
              icon: CupertinoIcons
                  .camera,
              onTap:
                  _pickCoverPhoto,
              background:
                  Colors.black
                      .withOpacity(
                .72,
              ),
              foreground:
                  Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultCover() {
    return Container(
      decoration:
          BoxDecoration(
        color: _secondarySurface,
        gradient:
            LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            _secondarySurface,
            _isDark
                ? const Color(
                    0xFF202327,
                  )
                : const Color(
                    0xFFE8EAED,
                  ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CIRCLE BUTTON
  // ============================================================

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color background,
    required Color foreground,
  }) {
    return Material(
      color: background,
      shape:
          const CircleBorder(),
      child: InkWell(
        customBorder:
            const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            color: foreground,
            size: 19,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE HEADER
  // ============================================================

  Widget _buildProfileHeader() {
    final rawPosts =
        _profilePosts.length;

    final rawLikes =
        _profileLikes.length;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _buildCoverPhoto(),

        // ------------------------------------------------------
        // AVATAR + EDIT PROFILE
        // ------------------------------------------------------

        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            0,
          ),
          child: Transform.translate(
            offset:
                const Offset(0, -48),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () =>
                          _openPhotoViewer(
                        isAvatar: true,
                      ),
                      child: Container(
                      width: 94,
                      height: 94,
                      padding:
                          const EdgeInsets
                              .all(
                        4,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            _background,
                        shape:
                            BoxShape.circle,
                      ),
                      child:
                          _buildProfileImage(
                        size: 86,
                      ),
                    ),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed:
                          _openEditProfile,
                      style:
                          OutlinedButton.styleFrom(
                        foregroundColor:
                            _text,
                        side: BorderSide(
                          color:
                              _divider,
                        ),
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal:
                              18,
                          vertical:
                              10,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            22,
                          ),
                        ),
                      ),
                      child:
                          const Text(
                        "Edit profile",
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 8,
                ),

                Row(
                  children: [
                    GestureDetector(
                      onTap:
                          _pickProfilePhoto,
                      child:
                          Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal:
                              10,
                          vertical:
                              6,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              _secondarySurface,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            18,
                          ),
                        ),
                        child: Row(
                          mainAxisSize:
                              MainAxisSize
                                  .min,
                          children: [
                            Icon(
                              CupertinoIcons
                                  .camera,
                              size: 15,
                              color:
                                  _text,
                            ),
                            const SizedBox(
                              width: 5,
                            ),
                            Text(
                              "Change photo",
                              style:
                                  TextStyle(
                                color:
                                    _text,
                                fontSize:
                                    12,
                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 15,
                ),

                // Name + username on a single line.
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.baseline,
                  textBaseline:
                      TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        _displayName,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            TextStyle(
                          color: _text,
                          fontSize: 20,
                          fontWeight:
                              FontWeight.w900,
                          letterSpacing:
                              -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    Flexible(
                      child: Text(
                        "@$_username",
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            TextStyle(
                          color: _muted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),

                if (_bio.isNotEmpty) ...[
                  const SizedBox(
                    height: 12,
                  ),
                  Text(
                    _bio,
                    style:
                        TextStyle(
                      color: _text,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],

                // Location + DOB on one line.
                if (_location.isNotEmpty ||
                    _dobText.isNotEmpty) ...[
                  const SizedBox(
                    height: 10,
                  ),
                  Wrap(
                    spacing: 16,
                    runSpacing: 7,
                    children: [
                      if (_location
                          .isNotEmpty)
                        _profileMeta(
                          CupertinoIcons
                              .location_solid,
                          _location,
                        ),
                      if (_dobText
                          .isNotEmpty)
                        _profileMeta(
                          Icons
                              .cake_rounded,
                          _dobText,
                        ),
                    ],
                  ),
                ],

                // Joined date.
                const SizedBox(
                  height: 8,
                ),
                _profileMeta(
                  Icons
                      .calendar_month_rounded,
                  _formatJoinedDate(),
                ),

                // Link / website.
                if (_website.isNotEmpty) ...[
                  const SizedBox(
                    height: 8,
                  ),
                  _profileMeta(
                    Icons.link_rounded,
                    _website,
                  ),
                ],

                const SizedBox(
                  height: 14,
                ),

                Row(
                  children: [
                    _countText(
                      _followingCount,
                      "Following",
                    ),
                    const SizedBox(
                      width: 20,
                    ),
                    _countText(
                      _followersCount,
                      "Followers",
                    ),
                  ],
                ),

                const SizedBox(
                  height: 18,
                ),

                // ------------------------------------------------
                // TAB BAR
                // ------------------------------------------------

                Container(
                  decoration:
                      BoxDecoration(
                    border: Border(
                      bottom:
                          BorderSide(
                        color:
                            _divider,
                      ),
                    ),
                  ),
                  child: TabBar(
                    controller:
                        _tabController,
                    isScrollable:
                        false,
                    labelColor:
                        _text,
                    unselectedLabelColor:
                        _muted,
                    indicatorColor:
                        _text,
                    indicatorWeight:
                        3,
                    dividerColor:
                        Colors.transparent,
                    tabs: const [
                      Tab(
                        icon: Icon(
                          CupertinoIcons
                              .doc_text,
                          size: 20,
                        ),
                      ),
                      Tab(
                        icon: Icon(
                          CupertinoIcons
                              .arrow_2_squarepath,
                          size: 20,
                        ),
                      ),
                      Tab(
                        icon: Icon(
                          CupertinoIcons
                              .heart,
                          size: 20,
                        ),
                      ),
                      Tab(
                        icon: Icon(
                          CupertinoIcons
                              .bubble_left,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileMeta(
    IconData icon,
    String value,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: _text.withOpacity(.78),
        ),
        const SizedBox(
          width: 6,
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                TextStyle(
              color: _muted,
              fontSize: 13.5,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _countText(
    int count,
    String label,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style:
              TextStyle(
            color: _text,
            fontSize: 14,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        const SizedBox(
          width: 4,
        ),
        Text(
          label,
          style:
              TextStyle(
            color: _muted,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ACCOUNT INFORMATION
  // ============================================================

  Widget _buildAccountSection() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        20,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const SizedBox(
            height: 18,
          ),
          if (_email
              .isNotEmpty)
            _accountRow(
              CupertinoIcons.mail,
              "Email",
              trailing: _email,
            ),
        ],
      ),
    );
  }

  Widget _accountRow(
    IconData icon,
    String title, {
    String? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior:
          HitTestBehavior.opaque,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          vertical: 12,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: _muted,
              size: 20,
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: Text(
                title,
                style:
                    TextStyle(
                  color: _text,
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style:
                    TextStyle(
                  color: _muted,
                  fontSize: 13,
                ),
              ),
            if (onTap != null)
              Icon(
                CupertinoIcons
                    .chevron_right,
                color: _muted,
                size: 17,
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
      backgroundColor: _background,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      title: Text(
        _displayName.isNotEmpty ? _displayName : "Profile",
        style: TextStyle(
          color: _text,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    body: _isLoading
        ? Center(
            child: CircularProgressIndicator(
              color: _text,
            ),
          )
        : RefreshIndicator(
            color: _text,
            backgroundColor: _surface,
            onRefresh: _refreshProfile,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildProfileHeader(),
                ),
                SliverToBoxAdapter(
                  child: _buildActivityTab(),
                ),
                SliverToBoxAdapter(
                  child: _buildAccountSection(),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 30),
                ),
              ],
            ),
          ),
  );
}
}