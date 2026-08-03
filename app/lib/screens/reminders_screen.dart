import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../models/reminder.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/appointment_calendar.dart';
import '../widgets/appointment_list_item.dart';
import '../widgets/appointment_sheet.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/quick_log.dart';
import '../widgets/reminder_list_item.dart';
import '../widgets/reminder_sheet.dart';

/// The Reminders tab, split into two sub-tabs: recurring "Reminders" and one-off
/// "Appointments". The active sub-tab is lifted to [AppShell] (via [subTab] /
/// [onSubTabChanged]) so the shell's FAB can switch between "add reminder" and
/// "add appointment".
class RemindersScreen extends StatefulWidget {
  final AppState appState;
  final int subTab; // 0 = Reminders, 1 = Appointments
  final ValueChanged<int> onSubTabChanged;
  const RemindersScreen({
    super.key,
    required this.appState,
    required this.subTab,
    required this.onSubTabChanged,
  });

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  bool _calendarView = false;

  AppState get appState => widget.appState;

  // --- Reminder actions ------------------------------------------------------

  Future<void> _handleDelete(BuildContext context, String id) async {
    final confirmed = await showDeleteConfirmDialog(context, title: 'Delete this reminder?');
    if (confirmed) {
      await appState.deleteReminder(id);
    }
  }

  Future<void> _handleMarkDoneLate(BuildContext context, Reminder r) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Mark as done now?',
      message: 'This will log it as done right now.',
      confirmLabel: 'Mark done',
    );
    if (confirmed) {
      await appState.markReminderDoneLate(r, date: dateStr(DateTime.now()));
    }
  }

  // --- Appointment actions ---------------------------------------------------

  Future<void> _handleDeleteAppointment(BuildContext context, String id) async {
    final confirmed = await showDeleteConfirmDialog(context, title: 'Delete this appointment?');
    if (confirmed) {
      await appState.deleteAppointment(id);
    }
  }

  Future<void> _handlePostpone(BuildContext context, Appointment a) async {
    final now = DateTime.now();
    final initial = a.at.isAfter(now) ? a.at : now.add(const Duration(days: 1));
    final picked = await pickRescheduleDateTime(context, initial: initial);
    if (picked == null) return;
    if (!picked.isAfter(DateTime.now())) return; // ignore a past pick silently
    await appState.postponeAppointment(a, picked);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  appState.babyName.isNotEmpty ? "${appState.babyName}'s reminders" : 'Reminders',
                  style: TextStyle(fontFamily: balooFamily, fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: _SubTabSegment(index: widget.subTab, onChanged: widget.onSubTabChanged),
              ),
              Expanded(
                child: widget.subTab == 0 ? _buildReminders(context) : _buildAppointments(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReminders(BuildContext context) {
    final due = appState.dueReminders;
    final all = [...appState.reminders]..sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text('Medicine, vitamins, tummy time and other care routines.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ),
          if (due.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: due
                    .map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DueReminderCard(
                            reminder: r,
                            onDone: () => appState.markReminderDone(r),
                            onSnooze: () => appState.snoozeReminderItem(r),
                            onDismiss: () => appState.dismissReminderItem(r),
                          ),
                        ))
                    .toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 2),
            child: Text('Quick log',
                style: TextStyle(fontFamily: balooFamily, fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Log a category right now, no schedule needed.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: QuickLogChips(
              onSelect: (category) => performQuickLog(context, appState, category),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text('All reminders',
                style: TextStyle(fontFamily: balooFamily, fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            child: all.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
                    child: Center(
                      child: Text('No reminders yet. Tap the bell to add one.',
                          style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  )
                : Column(
                    children: all
                        .map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ReminderListItem(
                                reminder: r,
                                now: appState.now,
                                missed: appState.isMissedNow(r),
                                onMarkDoneLate: () => _handleMarkDoneLate(context, r),
                                onEdit: () => showReminderSheet(context, appState, existing: r),
                                onDelete: () => _handleDelete(context, r.id),
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointments(BuildContext context) {
    final overdue = appState.overdueAppointments;
    final upcoming = appState.upcomingAppointments;
    // The calendar plots everything still open (overdue + upcoming).
    final open = [...overdue, ...upcoming];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Doctor visits, vaccinations and other one-off events.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                ),
                _ViewToggle(
                  calendar: _calendarView,
                  onChanged: (cal) => setState(() => _calendarView = cal),
                ),
              ],
            ),
          ),
          if (_calendarView)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              child: AppointmentCalendar(
                appointments: open,
                now: appState.now,
                onEdit: (a) => showAppointmentSheet(context, appState, existing: a),
                onDelete: (a) => _handleDeleteAppointment(context, a.id),
                onDone: (a) => appState.markAppointmentDone(a),
                onPostpone: (a) => _handlePostpone(context, a),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              child: (overdue.isEmpty && upcoming.isEmpty)
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
                      child: Center(
                        child: Text('No appointments yet. Tap the + to add one.',
                            style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final a in overdue)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AppointmentOverdueCard(
                              appointment: a,
                              now: appState.now,
                              onDone: () => appState.markAppointmentDone(a),
                              onPostpone: () => _handlePostpone(context, a),
                            ),
                          ),
                        if (upcoming.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 8),
                            child: Text('Upcoming',
                                style: TextStyle(fontFamily: balooFamily, fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          ),
                          for (final a in upcoming)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AppointmentListItem(
                                appointment: a,
                                now: appState.now,
                                onEdit: () => showAppointmentSheet(context, appState, existing: a),
                                onDelete: () => _handleDeleteAppointment(context, a.id),
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

/// The "Reminders | Appointments" segmented control at the top of the tab.
class _SubTabSegment extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _SubTabSegment({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.surfaceSecondary, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          _seg('Reminders', 0),
          _seg('Appointments', 1),
        ],
      ),
    );
  }

  Widget _seg(String label, int value) {
    final active = index == value;
    return Expanded(
      child: Material(
        color: active ? AppColors.accentBlush : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () => onChanged(value),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact List / Calendar toggle for the Appointments sub-tab.
class _ViewToggle extends StatelessWidget {
  final bool calendar;
  final ValueChanged<bool> onChanged;
  const _ViewToggle({required this.calendar, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.surfaceSecondary, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _btn(Icons.view_agenda_rounded, !calendar, () => onChanged(false)),
          _btn(Icons.calendar_month_rounded, calendar, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, bool active, VoidCallback onTap) {
    return Material(
      color: active ? AppColors.cardWhite : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 30,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: active ? AppColors.accentBlush : AppColors.textMuted),
        ),
      ),
    );
  }
}

/// A "due now" card at the top of the Reminders sub-tab: category dot + label, a
/// big "Mark done" button, then a Snooze / Dismiss row.
class _DueReminderCard extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onDone;
  final VoidCallback onSnooze;
  final VoidCallback onDismiss;

  const _DueReminderCard({
    required this.reminder,
    required this.onDone,
    required this.onSnooze,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final meta = reminderCategories[reminder.category]!;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: softTint(meta.color),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: meta.color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${meta.label} due', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: meta.color)),
                    const SizedBox(height: 1),
                    Text(
                      reminder.label.isNotEmpty ? reminder.label : meta.label,
                      style: TextStyle(fontFamily: balooFamily, fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: meta.color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: const Text('Mark done', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextButton(
                    onPressed: onSnooze,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.cardWhite,
                      foregroundColor: AppColors.reminderTitleText,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Snooze 15m', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextButton(
                    onPressed: onDismiss,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.cardWhite,
                      foregroundColor: AppColors.reminderTitleText,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Dismiss', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
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
