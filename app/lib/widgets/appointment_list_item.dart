import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/appointment.dart';
import '../theme/app_theme.dart';
import 'reminder_list_item.dart' show reminderTime12h;

String _relativeDay(DateTime at, DateTime now) {
  final d0 = DateTime(now.year, now.month, now.day);
  final d1 = DateTime(at.year, at.month, at.day);
  final diff = d1.difference(d0).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  if (diff > 1 && diff < 7) return DateFormat('EEEE').format(at); // e.g. Friday
  return DateFormat('EEE, d MMM').format(at);
}

/// A category tile (soft square with a coloured dot) — the appointment
/// equivalent of the reminder row's leading tile.
class _CategoryTile extends StatelessWidget {
  final Color color;
  const _CategoryTile({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: softTint(color), borderRadius: BorderRadius.circular(14)),
      alignment: Alignment.center,
      child: Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    );
  }
}

/// A row in the upcoming-appointments list: category tile, title + category,
/// the date/time + how far off it is, and an optional description snippet.
/// Tapping opens edit; × deletes.
class AppointmentListItem extends StatelessWidget {
  final Appointment appointment;
  final DateTime now;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AppointmentListItem({
    super.key,
    required this.appointment,
    required this.now,
    required this.onEdit,
    required this.onDelete,
  });

  String _untilLabel() {
    final msLeft = appointment.atMs - now.millisecondsSinceEpoch;
    if (msLeft <= 0) return 'now';
    final totalMin = (msLeft / 60000).floor();
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    if (h >= 24) {
      final d = h ~/ 24;
      return 'in ${d}d';
    }
    return h > 0 ? 'in ${h}h ${m}m' : 'in ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final meta = appointmentCategories[appointment.category]!;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CategoryTile(color: meta.color),
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
                          TextSpan(text: appointment.displayTitle),
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
                      '${_relativeDay(appointment.at, now)} · ${reminderTime12h(appointment.timeStr)} · ${_untilLabel()}',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (appointment.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        appointment.description,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (appointment.lead != AppointmentLead.none) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: softTint(meta.color), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          'Reminder ${appointment.lead.shortLabel}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: meta.color),
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

/// An overdue appointment surfaced as a card at the top of the Appointments tab:
/// category dot + title, "was due …", then Mark done / Postpone actions. It
/// lingers until the user resolves it.
class AppointmentOverdueCard extends StatelessWidget {
  final Appointment appointment;
  final DateTime now;
  final VoidCallback onDone;
  final VoidCallback onPostpone;

  const AppointmentOverdueCard({
    super.key,
    required this.appointment,
    required this.now,
    required this.onDone,
    required this.onPostpone,
  });

  @override
  Widget build(BuildContext context) {
    final meta = appointmentCategories[appointment.category]!;
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
                    Text('${meta.label} · overdue', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: meta.color)),
                    const SizedBox(height: 1),
                    Text(
                      appointment.displayTitle,
                      style: TextStyle(fontFamily: balooFamily, fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Was due ${_relativeDay(appointment.at, now).toLowerCase()} at ${reminderTime12h(appointment.timeStr)}',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
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
          SizedBox(
            height: 42,
            child: TextButton(
              onPressed: onPostpone,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.cardWhite,
                foregroundColor: AppColors.reminderTitleText,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Postpone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// A Done appointment as it appears in the daily report — a dashed card in the
/// category colour with an "Appointment" tag, placed at its scheduled time.
class AppointmentReportRow extends StatelessWidget {
  final Appointment appointment;
  const AppointmentReportRow({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final meta = appointmentCategories[appointment.category]!;
    return CustomPaint(
      painter: _DashedRRectPainter(color: meta.color, radius: 20, dash: 5, gap: 4, strokeWidth: 1.6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _CategoryTile(color: meta.color),
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
                        TextSpan(text: appointment.displayTitle),
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
                    reminderTime12h(appointment.timeStr),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: softTint(meta.color), borderRadius: BorderRadius.circular(999)),
              child: Text(
                'Appointment',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: meta.color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a rounded-rect border out of dashes (Flutter has no dashed border).
/// Mirrors the reminder report row's dashed treatment so appointments read as
/// the same family of "care event" rows.
class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;
  const _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.dash,
    required this.gap,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.radius != radius || old.dash != dash || old.gap != gap || old.strokeWidth != strokeWidth;
}
