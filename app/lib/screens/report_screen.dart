import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/date_time_pickers.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/feed_list_item.dart';
import '../widgets/log_feed_sheet.dart';
import '../widgets/stats_row.dart';

class ReportScreen extends StatefulWidget {
  final AppState appState;
  const ReportScreen({super.key, required this.appState});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late DateTime reportDate;

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
    // Falls back to today automatically since `picked` is only ever a valid
    // date or null (cancel) — there is no invalid/empty native-picker state.
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

        final title = appState.babyName.isNotEmpty ? "${appState.babyName}'s daily report" : 'Daily report';
        final dateLabel = isToday ? 'Today' : DateFormat('EEE, MMM d').format(reportDate);

        return SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(title,
                      style: const TextStyle(fontFamily: balooFamily, fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _NavCircleButton(icon: '‹', onTap: _prevDay),
                      InkWell(
                        onTap: _pickDate,
                        child: Text(dateLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 15)),
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
                StatsRow(
                  totalLabel: 'TOTAL INTAKE',
                  totalValue: stats.totalDisplay,
                  feedsLabel: 'FEEDS',
                  feedCountValue: '${stats.feedCount}',
                  avgGapValue: stats.avgIntervalDisplay,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  child: reportFeeds.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30, horizontal: 10),
                          child: Center(
                            child: Text('No feeds logged this day.',
                                style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        )
                      : Column(
                          children: reportFeeds
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

class _NavCircleButton extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  const _NavCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
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
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary))),
        ),
      ),
    );
  }
}
