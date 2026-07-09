import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_alarm_planner/i18n/app_controller.dart';
import 'package:smart_alarm_planner/models/event_model.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _kKey = 'events_v1';
  static const _kOrderKey = 'weekly_order_v1';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<List<EventModel>> loadEvents() async {
    final raw = _prefs.getString(_kKey);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final items = list.map((m) => EventModel.fromMap(m)).toList();

    items.sort((a, b) {
      final ai = a.time.hour * 60 + a.time.minute;
      final bi = b.time.hour * 60 + b.time.minute;
      return ai.compareTo(bi);
    });
    return items;
  }

  Future<void> saveEvents(List<EventModel> events) async {
    final list = events.map((e) => e.toMap()).toList();
    await _prefs.setString(_kKey, jsonEncode(list));
  }

  Future<void> upsertEvent(EventModel event) async {
    final items = await loadEvents();
    final idx = items.indexWhere((e) => e.id == event.id);
    if (idx >= 0) {
      items[idx] = event;
    } else {
      items.add(event);
    }
    await saveEvents(items);

    if (event.weekly && event.weekdays.isNotEmpty) {
      final order = _loadWeeklyOrder();
      for (final wd in event.weekdays) {
        final key = _key(wd, event.id);
        if (!order.containsKey(key)) {
          final next = _maxIndexForDay(order, wd) + 1;
          order[key] = next;
        }
      }
      _saveWeeklyOrder(order);
    } else {
      final order = _loadWeeklyOrder();
      final toRemove = order.keys.where((k) => k.endsWith(':${event.id}')).toList();
      for (final k in toRemove) {
        order.remove(k);
      }
      _saveWeeklyOrder(order);
    }
  }

  Future<void> deleteEvent(String id) async {
    final items = await loadEvents();
    items.removeWhere((e) => e.id == id);
    await saveEvents(items);

    final order = _loadWeeklyOrder();
    final keys = order.keys.where((k) => k.split(':')[1] == id).toList();
    for (final k in keys) {
      order.remove(k);
    }
    _saveWeeklyOrder(order);
  }

  Future<void> reorder(List<EventModel> reordered) async {
    await saveEvents(reordered);
  }

  String _key(int wd, String id) => '$wd:$id';

  Map<String, int> _loadWeeklyOrder() {
    final raw = _prefs.getString(_kOrderKey);
    if (raw == null) return {};
    final map = (jsonDecode(raw) as Map).map<String, int>(
      (k, v) => MapEntry(k as String, (v as num).toInt()),
    );
    return map;
  }

  Future<void> _saveWeeklyOrder(Map<String, int> order) async {
    await _prefs.setString(_kOrderKey, jsonEncode(order));
  }

  int _maxIndexForDay(Map<String, int> order, int wd) {
    final entries = order.entries.where((e) => e.key.startsWith('$wd:'));
    if (entries.isEmpty) return -1;
    return entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
  }

  int getWeeklyOrderIndex({required int wd, required String id}) {
    final order = _loadWeeklyOrder();
    final key = _key(wd, id);
    return order[key] ?? 1000000;
  }

  Future<void> reorderWeekday(int wd, List<String> orderedIds) async {
    final order = _loadWeeklyOrder();
    for (int i = 0; i < orderedIds.length; i++) {
      order[_key(wd, orderedIds[i])] = i;
    }
    await _saveWeeklyOrder(order);
  }

  Future<List<int>> weeklyConflicts({
    required String? editingId,
    required TimeOfDay time,
    required List<int> weekdays,
  }) async {
    final items = await loadEvents();
    final targetMinutes = time.hour * 60 + time.minute;
    final conflicts = <int>[];

    for (final wd in weekdays) {
      final clash = items.any((e) {
        if (e.id == editingId) return false;
        final eMinutes = e.time.hour * 60 + e.time.minute;
        if (eMinutes != targetMinutes) return false;

        if (e.repeatDaily) return true;
        if (e.weekly && e.weekdays.contains(wd)) return true;
        return false;
      });
      if (clash) conflicts.add(wd);
    }
    return conflicts;
  }

  Future<Directory> _backupDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final backup = Directory('${dir.path}/backups');
    if (!await backup.exists()) {
      await backup.create(recursive: true);
    }
    return backup;
  }

  Future<String> exportToFile() async {
    final items = await loadEvents();
    final jsonList = items.map((e) => e.toMap()).toList();
    final payload = jsonEncode({
      'schema': 1,
      'generatedAt': DateTime.now().toIso8601String(),
      'events': jsonList,
      'weeklyOrder': _loadWeeklyOrder(),
    });

    final dir = await _backupDir();
    final ts = DateTime.now();
    final name =
        'smart_alarm_backup_${ts.year.toString().padLeft(4, '0')}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}_${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}${ts.second.toString().padLeft(2, '0')}.json';
    final file = File('${dir.path}/$name');
    await file.writeAsString(payload);
    return file.path;
  }

  Future<String?> exportWithPicker() async {
    final items = await loadEvents();
    final jsonList = items.map((e) => e.toMap()).toList();
    final payload = jsonEncode({
      'schema': 1,
      'generatedAt': DateTime.now().toIso8601String(),
      'events': jsonList,
      'weeklyOrder': _loadWeeklyOrder(),
    });

    final ts = DateTime.now();
    final fileName =
        'smart_alarm_${ts.year.toString().padLeft(4, '0')}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}_${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}${ts.second.toString().padLeft(2, '0')}.json';

    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: AppController.instance.t('backup.exportTitle'),
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(payload)),
      type: FileType.custom,
      allowedExtensions: const ['json'],
      lockParentWindow: true,
    );

    return savedPath;
  }

  Future<int> importFromFile(File file) async {
    final raw = await file.readAsString();
    final data = jsonDecode(raw);

    if (data is! Map || !data.containsKey('events')) {
      throw FormatException(AppController.instance.t('backup.invalidFormat'));
    }

    final list = (data['events'] as List?) ?? const [];
    final events = <EventModel>[];
    for (final e in list) {
      try {
        events.add(EventModel.fromMap((e as Map).cast<String, dynamic>()));
      } catch (_) {
      }
    }

    await saveEvents(events);

    if (data['weeklyOrder'] is Map) {
      final order = (data['weeklyOrder'] as Map).map<String, int>(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      );
      await _prefs.setString(_kOrderKey, jsonEncode(order));
    }

    return events.length;
  }
}
