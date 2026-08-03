import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../models/reminder.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/appointment_sheet.dart';
import '../widgets/feed_fab.dart';
import '../widgets/log_diaper_sheet.dart';
import '../widgets/log_feed_sheet.dart';
import '../widgets/quick_log.dart';
import '../widgets/reminder_sheet.dart';
import 'diapers_screen.dart';
import 'home_screen.dart';
import 'reminders_screen.dart';
import 'report_screen.dart';

/// Persistent shell: bottom tab bar + FAB stay put while Reminders / Feed /
/// Diapers / Report swap underneath. "Feed" is the primary (emphasized) tab and
/// is shown first; the FAB is context-aware (bottle on Feed, bell on Reminders,
/// folded diaper on Diapers, hidden on Report). The Diapers tab uses its own
/// teal accent so it never reads as a Feed or Reminder.
class AppShell extends StatefulWidget {
  final AppState appState;
  const AppShell({super.key, required this.appState});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // 0 = Reminders, 1 = Feed (primary, default), 2 = Diapers, 3 = Report.
  int _tabIndex = 1;
  // Which sub-tab the Reminders tab is showing: 0 = Reminders, 1 = Appointments.
  // Lifted here so the FAB can switch between "add reminder" and "add appointment".
  int _remindersSubTab = 0;

