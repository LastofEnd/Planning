import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smart_alarm_planner/i18n/app_controller.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:smart_alarm_planner/models/event_model.dart';
import 'package:smart_alarm_planner/services/native_alarm.dart';
import 'package:smart_alarm_planner/services/storage_service.dart';

class AlarmService {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  late AndroidNotificationChannel _channelMain;
  GlobalKey<NavigatorState>? _navKey;

  Future<void> init({GlobalKey<NavigatorState>? navigatorKey}) async {
    _navKey = navigatorKey;
    NativeAlarm.setAlarmLaunchHandler(_openAlarmFromPayload);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iOSInit);

    await _fln.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) async {
        final payload = resp.payload ?? '';
        if (payload.isEmpty) return;
        _openAlarmFromPayload(payload);
      },
    );

    _channelMain = const AndroidNotificationChannel(
      'smart_alarm_main',
      'Smart Alarm',
      description: 'Alarm notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidImpl = _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_channelMain);
    try {
      await androidImpl?.requestNotificationsPermission();
    } catch (_) {}

    Future.delayed(const Duration(milliseconds: 450), () async {
      final payload = await NativeAlarm.consumeLaunchPayload();
      if (payload != null && payload.isNotEmpty) {
        _openAlarmFromPayload(payload);
      }
    });
  }


  void _openAlarmFromPayload(String payload, {int attempt = 0}) {
    final parts = payload.split('|');
    final eventId = parts.isNotEmpty ? parts[0] : '';
    if (eventId.isEmpty) return;

    final noSnooze = parts.contains('nosnooze');
    final state = _navKey?.currentState;
    if (state == null) {
      if (attempt < 25) {
        Future.delayed(
          const Duration(milliseconds: 120),
          () => _openAlarmFromPayload(payload, attempt: attempt + 1),
        );
      }
      return;
    }

    state.pushNamed('/alarm', arguments: {'id': eventId, 'noSnooze': noSnooze});
  }

  DateTime _nextOccurrenceForWeekday(int weekday, int h, int m) {
    final now = DateTime.now();
    var dt = DateTime(now.year, now.month, now.day, h, m);
    final today = dt.weekday;
    var addDays = (weekday - today) % 7;
    if (addDays < 0) addDays += 7;
    dt = dt.add(Duration(days: addDays));
    if (!dt.isAfter(now)) dt = dt.add(const Duration(days: 7));
    return dt;
  }

  DateTime _nextLocalDateTimeTodayOrTomorrow(int h, int m) {
    final now = DateTime.now();
    var dt = DateTime(now.year, now.month, now.day, h, m);
    if (!dt.isAfter(now)) dt = dt.add(const Duration(days: 1));
    return dt;
  }

  int _fnv1a32(String s) {
    const int fnvPrime = 0x01000193;
    var hash = 0x811C9DC5;
    for (final cu in s.codeUnits) {
      hash = (hash ^ (cu & 0xFF)) & 0xFFFFFFFF;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    if ((hash & 0x80000000) != 0) {
      hash = -(((~hash) + 1) & 0xFFFFFFFF);
    }
    return hash;
  }

  int _mainIdForDay(String id, int weekday) => _fnv1a32(id) ^ (weekday * 1111);
  int _preIdForDay(String id, int weekday) => _fnv1a32(id) ^ (weekday * 1111) ^ 777;
  int _mainId(String id) => _fnv1a32(id);
  int _preId(String id) => _fnv1a32(id) ^ 777;

  String _alarmPayload(EventModel e, {bool noSnooze = false}) {
    final parts = <String>[e.id, 'alarm'];
    if (e.canSnooze5 && !noSnooze) parts.add('cansnooze');
    if (noSnooze) parts.add('nosnooze');
    if (e.requireMathToDismiss) parts.add('math');
    return parts.join('|');
  }

  Future<void> _scheduleMain({
    required int id,
    required DateTime when,
    required EventModel event,
    bool noSnooze = false,
  }) async {
    await NativeAlarm.schedule(
      id: id,
      when: when,
      title: event.title,
      body: event.description.isEmpty ? AppController.instance.t('alarm.eventTime') : event.description,
      payload: _alarmPayload(event, noSnooze: noSnooze),
      canSnooze5: event.canSnooze5 && !noSnooze,
      requireMathToDismiss: event.requireMathToDismiss,
    );
  }

  Future<void> scheduleForEvent(EventModel e) async {
    await cancelForEvent(e.id);
    if (!e.enabled) return;

    if (e.isOneOff && e.oneOffDate != null) {
      final d = e.oneOffDate!;
      final when = DateTime(d.year, d.month, d.day, e.time.hour, e.time.minute);

      if (when.isAfter(DateTime.now())) {
        if (e.callBefore5) {
          final pre = when.subtract(const Duration(minutes: 5));
          if (pre.isAfter(DateTime.now())) {
            await NativeAlarm.schedule(
              id: _preId(e.id),
              when: pre,
              title: AppController.instance.t('notification.before5Title'),
              body: AppController.instance.t('notification.before5Body', {'title': e.title}),
              payload: '${e.id}|precall',
              preCall: true,
            );
          }
        }
        await _scheduleMain(id: _mainId(e.id), when: when, event: e);
      }
      return;
    }

    if (e.weekly && e.weekdays.isNotEmpty) {
      for (final wd in e.weekdays) {
        if (e.callBefore5) {
          final pre = _nextOccurrenceForWeekday(wd, e.time.hour, e.time.minute).subtract(const Duration(minutes: 5));
          if (pre.isAfter(DateTime.now())) {
            await NativeAlarm.schedule(
              id: _preIdForDay(e.id, wd),
              when: pre,
              title: AppController.instance.t('notification.before5Title'),
              body: AppController.instance.t('notification.before5Body', {'title': e.title}),
              payload: '${e.id}|precall',
              preCall: true,
            );
          }
        }

        final when = _nextOccurrenceForWeekday(wd, e.time.hour, e.time.minute);
        await _scheduleMain(id: _mainIdForDay(e.id, wd), when: when, event: e);
      }
      return;
    }

    if (e.callBefore5) {
      final pre = _nextLocalDateTimeTodayOrTomorrow(e.time.hour, e.time.minute).subtract(const Duration(minutes: 5));
      if (pre.isAfter(DateTime.now())) {
        await NativeAlarm.schedule(
          id: _preId(e.id),
          when: pre,
          title: AppController.instance.t('notification.before5Title'),
          body: AppController.instance.t('notification.before5Body', {'title': e.title}),
          payload: '${e.id}|precall',
          preCall: true,
        );
      }
    }

    final mainAt = _nextLocalDateTimeTodayOrTomorrow(e.time.hour, e.time.minute);
    await _scheduleMain(id: _mainId(e.id), when: mainAt, event: e);
  }

  Future<void> scheduleAll() async {
    final items = await StorageService.instance.loadEvents();
    for (final e in items) {
      await scheduleForEvent(e);
    }
  }

  Future<void> cancelForEvent(String id) async {
    for (var wd = 1; wd <= 7; wd++) {
      await NativeAlarm.cancel(_preIdForDay(id, wd));
      await NativeAlarm.cancel(_mainIdForDay(id, wd));
    }
    await NativeAlarm.cancel(_preId(id));
    await NativeAlarm.cancel(_mainId(id));
    await NativeAlarm.cancel(_mainId('${id}_snooze'));
  }

  Future<void> cancelAll() async {
    final items = await StorageService.instance.loadEvents();
    for (final e in items) {
      await cancelForEvent(e.id);
    }
  }

  Future<void> snooze5(String id) async {
    final items = await StorageService.instance.loadEvents();
    EventModel? event;
    for (final item in items) {
      if (item.id == id) {
        event = item;
        break;
      }
    }
    if (event == null) return;

    final when = DateTime.now().add(const Duration(minutes: 5));
    await _scheduleMain(
      id: _mainId('${id}_snooze'),
      when: when,
      event: event,
      noSnooze: true,
    );
  }

  Future<void> showNow({
    String? title,
    String? body,
  }) async {
    await _fln.show(
      999001,
      title ?? AppController.instance.t('notification.instantTitle'),
      body ?? AppController.instance.t('notification.instantBody'),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelMain.id,
          _channelMain.name,
          channelDescription: _channelMain.description,
          priority: Priority.high,
          importance: Importance.max,
        ),
      ),
      payload: 'test|notify',
    );
  }

  Future<void> testInSeconds(int seconds) async {
    final now = DateTime.now();
    final when = now.add(Duration(seconds: seconds));
    await NativeAlarm.schedule(
      id: 424242,
      when: when,
      title: AppController.instance.t('notification.nativeTestTitle'),
      body: AppController.instance.t('notification.nativeTestBody', {'seconds': seconds}),
      payload: 'test|notify',
    );
  }

  Future<List<String>> pendingText() async => <String>[];
}
