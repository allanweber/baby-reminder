import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'reminder_list_item.dart' show reminderTime12h;

/// An ad-hoc quick-log row in the daily report. Deliberately distinct from
/// scheduled-reminder rows: a plain solid white card (no dashed border, no
/// Done/Missed pill, since there was no schedule to satisfy). Tapping the body
/// opens the compact edit sheet; the × deletes with confirmation.
class QuickLogReportRow extends StatelessWidget {
  final ReminderCategory category;
  final String label;
  final String time; // HH:MM 24h
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const QuickLogReportRow({
    super.key,
    required this.category,
    required this.label,
    required this.time,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final meta = reminderCategories[category]!;
    // We collapse the label to just the category when they're the same (a quick
    // log stores the category name as its label), avoiding a doubled word.
    final title = label.isNotEmpty && label != meta.label ? '$label  ·  ${meta.label}' : meta.label;

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
                decoration: BoxDecoration(color: meta.soft, borderRadius: BorderRadius.circular(14)),
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
                    Text(
                      title,
                      style: const TextStyle(fontFamily: nunitoFamily, fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reminderTime12h(time),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
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
                    child: const Center(
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
