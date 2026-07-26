import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/diaper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'date_time_pickers.dart';

/// Opens the "Log diaper change" / "Edit diaper change" bottom sheet. Pass
/// [existing] to edit an in-place diaper, or omit it to log a new one.
Future<void> showLogDiaperSheet(BuildContext context, AppState appState, {Diaper? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => LogDiaperSheet(appState: appState, existing: existing),
  );
}

class LogDiaperSheet extends StatefulWidget {
  final AppState appState;
  final Diaper? existing;
  const LogDiaperSheet({super.key, required this.appState, this.existing});

  @override
  State<LogDiaperSheet> createState() => _LogDiaperSheetState();
}

class _LogDiaperSheetState extends State<LogDiaperSheet> {
  late DiaperType type;
  late DateTime date;
  late TimeOfDay time;
  PeeColor? peeColor;
  PoopColor? poopColor;
  String? poopAmount;
  late final TextEditingController noteController;
  String? formError;

  bool get isEditing => widget.existing != null;
  bool get showPee => type == DiaperType.pee || type == DiaperType.both;
  bool get showPoop => type == DiaperType.poop || type == DiaperType.both;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      type = e.type;
      date = DateTime.parse(e.date);
      final t = e.time.split(':');
      time = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
      peeColor = e.peeColor;
      poopColor = e.poopColor;
      poopAmount = e.poopAmount;
      noteController = TextEditingController(text: e.note);
    } else {
      final now = DateTime.now();
      type = DiaperType.pee; // default: lightest-weight starting state
      date = DateTime(now.year, now.month, now.day);
      time = TimeOfDay(hour: now.hour, minute: now.minute);
      noteController = TextEditingController();
    }
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  void _selectType(DiaperType t) {
    setState(() {
      type = t;
      // Drop fields that no longer apply, matching the reference behavior.
      if (t == DiaperType.pee) {
        poopColor = null;
        poopAmount = null;
      }
      if (t == DiaperType.poop) {
        peeColor = null;
      }
      formError = null;
    });
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

  Future<void> _pickTime() async {
    final picked = await pickTimeSheet(context, initialTime: time);
    if (picked != null) {
      setState(() {
        time = picked;
        formError = null;
      });
    }
  }

  String _timeStr(TimeOfDay t) => '${pad2(t.hour)}:${pad2(t.minute)}';

  void _save() {
    final needsPee = showPee;
    final needsPoop = showPoop;
    if (needsPee && peeColor == null) {
      setState(() => formError = 'Select a pee color.');
      return;
    }
    if (needsPoop && poopColor == null) {
      setState(() => formError = 'Select a poop color.');
      return;
    }
    final diaper = Diaper(
      id: widget.existing?.id ?? widget.appState.newDiaperId(),
      date: dateStr(date),
      time: _timeStr(time),
      type: type,
      peeColor: needsPee ? peeColor : null,
      poopColor: needsPoop ? poopColor : null,
      poopAmount: needsPoop ? poopAmount : null,
      note: noteController.text,
    );
    widget.appState.saveDiaper(diaper, isNew: !isEditing);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.diaperAccent;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
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
                isEditing ? 'Edit diaper change' : 'Log diaper change',
                style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 14),
              // Type pills
              Row(
                children: DiaperType.values.map((t) {
                  final active = type == t;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: t != DiaperType.both ? 8 : 0),
                      child: SizedBox(
                        height: 42,
                        child: OutlinedButton(
                          onPressed: () => _selectType(t),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: active ? accent : AppColors.cardWhite,
                            foregroundColor: active ? Colors.white : AppColors.gearStroke,
                            side: active ? BorderSide.none : BorderSide(color: AppColors.border, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: Text(diaperTypeLabels[t]!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              // Date / time
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _DateTimeField(label: 'DATE', value: DateFormat('dd/MM/yyyy').format(date), onTap: _pickDate)),
                  const SizedBox(width: 10),
                  Expanded(child: _DateTimeField(label: 'TIME', value: time.format(context), onTap: _pickTime)),
                ],
              ),
              const SizedBox(height: 14),
              if (showPee) ...[
                _ColorCard(
                  label: 'PEE COLOR',
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 12,
                    children: PeeColor.values.map((c) {
                      final meta = peeColors[c]!;
                      return _SwatchButton(
                        color: meta.hex,
                        label: meta.label,
                        selected: peeColor == c,
                        onTap: () => setState(() {
                          peeColor = c;
                          formError = null;
                        }),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (showPoop) ...[
                _ColorCard(
                  label: 'POOP COLOR',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 14,
                        runSpacing: 12,
                        children: PoopColor.values.map((c) {
                          final meta = poopColors[c]!;
                          return _SwatchButton(
                            color: meta.hex,
                            label: meta.label,
                            selected: poopColor == c,
                            onTap: () => setState(() {
                              poopColor = c;
                              formError = null;
                            }),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Text('AMOUNT (OPTIONAL)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var i = 0; i < poopAmounts.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: _AmountPill(
                                label: poopAmounts[i],
                                selected: poopAmount == poopAmounts[i],
                                // Tapping the already-selected pill deselects it.
                                onTap: () => setState(() => poopAmount = poopAmount == poopAmounts[i] ? null : poopAmounts[i]),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text('NOTE (OPTIONAL)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: noteController,
                minLines: 2,
                maxLines: 4,
                style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. slight rash, extra fussy…',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.cardWhite,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.border, width: 1.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.border, width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.border, width: 1.5)),
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
                        child: const Text('Save diaper log', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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

class _ColorCard extends StatelessWidget {
  final String label;
  final Widget child;
  const _ColorCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// A color swatch button: a filled circle with a label beneath. When selected
/// it gains a white-ring halo, a white checkmark overlay, and a bold teal
/// label — so the choice is unambiguous even between similar shades.
class _SwatchButton extends StatelessWidget {
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SwatchButton({required this.color, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(4),
              child: Transform.scale(
                scale: selected ? 1.08 : 1.0,
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: selected
                        ? const [
                            BoxShadow(color: AppColors.diaperAccent, spreadRadius: 5.5, blurRadius: 0),
                            BoxShadow(color: Colors.white, spreadRadius: 3, blurRadius: 0),
                          ]
                        : [
                            BoxShadow(color: AppColors.border, spreadRadius: 1.5, blurRadius: 0),
                          ],
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded, size: 18, color: Colors.white, shadows: [Shadow(color: Color(0x59000000), blurRadius: 1, offset: Offset(0, 1))])
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                color: selected ? AppColors.diaperAccent : AppColors.gearStroke,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AmountPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? AppColors.diaperAccent : AppColors.cardWhite,
          foregroundColor: selected ? Colors.white : AppColors.gearStroke,
          side: selected ? BorderSide.none : BorderSide(color: AppColors.border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      ),
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
