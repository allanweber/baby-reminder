import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../state/app_state.dart' show AppState, pad2;
import '../theme/app_theme.dart';
import 'date_time_pickers.dart';

/// Opens the "Add reminder" / "Edit reminder" bottom sheet. Pass [existing] to
/// edit an existing reminder, or omit it to create a new one.
Future<void> showReminderSheet(BuildContext context, AppState appState, {Reminder? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ReminderSheet(appState: appState, existing: existing),
  );
}

class ReminderSheet extends StatefulWidget {
  final AppState appState;
  final Reminder? existing;
  const ReminderSheet({super.key, required this.appState, this.existing});

  @override
  State<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<ReminderSheet> {
  late final TextEditingController labelController;
  late ReminderCategory category;
  late ReminderMode mode;
  late TimeOfDay fixedTime;
  late int intervalHours;
  String? formError;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      labelController = TextEditingController(text: e.label);
      category = e.category;
      mode = e.mode;
      if (e.fixedTime.isNotEmpty) {
        final t = e.fixedTime.split(':');
        fixedTime = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
      } else {
        fixedTime = const TimeOfDay(hour: 9, minute: 0);
      }
      intervalHours = e.intervalHours > 0 ? e.intervalHours : 4;
    } else {
      labelController = TextEditingController();
      category = ReminderCategory.medicine;
      mode = ReminderMode.fixed;
      fixedTime = const TimeOfDay(hour: 9, minute: 0);
      intervalHours = 4;
    }
  }

  @override
  void dispose() {
    labelController.dispose();
    super.dispose();
  }

  String _timeStr(TimeOfDay t) => '${pad2(t.hour)}:${pad2(t.minute)}';

  Future<void> _pickTime() async {
    final picked = await pickTimeSheet(context, initialTime: fixedTime);
    if (picked != null) {
      setState(() {
        fixedTime = picked;
        formError = null;
      });
    }
  }

  void _save() {
    final label = labelController.text.trim();
    if (label.isEmpty) {
      setState(() => formError = 'Give this reminder a label.');
      return;
    }
    if (mode == ReminderMode.fixed) {
      final hhmm = _timeStr(fixedTime);
      final conflict = widget.appState.fixedTimeConflict(hhmm, excludeId: widget.existing?.id);
      if (conflict != null) {
        final name = conflict.label.isNotEmpty ? conflict.label : reminderCategories[conflict.category]!.label;
        setState(() => formError = 'Another reminder ("$name") is already set for this time. Pick a different time.');
        return;
      }
    }

    if (isEditing) {
      widget.appState.updateReminder(
        widget.existing!.id,
        label: label,
        category: category,
        mode: mode,
        fixedTime: _timeStr(fixedTime),
        intervalHours: intervalHours,
      );
    } else {
      widget.appState.addReminder(
        label: label,
        category: category,
        mode: mode,
        fixedTime: _timeStr(fixedTime),
        intervalHours: intervalHours,
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.accentBlush;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: AppColors.dragHandle, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(
                isEditing ? 'Edit reminder' : 'Add reminder',
                style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              Text('LABEL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: labelController,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {
                  if (formError != null) setState(() => formError = null);
                },
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g. Vitamin D drops',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.cardWhite,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border, width: 1.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border, width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border, width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),
              Text('CATEGORY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ReminderCategory.values.map((c) {
                  final meta = reminderCategories[c]!;
                  final active = category == c;
                  return GestureDetector(
                    onTap: () => setState(() => category = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: active ? meta.color : AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: active ? meta.color : AppColors.border, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active ? Colors.white : meta.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            meta.label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: active ? Colors.white : AppColors.gearStroke,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Text('SCHEDULE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: AppColors.surfaceSecondary, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    _ModeTab(label: 'Daily at a time', active: mode == ReminderMode.fixed, onTap: () => setState(() { mode = ReminderMode.fixed; formError = null; })),
                    _ModeTab(label: 'Every N hours', active: mode == ReminderMode.interval, onTap: () => setState(() { mode = ReminderMode.interval; formError = null; })),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (mode == ReminderMode.fixed)
                _FixedTimeRow(value: fixedTime.format(context), onTap: _pickTime)
              else
                _IntervalRow(
                  hours: intervalHours,
                  onDec: () => setState(() => intervalHours = (intervalHours - 1).clamp(1, 24)),
                  onInc: () => setState(() => intervalHours = (intervalHours + 1).clamp(1, 24)),
                ),
              if (formError != null) ...[
                const SizedBox(height: 12),
                Text(formError!, style: TextStyle(color: AppColors.errorText, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
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
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: Text(isEditing ? 'Save reminder' : 'Add reminder', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModeTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: active ? AppColors.cardWhite : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? AppColors.accentBlush : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FixedTimeRow extends StatelessWidget {
  final String value;
  final VoidCallback onTap;
  const _FixedTimeRow({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('TIME OF DAY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(value, style: TextStyle(fontFamily: balooFamily, fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntervalRow extends StatelessWidget {
  final int hours;
  final VoidCallback onDec;
  final VoidCallback onInc;
  const _IntervalRow({required this.hours, required this.onDec, required this.onInc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('EVERY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          Row(
            children: [
              _StepBtn(label: '–', onTap: onDec),
              SizedBox(
                width: 64,
                child: Text(
                  '${hours}h',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: balooFamily, fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              _StepBtn(label: '+', onTap: onInc),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _StepBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = label == '+' ? AppColors.accentBlush : AppColors.surfaceSecondary;
    final fg = label == '+' ? Colors.white : AppColors.textPrimary;
    return Material(
      color: accent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(child: Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fg))),
        ),
      ),
    );
  }
}
