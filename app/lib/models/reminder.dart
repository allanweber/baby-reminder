import '../theme/app_theme.dart';

/// How a reminder recurs.
/// - [fixed]: due every day at a set clock time ([fixedTime]).
/// - [interval]: due every [intervalHours] hours, drifting from the last time
///   it was completed (same pattern as the feed reminder).
enum ReminderMode { fixed, interval }

ReminderMode reminderModeFromString(String s) =>
    ReminderMode.values.firstWhere((m) => m.name == s, orElse: () => ReminderMode.fixed);

String _pad2(int n) => n < 10 ? '0$n' : '$n';

/// A recurring alarm for a non-feed care item (medicine, vitamins, tummy time…).
/// Each reminder owns a stable [alarmId] so the native `alarm` engine can arm,
/// re-arm and cancel its full-screen alarm independently of the others.
class Reminder {
  final String id;
  final int alarmId;
  final String label;
  final ReminderCategory category;
  final ReminderMode mode;
  final String fixedTime; // HH:MM, 24h — used by fixed mode ('' otherwise)
  final int intervalHours; // used by interval mode (0 otherwise)
  final int nextDueAt; // ms since epoch: when the alarm is currently armed for
  final int createdAt; // ms since epoch: bounds "missed" history in the report

  const Reminder({
    required this.id,
    required this.alarmId,
    required this.label,
    required this.category,
    required this.mode,
    required this.fixedTime,
    required this.intervalHours,
    required this.nextDueAt,
    required this.createdAt,
  });

  bool get isFixed => mode == ReminderMode.fixed;

  /// Human-readable recurrence, e.g. "Daily at 9:00 AM" or "Every 8h".
  String get scheduleSummary {
    if (isFixed) return 'Daily at ${_display12h(fixedTime)}';
    return 'Every ${intervalHours}h';
  }

  /// The next occurrence of [hhmm] at or after [from] (today if the time is
  /// still ahead, otherwise tomorrow).
  static DateTime nextFixedOccurrence(String hhmm, DateTime from) {
    final parts = hhmm.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    var candidate = DateTime(from.year, from.month, from.day, h, m);
    if (!candidate.isAfter(from)) candidate = candidate.add(const Duration(days: 1));
    return candidate;
  }

  Reminder copyWith({
    String? label,
    ReminderCategory? category,
    ReminderMode? mode,
    String? fixedTime,
    int? intervalHours,
    int? nextDueAt,
  }) {
    return Reminder(
      id: id,
      alarmId: alarmId,
      label: label ?? this.label,
      category: category ?? this.category,
      mode: mode ?? this.mode,
      fixedTime: fixedTime ?? this.fixedTime,
      intervalHours: intervalHours ?? this.intervalHours,
      nextDueAt: nextDueAt ?? this.nextDueAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'alarmId': alarmId,
        'label': label,
        'category': category.name,
        'mode': mode.name,
        'fixedTime': fixedTime,
        'intervalHours': intervalHours,
        'nextDueAt': nextDueAt,
        'createdAt': createdAt,
      };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'] as String,
        alarmId: (json['alarmId'] as num).toInt(),
        label: json['label'] as String? ?? '',
        category: reminderCategoryFromString(json['category'] as String? ?? 'other'),
        mode: reminderModeFromString(json['mode'] as String? ?? 'fixed'),
        fixedTime: json['fixedTime'] as String? ?? '',
        intervalHours: (json['intervalHours'] as num?)?.toInt() ?? 0,
        nextDueAt: (json['nextDueAt'] as num?)?.toInt() ?? 0,
        createdAt: (json['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      );
}

/// An append-only record that a reminder was marked done. Drives the report's
/// "Done" rows and the completed/missed counts.
class ReminderLog {
  final String id;
  final String reminderId;
  final String label;
  final ReminderCategory category;
  final String date; // YYYY-MM-DD
  final String time; // HH:MM, 24h

  const ReminderLog({
    required this.id,
    required this.reminderId,
    required this.label,
    required this.category,
    required this.date,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'reminderId': reminderId,
        'label': label,
        'category': category.name,
        'date': date,
        'time': time,
      };

  factory ReminderLog.fromJson(Map<String, dynamic> json) => ReminderLog(
        id: json['id'] as String,
        reminderId: json['reminderId'] as String? ?? '',
        label: json['label'] as String? ?? '',
        category: reminderCategoryFromString(json['category'] as String? ?? 'other'),
        date: json['date'] as String,
        time: json['time'] as String,
      );
}

String _display12h(String time24) {
  final parts = time24.split(':');
  final h = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final ampm = h >= 12 ? 'PM' : 'AM';
  var h12 = h % 12;
  if (h12 == 0) h12 = 12;
  return '$h12:${_pad2(m)} $ampm';
}
