import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:smart_alarm_planner/i18n/app_controller.dart';
import 'package:smart_alarm_planner/models/event_model.dart';
import 'package:smart_alarm_planner/services/alarm_service.dart';
import 'package:smart_alarm_planner/services/storage_service.dart';
import 'package:smart_alarm_planner/widgets/priority_badge.dart';

class ConstructorScreen extends StatefulWidget {
  const ConstructorScreen({super.key});

  @override
  State<ConstructorScreen> createState() => _ConstructorScreenState();
}

class _ConstructorScreenState extends State<ConstructorScreen>
    with TickerProviderStateMixin {
  List<EventModel> _all = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _all = await StorageService.instance.loadEvents();
    setState(() {});
  }

  bool _isOneOff(EventModel e) {
    try {
      final v = (e as dynamic).isOneOff;
      return v == true;
    } catch (_) {
      return false;
    }
  }

  DateTime? _oneOffDate(EventModel e) {
    try {
      final v = (e as dynamic).oneOffDate;
      if (v is DateTime) return v;
      return null;
    } catch (_) {
      return null;
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  int _toMin(TimeOfDay t) => t.hour * 60 + t.minute;

  TimeOfDay _fromMin(int m) =>
      TimeOfDay(hour: ((m ~/ 60) % 24), minute: m % 60);

  bool _canDrag(EventModel e) =>
      !(e.priority == EventPriority.A1 || e.priority == EventPriority.A2);

  bool _canEdit(EventModel e) => e.priority != EventPriority.A1;

  List<EventModel> _visibleForTab(int tabIndex) {
    late final List<EventModel> list;
    if (tabIndex == 7) {
      list = _all.where((e) => _isOneOff(e)).toList();

      list.sort((a, b) {
        final ad = _oneOffDate(a);
        final bd = _oneOffDate(b);
        if (ad == null && bd == null) {
          return _toMin(a.time).compareTo(_toMin(b.time));
        } else if (ad == null) {
          return 1;
        } else if (bd == null) {
          return -1;
        } else {
          final cmp = ad.compareTo(bd);
          if (cmp != 0) return cmp;
          return _toMin(a.time).compareTo(_toMin(b.time));
        }
      });
    } else {
      final wd = tabIndex + 1;
      list = _all.where((e) {
        if (e.weekly) return e.weekdays.contains(wd);
        if (e.repeatDaily) return true;
        return false;
      }).toList();

      list.sort((a, b) => _toMin(a.time).compareTo(_toMin(b.time)));
    }
    return list;
  }

  Future<bool> _applyNewTime({
    required EventModel e,
    required TimeOfDay newTime,
    required int tabIndex,
  }) async {
    if (tabIndex >= 0 && tabIndex <= 6) {
      final wd = tabIndex + 1;
      final conflicts = await StorageService.instance.weeklyConflicts(
        editingId: e.id,
        time: newTime,
        weekdays: e.repeatDaily ? [1, 2, 3, 4, 5, 6, 7] : [wd],
      );
      if (conflicts.isNotEmpty) {
        final labels = conflicts.map((d) => context.weekdayShort(d)).join(', ');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t('event.timeConflict', {'days': labels}))),
          );
        }
        return false;
      }
    }

    e.time = newTime;
    await StorageService.instance.upsertEvent(e);
    await AlarmService.instance.scheduleForEvent(e);

    await _load();
    return true;
  }

  Future<TimeOfDay?> _showBetweenSlider(TimeOfDay start, TimeOfDay end) async {
    final startMin = _toMin(start);
    final endMin = _toMin(end);
    final gap = endMin - startMin;
    if (gap <= 5) return null;

    final divisions = gap ~/ 5;
    int valueMin = ((startMin + endMin) ~/ 2);
    valueMin = (valueMin / 5).round() * 5;

    return showModalBottomSheet<TimeOfDay>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.t('constructor.pickTimeBetween', {'start': _fmt(start), 'end': _fmt(end)}),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _fmt(_fromMin(valueMin)),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Slider(
                    min: 0,
                    max: divisions.toDouble(),
                    divisions: divisions,
                    value: ((valueMin - startMin) / 5)
                        .clamp(0, divisions)
                        .toDouble(),
                    onChanged: (v) {
                      setSt(() => valueMin = startMin + v.round() * 5);
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(context.t('common.cancel')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, _fromMin(valueMin)),
                          child: Text(context.t('common.done')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(ctx, null),
                    icon: const Icon(Icons.schedule),
                    label: Text(context.t('constructor.otherTime')),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _afterDropPickTime({
    required int tabIndex,
    required EventModel moved,
    required EventModel? prev,
    required EventModel? next,
  }) async {
    if (prev != null && next != null) {
      final between = await _showBetweenSlider(prev.time, next.time);
      if (between != null) {
        await _applyNewTime(e: moved, newTime: between, tabIndex: tabIndex);
        return;
      }
      final t = await showTimePicker(context: context, initialTime: moved.time);
      if (t != null) {
        await _applyNewTime(e: moved, newTime: t, tabIndex: tabIndex);
      }
    } else {
      final t = await showTimePicker(context: context, initialTime: moved.time);
      if (t != null) {
        await _applyNewTime(e: moved, newTime: t, tabIndex: tabIndex);
      }
    }
  }

  Widget _buildListForTab(int tabIndex) {
    final items = _visibleForTab(tabIndex);
    if (items.isEmpty) return Center(child: Text(context.t('event.noEvents')));

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) =>
          _onReorderInTab(tabIndex, oldIndex, newIndex),
      itemBuilder: (context, i) {
        final e = items[i];
        final canDrag = _canDrag(e);
        final canEdit = _canEdit(e);

        final isOneOff = _isOneOff(e);
        final date = _oneOffDate(e);

        return ListTile(
          key: ValueKey('${e.id}#$tabIndex#$i'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          leading: canDrag
              ? ReorderableDragStartListener(
                  index: i,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Icon(Icons.drag_handle),
                  ),
                )
              : const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(Icons.lock, color: Colors.grey),
                ),
          title: Row(
            children: [
              Text(
                _fmt(e.time),
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  e.title,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Wrap(
            spacing: 6,
            runSpacing: -6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PriorityBadge(priority: e.priority),
              if (e.enabled)
                Chip(
                  label: Text(context.t('common.enabled')),
                  visualDensity: VisualDensity.compact,
                ),
              if (tabIndex != 7 && e.repeatDaily)
                Chip(
                  label: Text(context.t('event.daily')),
                  visualDensity: VisualDensity.compact,
                ),
              if (tabIndex != 7 && e.weekly && e.weekdays.isNotEmpty)
                Chip(
                  label: Text(e.weekdays.map((d) => context.weekdayShort(d)).join(' ')),
                  visualDensity: VisualDensity.compact,
                ),

              if (tabIndex == 7 && isOneOff)
                Chip(
                  label: Text(date != null ? _fmtDate(date) : context.t('event.noDateSpecified')),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 96),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 0.9,
                  child: Switch(
                    value: e.enabled,
                    onChanged: (v) async {
                      e.enabled = v;
                      await StorageService.instance.upsertEvent(e);
                      if (v) {
                        await AlarmService.instance.scheduleForEvent(e);
                      } else {
                        await AlarmService.instance.cancelForEvent(e.id);
                      }
                      _load();
                    },
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: context.t('common.actions'),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      if (!canEdit) return;
                      await Navigator.of(context).pushNamed('/create', arguments: e);
                      _load();
                    } else if (value == 'delete') {
                      await AlarmService.instance.cancelForEvent(e.id);
                      await StorageService.instance.deleteEvent(e.id);
                      _load();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      enabled: canEdit,
                      child: Row(
                        children: [
                          const Icon(Icons.edit, size: 18),
                          const SizedBox(width: 8),
                          Text(canEdit ? context.t('common.edit') : context.t('common.editForbidden')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete, size: 18),
                          const SizedBox(width: 8),
                          Text(context.t('common.delete')),
                        ],
                      ),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onReorderInTab(int tabIndex, int oldIndex, int newIndex) async {
    final visible = _visibleForTab(tabIndex);
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = visible[oldIndex];

    if (!_canDrag(moved)) return;

    visible.removeAt(oldIndex);
    visible.insert(newIndex, moved);
    setState(() {});

    final idx = visible.indexWhere((e) => e.id == moved.id);
    final prev = idx > 0 ? visible[idx - 1] : null;
    final next = idx >= 0 && idx < visible.length - 1 ? visible[idx + 1] : null;

    await _afterDropPickTime(
      tabIndex: tabIndex,
      moved: moved,
      prev: prev,
      next: next,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 8,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.t('constructor.title')),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: context.weekdayShort(1)),
              Tab(text: context.weekdayShort(2)),
              Tab(text: context.weekdayShort(3)),
              Tab(text: context.weekdayShort(4)),
              Tab(text: context.weekdayShort(5)),
              Tab(text: context.weekdayShort(6)),
              Tab(text: context.weekdayShort(7)),
              Tab(text: context.t('event.once')),
            ],
          ),
        ),
        body: TabBarView(
          children: List.generate(8, (i) => _buildListForTab(i)),
        ),
      ),
    );
  }
}
