import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/diaper_list_item.dart';
import '../widgets/diaper_stats_row.dart';
import '../widgets/log_diaper_sheet.dart';

/// The Diapers tab: today's diaper stats, a full-width "Log diaper change"
/// button, and today's changes list. Logging/reporting only — no schedule or
/// alarm. Uses the distinct teal accent throughout so it never reads as a Feed
/// or Reminder entry.
class DiapersScreen extends StatelessWidget {
  final AppState appState;
  const DiapersScreen({super.key, required this.appState});

  Future<void> _handleDelete(BuildContext context, String id) async {
    final confirmed = await showDeleteConfirmDialog(context, title: 'Delete this diaper log?');
    if (confirmed) {
      await appState.deleteDiaper(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final title = appState.babyName.isNotEmpty ? "${appState.babyName}'s diapers" : 'Diapers';
        final todayStr = dateStr(appState.now);
        final today = appState.diapersForDate(todayStr).reversed.toList(); // newest first
        final stats = appState.diaperStatsFor(appState.diapersForDate(todayStr));

        return SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Text(title,
                      style: const TextStyle(fontFamily: balooFamily, fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Text('Log pee, poop and color to keep an eye on things.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ),
                DiaperStatsRow(stats: stats, changesLabel: 'CHANGES'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => showLogDiaperSheet(context, appState),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.diaperAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                      ).copyWith(
                        shadowColor: WidgetStateProperty.all(AppColors.diaperAccent.withValues(alpha: 0.35)),
                      ),
                      child: const Text('Log diaper change', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
                  child: Text("Today's changes",
                      style: TextStyle(fontFamily: balooFamily, fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  child: today.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30, horizontal: 10),
                          child: Center(
                            child: Text('No diaper changes logged yet today.',
                                style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        )
                      : Column(
                          children: today
                              .map((d) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: DiaperListItem(
                                      diaper: d,
                                      onEdit: () => showLogDiaperSheet(context, appState, existing: d),
                                      onDelete: () => _handleDelete(context, d.id),
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
