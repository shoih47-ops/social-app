import 'package:flutter/material.dart';

class LifeJourneyDetailsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> lifeJourney;

  const LifeJourneyDetailsScreen({
    super.key,
    required this.lifeJourney,
  });

  @override
  Widget build(BuildContext context) {
    final items = lifeJourney
        .map(_LifeJourneyItem.fromMap)
        .where((item) => item.startYear.isNotEmpty && item.title.isNotEmpty)
        .toList()
      ..sort((a, b) => b.startYearValue.compareTo(a.startYearValue));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        centerTitle: true,
        title: const Text(
          'Life Journey',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return _TimelineItem(
              item: items[index],
              isFirst: index == 0,
              isLast: index == items.length - 1,
            );
          },
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final _LifeJourneyItem item;
  final bool isFirst;
  final bool isLast;

  const _TimelineItem({
    required this.item,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(width: 2, color: const Color(0xFFE6E2FF)),
                  )
                else
                  const Expanded(child: SizedBox()),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6D4CFF),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: const Color(0xFFE6E2FF)),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEDEDED)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.icon} ${item.yearRange}',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
