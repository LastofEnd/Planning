import 'package:flutter/material.dart';
import 'package:smart_alarm_planner/models/event_model.dart';

Color _colorForPriority(EventPriority p) {
  switch (p) {
    case EventPriority.A1:
      return const Color(0xFFD32F2F);
    case EventPriority.A2:
      return const Color(0xFFF57C00);
    case EventPriority.B1:
      return const Color(0xFF1976D2);
    case EventPriority.C1:
      return const Color(0xFF388E3C);
    case EventPriority.D1:
      return const Color(0xFF616161);
  }
}

class PriorityBadge extends StatelessWidget {
  final EventPriority priority;
  const PriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final c = _colorForPriority(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c, width: 1),
      ),
      child: Text(
        priority.name,
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
