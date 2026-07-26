import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shows a brief bottom-anchored dark toast (the quick-log confirmation), then
/// auto-dismisses after ~1.5s. Bespoke overlay rather than a SnackBar so it
/// matches the app's look and sits above the bottom nav on any tab.
void showAppToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  final entry = OverlayEntry(
    builder: (context) => _ToastWidget(message: message),
  );
  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 1650), () {
    if (entry.mounted) entry.remove();
  });
}

class _ToastWidget extends StatefulWidget {
  final String message;
  const _ToastWidget({required this.message});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 180))..forward();
    // Fade back out shortly before removal so it doesn't just vanish.
    Future.delayed(const Duration(milliseconds: 1450), () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 20,
      right: 20,
      bottom: 96 + bottomInset,
      child: FadeTransition(
        opacity: _controller,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              // Fixed warm-dark toast in both themes (white text on top): the
              // light theme's primary ink, which reads as a raised surface on
              // the dark background too — so it never inverts to light-on-light.
              color: const Color(0xFF4A3B36),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, 8))],
            ),
            child: Text(
              widget.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
