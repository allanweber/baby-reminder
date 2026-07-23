import 'package:flutter/material.dart';

/// Design tokens lifted from the Claude Design handoff
/// (`Baby Feed Tracker.dc.html` / `design_handoff_baby_feed_tracker/README.md`).
class AppColors {
  static const background = Color(0xFFFFF8F2);
  static const surfaceSecondary = Color(0xFFF3EDE6);
  static const cardWhite = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF4A3B36);
  static const textSecondary = Color(0xFF9C8A82);
  static const textMuted = Color(0xFFB7A79E);
  static const textMuted2 = Color(0xFFC4B6AC);
  static const border = Color(0xFFEFE4DB);
  static const errorText = Color(0xFFB7726A);
  static const errorSolid = Color(0xFFC9695C);
  static const overdue = Color(0xFFD97B67);
  static const gearStroke = Color(0xFF8B7A73);
  static const settingsBg = Color(0xFFEFE4DB);
  static const reminderTitleText = Color(0xFF7A6A62);
  static const dragHandle = Color(0xFFE4D5CB);

  // Tweakable accent (default blush). Alternatives offered as theme options.
  static const accentBlush = Color(0xFFE39C8B);
  static const accentSage = Color(0xFF7FA377);
  static const accentLavender = Color(0xFFA98FC4);
  static const accentSoftPeach = Color(0xFFD9A441);

  static const feedTypes = {
    FeedType.formula: FeedTypeColors(
      label: 'Formula',
      color: Color(0xFFE39C8B),
      soft: Color(0xFFFBEAE5),
    ),
    FeedType.breastBottle: FeedTypeColors(
      label: 'Breast milk',
      color: Color(0xFF7FA377),
      soft: Color(0xFFEAF1E6),
    ),
    FeedType.breastfeeding: FeedTypeColors(
      label: 'Breastfeeding',
      color: Color(0xFFA98FC4),
      soft: Color(0xFFEFE7F5),
    ),
  };
}

class FeedTypeColors {
  final String label;
  final Color color;
  final Color soft;
  const FeedTypeColors({required this.label, required this.color, required this.soft});
}

enum FeedType { formula, breastBottle, breastfeeding }

FeedType feedTypeFromString(String s) => FeedType.values.firstWhere(
      (t) => t.name == s,
      orElse: () => FeedType.formula,
    );

class AppRadius {
  static const chip = 10.0;
  static const input = 14.0;
  static const card = 20.0;
  static const primaryButton = 18.0;
  static const sheet = 28.0;
  static const dialog = 22.0;
}

List<BoxShadow> cardShadow() => [
      const BoxShadow(color: Color.fromRGBO(74, 59, 54, 0.06), blurRadius: 14, offset: Offset(0, 3)),
    ];

List<BoxShadow> smallCardShadow() => [
      const BoxShadow(color: Color.fromRGBO(74, 59, 54, 0.05), blurRadius: 10, offset: Offset(0, 2)),
    ];

List<BoxShadow> primaryCtaShadow(Color accent) => [
      BoxShadow(color: accent.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6)),
    ];

List<BoxShadow> fabShadow(Color accent) => [
      BoxShadow(color: accent.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 8)),
    ];

ThemeData buildAppTheme(Color accent) {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Nunito',
    colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.light),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
      fontFamily: 'Nunito',
    ),
  );
}

const balooFamily = 'Baloo 2';
const nunitoFamily = 'Nunito';
