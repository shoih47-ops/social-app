part of '../../screens/create_post_screen.dart';

class CategorySelector extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return _ChoiceSelector(
      title: 'Category',
      options: options,
      selectedValue: selectedValue,
      onSelected: onSelected,
    );
  }
}
