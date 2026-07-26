import 'package:flutter/material.dart';

/// A complete set of theme-dependent neutral tokens. The app ships two:
/// [Palette.light] and [Palette.dark]. Everything that changes between light
/// and dark lives here; the solid accent colors (feed types, reminder
/// categories, diaper teal, pee/poop swatches) do NOT — they stay identical
/// across themes, per the design handoff's Dark Mode section.
class Palette {
  final Color background;
  final Color surfaceSecondary;
  final Color cardWhite; // the "card" surface (white in light, dark card in dark)
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textMuted2;
  final Color border;
  final Color errorText;
  final Color errorSolid;
  final Color overdue;
  final Color gearStroke;
  final Color settingsBg;
  final Color reminderTitleText;
  final Color dragHandle;
  final Color overdueBanner; // reminder banner bg when overdue / due
  final Color tabBarBorder; // hairline above the bottom tab bar
  // Diaper-feature neutral surfaces (the teal-tinted card, its × button, swatch
  // ring). The diaper accent itself (solid teal) stays constant across themes.
  final Color diaperSoft;
  final Color diaperText;
  final Color diaperSubtext;
  final Color diaperDeleteBg;
  final Color diaperDeleteText;
  final Color diaperSwatchRing;
  final Color diaperStatLabel;

  const Palette({
    required this.background,
    required this.surfaceSecondary,
    required this.cardWhite,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textMuted2,
    required this.border,
    required this.errorText,
    required this.errorSolid,
    required this.overdue,
    required this.gearStroke,
    required this.settingsBg,
    required this.reminderTitleText,
    required this.dragHandle,
    required this.overdueBanner,
    required this.tabBarBorder,
    required this.diaperSoft,
    required this.diaperText,
    required this.diaperSubtext,
    required this.diaperDeleteBg,
    required this.diaperDeleteText,
    required this.diaperSwatchRing,
    required this.diaperStatLabel,
  });

  static const light = Palette(
    background: Color(0xFFFFF8F2),
    surfaceSecondary: Color(0xFFF3EDE6),
    cardWhite: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF4A3B36),
    textSecondary: Color(0xFF9C8A82),
    textMuted: Color(0xFFB7A79E),
    textMuted2: Color(0xFFC4B6AC),
    border: Color(0xFFEFE4DB),
    errorText: Color(0xFFB7726A),
    errorSolid: Color(0xFFC9695C),
    overdue: Color(0xFFD97B67),
    gearStroke: Color(0xFF8B7A73),
    settingsBg: Color(0xFFEFE4DB),
    reminderTitleText: Color(0xFF7A6A62),
    dragHandle: Color(0xFFE4D5CB),
    overdueBanner: Color(0xFFF9E2DC),
    tabBarBorder: Color(0xFFF0E6DD),
    diaperSoft: Color(0xFFE4F0F4),
    diaperText: Color(0xFF2F4C57),
    diaperSubtext: Color(0xFF5B7C88),
    diaperDeleteBg: Color(0xFFD3E5EB),
    diaperDeleteText: Color(0xFF3D6577),
    diaperSwatchRing: Color(0xFFC7DCE2),
    diaperStatLabel: Color(0xFFEAF4F8),
  );

  // Dark token set (design handoff → "Dark Mode"). Warm charcoal surfaces,
  // legible warm-gray text; danger tuned; reminder-due bg deepened. The diaper
  // card becomes a teal-tinted dark surface.
  static const dark = Palette(
    background: Color(0xFF221B19),
    surfaceSecondary: Color(0xFF3D332F),
    cardWhite: Color(0xFF352C29),
    textPrimary: Color(0xFFF3EAE4),
    textSecondary: Color(0xFFB8A99F),
    textMuted: Color(0xFF8F8079),
    textMuted2: Color(0xFF8F8079),
    border: Color(0xFF453A35),
    errorText: Color(0xFFE39184),
    errorSolid: Color(0xFFD97A6C),
    overdue: Color(0xFFD97B67),
    gearStroke: Color(0xFFB8A99F),
    settingsBg: Color(0xFF3D332F),
    reminderTitleText: Color(0xFFC9BAB0),
    dragHandle: Color(0xFF4A3E38),
    overdueBanner: Color(0xFF4A342E),
    tabBarBorder: Color(0xFF453A35),
    diaperSoft: Color(0xFF2E3A3D),
    diaperText: Color(0xFFD6E7ED),
    diaperSubtext: Color(0xFF9FBAC4),
    diaperDeleteBg: Color(0xFF3A4A4F),
    diaperDeleteText: Color(0xFFA8C6D0),
    diaperSwatchRing: Color(0xFF45575E),
    diaperStatLabel: Color(0xFFEAF4F8),
  );
}

