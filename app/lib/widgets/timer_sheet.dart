import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

Future<void> showTimerSheet(BuildContext context, AppState appState) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _TimerSheet(appState: appState),
  );
}

class _TimerSheet extends StatefulWidget {
  final AppState appState;
  const _TimerSheet({required this.appState});

  @override
  State<_TimerSheet> createState() => _TimerSheetState();
}

class _TimerSheetState extends State<_TimerSheet> {
  // Quick-pick durations in minutes.
  static const _presets = [5, 10, 15, 20, 30, 45, 60, 90, 120];

  int _hours = 0;
  int _minutes = 15;

  int get _totalMinutes => _hours * 60 + _minutes;

  void _applyPreset(int minutes) {
    setState(() {
      _hours = minutes ~/ 60;
      _minutes = minutes % 60;
    });
  }

  void _bumpHours(int delta) => setState(() => _hours = (_hours + delta).clamp(0, 23));
  void _bumpMinutes(int delta) {
    setState(() {
      var total = _totalMinutes + delta;
      if (total < 0) total = 0;
      if (total > 23 * 60 + 59) total = 23 * 60 + 59;
      _hours = total ~/ 60;
      _minutes = total % 60;
    });
  }

  String _presetLabel(int minutes) => minutes % 60 == 0 ? '${minutes ~/ 60}h' : '${minutes}m';

  Future<void> _start() async {
    if (_totalMinutes <= 0) return;
    await widget.appState.startCustomTimer(Duration(minutes: _totalMinutes));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.accentBlush;
    final replacing = widget.appState.customTimerActive;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: AppColors.dragHandle, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text('Set a timer',
              style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            replacing
                ? 'This replaces the timer you already have running.'
                : 'Counts down in the same spot as the feed reminder and rings the alarm when it is up.',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((m) {
              final active = _totalMinutes == m;
              return OutlinedButton(
                onPressed: () => _applyPreset(m),
                style: OutlinedButton.styleFrom(
                  backgroundColor: active ? accent : Colors.white,
                  foregroundColor: active ? Colors.white : AppColors.gearStroke,
                  side: active ? BorderSide.none : const BorderSide(color: AppColors.border, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(_presetLabel(m), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('CUSTOM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _Stepper(label: 'hours', value: _hours, onMinus: () => _bumpHours(-1), onPlus: () => _bumpHours(1))),
              const SizedBox(width: 12),
              Expanded(child: _Stepper(label: 'minutes', value: _minutes, onMinus: () => _bumpMinutes(-5), onPlus: () => _bumpMinutes(5))),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _totalMinutes <= 0 ? null : _start,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.surfaceSecondary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(replacing ? 'Replace timer' : 'Start timer',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _Stepper({required this.label, required this.value, required this.onMinus, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _RoundButton(icon: Icons.remove, onTap: onMinus),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$value',
                  style: const TextStyle(fontFamily: balooFamily, fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            ],
          ),
          _RoundButton(icon: Icons.add, onTap: onPlus),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.settingsBg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 18, color: AppColors.reminderTitleText),
        ),
      ),
    );
  }
}
