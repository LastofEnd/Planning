import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:smart_alarm_planner/i18n/app_controller.dart';
import 'package:smart_alarm_planner/models/event_model.dart';
import 'package:smart_alarm_planner/services/storage_service.dart';

class MyTimelineScreen extends StatefulWidget {
  const MyTimelineScreen({super.key});

  @override
  State<MyTimelineScreen> createState() => _MyTimelineScreenState();
}

class _MyTimelineScreenState extends State<MyTimelineScreen> {
  DateTime _selectedDate = DateTime.now();
  List<EventModel> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _toMin(TimeOfDay t) => t.hour * 60 + t.minute;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _fmtMin(int minutes) {
    if (minutes >= 1440) return '24:00';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _durationText(int minutes) {
    return context.durationText(minutes);
  }

  bool _isVisibleForDate(EventModel e, DateTime date) {
    if (!e.enabled) return false;
    if (e.repeatDaily) return true;
    if (e.weekly && e.weekdays.contains(date.weekday)) return true;
    if (e.isOneOff && e.oneOffDate != null) return _sameDay(e.oneOffDate!, date);
    if (!e.weekly && !e.repeatDaily && !e.isOneOff) return _sameDay(date, DateTime.now());
    return false;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await StorageService.instance.loadEvents();
    final visible = all.where((e) => _isVisibleForDate(e, _selectedDate)).toList();
    visible.sort((a, b) => _toMin(a.time).compareTo(_toMin(b.time)));
    if (!mounted) return;
    setState(() {
      _events = visible;
      _loading = false;
    });
  }

  void _changeDay(int delta) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: delta)));
    _load();
  }

  void _goToday() {
    setState(() => _selectedDate = DateTime.now());
    _load();
  }

  List<_TimelineBlock> _blocks() {
    final result = <_TimelineBlock>[];
    for (var i = 0; i < _events.length; i++) {
      final start = _toMin(_events[i].time);
      final rawEnd = i + 1 < _events.length ? _toMin(_events[i + 1].time) : 1440;
      final end = rawEnd <= start ? start + 1 : rawEnd;
      result.add(_TimelineBlock(event: _events[i], start: start, end: end));
    }
    return result;
  }

  Color _colorFor(EventPriority priority, ColorScheme scheme) {
    switch (priority) {
      case EventPriority.A1:
        return Colors.redAccent;
      case EventPriority.A2:
        return Colors.deepOrangeAccent;
      case EventPriority.B1:
        return Colors.amber.shade700;
      case EventPriority.C1:
        return scheme.primary;
      case EventPriority.D1:
        return Colors.blueGrey;
    }
  }

  Widget _buildDateHeader(ColorScheme scheme) {
    final wd = context.weekdayShort(_selectedDate.weekday);
    final isToday = _sameDay(_selectedDate, DateTime.now());

    return Card(
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            IconButton.filledTonal(
              onPressed: () => _changeDay(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    isToday ? context.t('common.today') : wd,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_fmtDate(_selectedDate)} · $wd',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: () => _changeDay(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(ColorScheme scheme, List<_TimelineBlock> blocks) {
    final total = blocks.fold<int>(0, (sum, b) => sum + b.duration);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.event_note_outlined,
              title: context.t('timeline.events'),
              value: '${_events.length}',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.timelapse_outlined,
              title: context.t('timeline.covered'),
              value: _durationText(total),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(ColorScheme scheme, List<_TimelineBlock> blocks) {
    if (blocks.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildDateHeader(scheme),
          const SizedBox(height: 80),
          const Icon(Icons.timeline_outlined, size: 56),
          const SizedBox(height: 12),
          Center(child: Text(context.t('timeline.empty'))),
        ],
      );
    }

    final rangeStart = blocks.first.start;
    final rangeEnd = blocks.last.end;
    final range = math.max(1, rangeEnd - rangeStart);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _buildDateHeader(scheme),
          _buildStats(scheme, blocks),
          Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.view_timeline_outlined, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        context.t('timeline.bar'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 3.0;
                      final baseWidth = math.max(constraints.maxWidth, 940.0);
                      final widths = blocks
                          .map((b) => math.max(88.0, baseWidth * b.duration / range))
                          .toList();
                      final totalWidth = widths.fold<double>(0, (sum, w) => sum + w) + gap * math.max(0, blocks.length - 1);
                      final now = DateTime.now();
                      final showNow = _sameDay(_selectedDate, now) &&
                          now.hour * 60 + now.minute >= blocks.first.start &&
                          now.hour * 60 + now.minute <= blocks.last.end;

                      double posForMinute(int minute) {
                        var left = 0.0;
                        for (var i = 0; i < blocks.length; i++) {
                          final block = blocks[i];
                          final width = widths[i];
                          if (minute <= block.end) {
                            final local = (minute - block.start).clamp(0, block.duration);
                            return left + width * local / math.max(1, block.duration);
                          }
                          left += width + gap;
                        }
                        return totalWidth;
                      }

                      final nowPosition = showNow ? posForMinute(now.hour * 60 + now.minute) : null;

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: totalWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 98,
                                child: Stack(
                                  children: [
                                    Row(
                                      children: [
                                        for (var i = 0; i < blocks.length; i++) ...[
                                          _TimelineSegment(
                                            block: blocks[i],
                                            width: widths[i],
                                            color: _colorFor(blocks[i].event.priority, scheme),
                                            durationText: _durationText(blocks[i].duration),
                                            fmtMin: _fmtMin,
                                          ),
                                          if (i != blocks.length - 1) const SizedBox(width: gap),
                                        ],
                                      ],
                                    ),
                                    if (nowPosition != null)
                                      Positioned(
                                        left: math.max(0.0, math.min(nowPosition, totalWidth - 2)),
                                        top: 0,
                                        bottom: 0,
                                        child: Column(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: scheme.inverseSurface,
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                context.t('timeline.now'),
                                                style: TextStyle(
                                                  color: scheme.onInverseSurface,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Container(
                                                width: 2,
                                                color: scheme.inverseSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 28,
                                child: Stack(
                                  children: [
                                    Positioned(
                                      left: 0,
                                      child: Text(
                                        _fmtMin(blocks.first.start),
                                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                                      ),
                                    ),
                                    for (var i = 0; i < blocks.length; i++)
                                      Positioned(
                                        left: widths.take(i + 1).fold<double>(0, (sum, w) => sum + w) + gap * i - 22,
                                        child: Text(
                                          _fmtMin(blocks[i].end),
                                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              context.t('timeline.blocks'),
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final block in blocks)
            _TimelineBlockCard(
              block: block,
              durationText: _durationText(block.duration),
              fmtMin: _fmtMin,
              onChanged: _load,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('timeline.title')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildTimeline(scheme, _blocks()),
    );
  }
}

class _TimelineBlock {
  final EventModel event;
  final int start;
  final int end;

  const _TimelineBlock({
    required this.event,
    required this.start,
    required this.end,
  });

  int get duration => math.max(1, end - start);
}

class _TimelineSegment extends StatelessWidget {
  final _TimelineBlock block;
  final double width;
  final Color color;
  final String durationText;
  final String Function(int minutes) fmtMin;

  const _TimelineSegment({
    required this.block,
    required this.width,
    required this.color,
    required this.durationText,
    required this.fmtMin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 90,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${fmtMin(block.start)}–${fmtMin(block.end)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            block.event.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            durationText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.86),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineBlockCard extends StatelessWidget {
  final _TimelineBlock block;
  final String durationText;
  final String Function(int minutes) fmtMin;
  final VoidCallback onChanged;

  const _TimelineBlockCard({
    required this.block,
    required this.durationText,
    required this.fmtMin,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: const Icon(Icons.schedule),
        ),
        title: Text(
          block.event.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('${fmtMin(block.start)}–${fmtMin(block.end)} · $durationText'),
        trailing: Text(
          block.event.priority.name,
          style: TextStyle(
            color: scheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        onTap: block.event.priority == EventPriority.A1
            ? null
            : () async {
                await Navigator.of(context).pushNamed('/create', arguments: block.event);
                onChanged();
              },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
