import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// Comment tree sheet: comment, reply, reply-to-reply, edit and delete.
/// Open it with showModalBottomSheet (isScrollControlled: true).
class CommentsSheet extends StatefulWidget {
  final String postId;

  /// Called after any add / edit / delete.
  final VoidCallback? onCommentAdded;

  /// Called with the latest total comment count after any change.
  final ValueChanged<int>? onCountChanged;

  const CommentsSheet({
    super.key,
    required this.postId,
    this.onCommentAdded,
    this.onCountChanged,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  static const Color _accent = Color(0xFFF91880);

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _comments = [];
  bool _loading = true;
  bool _sending = false;
  String? _myId;

  Map<String, dynamic>? _replyingToComment;
  Map<String, dynamic>? _editingComment;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _surface =>
      _isDark ? const Color(0xFF15171B) : const Color(0xFFFFFFFF);
  Color get _composer =>
      _isDark ? const Color(0xFF202329) : const Color(0xFFF0F1F4);
  Color get _text =>
      _isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111318);
  Color get _muted =>
      _isDark ? const Color(0xFF9297A0) : const Color(0xFF737B86);
  Color get _divider =>
      _isDark ? const Color(0xFF282B31) : const Color(0xFFE6E8EC);

  @override
  void initState() {
    super.initState();
    _loadMe();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    try {
      final me = await ApiService.getCurrentUser();
      if (!mounted) return;
      setState(() => _myId = _idString(me['_id'] ?? me['id']));
    } catch (_) {}
  }

  Future<void> _loadComments() async {
    try {
      final result = await ApiService.getComments(postId: widget.postId);

      if (!mounted) return;

      final data = result['data'];
      final rawComments = data is Map ? data['comments'] : null;

      if (result['success'] == true && rawComments is List) {
        final tree = _buildCommentTreeFromResponse(rawComments);
        setState(() => _comments = tree);

        final total = data is Map && data['commentsCount'] is num
            ? (data['commentsCount'] as num).toInt()
            : _countTree(tree);
        widget.onCountChanged?.call(total);
      } else {
        _showMessage(
          result['message']?.toString() ?? 'Unable to load comments',
        );
      }
    } catch (_) {
      _showMessage('Unable to load comments');
    } finally {
      if (mounted && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  int _countTree(List<dynamic> list) {
    var n = 0;
    for (final c in list) {
      n += 1;
      if (c is Map && c['replies'] is List) {
        n += _countTree(c['replies'] as List);
      }
    }
    return n;
  }

  String? _idString(dynamic value) {
    if (value == null) return null;
    if (value is Map) return _idString(value['_id'] ?? value['id']);
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return null;
    return text;
  }

  List<dynamic> _buildCommentTreeFromResponse(List rawComments) {
    final flat = <Map<String, dynamic>>[];

    void collect(dynamic value, {String? inheritedParentId}) {
      if (value is! Map) return;

      final item = Map<String, dynamic>.from(value);
      final id = _idString(item['_id']);
      final explicitParentId =
          _idString(item['parentComment'] ?? item['parentId']);
      final parentId = explicitParentId ?? inheritedParentId;

      final children = item['replies'] is List
          ? List<dynamic>.from(item['replies'] as List)
          : <dynamic>[];

      item.remove('replies');
      if (parentId != null) item['parentComment'] = parentId;
      item['replies'] = <dynamic>[];
      flat.add(item);

      final childParentId = id ?? parentId;
      for (final child in children) {
        collect(child, inheritedParentId: childParentId);
      }
    }

    for (final comment in rawComments) {
      collect(comment);
    }

    final byId = <String, Map<String, dynamic>>{};
    for (final comment in flat) {
      final id = _idString(comment['_id']);
      if (id != null) byId[id] = comment;
    }

    final roots = <dynamic>[];
    for (final comment in flat) {
      final parentId =
          _idString(comment['parentComment'] ?? comment['parentId']);
      final id = _idString(comment['_id']);
      final parent = parentId == null ? null : byId[parentId];

      if (parent != null && parentId != id) {
        (parent['replies'] as List).add(comment);
      } else {
        roots.add(comment);
      }
    }

    return roots;
  }

  // ------------------------------------------------------------
  // ACTIONS
  // ------------------------------------------------------------

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    if (_editingComment != null &&
        _idString(_editingComment!['_id']) == null) {
      _showMessage('Unable to identify this comment');
      return;
    }

    setState(() => _sending = true);

    try {
      Map<String, dynamic> result;

      if (_editingComment != null) {
        result = await ApiService.updateComment(
          commentId: _idString(_editingComment!['_id'])!,
          content: text,
          postId: widget.postId,
        );
      } else {
        final parentId = _replyingToComment == null
            ? null
            : _idString(_replyingToComment!['_id']);

        result = await ApiService.createComment(
          postId: widget.postId,
          content: text,
          parentId: parentId,
        );
      }

      if (!mounted) return;

      if (result['success'] == true) {
        _controller.clear();
        setState(() {
          _replyingToComment = null;
          _editingComment = null;
        });
        FocusScope.of(context).unfocus();

        await _loadComments();
        widget.onCommentAdded?.call();
      } else {
        _showMessage(result['message']?.toString() ?? 'Operation failed');
      }
    } catch (_) {
      _showMessage('An error occurred');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      final result = await ApiService.deleteComment(
        commentId: commentId,
        postId: widget.postId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        if (_idString(_editingComment?['_id']) == commentId ||
            _idString(_replyingToComment?['_id']) == commentId) {
          _cancelInputMode();
        }
        await _loadComments();
        widget.onCommentAdded?.call();
      } else {
        _showMessage(
          result['message']?.toString() ?? 'Unable to delete comment',
        );
      }
    } catch (_) {
      _showMessage('An error occurred while deleting');
    }
  }

  bool _isMine(dynamic comment) {
    if (_myId == null || comment is! Map) return false;
    return _idString(comment['author']) == _myId;
  }

  void _showOptionsModal(dynamic comment) {
    if (comment is! Map || !_isMine(comment)) return;

    final id = _idString(comment['_id']);
    if (id == null) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: _divider,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: _boldIcon(Icons.edit_outlined, _accent),
                title: Text(
                  'Edit comment',
                  style: TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (!mounted) return;
                  setState(() {
                    _editingComment = Map<String, dynamic>.from(comment);
                    _replyingToComment = null;
                    _controller.text = comment['content']?.toString() ?? '';
                    _controller.selection = TextSelection.collapsed(
                      offset: _controller.text.length,
                    );
                  });
                },
              ),
              Divider(height: 1, color: _divider),
              ListTile(
                leading: _boldIcon(Icons.delete_outline, Colors.redAccent),
                title: const Text(
                  'Delete comment',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDeleteComment(id);
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete comment?',
            style: TextStyle(color: _text, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'This will also delete all replies to it. This action cannot be undone.',
            style: TextStyle(color: _muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Cancel', style: TextStyle(color: _text)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;
    await _deleteComment(commentId);
  }

  void _startReply(dynamic comment) {
    if (comment is! Map) return;

    setState(() {
      _replyingToComment = Map<String, dynamic>.from(comment);
      _editingComment = null;
      _controller.text = '@${_username(comment)} ';
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    });
  }

  void _cancelInputMode() {
    setState(() {
      _replyingToComment = null;
      _editingComment = null;
    });
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------

  Widget _boldIcon(IconData icon, Color color, {double size = 22}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        for (final o in const [
          Offset(.45, 0),
          Offset(-.45, 0),
          Offset(0, .45),
          Offset(0, -.45),
        ])
          Transform.translate(
            offset: o,
            child: Icon(icon, size: size, color: color),
          ),
        Icon(icon, size: size, color: color),
      ],
    );
  }

  Map<String, dynamic> _author(dynamic comment) {
    if (comment is Map && comment['author'] is Map) {
      return Map<String, dynamic>.from(comment['author']);
    }
    return {};
  }

  String _username(dynamic comment) =>
      _author(comment)['username']?.toString() ?? 'user';

  String _displayName(dynamic comment) {
    final name = _author(comment)['displayName']?.toString().trim() ?? '';
    return name.isNotEmpty ? name : _username(comment);
  }

  String _timeAgo(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 365) return '${(diff.inDays / 7).floor()}w';
    return '${(diff.inDays / 365).floor()}y';
  }

  Widget _avatar(dynamic comment, {double radius = 16}) {
    final author = _author(comment);
    final image =
        author['avatarUrl'] ?? author['profileImage'] ?? author['avatar'];

    ImageProvider? provider;

    final bytes = ApiService.dataUrlToBytes(image);
    if (bytes != null) {
      provider = MemoryImage(Uint8List.fromList(bytes));
    } else {
      final url = ApiService.normalizeImageUrl(image);
      if (url != null && url.isNotEmpty) provider = NetworkImage(url);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: _composer,
      backgroundImage: provider,
      onBackgroundImageError: provider == null ? null : (_, __) {},
      child: provider == null
          ? Icon(Icons.person, size: radius * 1.2, color: _muted)
          : null,
    );
  }

  // ------------------------------------------------------------
  // TREE
  // ------------------------------------------------------------

  Widget _buildCommentTree(dynamic comment, {int depth = 0}) {
    if (comment is! Map) return const SizedBox.shrink();

    final replies = comment['replies'] is List
        ? List<dynamic>.from(comment['replies'] as List)
        : <dynamic>[];

    final mine = _isMine(comment);
    final time = _timeAgo(comment['createdAt']);
    final edited = comment['updatedAt'] != null &&
        comment['createdAt'] != null &&
        comment['updatedAt'].toString() != comment['createdAt'].toString();

    final row = Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(comment, radius: depth == 0 ? 17 : 14),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: mine ? () => _showOptionsModal(comment) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _displayName(comment),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: _text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '@${_username(comment)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: _muted),
                        ),
                      ),
                      if (time.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '· $time',
                          style: TextStyle(fontSize: 12.5, color: _muted),
                        ),
                      ],
                      const Spacer(),
                      if (mine)
                        GestureDetector(
                          onTap: () => _showOptionsModal(comment),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _boldIcon(
                              Icons.more_horiz,
                              _muted,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    comment['content']?.toString() ?? '',
                    style: TextStyle(fontSize: 14.5, height: 1.3, color: _text),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _startReply(comment),
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _muted,
                          ),
                        ),
                      ),
                      if (edited) ...[
                        const SizedBox(width: 12),
                        Text(
                          'Edited',
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (replies.isEmpty) return row;

    // Replies are indented with a tree line; indentation stops growing
    // after 3 levels so deep threads stay readable.
    final indentReplies = depth < 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        Padding(
          padding: EdgeInsets.only(left: indentReplies ? 16 : 0),
          child: Container(
            padding: EdgeInsets.only(left: indentReplies ? 12 : 0),
            decoration: indentReplies
                ? BoxDecoration(
                    border: Border(
                      left: BorderSide(color: _divider, width: 2),
                    ),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final reply in replies)
                  _buildCommentTree(reply, depth: depth + 1),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final inputMode = _editingComment != null || _replyingToComment != null;

    return Material(
      color: _surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: _divider,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Comments',
                        style: TextStyle(
                          color: _text,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: _boldIcon(Icons.close, _text),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: _divider),
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: _accent,
                          strokeWidth: 2.4,
                        ),
                      )
                    : _comments.isEmpty
                        ? Center(
                            child: Text(
                              'No comments yet. Start the conversation.',
                              style: TextStyle(color: _muted),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                            itemCount: _comments.length,
                            itemBuilder: (context, index) =>
                                _buildCommentTree(_comments[index]),
                          ),
              ),
              if (inputMode)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: _composer,
                  child: Row(
                    children: [
                      Icon(
                        _editingComment != null ? Icons.edit : Icons.reply,
                        size: 15,
                        color: _accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _editingComment != null
                              ? 'Editing comment'
                              : 'Replying to @${_username(_replyingToComment)}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: _text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _cancelInputMode,
                        child: Icon(Icons.close, size: 17, color: _text),
                      ),
                    ],
                  ),
                ),
              Divider(height: 1, color: _divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLength: 300,
                        maxLines: 4,
                        minLines: 1,
                        cursorColor: _accent,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(color: _text),
                        decoration: InputDecoration(
                          hintText: _editingComment != null
                              ? 'Edit your comment...'
                              : _replyingToComment == null
                                  ? 'Add a comment...'
                                  : 'Add your reply...',
                          hintStyle: TextStyle(color: _muted),
                          counterText: '',
                          filled: true,
                          fillColor: _composer,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sending ? null : _sendComment,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: _accent,
                          shape: BoxShape.circle,
                        ),
                        child: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _editingComment != null
                                    ? Icons.check
                                    : Icons.arrow_upward,
                                color: Colors.white,
                                size: 22,
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
  }
}