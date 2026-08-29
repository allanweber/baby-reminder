import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/alarm_service.dart';
import '../services/error_log.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

Future<void> showSettingsSheet(BuildContext context, AppState appState) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SettingsSheet(appState: appState),
  );
}

class SettingsSheet extends StatefulWidget {
  final AppState appState;
  const SettingsSheet({super.key, required this.appState});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late final TextEditingController _nameController;
  static const _presets = [90, 120, 180, 240, 300];

  // Live permission state for the diagnostics panel; null = still checking.
  bool? _notifOk;
  bool? _exactOk;
  // Most recent recorded crash/error, if any.
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.appState.babyName);
    _refreshPermissions();
    _loadLastError();
  }

  Future<void> _loadLastError() async {
    final err = await ErrorLog.read();
    if (!mounted) return;
    setState(() {
      _lastError = err;
    });
  }

  Future<void> _refreshPermissions() async {
    bool? notif;
    bool? exact;
    try {
      notif = await widget.appState.notifications.notificationsEnabled();
      exact = await widget.appState.notifications.exactAlarmsAllowed();
    } catch (_) {
      // Leave the rows as "checking" rather than letting a platform error
      // bubble up and take the whole sheet down.
    }
    if (!mounted) return;
    setState(() {
      _notifOk = notif;
      _exactOk = exact;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _presetLabel(int minutes) => minutes % 60 == 0 ? '${minutes ~/ 60}h' : '${(minutes / 60).toStringAsFixed(1)}h';

  Widget _permissionRow({
    required String label,
    required String badWhy,
    required bool? granted,
    required Future<void> Function() onFix,
  }) {
    final ok = granted == true;
    final checking = granted == null;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ok || checking ? AppColors.border : AppColors.accentBlush,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            checking
                ? Icons.hourglass_empty_rounded
                : ok
                    ? Icons.check_circle_rounded
                    : Icons.error_rounded,
            size: 20,
            color: checking
                ? AppColors.textSecondary
                : ok
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFD9694F),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                if (!ok && !checking) ...[
                  const SizedBox(height: 2),
                  Text(badWhy, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          if (!ok && !checking)
            TextButton(
              onPressed: () async {
                try {
                  await onFix();
                } catch (e) {
                  _toast('Could not open the setting: $e');
                }
                await _refreshPermissions();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.reminderTitleText,
                backgroundColor: AppColors.settingsBg,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Fix', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportBackup() async {
    final bytes = Uint8List.fromList(utf8.encode(widget.appState.exportData()));
    final name = 'baby-feed-backup-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.json';
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save backup',
        fileName: name,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (path != null) _toast('Backup saved');
    } catch (_) {
      _toast('Could not save the backup');
    }
  }

  Future<void> _importBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text('This replaces the feeds and settings currently on this device with the contents of the backup file.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Choose a backup file',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final data = result.files.first.bytes;
      if (data == null) {
        _toast('Could not read that file');
        return;
      }
      final count = await widget.appState.importData(utf8.decode(data));
      _toast(count == null ? "That file isn't a valid backup" : 'Restored $count feeds');
    } catch (_) {
      _toast('Could not import the backup');
    }
  }


  @override
  Widget build(BuildContext context) {
    const accent = AppColors.accentBlush;
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          child: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: AppColors.dragHandle, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: 24 + MediaQuery.of(context).viewInsets.bottom),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              Text("Baby's name", style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                onChanged: (v) => widget.appState.setBabyName(v),
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Mia',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.cardWhite,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.border, width: 1.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.border, width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.border, width: 1.5)),
                ),
              ),
              const SizedBox(height: 20),
              Text('Feed reminder', style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(
                "Get nudged when it's about time for the next bottle.",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              _ToggleRow(
                title: 'Automatic next-feed reminder',
                subtitle: 'Start a countdown after each logged feed. Off by default — handy for scheduled feeds, skip it for on-demand.',
                value: widget.appState.feedReminderEnabled,
                accent: accent,
                onChanged: (v) => widget.appState.setFeedReminderEnabled(v),
              ),
              if (widget.appState.feedReminderEnabled) ...[
                const SizedBox(height: 14),
                Text('REMIND EVERY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presets.map((m) {
                    final active = widget.appState.reminderIntervalMin == m;
                    return OutlinedButton(
                      onPressed: () => widget.appState.setReminderInterval(m),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: active ? accent : AppColors.cardWhite,
                        foregroundColor: active ? Colors.white : AppColors.gearStroke,
                        side: active ? BorderSide.none : BorderSide(color: AppColors.border, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(_presetLabel(m), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 22),
              Text('Appearance', style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              _DarkModeRow(
                value: widget.appState.darkMode,
                accent: accent,
                onChanged: (v) => widget.appState.setDarkMode(v),
              ),
              const SizedBox(height: 22),
              Text('Reminder alarm', style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(
                'Rings like an alarm clock when a feed is due and keeps going until you dismiss it.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Text('SOUND', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kAlarmSounds.map((s) {
                  final active = widget.appState.alarmSound == s.id;
                  return OutlinedButton(
                    onPressed: () {
                      widget.appState.setAlarmSound(s.id);
                      widget.appState.previewAlarm(s.id);
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: active ? accent : AppColors.cardWhite,
                      foregroundColor: active ? Colors.white : AppColors.gearStroke,
                      side: active ? BorderSide.none : BorderSide(color: AppColors.border, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(s.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reminders ring at your phone’s alarm volume, so they stay quiet when it’s turned down or muted. Adjust the volume with your side buttons while a preview or alarm is playing.',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => widget.appState.previewAlarm(),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Preview', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.reminderTitleText,
                      backgroundColor: AppColors.settingsBg,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text('Notifications & alarm', style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(
                'For the alarm to ring while the app is closed or your phone is locked, Android needs these two permissions. If the alarm only sounds when the app is open, one of these is off.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              if (_lastError != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECE7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD9694F), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Last recorded error', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFFB84A32))),
                      const SizedBox(height: 6),
                      // Fixed dark ink: this panel keeps its light-pink background in
                      // both themes, so its body text must not follow the theme.
                      Text(_lastError!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4A3B36))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _lastError!));
                              _toast('Error copied — paste it to me.');
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFFB84A32)),
                            label: const Text('Copy', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFB84A32))),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFB84A32),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              await ErrorLog.clear();
                              if (!mounted) return;
                              setState(() => _lastError = null);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF8B7A73),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            ),
                            child: const Text('Clear', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              _permissionRow(
                label: 'Show notifications',
                badWhy: 'Off — alarms fire silently with nothing on screen.',
                granted: _notifOk,
                onFix: widget.appState.notifications.requestNotifications,
              ),
              _permissionRow(
                label: 'Alarms & reminders (exact)',
                badWhy: 'Off — the alarm can be delayed or skipped while idle.',
                granted: _exactOk,
                onFix: widget.appState.notifications.requestExactAlarms,
              ),
              const SizedBox(height: 22),
              Text('Backup & restore', style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(
                'Feeds are stored only on this device. Save a backup file to keep your history safe before uninstalling or switching phones, and import it to restore.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _exportBackup,
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: const Text('Export', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.cardWhite,
                          foregroundColor: AppColors.gearStroke,
                          side: BorderSide(color: AppColors.border, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _importBackup,
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Import', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.cardWhite,
                          foregroundColor: AppColors.gearStroke,
                          side: BorderSide(color: AppColors.border, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}

/// Settings row for the light/dark toggle: label + description on the left, a
/// pill switch on the right (track = accent when on, soft neutral when off;
/// white thumb slides left/right). Persisted via [AppState.setDarkMode].
class _DarkModeRow extends StatelessWidget {
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;
  const _DarkModeRow({required this.value, required this.accent, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dark mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('Easier on the eyes for night feeds.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _PillSwitch(value: value, accent: accent, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// A generic labelled toggle row (title + description on the left, a pill switch
/// on the right). Used for the automatic feed-reminder toggle.
class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _PillSwitch(value: value, accent: accent, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _PillSwitch extends StatelessWidget {
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;
  const _PillSwitch({required this.value, required this.accent, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? accent : AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(15),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }
}
