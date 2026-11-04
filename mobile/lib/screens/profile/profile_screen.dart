import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../home/home_video_player.dart';
import 'edit_profile_screen.dart';
import 'follow_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // COLORS (same palette as the home / create post screens)
  // ============================================================

  static const Color _accent = Color(0xFFF91880);
  static const Color _linkColor = Color(0xFF2563EB);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _background =>
      _isDark ? const Color(0xFF08090B) : const Color(0xFFF7F8FA);

  Color get _surface =>
      _isDark ? const Color(0xFF15171B) : const Color(0xFFFFFFFF);

  Color get _secondarySurface =>
      _isDark ? const Color(0xFF202329) : const Color(0xFFF0F1F4);

  Color get _text =>
      _isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111318);

  Color get _muted =>
      _isDark ? const Color(0xFF9297A0) : const Color(0xFF737B86);

  Color get _divider =>
      _isDark ? const Color(0xFF282B31) : const Color(0xFFE6E8EC);

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = true;
  bool _isLoadingPosts = false;

  Map<String, dynamic>? _user;

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

  List<Map<String, dynamic>>? _commentedPosts;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        return;
      }

      if (!mounted) return;

      setState(() {
        _activeTab = _tabController.index;

      });

      if (_activeTab == 3 && _commentedPosts == null) {
        _reloadCommented();
      }

      _loadPostsIfNeeded();
    });

    _loadProfile();

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
  // ICON HELPERS (bold icons, same style as the home screen)
  // ============================================================

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

  String _formatCount(int value) {
    if (value < 1000) {
      return value < 0 ? '0' : value.toString();
    }

    if (value > 10000000) {
      return '10M+';
    }

    if (value >= 10000000) {
      return '10M';
    }

    if (value >= 1000000) {
      final number = value / 1000000;

      return '${number.toStringAsFixed(number == number.roundToDouble() ? 0 : 1)}M';
    }

    final number = value / 1000;

    return '${number.toStringAsFixed(number >= 100 || number == number.roundToDouble() ? 0 : 1)}K';
  }

  void _snack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  // ============================================================
  // LOAD PROFILE
  // ============================================================

  Future<void> _loadProfile() async {
    if (mounted && _user == null) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final result = await ApiService.getMe();

      Map<String, dynamic>? user;

      if (result['success'] == true &&
          result['data'] is Map &&
          result['data']['user'] is Map) {
        user = Map<String, dynamic>.from(result['data']['user']);
      }

      if (!mounted) return;

      setState(() {
        _user = user ?? _user;

        _followersCount = _readCount(
          user?['followersCount'],
          user?['followers'],
        );

        _followingCount = _readCount(
          user?['followingCount'],
          user?['following'],
        );

        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Load Profile Error: $error');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _snack(
        error.toString().contains('Authentication token')
            ? 'Please login again'
            : 'Unable to load profile',
      );
    }
  }

  int _readCount(dynamic primary, dynamic fallback) {
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

  Future<void> _refreshProfile() async {
    await _loadProfile();

    if (_postsLoaded) {
      await _loadAllPosts(force: true);
    }

    if (_activeTab == 3 && mounted) {
      await _reloadCommented();
    }
  }

  Future<void> _reloadCommented() async {
    final posts = await _loadCommentedPosts();

    if (!mounted) return;

    setState(() {
      _commentedPosts = posts;
    });
  }

  // ============================================================
  // BASIC USER DATA
  // ============================================================

  String get _username {
    final value = _user?['username']?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }

    return 'User';
  }

  String get _displayName {
    final value = _user?['displayName']?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }

    return _username;
  }

  String get _email => _user?['email']?.toString() ?? '';

  String get _bio => _user?['bio']?.toString().trim() ?? '';

  String get _location => _user?['location']?.toString().trim() ?? '';

  String get _website => _user?['website']?.toString().trim() ?? '';

  String get _userId =>
      _user?['_id']?.toString() ?? _user?['id']?.toString() ?? '';

  String get _dobText {
    final raw = (_user?['dateOfBirth'] ?? _user?['dob'])?.toString().trim();

    if (raw == null || raw.isEmpty) {
      return '';
    }

    final date = DateTime.tryParse(raw)?.toLocal();

    if (date == null) return '';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String get _initials {
    final name = _displayName.trim();

    if (name.isEmpty) {
      return 'U';
    }

    final parts = name.split(RegExp(r'\s+'));

    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }

    return name[0].toUpperCase();
  }

  String _formatJoinedDate() {
    final createdAt = _user?['createdAt'];

    if (createdAt == null) {
      return 'MicroBlog member';
    }

    final date = DateTime.tryParse(createdAt.toString());

    if (date == null) {
      return 'MicroBlog member';
    }

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return 'Joined ${months[date.month - 1]} ${date.year}';
  }

  // ============================================================
  // LOST IMAGE PICKER DATA
  // ============================================================

  Future<void> _recoverLostPickerData() async {
    try {
      final response = await _imagePicker.retrieveLostData();

      if (response.isEmpty) {
        return;
      }

      final files = response.files;

      if (files == null || files.isEmpty) {
        return;
      }

      await _processSelectedImage(files.first, isAvatar: true);
    } catch (error) {
      debugPrint('Recover Lost Picker Data Error: $error');
    }
  }

  // ============================================================
  // PICK PHOTOS
  // ============================================================

  Future<void> _pickProfilePhoto() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 2000,
      );

      if (pickedFile == null) {
        return;
      }

      await _processSelectedImage(pickedFile, isAvatar: true);
    } catch (error) {
      debugPrint('Pick Profile Photo Error: $error');

      _snack('Unable to select profile photo');
    }
  }

  Future<void> _pickCoverPhoto() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 2500,
      );

      if (pickedFile == null) {
        return;
      }

      await _processSelectedImage(pickedFile, isAvatar: false);
    } catch (error) {
      debugPrint('Pick Cover Photo Error: $error');

      _snack('Unable to select cover photo');
    }
  }

  // ============================================================
  // CROP SELECTED IMAGE
  // ============================================================

  Future<File?> _cropImage(XFile pickedFile, {required bool isAvatar}) async {
    try {
      final CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        compressQuality: 90,
        maxWidth: isAvatar ? 1200 : 2000,
        maxHeight: isAvatar ? 1200 : 1000,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: isAvatar ? 'Crop profile photo' : 'Crop cover photo',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: _accent,
            initAspectRatio: isAvatar
                ? CropAspectRatioPreset.square
                : CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: isAvatar ? 'Crop profile photo' : 'Crop cover photo',
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
      debugPrint('Crop Image Error: $error');

      _snack('Unable to crop this photo');

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
    final croppedFile = await _cropImage(pickedFile, isAvatar: isAvatar);

    if (croppedFile == null) {
      return;
    }

    if (!mounted) return;

    setState(() {
      if (isAvatar) {
        _pendingProfilePhoto = croppedFile;
        _uploadingAvatar = true;
      } else {
        _pendingCoverPhoto = croppedFile;
        _uploadingCover = true;
      }
    });

    try {
      final dataUrl = await ApiService.fileToDataUrl(croppedFile);

      final result = isAvatar
          ? await ApiService.updateProfile(avatar: dataUrl)
          : await ApiService.updateProfile(coverPhoto: dataUrl);

      if (!mounted) return;

      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Unable to update photo');
      }

      final updatedUser =
          result['data'] is Map && result['data']['user'] is Map
              ? Map<String, dynamic>.from(result['data']['user'])
              : null;

      setState(() {
        if (updatedUser != null) {
          _user = updatedUser;
        } else {
          _user = {
            ...?_user,
            if (isAvatar) 'avatar': dataUrl else 'coverPhoto': dataUrl,
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

      await _askSharePhotoToFeed(dataUrl: dataUrl, isAvatar: isAvatar);
    } catch (error) {
      debugPrint('Upload Profile Photo Error: $error');

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

      _snack(_cleanError(error));
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share to feed?',
                  style: TextStyle(
                    color: _text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isAvatar
                      ? 'Would you like to share your new profile photo with your followers?'
                      : 'Would you like to share your new cover photo with your followers?',
                  style: TextStyle(color: _muted, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _text,
                          side: BorderSide(color: _divider),
                        ),
                        child: const Text('Not now'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Share'),
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

    await Future<void>.delayed(const Duration(milliseconds: 200));

    if (!mounted) return;

    await _showPhotoCaptionDialog(dataUrl: dataUrl, isAvatar: isAvatar);
  }

  Future<void> _showPhotoCaptionDialog({
    required String dataUrl,
    required bool isAvatar,
  }) async {
    final controller = TextEditingController(
      text: isAvatar
          ? 'I updated my profile photo.'
          : 'I updated my cover photo.',
    );

    final caption = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _surface,
          title: Text(
            'Share to feed',
            style: TextStyle(color: _text, fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            maxLength: 500,
            cursorColor: _accent,
            style: TextStyle(color: _text),
            decoration: InputDecoration(
              hintText: 'Write a caption...',
              hintStyle: TextStyle(color: _muted),
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
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: _muted)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
              ),
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Post'),
            ),
          ],
        );
      },
    );

    // Do not dispose immediately: the dialog may still be closing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

    if (caption == null || !mounted) {
      return;
    }

    await _publishPhotoToFeed(caption: caption.trim(), dataUrl: dataUrl);
  }

  Future<void> _publishPhotoToFeed({
    required String caption,
    required String dataUrl,
  }) async {
    try {
      final result = await ApiService.createPost(
        content: caption,
        image: dataUrl,
      );

      if (!mounted) return;

      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Unable to share photo');
      }

      _snack('Photo shared to your feed');

      if (_postsLoaded) {
        await _loadAllPosts(force: true);
      }
    } catch (error) {
      debugPrint('Share Profile Photo Error: $error');

      _snack(_cleanError(error));
    }
  }

  // ============================================================
  // EDIT PROFILE
  // ============================================================

  Future<void> _openEditProfile() async {
    final updatedUser = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: _user ?? {})),
    );

    if (!mounted) {
      return;
    }

    if (updatedUser is Map) {
      final map = Map<String, dynamic>.from(updatedUser);

      setState(() {
        _user = map['user'] is Map
            ? Map<String, dynamic>.from(map['user'])
            : map;
      });
    }

    await _loadProfile();
  }

  // ============================================================
  // FOLLOWERS / FOLLOWING LISTS
  // ============================================================

  Future<void> _openConnections({required bool followers}) async {
    if (_userId.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FollowListScreen(
          userId: _userId,
          followers: followers,
          myId: _userId,
        ),
      ),
    );

    if (!mounted) return;

    await _loadProfile();
  }

  // ============================================================
  // FULL SCREEN PHOTO VIEWER
  // ============================================================

  ImageProvider? _photoProvider({required bool isAvatar}) {
    final pending = isAvatar ? _pendingProfilePhoto : _pendingCoverPhoto;

    if (pending != null) {
      return FileImage(pending);
    }

    final value =
        _user?[isAvatar ? 'avatar' : 'coverPhoto']?.toString().trim() ?? '';

    if (value.isEmpty) return null;

    if (value.startsWith('data:image/')) {
      final bytes = ApiService.dataUrlToBytes(value);

      return bytes == null ? null : MemoryImage(Uint8List.fromList(bytes));
    }

    final normalized = ApiService.normalizeImageUrl(value);

    return normalized == null ? null : NetworkImage(normalized);
  }

  void _openPhotoViewer({required bool isAvatar}) {
    final provider = _photoProvider(isAvatar: isAvatar);

    if (provider == null) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image(
                  image: provider,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  // ============================================================
  // LOAD POSTS
  // ============================================================

  Future<void> _loadPostsIfNeeded() async {
    if (_postsLoaded || _isLoadingPosts) {
      return;
    }

    await _loadAllPosts();
  }

  Future<void> _loadAllPosts({bool force = false}) async {
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
      final result = await ApiService.getPosts();

      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Unable to load posts');
      }

      final rawPosts = result['data']?['posts'];

      final List<Map<String, dynamic>> parsed = [];

      if (rawPosts is List) {
        for (final raw in rawPosts) {
          if (raw is Map) {
            parsed.add(Map<String, dynamic>.from(raw));
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
      debugPrint('Load Profile Posts Error: $error');

      if (!mounted) return;

      setState(() {
        _isLoadingPosts = false;
        _postsLoaded = true;
      });

      _snack(_cleanError(error));
    }
  }

  // ============================================================
  // TAB DATA
  // ============================================================

  String _authorIdOf(Map<String, dynamic> post) {
    final author = post['author'];

    return author is Map
        ? (author['_id'] ?? author['id'])?.toString() ?? ''
        : author?.toString() ?? '';
  }

  List<Map<String, dynamic>> get _profilePosts => _allPosts
      .where((p) => _authorIdOf(p) == _userId && p['repostOf'] == null)
      .toList();

  List<Map<String, dynamic>> get _profileReposts => _allPosts
      .where((p) => _authorIdOf(p) == _userId && p['repostOf'] != null)
      .toList();

  List<Map<String, dynamic>> get _profileLikes {
    return _allPosts.where((post) {
      if (post['likedByMe'] == true) {
        return true;
      }

      final likes = post['likes'];

      if (likes is! List) {
        return false;
      }

      return likes.any((id) => id?.toString() == _userId);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _loadCommentedPosts() async {
    try {
      final result = await ApiService.getMyCommentedPosts();

      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Unable to load commented posts');
      }

      final rawPosts = result['data']?['posts'];

      final List<Map<String, dynamic>> posts = [];

      if (rawPosts is List) {
        for (final raw in rawPosts) {
          if (raw is Map) {
            posts.add(Map<String, dynamic>.from(raw));
          }
        }
      }

      return posts;
    } catch (error) {
      debugPrint('Load Commented Posts Error: $error');

      return [];
    }
  }

  // ============================================================
  // ACTIVE TAB CONTENT
  // ============================================================

  Widget _loadingBox() {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
      ),
    );
  }

  Widget _buildActivityTab() {
    if (_activeTab == 3) {
      if (_commentedPosts == null) {
        return _loadingBox();
      }

      return _buildPostList(
        _commentedPosts!,
        emptyTitle: 'No comments yet',
        emptySubtitle: 'Posts you comment on will appear here.',
      );
    }

    if (_isLoadingPosts || !_postsLoaded) {
      return _loadingBox();
    }

    final List<Map<String, dynamic>> posts;

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

    return _buildPostList(
      posts,
      emptyTitle: _activeTab == 0
          ? 'No posts yet'
          : _activeTab == 1
              ? 'No reposts yet'
              : 'No liked posts yet',
      emptySubtitle: _activeTab == 0
          ? 'Your posts will appear here.'
          : _activeTab == 1
              ? 'Your reposts will appear here.'
              : 'Posts you like will appear here.',
    );
  }

  Widget _buildPostList(
    List<Map<String, dynamic>> posts, {
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 45),
        child: Column(
          children: [
            _boldIcon(
              _activeTab == 0
                  ? CupertinoIcons.doc_text
                  : _activeTab == 1
                      ? CupertinoIcons.arrow_2_squarepath
                      : _activeTab == 2
                          ? CupertinoIcons.heart
                          : CupertinoIcons.bubble_left,
              34,
              _muted,
            ),
            const SizedBox(height: 14),
            Text(
              emptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              emptySubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      );
    }

    return Column(children: posts.map(_buildPostCard).toList());
  }

  // ============================================================
  // MEDIA (photos + videos, single or multiple)
  // ============================================================

  List<String> _mediaList(dynamic list, dynamic single) {
    final items = <String>[];

    if (list is List) {
      for (final item in list) {
        final value = item?.toString().trim() ?? '';

        if (value.isNotEmpty) items.add(value);
      }
    }

    if (items.isEmpty) {
      final value = single?.toString().trim() ?? '';

      if (value.isNotEmpty) items.add(value);
    }

    return items;
  }

  Widget _buildMedia(Map<String, dynamic> source, {double imageHeight = 260}) {
    final images = _mediaList(
      source['images'],
      source['image'] ?? source['imageUrl'] ?? source['mediaUrl'],
    );

    final videos = _mediaList(source['videos'], source['video'] ?? source['videoUrl']);

    if (images.isEmpty && videos.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxVideoHeight = MediaQuery.of(context).size.height * .6;

    Widget videoPlayer(String data) {
      return ClipRect(
        child: OverflowBox(
          minHeight: 0,
          maxHeight: double.infinity,
          alignment: Alignment.center,
          child: HomeVideoPlayer(videoData: data),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          if (images.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: images.length > 1
                  ? _MediaPager(
                      height: imageHeight + 40,
                      children: [
                        for (final item in images)
                          _buildPostImage(item, height: imageHeight + 40),
                      ],
                    )
                  : _buildPostImage(images.first, height: imageHeight),
            ),

          if (videos.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: images.isNotEmpty ? 10 : 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.black,
                  child: videos.length > 1
                      ? _MediaPager(
                          height: maxVideoHeight,
                          children: [
                            for (final item in videos)
                              Center(child: videoPlayer(item)),
                          ],
                        )
                      : ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: maxVideoHeight,
                          ),
                          child: videoPlayer(videos.first),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPostImage(String value, {double height = 260}) {
    if (value.startsWith('data:image/')) {
      final bytes = ApiService.dataUrlToBytes(value);

      if (bytes != null) {
        return Image.memory(
          Uint8List.fromList(bytes),
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _imageError(),
        );
      }
    }

    final normalized = ApiService.normalizeImageUrl(value);

    if (normalized != null) {
      return Image.network(
        normalized,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imageError(),
      );
    }

    return _imageError();
  }

  Widget _imageError() {
    return Container(
      height: 180,
      width: double.infinity,
      color: _secondarySurface,
      child: Icon(CupertinoIcons.photo, color: _muted, size: 32),
    );
  }

  // ============================================================
  // POST CARD
  // ============================================================

  Widget _buildPostCard(Map<String, dynamic> post) {
    final authorRaw = post['author'];

    final author = authorRaw is Map
        ? Map<String, dynamic>.from(authorRaw)
        : <String, dynamic>{};

    final displayName =
        author['displayName']?.toString().trim().isNotEmpty == true
            ? author['displayName'].toString()
            : author['username']?.toString() ?? 'User';

    final username = author['username']?.toString() ?? 'user';

    final content = post['content']?.toString() ?? '';

    final postId = post['_id']?.toString() ?? '';

    final likeCount = post['likesCount'] is num
        ? (post['likesCount'] as num).toInt()
        : post['likes'] is List
            ? (post['likes'] as List).length
            : 0;

    final commentCount = post['commentsCount'] is num
        ? (post['commentsCount'] as num).toInt()
        : 0;

    final repostCount = post['repostsCount'] is num
        ? (post['repostsCount'] as num).toInt()
        : 0;

    final shareCount = post['sharesCount'] is num
        ? (post['sharesCount'] as num).toInt()
        : 0;

    final liked =
        post['likedByMe'] == true || _containsId(post['likes'], _userId);

    final isRepost = post['repostOf'] != null;

    final repostOf = post['repostOf'];

    final isMine = _authorIdOf(post).isNotEmpty && _authorIdOf(post) == _userId;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _divider, width: .6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRepost)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  _boldIcon(CupertinoIcons.arrow_2_squarepath, 15, _muted),
                  const SizedBox(width: 6),
                  Text(
                    'Reposted',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

          // HEADER
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSmallAvatar(author, 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _text,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '@$username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _muted, fontSize: 13.5),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('•', style: TextStyle(color: _muted)),
                        const SizedBox(width: 6),
                        Text(
                          _timeAgo(post['createdAt']),
                          style: TextStyle(color: _muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isMine)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _confirmDeletePost(postId, isRepost: isRepost),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: _boldIcon(CupertinoIcons.ellipsis, 20, _muted),
                  ),
                ),
            ],
          ),

          // TEXT
          if (content.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              content,
              style: TextStyle(color: _text, fontSize: 15.5, height: 1.42),
            ),
          ],

          // OWN MEDIA (photos and videos). A repost shows the original's
          // media inside the reposted card below instead.
          if (!isRepost) _buildMedia(post),

          // REPOSTED POST
          if (repostOf is Map) ...[
            const SizedBox(height: 10),
            _buildQuotedPost(Map<String, dynamic>.from(repostOf)),
          ],

          const SizedBox(height: 6),

          // ACTIONS (same icons / size as the home feed)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _postAction(
                icon: liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                count: likeCount,
                color: liked ? _accent : _muted,
                onTap: () => _toggleLike(postId),
              ),
              _postAction(
                icon: CupertinoIcons.bubble_left,
                count: commentCount,
                onTap: () => _openComments(postId),
              ),
              _postAction(
                icon: CupertinoIcons.arrow_2_squarepath,
                count: repostCount,
                onTap: () => _repostPost(post),
              ),
              _postAction(
                icon: CupertinoIcons.arrowshape_turn_up_right,
                count: shareCount,
                onTap: () => _sharePost(post),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUOTED REPOST
  // ============================================================

  Widget _buildQuotedPost(Map<String, dynamic> post) {
    final authorRaw = post['author'];

    final author = authorRaw is Map
        ? Map<String, dynamic>.from(authorRaw)
        : <String, dynamic>{};

    final name =
        author['displayName']?.toString() ??
        author['username']?.toString() ??
        'User';

    final username = author['username']?.toString() ?? 'user';

    final content = post['content']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: _divider),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSmallAvatar(author, 28),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '@$username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ),
            ],
          ),
          if (content.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              content,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _text, fontSize: 14, height: 1.35),
            ),
          ],
          _buildMedia(post, imageHeight: 190),
        ],
      ),
    );
  }

  // ============================================================
  // POST ACTION (same size / bold as home)
  // ============================================================

  Widget _postAction({
    required IconData icon,
    required int count,
    required VoidCallback? onTap,
    Color? color,
  }) {
    final tint = color ?? _muted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _boldIcon(icon, 21, tint),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Text(
                _formatCount(count),
                style: TextStyle(
                  color: tint,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
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

    final label = isRepost ? 'repost' : 'post';

    final action = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete $label?',
                  style: TextStyle(
                    color: _text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isRepost
                      ? 'This repost will be removed from your profile and the home feed.'
                      : 'This post will be removed from your profile and the home feed, along with its comments and any reposts of it.',
                  style: TextStyle(color: _muted, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _text,
                          side: BorderSide(color: _divider),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(sheetContext, true),
                        child: const Text('Delete'),
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
      final result = await ApiService.deletePost(postId: postId);

      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Unable to delete $label');
      }

      final deleted = <String>{postId};

      final ids = result['data']?['deletedIds'];

      if (ids is List) {
        deleted.addAll(ids.map((e) => e.toString()));
      }

      if (!mounted) return;

      setState(() {
        _allPosts.removeWhere((p) => deleted.contains(p['_id']?.toString()));
      });

      _snack('${label[0].toUpperCase()}${label.substring(1)} deleted');
    } catch (error) {
      _snack(_cleanError(error));
    }
  }

  // ============================================================
  // LIKE
  // ============================================================

  /// Updates a post everywhere it is shown (posts, likes, comments tabs).
  void _patchPost(String postId, void Function(Map<String, dynamic>) change) {
    if (!mounted) return;

    setState(() {
      for (final list in [_allPosts, _commentedPosts ?? <Map<String, dynamic>>[]]) {
        for (final post in list) {
          if (post['_id']?.toString() == postId) {
            change(post);
          }
        }
      }
    });
  }

  Map<String, dynamic>? _findPost(String postId) {
    for (final list in [_allPosts, _commentedPosts ?? <Map<String, dynamic>>[]]) {
      for (final post in list) {
        if (post['_id']?.toString() == postId) return post;
      }
    }

    return null;
  }

  Future<void> _toggleLike(String postId) async {
    if (postId.isEmpty) {
      return;
    }

    final current = _findPost(postId);

    final wasLiked = current != null &&
        (current['likedByMe'] == true || _containsId(current['likes'], _userId));

    final oldCount = current?['likesCount'] is num
        ? (current!['likesCount'] as num).toInt()
        : current?['likes'] is List
            ? (current!['likes'] as List).length
            : 0;

    void apply(bool liked, int count) {
      _patchPost(postId, (post) {
        post['likedByMe'] = liked;
        post['likesCount'] = count < 0 ? 0 : count;

        final likes = post['likes'];

        if (likes is List) {
          likes.removeWhere((id) => id?.toString() == _userId);

          if (liked) likes.add(_userId);
        }
      });
    }

    // Update the number instantly.
    apply(!wasLiked, oldCount + (wasLiked ? -1 : 1));

    try {
      final result = await ApiService.toggleLike(postId: postId);

      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['data'];

        if (data is Map) {
          final serverCount = data['likesCount'];

          apply(
            data['liked'] == true,
            serverCount is num ? serverCount.toInt() : oldCount + (wasLiked ? -1 : 1),
          );
        }
      } else {
        apply(wasLiked, oldCount);

        _snack(result['message']?.toString() ?? 'Unable to update like');
      }
    } catch (error) {
      debugPrint('Toggle Like Error: $error');

      apply(wasLiked, oldCount);

      _snack('Unable to update like');
    }
  }

  // ============================================================
  // REPOST (tap the repost icon to repost again / undo)
  // ============================================================

  Future<void> _repostPost(Map<String, dynamic> post) async {
    final repostOf = post['repostOf'];

    final targetId = repostOf is Map
        ? repostOf['_id']?.toString() ?? ''
        : post['_id']?.toString() ?? '';

    if (targetId.isEmpty) return;

    final already = _allPosts.any((p) {
      if (_authorIdOf(p) != _userId) return false;

      final r = p['repostOf'];

      final id = r is Map ? r['_id']?.toString() : r?.toString();

      return id == targetId;
    });

    final controller = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              24 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  already ? 'Undo repost?' : 'Repost',
                  style: TextStyle(
                    color: _text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (already)
                  Text(
                    'This will remove your repost of this post.',
                    style: TextStyle(color: _muted, fontSize: 14),
                  )
                else
                  TextField(
                    controller: controller,
                    maxLength: 300,
                    maxLines: 3,
                    minLines: 1,
                    cursorColor: _accent,
                    style: TextStyle(color: _text),
                    decoration: InputDecoration(
                      hintText: 'Add a comment (optional)',
                      hintStyle: TextStyle(color: _muted),
                      counterText: '',
                      filled: true,
                      fillColor: _secondarySurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _text,
                          side: BorderSide(color: _divider),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(already ? 'Undo' : 'Repost'),
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

    final caption = controller.text.trim();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

    if (confirmed != true || !mounted) return;

    try {
      final result = await ApiService.repost(postId: targetId, caption: caption);

      if (!mounted) return;

      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Unable to repost');
      }

      _snack(already ? 'Repost removed' : 'Reposted');

      await _loadAllPosts(force: true);
    } catch (error) {
      _snack(_cleanError(error));
    }
  }

  // ============================================================
  // COMMENTS
  // ============================================================

  Future<void> _openComments(String postId) async {
    if (postId.isEmpty) {
      return;
    }

    final controller = TextEditingController();

    List<dynamic> comments = [];

    bool sending = false;

    int? latestCount;

    try {
      final result = await ApiService.getComments(postId: postId);

      if (result['success'] == true) {
        final raw = result['data']?['comments'];

        if (raw is List) {
          comments = List<dynamic>.from(raw);
        }
      }
    } catch (error) {
      debugPrint('Get Comments Error: $error');
    }

    if (!mounted) {
      controller.dispose();
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> sendComment() async {
              final text = controller.text.trim();

              if (text.isEmpty || sending) {
                return;
              }

              setModalState(() {
                sending = true;
              });

              try {
                final result = await ApiService.createComment(
                  postId: postId,
                  content: text,
                );

                if (result['success'] == true) {
                  final comment = result['data']?['comment'];

                  if (comment != null) {
                    final total = result['data']?['commentsCount'];

                    latestCount = total is num ? total.toInt() : null;

                    setModalState(() {
                      comments.add(comment);
                      controller.clear();
                    });
                  }
                } else if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        result['message']?.toString() ??
                            'Unable to add comment',
                      ),
                    ),
                  );
                }
              } catch (error) {
                debugPrint('Create Comment Error: $error');
              } finally {
                if (sheetContext.mounted) {
                  setModalState(() {
                    sending = false;
                  });
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.of(sheetContext).size.height * 0.78,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Comments',
                                style: TextStyle(
                                  color: _text,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: _boldIcon(CupertinoIcons.xmark, 20, _text),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: _divider),
                      Expanded(
                        child: comments.isEmpty
                            ? Center(
                                child: Text(
                                  'No comments yet.\nBe the first to comment.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: _muted, fontSize: 14),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: comments.length,
                                itemBuilder: (context, index) {
                                  final raw = comments[index];

                                  if (raw is! Map) {
                                    return const SizedBox.shrink();
                                  }

                                  final comment = Map<String, dynamic>.from(raw);

                                  final author = comment['author'];

                                  final username = author is Map
                                      ? author['username']?.toString() ?? 'User'
                                      : 'User';

                                  final content =
                                      comment['content']?.toString() ?? '';

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildSmallAvatar(
                                          author is Map
                                              ? Map<String, dynamic>.from(author)
                                              : <String, dynamic>{},
                                          34,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: _secondarySurface,
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  username,
                                                  style: TextStyle(
                                                    color: _text,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  content,
                                                  style: TextStyle(
                                                    color: _text,
                                                    fontSize: 14,
                                                    height: 1.35,
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
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                        decoration: BoxDecoration(
                          color: _surface,
                          border: Border(top: BorderSide(color: _divider)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                maxLength: 300,
                                minLines: 1,
                                maxLines: 4,
                                cursorColor: _accent,
                                style: TextStyle(color: _text),
                                decoration: InputDecoration(
                                  hintText: 'Write a comment...',
                                  hintStyle: TextStyle(color: _muted),
                                  counterText: '',
                                  filled: true,
                                  fillColor: _secondarySurface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(22),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: sending ? null : sendComment,
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: const BoxDecoration(
                                  color: _accent,
                                  shape: BoxShape.circle,
                                ),
                                child: sending
                                    ? const Padding(
                                        padding: EdgeInsets.all(13),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        CupertinoIcons.arrow_up,
                                        color: Colors.white,
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

    final newCount = latestCount;

    if (newCount != null) {
      _patchPost(postId, (post) {
        post['commentsCount'] = newCount;
      });
    }
  }

  // ============================================================
  // SHARE POST
  // ============================================================

  Future<void> _sharePost(Map<String, dynamic> post) async {
    final content = post['content']?.toString() ?? '';

    final author = post['author'];

    final username = author is Map
        ? author['username']?.toString() ?? 'User'
        : 'User';

    final text =
        '$username on MicroBlog:\n\n'
        '$content\n\n'
        'Shared from MicroBlog';

    try {
      await SharePlus.instance.share(
        ShareParams(text: text.trim(), subject: 'MicroBlog post'),
      );
    } catch (error) {
      debugPrint('Share Post Error: $error');
    }
  }

  bool _containsId(dynamic list, String id) {
    if (list is! List) {
      return false;
    }

    return list.any((item) => item?.toString() == id);
  }

  // ============================================================
  // TIME AGO
  // ============================================================

  String _timeAgo(dynamic value) {
    if (value == null) {
      return '';
    }

    final date = DateTime.tryParse(value.toString());

    if (date == null) {
      return '';
    }

    final difference = DateTime.now().difference(date.toLocal());

    if (difference.inSeconds < 60) {
      return 'now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }

    if (difference.inDays < 365) {
      return '${date.day}/${date.month}';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  // ============================================================
  // AVATARS
  // ============================================================

  Widget _buildSmallAvatar([Map<String, dynamic>? user, double size = 40]) {
    final data = user ?? _user ?? {};

    final avatar = data['avatar']?.toString().trim() ?? '';

    final displayName =
        data['displayName']?.toString().trim() ??
        data['username']?.toString().trim() ??
        'U';

    String initials = 'U';

    if (displayName.isNotEmpty) {
      final parts = displayName.split(RegExp(r'\s+'));

      initials = parts.length >= 2
          ? (parts[0][0] + parts[1][0]).toUpperCase()
          : displayName[0].toUpperCase();
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

    if (avatar.startsWith('data:image/')) {
      final bytes = ApiService.dataUrlToBytes(avatar);

      if (bytes != null) {
        return ClipOval(
          child: Image.memory(
            Uint8List.fromList(bytes),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback(),
          ),
        );
      }
    }

    if (avatar.isNotEmpty) {
      final normalized = ApiService.normalizeImageUrl(avatar);

      if (normalized != null) {
        return ClipOval(
          child: Image.network(
            normalized,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback(),
          ),
        );
      }
    }

    return fallback();
  }

  Widget _buildProfileImage({double size = 112}) {
    Widget wrap(Widget child) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipOval(child: child),
            if (_uploadingAvatar)
              ClipOval(
                child: Container(
                  color: Colors.black.withOpacity(.45),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (_pendingProfilePhoto != null) {
      return wrap(
        Image.file(
          _pendingProfilePhoto!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitialAvatar(size),
        ),
      );
    }

    final avatar = _user?['avatar']?.toString().trim() ?? '';

    if (avatar.startsWith('data:image/')) {
      final bytes = ApiService.dataUrlToBytes(avatar);

      if (bytes != null) {
        return wrap(
          Image.memory(
            Uint8List.fromList(bytes),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitialAvatar(size),
          ),
        );
      }
    }

    if (avatar.isNotEmpty) {
      final normalized = ApiService.normalizeImageUrl(avatar);

      if (normalized != null) {
        return wrap(
          Image.network(
            normalized,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitialAvatar(size),
          ),
        );
      }
    }

    return wrap(_buildInitialAvatar(size));
  }

  Widget _buildInitialAvatar(double size) {
    return Container(
      width: size,
      height: size,
      color: _secondarySurface,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: _text,
          fontSize: size * .30,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ============================================================
  // COVER PHOTO
  // ============================================================

  Widget _buildCoverPhoto() {
    Widget image;

    if (_pendingCoverPhoto != null) {
      image = Image.file(
        _pendingCoverPhoto!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultCover(),
      );
    } else {
      final cover = _user?['coverPhoto']?.toString().trim() ?? '';

      if (cover.startsWith('data:image/')) {
        final bytes = ApiService.dataUrlToBytes(cover);

        image = bytes != null
            ? Image.memory(
                Uint8List.fromList(bytes),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _defaultCover(),
              )
            : _defaultCover();
      } else if (cover.isNotEmpty) {
        final normalized = ApiService.normalizeImageUrl(cover);

        image = normalized != null
            ? Image.network(
                normalized,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _defaultCover(),
              )
            : _defaultCover();
      } else {
        image = _defaultCover();
      }
    }

    return SizedBox(
      width: double.infinity,
      height: 170,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => _openPhotoViewer(isAvatar: false),
            child: image,
          ),
          if (_uploadingCover)
            Container(
              color: Colors.black.withOpacity(.45),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              ),
            ),
          Positioned(
            right: 12,
            bottom: 12,
            child: _circleButton(
              icon: CupertinoIcons.camera,
              onTap: _pickCoverPhoto,
              background: Colors.black.withOpacity(.65),
              foreground: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent.withOpacity(_isDark ? .30 : .18),
            _secondarySurface,
          ],
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color background,
    required Color foreground,
  }) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: _boldIcon(icon, 18, foreground),
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE HEADER
  // ============================================================

  Widget _buildProfileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover photo with the profile photo overlapping its bottom edge.
        SizedBox(
          height: 170 + 48,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 170,
                child: _buildCoverPhoto(),
              ),

              Positioned(
                left: 16,
                top: 170 - 44,
                child: GestureDetector(
                  onTap: () => _openPhotoViewer(isAvatar: true),
                  child: Container(
                    width: 92,
                    height: 92,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _background,
                      shape: BoxShape.circle,
                    ),
                    child: _buildProfileImage(size: 84),
                  ),
                ),
              ),

              // Change profile photo.
              Positioned(
                left: 16 + 92 - 34,
                top: 170 - 44 + 92 - 34,
                child: GestureDetector(
                  onTap: _pickProfilePhoto,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: _background, width: 2.5),
                    ),
                    child: const Icon(
                      CupertinoIcons.camera_fill,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),

              // Smaller, thinner edit button.
              Positioned(
                right: 16,
                top: 170 + 10,
                child: OutlinedButton.icon(
                  onPressed: _openEditProfile,
                  icon: _boldIcon(Icons.edit_outlined, 15, _text),
                  label: Text(
                    'Edit profile',
                    style: TextStyle(
                      color: _text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _text,
                    side: BorderSide(color: _divider, width: 1),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),

                // ----------------------------------------------
                // NAME + USERNAME
                // ----------------------------------------------
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        _displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _text,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '@$_username',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                // ----------------------------------------------
                // BIO
                // ----------------------------------------------
                if (_bio.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _bio,
                    style: TextStyle(color: _text, fontSize: 15, height: 1.4),
                  ),
                ],

                // ----------------------------------------------
                // DETAILS: location, birthday, joined, link
                // ----------------------------------------------
                const SizedBox(height: 12),

                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (_location.isNotEmpty)
                      _profileMeta(CupertinoIcons.location_solid, _location),
                    if (_dobText.isNotEmpty)
                      _profileMeta(Icons.cake_rounded, _dobText),
                    _profileMeta(
                      Icons.calendar_month_rounded,
                      _formatJoinedDate(),
                    ),
                  ],
                ),

                if (_website.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _websiteLink(),
                ],

                // ----------------------------------------------
                // FOLLOWING / FOLLOWERS
                // ----------------------------------------------
                const SizedBox(height: 14),

                Row(
                  children: [
                    _countText(
                      _followingCount,
                      'Following',
                      () => _openConnections(followers: false),
                    ),
                    const SizedBox(width: 26),
                    _countText(
                      _followersCount,
                      'Followers',
                      () => _openConnections(followers: true),
                    ),
                  ],
                ),
              ],
            ),
        ),

        // --------------------------------------------------------
        // TAB BAR
        // --------------------------------------------------------
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _divider)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: _accent,
              unselectedLabelColor: _muted,
              indicatorColor: _accent,
              indicatorWeight: 3,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(
                  icon: _boldIcon(
                    CupertinoIcons.doc_text,
                    22,
                    _activeTab == 0 ? _accent : _muted,
                  ),
                ),
                Tab(
                  icon: _boldIcon(
                    CupertinoIcons.arrow_2_squarepath,
                    22,
                    _activeTab == 1 ? _accent : _muted,
                  ),
                ),
                Tab(
                  icon: _boldIcon(
                    _activeTab == 2
                        ? CupertinoIcons.heart_fill
                        : CupertinoIcons.heart,
                    22,
                    _activeTab == 2 ? _accent : _muted,
                  ),
                ),
                Tab(
                  icon: _boldIcon(
                    CupertinoIcons.bubble_left,
                    22,
                    _activeTab == 3 ? _accent : _muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _websiteLink() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openWebsite,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _boldIcon(Icons.link_rounded, 18, _linkColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _website,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _linkColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWebsite() async {
    var value = _website.trim();

    if (value.isEmpty) return;

    if (!value.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      value = 'https://$value';
    }

    final uri = Uri.tryParse(value);

    var opened = false;

    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (error) {
        debugPrint('Open website error: $error');
      }
    }

    if (!opened) {
      _snack('Unable to open this link');
    }
  }

  Widget _profileMeta(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _boldIcon(icon, 17, _muted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _muted,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _countText(int count, String label, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatCount(count),
              style: TextStyle(
                color: _text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: _text,
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ACCOUNT INFORMATION (email)
  // ============================================================

  Widget _buildAccountSection() {
    if (_email.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 14, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _divider, width: .6),
      ),
      child: Row(
        children: [
          _boldIcon(CupertinoIcons.mail, 21, _accent),
          const SizedBox(width: 12),
          Text(
            'Email',
            style: TextStyle(
              color: _text,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _email,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _text,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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
        backgroundColor: _surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: _text),
        shape: Border(bottom: BorderSide(color: _divider, width: 0.8)),
        title: Text(
          _displayName.isNotEmpty ? _displayName : 'Profile',
          style: TextStyle(
            color: _text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : RefreshIndicator(
              color: _accent,
              backgroundColor: _surface,
              onRefresh: _refreshProfile,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildProfileHeader()),
                  SliverToBoxAdapter(child: _buildActivityTab()),
                  SliverToBoxAdapter(child: _buildAccountSection()),
                  const SliverToBoxAdapter(child: SizedBox(height: 30)),
                ],
              ),
            ),
    );
  }
}

// ==================================================================
// MEDIA PAGER (1/N, 2/N ... badge when there is more than one item)
// ==================================================================

class _MediaPager extends StatefulWidget {
  final double height;
  final List<Widget> children;

  const _MediaPager({required this.height, required this.children});

  @override
  State<_MediaPager> createState() => _MediaPagerState();
}

class _MediaPagerState extends State<_MediaPager> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final total = widget.children.length;

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          PageView(
            onPageChanged: (value) => setState(() => _page = value),
            children: widget.children,
          ),
          if (total > 1)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_page + 1}/$total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}