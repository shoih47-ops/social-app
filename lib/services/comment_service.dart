import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CommentEntry {
  final String id;
  final Map<String, dynamic> data;

  const CommentEntry({required this.id, required this.data});

  List get likes => (data['likes'] is List) ? data['likes'] : [];

  String get userId => (data['userId'] ?? '').toString();

  String get username => (data['username'] ?? 'Unknown').toString();

  String? get photoUrl {
    final value = data['photoUrl'];
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  String get text => (data['text'] ?? '').toString();

  dynamic get createdAt => data['createdAt'];
}

class ReplyEntry {
  final String id;
  final Map<String, dynamic> data;

  const ReplyEntry({required this.id, required this.data});
}

class PostCommentsNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

class CommentRepliesNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

class CommentService {
  CommentService._();

  static final CommentService instance = CommentService._();

  static const int pageSize = 20;

  final Map<String, List<CommentEntry>> _commentsByPost = {};
  final Map<String, DocumentSnapshot?> _lastCommentDoc = {};
  final Map<String, bool> _hasMoreComments = {};
  final Map<String, bool> _initialLoading = {};
  final Map<String, bool> _loadingMore = {};
  final Map<String, bool> _loadedOnce = {};
  final Map<String, StreamSubscription<QuerySnapshot>> _commentSubscriptions =
      {};
  final Map<String, PostCommentsNotifier> _postNotifiers = {};

  final Map<String, List<ReplyEntry>> _repliesByComment = {};
  final Map<String, bool> _repliesLoadedOnce = {};
  final Map<String, bool> _repliesLoading = {};
  final Map<String, StreamSubscription<QuerySnapshot>> _replySubscriptions =
      {};
  final Map<String, CommentRepliesNotifier> _replyNotifiers = {};

  CollectionReference<Map<String, dynamic>> _commentsRef(String postId) {
    return FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('comments');
  }

  CollectionReference<Map<String, dynamic>> _repliesRef(
    String postId,
    String commentId,
  ) {
    return _commentsRef(postId).doc(commentId).collection('replies');
  }

  PostCommentsNotifier notifierForPost(String postId) {
    return _postNotifiers.putIfAbsent(postId, PostCommentsNotifier.new);
  }

  CommentRepliesNotifier notifierForReplies(String commentId) {
    return _replyNotifiers.putIfAbsent(
      commentId,
      CommentRepliesNotifier.new,
    );
  }

  List<CommentEntry> commentsFor(String postId) {
    return _commentsByPost[postId] ?? const [];
  }

  bool hasCachedComments(String postId) {
    return _commentsByPost.containsKey(postId);
  }

  bool isInitialLoading(String postId) {
    return (_initialLoading[postId] ?? false) && !(_loadedOnce[postId] ?? false);
  }

  bool isLoadingMore(String postId) => _loadingMore[postId] ?? false;

  bool hasMoreComments(String postId) => _hasMoreComments[postId] ?? true;

  List<ReplyEntry> repliesFor(String commentId) {
    return _repliesByComment[commentId] ?? const [];
  }

  bool repliesAreLoading(String commentId) => _repliesLoading[commentId] ?? false;

  bool repliesLoadedOnce(String commentId) {
    return _repliesLoadedOnce[commentId] ?? false;
  }

  Future<void> ensureCommentsLoaded(String postId) async {
    if (_loadedOnce[postId] == true) {
      _startCommentsListener(postId);
      return;
    }

    if (_initialLoading[postId] == true) return;

    _initialLoading[postId] = true;
    notifierForPost(postId).refresh();

    try {
      final snapshot = await _commentsRef(postId)
          .orderBy('createdAt', descending: true)
          .limit(pageSize)
          .get();

      _commentsByPost[postId] = snapshot.docs
          .map(
            (doc) => CommentEntry(
              id: doc.id,
              data: Map<String, dynamic>.from(doc.data()),
            ),
          )
          .toList();
      _lastCommentDoc[postId] =
          snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMoreComments[postId] = snapshot.docs.length == pageSize;
      _loadedOnce[postId] = true;
    } finally {
      _initialLoading[postId] = false;
      notifierForPost(postId).refresh();
      _startCommentsListener(postId);
    }
  }

  Future<void> loadMoreComments(String postId) async {
    if (_loadingMore[postId] == true || !hasMoreComments(postId)) return;

    final lastDoc = _lastCommentDoc[postId];
    if (lastDoc == null) return;

    _loadingMore[postId] = true;
    notifierForPost(postId).refresh();

    try {
      final snapshot = await _commentsRef(postId)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(lastDoc)
          .limit(pageSize)
          .get();

      if (snapshot.docs.isEmpty) {
        _hasMoreComments[postId] = false;
        return;
      }

      final existingIds =
          _commentsByPost[postId]?.map((entry) => entry.id).toSet() ??
          <String>{};
      final appended = snapshot.docs
          .where((doc) => !existingIds.contains(doc.id))
          .map(
            (doc) => CommentEntry(
              id: doc.id,
              data: Map<String, dynamic>.from(doc.data()),
            ),
          )
          .toList();

      _commentsByPost[postId] = [
        ...?_commentsByPost[postId],
        ...appended,
      ];
      _lastCommentDoc[postId] = snapshot.docs.last;
      _hasMoreComments[postId] = snapshot.docs.length == pageSize;
    } finally {
      _loadingMore[postId] = false;
      notifierForPost(postId).refresh();
      _startCommentsListener(postId);
    }
  }

  void _startCommentsListener(String postId) {
    _commentSubscriptions[postId]?.cancel();

    final loadedCount = _commentsByPost[postId]?.length ?? 0;
    final limit = loadedCount < pageSize ? pageSize : loadedCount;

    _commentSubscriptions[postId] = _commentsRef(postId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .listen(
      (snapshot) {
        _commentsByPost[postId] = snapshot.docs
            .map(
              (doc) => CommentEntry(
                id: doc.id,
                data: Map<String, dynamic>.from(doc.data()),
              ),
            )
            .toList();
        _lastCommentDoc[postId] =
            snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMoreComments[postId] = snapshot.docs.length == limit;
        _loadedOnce[postId] = true;
        notifierForPost(postId).refresh();
      },
      onError: (_) {},
    );
  }

  Future<void> ensureRepliesLoaded(String postId, String commentId) async {
    if (_repliesLoadedOnce[commentId] == true) {
      _startRepliesListener(postId, commentId);
      return;
    }

    if (_repliesLoading[commentId] == true) return;

    _repliesLoading[commentId] = true;
    notifierForReplies(commentId).refresh();

    try {
      final snapshot = await _repliesRef(postId, commentId)
          .orderBy('createdAt')
          .get();

      _repliesByComment[commentId] = snapshot.docs
          .map(
            (doc) => ReplyEntry(
              id: doc.id,
              data: Map<String, dynamic>.from(doc.data()),
            ),
          )
          .toList();
      _repliesLoadedOnce[commentId] = true;
    } finally {
      _repliesLoading[commentId] = false;
      notifierForReplies(commentId).refresh();
      _startRepliesListener(postId, commentId);
    }
  }

  void _startRepliesListener(String postId, String commentId) {
    _replySubscriptions[commentId]?.cancel();

    _replySubscriptions[commentId] = _repliesRef(postId, commentId)
        .orderBy('createdAt')
        .snapshots()
        .listen(
      (snapshot) {
        _repliesByComment[commentId] = snapshot.docs
            .map(
              (doc) => ReplyEntry(
                id: doc.id,
                data: Map<String, dynamic>.from(doc.data()),
              ),
            )
            .toList();
        _repliesLoadedOnce[commentId] = true;
        notifierForReplies(commentId).refresh();
      },
      onError: (_) {},
    );
  }

  void stopWatchingPost(String postId) {
    _commentSubscriptions[postId]?.cancel();
    _commentSubscriptions.remove(postId);
  }

  void stopWatchingReplies(String commentId) {
    _replySubscriptions[commentId]?.cancel();
    _replySubscriptions.remove(commentId);
  }

  void disposePost(String postId) {
    stopWatchingPost(postId);
    _postNotifiers.remove(postId);
  }
}
