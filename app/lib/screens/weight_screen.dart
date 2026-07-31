import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/weight.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/log_weight_sheet.dart';
import '../widgets/weight_list_item.dart';

/// The Weight tab: a solid-sage latest-weight card, a full-width "Log weight"
/// button, and the reverse-chronological weigh-in history with delta pills.
/// Logging only — a lower-frequency measurement, kept apart from the
/// higher-frequency Feed / Diapers / Reminders logging. Uses the distinct sage
/// accent throughout so a weight entry never reads as another feature's.
class WeightScreen extends StatelessWidget {
  final AppState appState;
  const WeightScreen({super.key, required this.appState});

  Future<void> _handleDelete(BuildContext context, String id) async {
    final confirmed = await showDeleteConfirmDialog(context, title: 'Delete this weigh-in?');
    if (confirmed) {
      await appState.deleteWeight(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final title = appState.babyName.isNotEmpty ? "${appState.babyName}'s weight" : 'Weight';
        final history = appState.weightsDescending; // newest first
        final latest = appState.latestWeight;

        return SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Text(title,
                      style: TextStyle(fontFamily: balooFamily, fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Text('Track weigh-ins over time to watch steady growth.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                  child: _LatestCard(appState: appState, latest: latest),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => showLogWeightSheet(context, appState),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.weightAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                      ).copyWith(
                        shadowColor: WidgetStateProperty.all(AppColors.weightAccent.withValues(alpha: 0.35)),
                      ),
                      child: const Text('Log weight', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                  child: Text('History',
                      style: TextStyle(fontFamily: balooFamily, fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  child: history.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
                          child: Center(
                            child: Text('No weigh-ins logged yet.',
                                style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        )
                      : Column(
                          children: history
                              .map((w) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: WeightListItem(
                                      weight: w,
                                      state: appState,
                                      onEdit: () => showLogWeightSheet(context, appState, existing: w),
                                      onDelete: () => _handleDelete(context, w.id),
                                    ),
                                  ))
                              .toList(),
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

/// The solid-sage summary card at the top of the tab: the most recent weigh-in's
/// value (large) and its date, or a muted "No entries yet" when empty.
class _LatestCard extends StatelessWidget {
  final AppState appState;
  final Weight? latest;
  const _LatestCard({required this.appState, required this.latest});

  @override
  Widget build(BuildContext context) {
    final latest = this.latest;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.weightAccent,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.weightAccent.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LATEST WEIGHT',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.85), letterSpacing: 0.3)),
          const SizedBox(height: 8),
          if (latest != null) ...[
            Text(
              appState.weightLabel(latest.kg),
              style: const TextStyle(fontFamily: balooFamily, fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(DateTime.parse(latest.date)),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
            ),
          ] else
            const Text(
              'No entries yet',
              style: TextStyle(fontFamily: balooFamily, fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
            ),
        ],
      ),
    );
  }
}
