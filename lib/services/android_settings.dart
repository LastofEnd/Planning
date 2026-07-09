import 'dart:io' show Platform;
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';

class AndroidSettings {
  AndroidSettings._();

  static Future<void> openAppNotificationSettings(BuildContext context) async {
    if (!Platform.isAndroid) return;
    final intent = const AndroidIntent(
      action: 'android.settings.APP_NOTIFICATION_SETTINGS',
      arguments: <String, dynamic>{
        'android.provider.extra.APP_PACKAGE': 'com.lastofend.plannig',
      },
    );
    await intent.launch();
  }

  static Future<void> openExactAlarmSettings(BuildContext context) async {
    if (!Platform.isAndroid) return;
    final intent = const AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
      data: 'package:com.lastofend.plannig',
    );
    await intent.launch();
  }
}
