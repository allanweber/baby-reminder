import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reminder.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/date_time_pickers.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/diaper_list_item.dart';
import '../widgets/diaper_stats_row.dart';
import '../widgets/edit_reminder_log_sheet.dart';
import '../widgets/feed_list_item.dart';
import '../widgets/log_diaper_sheet.dart';
import '../widgets/log_feed_sheet.dart';
import '../widgets/quick_log_report_row.dart';
import '../widgets/reminder_report_row.dart';
import '../widgets/stats_row.dart';

enum ReportFilter { all, feed, diapers, reminders }

class ReportScreen extends StatefulWidget {
  final AppState appState;
  const ReportScreen({super.key, required this.appState});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

/// One time-sorted entry in the merged report timeline.
class _TimelineItem {
  final String time; // HH:MM 24h, used for sorting
  final Widget child;
  const _TimelineItem(this.time, this.child);
}

class _ReportScreenState extends State<ReportScreen> {
  late DateTime reportDate;
  ReportFilter filter = ReportFilter.all;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    reportDate = DateTime(now.year, now.month, now.day);
  }

  void _prevDay() => setState(() => reportDate = reportDate.subtract(const Duration(days: 1)));
  void _nextDay() => setState(() => reportDate = reportDate.add(const Duration(days: 1)));
  void _goToday() {
    final now = DateTime.now();
    setState(() => reportDate = DateTime(now.year, now.month, now.day));
  }

