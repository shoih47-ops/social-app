import 'package:flutter/material.dart';

class ProfileAboutDetailsScreen extends StatelessWidget {
  final String? work;
  final String? family;
  final String? goal;
  final String? interests;
  final String? location;
  final String? nationality;
  final String? relationship;
  final String? birthday;
  final String? lifeQuote;

  const ProfileAboutDetailsScreen({
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
  });

  @override
  Widget build(BuildContext context) {
    final rows =
        [
          _AboutDetailData(icon: '💼', label: 'Work', value: work),
          _AboutDetailData(icon: '👨‍👩‍👧', label: 'Family', value: family),
          _AboutDetailData(icon: '🎯', label: 'Goal', value: goal),
          _AboutDetailData(icon: '⚽', label: 'Interests', value: interests),
          _AboutDetailData(icon: '📍', label: 'Location', value: location),
          _AboutDetailData(
            icon: '🌐',
            label: 'Nationality',
            value: nationality,
          ),
          _AboutDetailData(
            icon: '❤️',
            label: 'Relationship',
            value: relationship,
          ),
          _AboutDetailData(icon: '🎂', label: 'Birthday', value: birthday),
          _AboutDetailData(icon: '💬', label: 'Life Quote', value: lifeQuote),
        ].where((row) {
          return row.value != null && row.value!.trim().isNotEmpty;
        }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        centerTitle: true,
        title: const Text('About', style: TextStyle(color: Colors.black)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEDEDED)),
              ),
              child: Column(
                children: [
                  for (int index = 0; index < rows.length; index++) ...[
                    _AboutDetailTile(data: rows[index]),
                    if (index != rows.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutDetailTile extends StatelessWidget {
  final _AboutDetailData data;

  const _AboutDetailTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.value!.trim(),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
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

class _AboutDetailData {
  final String icon;
  final String label;
  final String? value;

  const _AboutDetailData({
    required this.icon,
    required this.label,
    required this.value,
  });
}
