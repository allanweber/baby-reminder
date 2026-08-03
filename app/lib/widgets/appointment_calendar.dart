import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../theme/app_theme.dart';
import 'appointment_list_item.dart';

/// A hand-built month calendar for the Appointments tab (no external calendar
/// dependency). Days that have appointments show a coloured dot; tapping a day
/// lists that day's appointments below the grid. Matches the app's date-picker
/// grid styling.
class AppointmentCalendar extends StatefulWidget {
  final List<Appointment> appointments; // the ones to plot (upcoming + overdue)
  final DateTime now;
  final void Function(Appointment) onEdit;
  final void Function(Appointment) onDelete;
  final void Function(Appointment) onDone;
  final void Function(Appointment) onPostpone;

  const AppointmentCalendar({
    super.key,
    required this.appointments,
    required this.now,
    required this.onEdit,
    required this.onDelete,
    required this.onDone,
    required this.onPostpone,
  });

  @override
  State<AppointmentCalendar> createState() => _AppointmentCalendarState();
}

class _AppointmentCalendarState extends State<AppointmentCalendar> {
  late DateTime _month;
  late DateTime _selectedDay;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    final n = widget.now;
    _selectedDay = DateTime(n.year, n.month, n.day);
    _month = DateTime(n.year, n.month, 1);
  }

  void _changeMonth(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta, 1));

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<Appointment> _appointmentsOn(DateTime day) {
    final list = widget.appointments.where((a) => _sameDay(a.at, day)).toList()
      ..sort((a, b) => a.atMs.compareTo(b.atMs));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7; // 0 = Sunday
    final today = widget.now;
    final selectedList = _appointmentsOn(_selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(20),
            boxShadow: smallCardShadow(),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavArrow(icon: Icons.chevron_left, onTap: () => _changeMonth(-1)),
                  Text(
                    '${_monthNames[_month.month - 1]} ${_month.year}',
                    style: TextStyle(fontFamily: balooFamily, fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  _NavArrow(icon: Icons.chevron_right, onTap: () => _changeMonth(1)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                    .map((d) => Expanded(
                          child: Center(
                            child: Text(d, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 6),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 4,
                crossAxisSpacing: 2,
                childAspectRatio: 1,
                children: [
                  for (var i = 0; i < firstWeekday; i++) const SizedBox.shrink(),
                  for (var day = 1; day <= daysInMonth; day++)
                    _buildDayCell(DateTime(_month.year, _month.month, day), today),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (selectedList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 10),
            child: Center(
              child: Text('No appointments on this day.',
                  style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          )
        else
          Column(
            children: selectedList.map((a) {
              final overdue = a.isOverdue(widget.now);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: overdue
                    ? AppointmentOverdueCard(
                        appointment: a,
                        now: widget.now,
                        onDone: () => widget.onDone(a),
                        onPostpone: () => widget.onPostpone(a),
                      )
                    : AppointmentListItem(
                        appointment: a,
                        now: widget.now,
                        onEdit: () => widget.onEdit(a),
                        onDelete: () => widget.onDelete(a),
                      ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildDayCell(DateTime day, DateTime today) {
    final isSelected = _sameDay(day, _selectedDay);
    final isToday = _sameDay(day, today);
    final appts = _appointmentsOn(day);
    final dotColor = appts.isEmpty
        ? null
        : appointmentCategories[appts.first.category]!.color;
    final fg = isSelected ? Colors.white : AppColors.textPrimary;

    return Center(
      child: Material(
        color: isSelected ? AppColors.accentBlush : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => setState(() => _selectedDay = day),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: isToday && !isSelected
                ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.accentBlush, width: 1.4))
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${day.day}', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: fg)),
                const SizedBox(height: 2),
                SizedBox(
                  height: 5,
                  child: dotColor == null
                      ? null
                      : Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
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
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
