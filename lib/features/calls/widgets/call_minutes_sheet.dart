// Call minutes and packs (spec 2, 3, 6). Premium members only can buy.
// Minutes are added by the server from the RevenueCat webhook, never here:
// after a purchase the sheet waits for the balance to change.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/services/subscription_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/overlays/silarah_bottom_sheet.dart';
import '../../../l10n/ui_copy.dart';
import '../../home/screens/legal_doc_screen.dart';
import '../../home/screens/paywall_gate_screen.dart';
import '../call_api.dart';
import '../call_models.dart';
import '../call_pack_pending.dart';
import '../calls_hub.dart';
import 'calling_guide_sheet.dart';
import 'calls_tab_widgets.dart';

/// Minutes go to the member the store account belongs to. A pack is bought
/// only when the store already knows this member, so a paid pack can never
/// land on an anonymous store ID (docs/voice_calling_spec.md 6.3).
Future<bool> callPackBuyerConfirmed(String? memberId, Future<String> Function() storeUserId) async {
  if (memberId == null || memberId.isEmpty) return false;
  try {
    return await storeUserId() == memberId;
  } catch (_) {
    return false;
  }
}

/// Returns true when minutes were added during the sheet.
Future<bool> showCallMinutesSheet(BuildContext context, {bool duringCall = false}) async {
  final result = await showSilarahBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CallMinutesSheet(duringCall: duringCall),
  );
  return result ?? false;
}

class _CallMinutesSheet extends StatefulWidget {
  const _CallMinutesSheet({required this.duringCall});
  final bool duringCall;

  @override
  State<_CallMinutesSheet> createState() => _CallMinutesSheetState();
}

/// Where a pack purchase is, shown live at the top of the sheet (like Play's
/// own order status): never a silent spinner or a line at the bottom.
enum PackBuyStage { idle, opening, confirming, added, pending, slow, failed, accountNotReady }

