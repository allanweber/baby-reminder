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

  // Diapers feature accent — a distinct teal used ONLY for this feature so a
  // diaper entry never reads as a Feed or Reminder.
  static const diaperAccent = Color(0xFF5B94AC);
  static const diaperSoft = Color(0xFFE4F0F4);
  static const diaperText = Color(0xFF2F4C57); // row title on teal-tinted cards
  static const diaperSubtext = Color(0xFF5B7C88); // row detail line
  static const diaperDeleteBg = Color(0xFFD3E5EB); // × button on diaper rows
  static const diaperDeleteText = Color(0xFF3D6577);
  static const diaperSwatchRing = Color(0xFFC7DCE2); // outer ring on swatch dots
  static const diaperStatLabel = Color(0xFFEAF4F8); // label on the teal stat card

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

/// The non-feed care items a reminder can be filed under. Colours + tints come
/// straight from the design handoff's "Reminder category colors" tokens.
enum ReminderCategory { medicine, vitamins, tummyTime, exercises, activities, diaper, bath, other }

class ReminderCategoryColors {
  final String label;
  final Color color; // icon + dashed border + status pill text
  final Color soft; // icon tile / status pill background
  const ReminderCategoryColors({required this.label, required this.color, required this.soft});
}

const reminderCategories = {
  ReminderCategory.medicine: ReminderCategoryColors(label: 'Medicine', color: Color(0xFFC9695C), soft: Color(0xFFF7E3E0)),
  ReminderCategory.vitamins: ReminderCategoryColors(label: 'Vitamins', color: Color(0xFFD9A441), soft: Color(0xFFFBF0DC)),
  ReminderCategory.tummyTime: ReminderCategoryColors(label: 'Tummy time', color: Color(0xFF8FAE7B), soft: Color(0xFFEDF3E6)),
  ReminderCategory.exercises: ReminderCategoryColors(label: 'Exercises', color: Color(0xFF6FA8A0), soft: Color(0xFFE3F1EF)),
  ReminderCategory.activities: ReminderCategoryColors(label: 'Activities', color: Color(0xFFB08FC4), soft: Color(0xFFF0E7F5)),
  ReminderCategory.diaper: ReminderCategoryColors(label: 'Diaper', color: Color(0xFFD98E8E), soft: Color(0xFFF9E9E9)),
  ReminderCategory.bath: ReminderCategoryColors(label: 'Bath', color: Color(0xFF7FB0C4), soft: Color(0xFFE6F1F5)),
  ReminderCategory.other: ReminderCategoryColors(label: 'Other', color: Color(0xFFA79A8F), soft: Color(0xFFEFEAE5)),
};

ReminderCategory reminderCategoryFromString(String s) => ReminderCategory.values.firstWhere(
      (c) => c.name == s,
      orElse: () => ReminderCategory.other,
    );

/// What a diaper change contained. `both` = pee & poop in one change.
enum DiaperType { pee, poop, both }

const diaperTypeLabels = {
  DiaperType.pee: 'Pee',
  DiaperType.poop: 'Poop',
  DiaperType.both: 'Pee & poop',
};

DiaperType diaperTypeFromString(String s) => DiaperType.values.firstWhere(
      (t) => t.name == s,
      orElse: () => DiaperType.pee,
    );

/// A selectable diaper color: its display label and the swatch fill. Enum keys
/// match the persisted JSON strings and the design handoff's color tokens.
class DiaperColorSwatch {
  final String label;
  final Color hex;
  const DiaperColorSwatch({required this.label, required this.hex});
}

/// Pee colors — spanning healthy shades through concerning ones (pink/red flags
/// possible dehydration or blood).
enum PeeColor { clear, pale, yellow, dark, pink }

const peeColors = {
  PeeColor.clear: DiaperColorSwatch(label: 'Clear', hex: Color(0xFFF7F6EC)),
  PeeColor.pale: DiaperColorSwatch(label: 'Pale yellow', hex: Color(0xFFF5E6A3)),
  PeeColor.yellow: DiaperColorSwatch(label: 'Yellow', hex: Color(0xFFE8C547)),
  PeeColor.dark: DiaperColorSwatch(label: 'Dark amber', hex: Color(0xFFC68A2E)),
  PeeColor.pink: DiaperColorSwatch(label: 'Pink/red', hex: Color(0xFFC4585A)),
};

/// Poop colors — again spanning concerning colors (black, red), not only
/// healthy ones.
enum PoopColor { yellow, brown, green, white, black, red }

const poopColors = {
  PoopColor.yellow: DiaperColorSwatch(label: 'Yellow', hex: Color(0xFFD9A441)),
  PoopColor.brown: DiaperColorSwatch(label: 'Brown', hex: Color(0xFF8B5E3C)),
  PoopColor.green: DiaperColorSwatch(label: 'Green', hex: Color(0xFF6B8E4E)),
  PoopColor.white: DiaperColorSwatch(label: 'Pale/white', hex: Color(0xFFE5DEC5)),
  PoopColor.black: DiaperColorSwatch(label: 'Black', hex: Color(0xFF3A3A3A)),
  PoopColor.red: DiaperColorSwatch(label: 'Red', hex: Color(0xFFB23A2E)),
};

const poopAmounts = ['Small', 'Medium', 'Large'];

PeeColor? peeColorFromString(String? s) {
  if (s == null) return null;
  for (final c in PeeColor.values) {
    if (c.name == s) return c;
  }
  return null;
}

PoopColor? poopColorFromString(String? s) {
  if (s == null) return null;
  for (final c in PoopColor.values) {
    if (c.name == s) return c;
  }
  return null;
}

List<BoxShadow> diaperStatShadow() => [
      const BoxShadow(color: Color.fromRGBO(91, 148, 172, 0.25), blurRadius: 14, offset: Offset(0, 3)),
    ];

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
      BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6)),
    ];

List<BoxShadow> fabShadow(Color accent) => [
      BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 8)),
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
