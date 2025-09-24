import 'package:flutter/material.dart';

String formatDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

String relativeExpiry(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(d.year, d.month, d.day);
  final diff = target.difference(today).inDays;

  if (diff < 0) {
    final daysAgo = -diff;
    if (daysAgo == 0) return 'expired today';
    return 'expired $daysAgo day${daysAgo > 1 ? 's' : ''} ago';
  } else if (diff == 0) {
    return 'expires today';
  } else if (diff == 1) {
    return 'in 1 day';
  } else {
    return 'in $diff days';
  }
}

Color expiryColor(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(d.year, d.month, d.day);
  final diff = target.difference(today).inDays;

  if (diff < 0) return Colors.red;
  if (diff <= 2) return Colors.orange;
  return Colors.green;
}
