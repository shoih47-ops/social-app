import 'package:flutter/material.dart';
import 'comment_tile.dart';
import 'reply_tile.dart';

class CommentWithReplies extends StatefulWidget {
  final Widget commentTile;
  final Widget repliesWidget;

  const CommentWithReplies({
    super.key,
    required this.commentTile,
    required this.repliesWidget,
  });

  @override
  State<CommentWithReplies> createState() => _CommentWithRepliesState();
}

class _CommentWithRepliesState extends State<CommentWithReplies> {
  bool showReplies = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        widget.commentTile,

        TextButton(
          onPressed: () {
            setState(() {
              showReplies = !showReplies;
            });
          },

          child: Text(showReplies ? "Hede replies" : "View replies"),
        ),

        if (showReplies) widget.repliesWidget,
      ],
    );
  }
}
