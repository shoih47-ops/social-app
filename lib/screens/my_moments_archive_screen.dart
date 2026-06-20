import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'my_moments_month_screen.dart';

class MyMomentsArchiveScreen extends StatelessWidget {
  final String userId;

  const MyMomentsArchiveScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        title: const Text('Life Archive'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data!.docs.where(_hasCreatedAt).toList()
            ..sort((a, b) {
              final aDate = _createdAt(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bDate = _createdAt(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bDate.compareTo(aDate);
            });

          if (posts.isEmpty) {
            return const Center(
              child: Text(
                'No moments to archive yet',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          final years = _buildArchive(posts);

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: years.length,
            itemBuilder: (context, yearIndex) {
              final year = years[yearIndex];

              return Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        year.year.toString(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    ...year.months.map(
                      (month) => _MonthArchiveTile(
                        year: year.year,
                        month: month,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MyMomentsMonthScreen(
                                userId: userId,
                                year: year.year,
                                month: month.month,
                                monthName: month.name,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static List<_YearArchive> _buildArchive(List<QueryDocumentSnapshot> posts) {
    final grouped = <int, Map<int, int>>{};

    for (final post in posts) {
      final date = _createdAt(post)?.toLocal();
      if (date == null) continue;

      grouped.putIfAbsent(date.year, () => {});
      grouped[date.year]![date.month] = (grouped[date.year]![date.month] ?? 0) + 1;
    }

    final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return years.map((year) {
      final months = grouped[year]!.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      return _YearArchive(
        year: year,
        months: months
            .map(
              (month) => _MonthArchive(
                month: month,
                name: _monthName(month),
                count: grouped[year]![month]!,
              ),
            )
            .toList(),
      );
    }).toList();
  }

  static bool _hasCreatedAt(QueryDocumentSnapshot post) {
    return _createdAt(post) != null;
  }

  static DateTime? _createdAt(QueryDocumentSnapshot post) {
    final data = post.data() as Map<String, dynamic>;
    final value = data['createdAt'];

    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    return null;
  }

  static String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month - 1];
  }
}

class _MonthArchiveTile extends StatelessWidget {
  final int year;
  final _MonthArchive month;
  final VoidCallback onTap;

  const _MonthArchiveTile({
    required this.year,
    required this.month,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        month.name,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$year \u2022 ${month.count} ${month.count == 1 ? 'moment' : 'moments'}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black45),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _YearArchive {
  final int year;
  final List<_MonthArchive> months;

  const _YearArchive({required this.year, required this.months});
}

class _MonthArchive {
  final int month;
  final String name;
  final int count;

  const _MonthArchive({
    required this.month,
    required this.name,
    required this.count,
  });
}
