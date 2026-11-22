// Guardian mode (spec 8): the Guardian sees when calls happened and how
// long they lasted, never anything said. Guardians never block calls.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/overlays/silarah_bottom_sheet.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/ui_copy.dart';
import '../call_models.dart';

class GuardianCallLogButton extends StatelessWidget {
  const GuardianCallLogButton({super.key, required this.matchId});
  final String matchId;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.uiCopy('Call times'),
      icon: Icon(Icons.call_outlined, color: AppColors.slateMist),
      onPressed: () => showSilarahBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surfaceMid,
        builder: (_) => _GuardianCallLog(matchId: matchId),
      ),
    );
  }
}

class _GuardianCallLog extends StatelessWidget {
  const _GuardianCallLog({required this.matchId});
  final String matchId;

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await SupabaseService.client
        .rpc('get_guardian_match_calls', params: {'p_match_id': matchId});
    return (rows as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return SafeArea(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(height: 160, child: Center(child: SilarahPulseLoader()));
          }
          final rows = snapshot.data ?? const [];
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UiText('Call times', style: AppTypography.screenTitle),
                const SizedBox(height: 4),
                UiText('Calls are never recorded. You see only when they happened and how long they lasted.',
                    style: AppTypography.caption.copyWith(color: AppColors.slateMist)),
                const SizedBox(height: 12),
                if (snapshot.hasError)
                  UiText('Call times could not be loaded.', style: AppTypography.body)
                else if (rows.isEmpty)
                  UiText('No calls yet', style: AppTypography.body.copyWith(color: AppColors.slateMist))
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final row in rows)
                          ListTile(
                            dense: true,
                            leading: Icon(
                              row['answered'] == true ? Icons.call_rounded : Icons.call_missed_rounded,
                              color: AppColors.slateMist,
                            ),
                            title: UiText.verbatim(
                              DateFormat.yMMMd(locale).add_jm().format(
                                  DateTime.parse(row['called_at'].toString()).toLocal()),
                              style: AppTypography.body,
                            ),
                            trailing: UiText.verbatim(
                              row['answered'] == true
                                  ? formatCallDuration((row['duration_seconds'] as num?)?.toInt() ?? 0)
                                  : context.uiCopy('Not answered'),
                              style: AppTypography.caption.copyWith(color: AppColors.slateMist),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
