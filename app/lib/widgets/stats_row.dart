import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatsRow extends StatelessWidget {
  final String totalLabel;
  final String totalValue;
  final String feedsLabel;
  final String feedCountValue;
  final String avgGapValue;

  const StatsRow({
    super.key,
    required this.totalLabel,
    required this.totalValue,
    required this.feedsLabel,
    required this.feedCountValue,
    required this.avgGapValue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Expanded(child: _StatCard(value: totalValue, label: totalLabel)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(value: feedCountValue, label: feedsLabel)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(value: avgGapValue, label: 'AVG GAP')),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: cardShadow(),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: balooFamily,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
