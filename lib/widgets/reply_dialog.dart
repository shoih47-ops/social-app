import 'package:flutter/material.dart';

class ReplyDialog extends StatefulWidget {
  final String username;
  final void Function(String text) onSend;

  const ReplyDialog({
    super.key,
    required this.username,
    required this.onSend,
  });

  @override
  State<ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<ReplyDialog> {
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

  void _handleSend() {
    widget.onSend(_controller.text.trim());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Reply to ${widget.username}"),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(hintText: "Write your reply..."),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: _handleSend,
          child: const Text("Send"),
        ),
      ],
    );
  }
}
