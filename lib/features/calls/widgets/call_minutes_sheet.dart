// Call minutes and packs (spec 2, 3, 6). Premium members only can buy.
// Minutes are added by the server from the RevenueCat webhook, never here:
// after a purchase the sheet waits for the balance to change.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/overlays/silarah_bottom_sheet.dart';
import '../../../l10n/ui_copy.dart';
import '../../home/screens/paywall_gate_screen.dart';
import '../call_api.dart';
import '../call_models.dart';
import '../calls_hub.dart';
import 'calling_guide_sheet.dart';

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

class _CallMinutesSheetState extends State<_CallMinutesSheet> {
  CallWallet? _wallet;
  Map<String, StoreProduct> _products = const {};
  bool _loading = true;
  String? _buying;
  bool _added = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
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
  }

  Future<void> _buy(CallPack pack) async {
    final product = _products[pack.productId];
    if (product == null || _buying != null) return;
    final before = _wallet?.packMinutes ?? 0;
    setState(() {
      _buying = pack.productId;
      _notice = null;
    });
    try {
      await Purchases.purchase(PurchaseParams.storeProduct(product));
    } on PlatformException catch (error) {
      final code = PurchasesErrorHelper.getErrorCode(error);
      if (!mounted) return;
      setState(() {
        _buying = null;
        _notice = code == PurchasesErrorCode.purchaseCancelledError
            ? null
            : 'The purchase could not be completed. You were not charged twice.';
      });
      return;
    }
    // Play charged; the server adds the minutes when RevenueCat tells it
    // (usually seconds). Wait for the balance to move.
    if (!mounted) return;
    setState(() => _notice = 'Payment received. Your minutes will appear in a few seconds.');
    for (var attempt = 0; attempt < 20 && mounted; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 3));
      final wallet = await CallApi.instance.wallet();
      if (!mounted) return;
      if (wallet != null && wallet.packMinutes > before) {
        setState(() {
          _wallet = wallet;
          _added = true;
          _buying = null;
          _notice = null;
        });
        if (widget.duringCall) Navigator.of(context).pop(true);
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _buying = null;
      _notice = 'Your minutes are on their way. They will appear shortly; you will not be charged again.';
    });
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
                    const SizedBox(height: AppDimensions.space16),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                        PaywallGateSheet.show(context, gate: PremiumGate.calls);
                      },
                      child: const UiText('See Premium'),
                    ),
                  ] else ...[
                    _BalanceRow(
                      label: 'Included with Premium',
                      value: context.uiCopyWith('{minutes} min', {'minutes': wallet.includedMinutes}),
                      detail: wallet.includedPeriodEnd == null
                          ? null
                          : context.uiCopyWith('Renews {date}', {
                              'date': DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
                                  .format(wallet.includedPeriodEnd!.toLocal()),
                            }),
                    ),
                    _BalanceRow(
                      label: 'Pack minutes',
                      value: context.uiCopyWith('{minutes} min', {'minutes': wallet.packMinutes}),
                      detail: context.uiCopy('Pack minutes never expire.'),
                      warn: wallet.negative,
                    ),
                    if (wallet.negative)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppDimensions.space8),
                        child: UiText(
                          'Your pack balance is below zero after a refund. Add minutes to call again.',
                          style: AppTypography.caption.copyWith(color: AppColors.expiryAmber),
                        ),
                      ),
                    if (_added)
                      UiText('Minutes added',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.verifiedTeal)),
                    const SizedBox(height: AppDimensions.space8),
                    if (!wallet.canBuyPacks)
                      // A Premium member who cannot buy: the refund limit.
                      UiText.verbatim(
                          context.uiCopyWith(
                              'After {refunds} refunded packs, minute packs can no longer be bought on this account. Your included minutes still work.',
                              {'refunds': CallsHub.instance.rules.value?.maxPackRefunds ?? 0}),
                          textAlign: TextAlign.center,
                          style: AppTypography.caption.copyWith(color: AppColors.slateMist))
                    else
                      for (final pack in wallet.packs)
                        _PackTile(
                          minutes: pack.minutes,
                          price: _products[pack.productId]?.priceString,
                          busy: _buying == pack.productId,
                          enabled: _buying == null && _products[pack.productId] != null,
                          onTap: () => _buy(pack),
                        ),
                    const SizedBox(height: AppDimensions.space8),
                    UiText("Calls need an active Premium plan. Only the caller's minutes are used; answering is always free.",
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(color: AppColors.slateMist)),
                  ],
                  if (_notice != null) ...[
                    const SizedBox(height: AppDimensions.space12),
                    UiText(_notice!,
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(color: AppColors.champagneGold)),
                  ],
                ],
              ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.label, required this.value, this.detail, this.warn = false});
  final String label;
  final String value;
  final String? detail;
  final bool warn;

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
          UiText.verbatim(value,
              style: AppTypography.bodyMedium.copyWith(
                  color: warn ? AppColors.expiryAmber : AppColors.champagneGold)),
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
    );
  }
}