class _CallMinutesSheetState extends State<_CallMinutesSheet> {
  CallWallet? _wallet;
  Map<String, StoreProduct> _products = const {};
  bool _loading = true;
  String? _buying;
  PackBuyStage _stage = PackBuyStage.idle;
  int _stageMinutes = 0;
  CallPack? _retryPack;
  bool _watchingPending = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _watchingPending = false;
    super.dispose();
  }

  /// A payment still pending from earlier (UPI, slow card): show it, and
  /// keep checking while the sheet is open so it flips to "added" live.
  Future<void> _resumePending(CallWallet wallet) async {
    await CallPackPending.instance.load();
    final pending = CallPackPending.instance.current.value;
    if (pending == null || !mounted) return;
    if (await CallPackPending.instance.settleWith(wallet.packMinutes)) return;
    setState(() {
      _stage = PackBuyStage.pending;
      _stageMinutes = pending.minutes;
    });
    if (_watchingPending) return;
    _watchingPending = true;
    while (mounted && _watchingPending && _stage == PackBuyStage.pending) {
      await Future<void>.delayed(const Duration(seconds: 5));
      if (!mounted || _stage != PackBuyStage.pending) break;
      final now = await CallApi.instance.wallet();
      if (!mounted || now == null) continue;
      if (await CallPackPending.instance.settleWith(now.packMinutes)) {
        HapticFeedback.mediumImpact();
        setState(() {
          _wallet = now;
          _stage = PackBuyStage.added;
        });
      }
    }
    _watchingPending = false;
  }

  Future<void> _load() async {
    final wallet = await CallApi.instance.wallet();
    Map<String, StoreProduct> products = const {};
    if (wallet != null && wallet.canBuyPacks && wallet.packs.isNotEmpty) {
      try {
        final list = await Purchases.getProducts(
          wallet.packs.map((pack) => pack.productId).toList(),
          productCategory: ProductCategory.nonSubscription,
        );
        products = {for (final product in list) product.identifier.split(':').first: product};
      } catch (error) {
        debugPrint('[CallMinutesSheet] store products unavailable: $error');
      }
    }
    if (!mounted) return;
    setState(() {
      _wallet = wallet;
      _products = products;
      _loading = false;
    });
    if (wallet != null && wallet.premium) unawaited(_resumePending(wallet));
  }

  Future<void> _buy(CallPack pack) async {
    final product = _products[pack.productId];
    if (product == null || _buying != null) return;
    final before = _wallet?.packMinutes ?? 0;
    setState(() {
      _buying = pack.productId;
      _stage = PackBuyStage.opening;
      _stageMinutes = pack.minutes;
      _retryPack = null;
    });
    if (!await callPackBuyerConfirmed(SupabaseService.currentUserId, () => Purchases.appUserID)) {
      if (!mounted) return;
      setState(() {
        _buying = null;
        _stage = PackBuyStage.accountNotReady;
        _retryPack = pack;
      });
      return;
    }
    try {
      await Purchases.purchase(PurchaseParams.storeProduct(product));
    } on PlatformException catch (error) {
      final code = storeErrorCode(error);
      if (!mounted) return;
      if (code == PurchasesErrorCode.paymentPendingError) {
        // UPI and other delayed payments: Play charges once, later.
        await CallPackPending.instance.save(pack.minutes, before);
      }
      if (!mounted) return;
      setState(() {
        _buying = null;
        switch (code) {
          case PurchasesErrorCode.purchaseCancelledError:
            _stage = PackBuyStage.idle;
          case PurchasesErrorCode.paymentPendingError:
            _stage = PackBuyStage.pending;
          default:
            _stage = PackBuyStage.failed;
            _retryPack = pack;
        }
      });
      if (_stage == PackBuyStage.pending && _wallet != null) unawaited(_resumePending(_wallet!));
      return;
    }
    // Play charged; the server adds the minutes when RevenueCat tells it
    // (usually seconds). Wait for the balance to move.
    if (!mounted) return;
    setState(() => _stage = PackBuyStage.confirming);
    for (var attempt = 0; attempt < 20 && mounted; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 3));
      final wallet = await CallApi.instance.wallet();
      if (!mounted) return;
      if (wallet != null && wallet.packMinutes > before) {
        HapticFeedback.mediumImpact();
        await CallPackPending.instance.settleWith(wallet.packMinutes);
        if (!mounted) return;
        setState(() {
          _wallet = wallet;
          _buying = null;
          _stage = PackBuyStage.added;
        });
        if (widget.duringCall) Navigator.of(context).pop(true);
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _buying = null;
      _stage = PackBuyStage.slow;
    });
  }

  String? _termsDetail(BuildContext context, CallWallet wallet) {
    final lines = callMinutesTermLines(
        context, wallet.terms, DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()));
    return lines.isEmpty ? null : lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _wallet;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {},
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceMid,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.goldBorder)),
        ),
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.of(context).viewPadding.bottom),
        child: _loading
            ? const SizedBox(height: 160, child: Center(child: SilarahPulseLoader()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: AppDimensions.minTouchTarget),
                      Expanded(
                        child: UiText('Call minutes',
                            style: AppTypography.screenTitle, textAlign: TextAlign.center),
                      ),
                      const CallingGuideButton(),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space16),
                  if (wallet == null)
                    UiText('Minutes could not be loaded. Check your connection and try again.',
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(color: AppColors.slateMist))
                  else if (!wallet.premium) ...[
                    UiText.verbatim(
                        context.uiCopyWith('Calls are part of Premium. Premium includes {included} call minutes every month.',
                            {'included': CallsHub.instance.rules.value?.includedMinutes ?? 0}),
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(color: AppColors.slateMist)),
                    if (wallet.terms.packsSavedWhileLapsed) ...[
                      const SizedBox(height: AppDimensions.space8),
                      UiText.verbatim(
                          context.uiCopyWith('Your {minutes} pack minutes are saved. Renew Premium to use them.',
                              {'minutes': wallet.packMinutes}),
                          textAlign: TextAlign.center,
                          style: AppTypography.body.copyWith(color: AppColors.champagneGold)),
                    ],
                    const SizedBox(height: AppDimensions.space16),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                        PaywallGateSheet.show(context, gate: PremiumGate.calls);
                      },
                      child: const UiText('See Premium'),
                    ),
                  ] else ...[
                    PackBuyStatus(
                      stage: _stage,
                      minutes: _stageMinutes,
                      onRetry: _retryPack == null ? null : () => _buy(_retryPack!),
                    ),
                    _BalanceRow(
                      label: 'Included with Premium',
                      value: context.uiCopyWith('{minutes} min', {'minutes': wallet.includedMinutes}),
                      detail: _termsDetail(context, wallet),
                    ),
                    _BalanceRow(
                      label: 'Pack minutes',
                      value: context.uiCopyWith('{minutes} min', {'minutes': wallet.packMinutes}),
                      detail: context.uiCopy('Pack minutes never expire. They work while you have Premium.'),
                      warn: wallet.negative,
                      highlight: _stage == PackBuyStage.added,
                    ),
                    if (wallet.negative)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppDimensions.space8),
                        child: UiText(
                          'Your pack balance is below zero because Google Play refunded a pack. Add minutes to call again.',
                          style: AppTypography.caption.copyWith(color: AppColors.expiryAmber),
                        ),
                      ),
                    const SizedBox(height: AppDimensions.space8),
                    if (wallet.canBuyPacks)
                      for (final pack in wallet.packs)
                        _PackTile(
                          minutes: pack.minutes,
                          price: _products[pack.productId]?.priceString,
                          busy: _buying == pack.productId,
                          enabled: _buying == null && _products[pack.productId] != null,
                          onTap: () => _buy(pack),
                        ),
                    const SizedBox(height: AppDimensions.space8),
                    UiText("Only the caller's minutes are used, per started minute. Answering never uses minutes.",
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(color: AppColors.slateMist)),
                    // Shown before purchase (Consumer Protection E-Commerce
                    // Rules): packs are non-refundable, with the policy a tap away.
                    if (wallet.canBuyPacks) ...[
                      const SizedBox(height: AppDimensions.space4),
                      UiText('Minute packs are non-refundable, except as set out in the Refund Policy.',
                          textAlign: TextAlign.center,
                          style: AppTypography.caption.copyWith(color: AppColors.slateMist)),
                      Center(
                        child: TextButton(
                          key: const ValueKey('call-packs-refund-policy'),
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const LegalDocScreen(type: 'refund-policy'))),
                          child: const UiText('Refund Policy'),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.label, required this.value, this.detail, this.warn = false, this.highlight = false});
  final String label;
  final String value;
  final String? detail;
  final bool warn;

  /// Minutes just added: the number turns green.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(label, style: AppTypography.bodyMedium),
                if (detail != null)
                  UiText.verbatim(detail!, style: AppTypography.caption.copyWith(color: AppColors.slateMist)),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: AppDimensions.durationReveal,
            child: UiText.verbatim(value,
                key: ValueKey(value),
                style: AppTypography.bodyMedium.copyWith(
                    color: warn
                        ? AppColors.expiryAmber
                        : highlight
                            ? AppColors.verifiedTeal
                            : AppColors.champagneGold)),
          ),
        ],
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  const _PackTile({
    required this.minutes,
    required this.price,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });
  final int minutes;
  final String? price;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space8),
      child: AnimatedOpacity(
        duration: AppDimensions.durationReveal,
        opacity: enabled || busy ? 1 : 0.45,
        child: Material(
        color: AppColors.surfaceGlass,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.call_rounded, color: AppColors.champagneGold, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: UiText.verbatim(
                      context.uiCopyWith('{minutes} minutes', {'minutes': minutes}),
                      style: AppTypography.bodyMedium),
                ),
                if (busy)
                  const SilarahActivityIndicator(size: 18)
                else
                  UiText.verbatim(price ?? '—',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.champagneGold)),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// The live purchase status at the top of the minutes sheet.
