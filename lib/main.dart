import 'dart:io';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:smart_alarm_planner/i18n/app_controller.dart';
import 'package:smart_alarm_planner/screens/alarm_screen.dart' as screens;
import 'package:smart_alarm_planner/screens/create_event_screen.dart';
import 'package:smart_alarm_planner/screens/constructor_screen.dart';
import 'package:smart_alarm_planner/screens/diagnostics_screen.dart';
import 'package:smart_alarm_planner/screens/home_screen.dart';
import 'package:smart_alarm_planner/screens/my_timeline_screen.dart';
import 'package:smart_alarm_planner/screens/settings_screen.dart';
import 'package:smart_alarm_planner/services/alarm_service.dart';
import 'package:smart_alarm_planner/services/storage_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> _initTz() async {
  tzdata.initializeTimeZones();
  try {
    if (Platform.isAndroid) {
      tz.setLocalLocation(tz.getLocation('Europe/Kiev'));
    } else {
      tz.setLocalLocation(tz.getLocation('Europe/Kyiv'));
    }
  } catch (_) {
    tz.setLocalLocation(tz.getLocation('UTC'));
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.instance.init();
  await AppController.instance.init();
  await _initTz();
  await AlarmService.instance.init(navigatorKey: navigatorKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppController.instance;

    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          title: app.t('app.title'),
          themeMode: app.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: app.accentColor,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: app.accentColor,
            brightness: Brightness.dark,
          ),
          builder: (context, child) => AppScope(
            controller: app,
            child: child ?? const SizedBox.shrink(),
          ),
          routes: {
            '/': (_) => const HomeScreen(),
            '/create': (_) => const CreateEventScreen(),
            '/construct': (_) => const ConstructorScreen(),
            '/timeline': (_) => const MyTimelineScreen(),
            '/settings': (_) => const SettingsScreen(),
            '/alarm': (_) => const screens.AlarmFullScreen(),
            '/diag': (_) => const DiagnosticsScreen(),
          },
          initialRoute: '/',
        );
      },
    );
  }
}
