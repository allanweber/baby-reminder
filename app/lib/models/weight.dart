/// A single logged weight measurement. A lower-frequency data point than
/// feeds/diapers, so it carries only a date (no clock time). The value is
/// stored canonically in kilograms; the kg/lb toggle is a display-only
/// conversion (like the ml/oz feed toggle), so switching units never changes
/// what's persisted.
class Weight {
  final String id;
  final String date; // YYYY-MM-DD
  final double kg; // canonical unit

  const Weight({
    required this.id,
    required this.date,
    required this.kg,
  });

  /// Sort key so lexical comparison equals chronological order. Weights carry
  /// no time, so ties on the same date fall back to the id for a stable order.
  String get sortKey => '$date$id';

  Weight copyWith({String? date, double? kg}) => Weight(
        id: id,
        date: date ?? this.date,
        kg: kg ?? this.kg,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'kg': kg,
      };

  factory Weight.fromJson(Map<String, dynamic> json) => Weight(
        id: json['id'] as String,
        date: json['date'] as String,
        kg: (json['kg'] as num).toDouble(),
      );
}