  @override
  Widget build(BuildContext context) {
    // Rebuild on every state change so the alarm overlay appears/disappears the
    // moment an alarm starts or is dismissed.
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final ringingAppointment = widget.appState.ringingAppointment;
        final ringingReminder = widget.appState.ringingReminder;
        return Stack(
          children: [
            _buildShell(context),
            if (ringingAppointment != null)
              _AppointmentAlarmOverlay(
                appState: widget.appState,
                appointment: ringingAppointment,
                isLead: widget.appState.ringingAppointmentIsLead,
              )
            else if (ringingReminder != null)
              _ReminderAlarmOverlay(appState: widget.appState, reminder: ringingReminder)
            else if (widget.appState.alarmRinging)
              _AlarmOverlay(
                appState: widget.appState,
                onLog: () => showLogFeedSheet(context, widget.appState),
              ),
          ],
        );
      },
    );
  }

  Widget? _buildFab(BuildContext context) {
    const accent = AppColors.accentBlush;
    if (_tabIndex == 0) {
      // On the Appointments sub-tab the FAB adds an appointment (calendar);
      // on the Reminders sub-tab it adds a reminder (bell).
      if (_remindersSubTab == 1) {
        return FeedFab(
          accentColor: accent,
          icon: AppIcons.calendar(size: 24, color: Colors.white),
          onTap: () => showAppointmentSheet(context, widget.appState),
        );
      }
      return FeedFab(
        accentColor: accent,
        icon: AppIcons.bell(color: Colors.white),
        onTap: () => showReminderSheet(context, widget.appState),
      );
    }
    if (_tabIndex == 1) {
      return FeedFab(
        accentColor: accent,
        onTap: () => showLogFeedSheet(context, widget.appState),
      );
    }
    if (_tabIndex == 2) {
      return FeedFab(
        accentColor: AppColors.diaperAccent,
        icon: AppIcons.diaper(size: 24, color: Colors.white, strokeWidth: 1.9),
        onTap: () => showLogDiaperSheet(context, widget.appState),
      );
    }
    // Report: a quick-log FAB (Report previously had none).
    return FeedFab(
      accentColor: accent,
      icon: AppIcons.plus(color: Colors.white),
      onTap: () => showQuickLogSheet(context, widget.appState),
    );
  }

  Widget _buildShell(BuildContext context) {
    const accent = AppColors.accentBlush;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _tabIndex,
        children: [
          RemindersScreen(
            appState: widget.appState,
            subTab: _remindersSubTab,
            onSubTabChanged: (i) => setState(() => _remindersSubTab = i),
          ),
          HomeScreen(appState: widget.appState),
          DiapersScreen(appState: widget.appState),
          ReportScreen(appState: widget.appState),
        ],
      ),
      floatingActionButton: _buildFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          border: Border(top: BorderSide(color: AppColors.tabBarBorder, width: 1)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: _TabButton(
                  icon: AppIcons.bell(size: 20, color: _tabIndex == 0 ? accent : AppColors.textMuted),
                  label: 'Reminders',
                  active: _tabIndex == 0,
                  accent: accent,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
              ),
              Expanded(
                child: _TabButton(
                  icon: AppIcons.house(size: 25, color: _tabIndex == 1 ? accent : AppColors.textMuted),
                  label: 'Feed',
                  active: _tabIndex == 1,
                  accent: accent,
                  primary: true,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
              ),
              Expanded(
                child: _TabButton(
                  icon: AppIcons.diaper(size: 20, color: _tabIndex == 2 ? AppColors.diaperAccent : AppColors.textMuted),
                  label: 'Diapers',
                  active: _tabIndex == 2,
                  accent: AppColors.diaperAccent,
                  onTap: () => setState(() => _tabIndex = 2),
                ),
              ),
              Expanded(
                child: _TabButton(
                  icon: AppIcons.calendar(size: 20, color: _tabIndex == 3 ? accent : AppColors.textMuted),
                  label: 'Report',
                  active: _tabIndex == 3,
                  accent: accent,
                  onTap: () => setState(() => _tabIndex = 3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen "alarm playing" state shown over the whole app while the feed
/// reminder (or a custom timer) is ringing, with an immediate way to stop it.
class _AlarmOverlay extends StatelessWidget {
  final AppState appState;
  final VoidCallback onLog;
  const _AlarmOverlay({required this.appState, required this.onLog});

  @override
  Widget build(BuildContext context) {
    final isTimer = appState.alarmIsCustomTimer;
    final name = appState.babyName;
    final title = isTimer
        ? '${appState.customTimerLabel} done'
        : (name.isNotEmpty ? '$name is due for a feed' : 'Time for a feed');
    final subtitle = isTimer ? 'Your timer is up' : 'Your feed alarm is playing';
    return Positioned.fill(
      child: Material(
        color: AppColors.overdue,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              children: [
                const Spacer(),
                const Icon(Icons.notifications_active_rounded, size: 96, color: Colors.white),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: balooFamily, fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: () => appState.dismissReminder(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.overdue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Text(isTimer ? 'Stop timer' : 'Dismiss alarm',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => appState.snoozeReminder(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(isTimer ? '+15 min' : 'Snooze 15m',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: onLog,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Log feed', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen alarm for a due care reminder (medicine, vitamins…). Same OS
/// alarm treatment as feeds, but its actions log a completion / snooze / skip.
class _ReminderAlarmOverlay extends StatelessWidget {
  final AppState appState;
  final Reminder reminder;
  const _ReminderAlarmOverlay({required this.appState, required this.reminder});

  @override
  Widget build(BuildContext context) {
    final meta = reminderCategories[reminder.category]!;
    final title = reminder.label.isNotEmpty ? reminder.label : meta.label;
    return Positioned.fill(
      child: Material(
        color: meta.color,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              children: [
                const Spacer(),
                const Icon(Icons.notifications_active_rounded, size: 96, color: Colors.white),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: balooFamily, fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  '${meta.label} reminder',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: () => appState.markReminderDone(reminder),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: meta.color,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Text('Mark done', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => appState.snoozeReminderItem(reminder),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Snooze 15m', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => appState.dismissReminderItem(reminder),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Dismiss', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen alarm for an appointment. The at-time alarm offers Mark done /
/// Postpone / Dismiss; the earlier lead (1h/1d) alarm is a heads-up, so it only
/// offers Dismiss + Postpone (you can't be "done" before it happens).
class _AppointmentAlarmOverlay extends StatelessWidget {
  final AppState appState;
  final Appointment appointment;
  final bool isLead;
  const _AppointmentAlarmOverlay({required this.appState, required this.appointment, required this.isLead});

  Future<void> _postpone(BuildContext context) async {
    // Silence the ringing alarm first, then let the user pick a new time.
    await appState.dismissAppointmentAlarm(appointment);
    if (!context.mounted) return;
    final now = DateTime.now();
    final initial = appointment.at.isAfter(now) ? appointment.at : now.add(const Duration(days: 1));
    final picked = await pickRescheduleDateTime(context, initial: initial);
    if (picked == null || !picked.isAfter(DateTime.now())) return;
    await appState.postponeAppointment(appointment, picked);
  }

  @override
  Widget build(BuildContext context) {
    final meta = appointmentCategories[appointment.category]!;
    final subtitle = isLead
        ? '${meta.label} appointment ${appointment.lead.shortLabel}'
        : '${meta.label} appointment';
    return Positioned.fill(
      child: Material(
        color: meta.color,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              children: [
                const Spacer(),
                const Icon(Icons.event_available_rounded, size: 96, color: Colors.white),
                const SizedBox(height: 24),
                Text(
                  appointment.displayTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: balooFamily, fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
                const Spacer(),
                if (!isLead) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () => appState.markAppointmentDone(appointment),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: meta.color,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Text('Mark done', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _outlined('Postpone', () => _postpone(context))),
                      const SizedBox(width: 12),
                      Expanded(child: _outlined('Dismiss', () => appState.dismissAppointmentAlarm(appointment))),
                    ],
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () => appState.dismissAppointmentAlarm(appointment),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: meta.color,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Text('Dismiss', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: _outlined('Postpone', () => _postpone(context)),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _outlined(String label, VoidCallback onTap) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white70, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool active;
  final Color accent;
  final bool primary;
  final VoidCallback onTap;
  const _TabButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? accent : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: primary ? 13 : 12,
                fontWeight: primary ? FontWeight.w800 : FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
