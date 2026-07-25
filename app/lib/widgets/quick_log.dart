import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';
import 'feed_list_item.dart' show display12h;

/// The categories offered for quick logging — every reminder category except
/// Diaper (diapers have their own dedicated tab).
const quickLogCategories = [
  ReminderCategory.medicine,
  ReminderCategory.vitamins,
  ReminderCategory.tummyTime,
  ReminderCategory.exercises,
  ReminderCategory.activities,
  ReminderCategory.bath,
  ReminderCategory.other,
];

/// Logs [category] on the spot and shows the confirmation toast. Shared by the
/// Reminders-tab chip row and the Report quick-log sheet so both behave
/// identically.
Future<void> performQuickLog(BuildContext context, AppState appState, ReminderCategory category) async {
  final log = await appState.quickLog(category);
  if (!context.mounted) return;
  showAppToast(context, '${reminderCategories[category]!.label} logged · ${display12h(log.time)}');
}

/// A wrap of compact, category-tinted pills — one per [quickLogCategories].
/// Tapping a pill invokes [onSelect].
class QuickLogChips extends StatelessWidget {
  final ValueChanged<ReminderCategory> onSelect;
  const QuickLogChips({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: quickLogCategories.map((c) {
        final meta = reminderCategories[c]!;
        return Material(
          color: meta.soft,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: () => onSelect(c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: meta.color, width: 1.5),
              ),
              child: Text(
                meta.label,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: meta.color),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// The Report screen's "Quick log" bottom sheet: the same chips plus a Cancel
/// button. Tapping a chip logs, toasts, and closes the sheet.
Future<void> showQuickLogSheet(BuildContext context, AppState appState) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: AppColors.dragHandle, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Quick log',
                style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Log a category right now, no schedule needed.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            QuickLogChips(
              onSelect: (category) {
                Navigator.of(sheetContext).pop();
                performQuickLog(context, appState, category);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.settingsBg,
                  foregroundColor: AppColors.reminderTitleText,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
