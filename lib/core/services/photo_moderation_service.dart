import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'operational_telemetry_service.dart';

enum PhotoModerationDecision { approved, flagged, rejected, scanFailed }

class PhotoModerationResult {
  const PhotoModerationResult({
    required this.decision,
    required this.confidence,
    required this.nsfwConfidence,
    required this.safeConfidence,
    required this.category,
    required this.threshold,
    this.personDetected = true,
    this.swimwearConfidence = 0,
    this.error,
  });

  final PhotoModerationDecision decision;
  final double confidence;
  final double nsfwConfidence;
  final double safeConfidence;
  final String category;
  final double threshold;

  /// False when neither a face nor clothing was found. Covered photos (niqab,
  /// burqa) can land here, so the picker asks the member instead of rejecting.
  final bool personDetected;

  /// ML Kit's "Swimwear" label confidence. OpenNSFW2 scores swimwear as
  /// safe (0.00-0.17 measured), so this is the signal that holds it.
  final double swimwearConfidence;
  final String? error;

  bool get isSafe => decision == PhotoModerationDecision.approved;
  bool get canUpload =>
      decision == PhotoModerationDecision.approved ||
      decision == PhotoModerationDecision.flagged;

  Map<String, dynamic> toValidationPayload() => {
        'policy_version': PhotoModerationService.policyVersion,
        'status': decision.name,
        'is_nsfw': category == 'explicit_content',
        // The upload function holds anything above 0.50 for staff review.
        // A swimwear hold must reach that queue even when nudity is low.
        'nsfw_confidence': decision == PhotoModerationDecision.flagged
            ? math.max(
                nsfwConfidence, PhotoModerationService.reviewThreshold + 0.01)
            : nsfwConfidence,
        'raw_nsfw_confidence': nsfwConfidence,
        'swimwear_confidence': swimwearConfidence,
        'requires_review': decision == PhotoModerationDecision.flagged,
        'person_detected': personDetected,
        'confidence': confidence,
        'safe_confidence': safeConfidence,
        'category': category,
        'threshold': threshold,
      };
}

@immutable
class NsfwScores {
  const NsfwScores({required this.safe, required this.nsfw});

  final double safe;
  final double nsfw;
}

typedef HumanPresenceScanner = Future<bool> Function(String path);
typedef NsfwScanner = Future<NsfwScores> Function(String path);
typedef SwimwearScanner = Future<double> Function(String path);

/// Runs profile-photo moderation completely on-device.
///
/// ML Kit faces or clothing signal a person; when neither is found the member
/// confirms the photo rather than being rejected, because covered photos
/// (niqab, burqa) and close portraits often carry no object label. A bundled,
/// compact OpenNSFW2 binary classifier is executed directly through LiteRT,
/// avoiding the release-only Flutter embedding defect in the old
/// `nsfw_detect` plugin.
/// Guided photo-badge capture remains a separate, human-reviewed workflow.
class PhotoModerationService {
  PhotoModerationService({
    HumanPresenceScanner? humanPresenceScanner,
    NsfwScanner? nsfwScanner,
    SwimwearScanner? swimwearScanner,
  })  : _humanPresenceScanner = humanPresenceScanner ?? _detectHumanPresence,
        _nsfwScanner = nsfwScanner ?? _runNsfw,
        _swimwearScanner = swimwearScanner ?? _detectSwimwear;

  static final PhotoModerationService instance = PhotoModerationService();

  static const int policyVersion = 5;

  /// Above this the photo is blocked on the device and never uploaded.
  static const double explicitContentBlockThreshold = 0.85;

  /// Above this (up to the block threshold) the photo is held for staff
  /// review instead of publishing. Mirrors finalize_profile_photo_upload.
  static const double reviewThreshold = 0.50;

  /// Swimwear label confidence that holds a photo for staff review. Measured
  /// 0.63-0.98 on swimwear and never present on hijab/niqab/burqa photos.
  /// Held, not blocked: a burkini is swimwear and a reviewer approves it.
  static const double swimwearReviewThreshold = 0.60;
  static const double confidenceThreshold = explicitContentBlockThreshold;
  static const String modelAssetPath = 'assets/models/opennsfw2_float16.tflite';
  static const String modelSource = 'bhky/opennsfw2';
  // Reproducible float16-weight build from tool/build_compact_nsfw_model.py.
  // Inputs and outputs remain float32 so Android/iOS call sites do not depend
  // on device-specific quantization parameters.
  static const int modelBytes = 11831128;
  static const String modelSha256 =
      'fc8379e668899303823b73abad9984d26e09eb94b29694d5ef7be433f1239cd9';

