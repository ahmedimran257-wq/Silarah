// "Tap to return to call · 04:12" above every screen while a call is ringing
// out or live and the member has left the call screen
// (docs/voice_calling_spec.md 12.1). The tree keeps the same shape whether
// the bar shows or not, so the app's navigation state is never rebuilt.
import 'package:flutter/material.dart';
import 'package:silarah/l10n/ui_copy.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../call_controller.dart';
import '../call_models.dart';
import '../screens/call_screen.dart';

class CallReturnBarHost extends StatelessWidget {
  const CallReturnBarHost({super.key, required this.onOpenCall, required this.child, this.controller});

  final VoidCallback onOpenCall;
  final Widget child;
  final CallController? controller;

  static bool showsFor(CallController call, {required bool screenOpen}) =>
      !screenOpen &&
      (call.phase == CallPhase.outgoing || call.phase == CallPhase.connecting || call.phase == CallPhase.active);

  @override
  Widget build(BuildContext context) {
    final call = controller ?? CallController.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([call, CallScreen.openCount]),
      builder: (context, _) {
        final visible = showsFor(call, screenOpen: CallScreen.isOpen);
        final topInset = MediaQuery.paddingOf(context).top;
        return Column(
          children: [
            AnimatedSize(
              duration: AppDimensions.durationTransition,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: visible
                  ? _Bar(call: call, topInset: topInset, onTap: onOpenCall)
                  : const SizedBox(width: double.infinity),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: visible,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.call, required this.topInset, required this.onTap});

  final CallController call;
  final double topInset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = call.phase == CallPhase.active && call.connectedAt != null;
    final status = active
        ? context.uiCopyWith('Tap to return to call · {time}', {'time': formatCallDuration(call.elapsedSeconds)})
        : context.uiCopy(call.phase == CallPhase.outgoing ? 'Calling… Tap to return' : 'Connecting… Tap to return');
    final color = AppColors.verifiedTeal;
    final onColor = AppColors.readableOn(color);
    return Semantics(
      button: true,
      liveRegion: false,
      label: '${call.otherName}, $status',
      child: Material(
        color: color,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimensions.space16,
              topInset + AppDimensions.space6,
              AppDimensions.space16,
              AppDimensions.space8,
            ),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Icon(Icons.call_rounded, size: 16, color: onColor),
                  const SizedBox(width: AppDimensions.space8),
                  Expanded(
                    child: UiText.verbatim(
                      call.otherName.isEmpty ? status : '${call.otherName} · $status',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(color: onColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (call.muted) Icon(Icons.mic_off_rounded, size: 16, color: onColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
