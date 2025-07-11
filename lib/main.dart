import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'models/roast_schedule_form_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ja_JP', null);
  runApp(
    ChangeNotifierProvider(
      create: (_) => RoastScheduleFormProvider(),
      child: const WorkAssignmentApp(),
    ),
  );
}
