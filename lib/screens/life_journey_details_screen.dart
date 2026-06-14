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
        .where((item) => item.year.isNotEmpty && item.title.isNotEmpty)
        .toList()
      ..sort((a, b) => b.year.compareTo(a.year));

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
                        '${item.icon} ${item.year}',
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
  final String year;
  final String title;

  const _LifeJourneyItem({required this.year, required this.title});

  String get icon {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('app') || lowerTitle.contains('build')) {
      return '🚀';
    }
    if (lowerTitle.contains('flutter') || lowerTitle.contains('learn')) {
      return '📱';
    }
    return '💡';
  }

  factory _LifeJourneyItem.fromMap(Map<String, dynamic> data) {
    return _LifeJourneyItem(
      year: (data['year'] ?? '').toString().trim(),
      title: (data['title'] ?? '').toString().trim(),
    );
  }
}
