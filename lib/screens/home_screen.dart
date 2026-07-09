import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:smart_alarm_planner/i18n/app_controller.dart';
import 'package:smart_alarm_planner/models/event_model.dart';
import 'package:smart_alarm_planner/screens/create_event_screen.dart';
import 'package:smart_alarm_planner/screens/constructor_screen.dart';
import 'package:smart_alarm_planner/screens/diagnostics_screen.dart';
import 'package:smart_alarm_planner/screens/my_timeline_screen.dart';
import 'package:smart_alarm_planner/screens/settings_screen.dart';
import 'package:smart_alarm_planner/services/alarm_service.dart';
import 'package:smart_alarm_planner/services/android_settings.dart';
import 'package:smart_alarm_planner/services/storage_service.dart';
import 'package:smart_alarm_planner/widgets/event_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<EventModel> _today = [];

  @override
  void initState() {
    super.initState();
    _load();
    AlarmService.instance.scheduleAll();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _load() async {
    final all = await StorageService.instance.loadEvents();
    final today = DateTime.now();
    final todayWd = today.weekday;

    final filtered = all.where((e) {
      if (!e.enabled) return false;
      if (e.repeatDaily) return true;
      if (e.weekly && e.weekdays.contains(todayWd)) return true;
      if (e.isOneOff && e.oneOffDate != null) return _sameDay(e.oneOffDate!, today);
      if (!e.weekly && !e.repeatDaily && !e.isOneOff) return true;
      return false;
    }).toList();

    int toMin(TimeOfDay t) => t.hour * 60 + t.minute;
    filtered.sort((a, b) => toMin(a.time).compareTo(toMin(b.time)));

    if (!mounted) return;
    setState(() => _today = filtered);
  }


  Future<void> _openPage(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    await _load();
  }

  Future<void> _exportDb() async {
    try {
      final savedTo = await StorageService.instance.exportWithPicker();
      if (!mounted) return;

      if (savedTo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('backup.exportCanceled'))),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('backup.saved', {'path': savedTo}))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('backup.exportError', {'error': e}))),
      );
    }
  }

  Future<void> _importDb() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        dialogTitle: context.t('backup.importTitle'),
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (res == null || res.files.single.path == null) return;

      final file = File(res.files.single.path!);
      final count = await StorageService.instance.importFromFile(file);

      await AlarmService.instance.cancelAll();
      await AlarmService.instance.scheduleAll();

      if (!mounted) return;
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('backup.imported', {'count': count}))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('backup.importError', {'error': e}))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wdName = context.weekdayShort(DateTime.now().weekday);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('home.title', {'weekday': wdName})),
        actions: [
          PopupMenuButton<String>(
            tooltip: context.t('menu.tooltip'),
            onSelected: (value) async {
              switch (value) {
                case 'timeline':
                  await _openPage(const MyTimelineScreen());
                  break;
                case 'construct':
                  await _openPage(const ConstructorScreen());
                  break;
                case 'settings':
                  await _openPage(const SettingsScreen());
                  break;
                case 'notif_settings':
                  await AndroidSettings.openAppNotificationSettings(context);
                  break;
                case 'exact_alarm':
                  await AndroidSettings.openExactAlarmSettings(context);
                  break;
                case 'export_db':
                  await _exportDb();
                  break;
                case 'import_db':
                  await _importDb();
                  break;
                case 'diag':
                  await _openPage(const DiagnosticsScreen());
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'timeline',
                child: ListTile(
                  leading: const Icon(Icons.view_timeline_outlined),
                  title: Text(context.t('menu.timeline')),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'construct',
                child: ListTile(
                  leading: const Icon(Icons.view_week_outlined),
                  title: Text(context.t('menu.constructor')),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(context.t('menu.settings')),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'notif_settings',
                child: ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: Text(context.t('menu.notificationSettings')),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'exact_alarm',
                child: ListTile(
                  leading: const Icon(Icons.alarm_on_outlined),
                  title: Text(context.t('menu.exactAlarmPermission')),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'export_db',
                child: ListTile(
                  leading: const Icon(Icons.save_alt_outlined),
                  title: Text(context.t('menu.export')),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'import_db',
                child: ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: Text(context.t('menu.import')),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'diag',
                child: ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: Text(context.t('menu.diagnostics')),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _today.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(context.t('home.emptyToday'))),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _today.length,
                itemBuilder: (_, i) => EventCard(
                  event: _today[i],
                  onChanged: _load,
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateEventScreen())).then((_) => _load()),
        icon: const Icon(Icons.add),
        label: Text(context.t('home.createEvent')),
      ),
    );
  }
}
