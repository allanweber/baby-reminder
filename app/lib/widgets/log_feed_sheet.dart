import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/feed.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'date_time_pickers.dart';

/// Feed-duration bounds shared by the stepper and the type-to-enter path. The
/// +/- buttons move in [kFeedDurationStepMin]-minute steps so a long feed (e.g.
/// 40 min) is a few taps rather than dozens; any value (typed or stepped) is
/// clamped to a sensible 0..[kMaxFeedDurationMin] range.
const int kMaxFeedDurationMin = 240;
const int kFeedDurationStepMin = 5;
int clampFeedDuration(int minutes) => minutes.clamp(0, kMaxFeedDurationMin);

/// Opens the "Log a feed" / "Edit feed" bottom sheet. Pass [existing] to
/// edit an in-place feed, or omit it to log a new one.
Future<void> showLogFeedSheet(BuildContext context, AppState appState, {Feed? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => LogFeedSheet(appState: appState, existing: existing),
  );
}

class LogFeedSheet extends StatefulWidget {
  final AppState appState;
  final Feed? existing;
  const LogFeedSheet({super.key, required this.appState, this.existing});

  @override
  State<LogFeedSheet> createState() => _LogFeedSheetState();
}

class _LogFeedSheetState extends State<LogFeedSheet> {
  late FeedType type;
  late DateTime date;
  late TimeOfDay time;
  late int amountMl;
  late int durationMin;
  late final TextEditingController noteController;
  late List<String> tags;
  String? formError;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      type = e.type;
      date = DateTime.parse(e.date);
      final t = e.time.split(':');
      time = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
      amountMl = e.amountMl > 0 ? e.amountMl : 120;
      durationMin = e.durationMin;
      noteController = TextEditingController(text: e.note);
      tags = [...e.tags];
    } else {
      final now = DateTime.now();
      final last = widget.appState.feeds.isNotEmpty ? widget.appState.feeds.last : null;
      type = last?.type ?? FeedType.formula;
      date = DateTime(now.year, now.month, now.day);
      time = TimeOfDay(hour: now.hour, minute: now.minute);
      amountMl = last != null && last.amountMl > 0 ? last.amountMl : 120;
      durationMin = last?.durationMin ?? 0;
      noteController = TextEditingController();
      tags = [];
    }
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await pickDateSheet(
      context,
      initialDate: date,
      firstDate: DateTime(2015),
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

  void _incAmount() {
    final step = widget.appState.unitPref == 'oz' ? 15 : 10;
    setState(() {
      amountMl = (amountMl + step).clamp(0, 400);
      formError = null;
    });
  }

  void _decAmount() {
    final step = widget.appState.unitPref == 'oz' ? 15 : 10;
    setState(() {
      amountMl = (amountMl - step).clamp(0, 400);
      formError = null;
    });
  }

  void _incDuration() => setState(() => durationMin = clampFeedDuration(durationMin + kFeedDurationStepMin));
  void _decDuration() => setState(() => durationMin = clampFeedDuration(durationMin - kFeedDurationStepMin));

  /// Opens a small dialog to type the duration in minutes directly — the fast
  /// path for an exact long duration without tapping the stepper repeatedly.
  Future<void> _editDurationDirect() async {
    final controller = TextEditingController(text: durationMin > 0 ? '$durationMin' : '');
    final entered = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Duration (minutes)',
            style: TextStyle(fontFamily: balooFamily, fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: balooFamily, fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: '0',
            suffixText: 'min',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onSubmitted: (v) => Navigator.of(context).pop(int.tryParse(v.trim())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(int.tryParse(controller.text.trim())),
            child: const Text('Set', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (entered != null) {
      setState(() => durationMin = clampFeedDuration(entered));
    }
  }

  String _timeStr(TimeOfDay t) => '${pad2(t.hour)}:${pad2(t.minute)}';

  void _save() {
    final needsAmount = type == FeedType.formula || type == FeedType.breastBottle;
    if (needsAmount && amountMl <= 0) {
      setState(() => formError = 'Enter an amount.');
      return;
    }
    if (type == FeedType.breastfeeding && durationMin <= 0) {
      setState(() => formError = 'Enter how long the feed took.');
      return;
    }

    final feed = Feed(
      id: widget.existing?.id ?? widget.appState.newFeedId(),
      date: dateStr(date),
      time: _timeStr(time),
      type: type,
      amountMl: needsAmount ? amountMl : 0,
      durationMin: durationMin,
      note: noteController.text,
      tags: tags,
    );
    widget.appState.saveFeed(feed, isNew: !isEditing);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.accentBlush;
    final showAmount = type != FeedType.breastfeeding;
    final unitPref = widget.appState.unitPref;
    final amountDisplay = unitPref == 'oz' ? '${(amountMl / mlPerOz).toStringAsFixed(1)} oz' : '$amountMl ml';
    final durationLabel = type == FeedType.breastfeeding ? 'DURATION (MIN)' : 'DURATION (OPTIONAL)';
    final durationHint = type == FeedType.breastfeeding
        ? 'Tap ± for 5 min, or tap the number to type'
        : 'How long the feed took, if you tracked it';

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
                isEditing ? 'Edit feed' : 'Log a feed',
                style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 14),
              Row(
                children: FeedType.values.map((t) {
                  final meta = AppColors.feedTypes[t]!;
                  final active = type == t;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: t != FeedType.breastfeeding ? 8 : 0),
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              type = t;
                              formError = null;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: active ? meta.color : AppColors.cardWhite,
                            foregroundColor: active ? Colors.white : AppColors.gearStroke,
                            side: active ? BorderSide.none : BorderSide(color: AppColors.border, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: Text(meta.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _DateTimeField(label: 'DATE', value: DateFormat('dd/MM/yyyy').format(date), onTap: _pickDate)),
                  const SizedBox(width: 10),
                  Expanded(child: _DateTimeField(label: 'TIME', value: time.format(context), onTap: _pickTime)),
                ],
              ),
              const SizedBox(height: 14),
              if (showAmount) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('AMOUNT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(color: AppColors.surfaceSecondary, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                _UnitPill(label: 'ml', active: unitPref == 'ml', accent: accent, onTap: () => widget.appState.setUnitPref('ml')),
                                _UnitPill(label: 'oz', active: unitPref == 'oz', accent: accent, onTap: () => widget.appState.setUnitPref('oz')),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StepperButton(label: '–', size: 44, bg: AppColors.surfaceSecondary, fg: AppColors.textPrimary, onTap: _decAmount),
                          SizedBox(
                            width: 110,
                            child: Text(
                              amountDisplay,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: balooFamily, fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                          ),
                          _StepperButton(label: '+', size: 44, bg: accent, fg: Colors.white, onTap: _incAmount),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(durationLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                          const SizedBox(height: 1),
                          Text(durationHint, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted2)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        _StepperButton(label: '–', size: 36, bg: AppColors.surfaceSecondary, fg: AppColors.textPrimary, onTap: _decDuration, fontSize: 18),
                        // Tap the value to type an exact duration.
                        InkWell(
                          onTap: _editDurationDirect,
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 56,
                            height: 36,
                            child: Center(
                              child: Text(
                                '$durationMin m',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontFamily: balooFamily, fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                            ),
                          ),
                        ),
                        _StepperButton(label: '+', size: 36, bg: AppColors.surfaceSecondary, fg: AppColors.textPrimary, onTap: _incDuration, fontSize: 18),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('NOTE (OPTIONAL)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: noteController,
                minLines: 2,
                maxLines: 4,
                style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. spit up a little, fussy before feed…',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.cardWhite,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.border, width: 1.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.border, width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.border, width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),
              Text('TAGS (OPTIONAL)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              _TagField(
                selected: tags,
                known: widget.appState.feedTags,
                onChanged: (next) => setState(() => tags = next),
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
                        child: const Text('Save feed', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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

/// Free-form tag entry with reusable suggestions. Selected tags show as
/// removable chips; typing and submitting adds a new one; when the field is
/// focused, the remembered [known] tags (minus those already chosen, filtered by
/// what's typed) appear as tappable chips below it.
class _TagField extends StatefulWidget {
  final List<String> selected;
  final List<String> known;
  final ValueChanged<List<String>> onChanged;
  const _TagField({required this.selected, required this.known, required this.onChanged});

  @override
  State<_TagField> createState() => _TagFieldState();
}

class _TagFieldState extends State<_TagField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool _has(String tag) => widget.selected.any((t) => t.toLowerCase() == tag.toLowerCase());

  void _add(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty || _has(tag)) {
      _controller.clear();
      return;
    }
    widget.onChanged([...widget.selected, tag]);
    _controller.clear();
  }

  void _remove(String tag) => widget.onChanged(widget.selected.where((t) => t != tag).toList());

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim().toLowerCase();
    final suggestions = widget.known
        .where((t) => !_has(t) && (query.isEmpty || t.toLowerCase().contains(query)))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...widget.selected.map((t) => _SelectedTagChip(label: t, onRemove: () => _remove(t))),
              // The text input sits inline with the chips, growing to fill.
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (v) {
                    _add(v);
                    // Keep the field focused so several tags can be added in a row.
                    _focus.requestFocus();
                  },
                  style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    hintText: widget.selected.isEmpty ? 'Add a tag…' : 'Add another…',
                    hintStyle: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Reusable-tag suggestions, revealed while the field is focused.
        if (_focus.hasFocus && suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('TAP TO REUSE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map((t) => _SuggestionChip(label: t, onTap: () {
                      _add(t);
                      _focus.requestFocus();
                    }))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _SelectedTagChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _SelectedTagChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.accentBlush;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(color: softTint(accent), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF8A5A4E))),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 15, color: Color(0xFF8A5A4E)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            ],
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
  final double fontSize;
  const _StepperButton({required this.label, required this.size, required this.bg, required this.fg, required this.onTap, this.fontSize = 22});

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
          child: Center(child: Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: fg))),
        ),
      ),
    );
  }
}
