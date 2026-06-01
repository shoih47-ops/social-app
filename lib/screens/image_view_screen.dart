import 'package:flutter/material.dart';

class ImageViewScreen extends StatelessWidget {
  final String imageUrl;

  const ImageViewScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: InteractiveViewer(child: Image.network(imageUrl))),
    );
  }
}
