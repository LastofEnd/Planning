import 'dart:convert';
import 'package:flutter/material.dart';

enum EventPriority { A1, A2, B1, C1, D1 }

EventPriority priorityFromString(String s) => EventPriority.values.firstWhere(
      (e) => e.name == s,
      orElse: () => EventPriority.C1,
    );

const kWeekdayNames = {
  1: 'Пн',
  2: 'Вт',
  3: 'Ср',
  4: 'Чт',
  5: 'Пт',
  6: 'Сб',
  7: 'Нд',
};

class EventModel {
  final String id;
  String title;
  String description;
  TimeOfDay time;

  bool canSnooze5;
  bool callBefore5;
  bool requireMathToDismiss;

  bool repeatDaily;
  bool weekly;
  List<int> weekdays;

  bool isOneOff;
  DateTime? oneOffDate;

  EventPriority priority;
  bool enabled;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.time,
    this.canSnooze5 = false,
    this.callBefore5 = false,
    this.requireMathToDismiss = false,
    this.repeatDaily = false,
    this.weekly = false,
    List<int>? weekdays,
    this.isOneOff = false,
    this.oneOffDate,
    this.priority = EventPriority.C1,
    this.enabled = true,
  }) : weekdays = weekdays ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'hour': time.hour,
        'minute': time.minute,
        'canSnooze5': canSnooze5,
        'callBefore5': callBefore5,
        'requireMathToDismiss': requireMathToDismiss,
        'repeatDaily': repeatDaily,
        'weekly': weekly,
        'weekdays': weekdays,
        'isOneOff': isOneOff,
        'oneOffDate': oneOffDate == null
            ? null
            : '${oneOffDate!.year.toString().padLeft(4, '0')}-'
                '${oneOffDate!.month.toString().padLeft(2, '0')}-'
                '${oneOffDate!.day.toString().padLeft(2, '0')}',
        'priority': priority.name,
        'enabled': enabled,
      };

  factory EventModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(String? iso) {
      if (iso == null || iso.isEmpty) return null;
      try {
        final parts = iso.split('-').map((e) => int.tryParse(e) ?? 0).toList();
        if (parts.length == 3) return DateTime(parts[0], parts[1], parts[2]);
      } catch (_) {}
      return null;
    }

    return EventModel(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      time: TimeOfDay(hour: map['hour'], minute: map['minute']),
      canSnooze5: map['canSnooze5'] ?? false,
      callBefore5: map['callBefore5'] ?? false,
      requireMathToDismiss: map['requireMathToDismiss'] ?? false,
      repeatDaily: map['repeatDaily'] ?? false,
      weekly: map['weekly'] ?? false,
      weekdays: (map['weekdays'] as List?)?.map((e) => e as int).toList() ?? [],
      isOneOff: map['isOneOff'] ?? false,
      oneOffDate: parseDate(map['oneOffDate']),
      priority: priorityFromString(map['priority'] ?? 'C1'),
      enabled: map['enabled'] ?? true,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory EventModel.fromJson(String s) => EventModel.fromMap(jsonDecode(s));
}
