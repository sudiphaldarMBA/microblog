import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../services/api_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
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

  XFile? _image;
  XFile? _video;

  // Generic file selected from mobile file manager.
  PlatformFile? _selectedFile;

  bool _posting = false;
  bool _showPoll = false;

  int _pollDuration = 1;

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _textController.dispose();
    _locationController.dispose();

    for (final controller in _pollControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  // ============================================================
  // GALLERY
  // ============================================================

  Future<void> _pickFromGallery() async {
    if (_posting) {
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      if (image == null || !mounted) {
        return;
      }

      setState(() {
        _image = image;
        _video = null;
        _selectedFile = null;
      });
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

    final dark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: dark ? const Color(0xFF111315) : Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final textColor = dark ? Colors.white : Colors.black;

        final mutedColor = dark
            ? const Color(0xFF8D939C)
            : const Color(0xFF69707A);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Camera',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Choose what you want to capture',
                  style: TextStyle(color: mutedColor, fontSize: 14),
                ),

                const SizedBox(height: 20),

                // ------------------------------------------------
                // TAKE PHOTO
                // ------------------------------------------------
                _cameraOption(
                  context: sheetContext,
                  icon: CupertinoIcons.camera,
                  title: 'Take photo',
                  subtitle: 'Capture a photo with your camera',
                  textColor: textColor,
                  mutedColor: mutedColor,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _capturePhoto();
                  },
                ),

                const SizedBox(height: 10),

                // ------------------------------------------------
                // RECORD VIDEO
                // ------------------------------------------------
                _cameraOption(
                  context: sheetContext,
                  icon: CupertinoIcons.videocam,
                  title: 'Record video',
                  subtitle: 'Record a video up to 5 minutes',
                  textColor: textColor,
                  mutedColor: mutedColor,
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

      setState(() {
        _image = image;
        _video = null;
        _selectedFile = null;
      });
    } catch (error) {
      _showMessage('Unable to access camera');
    }
  }

  // ============================================================
  // CAMERA VIDEO
  // ============================================================

  Future<void> _captureVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );

      if (video == null || !mounted) {
        return;
      }

      setState(() {
        _video = video;
        _image = null;
        _selectedFile = null;
      });
    } catch (error) {
      _showMessage('Unable to access camera video');
    }
  }

  // ============================================================
  // FILE MANAGER
  // ============================================================
  //
  // This is intentionally separate from Gallery.
  //
  // Files opens the device's generic file picker and allows:
  // - Images
  // - Videos
  // - Audio / Music
  // - Documents
  // - Other files
  //
  // ============================================================

  Future<void> _pickFromFileManager() async {
    if (_posting) {
      return;
    }

    try {
      final PlatformFile? file = await FilePicker.pickFile(type: FileType.any);

      if (file == null || !mounted) {
        return;
      }

      final extension = (file.extension ?? '').toLowerCase();

      const imageExtensions = <String>{
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'bmp',
        'heic',
        'heif',
      };

      const videoExtensions = <String>{
        'mp4',
        'mov',
        'm4v',
        'avi',
        'mkv',
        'webm',
        '3gp',
      };

      // ----------------------------------------------------------
      // IMAGE
      // ----------------------------------------------------------

      if (imageExtensions.contains(extension)) {
        final path = file.path;

        if (path == null || path.isEmpty) {
          _showMessage('Unable to access selected image');
          return;
        }

        setState(() {
          _image = XFile(path);
          _video = null;
          _selectedFile = null;
        });

        return;
      }

      // ----------------------------------------------------------
      // VIDEO
      // ----------------------------------------------------------

      if (videoExtensions.contains(extension)) {
        final path = file.path;

        if (path == null || path.isEmpty) {
          _showMessage('Unable to access selected video');
          return;
        }

        setState(() {
          _video = XFile(path);
          _image = null;
          _selectedFile = null;
        });

        return;
      }

      // ----------------------------------------------------------
      // MUSIC / DOCUMENT / OTHER FILE
      // ----------------------------------------------------------

      setState(() {
        _selectedFile = file;
        _image = null;
        _video = null;
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
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color mutedColor,
    required VoidCallback onTap,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF191B1F) : const Color(0xFFF4F5F7),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: textColor, size: 24),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(color: mutedColor, fontSize: 13),
                    ),
                  ],
                ),
              ),

              Icon(CupertinoIcons.chevron_right, color: mutedColor, size: 18),
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
        final dark = Theme.of(dialogContext).brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: dark ? const Color(0xFF090A0C) : Colors.white,
          title: Text(
            'Add location',
            style: TextStyle(
              color: dark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: TextField(
            controller: _locationController,
            autofocus: true,
            style: TextStyle(color: dark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: 'City, place or area',
              prefixIcon: Icon(
                CupertinoIcons.location_solid,
                color: dark ? Colors.white : Colors.black,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: FilledButton.styleFrom(
                backgroundColor: dark ? Colors.white : Colors.black,
                foregroundColor: dark ? Colors.black : Colors.white,
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

    // ----------------------------------------------------------
    // GENERIC FILE CHECK
    // ----------------------------------------------------------

    if (_selectedFile != null) {
      _showMessage(
        'Music and document attachments are not supported by the current post API yet.',
      );
      return;
    }

    // ----------------------------------------------------------
    // EMPTY POST CHECK
    // ----------------------------------------------------------

    if (content.isEmpty &&
        _image == null &&
        _video == null &&
        options.isEmpty) {
      _showMessage('Write something or add media first');
      return;
    }

    // ----------------------------------------------------------
    // POLL VALIDATION
    // ----------------------------------------------------------

    if (_showPoll && options.length < 2) {
      _showMessage('Add at least two poll options');
      return;
    }

    setState(() {
      _posting = true;
    });

    try {
      String? imageData;
      String? videoData;

      // --------------------------------------------------------
      // IMAGE
      // --------------------------------------------------------

      if (_image != null) {
        imageData = await ApiService.fileToDataUrl(File(_image!.path));
      }

      // --------------------------------------------------------
      // VIDEO
      // --------------------------------------------------------

      if (_video != null) {
        videoData = await ApiService.fileToDataUrl(File(_video!.path));
      }

      // --------------------------------------------------------
      // POLL
      // --------------------------------------------------------

      Map<String, dynamic>? poll;

      if (_showPoll) {
        poll = {'options': options, 'durationDays': _pollDuration};
      }

      // --------------------------------------------------------
      // CREATE POST
      // --------------------------------------------------------

      final result = await ApiService.createPost(
        content: content,
        image: imageData,
        video: videoData,
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final background = dark ? Colors.black : Colors.white;

    final textColor = dark ? Colors.white : Colors.black;

    final muted = dark ? const Color(0xFF8D939C) : const Color(0xFF69707A);

    final composer = dark ? const Color(0xFF17191C) : const Color(0xFFF1F3F5);

    return Scaffold(
      backgroundColor: background,

      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,

        leading: IconButton(
          onPressed: _posting ? null : () => Navigator.pop(context),
          icon: Icon(Icons.close_rounded, color: textColor),
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            child: FilledButton(
              onPressed: _posting ? null : _publish,

              style: FilledButton.styleFrom(
                backgroundColor: dark ? Colors.white : Colors.black,
                foregroundColor: dark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),

              child: _posting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          dark ? Colors.black : Colors.white,
                        ),
                      ),
                    )
                  : const Text(
                      'Post',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
                  vertical: 8,
                ),

                children: [
                  // ==================================================
                  // COMPOSER
                  // ==================================================
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, color: Colors.white),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: TextField(
                          controller: _textController,
                          autofocus: true,
                          maxLength: 500,
                          maxLines: null,
                          minLines: 1,
                          keyboardType: TextInputType.multiline,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            height: 1.4,
                          ),
                          decoration: InputDecoration(
                            hintText: "What's happening?",
                            hintStyle: TextStyle(color: muted, fontSize: 18),
                            border: InputBorder.none,
                            counterText: "",
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ==================================================
                  // IMAGE PREVIEW
                  // ==================================================
                  if (_image != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(_image!.path),
                              width: double.infinity,
                              height: 260,
                              fit: BoxFit.cover,
                            ),
                          ),

                          Positioned(
                            right: 8,
                            top: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _image = null;
                                  });
                                },
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ==================================================
                  // VIDEO PREVIEW
                  // ==================================================
                  if (_video != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 180,
                            decoration: BoxDecoration(
                              color: composer,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: dark
                                    ? const Color(0xFF202328)
                                    : const Color(0xFFE7E9ED),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.play_rectangle,
                                  size: 40,
                                  color: textColor,
                                ),

                                const SizedBox(height: 8),

                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    _video!.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Positioned(
                            right: 8,
                            top: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _video = null;
                                  });
                                },
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

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
                          color: composer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: textColor.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _fileIcon(_selectedFile!.extension),
                                color: textColor,
                                size: 24,
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
                                      color: textColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  Text(
                                    'File attachment',
                                    style: TextStyle(
                                      color: muted,
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
                              icon: Icon(Icons.close, color: textColor),
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
                          backgroundColor: composer,
                          side: BorderSide.none,

                          avatar: Icon(
                            CupertinoIcons.location_solid,
                            size: 16,
                            color: textColor,
                          ),

                          label: Text(
                            _locationController.text.trim(),
                            style: TextStyle(color: textColor),
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
                          color: composer,
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
                                      color: textColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),

                                DropdownButton<int>(
                                  value: _pollDuration,
                                  dropdownColor: composer,
                                  style: TextStyle(color: textColor),
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
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: 'Option ${i + 1}',
                                    labelStyle: TextStyle(color: muted),
                                    suffixIcon: i >= 2
                                        ? IconButton(
                                            onPressed: () =>
                                                _removePollOption(i),
                                            icon: Icon(
                                              Icons.close,
                                              color: textColor,
                                            ),
                                          )
                                        : null,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),

                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _addPollOption,
                                icon: Icon(
                                  Icons.add_rounded,
                                  color: dark ? Colors.white : Colors.black,
                                ),
                                label: Text(
                                  'Add option',
                                  style: TextStyle(
                                    color: dark ? Colors.white : Colors.black,
                                  ),
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
                border: Border(
                  top: BorderSide(
                    color: dark
                        ? const Color(0xFF202328)
                        : const Color(0xFFE7E9ED),
                    width: 0.5,
                  ),
                ),
              ),

              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // --------------------------------------------------
                  // GALLERY
                  // Opens native photo/video gallery.
                  // --------------------------------------------------
                  _toolbarIcon(
                    CupertinoIcons.photo_on_rectangle,
                    _pickFromGallery,
                    tooltip: 'Photo or video',
                  ),

                  // --------------------------------------------------
                  // CAMERA
                  // Photo + Video
                  // --------------------------------------------------
                  _toolbarIcon(
                    CupertinoIcons.camera,
                    _openCameraOptions,
                    tooltip: 'Camera',
                  ),

                  // --------------------------------------------------
                  // TAG
                  // --------------------------------------------------
                  _toolbarIcon(
                    CupertinoIcons.at,
                    () => _showMessage('Tagging coming soon'),
                    tooltip: 'Tag people',
                  ),

                  // --------------------------------------------------
                  // FILE MANAGER
                  // Opens generic mobile file manager.
                  // --------------------------------------------------
                  _toolbarIcon(
                    Icons.folder_open_rounded,
                    _pickFromFileManager,
                    tooltip: 'Files',
                  ),

                  // --------------------------------------------------
                  // POLL
                  // --------------------------------------------------
                  _toolbarIcon(
                    Icons.poll_outlined,
                    _togglePoll,
                    tooltip: 'Poll',
                  ),

                  // --------------------------------------------------
                  // LOCATION
                  // --------------------------------------------------
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
    final dark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      onPressed: _posting ? null : onTap,
      tooltip: tooltip,
      icon: Icon(icon, color: dark ? Colors.white : Colors.black, size: 22),
    );
  }
}
