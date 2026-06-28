import 'package:flutter/material.dart';

import '../../screens/profile_about_details_screen.dart';

class ProfileAboutCard extends StatelessWidget {
  final String? work;
  final String? family;
  final String? goal;
  final String? interests;
  final String? location;
  final String? nationality;
  final String? relationship;
  final String? birthday;
  final String? lifeQuote;
  final bool compactPriorityOnly;

  const ProfileAboutCard({
    super.key,
    this.work,
    this.family,
    this.goal,
    this.interests,
    this.location,
    this.nationality,
    this.relationship,
    this.birthday,
    this.lifeQuote,
    this.compactPriorityOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final allRows =
        [
          _AboutRowData(icon: '💼', label: 'Work', value: work),
          _AboutRowData(icon: '👨‍👩‍👧', label: 'Family', value: family),
          _AboutRowData(icon: '🎯', label: 'Goal', value: goal),
          _AboutRowData(icon: '⚽', label: 'Interests', value: interests),
          _AboutRowData(icon: '📍', label: 'Location', value: location),
          _AboutRowData(icon: '🌐', label: 'Nationality', value: nationality),
          _AboutRowData(icon: '❤️', label: 'Relationship', value: relationship),
          _AboutRowData(icon: '🎂', label: 'Birthday', value: birthday),
          _AboutRowData(icon: '💬', label: 'Life Quote', value: lifeQuote),
        ].where((row) {
          return row.value != null && row.value!.trim().isNotEmpty;
        }).toList();

    if (allRows.isEmpty) return const SizedBox.shrink();

    final priorityRows =
        [
          _AboutRowData(icon: '💼', label: 'Work', value: work),
          _AboutRowData(icon: '🎯', label: 'Goal', value: goal),
          _AboutRowData(icon: '📍', label: 'Location', value: location),
        ].where((row) {
          return row.value != null && row.value!.trim().isNotEmpty;
        }).toList();

    final summaryRows = compactPriorityOnly
        ? priorityRows
        : [
            ...priorityRows,
            ...allRows.where((row) {
              return !priorityRows.any(
                (priority) => priority.label == row.label,
              );
            }),
          ].take(3).toList();

    if (summaryRows.isEmpty && !compactPriorityOnly) {
      return const SizedBox.shrink();
    }

    if (compactPriorityOnly) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDEDED)),
        ),
        child: Column(
          children: [
            if (summaryRows.isNotEmpty)
              Row(
                children: [
                  for (var index = 0; index < summaryRows.length; index++) ...[
                    Expanded(child: _AboutTile(data: summaryRows[index])),
                    if (index != summaryRows.length - 1)
                      const SizedBox(width: 6),
                  ],
                ],
              ),
            Align(
              alignment: Alignment.centerRight,
              child: _AboutViewAllButton(
                work: work,
                family: family,
                goal: goal,
                interests: interests,
                location: location,
                nationality: nationality,
                relationship: relationship,
                birthday: birthday,
                lifeQuote: lifeQuote,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: summaryRows.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 3.2,
            ),
            itemBuilder: (context, index) {
              return _AboutTile(data: summaryRows[index]);
            },
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: _AboutViewAllButton(
              work: work,
              family: family,
              goal: goal,
              interests: interests,
              location: location,
              nationality: nationality,
              relationship: relationship,
              birthday: birthday,
              lifeQuote: lifeQuote,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutViewAllButton extends StatelessWidget {
  final String? work;
  final String? family;
  final String? goal;
  final String? interests;
  final String? location;
  final String? nationality;
  final String? relationship;
  final String? birthday;
  final String? lifeQuote;

  const _AboutViewAllButton({
    this.work,
    this.family,
    this.goal,
    this.interests,
    this.location,
    this.nationality,
    this.relationship,
    this.birthday,
    this.lifeQuote,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileAboutDetailsScreen(
              work: work,
              family: family,
              goal: goal,
              interests: interests,
              location: location,
              nationality: nationality,
              relationship: relationship,
              birthday: birthday,
              lifeQuote: lifeQuote,
            ),
          ),
        );
      },
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF6D4CFF),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text(
        'View All',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  final _AboutRowData data;

  const _AboutTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Text(data.icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    data.value!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutRowData {
  final String icon;
  final String label;
  final String? value;

  const _AboutRowData({
    required this.icon,
    required this.label,
    required this.value,
  });
}
