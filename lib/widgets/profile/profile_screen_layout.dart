import 'package:flutter/material.dart';

import 'profile_background.dart';

/// Shared profile body: background + scroll content (+ optional cover actions).
/// Used by [ProfileScreen] and [UserProfileScreen].
class ProfileScreenLayout extends StatelessWidget {
  final String coverUrl;
  final Widget content;
  final Widget? coverActions;

  const ProfileScreenLayout({
    super.key,
    required this.coverUrl,
    required this.content,
    this.coverActions,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ProfileBackground(coverUrl: coverUrl),
        SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(children: [const SizedBox(height: 150), content]),
          ),
        ),
        ?coverActions,
      ],
    );
  }
}