  static const int _inputSize = 224;
  static const int _resizeSize = 256;
  static const List<int> _expectedInputShape = [1, 224, 224, 3];
  static const List<int> _expectedOutputShape = [1, 2];
  static const int _safeIndex = 0;
  static const int _nsfwIndex = 1;

  static const Set<String> _humanLabelHints = {
    'person',
    'people',
    'human',
    'face',
    'portrait',
    'selfie',
    'crowd',
    'fashion',
    'fashion good',
    'clothing',
  };

  static Future<void>? _classifierReady;
  static Interpreter? _interpreter;
  static Future<void> _inferenceTail = Future<void>.value();

  final HumanPresenceScanner _humanPresenceScanner;
  final NsfwScanner _nsfwScanner;
  final SwimwearScanner _swimwearScanner;

  static Future<void> warmUp() => _ensureClassifierReady();

  Future<PhotoModerationResult> scanFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists() || await file.length() < 128) {
        return _invalidImage();
      }

      final hasHuman = await _humanPresenceScanner(path);
      final scores = await _nsfwScanner(path);
      // The swimwear signal is advisory; a labeler failure must not block a
      // member, and the nudity check above still applies.
      var swimwear = 0.0;
      try {
        swimwear = await _swimwearScanner(path);
      } catch (error) {
        debugPrint('[PhotoModerationService] swimwear label failed: $error');
      }
      return evaluateScores(
        scores,
        personDetected: hasHuman,
        swimwearConfidence: swimwear,
      );
    } on FormatException catch (error) {
      debugPrint('[PhotoModerationService] invalid image: $error');
      return _invalidImage();
    } catch (error, stackTrace) {
      debugPrint('[PhotoModerationService] scan failed: $error\n$stackTrace');
      // A device that cannot run the on-device scan blocks the photo step, the
      // last onboarding gate. Report a stable code (never the error text).
      OperationalTelemetryService.record('photo', 'moderation_scan_failed');
      return PhotoModerationResult(
        decision: PhotoModerationDecision.scanFailed,
        confidence: 0,
        nsfwConfidence: 0,
        safeConfidence: 0,
        category: 'scan_failed',
        threshold: explicitContentBlockThreshold,
        error: error.toString(),
      );
    }
  }

  static PhotoModerationResult evaluateScores(
    NsfwScores rawScores, {
    bool personDetected = true,
    double swimwearConfidence = 0,
  }) {
    final swimwear = swimwearConfidence.clamp(0.0, 1.0).toDouble();
    final nsfw = rawScores.nsfw.clamp(0.0, 1.0).toDouble();
    final safe = rawScores.safe.clamp(0.0, 1.0).toDouble();

    // Policy v4: explicit photos never leave the device; revealing ones are
    // held for review. Modest dress (hijab, niqab, burqa) scores near zero.
    if (nsfw > explicitContentBlockThreshold) {
      return PhotoModerationResult(
        decision: PhotoModerationDecision.rejected,
        confidence: nsfw,
        nsfwConfidence: nsfw,
        safeConfidence: safe,
        category: 'explicit_content',
        threshold: explicitContentBlockThreshold,
        personDetected: personDetected,
        swimwearConfidence: swimwear,
      );
    }
    if (nsfw > reviewThreshold) {
      return PhotoModerationResult(
        decision: PhotoModerationDecision.flagged,
        confidence: nsfw,
        nsfwConfidence: nsfw,
        safeConfidence: safe,
        category: 'needs_review',
        threshold: reviewThreshold,
        personDetected: personDetected,
        swimwearConfidence: swimwear,
      );
    }
    if (swimwear >= swimwearReviewThreshold) {
      return PhotoModerationResult(
        decision: PhotoModerationDecision.flagged,
        confidence: swimwear,
        nsfwConfidence: nsfw,
        safeConfidence: safe,
        category: 'swimwear_review',
        threshold: swimwearReviewThreshold,
        personDetected: personDetected,
        swimwearConfidence: swimwear,
      );
    }

    return PhotoModerationResult(
      decision: PhotoModerationDecision.approved,
      confidence: safe,
      nsfwConfidence: nsfw,
      safeConfidence: safe,
      category: 'safe_image',
      threshold: reviewThreshold,
      personDetected: personDetected,
      swimwearConfidence: swimwear,
    );
  }

  static PhotoModerationResult _invalidImage() => const PhotoModerationResult(
        decision: PhotoModerationDecision.rejected,
        confidence: 1,
        nsfwConfidence: 0,
        safeConfidence: 0,
        category: 'invalid_image',
        threshold: 0,
      );

  static Future<bool> _detectHumanPresence(String path) async {
    // The base object model has no "person" label: clothing reads as
    // "fashion good" and close portraits often get no label, so a face also
    // counts.
    if (await _hasClothingLabel(path)) return true;
    return _hasFace(path);
  }

  static Future<double> _detectSwimwear(String path) async {
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.3),
    );
    try {
      final labels = await labeler.processImage(InputImage.fromFilePath(path));
      return labels
          .where((label) => label.label.toLowerCase() == 'swimwear')
          .fold<double>(0, (best, label) => math.max(best, label.confidence));
    } finally {
      labeler.close();
    }
  }

  static Future<bool> _hasFace(String path) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.05,
      ),
    );
    try {
      final faces = await detector.processImage(InputImage.fromFilePath(path));
      return faces.isNotEmpty;
    } finally {
      detector.close();
    }
  }

  static Future<bool> _hasClothingLabel(String path) async {
    final detector = ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: true,
        multipleObjects: true,
      ),
    );

    try {
      final objects = await detector.processImage(
        InputImage.fromFilePath(path),
      );
      return objects.any(
        (object) => object.labels.any((label) {
          final normalized = label.text.trim().toLowerCase();
          return _humanLabelHints.any(
            (hint) => normalized == hint || normalized.contains(hint),
          );
        }),
      );
    } finally {
      detector.close();
    }
  }

  static Future<NsfwScores> _runNsfw(String path) async {
    final previousInference = _inferenceTail;
    final release = Completer<void>();
    _inferenceTail = release.future;
    await previousInference;

    try {
      Object? firstFailure;
      StackTrace? firstStackTrace;
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          return await _runNsfwOnce(path);
        } catch (error, stackTrace) {
          if (attempt > 0) rethrow;
          firstFailure = error;
          firstStackTrace = stackTrace;
          debugPrint(
            '[PhotoModerationService] classifier recovery: $error',
          );
          await _resetClassifier(refreshModelFile: true);
        }
      }
      Error.throwWithStackTrace(firstFailure!, firstStackTrace!);
    } finally {
      release.complete();
    }
  }

  static Future<NsfwScores> _runNsfwOnce(String path) async {
    await _ensureClassifierReady();
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('NSFW classifier was not initialized.');
    }

    final decoded = img.decodeImage(await File(path).readAsBytes());
    if (decoded == null) {
      throw const FormatException('The selected file is not a real image.');
    }
    final oriented = img.bakeOrientation(decoded);
    if (oriented.width < 32 || oriented.height < 32) {
      throw const FormatException('The selected image is too small.');
    }

    final resized = img.copyResize(
      oriented,
      width: _resizeSize,
      height: _resizeSize,
      interpolation: img.Interpolation.linear,
    );
    // Match the model's published Yahoo preprocessing: the 256px resize is
    // passed through JPEG once, centre-cropped to 224px, converted RGB→BGR,
    // then the training-set mean [104, 117, 123] is subtracted. Keeping this
    // contract exact prevents silent score drift between Python validation and
    // the shipped Dart inference path.
    final jpegRoundTrip = img.decodeJpg(img.encodeJpg(resized, quality: 75));
    if (jpegRoundTrip == null) {
      throw const FormatException('The selected file could not be normalized.');
    }
    final cropped = img.copyCrop(
      jpegRoundTrip,
      x: (_resizeSize - _inputSize) ~/ 2,
      y: (_resizeSize - _inputSize) ~/ 2,
      width: _inputSize,
      height: _inputSize,
    );
    final input = [
      List.generate(
        _inputSize,
        (y) => List.generate(
          _inputSize,
          (x) {
            final pixel = cropped.getPixel(x, y);
            return <double>[
              pixel.b.toDouble() - 104,
              pixel.g.toDouble() - 117,
              pixel.r.toDouble() - 123,
            ];
          },
          growable: false,
        ),
        growable: false,
      ),
    ];
    final output = [List<double>.filled(2, 0, growable: false)];
    interpreter.run(input, output);

    final probabilities = _normalizeOutput(output.single);
    return NsfwScores(
      safe: probabilities[_safeIndex],
      nsfw: probabilities[_nsfwIndex],
    );
  }

  static List<double> _normalizeOutput(List<double> values) {
    if (values.length != 2 || values.any((value) => !value.isFinite)) {
      throw StateError('NSFW classifier returned invalid values.');
    }
    final sum = values[0] + values[1];
    final alreadyProbabilities =
        values.every((value) => value >= 0 && value <= 1) &&
            (sum - 1).abs() <= 0.01;
    if (alreadyProbabilities) return values;

    final maxValue = values.reduce(math.max);
    final exponentials = values
        .map((value) => math.exp(value - maxValue))
        .toList(growable: false);
    final denominator = exponentials[0] + exponentials[1];
    if (!denominator.isFinite || denominator <= 0) {
      throw StateError('NSFW classifier returned invalid probabilities.');
    }
    return exponentials
        .map((value) => value / denominator)
        .toList(growable: false);
  }

  static Future<void> _ensureClassifierReady({bool refreshModelFile = false}) {
    final existing = _classifierReady;
    if (existing != null && !refreshModelFile) return existing;

    final initialization = () async {
      final modelFile = await _materializeModelFile(
        forceRefresh: refreshModelFile,
      );
      final options = InterpreterOptions()
        ..threads = math.min(4, math.max(1, Platform.numberOfProcessors));
      // Materializing once and loading from a file avoids retaining a second
      // model copy in the Dart heap.
      final interpreter = Interpreter.fromFile(
        modelFile,
        options: options,
      );
      final inputs = interpreter.getInputTensors();
      final outputs = interpreter.getOutputTensors();
      final inputShape = inputs.singleOrNull?.shape;
      final outputShape = outputs.singleOrNull?.shape;
      if (inputs.length != 1 ||
          outputs.length != 1 ||
          !listEquals(inputShape, _expectedInputShape) ||
          !listEquals(outputShape, _expectedOutputShape)) {
        interpreter.close();
        throw StateError(
          'Unexpected NSFW tensor contract: inputs=${inputs.length} '
          '$inputShape, outputs=${outputs.length} $outputShape.',
        );
      }
      _interpreter = interpreter;
    }();

    _classifierReady = initialization.catchError((Object error) {
      _classifierReady = null;
      _interpreter?.close();
      _interpreter = null;
      throw error;
    });
    return _classifierReady!;
  }

  static Future<void> _resetClassifier({
    required bool refreshModelFile,
  }) async {
    _interpreter?.close();
    _interpreter = null;
    _classifierReady = null;
    await _ensureClassifierReady(refreshModelFile: refreshModelFile);
  }

  static Future<File> _materializeModelFile({
    bool forceRefresh = false,
  }) async {
    final supportDirectory = await getApplicationSupportDirectory();
    final modelDirectory = Directory('${supportDirectory.path}/ml_models');
    final modelFile = File('${modelDirectory.path}/opennsfw2_float16.tflite');
    final integrityFile = File('${modelFile.path}.sha256');

    if (!forceRefresh &&
        await modelFile.exists() &&
        await modelFile.length() == modelBytes &&
        await integrityFile.exists() &&
        (await integrityFile.readAsString()).trim() == modelSha256) {
      return modelFile;
    }

    await modelDirectory.create(recursive: true);
    final asset = await rootBundle.load(modelAssetPath);
    final bytes = asset.buffer.asUint8List(
      asset.offsetInBytes,
      asset.lengthInBytes,
    );
    if (bytes.length != modelBytes ||
        sha256.convert(bytes).toString() != modelSha256) {
      throw StateError('Bundled NSFW model failed its integrity check.');
    }

    final temporaryFile = File('${modelFile.path}.writing');
    if (await temporaryFile.exists()) await temporaryFile.delete();
    await temporaryFile.writeAsBytes(bytes, flush: true);
    if (await modelFile.exists()) await modelFile.delete();
    await temporaryFile.rename(modelFile.path);
    await integrityFile.writeAsString(modelSha256, flush: true);
    return modelFile;
  }
}
