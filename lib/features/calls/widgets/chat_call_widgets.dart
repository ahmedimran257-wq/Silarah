// Calling inside a chat: the call button, the call history tiles shown among
// the messages, and the per-chat "mute calls / block calls" choices.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/overlays/silarah_bottom_sheet.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/ui_copy.dart';
import '../../home/screens/paywall_gate_screen.dart';
import '../call_api.dart';
import '../call_controller.dart';
import '../call_models.dart';
import 'call_microphone_gate.dart';
import 'call_minutes_sheet.dart';
import '../screens/call_screen.dart';

/// Loads and refreshes the call controls of one chat.
class ChatCallControls extends ValueNotifier<ChatCallState> {
  ChatCallControls(this.matchId) : super(ChatCallState.hidden) {
    CallController.historyVersion.addListener(_onHistoryChanged);
  }

  final String matchId;
  bool _disposed = false;

  Future<void> refresh() async {
    final state = await CallApi.instance.chatState(matchId);
    if (!_disposed) value = state;
  }

  /// A call ended or a missed-call note arrived: show it in the history.
  void _onHistoryChanged() => unawaited(refresh());

  Future<bool> setPrefs({required bool muted, required bool callsBlocked}) async {
    final ok = await CallApi.instance.setChatPrefs(matchId, muted: muted, callsBlocked: callsBlocked);
    await refresh();
    return ok;
  }

  @override
  void dispose() {
    _disposed = true;
    CallController.historyVersion.removeListener(_onHistoryChanged);
    super.dispose();
  }
}

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: UiText.verbatim(text)));
}

/// The call button in the chat header.
Future<void> startCallFromChat(
  BuildContext context, {
  required ChatCallControls controls,
  required String name,
  String? photoUrl,
  String? otherUserId,
}) async {
  final state = controls.value;
  if (!state.callsEnabled) {
    _snack(context, context.uiCopy("Calling isn't available right now."));
    return;
  }
  if (state.reason == 'premium_required') {
    await PaywallGateSheet.show(context, gate: PremiumGate.calls);
    return;
  }
  if (state.reason == 'limit_reached') {
    _snack(context, context.uiCopyWith('You can call {name} again tomorrow.', {'name': name}));
    return;
  }
  if (state.reason == 'not_allowed' || state.reason == 'account_restricted') {
    _snack(context, context.uiCopy("You can't call in this chat."));
    return;
  }
  await placeCall(
    context,
    matchId: controls.matchId,
    name: name,
    photoUrl: photoUrl,
    otherUserId: otherUserId,
    onUnavailable: () => unawaited(controls.refresh()),
  );
}

/// Places a call and explains every outcome the server can give. Used by
/// the chat header and the Calls tab; the server decides who may call.
Future<void> placeCall(
  BuildContext context, {
  required String matchId,
  required String name,
  String? photoUrl,
  String? otherUserId,
  VoidCallback? onUnavailable,
}) async {
  if (!await ensureCallMicrophone(context) || !context.mounted) return;
  final router = GoRouter.of(context);
  final result = await CallController.instance.startOutgoing(
    toMatchId: matchId,
    name: name,
    toUserId: otherUserId,
  );
  if (!context.mounted) return;
  switch (result.outcome) {
    case CallStartOutcome.ringing:
    case CallStartOutcome.glare:
      if (!CallScreen.isOpen) {
        unawaited(router.push('/call', extra: {'photoUrl': photoUrl, 'otherUserId': otherUserId}));
      }
    case CallStartOutcome.unavailable:
      _snack(context, context.uiCopyWith(neutralUnavailableCopy, {'name': name}));
      onUnavailable?.call();
    case CallStartOutcome.premiumRequired:
      await PaywallGateSheet.show(context, gate: PremiumGate.calls);
    case CallStartOutcome.noMinutes:
    case CallStartOutcome.balanceNegative:
      await showCallMinutesSheet(context);
    case CallStartOutcome.limitReached:
      _snack(context, context.uiCopyWith('You can call {name} again tomorrow.', {'name': name}));
    case CallStartOutcome.callsDisabled:
      _snack(context, context.uiCopy("Calling isn't available right now."));
    case CallStartOutcome.capacity:
      _snack(context, context.uiCopy('Calling is busy right now. Please try again later.'));
    case CallStartOutcome.busySelf:
      _snack(context, context.uiCopy("You're already in a call."));
    case CallStartOutcome.notAllowed:
      _snack(context, context.uiCopy("You can't call in this chat."));
    case CallStartOutcome.rateLimited:
      _snack(context, context.uiCopy('Too many calls. Please try again later.'));
    case CallStartOutcome.failed:
      _snack(context, context.uiCopy('Call failed. Please try again.'));
  }
}

