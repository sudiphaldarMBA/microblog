import 'package:flutter/material.dart';

class RepostModalSheet extends StatefulWidget {
  final Color surfaceColor;
  final Color textColor;
  final Color mutedColor;
  final Color composerColor;

  const RepostModalSheet({
    super.key,
    required this.surfaceColor,
    required this.textColor,
    required this.mutedColor,
    required this.composerColor,
  });

  @override
  State<RepostModalSheet> createState() => _RepostModalSheetState();
}

class _RepostModalSheetState extends State<RepostModalSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 18,
        bottom: bottomPadding + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ------------------------------------------------------
          // HEADER
          // ------------------------------------------------------
          Row(
            children: [
              Expanded(
                child: Text(
                  'Repost',
                  style: TextStyle(
                    color: widget.textColor,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.of(context).pop(null);
                },
                icon: Icon(Icons.close_rounded, color: widget.textColor),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ------------------------------------------------------
          // DESCRIPTION
          // ------------------------------------------------------
          Text(
            'Add your thoughts to this repost',
            style: TextStyle(color: widget.mutedColor, fontSize: 13),
          ),

          const SizedBox(height: 14),

          // ------------------------------------------------------
          // REPOST CAPTION
          // ------------------------------------------------------
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 500,
            maxLines: 5,
            style: TextStyle(color: widget.textColor, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'What do you think?',
              hintStyle: TextStyle(color: widget.mutedColor),
              filled: true,
              fillColor: widget.composerColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),

          const SizedBox(height: 8),

          // ------------------------------------------------------
          // REPOST BUTTON
          // ------------------------------------------------------
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () {
                final String caption = _controller.text.trim();

                Navigator.of(context).pop(caption);
              },
              child: const Text(
                'Repost',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
