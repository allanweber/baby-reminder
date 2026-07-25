import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// The diaper stats row: a solid-teal "Changes" card (white text) followed by
/// white Pee and Poop count cards. The lead card's label differs by context
/// ("CHANGES" on the Diapers tab, "TOTAL CHANGES" in the report).
class DiaperStatsRow extends StatelessWidget {
  final DiaperStats stats;
  final String changesLabel;

  const DiaperStatsRow({super.key, required this.stats, this.changesLabel = 'CHANGES'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          Expanded(child: _tealCard('${stats.total}', changesLabel)),
          const SizedBox(width: 10),
          Expanded(child: _whiteCard('${stats.peeCount}', 'PEE')),
          const SizedBox(width: 10),
          Expanded(child: _whiteCard('${stats.poopCount}', 'POOP')),
        ],
      ),
    );
  }

  Widget _tealCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.diaperAccent,
        borderRadius: BorderRadius.circular(18),
        boxShadow: diaperStatShadow(),
      ),
      child: Column(
        children: [
          Text(value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.diaperStatLabel)),
        ],
      ),
    );
  }

  Widget _whiteCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: cardShadow(),
      ),
      child: Column(
        children: [
          Text(value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
