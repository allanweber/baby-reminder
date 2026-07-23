import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_icons.dart';

/// FAB: line-drawn baby bottle with a small white circular "+" badge
/// overlapping its bottom-right corner, per the prototype.
class FeedFab extends StatelessWidget {
  final Color accentColor;
  final VoidCallback onTap;
  const FeedFab({super.key, required this.accentColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      height: 66,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
              boxShadow: fabShadow(accentColor),
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: Center(child: AppIcons.bottle(color: Colors.white)),
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.15), blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Center(
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 4.8,
                        left: 0,
                        child: Container(width: 12, height: 2.4, decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(2))),
                      ),
                      Positioned(
                        left: 4.8,
                        top: 0,
                        child: Container(width: 2.4, height: 12, decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(2))),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
