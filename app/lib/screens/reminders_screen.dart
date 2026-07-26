import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/quick_log.dart';
import '../widgets/reminder_list_item.dart';
import '../widgets/reminder_sheet.dart';

class RemindersScreen extends StatelessWidget {
  final AppState appState;
  const RemindersScreen({super.key, required this.appState});

  Future<void> _handleDelete(BuildContext context, String id) async {
    final confirmed = await showDeleteConfirmDialog(context);
    if (confirmed) {
      await appState.deleteReminder(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final title = appState.babyName.isNotEmpty ? "${appState.babyName}'s reminders" : 'Reminders';
        final due = appState.dueReminders;
        final all = [...appState.reminders]..sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));

        return SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Text(title,
                      style: TextStyle(fontFamily: balooFamily, fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
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
                                      onEdit: () => showReminderSheet(context, appState, existing: r),
                                      onDelete: () => _handleDelete(context, r.id),
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

/// A "due now" card at the top of the Reminders tab: category dot + label, a big
/// "Mark done" button, then a Snooze / Dismiss row — mirroring the feed
/// reminder banner's action layout.
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
