import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reminder.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'date_time_pickers.dart';

/// Opens the compact "Edit log" sheet for a quick log — date and time only
/// (a quick log has no schedule, note or amount to edit).
Future<void> showEditReminderLogSheet(BuildContext context, AppState appState, ReminderLog log) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _EditReminderLogSheet(appState: appState, log: log),
  );
}

class _EditReminderLogSheet extends StatefulWidget {
  final AppState appState;
  final ReminderLog log;
  const _EditReminderLogSheet({required this.appState, required this.log});

  @override
  State<_EditReminderLogSheet> createState() => _EditReminderLogSheetState();
}

class _EditReminderLogSheetState extends State<_EditReminderLogSheet> {
  late DateTime date;
  late TimeOfDay time;

  @override
  void initState() {
    super.initState();
    date = DateTime.parse(widget.log.date);
    final t = widget.log.time.split(':');
    time = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
  }

  Future<void> _pickDate() async {
    final picked = await pickDateSheet(context, initialDate: date, firstDate: DateTime(2015), lastDate: DateTime(2100));
    if (picked != null) setState(() => date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await pickTimeSheet(context, initialTime: time);
    if (picked != null) setState(() => time = picked);
  }

  void _save() {
    widget.appState.updateReminderLog(
      widget.log.id,
      date: dateStr(date),
      time: '${pad2(time.hour)}:${pad2(time.minute)}',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final meta = reminderCategories[widget.log.category]!;
    return Container(
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
            const Text('Edit log',
                style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(meta.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Field(label: 'DATE', value: DateFormat('dd/MM/yyyy').format(date), onTap: _pickDate)),
                const SizedBox(width: 10),
                Expanded(child: _Field(label: 'TIME', value: time.format(context), onTap: _pickTime)),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.settingsBg,
                        foregroundColor: AppColors.reminderTitleText,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentBlush,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Text('Save', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _Field({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 14)),
          ),
        ),
      ],
    );
  }
}
