import 'package:flutter/material.dart';
import 'package:smart_alarm_planner/i18n/app_controller.dart';
import 'package:smart_alarm_planner/models/event_model.dart';
import 'package:smart_alarm_planner/screens/create_event_screen.dart';
import 'package:smart_alarm_planner/services/alarm_service.dart';
import 'package:smart_alarm_planner/services/storage_service.dart';
import 'package:smart_alarm_planner/widgets/priority_badge.dart';

class EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback onChanged;

  const EventCard({
    super.key,
    required this.event,
    required this.onChanged,
  });

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';

  String? _scheduleText(BuildContext context) {
    if (event.weekly && event.weekdays.isNotEmpty) {
      final days = [...event.weekdays]..sort();
      return days.map((d) => context.weekdayShort(d)).join(', ');
    }
    if (!event.weekly && event.repeatDaily) return context.t('event.daily');
    if (event.isOneOff && event.oneOffDate != null) return _fmtDate(event.oneOffDate!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canEdit = event.priority != EventPriority.A1;
    final scheduleText = _scheduleText(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 44,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.alarm,
                    color: event.enabled ? scheme.primary : scheme.outline,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _fmt(event.time),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      event.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PriorityBadge(priority: event.priority),
                      if (scheduleText != null) _SmallInfoChip(text: scheduleText),
                      if (event.canSnooze5) _SmallInfoChip(text: context.t('event.snooze5')),
                      if (event.requireMathToDismiss) _SmallInfoChip(text: context.t('event.mathDismissShort')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 0.9,
                  child: Switch(
                    value: event.enabled,
                    onChanged: (v) async {
                      event.enabled = v;
                      await StorageService.instance.upsertEvent(event);
                      if (v) {
                        await AlarmService.instance.scheduleForEvent(event);
                      } else {
                        await AlarmService.instance.cancelForEvent(event.id);
                      }
                      onChanged();
                    },
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: context.t('common.actions'),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      if (!canEdit) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CreateEventScreen(),
                          settings: RouteSettings(arguments: event),
                        ),
                      );
                      onChanged();
                    } else if (value == 'delete') {
                      await AlarmService.instance.cancelForEvent(event.id);
                      await StorageService.instance.deleteEvent(event.id);
                      onChanged();
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
          ],
        ),
      ),
    );
  }
}

class _SmallInfoChip extends StatelessWidget {
  final String text;

  const _SmallInfoChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 168),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
