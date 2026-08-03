import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/weight.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'date_time_pickers.dart';

/// Opens the "Log weight" / "Edit weight" bottom sheet. Pass [existing] to edit
/// an in-place weigh-in, or omit it to log a new one. Same shell as the feed
/// and diaper sheets; uses the sage weight accent.
Future<void> showLogWeightSheet(BuildContext context, AppState appState, {Weight? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => LogWeightSheet(appState: appState, existing: existing),
  );
}

class LogWeightSheet extends StatefulWidget {
  final AppState appState;
  final Weight? existing;
  const LogWeightSheet({super.key, required this.appState, this.existing});

  @override
  State<LogWeightSheet> createState() => _LogWeightSheetState();
}

class _LogWeightSheetState extends State<LogWeightSheet> {
  late DateTime date;
  late double kg; // canonical value; the field displays it in [unit]
  late String unit; // 'kg' | 'lb' — mirrors the app-wide default
  late final TextEditingController valueController;
  String? formError;

  bool get isEditing => widget.existing != null;

  static const _stepKg = 0.05; // ≈0.11 lb — the design's per-tap nudge
  static const _maxKg = 60.0;

  @override
  void initState() {
    super.initState();
    unit = widget.appState.weightUnitPref;
    final e = widget.existing;
    if (e != null) {
      date = DateTime.parse(e.date);
      kg = e.kg;
    } else {
      final now = DateTime.now();
      date = DateTime(now.year, now.month, now.day);
      // Seed a sensible starting value: the latest weigh-in, else a typical
      // infant weight, so the stepper starts somewhere useful.
      kg = widget.appState.latestWeight?.kg ?? 4.0;
    }
    valueController = TextEditingController(text: _displayStr());
  }

  @override
  void dispose() {
    valueController.dispose();
    super.dispose();
  }

  /// The current canonical [kg] rendered in [unit] to exactly 2 decimals.
  String _displayStr() =>
      (unit == 'lb' ? kg * lbPerKg : kg).toStringAsFixed(2);

  void _syncField() {
    valueController.text = _displayStr();
    valueController.selection = TextSelection.collapsed(offset: valueController.text.length);
  }

  /// Reads the field's current text (in [unit]) back into canonical [kg].
  /// Returns false when the text isn't a parseable positive number.
  bool _commitField() {
    final parsed = double.tryParse(valueController.text.trim().replaceAll(',', '.'));
    if (parsed == null) return false;
    kg = unit == 'lb' ? parsed / lbPerKg : parsed;
    return true;
  }

  Future<void> _pickDate() async {
    final picked = await pickDateSheet(context, initialDate: date, firstDate: DateTime(2015), lastDate: DateTime(2100));
    if (picked != null) {
      setState(() {
        date = picked;
        formError = null;
      });
    }
  }

  void _selectUnit(String u) {
    if (u == unit) return;
    _commitField(); // keep the typed value across the conversion
    setState(() {
      unit = u;
      formError = null;
    });
    widget.appState.setWeightUnitPref(u); // persist as the new default
    _syncField();
  }

  void _step(double deltaKg) {
    _commitField();
    setState(() {
      kg = (kg + deltaKg).clamp(0.0, _maxKg);
      formError = null;
    });
    _syncField();
  }

  void _save() {
    if (!_commitField()) {
      setState(() => formError = 'Enter a valid weight.');
      return;
    }
    if (kg <= 0) {
      setState(() => formError = 'Weight must be greater than 0.');
      return;
    }
    final weight = Weight(
      id: widget.existing?.id ?? widget.appState.newWeightId(),
      date: dateStr(date),
      kg: kg,
    );
    widget.appState.saveWeight(weight, isNew: !isEditing);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.weightAccent;
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.4,
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
                isEditing ? 'Edit weight' : 'Log weight',
                style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 14),
              _DateTimeField(label: 'DATE', value: DateFormat('dd/MM/yyyy').format(date), onTap: _pickDate),
              const SizedBox(height: 14),
              // Value card: unit toggle in the header, stepper + editable field.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('WEIGHT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: AppColors.surfaceSecondary, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              _UnitPill(label: 'kg', active: unit == 'kg', accent: accent, onTap: () => _selectUnit('kg')),
                              _UnitPill(label: 'lb', active: unit == 'lb', accent: accent, onTap: () => _selectUnit('lb')),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StepperButton(label: '–', size: 44, bg: AppColors.surfaceSecondary, fg: AppColors.textPrimary, onTap: () => _step(-_stepKg)),
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: valueController,
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                            onChanged: (_) {
                              if (formError != null) setState(() => formError = null);
                            },
                            style: TextStyle(fontFamily: balooFamily, fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        _StepperButton(label: '+', size: 44, bg: accent, fg: Colors.white, onTap: () => _step(_stepKg)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(unit, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                  ],
                ),
              ),
              if (formError != null) ...[
                const SizedBox(height: 10),
                Text(formError!, style: TextStyle(color: AppColors.errorText, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 16),
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
                        child: const Text('Save', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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

class _DateTimeField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateTimeField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 14)),
          ),
        ),
      ],
    );
  }
}

class _UnitPill extends StatelessWidget {
  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;
  const _UnitPill({required this.label, required this.active, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.cardWhite : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: active ? accent : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final String label;
  final double size;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  const _StepperButton({required this.label, required this.size, required this.bg, required this.fg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: fg))),
        ),
      ),
    );
  }
}
