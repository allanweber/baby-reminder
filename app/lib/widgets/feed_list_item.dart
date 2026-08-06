import 'package:flutter/material.dart';

import '../models/feed.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

String display12h(String time24) {
  final parts = time24.split(':');
  final h = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final ampm = h >= 12 ? 'PM' : 'AM';
  var h12 = h % 12;
  if (h12 == 0) h12 = 12;
  return '$h12:${pad2(m)} $ampm';
}

class FeedListItem extends StatelessWidget {
  final Feed feed;
  final AppState state;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const FeedListItem({
    super.key,
    required this.feed,
    required this.state,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final meta = AppColors.feedTypes[feed.type]!;
    final displayAmount = feed.type == FeedType.breastfeeding
        ? '${feed.durationMin} min'
        : state.amountLabel(feed.amountMl);
    final noteSuffix = feed.note.isNotEmpty
        ? ' · ${feed.note}'
        : (feed.durationMin > 0 && feed.type != FeedType.breastfeeding ? ' · ${feed.durationMin} min' : '');

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
            crossAxisAlignment: CrossAxisAlignment.center,
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
                          TextSpan(text: displayAmount),
                          TextSpan(
                            text: ' · ${meta.label}',
                            style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${display12h(feed.time)}$noteSuffix',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (feed.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: feed.tags.map((t) => _FeedTagChip(label: t)).toList(),
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
                      child: Text(
                        '×',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.errorText),
                      ),
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

/// A small read-only tag pill shown on a feed row (in the list and the report).
class _FeedTagChip extends StatelessWidget {
  final String label;
  const _FeedTagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.accentBlush;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: softTint(accent), borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8A5A4E)),
      ),
    );
  }
}
