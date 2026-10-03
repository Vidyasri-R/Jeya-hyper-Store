import 'package:intl/intl.dart';

/// "Today" / "Tomorrow" / "Sat, 4 Oct" for a delivery date (device time; our customers are in IST).
String deliveryDay(DateTime by) {
  final now = DateTime.now();
  final days = DateTime(by.year, by.month, by.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  return DateFormat('EEE, d MMM').format(by);
}

/// "Tomorrow, Sat 4 Oct" — the relative day plus the date, so there's no doubt.
String deliveryPromise(DateTime by) {
  final day = deliveryDay(by);
  return day == 'Today' || day == 'Tomorrow' ? '$day, ${DateFormat('EEE d MMM').format(by)}' : day;
}
