import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/appointment.dart';
import '../state/app_state.dart' show AppState, pad2;
import '../theme/app_theme.dart';
import 'date_time_pickers.dart';

/// Opens the "Add appointment" / "Edit appointment" bottom sheet. Pass
/// [existing] to edit, or omit it to create a new one.
Future<void> showAppointmentSheet(BuildContext context, AppState appState, {Appointment? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AppointmentSheet(appState: appState, existing: existing),
  );
}

/// Prompts for a new date then a new time, returning the combined [DateTime]
/// (or null if the user backed out of either step). Shared by the "Postpone"
/// actions on the overdue cards and the alarm overlay.
Future<DateTime?> pickRescheduleDateTime(BuildContext context, {required DateTime initial}) async {
  final date = await pickDateSheet(
    context,
    initialDate: initial,
    firstDate: DateTime(DateTime.now().year - 1),
    lastDate: DateTime(2100),
  );
  if (date == null || !context.mounted) return null;
  final time = await pickTimeSheet(context, initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute));
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

class AppointmentSheet extends StatefulWidget {
  final AppState appState;
  final Appointment? existing;
  const AppointmentSheet({super.key, required this.appState, this.existing});

  @override
  State<AppointmentSheet> createState() => _AppointmentSheetState();
}

class _AppointmentSheetState extends State<AppointmentSheet> {
  late final TextEditingController titleController;
  late final TextEditingController descriptionController;
  late AppointmentCategory category;
  late DateTime date;
  late TimeOfDay time;
  late AppointmentLead lead;
  String? formError;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      titleController = TextEditingController(text: e.title);
      descriptionController = TextEditingController(text: e.description);
      category = e.category;
      date = DateTime(e.at.year, e.at.month, e.at.day);
      time = TimeOfDay(hour: e.at.hour, minute: e.at.minute);
      lead = e.lead;
    } else {
      titleController = TextEditingController();
      descriptionController = TextEditingController();
      category = AppointmentCategory.doctor;
      final soon = DateTime.now().add(const Duration(days: 1));
      date = DateTime(soon.year, soon.month, soon.day);
      time = const TimeOfDay(hour: 10, minute: 0);
      lead = AppointmentLead.oneDay;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  DateTime get _combined => DateTime(date.year, date.month, date.day, time.hour, time.minute);

  Future<void> _pickDate() async {
    final picked = await pickDateSheet(
      context,
      initialDate: date,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        date = picked;
        formError = null;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await pickTimeSheet(context, initialTime: time);
    if (picked != null) {
      setState(() {
        time = picked;
        formError = null;
      });
    }
  }

  void _save() {
    if (!_combined.isAfter(DateTime.now())) {
      setState(() => formError = 'Pick a date and time in the future.');
      return;
    }
    final atMs = _combined.millisecondsSinceEpoch;
    if (isEditing) {
      widget.appState.updateAppointment(
        widget.existing!.id,
        title: titleController.text,
        category: category,
        atMs: atMs,
        lead: lead,
        description: descriptionController.text,
      );
    } else {
      widget.appState.addAppointment(
        title: titleController.text,
        category: category,
        atMs: atMs,
        lead: lead,
        description: descriptionController.text,
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.accentBlush;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.94,
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
                isEditing ? 'Edit appointment' : 'Add appointment',
                style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              Text('TITLE (OPTIONAL)', style: _labelStyle),
              const SizedBox(height: 6),
              _textField(
                controller: titleController,
                hint: 'e.g. 6-month checkup',
                capitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              Text('CATEGORY', style: _labelStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppointmentCategory.values.map((c) {
                  final meta = appointmentCategories[c]!;
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
              Text('WHEN', style: _labelStyle),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _PickerTile(caption: 'DATE', value: DateFormat('EEE, d MMM yyyy').format(_combined), onTap: _pickDate)),
                  const SizedBox(width: 10),
                  _PickerTile(caption: 'TIME', value: '${pad2(time.hour)}:${pad2(time.minute)}', onTap: _pickTime),
                ],
              ),
              const SizedBox(height: 18),
              Text('REMIND ME', style: _labelStyle),
              const SizedBox(height: 8),
              Column(
                children: AppointmentLead.values
                    .map((l) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _LeadOption(
                            label: l.label,
                            selected: lead == l,
                            onTap: () => setState(() => lead = l),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 10),
              Text('DESCRIPTION (OPTIONAL)', style: _labelStyle),
              const SizedBox(height: 6),
              _textField(
                controller: descriptionController,
                hint: 'Anything to remember for this visit',
                capitalization: TextCapitalization.sentences,
                maxLines: 3,
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
                        child: Text(isEditing ? 'Save appointment' : 'Add appointment', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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

  TextStyle get _labelStyle => TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary);

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextCapitalization capitalization = TextCapitalization.none,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: capitalization,
      maxLines: maxLines,
      onChanged: (_) {
        if (formError != null) setState(() => formError = null);
      },
      style: TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.cardWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border, width: 1.5)),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final String caption;
  final String value;
  final VoidCallback onTap;
  const _PickerTile({required this.caption, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(caption, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontFamily: balooFamily, fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LeadOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.accentBlush;
    return Material(
      color: selected ? softTint(accent) : AppColors.cardWhite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? accent : AppColors.border, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? accent : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
