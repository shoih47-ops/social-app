import 'dart:async';

import 'package:flutter/material.dart';

import '../services/user_search_service.dart';
import '../widgets/user_search_result_tile.dart';
import 'user_profile_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final UserSearchService _searchService = UserSearchService();
  Timer? _debounce;
  List<UserSearchResult> _results = const [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;
  int _searchGeneration = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      _searchGeneration++;
      setState(() {
        _results = const [];
        _isLoading = false;
        _hasSearched = false;
        _errorMessage = null;
      });
      return;
    }

    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _search(trimmedQuery),
    );
  }

  Future<void> _search(String query) async {
    final generation = ++_searchGeneration;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _searchService.searchUsers(query);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = results;
        _isLoading = false;
        _hasSearched = true;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = const [];
        _isLoading = false;
        _hasSearched = true;
        _errorMessage = 'Could not search users. Please try again.';
      });
    }
  }

  void _openProfile(UserSearchResult user) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: user.userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        title: const Text('Search Users'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                onSubmitted: (query) {
                  _debounce?.cancel();
                  if (query.trim().isNotEmpty) _search(query.trim());
                },
                decoration: InputDecoration(
                  hintText: 'Search by name or username',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            _onQueryChanged('');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }
    if (_hasSearched && _results.isEmpty) {
      return const Center(
        child: Text(
          'No users found',
          style: TextStyle(color: Color(0xFF6B6475), fontSize: 16),
        ),
      );
    }
    if (!_hasSearched) {
      return const Center(
        child: Text(
          'Find people by name or username',
          style: TextStyle(color: Color(0xFF6B6475)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final user = _results[index];
        return UserSearchResultTile(
          user: user,
          onTap: () => _openProfile(user),
        );
      },
    );
  }
}
