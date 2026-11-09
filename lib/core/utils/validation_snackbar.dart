// SILARAH — Validation Snackbar Helper
// Shows a themed snackbar listing missing mandatory fields.
import 'package:flutter/material.dart';
import 'package:silarah/l10n/ui_copy.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

/// Shows a themed snackbar with a list of missing mandatory fields.
void showValidationSnackbar(BuildContext context, List<String> missingFields) {
  if (missingFields.isEmpty) return;

  final fields = missingFields.map(context.uiCopy).toList();
  final message = fields.length == 1
      ? context.uiCopyWith('Please fill in: {field}', {'field': fields.first})
      : '${context.uiCopy('Please fill in:')}\n• ${fields.join('\n• ')}';

  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded,
                color: AppColors.champagneGold, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTypography.body.copyWith(
                  color: AppColors.onSnackbar,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.snackbarSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          side: BorderSide(color: AppColors.goldBorder),
        ),
        duration: const Duration(seconds: 3),
        // Clears the onboarding Continue button and its padding.
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 104),
      ),
    );
}
