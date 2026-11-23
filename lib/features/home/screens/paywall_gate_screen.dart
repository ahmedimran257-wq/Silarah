// SILARAH — Paywall Gate (Step 9)
//
// Shown as a bottom sheet when a male non-subscriber tries
// to open a chat conversation.
//
//   "Non-subscriber men who try to open a chat see:
//    'Subscribe to unlock messaging. Women always message
//     free on SILARAH.' The price shown is in their local currency."
//
// Usage:
//   PaywallGateSheet.show(context);
import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/messaging_access_policy.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/overlays/silarah_bottom_sheet.dart';
import 'subscription_screen.dart';
import '../../calls/calls_hub.dart';

/// Why the Premium sheet is being shown.
enum PremiumGate {
  /// Opening or continuing a conversation. Women message free, so this gate
  /// never shows to them.
  messaging,

  /// A Premium feature that is the same for everyone: the daily profile
  /// limit, the private shortlist, compatibility insights. It shows to
  /// every free member, women included.
  feature,

  /// Starting a voice call (docs/voice_calling_spec.md 2): only Premium
  /// members call. Shows to every free member; free women can still answer.
  calls,
}

class PaywallGateSheet {
  static Future<void>? _activeSheet;

  /// Shows the paywall as a modal bottom sheet.
  ///
  /// For [PremiumGate.messaging] this is a no-op for women, who message
  /// free (defence-in-depth on top of the call-site checks in
  /// chat_list_screen.dart and chat_screen.dart). [PremiumGate.feature]
  /// gates apply to everyone; before it existed a woman tapping "Upgrade
  /// Now" or a Premium card got no response at all.
  static Future<void> show(
    BuildContext context, {
    PremiumGate gate = PremiumGate.messaging,
  }) {
    final authState = context.read<AuthCubit>().state;
    final gender = authState is AuthAuthenticated ? authState.gender : null;
    if (gate == PremiumGate.messaging &&
        MessagingAccessPolicy.hasFreeMessaging(gender)) {
      return Future.value();
    }

    // A fast double tap can finish two access checks before the first route is
    // painted. Share one in-flight modal future so only one paywall can exist.
    final active = _activeSheet;
    if (active != null) return active;

    final sheet = showSilarahBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaywallGateContent(gate: gate),
    );
    _activeSheet = sheet;
    return sheet.whenComplete(() {
      if (identical(_activeSheet, sheet)) _activeSheet = null;
    });
  }
}

class _PaywallGateContent extends StatelessWidget {
  const _PaywallGateContent({required this.gate});

  final PremiumGate gate;

  @override
  Widget build(BuildContext context) {
    final forFeature = gate == PremiumGate.feature;
    final forCalls = gate == PremiumGate.calls;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMid,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.goldBorder, width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Product-specific premium seal rather than a generic lock screen.
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: AppColors.goldGlow,
              border: Border.all(color: AppColors.goldBorder, width: 1.5),
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.champagneGold,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),

          UiText(
            forCalls
                ? 'Talk with your matches'
                : forFeature
                    ? 'Unlock Silarah Premium'
                    : 'Continue your conversation',
            style: AppTypography.screenTitle.copyWith(fontSize: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          UiText(
            forCalls
                ? 'Premium members call their matches inside Silarah, with no phone numbers shared. Answering a call is always free.'
                : forFeature
                    ? 'Browse without a daily limit and get the tools that help you decide with care.'
                    : 'Women can message their matches at no cost.\nMen unlock conversations with Silarah Premium.',
            style: AppTypography.bodyMuted.copyWith(height: 1.45),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),

          if (forCalls) ...[
            _PremiumProofRow(
              icon: Icons.call_outlined,
              label: context.uiCopyWith('{included} call minutes every month',
                  {'included': CallsHub.instance.rules.value?.includedMinutes ?? 0}),
            ),
            const SizedBox(height: 7),
            const _PremiumProofRow(
              icon: Icons.lock_outline_rounded,
              label: 'Private calls, never recorded',
            ),
            const SizedBox(height: 7),
            const _PremiumProofRow(
              icon: Icons.forum_outlined,
              label: 'Full match messaging',
            ),
          ] else if (forFeature) ...[
            const _PremiumProofRow(
              icon: Icons.all_inclusive_rounded,
              label: 'Unlimited profile browsing',
            ),
            const SizedBox(height: 7),
            const _PremiumProofRow(
              icon: Icons.bookmark_added_outlined,
              label: 'Private shortlist',
            ),
            const SizedBox(height: 7),
            const _PremiumProofRow(
              icon: Icons.hub_outlined,
              label: 'Mutual compatibility insights',
            ),
            if (CallsHub.instance.callingOn) ...[
              const SizedBox(height: 7),
              const _PremiumProofRow(
                icon: Icons.call_outlined,
                label: 'Private voice calls with your matches',
              ),
            ],
          ] else ...[
            const _PremiumProofRow(
              icon: Icons.forum_outlined,
              label: 'Full match messaging',
            ),
            // Listed only while calling is switched on (spec 12.6).
            if (CallsHub.instance.callingOn) ...[
              const SizedBox(height: 7),
              const _PremiumProofRow(
                icon: Icons.call_outlined,
                label: 'Private voice calls with your matches',
              ),
            ],
            const SizedBox(height: 7),
            const _PremiumProofRow(
              icon: Icons.travel_explore_rounded,
              label: 'All India discovery and advanced filters',
            ),
          ],
          const SizedBox(height: 7),
          const _PremiumProofRow(
            icon: Icons.visibility_outlined,
            label: 'Profile viewers and weekly boost',
          ),
          const SizedBox(height: 14),

          // Price highlight
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppColors.goldGlow,
              border: Border.all(color: AppColors.goldBorder),
            ),
            child: UiText(
              context.uiCopy('Plans are shown in your local currency'),
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.champagneGold),
            ),
          ),

          const SizedBox(height: 20),

          // Subscribe CTA
          SilarahPressable(
            semanticLabel: context.uiCopy('See Plans'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SubscriptionScreen(),
                ),
              );
            },
            child: Container(
              height: 54,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppColors.champagneGold,
              ),
              alignment: Alignment.center,
              child: UiText(
                context.uiCopy('See Plans'),
                style: AppTypography.button.copyWith(
                  color: AppColors.readableOn(AppColors.champagneGold),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Not Now
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: UiText(
              context.uiCopy('Not Now'),
              style: AppTypography.bodyMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumProofRow extends StatelessWidget {
  const _PremiumProofRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.champagneGold, size: 17),
        const SizedBox(width: 8),
        Flexible(
          child: UiText(
            context.uiCopy(label),
            style: AppTypography.captionMedium,
          ),
        ),
      ],
    );
  }
}
