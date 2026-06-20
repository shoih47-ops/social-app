import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserSearchResult {
  final String userId;
  final String displayName;
  final String username;
  final String bio;
  final String photoUrl;

  const UserSearchResult({
    required this.userId,
    required this.displayName,
    required this.username,
    required this.bio,
    required this.photoUrl,
  });
}

class UserSearchService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  List<UserSearchResult>? _cachedUsers;

  UserSearchService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  Future<List<UserSearchResult>> searchUsers(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return const [];

    final users = _cachedUsers ??= await _loadUsers();
    final matches = users.where((user) {
      return user.displayName.toLowerCase().contains(normalizedQuery) ||
          user.username.toLowerCase().contains(normalizedQuery);
    }).toList();

    matches.sort((a, b) {
      final aStarts = _startsWithQuery(a, normalizedQuery);
      final bStarts = _startsWithQuery(b, normalizedQuery);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return matches;
  }

  Future<List<UserSearchResult>> _loadUsers() async {
    final snapshot = await _firestore.collection('users').get();
    final currentUserId = _auth.currentUser?.uid;

    return snapshot.docs
        .where((doc) => doc.id != currentUserId)
        .map((doc) {
          final data = doc.data();
          final username = _text(data['username']);
          final displayName = _firstText([
            data['displayName'],
            data['name'],
            data['fullName'],
            username,
          ]);
          return UserSearchResult(
            userId: doc.id,
            displayName: displayName,
            username: username,
            bio: _text(data['bio']),
            photoUrl: _firstText([data['photoUrl'], data['photo']]),
          );
        })
        .where(
          (user) => user.displayName.isNotEmpty || user.username.isNotEmpty,
        )
        .toList();
  }

  bool _startsWithQuery(UserSearchResult user, String query) {
    return user.displayName.toLowerCase().startsWith(query) ||
        user.username.toLowerCase().startsWith(query);
  }

  String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = _text(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _text(dynamic value) => value is String ? value.trim() : '';
}
