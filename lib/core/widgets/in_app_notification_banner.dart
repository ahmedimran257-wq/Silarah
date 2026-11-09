import 'package:silarah/l10n/ui_copy.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../cubits/notifications/notifications_cubit.dart';
import '../theme/app_colors.dart';
import '../theme/app_curves.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';
import 'buttons/silarah_pressable.dart';

class InAppNotificationBannerHost extends StatefulWidget {
  const InAppNotificationBannerHost({
    super.key,
    required this.child,
    required this.notifications,
    required this.onTap,
  });

  final Widget child;
  final Stream<NotificationItem> notifications;
  final ValueChanged<NotificationItem> onTap;

  @override
  State<InAppNotificationBannerHost> createState() =>
      _InAppNotificationBannerHostState();
}

class _InAppNotificationBannerHostState
    extends State<InAppNotificationBannerHost> {
  StreamSubscription<NotificationItem>? _subscription;
  Timer? _dismissTimer;
  NotificationItem? _item;
  bool _visible = false;
  int _presentation = 0;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant InAppNotificationBannerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notifications != widget.notifications) _listen();
  }

  void _listen() {
    _subscription?.cancel();
    _subscription = widget.notifications.listen(_show);
  }

  void _show(NotificationItem item) {
    final presentation = ++_presentation;
    _dismissTimer?.cancel();
    setState(() {
      _item = item;
      _visible = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || presentation != _presentation) return;
      setState(() => _visible = true);
    });
    _dismissTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    if (!mounted || _item == null) return;
    final presentation = ++_presentation;
    _dismissTimer?.cancel();
    setState(() => _visible = false);
    final exitDelay = MediaQuery.maybeOf(context)?.disableAnimations ?? false
        ? Duration.zero
        : AppDimensions.durationDialogExit;
    Timer(exitDelay, () {
      if (!mounted || presentation != _presentation) return;
      setState(() => _item = null);
    });
  }

  void _dismissImmediately() {
    _presentation++;
    _dismissTimer?.cancel();
    if (mounted) {
      setState(() {
        _visible = false;
        _item = null;
      });
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Stack(
      children: [
        widget.child,
        if (item != null)
          Positioned(
            top: 0,
            left: AppDimensions.space12,
            right: AppDimensions.space12,
            // The host sits above the navigator, outside any Material, so
            // without this the banner text renders with debug underlines.
            child: Material(
              type: MaterialType.transparency,
              child: SafeArea(
                bottom: false,
                child: AnimatedSlide(
                  duration: reduceMotion
                      ? Duration.zero
                      : AppDimensions.durationReveal,
                  curve: AppCurves.reveal,
                  offset: _visible ? Offset.zero : const Offset(0, -.16),
                  child: AnimatedOpacity(
                    duration: reduceMotion
                        ? Duration.zero
                        : AppDimensions.durationTransition,
                    curve: AppCurves.transition,
                    opacity: _visible ? 1 : 0,
                    child: Dismissible(
                      key: ValueKey('in_app_notification_${item.id}'),
                      direction: DismissDirection.horizontal,
                      onDismissed: (_) => _dismissImmediately(),
                      child: SilarahPressable(
                        haptic: false,
                        semanticLabel: item.title,
                        onTap: () {
                          _dismiss();
                          widget.onTap(item);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha:
                                      AppColors.active.mode.isDark ? .4 : .14,
                                ),
                                blurRadius: 26,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              PositionedDirectional(
                                start: 0,
                                top: 10,
                                bottom: 10,
                                child: Container(
                                  width: 2,
                                  decoration: BoxDecoration(
                                    color: AppColors.champagneGold,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 8, 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: AppColors.goldGlow,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.goldBorder,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.notifications_none_rounded,
                                        color: AppColors.champagneGold,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(
                                      width: AppDimensions.space12,
                                    ),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          UiText(
                                            item.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.bodyMedium,
                                          ),
                                          const SizedBox(
                                            height: AppDimensions.space4,
                                          ),
                                          UiText(
                                            item.body,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.caption,
                                          ),
                                        ],
                                      ),
                                    ),
                                    _CatalogButtonSemantics(
                                      label: 'Dismiss notification',
                                      child: IconButton(
                                        onPressed: _dismiss,
                                        icon: Icon(
                                          Icons.close_rounded,
                                          color: AppColors.slateMist,
                                          size: 19,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Announces [child] as a button, with [label] read from the copy catalog.
class _CatalogButtonSemantics extends StatelessWidget {
  const _CatalogButtonSemantics({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.uiCopy(label),
        button: true,
        child: child,
      );
}
