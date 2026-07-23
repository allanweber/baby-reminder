import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/app_state.dart' show pad2;
import '../theme/app_theme.dart';

/// Custom replacement for [showDatePicker]: a calendar grid where tapping a
/// day immediately selects it and closes the sheet (no separate OK step).
Future<DateTime?> pickDateSheet(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _DatePickerSheet(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

/// Custom replacement for [showTimePicker]: an analog clock face. Tapping or
/// dragging on the dial sets the active field (hour, then minute). Unlike the
/// stock 24-value dial, only 12 well-spaced numbers sit on the ring at a time
/// (12-hour with an AM/PM toggle), so nothing is cramped.
Future<TimeOfDay?> pickTimeSheet(BuildContext context, {required TimeOfDay initialTime}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _TimePickerSheet(initialTime: initialTime),
  );
}

class _SheetChrome extends StatelessWidget {
  final Widget child;
  const _SheetChrome({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: AppColors.dragHandle, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _DatePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  const _DatePickerSheet({required this.initialDate, required this.firstDate, required this.lastDate});

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late DateTime _month;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialDate.year, widget.initialDate.month, 1);
  }

  bool get _canGoPrev => _month.isAfter(DateTime(widget.firstDate.year, widget.firstDate.month, 1));
  bool get _canGoNext => _month.isBefore(DateTime(widget.lastDate.year, widget.lastDate.month, 1));

  void _changeMonth(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta, 1));

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7; // 0 = Sunday
    final today = DateTime.now();

    return _SheetChrome(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavArrow(icon: Icons.chevron_left, onTap: _canGoPrev ? () => _changeMonth(-1) : null),
              Text(
                '${_monthNames[_month.month - 1]} ${_month.year}',
                style: const TextStyle(fontFamily: balooFamily, fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              _NavArrow(icon: Icons.chevron_right, onTap: _canGoNext ? () => _changeMonth(1) : null),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 2,
            childAspectRatio: 1,
            children: [
              for (var i = 0; i < firstWeekday; i++) const SizedBox.shrink(),
              for (var day = 1; day <= daysInMonth; day++)
                _DayCell(
                  day: day,
                  isSelected: widget.initialDate.year == _month.year &&
                      widget.initialDate.month == _month.month &&
                      widget.initialDate.day == day,
                  isToday: today.year == _month.year && today.month == _month.month && today.day == day,
                  enabled: !DateTime(_month.year, _month.month, day).isBefore(DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day)) &&
                      !DateTime(_month.year, _month.month, day).isAfter(DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day)),
                  onTap: () => Navigator.of(context).pop(DateTime(_month.year, _month.month, day)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSecondary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 20, color: onTap == null ? AppColors.textMuted2 : AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool isSelected;
  final bool isToday;
  final bool enabled;
  final VoidCallback onTap;
  const _DayCell({required this.day, required this.isSelected, required this.isToday, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = isSelected ? Colors.white : (enabled ? AppColors.textPrimary : AppColors.textMuted2);
    return Center(
      child: Material(
        color: isSelected ? AppColors.accentBlush : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: isToday && !isSelected
                ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.accentBlush, width: 1.4))
                : null,
            child: Text('$day', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: fg)),
          ),
        ),
      ),
    );
  }
}

enum _TimeField { hour, minute }

class _TimePickerSheet extends StatefulWidget {
  final TimeOfDay initialTime;
  const _TimePickerSheet({required this.initialTime});

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late int _hour24; // 0..23
  late int _minute; // 0..59
  _TimeField _field = _TimeField.hour;

  @override
  void initState() {
    super.initState();
    _hour24 = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
  }

  bool get _isPm => _hour24 >= 12;

  int get _hour12 {
    final h = _hour24 % 12;
    return h == 0 ? 12 : h;
  }

  void _setHour12(int h12) {
    final base = h12 % 12; // 12 -> 0
    setState(() => _hour24 = _isPm ? base + 12 : base);
  }

  void _setAmPm(bool pm) => setState(() {
        final base = _hour24 % 12;
        _hour24 = pm ? base + 12 : base;
      });

  /// [turns] is the tapped/dragged angle clockwise from the top, in [0, 1).
  void _onDialAngle(double turns) {
    if (_field == _TimeField.hour) {
      final idx = (turns * 12).round() % 12; // 0 == 12 o'clock
      _setHour12(idx == 0 ? 12 : idx);
    } else {
      setState(() => _minute = (turns * 60).round() % 60);
    }
  }

