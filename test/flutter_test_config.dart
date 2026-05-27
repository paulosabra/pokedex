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
/// this directory. It wraps the default [LocalFileComparator] with a tolerant
/// one so sub-pixel anti-aliasing noise no longer fails golden tests.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final defaultComparator = goldenFileComparator;
  if (defaultComparator is LocalFileComparator) {
    goldenFileComparator = _TolerantGoldenFileComparator(
      defaultComparator,
      tolerance: _kGoldenDiffTolerance,
    );
  }

  await testMain();
}

/// Delegates all golden I/O to the wrapped [LocalFileComparator] but accepts a
/// comparison whose pixel diff stays within [tolerance]. Anything above the
/// threshold is handed back to the inner comparator, which throws the standard
/// failure and writes the usual `failures/` diff artifacts.
class _TolerantGoldenFileComparator extends GoldenFileComparator {
  _TolerantGoldenFileComparator(this._inner, {required this.tolerance});

  final LocalFileComparator _inner;
  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await _inner.getGoldenBytes(golden),
    );

    if (result.passed || result.diffPercent <= tolerance) {
      return true;
    }

    // Over the tolerance: let the default comparator produce the canonical
    // error message and the usual `failures/` diff artifacts.
    return _inner.compare(imageBytes, golden);
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) =>
      _inner.update(golden, imageBytes);
}
