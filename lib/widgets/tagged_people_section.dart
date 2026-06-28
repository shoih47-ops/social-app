import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/profile_screen.dart';
import '../screens/user_profile_screen.dart';

class TaggedPeopleSection extends StatefulWidget {
  final List<String> userIds;
  final bool compact;

  const TaggedPeopleSection({
    super.key,
    required this.userIds,
    this.compact = false,
  });

  @override
  State<TaggedPeopleSection> createState() => _TaggedPeopleSectionState();
}

class _TaggedPeopleSectionState extends State<TaggedPeopleSection> {
  late Future<List<_TaggedPerson>> _people;

  @override
  void initState() {
    super.initState();
    _people = _loadPeople();
  }

  @override
  void didUpdateWidget(TaggedPeopleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.compact != widget.compact ||
        !_sameIds(oldWidget.userIds, widget.userIds)) {
      _people = _loadPeople();
    }
  }

  bool _sameIds(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  Future<List<_TaggedPerson>> _loadPeople() async {
    final uniqueIds = _uniqueIds;
    final idsToLoad = widget.compact ? uniqueIds.take(3) : uniqueIds;
    final documents = await Future.wait(
      idsToLoad.map(
        (id) => FirebaseFirestore.instance.collection('users').doc(id).get(),
      ),
    );

    return documents.where((document) => document.exists).map((document) {
      final data = document.data() ?? const <String, dynamic>{};
      final name = _firstText([
        data['displayName'],
        data['name'],
        data['fullName'],
        data['username'],
      ]);
      return _TaggedPerson(
        userId: document.id,
        name: name.isEmpty ? 'User' : name,
        photoUrl: _firstText([data['photoUrl'], data['photo']]),
      );
    }).toList();
  }

  List<String> get _uniqueIds => widget.userIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();

  String _firstText(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  void _openProfile(_TaggedPerson person) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final page = person.userId == currentUserId
        ? ProfileScreen(userId: person.userId)
        : UserProfileScreen(userId: person.userId);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userIds.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<List<_TaggedPerson>>(
      future: _people,
      builder: (context, snapshot) {
        final people = snapshot.data ?? const <_TaggedPerson>[];
        if (people.isEmpty) return const SizedBox.shrink();

        if (widget.compact) {
          final namedPeople = people.take(2).toList();
          final remainingCount = _uniqueIds.length - namedPeople.length;
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _TaggedAvatarStack(
                  people: people.take(3).toList(),
                  onPressed: _openProfile,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (
                        var index = 0;
                        index < namedPeople.length;
                        index++
                      ) ...[
                        if (index > 0)
                          const Text(
                            ', ',
                            style: TextStyle(color: Color(0xFF625B68)),
                          ),
                        InkWell(
                          onTap: () => _openProfile(namedPeople[index]),
                          borderRadius: BorderRadius.circular(4),
                          child: Text(
                            namedPeople[index].name,
                            style: const TextStyle(
                              color: Color(0xFF5B21B6),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      if (remainingCount > 0)
                        Text(
                          ' +$remainingCount others',
                          style: const TextStyle(
                            color: Color(0xFF625B68),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: people.map((person) {
              final hasPhoto = person.photoUrl.isNotEmpty;
              return ActionChip(
                onPressed: () => _openProfile(person),
                avatar: CircleAvatar(
                  radius: 12,
                  backgroundColor: const Color(0xFFEDE9FE),
                  backgroundImage: hasPhoto
                      ? NetworkImage(person.photoUrl)
                      : null,
                  child: hasPhoto
                      ? null
                      : const Icon(
                          Icons.person,
                          size: 14,
                          color: Color(0xFF6D28D9),
                        ),
                ),
                label: Text(person.name),
                labelStyle: const TextStyle(
                  color: Color(0xFF5B21B6),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: const Color(0xFFF3E8FF),
                side: const BorderSide(color: Color(0xFFD8C7FF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _TaggedAvatarStack extends StatelessWidget {
  final List<_TaggedPerson> people;
  final ValueChanged<_TaggedPerson> onPressed;

  const _TaggedAvatarStack({
    required this.people,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const avatarSize = 28.0;
    const overlapOffset = 18.0;

    return SizedBox(
      width: avatarSize + (people.length - 1) * overlapOffset,
      height: avatarSize,
      child: Stack(
        children: [
          for (var index = 0; index < people.length; index++)
            Positioned(
              left: index * overlapOffset,
              child: GestureDetector(
                onTap: () => onPressed(people[index]),
                child: Container(
                  width: avatarSize,
                  height: avatarSize,
                  padding: const EdgeInsets.all(1.5),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFFEDE9FE),
                    backgroundImage: people[index].photoUrl.isNotEmpty
                        ? NetworkImage(people[index].photoUrl)
                        : null,
                    child: people[index].photoUrl.isNotEmpty
                        ? null
                        : const Icon(
                            Icons.person,
                            size: 15,
                            color: Color(0xFF6D28D9),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaggedPerson {
  final String userId;
  final String name;
  final String photoUrl;

  const _TaggedPerson({
    required this.userId,
    required this.name,
    required this.photoUrl,
  });
}
