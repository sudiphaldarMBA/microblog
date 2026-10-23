
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;
  final VoidCallback? onCommentAdded;

  const CommentsSheet({
    super.key,
    required this.postId,
    this.onCommentAdded,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _comments = [];
  bool _loading = true;
  bool _sending = false;

  Map<String, dynamic>? _replyingToComment;
  Map<String, dynamic>? _editingComment;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() => _loading = true);
    }

    try {
      final result = await ApiService.getComments(
        postId: widget.postId,
      );

      if (!mounted) return;

      final data = result['data'];
      final rawComments = data is Map ? data['comments'] : null;

      if (result['success'] == true && rawComments is List) {
        setState(() {
          _comments = _buildCommentTreeFromResponse(rawComments);
        });
      } else {
        _showErrorSnackBar(
          result['message']?.toString() ?? 'Unable to load comments',
        );
      }
    } catch (_) {
      if (mounted) {
        _showErrorSnackBar('Unable to load comments');
      }
    } finally {
      if (mounted && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  String? _idString(dynamic value) {
    if (value == null) return null;

    if (value is Map) {
      return _idString(value['_id'] ?? value['id']);
    }

    final text = value.toString().trim();

    if (text.isEmpty || text == 'null') {
      return null;
    }

    return text;
  }

  List<dynamic> _buildCommentTreeFromResponse(List rawComments) {
    final flat = <Map<String, dynamic>>[];

    void collect(
      dynamic value, {
      String? inheritedParentId,
    }) {
      if (value is! Map) return;

      final item = Map<String, dynamic>.from(value);
      final id = _idString(item['_id']);

      final explicitParentId = _idString(
        item['parentComment'] ?? item['parentId'],
      );

      final parentId = explicitParentId ?? inheritedParentId;

      final children = item['replies'] is List
          ? List<dynamic>.from(item['replies'] as List)
          : <dynamic>[];

      item.remove('replies');

      if (parentId != null) {
        item['parentComment'] = parentId;
      }

      item['replies'] = <dynamic>[];
      flat.add(item);

      final childParentId = id ?? parentId;

      for (final child in children) {
        collect(
          child,
          inheritedParentId: childParentId,
        );
      }
    }

    for (final comment in rawComments) {
      collect(comment);
    }

    final byId = <String, Map<String, dynamic>>{};

    for (final comment in flat) {
      final id = _idString(comment['_id']);

      if (id != null) {
        byId[id] = comment;
      }
    }

    final roots = <dynamic>[];

    for (final comment in flat) {
      final parentId = _idString(
        comment['parentComment'] ?? comment['parentId'],
      );

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

  Future<void> _sendComment() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _sending) return;

    if (_editingComment != null &&
        _idString(_editingComment!['_id']) == null) {
      _showErrorSnackBar('Unable to identify this comment');
      return;
    }

    setState(() => _sending = true);

    try {
      dynamic result;

      if (_editingComment != null) {
        result = await ApiService.updateComment(
          commentId: _idString(_editingComment!['_id'])!,
          content: text,
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
        _showErrorSnackBar(
          result['message']?.toString() ?? 'Operation failed',
        );
      }
    } catch (_) {
      if (mounted) {
        _showErrorSnackBar('An error occurred');
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      final result = await ApiService.deleteComment(
        commentId: commentId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        await _loadComments();
        widget.onCommentAdded?.call();
      } else {
        _showErrorSnackBar(
          result['message']?.toString() ?? 'Unable to delete comment',
        );
      }
    } catch (_) {
      if (mounted) {
        _showErrorSnackBar('An error occurred while deleting');
      }
    }
  }

  void _showOptionsModal(dynamic comment) {
    if (comment is! Map) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final id = _idString(comment['_id']);

    if (id == null) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? Colors.black : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.edit_outlined,
                  color: isDark ? Colors.white : Colors.black,
                ),
                title: Text(
                  'Edit Comment',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);

                  if (!mounted) return;

                  setState(() {
                    _editingComment = Map<String, dynamic>.from(comment);
                    _replyingToComment = null;
                    _controller.text =
                        comment['content']?.toString() ?? '';
                  });
                },
              ),
              Divider(
                height: 1,
                color: isDark ? Colors.white24 : Colors.black12,
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Delete Comment',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDeleteComment(id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteComment(String commentId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF16181C) : Colors.white,
          title: Text(
            'Delete comment?',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            'This action cannot be undone.',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
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

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Map<String, dynamic> _author(dynamic comment) {
    if (comment is Map && comment['author'] is Map) {
      return Map<String, dynamic>.from(comment['author']);
    }

    return {};
  }

  String _username(dynamic comment) {
    return _author(comment)['username']?.toString() ?? 'user';
  }

  String _displayName(dynamic comment) {
    return _author(comment)['displayName']?.toString().trim().isNotEmpty ==
            true
        ? _author(comment)['displayName'].toString().trim()
        : _username(comment);
  }

  Widget _avatar(dynamic comment, {double radius = 16}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final author = _author(comment);

    final image = author['avatarUrl'] ??
        author['profileImage'] ??
        author['avatar'];

    if (image != null && image.toString().trim().isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: isDark ? Colors.white12 : Colors.black12,
        backgroundImage: NetworkImage(image.toString()),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: isDark ? Colors.white12 : Colors.black12,
      child: Icon(
        Icons.person,
        size: radius * 1.2,
        color: isDark ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildCommentTree(
    dynamic comment, {
    double indent = 0,
    int depth = 0,
  }) {
    if (comment is! Map) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color subColor = isDark ? Colors.white60 : Colors.black54;
    final Color treeLineColor = isDark ? Colors.white24 : Colors.black12;

    final replies = comment['replies'] is List
        ? List<dynamic>.from(comment['replies'] as List)
        : <dynamic>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: indent,
            top: 8,
            bottom: 4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (depth > 0)
                Container(
                  width: 2,
                  height: 38,
                  margin: const EdgeInsets.only(
                    right: 8,
                    left: 4,
                  ),
                  color: treeLineColor,
                ),
              _avatar(comment),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onLongPress: () => _showOptionsModal(comment),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _displayName(comment),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: textColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '@${_username(comment)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: subColor,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Comment options',
                            icon: Icon(
                              Icons.more_horiz,
                              size: 18,
                              color: subColor,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: () => _showOptionsModal(comment),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        comment['content']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _startReply(comment),
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: subColor,
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
        ...replies.map(
          (reply) => _buildCommentTree(
            reply,
            indent: indent + 16,
            depth: depth + 1,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgSurface = isDark ? Colors.black : Colors.white;
    final Color elementColor = isDark ? Colors.white : Colors.black;
    final Color invertElementColor = isDark ? Colors.black : Colors.white;
    final Color borderLine = isDark ? Colors.white12 : Colors.black12;

    return Scaffold(
      backgroundColor: bgSurface,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: bgSurface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Comments',
          style: TextStyle(
            color: elementColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: elementColor),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: borderLine,
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: elementColor,
                        strokeWidth: 2,
                      ),
                    )
                  : _comments.isEmpty
                      ? Center(
                          child: Text(
                            'No comments yet.',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white60
                                  : Colors.black54,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            return _buildCommentTree(_comments[index]);
                          },
                        ),
            ),

            // Replying/editing status.
            if (_replyingToComment != null || _editingComment != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: isDark ? Colors.white10 : Colors.black12,
                child: Row(
                  children: [
                    Icon(
                      _editingComment != null
                          ? Icons.edit
                          : Icons.reply,
                      size: 14,
                      color: elementColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _editingComment != null
                            ? 'Editing comment...'
                            : 'Replying to @${_username(_replyingToComment)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: elementColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _cancelInputMode,
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: elementColor,
                      ),
                    ),
                  ],
                ),
              ),

            Container(
              color: borderLine,
              height: 1,
            ),

            // Comment/reply composer.
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: 300,
                      maxLines: 3,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(color: elementColor),
                      decoration: InputDecoration(
                        hintText: _editingComment != null
                            ? 'Edit your comment...'
                            : _replyingToComment == null
                                ? 'Add a comment...'
                                : 'Add your reply...',
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white38
                              : Colors.black38,
                        ),
                        counterText: '',
                        filled: true,
                        fillColor:
                            isDark ? Colors.white10 : Colors.black12,
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
                  IconButton(
                    tooltip: _editingComment != null
                        ? 'Save comment'
                        : 'Send comment',
                    onPressed: _sending ? null : _sendComment,
                    icon: CircleAvatar(
                      backgroundColor: elementColor,
                      child: _sending
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: invertElementColor,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              Icons.arrow_upward,
                              color: invertElementColor,
                              size: 18,
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
  }
}
