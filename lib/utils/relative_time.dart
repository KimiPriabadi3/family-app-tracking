String formatRelativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays == 1) return 'kemarin';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  return '${dt.day}/${dt.month}/${dt.year}';
}
