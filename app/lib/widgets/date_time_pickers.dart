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

  void _setHour(int h) => setState(() => _hour24 = h % 24);
  void _setMinute(int m) => setState(() => _minute = m % 60);

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
            'Select time (24h)',
            style: TextStyle(fontFamily: balooFamily, fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TimeFieldChip(
                text: pad2(_hour24),
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
            ],
          ),
          const SizedBox(height: 18),
          _ClockDial(
            hourMode: _field == _TimeField.hour,
            hour24: _hour24,
            minute: _minute,
            onHour: _setHour,
            onMinute: _setMinute,
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

/// 24-hour clock face. In hour mode two rings are shown — 00–11 on the outer
/// ring, 12–23 on the inner ring — so all 24 hours fit without crowding; in
/// minute mode a single ring of 5-minute marks is shown. Tapping or dragging
/// picks the nearest value (and, for hours, the nearer ring).
class _ClockDial extends StatelessWidget {
  final bool hourMode;
  final int hour24; // 0..23
  final int minute; // 0..59
  final ValueChanged<int> onHour;
  final ValueChanged<int> onMinute;
  final VoidCallback onReleased;
  const _ClockDial({
    required this.hourMode,
    required this.hour24,
    required this.minute,
    required this.onHour,
    required this.onMinute,
    required this.onReleased,
  });

  static const double _size = 288;
  static const double _rOuter = 118;
  static const double _rInner = 78;

  void _handle(Offset local) {
    const center = Offset(_size / 2, _size / 2);
    final v = local - center;
    final dist = v.distance;
    if (dist < 4) return;
    // atan2(x, -y): 0 at the top, increasing clockwise.
    var turns = math.atan2(v.dx, -v.dy) / (2 * math.pi);
    if (turns < 0) turns += 1;
    if (hourMode) {
      final idx = (turns * 12).round() % 12; // 0 == top
      final inner = dist < (_rOuter + _rInner) / 2;
      onHour(inner ? idx + 12 : idx);
    } else {
      onMinute((turns * 60).round() % 60);
    }
  }

  Offset _pos(double turns, double r) => Offset(
        _size / 2 + r * math.sin(turns * 2 * math.pi),
        _size / 2 - r * math.cos(turns * 2 * math.pi),
      );

  Widget _number(int value, double turns, double r, bool selected, double fontSize, Color unselected) {
    final p = _pos(turns, r);
    return Positioned(
      left: p.dx - 20,
      top: p.dy - 20,
      width: 40,
      height: 40,
      child: Center(
        child: Text(
          pad2(value),
          style: TextStyle(
            fontFamily: balooFamily,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : unselected,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final numbers = <Widget>[];
    if (hourMode) {
      for (var i = 0; i < 12; i++) {
        final turns = i / 12;
        numbers.add(_number(i, turns, _rOuter, hour24 == i, 16, AppColors.textPrimary));
        numbers.add(_number(i + 12, turns, _rInner, hour24 == i + 12, 13, AppColors.textSecondary));
      }
    } else {
      for (var i = 0; i < 12; i++) {
        final value = i * 5;
        numbers.add(_number(value, i / 12, _rOuter, minute == value, 16, AppColors.textPrimary));
      }
    }

    final handTurns = hourMode ? (hour24 % 12) / 12 : minute / 60;
    final handRadius = hourMode ? (hour24 < 12 ? _rOuter : _rInner) : _rOuter;

    return GestureDetector(
      onTapDown: (d) => _handle(d.localPosition),
      onPanStart: (d) => _handle(d.localPosition),
      onPanUpdate: (d) => _handle(d.localPosition),
      onPanEnd: (_) => onReleased(),
      onTapUp: (_) => onReleased(),
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ClockFacePainter(handTurns: handTurns, handRadius: handRadius),
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
  final double handTurns;
  final double handRadius;
  const _ClockFacePainter({required this.handTurns, required this.handRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width / 2, Paint()..color = AppColors.surfaceSecondary);

    final theta = handTurns * 2 * math.pi;
    final knob = center + Offset(handRadius * math.sin(theta), -handRadius * math.cos(theta));

    final accent = Paint()..color = AppColors.accentBlush;
    canvas.drawLine(
      center,
      knob,
      Paint()
        ..color = AppColors.accentBlush
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(knob, 19, accent);
    canvas.drawCircle(center, 5, accent);
  }

  @override
  bool shouldRepaint(covariant _ClockFacePainter old) =>
      old.handTurns != handTurns || old.handRadius != handRadius;
}
