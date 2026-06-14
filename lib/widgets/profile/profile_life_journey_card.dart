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
        .where((item) => item.year.isNotEmpty && item.title.isNotEmpty)
        .toList()
      ..sort((a, b) => b.year.compareTo(a.year));

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
        child: Text(
          '${item.year} • ${item.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _LifeJourneyItem {
  final String year;
  final String title;

  const _LifeJourneyItem({required this.year, required this.title});

  factory _LifeJourneyItem.fromMap(Map<String, dynamic> data) {
    return _LifeJourneyItem(
      year: (data['year'] ?? '').toString().trim(),
      title: (data['title'] ?? '').toString().trim(),
    );
  }
}
