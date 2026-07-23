import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/feed_fab.dart';
import '../widgets/log_feed_sheet.dart';
import 'home_screen.dart';
import 'report_screen.dart';

/// Persistent shell: bottom tab bar + FAB stay put while Home/Daily report
/// swap underneath, matching the prototype where both screens share one
/// device frame.
class AppShell extends StatefulWidget {
  final AppState appState;
  const AppShell({super.key, required this.appState});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Rebuild on every state change so the alarm overlay appears/disappears the
    // moment the reminder starts or is dismissed.
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) => Stack(
        children: [
          _buildShell(context),
          if (widget.appState.alarmRinging)
            _AlarmOverlay(
              appState: widget.appState,
              onLog: () => showLogFeedSheet(context, widget.appState),
            ),
        ],
      ),
    );
  }

  Widget _buildShell(BuildContext context) {
    const accent = AppColors.accentBlush;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _tabIndex,
        children: [
          HomeScreen(appState: widget.appState),
          ReportScreen(appState: widget.appState),
        ],
      ),
      floatingActionButton: FeedFab(
        accentColor: accent,
        onTap: () => showLogFeedSheet(context, widget.appState),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0E6DD), width: 1)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: _TabButton(
                  icon: AppIcons.house(color: _tabIndex == 0 ? accent : AppColors.textMuted),
                  label: 'Home',
                  active: _tabIndex == 0,
                  accent: accent,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
              ),
              Expanded(
                child: _TabButton(
                  icon: AppIcons.calendar(color: _tabIndex == 1 ? accent : AppColors.textMuted),
                  label: 'Daily report',
                  active: _tabIndex == 1,
                  accent: accent,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen "alarm playing" state shown over the whole app while the feed
/// reminder is ringing, with an immediate way to stop it.
class _AlarmOverlay extends StatelessWidget {
  final AppState appState;
  final VoidCallback onLog;
  const _AlarmOverlay({required this.appState, required this.onLog});

  @override
  Widget build(BuildContext context) {
    final isTimer = appState.alarmIsCustomTimer;
    final name = appState.babyName;
    final title = isTimer
        ? '${appState.customTimerLabel} done'
        : (name.isNotEmpty ? '$name is due for a feed' : 'Time for a feed');
    final subtitle = isTimer ? 'Your timer is up' : 'Your feed alarm is playing';
    return Positioned.fill(
      child: Material(
        color: AppColors.overdue,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              children: [
                const Spacer(),
                const Icon(Icons.notifications_active_rounded, size: 96, color: Colors.white),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: balooFamily, fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: () => appState.dismissReminder(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.overdue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Text(isTimer ? 'Stop timer' : 'Dismiss alarm',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => appState.snoozeReminder(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(isTimer ? '+15 min' : 'Snooze 15m',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: onLog,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Log feed', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;
  const _TabButton({required this.icon, required this.label, required this.active, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? accent : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
