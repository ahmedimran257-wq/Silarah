// Full-screen call UI: outgoing ring, incoming ring, connecting, live call
// (minute meter, warnings, top-up without dropping, earpiece / speaker /
// Bluetooth, mute, report) and the ended state.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/profile_photo_service.dart';
import '../../../core/widgets/overlays/silarah_bottom_sheet.dart';
import '../../../core/widgets/overlays/silarah_dialog.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/loaders/silarah_blur_image.dart';
import '../../../features/home/widgets/report_bottom_sheet.dart';
import '../../../l10n/ui_copy.dart';
import '../call_controller.dart';
import '../call_models.dart';
import '../widgets/call_microphone_gate.dart';
import '../widgets/call_minutes_sheet.dart';

/// The call screen, shown by CallLayer above the whole app while
/// [CallController.screenShown]; it is never a page of the app's navigation.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key, this.controller, this.photoLoader});

  final CallController? controller;

  /// Photo URLs this member may see, by owner id (tests swap it).
  final Future<Map<String, String>> Function(List<String> ownerUserIds)? photoLoader;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final CallController _call = widget.controller ?? CallController.instance;
  bool _stillTalkingShown = false;

  @override
  void initState() {
    super.initState();
    _call.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadPhoto();
      _answerIfAsked();
    });
  }

  @override
  void dispose() {
    _call.removeListener(_changed);
    super.dispose();
  }

  String? get _otherUserId => _call.otherUserId;

  String? _loadedPhotoUrl;
  String? _photoLoadedFor;

  String? get _photoUrl {
    final given = _call.photoUrl;
    return given != null && given.isNotEmpty ? given : _loadedPhotoUrl;
  }

  /// The notification's Answer opened or reached this screen: answer once.
  void _answerIfAsked() {
    final id = _call.takeAnswerOnShow();
    if (id != null) unawaited(_answer(id));
  }

  /// Loads the other member's photo once their id is known.
  void _loadPhoto() {
    final given = _call.photoUrl;
    final id = _otherUserId;
    if ((given != null && given.isNotEmpty) || id == null || id.isEmpty || id == _photoLoadedFor) return;
    _photoLoadedFor = id;
    final load = widget.photoLoader ??
        (List<String> ids) => ProfilePhotoService.instance.getAuthorizedPhotoUrls(ownerUserIds: ids);
    unawaited(() async {
      try {
        final urls = await load([id]);
        final url = urls[id];
        if (mounted && _otherUserId == id && url != null && url.isNotEmpty) {
          setState(() => _loadedPhotoUrl = url);
        }
      } catch (_) {
        // No photo: the initial stays, as before.
      }
    }());
  }

  void _changed() {
    if (!mounted) return;
    _loadPhoto();
    _answerIfAsked();
    if (_call.warning == CallTimeWarning.stillTalking && _call.isCaller && !_stillTalkingShown) {
      _stillTalkingShown = true;
      unawaited(_askStillTalking());
    }
    if (_call.warning == CallTimeWarning.none) _stillTalkingShown = false;
    setState(() {});
  }

  Future<void> _answer(String requestId) async {
    final allowed = await ensureCallMicrophone(context);
    if (!mounted) return;
    if (!allowed) {
      await _call.decline();
      return;
    }
    await _call.answer(
      forRequestId: requestId,
      forMatchId: _call.incoming?.matchId,
      name: _call.incoming?.callerName,
    );
  }

  Future<void> _askStillTalking() async {
    final keep = await showSilarahDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: UiText('Still talking?', style: AppTypography.screenTitle),
        content: UiText('Your hour is almost up. Keep talking to use more of your minutes.',
            style: AppTypography.body.copyWith(color: AppColors.slateMist)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: UiText('End soon', style: AppTypography.button.copyWith(color: AppColors.slateMist)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: UiText('Keep talking', style: AppTypography.button.copyWith(color: AppColors.champagneGold)),
          ),
        ],
      ),
    );
    if (keep == true && mounted) await _extend();
  }

  Future<void> _extend() async {
    final outcome = await _call.extend();
    if (!mounted) return;
    if (outcome == 'extended') {
      _snack('Minutes added');
    } else if (outcome == 'no_minutes') {
      await _addMinutes();
    } else {
      _snack('Could not add minutes. Your call continues until the time runs out.');
    }
  }

  Future<void> _addMinutes() async {
    final bought = await showCallMinutesSheet(context, duringCall: true);
    if (bought && mounted) await _extend();
  }

  Future<void> _report() async {
    final userId = _otherUserId;
    if (userId == null) return;
    // Reporting ends the call on the server (spec 8).
    await ReportBottomSheet.show(context, reportedUserId: userId, reportedName: _call.otherName, fromCall: true);
  }

  Future<void> _chooseRoute() async {
    final chosen = await showSilarahBottomSheet<CallAudioRoute>(
      context: context,
      backgroundColor: AppColors.surfaceMid,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final route in [
              CallAudioRoute.earpiece,
              CallAudioRoute.speaker,
              CallAudioRoute.bluetooth,
              CallAudioRoute.wired,
            ])
              if (_call.availableRoutes.contains(route))
                ListTile(
                  leading: Icon(_routeIcon(route), color: AppColors.pearlWhite),
                  title: UiText.verbatim(_routeTitle(context, route), style: AppTypography.body),
                  trailing: route == _call.route ? Icon(Icons.check_rounded, color: AppColors.champagneGold) : null,
                  onTap: () => Navigator.of(sheetContext).pop(route),
                ),
          ],
        ),
      ),
    );
    if (chosen != null) await _call.setRoute(chosen);
  }

  void _snack(String copy) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: UiText(copy)),
    );
  }

  static IconData _routeIcon(CallAudioRoute route) => switch (route) {
        CallAudioRoute.earpiece => Icons.phone_in_talk_rounded,
        CallAudioRoute.speaker => Icons.volume_up_rounded,
        CallAudioRoute.bluetooth => Icons.bluetooth_audio_rounded,
        CallAudioRoute.wired => Icons.headphones_rounded,
      };

  /// "Bluetooth · Galaxy Buds": the headset's own name when Android gives it.
  String _routeTitle(BuildContext context, CallAudioRoute route) {
    final label = context.uiCopy(_routeLabel(route));
    final name =
        route == CallAudioRoute.bluetooth || route == CallAudioRoute.wired ? _call.routeNames[route]?.trim() : null;
    return name == null || name.isEmpty || name.toLowerCase() == label.toLowerCase() ? label : '$label · $name';
  }

  static String _routeLabel(CallAudioRoute route) => switch (route) {
        CallAudioRoute.earpiece => 'Phone',
        CallAudioRoute.speaker => 'Speaker',
        CallAudioRoute.bluetooth => 'Bluetooth',
        CallAudioRoute.wired => 'Headphones',
      };

  String _statusLine(BuildContext context) => switch (_call.phase) {
        CallPhase.outgoing => context.uiCopy('Ringing…'),
        CallPhase.incoming => context.uiCopy('Incoming call'),
        CallPhase.connecting => context.uiCopy('Connecting…'),
        CallPhase.active => _call.onHold
            ? context.uiCopy('On hold')
            : _call.reconnecting
                ? context.uiCopy('Reconnecting…')
                : formatCallDuration(_call.elapsedSeconds),
        CallPhase.ended => context.uiCopy(_call.endedCopy),
        CallPhase.idle => '',
      };

  String? _meter(BuildContext context) {
    if (_call.phase != CallPhase.active) return null;
    final minutes = _call.minutesLeftOfHold;
    // The last started minute is already charged, yet up to 59 s remain.
    if (minutes <= 0 && _call.warning != CallTimeWarning.none) return context.uiCopy('Less than a minute left');
    return switch (_call.warning) {
      CallTimeWarning.thirtySeconds => context.uiCopy('Less than a minute left'),
      CallTimeWarning.twoMinutes ||
      CallTimeWarning.stillTalking =>
        context.uiCopyWith('{minutes} min left', {'minutes': minutes}),
      CallTimeWarning.none => _call.isCaller ? context.uiCopyWith('{minutes} min left', {'minutes': minutes}) : null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final phase = _call.phase;
    final name = _call.otherName.isEmpty ? context.uiCopy('A Silarah member') : _call.otherName;
    final meter = _meter(context);
    final warn = _call.warning != CallTimeWarning.none;
    // Back never drops a call by accident; End does. Back is the call
    // layer's: a ring waits for Answer or Decline, a call goes on behind the
    // return bar (CallController.leaveCallScreen, spec 12.1).
    return Scaffold(
      backgroundColor: AppColors.obsidianDeep,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space24),
          child: Column(
            children: [
              const SizedBox(height: AppDimensions.space16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.slateMist),
                  const SizedBox(width: 6),
                  Flexible(
                    child: UiText(
                      'Calls are private. Silarah never records them.',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(color: AppColors.slateMist),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _Avatar(name: name, photoUrl: _photoUrl, live: phase == CallPhase.active),
              const SizedBox(height: AppDimensions.space24),
              UiText.verbatim(name, textAlign: TextAlign.center, style: AppTypography.userName, maxLines: 2),
              const SizedBox(height: AppDimensions.space8),
              Semantics(
                liveRegion: true,
                child: UiText.verbatim(_statusLine(context),
                    textAlign: TextAlign.center, style: AppTypography.body.copyWith(color: AppColors.slateMist)),
              ),
              if (meter != null) ...[
                const SizedBox(height: AppDimensions.space12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: warn ? AppColors.expiryAmber.withValues(alpha: .16) : AppColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: warn ? AppColors.expiryAmber : AppColors.cardBorder),
                  ),
                  child: UiText.verbatim(meter,
                      style:
                          AppTypography.caption.copyWith(color: warn ? AppColors.expiryAmber : AppColors.pearlWhite)),
                ),
              ],
              if (_call.onHold) ...[
                const SizedBox(height: AppDimensions.space12),
                UiText('Another call is using your phone. Your microphone is off until it ends.',
                    textAlign: TextAlign.center, style: AppTypography.caption.copyWith(color: AppColors.expiryAmber)),
              ],
              const Spacer(),
              if (phase == CallPhase.active || phase == CallPhase.connecting)
                _LiveControls(
                  muted: _call.muted,
                  route: _call.route,
                  routeLabel: _routeLabel(_call.route),
                  routeIcon: _routeIcon(_call.route),
                  canAddMinutes: _call.isCaller && phase == CallPhase.active,
                  canReport: _otherUserId != null,
                  extending: _call.extending,
                  onMute: _call.toggleMute,
                  onRoute: _chooseRoute,
                  onAddMinutes: _addMinutes,
                  onReport: _report,
                ),
              const SizedBox(height: AppDimensions.space32),
              if (phase == CallPhase.incoming)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RoundAction(
                      icon: Icons.call_end_rounded,
                      label: 'Decline',
                      color: AppColors.softCoral,
                      onTap: _call.decline,
                    ),
                    _RoundAction(
                      icon: Icons.call_rounded,
                      label: 'Answer',
                      color: AppColors.verifiedTeal,
                      onTap: () => _answer(_call.requestId!),
                    ),
                  ],
                )
              else if (phase != CallPhase.ended)
                _RoundAction(
                  icon: Icons.call_end_rounded,
                  label: phase == CallPhase.outgoing ? 'Cancel' : 'End call',
                  color: AppColors.softCoral,
                  onTap: () => _call.hangUp(),
                ),
              const SizedBox(height: AppDimensions.space32),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.photoUrl, required this.live});
  final String name;
  final String? photoUrl;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceGlassHover,
        border: Border.all(color: live ? AppColors.verifiedTeal : AppColors.goldBorder, width: 2),
        boxShadow: [BoxShadow(color: AppColors.goldGlow, blurRadius: 32)],
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl == null || photoUrl!.isEmpty
          ? Center(child: UiText.verbatim(initial, style: AppTypography.wordmark))
          : SilarahBlurImage(imageUrl: photoUrl!, width: 132, height: 132),
    );
  }
}

