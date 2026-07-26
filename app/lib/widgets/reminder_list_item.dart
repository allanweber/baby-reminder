import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../state/app_state.dart' show pad2;
import '../theme/app_theme.dart';

/// A row in the Reminders tab list: category tile + label + schedule summary,
/// with the time until it next comes due. Tapping opens edit; × deletes.
class ReminderListItem extends StatelessWidget {
  final Reminder reminder;
  final DateTime now;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  /// True when this fixed-time reminder is currently missed for today — draws a
  /// tappable "Missed · tap to mark done" pill under the label.
  final bool missed;
  /// Called when the missed pill is tapped (opens the confirm dialog).
  final VoidCallback? onMarkDoneLate;

  const ReminderListItem({
    super.key,
    required this.reminder,
    required this.now,
    required this.onEdit,
    required this.onDelete,
    this.missed = false,
    this.onMarkDoneLate,
  });

  String _untilLabel() {
    final msLeft = reminder.nextDueAt - now.millisecondsSinceEpoch;
    if (msLeft <= 0) return 'Due now';
    final totalMin = (msLeft / 60000).floor();
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    if (h >= 24) {
      final d = h ~/ 24;
      return 'in ${d}d ${h % 24}h';
    }
    return h > 0 ? 'in ${h}h ${m}m' : 'in ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final meta = reminderCategories[reminder.category]!;
    final overdue = reminder.nextDueAt - now.millisecondsSinceEpoch <= 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(20),
            boxShadow: smallCardShadow(),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: softTint(meta.color), borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: meta.color, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: TextStyle(fontFamily: nunitoFamily, fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        children: [
                          TextSpan(text: reminder.label.isNotEmpty ? reminder.label : meta.label),
                          TextSpan(
                            text: '  ·  ${meta.label}',
                            style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${reminder.scheduleSummary} · ${_untilLabel()}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: overdue ? AppColors.overdue : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (missed) ...[
                      const SizedBox(height: 6),
                      // Only the pill taps through to "mark done late" — the rest
                      // of the row still opens the edit sheet.
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onMarkDoneLate,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: softTint(AppColors.overdue),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Missed · tap to mark done',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.overdue),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                height: 30,
                child: Material(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(10),
                    child: Center(
                      child: Text('×', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.errorText)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String reminderTime12h(String time24) {
  final parts = time24.split(':');
  final h = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final ampm = h >= 12 ? 'PM' : 'AM';
  var h12 = h % 12;
  if (h12 == 0) h12 = 12;
  return '$h12:${pad2(m)} $ampm';
}
