import 'package:intl/intl.dart';

String todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

String dayKeyAgo(int d) =>
    DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: d)));

bool isWeekend() {
  final wd = DateTime.now().weekday;
  return wd == DateTime.saturday || wd == DateTime.sunday;
}
