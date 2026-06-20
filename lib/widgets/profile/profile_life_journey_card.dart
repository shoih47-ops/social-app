import 'package:flutter/material.dart';

class ProfileLifeJourneyCard extends StatelessWidget {
  final List<Map<String, dynamic>> lifeJourney;
  final int maxItems;
  final VoidCallback? onViewAll;

  const ProfileLifeJourneyCard({
    super.key,
    required this.lifeJourney,
    this.maxItems = 2,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final items = lifeJourney
        .map(_LifeJourneyItem.fromMap)
        .where((item) => item.startYear.isNotEmpty && item.title.isNotEmpty)
        .toList()
      ..sort((a, b) => b.startYearValue.compareTo(a.startYearValue));

    if (items.isEmpty) return const SizedBox.shrink();

    final visibleItems = items.take(maxItems).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Life Journey',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: onViewAll ??
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Full Life Journey coming soon'),
                        ),
                      );
                    },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6D4CFF),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (int index = 0; index < visibleItems.length; index++) ...[
            _LifeJourneyTile(item: visibleItems[index]),
            if (index != visibleItems.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _LifeJourneyTile extends StatelessWidget {
  final _LifeJourneyItem item;

  const _LifeJourneyTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.icon} ${item.yearRange}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LifeJourneyItem {
  final String startYear;
  final String endYear;
  final String title;
  final String category;
  final bool isOngoing;

  const _LifeJourneyItem({
    required this.startYear,
    required this.endYear,
    required this.title,
    required this.category,
    required this.isOngoing,
  });

  String get yearRange {
    if (isOngoing || endYear.isEmpty) return '$startYear - Present';
    return '$startYear - $endYear';
  }

  int get startYearValue => int.tryParse(startYear) ?? 0;

  String get icon {
    switch (category) {
      case 'Work':
        return '💼';
      case 'Education':
        return '🎓';
      case 'Project':
        return '🚀';
      case 'Achievement':
        return '🏆';
      case 'Personal':
        return '👤';
      case 'Travel':
        return '✈️';
      case 'Family':
        return '👨‍👩‍👧';
      default:
        return '📌';
    }
  }

  factory _LifeJourneyItem.fromMap(Map<String, dynamic> data) {
    final startYear = (data['startYear'] ?? data['year'] ?? '')
        .toString()
        .trim();
    final endYear = (data['endYear'] ?? '').toString().trim();

    return _LifeJourneyItem(
      startYear: startYear,
      endYear: endYear,
      title: (data['title'] ?? '').toString().trim(),
      category: _normalizeCategory(data['category']),
      isOngoing: data['isOngoing'] == true ||
          data['ongoing'] == true ||
          (endYear.isEmpty && startYear.isNotEmpty),
    );
  }

  static String _normalizeCategory(dynamic value) {
    final category = (value ?? '').toString().trim();
    const categories = {
      'Work',
      'Education',
      'Project',
      'Achievement',
      'Personal',
      'Travel',
      'Family',
      'Other',
    };
    return categories.contains(category) ? category : 'Other';
  }
}
