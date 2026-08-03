import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/weight.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'app_icons.dart';

/// A weigh-in history row: a white card with a soft-sage dial-gauge tile, the
/// weight value (2 decimals, in the current unit) + its date, and — when a
/// previous entry exists — a small sage delta pill showing the change since it.
/// The whole row opens the edit sheet; the trailing × opens the shared
/// delete-confirm dialog.
class WeightListItem extends StatelessWidget {
  final Weight weight;
  final AppState state;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const WeightListItem({
    super.key,
    required this.weight,
    required this.state,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.weightAccent;
    final deltaKg = state.weightDeltaKg(weight);
    final dateLabel = DateFormat('MMM d, yyyy').format(DateTime.parse(weight.date));

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
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: softTint(accent), borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: AppIcons.gauge(size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.weightLabel(weight.kg),
                      style: TextStyle(fontFamily: nunitoFamily, fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (deltaKg != null) ...[
                _DeltaPill(label: state.weightDeltaLabel(deltaKg)),
                const SizedBox(width: 8),
              ],
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

/// The sage "change since previous entry" pill, e.g. "+0.45 kg". Same computed
/// soft-tint treatment as the report's reminder status pills, so it stays
/// legible on either theme.
class _DeltaPill extends StatelessWidget {
  final String label;
  const _DeltaPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: softTint(AppColors.weightAccent),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.weightAccent),
      ),
    );
  }
}
