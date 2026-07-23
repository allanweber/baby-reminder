import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The on-demand timer's card. It sits in exactly the same spot as the feed
/// [ReminderBanner] and replaces it while a user timer is running.
class CustomTimerBanner extends StatelessWidget {
  final String label;
  final String countdownLabel;
  final bool overdue;
  final VoidCallback onAddFive;
  final VoidCallback onCancel;

  const CustomTimerBanner({
    super.key,
    required this.label,
    required this.countdownLabel,
    required this.overdue,
    required this.onAddFive,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final bg = overdue ? const Color(0xFFF9E2DC) : AppColors.surfaceSecondary;
    const accent = AppColors.accentBlush;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: overdue ? AppColors.overdue : accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.timer_outlined, size: 19, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      overdue ? '$label done' : label,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.reminderTitleText, letterSpacing: 0.2),
                    ),
                    Text(
                      countdownLabel,
                      style: const TextStyle(
                          fontFamily: balooFamily, fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextButton(
                    onPressed: onAddFive,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.67),
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('+5 min', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancel timer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