class ChatCallButton extends StatelessWidget {
  const ChatCallButton({super.key, required this.controls, required this.onTap});
  final ChatCallControls controls;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ChatCallState>(
      valueListenable: controls,
      builder: (context, state, _) {
        if (!state.showCallButton) return const SizedBox.shrink();
        return Semantics(
          button: true,
          label: context.uiCopy('Voice call'),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsetsDirectional.only(start: AppDimensions.space4),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Icon(Icons.call_outlined, color: AppColors.champagneGold, size: 20),
            ),
          ),
        );
      },
    );
  }
}

/// Mute / block calls from the chat menu.
Future<void> showChatCallPrefsSheet(
  BuildContext context, {
  required ChatCallControls controls,
  required String name,
}) async {
  await showSilarahBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceMid,
    builder: (sheetContext) => ValueListenableBuilder<ChatCallState>(
      valueListenable: controls,
      builder: (context, state, _) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              value: state.muted,
              activeThumbColor: AppColors.champagneGold,
              title: UiText('Mute calls from this chat', style: AppTypography.body),
              subtitle: UiText('Calls do not ring; they show as missed.',
                  style: AppTypography.caption.copyWith(color: AppColors.slateMist)),
              onChanged: (value) => controls.setPrefs(muted: value, callsBlocked: state.callsBlocked),
            ),
            SwitchListTile(
              value: state.callsBlocked,
              activeThumbColor: AppColors.softCoral,
              title: UiText.verbatim(context.uiCopyWith('Block calls from {name}', {'name': name}),
                  style: AppTypography.body),
              subtitle: UiText('You can still message. They are not told.',
                  style: AppTypography.caption.copyWith(color: AppColors.slateMist)),
              onChanged: (value) => controls.setPrefs(muted: state.muted, callsBlocked: value),
            ),
            const SizedBox(height: AppDimensions.space8),
          ],
        ),
      ),
    ),
  );
}

/// One call in the chat timeline.
class ChatCallTile extends StatelessWidget {
  const ChatCallTile({
    super.key,
    required this.event,
    required this.name,
    required this.iAmFemale,
    required this.iAmPremium,
    required this.onCallBack,
    required this.onAskToCallBack,
  });

  final ChatCallEvent event;
  final String name;
  final bool iAmFemale;
  final bool iAmPremium;
  final VoidCallback onCallBack;
  final VoidCallback onAskToCallBack;

  @override
  Widget build(BuildContext context) {
    final missedForMe = !event.outgoing &&
        (event.outcome == CallEventOutcome.missed || event.outcome == CallEventOutcome.declined);
    final time = DateFormat.jm(Localizations.localeOf(context).toLanguageTag()).format(event.createdAt);
    final String title;
    if (event.outcome == CallEventOutcome.answered) {
      title = context.uiCopyWith(
        event.outgoing ? 'You called · {duration}' : '{name} called · {duration}',
        {'name': name, 'duration': formatCallDuration(event.durationSeconds ?? 0)},
      );
    } else if (event.outgoing) {
      title = context.uiCopy('You called · no answer');
    } else if (event.outcome == CallEventOutcome.declined) {
      title = context.uiCopyWith('You declined a call from {name}', {'name': name});
    } else {
      title = context.uiCopyWith('📞 {name} tried to call you', {'name': name});
    }
    final showActions = missedForMe;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space8),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: missedForMe ? AppColors.goldBorder : AppColors.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    event.outcome == CallEventOutcome.answered
                        ? Icons.call_rounded
                        : event.outgoing
                            ? Icons.call_made_rounded
                            : Icons.call_missed_rounded,
                    size: 16,
                    color: missedForMe ? AppColors.champagneGold : AppColors.slateMist,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: UiText.verbatim(title,
                        style: AppTypography.caption.copyWith(color: AppColors.pearlWhite)),
                  ),
                  const SizedBox(width: 8),
                  UiText.verbatim(time, style: AppTypography.caption.copyWith(color: AppColors.slateMist)),
                ],
              ),
              if (showActions) ...[
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    // Free women message free (spec 8): ask him to call back.
                    if (iAmFemale && !iAmPremium)
                      TextButton(
                        onPressed: onAskToCallBack,
                        child: UiText('Ask him to call back',
                            style: AppTypography.caption.copyWith(color: AppColors.champagneGold)),
                      ),
                    // Without Premium this opens the paywall (spec 2 and 8).
                    TextButton(
                      onPressed: onCallBack,
                      child: UiText('Call back',
                          style: AppTypography.caption.copyWith(color: AppColors.champagneGold)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The message a free woman sends with "Ask him to call back".
const askToCallBackMessage = 'Please call me back when you can.';
