import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/alarm_service.dart';
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.appState.babyName);
    _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    final notif = await widget.appState.notifications.notificationsEnabled();
    final exact = await widget.appState.notifications.exactAlarmsAllowed();
    if (!mounted) return;
    setState(() {
      _notifOk = notif;
      _exactOk = exact;
    });
  }

  Future<void> _sendTestAlarm() async {
    await widget.appState.notifications
        .scheduleTest(soundId: widget.appState.alarmSound);
    _toast('Test alarm set for 10s from now — lock your phone and wait.');
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ok || checking ? AppColors.border : const Color(0xFFE39C8B),
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
                Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                if (!ok && !checking) ...[
                  const SizedBox(height: 2),
                  Text(badWhy, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          if (!ok && !checking)
            TextButton(
              onPressed: () async {
                await onFix();
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
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
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
              const Text("Baby's name", style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                onChanged: (v) => widget.appState.setBabyName(v),
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Mia',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Feed reminder', style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text(
                "Get nudged when it's about time for the next bottle.",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presets.map((m) {
                  final active = widget.appState.reminderIntervalMin == m;
                  return OutlinedButton(
                    onPressed: () => widget.appState.setReminderInterval(m),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: active ? accent : Colors.white,
                      foregroundColor: active ? Colors.white : AppColors.gearStroke,
                      side: active ? BorderSide.none : const BorderSide(color: AppColors.border, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(_presetLabel(m), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),
              const Text('Reminder alarm', style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text(
                'Rings like an alarm clock when a feed is due and keeps going until you dismiss it.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              const Text('SOUND', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
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
                      backgroundColor: active ? accent : Colors.white,
                      foregroundColor: active ? Colors.white : AppColors.gearStroke,
                      side: active ? BorderSide.none : const BorderSide(color: AppColors.border, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(s.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('VOLUME', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  const Spacer(),
                  Text('${(widget.appState.alarmVolume * 100).round()}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
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
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: accent,
                  thumbColor: accent,
                  inactiveTrackColor: AppColors.surfaceSecondary,
                  overlayColor: accent.withOpacity(0.15),
                ),
                child: Slider(
                  value: widget.appState.alarmVolume,
                  onChanged: (v) => widget.appState.setAlarmVolume(v),
                ),
              ),
              const SizedBox(height: 22),
              const Text('Notifications & alarm', style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text(
                'For the alarm to ring while the app is closed or your phone is locked, Android needs these two permissions. If the alarm only sounds when the app is open, one of these is off.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _sendTestAlarm,
                  icon: const Icon(Icons.notifications_active_rounded, size: 18),
                  label: const Text('Test alarm in 10s (lock your phone)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.gearStroke,
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text('Backup & restore', style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text(
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
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.gearStroke,
                          side: const BorderSide(color: AppColors.border, width: 1.5),
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
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.gearStroke,
                          side: const BorderSide(color: AppColors.border, width: 1.5),
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
        );
      },
    );
  }
}
