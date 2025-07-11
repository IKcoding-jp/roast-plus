import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'models/roast_schedule_form_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'models/theme_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeDateFormatting('ja_JP', null);
  final themeSettings = await ThemeSettings.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RoastScheduleFormProvider()),
        ChangeNotifierProvider<ThemeSettings>.value(value: themeSettings),
      ],
      child: const WorkAssignmentApp(),
    ),
  );
}
