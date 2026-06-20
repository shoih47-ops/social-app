import 'package:flutter/material.dart';

import 'profile_background.dart';

/// Shared profile body: background + scroll content (+ optional cover actions).
/// Used by [ProfileScreen] and [UserProfileScreen].
class ProfileScreenLayout extends StatelessWidget {
  final String coverUrl;
  final Widget content;
  final Widget? coverActions;
  final VoidCallback? onCoverTap;
  final ScrollController? scrollController;

  const ProfileScreenLayout({
    super.key,
    required this.coverUrl,
    required this.content,
    this.coverActions,
    this.onCoverTap,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return SingleChildScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ProfileBackground(coverUrl: coverUrl, onTap: onCoverTap),
          ?coverActions,
          Padding(
            padding: EdgeInsets.only(top: topInset + 150),
            child: content,
          ),
        ],
      ),
    );
  }
}
