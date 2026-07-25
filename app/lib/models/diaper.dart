import '../theme/app_theme.dart';

/// A single logged diaper change. Logging/reporting only — no schedule or alarm.
/// Colors are stored as enum keys; the pee/poop palettes deliberately span
/// concerning shades (pink/red, black, red) as well as healthy ones so the log
/// is useful for spotting problems, not just "normal" changes.
class Diaper {
  final String id;
  final String date; // YYYY-MM-DD
  final String time; // HH:MM, 24h
  final DiaperType type;
  final PeeColor? peeColor; // set when type includes pee
  final PoopColor? poopColor; // set when type includes poop
  final String? poopAmount; // 'Small' | 'Medium' | 'Large' | null (optional)
  final String note;

  const Diaper({
    required this.id,
    required this.date,
    required this.time,
    required this.type,
    this.peeColor,
    this.poopColor,
    this.poopAmount,
    this.note = '',
  });

  bool get hasPee => type == DiaperType.pee || type == DiaperType.both;
  bool get hasPoop => type == DiaperType.poop || type == DiaperType.both;

  /// Sort key combining date+time so lexical comparison equals chronological order.
  String get sortKey => '$date$time';

  /// The report/list detail line after the time, e.g.
  /// "Pee · Yellow" or "Pee · Pale yellow  ·  Poop · Brown · Medium".
  String get detailStr {
    final parts = <String>[];
    if (peeColor != null) parts.add('Pee · ${peeColors[peeColor]!.label}');
    if (poopColor != null) {
      final amount = poopAmount != null ? ' · $poopAmount' : '';
      parts.add('Poop · ${poopColors[poopColor]!.label}$amount');
    }
    return parts.join('  ·  ');
  }

  Diaper copyWith({
    String? date,
    String? time,
    DiaperType? type,
    PeeColor? peeColor,
    PoopColor? poopColor,
    String? poopAmount,
    String? note,
    bool clearPee = false,
    bool clearPoop = false,
    bool clearAmount = false,
  }) {
    return Diaper(
      id: id,
      date: date ?? this.date,
      time: time ?? this.time,
      type: type ?? this.type,
      peeColor: clearPee ? null : (peeColor ?? this.peeColor),
      poopColor: clearPoop ? null : (poopColor ?? this.poopColor),
      poopAmount: clearAmount ? null : (poopAmount ?? this.poopAmount),
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'time': time,
        'type': type.name,
        'peeColor': peeColor?.name,
        'poopColor': poopColor?.name,
        'poopAmount': poopAmount,
        'note': note,
      };

  factory Diaper.fromJson(Map<String, dynamic> json) => Diaper(
        id: json['id'] as String,
        date: json['date'] as String,
        time: json['time'] as String,
        type: diaperTypeFromString(json['type'] as String),
        peeColor: peeColorFromString(json['peeColor'] as String?),
        poopColor: poopColorFromString(json['poopColor'] as String?),
        poopAmount: json['poopAmount'] as String?,
        note: json['note'] as String? ?? '',
      );
}
