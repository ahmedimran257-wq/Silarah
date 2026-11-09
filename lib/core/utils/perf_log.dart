// SILARAH — opt-in startup timing marks
//
// Build with --dart-define=SILARAH_PERF_LOG=true to print "[perf]" lines to
// logcat. Without the define, kPerfLog is a compile-time false and every call
// is removed from the release binary.
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

const bool kPerfLog = bool.fromEnvironment('SILARAH_PERF_LOG');

final Stopwatch _sinceStart = Stopwatch()..start();

/// Records [label] with milliseconds since the Dart isolate started.
void perfMark(String label) {
  if (!kPerfLog) return;
  // ignore: avoid_print
  print('[perf] ${_sinceStart.elapsedMilliseconds}ms $label');
}

/// Starts the clock at the very top of main() so marks share one origin.
void perfStart() {
  if (!kPerfLog) return;
  _sinceStart.reset();
  debugPrint('[perf] 0ms main');
}

/// Prints build and raster time histograms for each batch of frames, as
/// "[perf] frames b=<ms:count,...> r=<ms:count,...>".
void perfWatchFrames() {
  if (!kPerfLog) return;
  SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
    final build = <int, int>{};
    final raster = <int, int>{};
    for (final timing in timings) {
      final buildMs = timing.buildDuration.inMilliseconds;
      final rasterMs = timing.rasterDuration.inMilliseconds;
      build[buildMs] = (build[buildMs] ?? 0) + 1;
      raster[rasterMs] = (raster[rasterMs] ?? 0) + 1;
    }
    String encode(Map<int, int> bins) =>
        bins.entries.map((e) => '${e.key}:${e.value}').join(',');
    // ignore: avoid_print
    print('[perf] frames b=${encode(build)} r=${encode(raster)}');
  });
}