  Future<void> _pickDate() async {
    final picked = await pickDateSheet(
      context,
      initialDate: reportDate,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => reportDate = picked);
    }
  }

  Future<void> _handleDelete(BuildContext context, String id) async {
    final confirmed = await showDeleteConfirmDialog(context);
    if (confirmed) {
      await widget.appState.deleteFeed(id);
    }
  }

  Future<void> _handleDeleteDiaper(BuildContext context, String id) async {
    final confirmed = await showDeleteConfirmDialog(context, title: 'Delete this diaper log?');
    if (confirmed) {
      await widget.appState.deleteDiaper(id);
    }
  }

  Future<void> _handleDeleteLog(BuildContext context, String id) async {
    final confirmed = await showDeleteConfirmDialog(context, title: 'Delete this log?');
    if (confirmed) {
      await widget.appState.deleteReminderLog(id);
    }
  }

  Future<void> _handleMarkDoneLate(BuildContext context, Reminder r, String date) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Mark as done now?',
      message: 'This will log it as done right now.',
      confirmLabel: 'Mark done',
    );
    if (confirmed) {
      await widget.appState.markReminderDoneLate(r, date: date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final now = DateTime.now();
        final todayStr = dateStr(now);
        final reportDateStr = dateStr(reportDate);
        final isToday = reportDateStr == todayStr;

        final reportFeeds = appState.feedsForDate(reportDateStr).toList()
          ..sort((a, b) => a.time.compareTo(b.time));
        final stats = appState.computeStats(appState.feedsForDate(reportDateStr));
        final reportDiapers = appState.diapersForDate(reportDateStr);
        final diaperStats = appState.diaperStatsFor(reportDiapers);
        final completed = appState.completedLogsForDate(reportDateStr);
        final quickLogs = appState.quickLogsForDate(reportDateStr);
        final missed = appState.missedRemindersForDate(reportDateStr);

        final showFeeds = filter == ReportFilter.all || filter == ReportFilter.feed;
        final showDiapers = filter == ReportFilter.all || filter == ReportFilter.diapers;
        final showReminders = filter == ReportFilter.all || filter == ReportFilter.reminders;

        // Build the timeline for the current filter, time-sorted.
        final items = <_TimelineItem>[];
        if (showFeeds) {
          for (final f in reportFeeds) {
            items.add(_TimelineItem(
              f.time,
              FeedListItem(
                feed: f,
                state: appState,
                onEdit: () => showLogFeedSheet(context, appState, existing: f),
                onDelete: () => _handleDelete(context, f.id),
              ),
            ));
          }
        }
        if (showDiapers) {
          for (final d in reportDiapers) {
            items.add(_TimelineItem(
              d.time,
              DiaperListItem(
                diaper: d,
                onEdit: () => showLogDiaperSheet(context, appState, existing: d),
                onDelete: () => _handleDeleteDiaper(context, d.id),
              ),
            ));
          }
        }
        if (showReminders) {
          for (final l in completed) {
            items.add(_TimelineItem(
              l.time,
              ReminderReportRow(
                category: l.category,
                label: l.label,
                time: l.time,
                done: true,
                isLate: l.isLate,
                // Late catch-ups are deletable (like quick logs); plain
                // scheduled completions are not.
                onDelete: l.isLate ? () => _handleDeleteLog(context, l.id) : null,
              ),
            ));
          }
          for (final m in missed) {
            items.add(_TimelineItem(
              m.time,
              ReminderReportRow(
                category: m.reminder.category,
                label: m.reminder.label,
                time: m.time,
                done: false,
                onTap: () => _handleMarkDoneLate(context, m.reminder, reportDateStr),
              ),
            ));
          }
          for (final l in quickLogs) {
            items.add(_TimelineItem(
              l.time,
              QuickLogReportRow(
                category: l.category,
                label: l.label,
                time: l.time,
                onEdit: () => showEditReminderLogSheet(context, appState, l),
                onDelete: () => _handleDeleteLog(context, l.id),
              ),
            ));
          }
        }
        items.sort((a, b) => a.time.compareTo(b.time));

        final title = appState.babyName.isNotEmpty ? "${appState.babyName}'s daily report" : 'Daily report';
        final dateLabel = isToday ? 'Today' : DateFormat('EEE, d MMM').format(reportDate);

        return SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(title,
                      style: TextStyle(fontFamily: balooFamily, fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _FilterSegment(
                    filter: filter,
                    onChanged: (f) => setState(() => filter = f),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _NavCircleButton(icon: '‹', onTap: _prevDay),
                      InkWell(
                        onTap: _pickDate,
                        child: Text(dateLabel,
                            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 15)),
                      ),
                      _NavCircleButton(icon: '›', onTap: _nextDay),
                    ],
                  ),
                ),
                if (!isToday)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Center(
                      child: TextButton(
                        onPressed: _goToday,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.settingsBg,
                          foregroundColor: AppColors.reminderTitleText,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Jump to today', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                if (filter == ReportFilter.reminders)
                  _ReminderStatsRow(completed: completed.length, missed: missed.length, logged: quickLogs.length)
                else if (filter == ReportFilter.diapers)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: DiaperStatsRow(stats: diaperStats, changesLabel: 'TOTAL CHANGES'),
                  )
                else
                  StatsRow(
                    totalLabel: 'TOTAL INTAKE',
                    totalValue: stats.totalDisplay,
                    feedsLabel: 'FEEDS',
                    feedCountValue: '${stats.feedCount}',
                    avgGapValue: stats.avgIntervalDisplay,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  child: items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
                          child: Center(
                            child: Text('Nothing logged this day.',
                                style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        )
                      : Column(
                          children: items
                              .map((it) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: it.child,
                                  ))
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FilterSegment extends StatelessWidget {
  final ReportFilter filter;
  final ValueChanged<ReportFilter> onChanged;
  const _FilterSegment({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.surfaceSecondary, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          _seg('All', ReportFilter.all),
          _seg('Feed', ReportFilter.feed),
          _seg('Diapers', ReportFilter.diapers),
          _seg('Reminders', ReportFilter.reminders),
        ],
      ),
    );
  }

  Widget _seg(String label, ReportFilter value) {
    final active = filter == value;
    // The Diapers segment fills with the teal diaper accent, not the app accent.
    final activeColor = value == ReportFilter.diapers ? AppColors.diaperAccent : AppColors.accentBlush;
    return Expanded(
      child: Material(
        color: active ? activeColor : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () => onChanged(value),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
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

class _ReminderStatsRow extends StatelessWidget {
  final int completed;
  final int missed;
  final int logged;
  const _ReminderStatsRow({required this.completed, required this.missed, required this.logged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Expanded(child: _card('$completed', 'COMPLETED')),
          const SizedBox(width: 10),
          Expanded(child: _card('$missed', 'MISSED')),
          const SizedBox(width: 10),
          Expanded(child: _card('$logged', 'LOGGED')),
        ],
      ),
    );
  }

  Widget _card(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: cardShadow(),
      ),
      child: Column(
        children: [
          Text(value,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _NavCircleButton extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  const _NavCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardWhite,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color.fromRGBO(74, 59, 54, 0.08), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Center(child: Text(icon, style: TextStyle(fontSize: 16, color: AppColors.textPrimary))),
        ),
      ),
    );
  }
}