/// The palette currently in force. Swapped by [applyPalette] (called from the
/// root App build) before the widget tree rebuilds, so every [AppColors] getter
/// below resolves to the active theme's value. The whole tree rebuilds on the
/// same [notifyListeners] that flips this, so there's a single, consistent read
/// per frame.
Palette _activePalette = Palette.light;

/// Points the neutral tokens at the light or dark set. Call before building
/// [MaterialApp] each frame.
void applyPalette({required bool dark}) {
  _activePalette = dark ? Palette.dark : Palette.light;
}

bool get isDarkPalette => identical(_activePalette, Palette.dark);

/// Design tokens lifted from the Claude Design handoff
/// (`Baby Feed Tracker.dc.html` / `design_handoff_baby_feed_tracker/README.md`).
///
/// Neutral tokens resolve through [_activePalette] so they follow the active
/// (light/dark) theme. Solid accent colors are compile-time constants — they're
/// identical in both themes by design.
class AppColors {
  static Color get background => _activePalette.background;
  static Color get surfaceSecondary => _activePalette.surfaceSecondary;
  static Color get cardWhite => _activePalette.cardWhite;
  static Color get textPrimary => _activePalette.textPrimary;
  static Color get textSecondary => _activePalette.textSecondary;
  static Color get textMuted => _activePalette.textMuted;
  static Color get textMuted2 => _activePalette.textMuted2;
  static Color get border => _activePalette.border;
  static Color get errorText => _activePalette.errorText;
  static Color get errorSolid => _activePalette.errorSolid;
  static Color get overdue => _activePalette.overdue;
  static Color get gearStroke => _activePalette.gearStroke;
  static Color get settingsBg => _activePalette.settingsBg;
  static Color get reminderTitleText => _activePalette.reminderTitleText;
  static Color get dragHandle => _activePalette.dragHandle;
  static Color get overdueBanner => _activePalette.overdueBanner;
  static Color get tabBarBorder => _activePalette.tabBarBorder;

  // Tweakable accent (default blush). Alternatives offered as theme options.
  // Accents are identical across light/dark, so they remain compile-time consts.
  static const accentBlush = Color(0xFFE39C8B);
  static const accentSage = Color(0xFF7FA377);
  static const accentLavender = Color(0xFFA98FC4);
  static const accentSoftPeach = Color(0xFFD9A441);

  // Diapers feature accent — a distinct teal used ONLY for this feature so a
  // diaper entry never reads as a Feed or Reminder. The solid teal is constant;
  // the surfaces around it (soft card, × button, swatch ring) follow the theme.
  static const diaperAccent = Color(0xFF5B94AC);
  static Color get diaperSoft => _activePalette.diaperSoft;
  static Color get diaperText => _activePalette.diaperText; // row title on teal-tinted cards
  static Color get diaperSubtext => _activePalette.diaperSubtext; // row detail line
  static Color get diaperDeleteBg => _activePalette.diaperDeleteBg; // × button on diaper rows
  static Color get diaperDeleteText => _activePalette.diaperDeleteText;
  static Color get diaperSwatchRing => _activePalette.diaperSwatchRing; // outer ring on swatch dots
  static Color get diaperStatLabel => _activePalette.diaperStatLabel; // label on the teal stat card

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

/// A category/type "soft" tint: the solid accent [base] blended 24% over the
/// current card surface (`color-mix(in srgb, base 24%, cardBg 76%)`). Computed,
/// not looked up, so any accent stays legible against either theme's card —
/// per the design handoff's Dark Mode section. Optionally blend over a
/// different [surface] (e.g. the page background) when a chip sits off-card.
Color softTint(Color base, {Color? surface}) =>
    Color.alphaBlend(base.withValues(alpha: 0.24), surface ?? AppColors.cardWhite);

ThemeData buildAppTheme(Color accent, {Brightness brightness = Brightness.light}) {
  final palette = brightness == Brightness.dark ? Palette.dark : Palette.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
    fontFamily: 'Nunito',
    colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: brightness).copyWith(
      surface: palette.cardWhite,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
      fontFamily: 'Nunito',
    ),
  );
}

const balooFamily = 'Baloo 2';
const nunitoFamily = 'Nunito';
