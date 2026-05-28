import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Maximum fraction of pixels that may differ before a golden is treated as a
/// mismatch.
///
/// Golden baselines are regenerated on Linux to match CI exactly (see
/// `.github/workflows/update-goldens.yml`) and the Flutter SDK is pinned in CI,
/// so a freshly baselined run diffs at ~0%. This small tolerance only absorbs
/// the residual sub-pixel anti-aliasing noise that can appear across host
/// platforms (e.g. local macOS vs. Linux CI) and SDK patch releases, so a
/// local run and CI agree without re-baselining on every machine.
///
/// Keep this low: a value too high would let real visual regressions slip
/// through. 1% is enough for anti-aliasing jitter but well below the footprint
/// of any meaningful layout or color change.
const double _kGoldenDiffTolerance = 0.01; // 1%

/// Entry point picked up automatically by `flutter_test` for every test under
/// this directory. It replaces the default zero-tolerance [LocalFileComparator]
/// with a tolerant subclass that keeps each test file's own `goldens/`
/// directory.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final defaultComparator = goldenFileComparator;
  if (defaultComparator is LocalFileComparator) {
    // `basedir` is @protected; reading it here is the only way to carry each
    // test file's own `goldens/` directory into the tolerant comparator.

    final goldensDir = defaultComparator.basedir;
    goldenFileComparator = _TolerantGoldenFileComparator(
      goldensDir,
      tolerance: _kGoldenDiffTolerance,
    );
  }

  await testMain();
}

/// A [LocalFileComparator] that passes when the pixel diff stays within the
/// configured tolerance. Anything above the threshold is deferred to the
/// default comparison, which throws the standard failure and writes the usual
/// `failures/` diff artifacts.
class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(super.testFile, {required this.tolerance});

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (result.passed || result.diffPercent <= tolerance) {
      return true;
    }

    return super.compare(imageBytes, golden);
  }
}
