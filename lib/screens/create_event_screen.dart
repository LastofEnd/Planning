import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:smart_alarm_planner/i18n/app_controller.dart';
import 'package:smart_alarm_planner/models/event_model.dart';
import 'package:smart_alarm_planner/services/alarm_service.dart';
import 'package:smart_alarm_planner/services/storage_service.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();

  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  bool _snooze = false;
  bool _callBefore = false;
  bool _requireMathToDismiss = false;
  bool _oneOff = false;
  DateTime? _oneOffDate;
  bool _weekly = false;
  final Set<int> _weekdays = {};
  bool _daily = false;
  EventPriority _priority = EventPriority.C1;
  EventModel? _editing;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is EventModel && _editing == null) {
      _editing = arg;
      _title.text = arg.title;
      _desc.text = arg.description;
      _time = arg.time;
      _snooze = arg.canSnooze5;
      _callBefore = arg.callBefore5;
      _requireMathToDismiss = arg.requireMathToDismiss;
      _oneOff = arg.isOneOff;
      _oneOffDate = arg.oneOffDate;
      _weekly = arg.weekly;
      _weekdays
        ..clear()
        ..addAll(arg.weekdays);
      _daily = arg.repeatDaily;
      _priority = arg.priority;
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final init = _oneOffDate ?? DateTime(now.year, now.month, now.day);
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) setState(() => _oneOffDate = d);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    if (_oneOff) {
      _weekly = false;
      _daily = false;
      _weekdays.clear();
      if (_oneOffDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('event.chooseOneOffDate'))),
        );
        return;
      }
    }

    if (_weekly && _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('event.chooseWeekday'))),
      );
      return;
    }

    if (_weekly) {
      final conflicts = await StorageService.instance.weeklyConflicts(
        editingId: _editing?.id,
        time: _time,
        weekdays: _weekdays.toList(),
      );
      if (conflicts.isNotEmpty) {
        final labels = conflicts.map((d) => context.weekdayShort(d)).join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('event.timeConflict', {'days': labels}))),
        );
        return;
      }
    }

    final item = _editing ??
        EventModel(
          id: const Uuid().v4(),
          title: _title.text.trim(),
          description: _desc.text.trim(),
          time: _time,
        );

    item.title = _title.text.trim();
    item.description = _desc.text.trim();
    item.time = _time;
    item.canSnooze5 = _snooze;
    item.callBefore5 = _callBefore;
    item.requireMathToDismiss = _requireMathToDismiss;
    item.isOneOff = _oneOff;
    item.oneOffDate = _oneOff ? _oneOffDate : null;
    item.weekly = !_oneOff && _weekly;
    item.weekdays = item.weekly ? _weekdays.toList() : <int>[];
    item.repeatDaily = (!_oneOff && !_weekly) ? _daily : false;
    item.priority = _priority;

    await StorageService.instance.upsertEvent(item);
    await AlarmService.instance.scheduleForEvent(item);

    if (mounted) Navigator.pop(context);
  }

  Widget _buildWeekdayPicker() {
    if (!_weekly) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: -6,
      children: List.generate(7, (i) {
        final wd = i + 1;
        final label = context.weekdayShort(wd);
        final selected = _weekdays.contains(wd);
        return FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (v) {
            setState(() {
              if (v) {
                _weekdays.add(wd);
              } else {
                _weekdays.remove(wd);
              }
            });
          },
        );
      }),
    );
  }

  Widget _buildOneOffPicker() {
    if (!_oneOff) return const SizedBox.shrink();
    final text = _oneOffDate == null
        ? context.t('event.noDate')
        : '${_oneOffDate!.day.toString().padLeft(2, '0')}.'
            '${_oneOffDate!.month.toString().padLeft(2, '0')}.'
            '${_oneOffDate!.year}';
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      children: [
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ElevatedButton(onPressed: _pickDate, child: Text(context.t('event.pickDate'))),
      ],
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final editingA1 = _editing?.priority == EventPriority.A1;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing == null ? context.t('event.createTitle') : context.t('event.editTitle')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _title,
                decoration: InputDecoration(labelText: context.t('event.name')),
                validator: (v) => (v == null || v.trim().isEmpty) ? context.t('event.nameRequired') : null,
                readOnly: editingA1,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                decoration: InputDecoration(labelText: context.t('event.description')),
                maxLines: 3,
                readOnly: editingA1,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    context.t('event.time', {'time': _fmt(_time)}),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  ElevatedButton(
                    onPressed: editingA1 ? null : _pickTime,
                    child: Text(context.t('common.pick')),
                  ),
                ],
              ),
              const Divider(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: Text(context.t('event.oneOff')),
                    selected: _oneOff,
                    onSelected: editingA1
                        ? null
                        : (v) => setState(() {
                              _oneOff = v;
                              if (_oneOff) {
                                _weekly = false;
                                _daily = false;
                                _weekdays.clear();
                              } else {
                                _oneOffDate = null;
                              }
                            }),
                  ),
                  FilterChip(
                    label: Text(context.t('event.weekly')),
                    selected: _weekly,
                    onSelected: editingA1
                        ? null
                        : (v) => setState(() {
                              _weekly = v;
                              if (_weekly) {
                                _oneOff = false;
                                _oneOffDate = null;
                                _daily = false;
                              } else {
                                _weekdays.clear();
                              }
                            }),
                  ),
                  if (!_weekly && !_oneOff)
                    FilterChip(
                      label: Text(context.t('event.daily')),
                      selected: _daily,
                      onSelected: editingA1 ? null : (v) => setState(() => _daily = v),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _buildOneOffPicker(),
              _buildWeekdayPicker(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: Text(context.t('event.snooze5')),
                    selected: _snooze,
                    onSelected: editingA1 ? null : (v) => setState(() => _snooze = v),
                  ),
                  FilterChip(
                    label: Text(context.t('event.callBefore5')),
                    selected: _callBefore,
                    onSelected: editingA1 ? null : (v) => setState(() => _callBefore = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: _requireMathToDismiss ? scheme.primaryContainer : scheme.surfaceVariant,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: CheckboxListTile(
                  value: _requireMathToDismiss,
                  onChanged: editingA1 ? null : (v) => setState(() => _requireMathToDismiss = v ?? false),
                  title: Text(context.t('event.mathDismiss')),
                  subtitle: Text(context.t('event.mathDismissDescription')),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<EventPriority>(
                value: _priority,
                items: EventPriority.values
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                onChanged: editingA1 ? null : (v) => setState(() => _priority = v ?? _priority),
                decoration: InputDecoration(labelText: context.t('event.priority')),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(_editing == null ? context.t('event.save') : context.t('event.saveChanges')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
