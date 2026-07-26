import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'reminder_list_item.dart' show reminderTime12h;

/// A reminder row in the daily report — visually distinct from feed rows: a
/// dashed border in the category colour, the category tile, label + category,
/// the time, and a status pill ("Done" / "Missed"). Missed rows render grayed.
class ReminderReportRow extends StatelessWidget {
  final ReminderCategory category;
  final String label;
  final String time; // HH:MM 24h
  final bool done;

  const ReminderReportRow({
    super.key,
    required this.category,
    required this.label,
    required this.time,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final meta = reminderCategories[category]!;
    // Missed rows are grayed down to distinguish them from completed ones.
    final opacity = done ? 1.0 : 0.55;

    return Opacity(
      opacity: opacity,
      child: CustomPaint(
        painter: _DashedRRectPainter(color: meta.color, radius: 20, dash: 5, gap: 4, strokeWidth: 1.6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          TextSpan(text: label.isNotEmpty ? label : meta.label),
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
                      reminderTime12h(time),
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: done ? softTint(meta.color) : AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  done ? 'Done' : 'Missed',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: done ? meta.color : AppColors.textSecondary,
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

/// Paints a rounded-rect border out of dashes. Flutter has no built-in dashed
/// border, so the reminder rows draw their own.
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
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.radius != radius || old.dash != dash || old.gap != gap || old.strokeWidth != strokeWidth;
}
