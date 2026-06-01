String timeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
        return "Just now";        
    } else if (difference.inMinutes < 60) {
        return "${difference.inMinutes} min ago";
    } else if (difference.inHours < 24) {
        return "${difference.inHours} hr ago";
    } else if (difference.inDays < 7) {
        return "${difference.inDays} days ago";
    } else {
        return "${time.day}/${time.month}/${time.year}";
    }
}