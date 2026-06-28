part of '../../screens/create_post_screen.dart';

class PeopleSelector extends StatelessWidget {
  final List<UserSearchResult> selectedPeople;
  final ValueChanged<List<UserSearchResult>> onChanged;

  const PeopleSelector({
    super.key,
    required this.selectedPeople,
    required this.onChanged,
  });

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<List<UserSearchResult>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8F8FA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PeoplePickerSheet(initialSelection: selectedPeople),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.people_outline,
              size: 19,
              color: Colors.deepPurple.shade700,
            ),
            const SizedBox(width: 7),
            Text(
              'People in this Moment',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.deepPurple.shade700,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _openPicker(context),
              icon: Icon(
                selectedPeople.isEmpty ? Icons.add : Icons.edit_outlined,
                size: 18,
              ),
              label: Text(selectedPeople.isEmpty ? 'Add people' : 'Edit'),
            ),
          ],
        ),
        if (selectedPeople.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedPeople.map((person) {
              final name = person.displayName.isEmpty
                  ? person.username
                  : person.displayName;
              return InputChip(
                label: Text(name),
                onDeleted: () {
                  onChanged(
                    selectedPeople
                        .where((item) => item.userId != person.userId)
                        .toList(),
                  );
                },
                labelStyle: const TextStyle(
                  color: Color(0xFF5B21B6),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                deleteIconColor: const Color(0xFF6D28D9),
                backgroundColor: const Color(0xFFF3E8FF),
                side: const BorderSide(color: Color(0xFFD8C7FF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _PeoplePickerSheet extends StatefulWidget {
  final List<UserSearchResult> initialSelection;

  const _PeoplePickerSheet({required this.initialSelection});

  @override
  State<_PeoplePickerSheet> createState() => _PeoplePickerSheetState();
}

class _PeoplePickerSheetState extends State<_PeoplePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final UserSearchService _searchService = UserSearchService();
  late final Map<String, UserSearchResult> _selected;
  Timer? _debounce;
  List<UserSearchResult> _results = const [];
  bool _isLoading = false;
  bool _hasSearched = false;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _selected = {
      for (final person in widget.initialSelection) person.userId: person,
    };
  }

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
    setState(() => _isLoading = true);
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
      });
    }
  }

  void _toggle(UserSearchResult person) {
    setState(() {
      if (_selected.containsKey(person.userId)) {
        _selected.remove(person.userId);
      } else {
        _selected[person.userId] = person;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'People in this Moment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5B21B6),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _selected.values.toList(),
                    ),
                    child: Text('Done (${_selected.length})'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Search by name or username',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_hasSearched) {
      return const Center(child: Text('Search for people to add'));
    }
    if (_results.isEmpty) {
      return const Center(child: Text('No users found'));
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final person = _results[index];
        final selected = _selected.containsKey(person.userId);
        final name = person.displayName.isEmpty
            ? person.username
            : person.displayName;
        return CheckboxListTile(
          value: selected,
          onChanged: (_) => _toggle(person),
          activeColor: const Color(0xFF8B5CF6),
          secondary: CircleAvatar(
            backgroundColor: const Color(0xFFEDE9FE),
            backgroundImage: person.photoUrl.isEmpty
                ? null
                : NetworkImage(person.photoUrl),
            child: person.photoUrl.isEmpty
                ? const Icon(Icons.person, color: Color(0xFF8B5CF6))
                : null,
          ),
          title: Text(name),
          subtitle: person.username.isEmpty
              ? null
              : Text('@${person.username}'),
        );
      },
    );
  }
}