class PackBuyStatus extends StatelessWidget {
  const PackBuyStatus({super.key, required this.stage, required this.minutes, this.onRetry});
  final PackBuyStage stage;
  final int minutes;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final values = {'minutes': minutes};
    final (String? text, Color color, Widget? lead) = switch (stage) {
      PackBuyStage.idle => (null, AppColors.slateMist, null),
      PackBuyStage.opening =>
        (context.uiCopy('Opening Google Play…'), AppColors.champagneGold, const SilarahActivityIndicator(size: 18)),
      PackBuyStage.confirming => (
          context.uiCopyWith('Payment received · adding {minutes} minutes…', values),
          AppColors.champagneGold,
          const SilarahActivityIndicator(size: 18)
        ),
      PackBuyStage.added => (
          context.uiCopyWith('{minutes} minutes added', values),
          AppColors.verifiedTeal,
          Icon(Icons.check_circle_rounded, color: AppColors.verifiedTeal, size: 20)
        ),
      PackBuyStage.pending => (
          context.uiCopyWith(
              'Payment pending. Your {minutes} minutes are added automatically when Google Play confirms it.', values),
          AppColors.expiryAmber,
          Icon(Icons.hourglass_top_rounded, color: AppColors.expiryAmber, size: 20)
        ),
      PackBuyStage.slow => (
          context.uiCopy('Your minutes are on their way. They will appear shortly; you will not be charged again.'),
          AppColors.expiryAmber,
          Icon(Icons.schedule_rounded, color: AppColors.expiryAmber, size: 20)
        ),
      PackBuyStage.failed => (
          context.uiCopy("Payment didn't go through. You weren't charged."),
          AppColors.softCoral,
          Icon(Icons.error_outline_rounded, color: AppColors.softCoral, size: 20)
        ),
      PackBuyStage.accountNotReady => (
          context.uiCopy(
              "We couldn't confirm your account with Google Play yet. Please try again in a moment. You were not charged."),
          AppColors.softCoral,
          Icon(Icons.error_outline_rounded, color: AppColors.softCoral, size: 20)
        ),
    };
    final retry = onRetry != null && (stage == PackBuyStage.failed || stage == PackBuyStage.accountNotReady);
    return AnimatedSize(
      duration: AppDimensions.durationReveal,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: AppDimensions.durationReveal,
        child: text == null
            ? const SizedBox(width: double.infinity, key: ValueKey('pack-status-idle'))
            : Container(
                key: ValueKey('pack-status-${stage.name}'),
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppDimensions.space16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  border: Border.all(color: color.withValues(alpha: 0.45)),
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Row(
                    children: [
                      if (lead != null) ...[lead, const SizedBox(width: 12)],
                      Expanded(
                        child: UiText.verbatim(text, style: AppTypography.bodyMedium.copyWith(color: color)),
                      ),
                      if (retry)
                        TextButton(
                          key: const ValueKey('pack-status-retry'),
                          onPressed: onRetry,
                          child: UiText(context.uiCopy('Try again')),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

