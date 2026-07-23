import 'package:flutter/material.dart';

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

/// Custom replacement for [showTimePicker]: tap an hour, then tap a minute —
/// selecting the minute immediately confirms and closes the sheet. Values
/// are laid out in a well-spaced grid instead of a cramped 24-value dial.
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

class _TimePickerSheet extends StatefulWidget {
  final TimeOfDay initialTime;
  const _TimePickerSheet({required this.initialTime});

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late int _step; // 0 = pick hour, 1 = pick minute
  late int _hour;

  @override
  void initState() {
    super.initState();
    _step = 0;
    _hour = widget.initialTime.hour;
  }

  void _pickHour(int hour) => setState(() {
        _hour = hour;
        _step = 1;
      });

  void _pickMinute(int minute) => Navigator.of(context).pop(TimeOfDay(hour: _hour, minute: minute));

  @override
  Widget build(BuildContext context) {
    return _SheetChrome(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_step == 1)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _NavArrow(icon: Icons.chevron_left, onTap: () => setState(() => _step = 0)),
                ),
              Text(
                _step == 0 ? 'Select hour' : 'Select minute for ${_hour.toString().padLeft(2, '0')}h',
                style: const TextStyle(fontFamily: balooFamily, fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_step == 0)
            _NumberGrid(count: 24, crossAxisCount: 6, selected: _hour, onTap: _pickHour)
          else
            SizedBox(
              height: 260,
              child: _NumberGrid(count: 60, crossAxisCount: 6, selected: null, onTap: _pickMinute, scrollable: true),
            ),
        ],
      ),
    );
  }
}

class _NumberGrid extends StatelessWidget {
  final int count;
  final int crossAxisCount;
  final int? selected;
  final ValueChanged<int> onTap;
  final bool scrollable;
  const _NumberGrid({
    required this.count,
    required this.crossAxisCount,
    required this.selected,
    required this.onTap,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: scrollable ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: count,
      itemBuilder: (context, i) {
        final active = selected == i;
        return Material(
          color: active ? AppColors.accentBlush : AppColors.surfaceSecondary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onTap(i),
            child: Center(
              child: Text(
                i.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
