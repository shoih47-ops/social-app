part of '../../screens/create_post_screen.dart';

class CategorySelector extends StatefulWidget {
  final List<String> options;
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  const CategorySelector({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  static const int _collapsedCategoryCount = 6;

  bool _isExpanded = false;

  List<String> get _visibleOptions {
    if (_isExpanded || widget.options.length <= _collapsedCategoryCount) {
      return widget.options;
    }

    final visibleOptions = widget.options
        .take(_collapsedCategoryCount)
        .toList(growable: true);
    final selectedValue = widget.selectedValue;

    if (selectedValue != null &&
        widget.options.contains(selectedValue) &&
        !visibleOptions.contains(selectedValue)) {
      visibleOptions.add(selectedValue);
    }

    return visibleOptions;
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canExpand = widget.options.length > _collapsedCategoryCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.deepPurple.shade700,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _visibleOptions.map((option) {
              final isSelected = widget.selectedValue == option;

              return ChoiceChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (_) => widget.onSelected(option),
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.deepPurple.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                selectedColor: Colors.deepPurple.shade400,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: isSelected
                      ? Colors.deepPurple.shade400
                      : Colors.deepPurple.shade300,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ),
        if (canExpand) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _toggleExpanded,
            style: TextButton.styleFrom(
              foregroundColor: Colors.deepPurple.shade600,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _isExpanded ? 'Show Less' : 'See More',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
