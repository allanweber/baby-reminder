import '../theme/app_theme.dart';

/// How far ahead of an appointment its *lead* alarm should ring. Every
/// appointment also rings a second alarm at the appointment time itself (see
/// [Appointment.atAlarmId]); this only controls the earlier heads-up.
/// - [none]: no lead alarm, only the at-time alarm fires.
/// - [oneHour]: rings one hour before.
/// - [oneDay]: rings one day before.
enum AppointmentLead { none, oneHour, oneDay }

AppointmentLead appointmentLeadFromString(String s) =>
    AppointmentLead.values.firstWhere((l) => l.name == s, orElse: () => AppointmentLead.none);

extension AppointmentLeadX on AppointmentLead {
  /// How long before the appointment the lead alarm fires. Null for [none].
  Duration? get before {
    switch (this) {
      case AppointmentLead.none:
        return null;
      case AppointmentLead.oneHour:
        return const Duration(hours: 1);
      case AppointmentLead.oneDay:
        return const Duration(days: 1);
    }
  }

  /// Picker/summary label, e.g. "1 hour before".
  String get label {
    switch (this) {
      case AppointmentLead.none:
        return 'No reminder';
      case AppointmentLead.oneHour:
        return '1 hour before';
      case AppointmentLead.oneDay:
        return '1 day before';
    }
  }

  /// Short form for the list rows, e.g. "1h before".
  String get shortLabel {
    switch (this) {
      case AppointmentLead.none:
        return 'No reminder';
      case AppointmentLead.oneHour:
        return '1h before';
      case AppointmentLead.oneDay:
        return '1 day before';
    }
  }
}

String _pad2(int n) => n < 10 ? '0$n' : '$n';

/// A one-off, dated event (a doctor's visit, a vaccination…) as opposed to the
/// recurring [Reminder]. It rings the same full-screen `alarm` engine, but twice:
/// once at [leadAlarmId] (the 1h/1d heads-up, if any) and once at [atAlarmId]
/// (the appointment time). Both ids come from the shared reminder alarm-id space
/// so they never collide with the feed reminder, the test alarm, or a care
/// reminder.
class Appointment {
  final String id;
  final int leadAlarmId;
  final int atAlarmId;
  final String title; // optional; falls back to the category label when empty
  final AppointmentCategory category;
  final int atMs; // ms since epoch: the appointment date + time
  final AppointmentLead lead;
  final String description; // optional free text
  final int? doneAtMs; // ms since epoch when marked done; null = not done yet
  final int createdAt; // ms since epoch

  const Appointment({
    required this.id,
    required this.leadAlarmId,
    required this.atAlarmId,
    required this.title,
    required this.category,
    required this.atMs,
    required this.lead,
    required this.description,
    required this.doneAtMs,
    required this.createdAt,
  });

  bool get isDone => doneAtMs != null;

  DateTime get at => DateTime.fromMillisecondsSinceEpoch(atMs);

  /// When the lead alarm should ring, or null when there is no lead.
  DateTime? get leadAt {
    final d = lead.before;
    if (d == null) return null;
    return at.subtract(d);
  }

  String get dateStr => '${at.year}-${_pad2(at.month)}-${_pad2(at.day)}';
  String get timeStr => '${_pad2(at.hour)}:${_pad2(at.minute)}';

  /// The line shown as the row's headline: the title, or the category label when
  /// the title was left blank.
  String get displayTitle =>
      title.isNotEmpty ? title : appointmentCategories[category]!.label;

  /// True when the appointment time has passed and it was never marked done —
  /// it lingers as an "overdue" card until resolved.
  bool isOverdue(DateTime now) => !isDone && at.isBefore(now);

  Appointment copyWith({
    String? title,
    AppointmentCategory? category,
    int? atMs,
    AppointmentLead? lead,
    String? description,
    int? doneAtMs,
    bool clearDone = false,
  }) {
    return Appointment(
      id: id,
      leadAlarmId: leadAlarmId,
      atAlarmId: atAlarmId,
      title: title ?? this.title,
      category: category ?? this.category,
      atMs: atMs ?? this.atMs,
      lead: lead ?? this.lead,
      description: description ?? this.description,
      doneAtMs: clearDone ? null : (doneAtMs ?? this.doneAtMs),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'leadAlarmId': leadAlarmId,
        'atAlarmId': atAlarmId,
        'title': title,
        'category': category.name,
        'atMs': atMs,
        'lead': lead.name,
        'description': description,
        'doneAtMs': doneAtMs,
        'createdAt': createdAt,
      };

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'] as String,
        leadAlarmId: (json['leadAlarmId'] as num).toInt(),
        atAlarmId: (json['atAlarmId'] as num).toInt(),
        title: json['title'] as String? ?? '',
        category: appointmentCategoryFromString(json['category'] as String? ?? 'other'),
        atMs: (json['atMs'] as num).toInt(),
        lead: appointmentLeadFromString(json['lead'] as String? ?? 'none'),
        description: json['description'] as String? ?? '',
        doneAtMs: (json['doneAtMs'] as num?)?.toInt(),
        createdAt: (json['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      );
}
