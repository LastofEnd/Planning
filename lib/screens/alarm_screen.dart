import 'dart:math';
import 'package:flutter/material.dart';
import 'package:smart_alarm_planner/i18n/app_controller.dart';
import 'package:smart_alarm_planner/models/event_model.dart';
import 'package:smart_alarm_planner/services/alarm_service.dart';
import 'package:smart_alarm_planner/services/native_alarm.dart';
import 'package:smart_alarm_planner/services/storage_service.dart';

class AlarmFullScreen extends StatefulWidget {
  const AlarmFullScreen({super.key});

  @override
  State<AlarmFullScreen> createState() => _AlarmFullScreenState();
}

class _AlarmFullScreenState extends State<AlarmFullScreen> {
  final _rng = Random();
  final List<_MathTask> _tasks = [];
  final List<TextEditingController> _answers = [];

  EventModel? _event;
  bool _noSnoozeOnce = false;
  bool _showChallenge = false;
  String? _loadedId;

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    for (final c in _answers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load(String id) async {
    final items = await StorageService.instance.loadEvents();
    EventModel? found;
    for (final item in items) {
      if (item.id == id) {
        found = item;
        break;
      }
    }
    if (found == null && items.isNotEmpty) found = items.first;
    if (!mounted) return;
    setState(() {
      _event = found;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;

    if (arg is String) {
      if (_loadedId != arg) {
        _loadedId = arg;
        _load(arg);
      }
    } else if (arg is Map) {
      final id = arg['id'] as String?;
      _noSnoozeOnce = (arg['noSnooze'] as bool?) ?? false;
      if (id != null && _loadedId != id) {
        _loadedId = id;
        _load(id);
      }
    }
  }

  Future<void> _snooze() async {
    if (_event == null) return;
    await AlarmService.instance.snooze5(_event!.id);
    await NativeAlarm.stopRinging();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _stop() async {
    await NativeAlarm.stopRinging();
    if (mounted) Navigator.pop(context);
  }

  void _startChallenge() {
    for (final c in _answers) {
      c.dispose();
    }
    _tasks.clear();
    _answers.clear();

    for (int i = 0; i < 3; i++) {
      var a = 10 + _rng.nextInt(90);
      var b = 10 + _rng.nextInt(90);
      final isAdd = _rng.nextBool();
      if (!isAdd && b > a) {
        final temp = a;
        a = b;
        b = temp;
      }
      final task = _MathTask(
        left: a,
        right: b,
        sign: isAdd ? '+' : '-',
        answer: isAdd ? a + b : a - b,
      );
      _tasks.add(task);
      _answers.add(TextEditingController());
    }

    setState(() => _showChallenge = true);
  }

  bool get _allAnswersCorrect {
    if (_tasks.length != 3 || _answers.length != 3) return false;
    for (int i = 0; i < 3; i++) {
      final value = int.tryParse(_answers[i].text.trim());
      if (value != _tasks[i].answer) return false;
    }
    return true;
  }

  Widget _alarmButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    Color? background,
    Color? foreground,
  }) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  Widget _buildChallengeCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('alarm.solveTitle'),
                style: const TextStyle(
                  color: Color(0xFF1D2A52),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.t('alarm.solveSubtitle'),
                style: const TextStyle(color: Color(0xFF667085), fontSize: 13),
              ),
              const SizedBox(height: 14),
              ...List.generate(_tasks.length, (i) {
                final task = _tasks[i];
                return Padding(
                  padding: EdgeInsets.only(bottom: i == _tasks.length - 1 ? 0 : 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${task.left} ${task.sign} ${task.right} =',
                          style: const TextStyle(
                            color: Color(0xFF1D2A52),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 96,
                        child: TextField(
                          controller: _answers[i],
                          keyboardType: const TextInputType.numberWithOptions(signed: true),
                          textInputAction: i == _tasks.length - 1 ? TextInputAction.done : TextInputAction.next,
                          textAlign: TextAlign.center,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '?',
                            filled: true,
                            fillColor: const Color(0xFFF2F4F7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: const TextStyle(
                            color: Color(0xFF1D2A52),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final solved = _allAnswersCorrect;
                  return SizedBox(
                    width: double.infinity,
                    child: _alarmButton(
                      onPressed: solved ? _stop : null,
                      icon: Icons.stop_circle_outlined,
                      label: context.t('alarm.dismiss'),
                      background: solved ? const Color(0xFF1D2A52) : const Color(0xFFE4E7EC),
                      foreground: solved ? Colors.white : const Color(0xFF98A2B3),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(EventModel e) {
    final items = <Widget>[];

    if (e.canSnooze5 && !_noSnoozeOnce && !_showChallenge) {
      items.add(
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white10,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _snooze,
          icon: const Icon(Icons.snooze),
          label: Text(context.t('alarm.snooze5')),
        ),
      );
    }

    if (e.requireMathToDismiss) {
      if (!_showChallenge) {
        items.add(
          _alarmButton(
            onPressed: _startChallenge,
            icon: Icons.calculate_outlined,
            label: context.t('alarm.solveExamples'),
            background: Colors.white,
            foreground: const Color(0xFF1D2A52),
          ),
        );
      }
    } else {
      items.add(
        _alarmButton(
          onPressed: _stop,
          icon: Icons.stop_circle_outlined,
          label: context.t('alarm.turnOff'),
          background: Colors.white,
          foreground: const Color(0xFF1D2A52),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = _event;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF101828), Color(0xFF1D2A52)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: e == null
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 36),
                            Text(
                              _fmt(e.time),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                e.title,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (e.description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                child: Text(
                                  e.description,
                                  style: const TextStyle(color: Colors.white60, fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            if (e.requireMathToDismiss) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Text(
                                  context.t('alarm.mathActive'),
                                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                            SizedBox(height: _showChallenge ? 24 : 80),
                            if (_showChallenge) _buildChallengeCard(),
                            const SizedBox(height: 24),
                            _buildActions(e),
                            const SizedBox(height: 48),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _MathTask {
  final int left;
  final int right;
  final String sign;
  final int answer;

  const _MathTask({
    required this.left,
    required this.right,
    required this.sign,
    required this.answer,
  });
}
