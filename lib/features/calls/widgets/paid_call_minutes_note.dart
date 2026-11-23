// What happens to paid call minutes when a member pauses or deletes their
// account (docs/voice_calling_spec.md 6.6). Shown only when the member has
// paid minutes, whether or not calling is switched on: minutes bought
// before a switch-off are still theirs.
import 'package:flutter/material.dart';
import 'package:silarah/l10n/ui_copy.dart';

import '../call_api.dart';

enum PaidCallMinutesContext { deletion, pause }

class PaidCallMinutesNote extends StatefulWidget {
  const PaidCallMinutesNote({
    super.key,
    required this.kind,
    required this.builder,
    this.load,
  });

  final PaidCallMinutesContext kind;

  /// Draws the note around its text.
  final Widget Function(BuildContext context, String text) builder;

  /// Paid (pack) minutes; defaults to the member's wallet.
  final Future<int?> Function()? load;

  static String copyFor(PaidCallMinutesContext kind) => switch (kind) {
        PaidCallMinutesContext.deletion =>
          'You have {minutes} paid call minutes. They will be lost and cannot be refunded after deletion.',
        PaidCallMinutesContext.pause => 'Your {minutes} paid call minutes are kept while your profile is paused.',
      };

  @override
  State<PaidCallMinutesNote> createState() => _PaidCallMinutesNoteState();
}

class _PaidCallMinutesNoteState extends State<PaidCallMinutesNote> {
  late final Future<int?> _minutes =
      (widget.load ?? () async => (await CallApi.instance.wallet())?.packMinutes)();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: _minutes,
      builder: (context, snapshot) {
        final minutes = snapshot.data ?? 0;
        if (minutes <= 0) return const SizedBox.shrink();
        return widget.builder(
          context,
          context.uiCopyWith(PaidCallMinutesNote.copyFor(widget.kind), {'minutes': minutes}),
        );
      },
    );
  }
}