  /// After the user lifts their finger on the hour ring, advance to minutes.
  void _onDialReleased() {
    if (_field == _TimeField.hour) setState(() => _field = _TimeField.minute);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetChrome(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Select time',
            style: TextStyle(fontFamily: balooFamily, fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TimeFieldChip(
                text: pad2(_hour12),
                active: _field == _TimeField.hour,
                onTap: () => setState(() => _field = _TimeField.hour),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(':', style: TextStyle(fontFamily: balooFamily, fontSize: 34, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              _TimeFieldChip(
                text: pad2(_minute),
                active: _field == _TimeField.minute,
                onTap: () => setState(() => _field = _TimeField.minute),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AmPmChip(label: 'AM', active: !_isPm, onTap: () => _setAmPm(false)),
                  const SizedBox(height: 6),
                  _AmPmChip(label: 'PM', active: _isPm, onTap: () => _setAmPm(true)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ClockDial(
            hourMode: _field == _TimeField.hour,
            selectedValue: _field == _TimeField.hour ? _hour12 : _minute,
            onAngle: _onDialAngle,
            onReleased: _onDialReleased,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.settingsBg,
                      foregroundColor: AppColors.reminderTitleText,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(TimeOfDay(hour: _hour24, minute: _minute)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlush,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('OK', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeFieldChip extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;
  const _TimeFieldChip({required this.text, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.accentBlush.withOpacity(0.16) : AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 76,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? AppColors.accentBlush : Colors.transparent, width: 2),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: balooFamily,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: active ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _AmPmChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _AmPmChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.accentBlush : AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 46,
          height: 27,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// The circular clock face. Twelve numbers sit on the ring; tapping or dragging
/// anywhere reports the angle (clockwise turns from the top) back to the parent.
class _ClockDial extends StatelessWidget {
  final bool hourMode;
  final int selectedValue; // hour 1..12, or minute 0..59
  final ValueChanged<double> onAngle;
  final VoidCallback onReleased;
  const _ClockDial({
    required this.hourMode,
    required this.selectedValue,
    required this.onAngle,
    required this.onReleased,
  });

  static const double _size = 268;
  static const double _numberRadius = 106;

  void _report(Offset local) {
    const center = Offset(_size / 2, _size / 2);
    final v = local - center;
    if (v.distance < 4) return;
    // atan2(x, -y): 0 at the top, increasing clockwise.
    var turns = math.atan2(v.dx, -v.dy) / (2 * math.pi);
    if (turns < 0) turns += 1;
    onAngle(turns);
  }

  @override
  Widget build(BuildContext context) {
    // Angle (turns from top) of the currently selected value, for the hand.
    final selectedTurns = hourMode ? (selectedValue % 12) / 12 : selectedValue / 60;

    final numbers = <Widget>[];
    for (var i = 0; i < 12; i++) {
      final value = hourMode ? (i == 0 ? 12 : i) : i * 5;
      final turns = i / 12;
      final theta = turns * 2 * math.pi;
      final dx = _numberRadius * math.sin(theta);
      final dy = -_numberRadius * math.cos(theta);
      final isSelected = value == selectedValue;
      numbers.add(Positioned(
        left: _size / 2 + dx - 20,
        top: _size / 2 + dy - 20,
        width: 40,
        height: 40,
        child: Center(
          child: Text(
            hourMode ? '$value' : pad2(value),
            style: TextStyle(
              fontFamily: balooFamily,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ));
    }

    return GestureDetector(
      onTapDown: (d) => _report(d.localPosition),
      onPanStart: (d) => _report(d.localPosition),
      onPanUpdate: (d) => _report(d.localPosition),
      onPanEnd: (_) => onReleased(),
      onTapUp: (_) => onReleased(),
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ClockFacePainter(selectedTurns: selectedTurns, numberRadius: _numberRadius),
              ),
            ),
            IgnorePointer(child: Stack(children: numbers)),
          ],
        ),
      ),
    );
  }
}

class _ClockFacePainter extends CustomPainter {
  final double selectedTurns;
  final double numberRadius;
  const _ClockFacePainter({required this.selectedTurns, required this.numberRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final face = Paint()..color = AppColors.surfaceSecondary;
    canvas.drawCircle(center, size.width / 2, face);

    final theta = selectedTurns * 2 * math.pi;
    final knob = center + Offset(numberRadius * math.sin(theta), -numberRadius * math.cos(theta));

    final accent = Paint()..color = AppColors.accentBlush;
    // Hand.
    final hand = Paint()
      ..color = AppColors.accentBlush
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, knob, hand);
    // Selection knob + center hub.
    canvas.drawCircle(knob, 21, accent);
    canvas.drawCircle(center, 5, accent);
  }

  @override
  bool shouldRepaint(covariant _ClockFacePainter old) =>
      old.selectedTurns != selectedTurns || old.numberRadius != numberRadius;
}