class _LiveControls extends StatelessWidget {
  const _LiveControls({
    required this.muted,
    required this.route,
    required this.routeLabel,
    required this.routeIcon,
    required this.canAddMinutes,
    required this.canReport,
    required this.extending,
    required this.onMute,
    required this.onRoute,
    required this.onAddMinutes,
    required this.onReport,
  });

  final bool muted;
  final CallAudioRoute route;
  final String routeLabel;
  final IconData routeIcon;
  final bool canAddMinutes;
  final bool canReport;
  final bool extending;
  final VoidCallback onMute;
  final VoidCallback onRoute;
  final VoidCallback onAddMinutes;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppDimensions.space16,
      runSpacing: AppDimensions.space16,
      children: [
        _SmallAction(
          icon: muted ? Icons.mic_off_rounded : Icons.mic_none_rounded,
          label: muted ? 'Unmute' : 'Mute',
          active: muted,
          onTap: onMute,
        ),
        _SmallAction(icon: routeIcon, label: routeLabel, active: route != CallAudioRoute.earpiece, onTap: onRoute),
        if (canAddMinutes)
          _SmallAction(
            icon: Icons.add_alarm_rounded,
            label: 'Add minutes',
            active: false,
            busy: extending,
            onTap: onAddMinutes,
          ),
        if (canReport) _SmallAction(icon: Icons.flag_outlined, label: 'Report', active: false, onTap: onReport),
      ],
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.busy = false,
  });
  final IconData icon;
  final String label;
  final bool active;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.uiCopy(label),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(40),
        child: SizedBox(
          width: 76,
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? AppColors.pearlWhite : AppColors.surfaceGlass,
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: busy
                    ? Padding(
                        padding: const EdgeInsets.all(18),
                        child: SilarahActivityIndicator(size: 22, color: AppColors.champagneGold),
                      )
                    : Icon(icon, color: active ? AppColors.obsidianDeep : AppColors.pearlWhite),
              ),
              const SizedBox(height: 6),
              ExcludeSemantics(
                child: UiText(label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: AppTypography.caption.copyWith(color: AppColors.slateMist)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.uiCopy(label),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: color,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 72,
                height: 72,
                child: Icon(icon, color: AppColors.readableOn(color), size: 32),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: UiText(label, style: AppTypography.caption.copyWith(color: AppColors.slateMist)),
          ),
        ],
      ),
    );
  }
}
