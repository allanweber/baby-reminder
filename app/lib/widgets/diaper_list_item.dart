import 'package:flutter/material.dart';

import '../models/diaper.dart';
import '../theme/app_theme.dart';
import 'app_icons.dart';
import 'feed_list_item.dart' show display12h;

/// A diaper row — visually distinct from feed (white) and reminder (dashed)
/// rows: a solid teal-tinted card with a teal folded-diaper tile, the type
/// label, a time + color/amount detail line, and trailing color-swatch dot
/// badge(s). Used identically on the Diapers tab and in the daily report.
class DiaperListItem extends StatelessWidget {
  final Diaper diaper;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const DiaperListItem({
    super.key,
    required this.diaper,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final detail = diaper.detailStr;
    final noteSuffix = diaper.note.isNotEmpty ? ' · ${diaper.note}' : '';
    final subtitle = '${display12h(diaper.time)}${detail.isNotEmpty ? ' · $detail' : ''}$noteSuffix';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.diaperSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: AppColors.diaperAccent, borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: AppIcons.diaper(size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onEdit,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    diaperTypeLabels[diaper.type]!,
                    style: const TextStyle(fontFamily: nunitoFamily, fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.diaperText),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.diaperSubtext),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SwatchRow(diaper: diaper),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            height: 30,
            child: Material(
              color: AppColors.diaperDeleteBg,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(10),
                child: const Center(
                  child: Text('×', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.diaperDeleteText)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The one or two color-swatch dots trailing a diaper row: the logged pee color
/// and/or poop color, each a small circle with a white ring so it reads clearly
/// on the teal card.
class _SwatchRow extends StatelessWidget {
  final Diaper diaper;
  const _SwatchRow({required this.diaper});

  @override
  Widget build(BuildContext context) {
    final dots = <Widget>[];
    if (diaper.peeColor != null) dots.add(_dot(peeColors[diaper.peeColor]!.hex));
    if (diaper.poopColor != null) dots.add(_dot(poopColors[diaper.poopColor]!.hex));
    if (dots.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < dots.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          dots[i],
        ],
      ],
    );
  }

  Widget _dot(Color color) => Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: AppColors.diaperSwatchRing, spreadRadius: 1, blurRadius: 0)],
        ),
      );
}
