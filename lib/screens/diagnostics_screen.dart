import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smart_alarm_planner/i18n/app_controller.dart';
import 'package:smart_alarm_planner/services/alarm_service.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final List<String> _lines = [];

  void _log(String s) => setState(() => _lines.insert(0, s));

  Future<void> _trace10s() async {
    _log('testInSeconds(10) scheduled');
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(seconds: 1));
      _log('[TRACE] tick=$i now=${DateTime.now()} (+${i * 1000}ms)');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('diagnostics.title'))),
      body: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: () async {
                  await AlarmService.instance.testInSeconds(10);
                  _trace10s();
                },
                child: Text(context.t('diagnostics.trace')),
              ),
              ElevatedButton(
                onPressed: () async {
                  _log('Refresh: open logs in Logcat (tag=ALARM)');
                },
                child: Text(context.t('diagnostics.refresh')),
              ),
              ElevatedButton(
                onPressed: () async {
                  await AlarmService.instance.showNow();
                },
                child: Text(context.t('diagnostics.notificationSettings')),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _lines.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(_lines[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
