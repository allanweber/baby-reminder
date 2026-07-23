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
