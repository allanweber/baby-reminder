import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ReminderBanner extends StatelessWidget {
  final bool showCountdown;
  final bool overdue;
  final String reminderLabel;
  final Color accentColor;
  final VoidCallback onLogNow;
  final VoidCallback onSnooze;
  final VoidCallback onDismiss;

  const ReminderBanner({
    super.key,
    required this.showCountdown,
    required this.overdue,
    required this.reminderLabel,
    required this.accentColor,
    required this.onLogNow,
    required this.onSnooze,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (!showCountdown) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: _LogNowButton(accentColor: accentColor, onTap: onLogNow),
      );
    }

    final bg = overdue ? const Color(0xFFF9E2DC) : AppColors.surfaceSecondary;
    final dotColor = overdue ? AppColors.overdue : accentColor;

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
              _PulsingDot(color: dotColor, pulsing: overdue),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      overdue ? 'Feed overdue' : 'Next feed in',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.reminderTitleText, letterSpacing: 0.2),
                    ),
                    Text(
                      reminderLabel,
                      style: const TextStyle(fontFamily: balooFamily, fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _LogNowButton(accentColor: accentColor, onTap: onLogNow),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextButton(
                    onPressed: onSnooze,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.67),
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Snooze 15m', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextButton(
                    onPressed: onDismiss,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Dismiss', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
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

class _LogNowButton extends StatelessWidget {
  final Color accentColor;
  final VoidCallback onTap;
  const _LogNowButton({required this.accentColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
          shadowColor: Colors.transparent,
        ).copyWith(
          shadowColor: WidgetStateProperty.all(accentColor.withOpacity(0.4)),
        ),
        child: const Text('Log feed now', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool pulsing;
  const _PulsingDot({required this.color, required this.pulsing});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    if (widget.pulsing) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing && !oldWidget.pulsing) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulsing && oldWidget.pulsing) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (!widget.pulsing) return dot;
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.35).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: dot,
    );
  }
}
