import 'dart:async';
import 'package:flutter/services.dart';

class NativeAlarm {
  static const _ch = MethodChannel('plannig/alarm');

  static void setAlarmLaunchHandler(FutureOr<void> Function(String payload) handler) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'alarmLaunch') {
        final payload = call.arguments as String?;
        if (payload != null && payload.isNotEmpty) {
          await handler(payload);
        }
      }
    });
  }

  static Future<String?> consumeLaunchPayload() async {
    return _ch.invokeMethod<String>('consumeLaunchPayload');
  }

  static Future<void> stopRinging() async {
    await _ch.invokeMethod('stopRinging');
  }

  static Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required String payload,
    bool repeatDaily = false,
    bool preCall = false,
    bool canSnooze5 = false,
    bool requireMathToDismiss = false,
  }) async {
    await _ch.invokeMethod('schedule', {
      'id': id,
      'whenMs': when.millisecondsSinceEpoch,
      'title': title,
      'body': body,
      'payload': payload,
      'repeatDaily': repeatDaily,
      'preCall': preCall,
      'canSnooze5': canSnooze5,
      'requireMathToDismiss': requireMathToDismiss,
    });
  }

  static Future<void> cancel(int id) async {
    await _ch.invokeMethod('cancel', {'id': id});
  }
}
