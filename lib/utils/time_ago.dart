import 'package:cloud_firestore/cloud_firestore.dart';

enum TimeAgoDisplay { relative, feed, detail }

String timeAgo(DateTime time) {
  return TimeAgoHelper.format(Timestamp.fromDate(time));
}

class TimeAgoHelper {
  static String format(
    Timestamp createdAt, {
    TimeAgoDisplay display = TimeAgoDisplay.relative,
  }) {
    final date = createdAt.toDate().toLocal();
    final relativeTime = _relativeTime(date);

    switch (display) {
      case TimeAgoDisplay.feed:
        if (DateTime.now().difference(date).inHours < 24) {
          return '$relativeTime • ${_weekdayName(date)}';
        }

        return '${_weekdayName(date)}, ${_shortMonthName(date.month)} '
            '${date.day} • ${_formatTime(date)}';
      case TimeAgoDisplay.detail:
        return '${_weekdayName(date)}, ${_shortMonthName(date.month)} '
            '${date.day} • ${_formatTime(date)}';
      case TimeAgoDisplay.relative:
        return relativeTime;
    }
  }

  static Timestamp fromFirestore(dynamic createdAt) {
    if (createdAt is Timestamp) {
      return createdAt;
    }

    return Timestamp.fromDate(DateTime.now());
  }

  static String _relativeTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return minutes == 1 ? '1 min ago' : '$minutes min ago';
    }

    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return hours == 1 ? '1 hour ago' : '$hours hours ago';
    }

    final days = difference.inDays;
    return days == 1 ? '1 day ago' : '$days days ago';
  }

  static String _weekdayName(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return weekdays[date.weekday - 1];
  }

  static String _shortMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return months[month - 1];
  }

  static String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }
}
