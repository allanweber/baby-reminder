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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.appState.babyName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _presetLabel(int minutes) => minutes % 60 == 0 ? '${minutes ~/ 60}h' : '${(minutes / 60).toStringAsFixed(1)}h';

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

  Future<void> _setupAutoBackup() async {
    final uri = await widget.appState.backup.pickFolder();
    if (uri == null || !mounted) return;

    final existing = await widget.appState.backup.existingBackupUri(uri);
    if (!mounted) return;

    if (existing != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Backup found in this folder'),
          content: const Text('Restore that backup onto this device, or replace it with the data currently on this device?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop('cancel'), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(context).pop('replace'), child: const Text('Replace')),
            TextButton(onPressed: () => Navigator.of(context).pop('restore'), child: const Text('Restore')),
          ],
        ),
      );
      if (choice == 'restore') {
        final content = await widget.appState.backup.read(existing);
        if (content == null) {
          _toast('Could not read the existing backup');
          return;
        }
        final count = await widget.appState.importData(content);
        await widget.appState.enableAutoBackup(uri);
        _toast(count == null ? 'Backup file was invalid' : 'Restored $count feeds · auto-backup on');
        return;
      } else if (choice != 'replace') {
        return; // cancelled
      }
    }

    await widget.appState.enableAutoBackup(uri);
    _toast('Auto-backup is on');
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
              const Text('Backup & restore', style: TextStyle(fontFamily: balooFamily, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text(
                'Feeds are stored only on this device. Keep your history safe against uninstalls and new phones.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.appState.autoBackupOn ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                          size: 20,
                          color: widget.appState.autoBackupOn ? AppColors.accentSage : AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.appState.autoBackupOn ? 'Automatic backup is on' : 'Automatic backup is off',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Silently saves a backup to a folder you pick (e.g. Google Drive) whenever something changes, and offers to restore it when you re-pick that folder after a reinstall.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    if (widget.appState.autoBackupOn)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _setupAutoBackup,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.gearStroke,
                                side: const BorderSide(color: AppColors.border, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Change folder', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await widget.appState.disableAutoBackup();
                                _toast('Auto-backup turned off');
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.errorText,
                                side: const BorderSide(color: AppColors.border, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Turn off', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _setupAutoBackup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Turn on auto-backup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('OR SAVE A ONE-OFF FILE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              const SizedBox(height: 8),
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
