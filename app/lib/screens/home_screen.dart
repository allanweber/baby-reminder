import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/custom_timer_banner.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/feed_list_item.dart';
import '../widgets/log_feed_sheet.dart';
import '../widgets/reminder_banner.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/stats_row.dart';
import '../widgets/timer_sheet.dart';

class HomeScreen extends StatelessWidget {
  final AppState appState;
  const HomeScreen({super.key, required this.appState});

  String _timePhrase(int hour) {
    if (hour < 12) return 'Off to a gentle start this morning';
    if (hour < 18) return 'Cruising through the afternoon';
    return 'Winding down for the evening';
  }

  Future<void> _handleDelete(BuildContext context, String id) async {
    final confirmed = await showDeleteConfirmDialog(context);
    if (confirmed) {
      await appState.deleteFeed(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final now = appState.now;
        final todayStr = dateStr(now);
        final greeting = appState.babyName.isNotEmpty ? "${appState.babyName}'s feeds" : "Today's feeds";
        final longDate = DateFormat('EEEE, d MMMM').format(now);
        final timePhrase = _timePhrase(now.hour);

        final homeFeeds = appState.feedsForDate(todayStr).toList()
          ..sort((a, b) => b.time.compareTo(a.time));
        final stats = appState.computeStats(appState.feedsForDate(todayStr));

        String fmtCountdown(int msLeft) {
          final totalSec = (msLeft / 1000).floor();
          final h = totalSec ~/ 3600;
          final m = (totalSec % 3600) ~/ 60;
          final s = totalSec % 60;
          return h > 0 ? '${h}h ${pad2(m)}m ${pad2(s)}s' : '${m}m ${pad2(s)}s';
        }

        // A running custom timer takes over the countdown; otherwise it tracks
        // the feed reminder.
        final customActive = appState.customTimerActive;
        final msLeft = appState.effectiveReminderAt - now.millisecondsSinceEpoch;
        final overdue = msLeft <= 0;
        final reminderLabel = overdue ? 'Due now' : fmtCountdown(msLeft);

        return SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(greeting,
                                style: const TextStyle(
                                    fontFamily: balooFamily, fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(longDate,
                                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(timePhrase,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      Material(
                        color: AppColors.settingsBg,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => showTimerSheet(context, appState),
                          child: Tooltip(
                            message: 'Set a timer',
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: const Center(
                                child: Icon(Icons.timer_outlined, size: 22, color: AppColors.gearStroke),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: AppColors.settingsBg,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => showSettingsSheet(context, appState),
                          child: Tooltip(
                            message: 'Settings',
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Center(child: AppIcons.gear(color: AppColors.gearStroke)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (customActive)
                  CustomTimerBanner(
                    label: appState.customTimerLabel,
                    countdownLabel: overdue ? "Time's up" : fmtCountdown(msLeft),
                    overdue: overdue,
                    onAddFive: () => appState.extendCustomTimer(const Duration(minutes: 5)),
                    onCancel: () => appState.cancelCustomTimer(),
                  )
                else
                  ReminderBanner(
                    showCountdown: !appState.reminderDismissed,
                    overdue: overdue,
                    reminderLabel: reminderLabel,
                    accentColor: AppColors.accentBlush,
                    onLogNow: () => showLogFeedSheet(context, appState),
                    onSnooze: () => appState.snoozeReminder(),
                    onDismiss: () => appState.dismissReminder(),
                  ),
                StatsRow(
                  totalLabel: "TODAY'S INTAKE",
                  totalValue: stats.totalDisplay,
                  feedsLabel: 'FEEDS TODAY',
                  feedCountValue: '${stats.feedCount}',
                  avgGapValue: stats.avgIntervalDisplay,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
                  child: Text("Today's feeds",
                      style: TextStyle(fontFamily: balooFamily, fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  child: homeFeeds.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30, horizontal: 10),
                          child: Center(
                            child: Text('No feeds logged yet today.',
                                style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        )
                      : Column(
                          children: homeFeeds
                              .map((f) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: FeedListItem(
                                      feed: f,
                                      state: appState,
                                      onEdit: () => showLogFeedSheet(context, appState, existing: f),
                                      onDelete: () => _handleDelete(context, f.id),
                                    ),
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
