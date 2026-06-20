import 'package:flutter/material.dart';

import '../services/user_search_service.dart';

class UserSearchResultTile extends StatelessWidget {
  final UserSearchResult user;
  final VoidCallback onTap;

  const UserSearchResultTile({
    super.key,
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = user.photoUrl.isNotEmpty;
    final displayName = user.displayName.isEmpty
        ? user.username
        : user.displayName;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFEDE9FE),
                backgroundImage: hasPhoto ? NetworkImage(user.photoUrl) : null,
                child: hasPhoto
                    ? null
                    : const Icon(Icons.person, color: Color(0xFF8B5CF6)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (user.username.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@${user.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF8B5CF6)),
                      ),
                    ],
                    if (user.bio.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        user.bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6B6475),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
