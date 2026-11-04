import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../services/api_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  // ============================================================
  // LIMITS
  // ============================================================

  static const int _maxImages = 10;
  static const int _maxVideos = 5;
  static const int _maxVideoMinutes = 100;

  // ============================================================
  // THEME (same palette as the home screen)
  // ============================================================

  static const Color _accent = Color(0xFFF91880);

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color get _background =>
      _dark ? const Color(0xFF08090B) : const Color(0xFFF7F8FA);

  Color get _surface =>
      _dark ? const Color(0xFF15171B) : const Color(0xFFFFFFFF);

  Color get _text =>
      _dark ? const Color(0xFFFFFFFF) : const Color(0xFF111318);

  Color get _muted =>
      _dark ? const Color(0xFF9297A0) : const Color(0xFF737B86);

  Color get _divider =>
      _dark ? const Color(0xFF282B31) : const Color(0xFFE6E8EC);

  Color get _composer =>
      _dark ? const Color(0xFF202329) : const Color(0xFFF0F1F4);

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _textController = TextEditingController();

  final TextEditingController _locationController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  final List<TextEditingController> _pollControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  // ============================================================
  // MEDIA STATE
  // ============================================================

  final List<XFile> _images = [];
  final List<XFile> _videos = [];

  int _imagePage = 0;

  // Generic file selected from mobile file manager.
  PlatformFile? _selectedFile;

  bool _posting = false;
  bool _showPoll = false;

  int _pollDuration = 1;

  // Current user (profile photo stays in sync with the profile).
  Map<String, dynamic>? _currentUser;

  // ============================================================
  // INIT / DISPOSE
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _textController.dispose();
    _locationController.dispose();

    for (final controller in _pollControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final user = await ApiService.getCurrentUser();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUser = user;
      });
    } catch (_) {
      // Avatar falls back to the placeholder.
    }
  }

  // ============================================================
  // MEDIA HELPERS
  // ============================================================

  static const Set<String> _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
  };

  static const Set<String> _videoExtensions = {
    'mp4',
    'mov',
    'm4v',
    'avi',
    'mkv',
    'webm',
    '3gp',
  };

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');

    if (dot < 0 || dot == path.length - 1) {
      return '';
    }

    return path.substring(dot + 1).toLowerCase();
  }

  /// Returns true when the video is allowed (100 minutes max).
  Future<bool> _videoLengthAllowed(String path) async {
    VideoPlayerController? controller;

    try {
      controller = VideoPlayerController.file(File(path));

      await controller.initialize();

      return controller.value.duration.inSeconds <= _maxVideoMinutes * 60;
    } catch (_) {
      // If the length cannot be read, do not block the user.
      return true;
    } finally {
      await controller?.dispose();
    }
  }

  /// Adds picked files. Photos and videos can be mixed.
  Future<void> _addFiles(List<String> paths) async {
    String? warning;

    for (final path in paths) {
      final extension = _extensionOf(path);

      if (_videoExtensions.contains(extension)) {
        if (_videos.length >= _maxVideos) {
          warning = 'You can add up to $_maxVideos videos per post';
          continue;
        }

        final allowed = await _videoLengthAllowed(path);

        if (!allowed) {
          warning = 'Videos can be up to $_maxVideoMinutes minutes long';
          continue;
        }

        _videos.add(XFile(path));
      } else {
        if (_images.length >= _maxImages) {
          warning = 'You can add up to $_maxImages photos per post';
          continue;
        }

        _images.add(XFile(path));
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedFile = null;

      if (_imagePage >= _images.length) {
        _imagePage = _images.isEmpty ? 0 : _images.length - 1;
      }
    });

    if (warning != null) {
      _showMessage(warning);
    }
  }

  // ============================================================
  // GALLERY (direct) - opens the phone gallery for photos or videos
  // ============================================================

  Future<void> _openGalleryOptions() async {
    if (_posting) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _cameraOption(
                  icon: Icons.photo_library_outlined,
                  title: 'Photos',
                  subtitle: 'Choose up to $_maxImages photos from gallery',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickPhotosFromGallery();
                  },
                ),

                const SizedBox(height: 10),

                _cameraOption(
                  icon: Icons.video_library_outlined,
                  title: 'Videos',
                  subtitle: 'Choose a video from gallery',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickVideoFromGallery();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickPhotosFromGallery() async {
    if (_images.length >= _maxImages) {
      _showMessage('You can add up to $_maxImages photos per post');
      return;
    }

    try {
      final List<XFile> picked = await _picker.pickMultiImage(
        imageQuality: 82,
        maxWidth: 1800,
        maxHeight: 1800,
      );

      if (picked.isEmpty || !mounted) {
        return;
      }

      await _addFiles(picked.map((file) => file.path).toList());
    } catch (error) {
      _showMessage('Unable to access gallery');
    }
  }

  Future<void> _pickVideoFromGallery() async {
    if (_videos.length >= _maxVideos) {
      _showMessage('You can add up to $_maxVideos videos per post');
      return;
    }

    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (video == null || !mounted) {
        return;
      }

      // Gallery videos may have no extension, so add them as videos.
      if (!_videoExtensions.contains(_extensionOf(video.path))) {
        if (!await _videoLengthAllowed(video.path)) {
          _showMessage('Videos can be up to $_maxVideoMinutes minutes long');
          return;
        }

        setState(() {
          _videos.add(video);
          _selectedFile = null;
        });
        return;
      }

      await _addFiles([video.path]);
    } catch (error) {
      _showMessage('Unable to access gallery');
    }
  }

  // ============================================================
  // FILES MENU (gallery photos+videos together, or file manager)
  // ============================================================

  Future<void> _openFilesOptions() async {
    if (_posting) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _cameraOption(
                  icon: Icons.collections_outlined,
                  title: 'Gallery',
                  subtitle: 'Photos and videos together',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickMixedFromGallery();
                  },
                ),

                const SizedBox(height: 10),

                _cameraOption(
                  icon: Icons.folder_open_rounded,
                  title: 'Files',
                  subtitle: 'Browse your phone storage',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickFromFileManager();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickMixedFromGallery() async {
    if (_images.length >= _maxImages && _videos.length >= _maxVideos) {
      _showMessage('Photo and video limit reached');
      return;
    }

    try {
      final List<XFile> picked = await _picker.pickMultipleMedia(
        imageQuality: 82,
        maxWidth: 1800,
        maxHeight: 1800,
      );

      if (picked.isEmpty || !mounted) {
        return;
      }

      await _addFiles(picked.map((file) => file.path).toList());
    } catch (error) {
      _showMessage('Unable to access gallery');
    }
  }

  // ============================================================
  // CAMERA MENU
  // ============================================================

  Future<void> _openCameraOptions() async {
    if (_posting) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Camera',
                  style: TextStyle(
                    color: _text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Choose what you want to capture',
                  style: TextStyle(color: _muted, fontSize: 14),
                ),

                const SizedBox(height: 20),

                _cameraOption(
                  icon: Icons.photo_camera_outlined,
                  title: 'Take photo',
                  subtitle: 'Capture a photo with your camera',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _capturePhoto();
                  },
                ),

                const SizedBox(height: 10),

                _cameraOption(
                  icon: Icons.videocam_outlined,
                  title: 'Record video',
                  subtitle: 'Record a video up to $_maxVideoMinutes minutes',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _captureVideo();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // CAMERA PHOTO
  // ============================================================

  Future<void> _capturePhoto() async {
    if (_images.length >= _maxImages) {
      _showMessage('You can add up to $_maxImages photos per post');
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
        maxWidth: 1800,
        maxHeight: 1800,
      );

      if (image == null || !mounted) {
        return;
      }

      await _addFiles([image.path]);
    } catch (error) {
      _showMessage('Unable to access camera');
    }
  }

  // ============================================================
  // CAMERA VIDEO
  // ============================================================

  Future<void> _captureVideo() async {
    if (_videos.length >= _maxVideos) {
      _showMessage('You can add up to $_maxVideos videos per post');
      return;
    }

    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: _maxVideoMinutes),
      );

      if (video == null || !mounted) {
        return;
      }

      // Camera videos have no extension guarantee, so add directly.
      if (!_videoExtensions.contains(_extensionOf(video.path))) {
        setState(() {
          _videos.add(video);
          _selectedFile = null;
        });
        return;
      }

      await _addFiles([video.path]);
    } catch (error) {
      _showMessage('Unable to access camera video');
    }
  }

  // ============================================================
  // FILE MANAGER
  // ============================================================

  Future<void> _pickFromFileManager() async {
    if (_posting) {
      return;
    }

    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.any,
      );

      if (file == null || !mounted) {
        return;
      }

      final extension = (file.extension ?? '').toLowerCase();

      if (_imageExtensions.contains(extension) ||
          _videoExtensions.contains(extension)) {
        final path = file.path;

        if (path == null || path.isEmpty) {
          _showMessage('Unable to access selected file');
          return;
        }

        await _addFiles([path]);
        return;
      }

      // Music / document / other file.
      setState(() {
        _selectedFile = file;
        _images.clear();
        _videos.clear();
        _imagePage = 0;
      });

      _showMessage(
        'File selected. Music/documents need backend file support before they can be posted.',
      );
    } catch (error) {
      _showMessage('Unable to open mobile file manager');
    }
  }

  // ============================================================
  // CAMERA OPTION WIDGET
  // ============================================================

  Widget _cameraOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _composer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: _boldIcon(icon, 24, _accent),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                  ],
                ),
              ),

              Icon(CupertinoIcons.chevron_right, color: _muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOCATION
  // ============================================================

  Future<void> _addLocation() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _surface,
          title: Text(
            'Add location',
            style: TextStyle(color: _text, fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: _locationController,
            autofocus: true,
            style: TextStyle(color: _text),
            decoration: InputDecoration(
              hintText: 'City, place or area',
              hintStyle: TextStyle(color: _muted),
              prefixIcon: _boldIcon(
                CupertinoIcons.location_solid,
                20,
                _accent,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: _muted)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // POLL
  // ============================================================

  void _togglePoll() {
    setState(() {
      _showPoll = !_showPoll;
    });
  }

  void _addPollOption() {
    if (_pollControllers.length >= 4) {
      _showMessage('A poll can have up to 4 options');
      return;
    }

    setState(() {
      _pollControllers.add(TextEditingController());
    });
  }

  void _removePollOption(int index) {
    if (_pollControllers.length <= 2) {
      return;
    }

    final controller = _pollControllers.removeAt(index);

    controller.dispose();

    setState(() {});
  }

  // ============================================================
  // PUBLISH
  // ============================================================

  Future<void> _publish() async {
    final content = _textController.text.trim();

    final options = _pollControllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (_selectedFile != null) {
      _showMessage(
        'Music and document attachments are not supported by the current post API yet.',
      );
      return;
    }

    if (content.isEmpty &&
        _images.isEmpty &&
        _videos.isEmpty &&
        options.isEmpty) {
      _showMessage('Write something or add media first');
      return;
    }

    if (_showPoll && options.length < 2) {
      _showMessage('Add at least two poll options');
      return;
    }

    setState(() {
      _posting = true;
    });

    try {
      final List<String> imageData = [];
      final List<String> videoData = [];

      for (final image in _images) {
        imageData.add(await ApiService.fileToDataUrl(File(image.path)));
      }

      for (final video in _videos) {
        videoData.add(await ApiService.fileToDataUrl(File(video.path)));
      }

      Map<String, dynamic>? poll;

      if (_showPoll) {
        poll = {'options': options, 'durationDays': _pollDuration};
      }

      final result = await ApiService.createPost(
        content: content,
        images: imageData,
        videos: videoData,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        poll: poll,
      );

      if (!mounted) {
        return;
      }

      if (result['success'] == true) {
        Navigator.pop(context, true);
        return;
      }

      _showMessage(result['message']?.toString() ?? 'Unable to create post');
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _posting = false;
        });
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  // ============================================================
  // ICON HELPERS
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

  // ============================================================
  // AVATAR (synced with the profile photo)
  // ============================================================

  Widget _avatar() {
    const radius = 22.0;

    final user = _currentUser;

    final name =
        (user?['displayName'] ?? user?['name'] ?? user?['username'] ?? '')
            .toString()
            .trim();

    final value = user?['avatar']?.toString().trim() ?? '';

    Widget fallback() {
      return Container(
        width: radius * 2,
        height: radius * 2,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: _composer),
        child: name.isEmpty
            ? Icon(Icons.person, color: _muted)
            : Text(
                name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: _text,
                  fontSize: radius * .72,
                  fontWeight: FontWeight.w800,
                ),
              ),
      );
    }

    if (value.isEmpty) {
      return fallback();
    }

    final bytes = ApiService.dataUrlToBytes(value);

    if (bytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.transparent,
        backgroundImage: MemoryImage(Uint8List.fromList(bytes)),
      );
    }

    final url = ApiService.normalizeImageUrl(value);

    if (url == null) {
      return fallback();
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.transparent,
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (_, __) {},
    );
  }

  // ============================================================
  // MEDIA PREVIEW WIDGETS
  // ============================================================

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _removeButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: _posting ? null : onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _imagePreview() {
    final total = _images.length;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 280,
          child: Stack(
            children: [
              PageView.builder(
                itemCount: total,
                onPageChanged: (value) => setState(() => _imagePage = value),
                itemBuilder: (_, index) => Image.file(
                  File(_images[index].path),
                  width: double.infinity,
                  height: 280,
                  fit: BoxFit.cover,
                ),
              ),

              Positioned(
                left: 10,
                top: 10,
                child: _badge('${_imagePage + 1}/$total'),
              ),

              Positioned(
                right: 8,
                top: 8,
                child: _removeButton(() {
                  setState(() {
                    _images.removeAt(_imagePage);

                    if (_imagePage >= _images.length) {
                      _imagePage = _images.isEmpty ? 0 : _images.length - 1;
                    }
                  });
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _videoTile(int index) {
    final total = _videos.length;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: _composer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _divider),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _boldIcon(CupertinoIcons.play_rectangle, 34, _accent),

                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _videos[index].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(left: 10, top: 10, child: _badge('${index + 1}/$total')),

          Positioned(
            right: 8,
            top: 8,
            child: _removeButton(() {
              setState(() {
                _videos.removeAt(index);
              });
            }),
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

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: _divider, width: 0.8)),

        leading: IconButton(
          onPressed: _posting ? null : () => Navigator.pop(context),
          icon: _boldIcon(Icons.close_rounded, 24, _text),
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            child: FilledButton(
              onPressed: _posting ? null : _publish,
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _accent.withOpacity(.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: _posting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Post',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                children: [
                  // ==================================================
                  // COMPOSER
                  // ==================================================
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _avatar(),

                      const SizedBox(width: 12),

                      Expanded(
                        child: TextField(
                          controller: _textController,
                          autofocus: true,
                          maxLength: 500,
                          minLines: 8,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          cursorColor: _accent,
                          style: TextStyle(
                            color: _text,
                            fontSize: 18,
                            height: 1.4,
                          ),
                          decoration: InputDecoration(
                            hintText: "What's happening?",
                            hintStyle: TextStyle(color: _muted, fontSize: 18),
                            border: InputBorder.none,
                            counterText: '',
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ==================================================
                  // MEDIA PREVIEWS
                  // ==================================================
                  if (_images.isNotEmpty) _imagePreview(),

                  for (int i = 0; i < _videos.length; i++) _videoTile(i),

                  // ==================================================
                  // GENERIC FILE PREVIEW
                  // ==================================================
                  if (_selectedFile != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _composer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: _accent.withOpacity(.12),
                                shape: BoxShape.circle,
                              ),
                              child: _boldIcon(
                                _fileIcon(_selectedFile!.extension),
                                24,
                                _accent,
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedFile!.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _text,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  Text(
                                    'File attachment',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _selectedFile = null;
                                });
                              },
                              icon: Icon(Icons.close, color: _text),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ==================================================
                  // LOCATION
                  // ==================================================
                  if (_locationController.text.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          backgroundColor: _composer,
                          side: BorderSide.none,
                          avatar: _boldIcon(
                            CupertinoIcons.location_solid,
                            16,
                            _accent,
                          ),
                          label: Text(
                            _locationController.text.trim(),
                            style: TextStyle(color: _text),
                          ),
                          onDeleted: () {
                            setState(() {
                              _locationController.clear();
                            });
                          },
                        ),
                      ),
                    ),

                  // ==================================================
                  // POLL
                  // ==================================================
                  if (_showPoll)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _composer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Poll',
                                    style: TextStyle(
                                      color: _text,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),

                                DropdownButton<int>(
                                  value: _pollDuration,
                                  dropdownColor: _surface,
                                  style: TextStyle(color: _text),
                                  underline: const SizedBox.shrink(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _pollDuration = value;
                                      });
                                    }
                                  },
                                  items: const [
                                    DropdownMenuItem(
                                      value: 1,
                                      child: Text('1 day'),
                                    ),
                                    DropdownMenuItem(
                                      value: 3,
                                      child: Text('3 days'),
                                    ),
                                    DropdownMenuItem(
                                      value: 7,
                                      child: Text('7 days'),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            for (int i = 0; i < _pollControllers.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: TextField(
                                  controller: _pollControllers[i],
                                  style: TextStyle(color: _text),
                                  decoration: InputDecoration(
                                    labelText: 'Option ${i + 1}',
                                    labelStyle: TextStyle(color: _muted),
                                    suffixIcon: i >= 2
                                        ? IconButton(
                                            onPressed: () =>
                                                _removePollOption(i),
                                            icon: Icon(
                                              Icons.close,
                                              color: _text,
                                            ),
                                          )
                                        : null,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: _divider),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: _accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _addPollOption,
                                icon: const Icon(
                                  Icons.add_rounded,
                                  color: _accent,
                                ),
                                label: const Text(
                                  'Add option',
                                  style: TextStyle(color: _accent),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ========================================================
            // FIXED BOTTOM TOOLBAR
            // ========================================================
            Container(
              decoration: BoxDecoration(
                color: _surface,
                border: Border(
                  top: BorderSide(color: _divider, width: 0.6),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Row(
                children: [
                  // Photos + videos together from the gallery.
                  _toolbarIcon(
                    Icons.photo_library_outlined,
                    _openGalleryOptions,
                    tooltip: 'Gallery',
                  ),

                  _toolbarIcon(
                    Icons.photo_camera_outlined,
                    _openCameraOptions,
                    tooltip: 'Camera',
                  ),

                  _toolbarIcon(
                    CupertinoIcons.at,
                    () => _showMessage('Tagging coming soon'),
                    tooltip: 'Tag people',
                  ),

                  _toolbarIcon(
                    Icons.folder_open_rounded,
                    _openFilesOptions,
                    tooltip: 'Files',
                  ),

                  _toolbarIcon(
                    Icons.bar_chart_rounded,
                    _togglePoll,
                    tooltip: 'Poll',
                  ),

                  _toolbarIcon(
                    CupertinoIcons.location_solid,
                    _addLocation,
                    tooltip: 'Location',
                  ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FILE ICON
  // ============================================================

  IconData _fileIcon(String? extension) {
    final ext = (extension ?? '').toLowerCase();

    const audioExtensions = <String>{
      'mp3',
      'wav',
      'aac',
      'm4a',
      'flac',
      'ogg',
      'opus',
    };

    const documentExtensions = <String>{
      'pdf',
      'doc',
      'docx',
      'txt',
      'rtf',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
      'csv',
    };

    if (audioExtensions.contains(ext)) {
      return CupertinoIcons.music_note;
    }

    if (documentExtensions.contains(ext)) {
      return CupertinoIcons.doc_text;
    }

    return Icons.insert_drive_file_outlined;
  }

  // ============================================================
  // TOOLBAR ICON
  // ============================================================

  Widget _toolbarIcon(IconData icon, VoidCallback onTap, {String? tooltip}) {
    return IconButton(
      onPressed: _posting ? null : onTap,
      tooltip: tooltip,
      icon: _boldIcon(icon, 23, _accent),
    );
  }
}