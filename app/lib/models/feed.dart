import '../theme/app_theme.dart';

/// A single logged feed. Amounts are always stored canonically in ml;
/// oz is a display-only conversion (1 oz = 29.5735 ml).
class Feed {
  final String id;
  final String date; // YYYY-MM-DD
  final String time; // HH:MM, 24h
  final FeedType type;
  final int amountMl;
  final int durationMin;
  final String note;

  const Feed({
    required this.id,
    required this.date,
    required this.time,
    required this.type,
    required this.amountMl,
    required this.durationMin,
    required this.note,
  });

  /// Sort key combining date+time so lexical comparison equals chronological order.
  String get sortKey => '$date$time';

  DateTime get dateTime => DateTime.parse('${date}T$time:00');

  Feed copyWith({
    String? date,
    String? time,
    FeedType? type,
    int? amountMl,
    int? durationMin,
    String? note,
  }) {
    return Feed(
      id: id,
      date: date ?? this.date,
      time: time ?? this.time,
      type: type ?? this.type,
      amountMl: amountMl ?? this.amountMl,
      durationMin: durationMin ?? this.durationMin,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'time': time,
        'type': type.name,
        'amountMl': amountMl,
        'durationMin': durationMin,
        'note': note,
      };

  factory Feed.fromJson(Map<String, dynamic> json) => Feed(
        id: json['id'] as String,
        date: json['date'] as String,
        time: json['time'] as String,
        type: feedTypeFromString(json['type'] as String),
        amountMl: json['amountMl'] as int,
        durationMin: json['durationMin'] as int,
        note: json['note'] as String? ?? '',
      );
}
