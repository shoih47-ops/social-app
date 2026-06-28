import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../screens/profile_screen.dart';
import '../../screens/user_profile_screen.dart';

class FeaturedPeopleSection extends StatefulWidget {
  final String profileUserId;

  const FeaturedPeopleSection({
    super.key,
    required this.profileUserId,
  });

  @override
  State<FeaturedPeopleSection> createState() =>
      _FeaturedPeopleSectionState();
}

class _FeaturedPeopleSectionState extends State<FeaturedPeopleSection> {
  static const int _previewCount = 5;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _taggedPostsSubscription;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _taggedPosts = const [];
  List<_FeaturedPerson> _people = const [];
  int _subscriptionGeneration = 0;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _listenToPosts();
  }

  @override
  void didUpdateWidget(FeaturedPeopleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileUserId != widget.profileUserId) {
      _listenToPosts();
    }
  }

  @override
  void dispose() {
    _taggedPostsSubscription?.cancel();
    super.dispose();
  }

  void _listenToPosts() {
    _taggedPostsSubscription?.cancel();
    _taggedPosts = const [];
    final subscriptionGeneration = ++_subscriptionGeneration;
    ++_loadGeneration;
    _taggedPostsSubscription = FirebaseFirestore.instance
        .collection('posts')
        .where('taggedUserIds', arrayContains: widget.profileUserId)
        .snapshots()
        .listen(
          (snapshot) {
            if (subscriptionGeneration != _subscriptionGeneration) return;
            _taggedPosts = snapshot.docs;
            _loadPeople(++_loadGeneration);
          },
          onError: (_) {
            if (mounted &&
                subscriptionGeneration == _subscriptionGeneration) {
              ++_loadGeneration;
              setState(() => _people = const []);
            }
          },
        );
  }

  Future<void> _loadPeople(int generation) async {
    final counts = <String, int>{};

    for (final post in _taggedPosts) {
      final data = post.data();
      final rawIds = data['taggedUserIds'];
      final uniqueIds = rawIds is List
          ? rawIds
              .map((id) => id.toString().trim())
              .where((id) => id.isNotEmpty)
              .toSet()
          : <String>{};
      if (!uniqueIds.remove(widget.profileUserId)) continue;

      for (final userId in uniqueIds) {
        counts.update(userId, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    if (counts.isEmpty) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _people = const []);
      }
      return;
    }

    List<DocumentSnapshot<Map<String, dynamic>>> documents;
    try {
      documents = await Future.wait(
        counts.keys.map(
          (userId) => FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get(),
        ),
      );
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _people = const []);
      }
      return;
    }
    if (!mounted || generation != _loadGeneration) return;

    final people = documents
        .where((document) => document.exists)
        .map((document) {
          final data = document.data() ?? const <String, dynamic>{};
          final name = _firstText([
            data['displayName'],
            data['name'],
            data['fullName'],
            data['username'],
          ]);
          return _FeaturedPerson(
            userId: document.id,
            name: name.isEmpty ? 'User' : name,
            photoUrl: _firstText([data['photoUrl'], data['photo']]),
            momentCount: counts[document.id] ?? 0,
          );
        })
        .toList()
      ..sort((first, second) {
        final countOrder = second.momentCount.compareTo(first.momentCount);
        if (countOrder != 0) return countOrder;
        return first.name.toLowerCase().compareTo(second.name.toLowerCase());
      });

    setState(() => _people = people);
  }

  String _firstText(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  void _openProfile(_FeaturedPerson person) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => person.userId == currentUserId
            ? ProfileScreen(userId: person.userId)
            : UserProfileScreen(userId: person.userId),
      ),
    );
  }

  void _viewAll() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AllFeaturedPeopleScreen(
          profileUserId: widget.profileUserId,
          people: _people,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_people.isEmpty) return const SizedBox.shrink();
    final preview = _people.take(_previewCount).toList();
    final remainingCount = _people.length - preview.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFCFAFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDE7F6)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Featured People',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _viewAll,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final person in preview)
                    Expanded(
                      child: _FeaturedPersonAvatar(
                        person: person,
                        onTap: () => _openProfile(person),
                      ),
                    ),
                  if (remainingCount > 0)
                    Expanded(
                      child: _FeaturedPeopleOverflow(
                        count: remainingCount,
                        onTap: _viewAll,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedPersonAvatar extends StatelessWidget {
  final _FeaturedPerson person;
  final VoidCallback onTap;

  const _FeaturedPersonAvatar({required this.person, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = person.photoUrl.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFEDE9FE),
              backgroundImage: hasPhoto ? NetworkImage(person.photoUrl) : null,
              child: hasPhoto
                  ? null
                  : const Icon(
                      Icons.person,
                      size: 20,
                      color: Color(0xFF8B5CF6),
                    ),
            ),
            const SizedBox(height: 5),
            Text(
              person.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedPeopleOverflow extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _FeaturedPeopleOverflow({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFEDE9FE),
              child: Text(
                '+$count',
                style: const TextStyle(
                  color: Color(0xFF6D28D9),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'More',
              maxLines: 1,
              style: TextStyle(
                color: Color(0xFF6D28D9),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedPersonRow extends StatelessWidget {
  final _FeaturedPerson person;
  final VoidCallback onTap;

  const _FeaturedPersonRow({required this.person, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = person.photoUrl.isNotEmpty;
    final momentLabel = person.momentCount == 1 ? 'moment' : 'moments';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFEDE9FE),
              backgroundImage: hasPhoto ? NetworkImage(person.photoUrl) : null,
              child: hasPhoto
                  ? null
                  : const Icon(Icons.person, color: Color(0xFF8B5CF6)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${person.momentCount} $momentLabel',
                    style: const TextStyle(
                      color: Color(0xFF7C3AED),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}

class _AllFeaturedPeopleScreen extends StatelessWidget {
  final String profileUserId;
  final List<_FeaturedPerson> people;

  const _AllFeaturedPeopleScreen({
    required this.profileUserId,
    required this.people,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        title: const Text('Featured People'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        itemCount: people.length,
        itemBuilder: (context, index) {
          final person = people[index];
          return _FeaturedPersonRow(
            person: person,
            onTap: () {
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => person.userId == currentUserId
                      ? ProfileScreen(userId: person.userId)
                      : UserProfileScreen(userId: person.userId),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FeaturedPerson {
  final String userId;
  final String name;
  final String photoUrl;
  final int momentCount;

  const _FeaturedPerson({
    required this.userId,
    required this.name,
    required this.photoUrl,
    required this.momentCount,
  });
}
