import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/features/pokemon/presentation/analytics/error_te_code.dart';

void main() {
  group('teCodeFor', () {
    test('maps every Failure subtype to its PRD TE code', () {
      expect(teCodeFor(const NetworkFailure()), 'TE-01');
      expect(teCodeFor(const CacheFailure()), 'TE-01');
      expect(teCodeFor(const NotFoundFailure()), 'TE-03');
      expect(teCodeFor(const TimeoutFailure()), 'TE-06');
      expect(teCodeFor(const ServerFailure()), 'TE-07');
      expect(teCodeFor(const RateLimitFailure()), 'TE-08');
      expect(teCodeFor(const ParsingFailure()), 'TE-09');
    });
  });

  group('teCodeForError', () {
    test('delegates to teCodeFor for a Failure', () {
      expect(teCodeForError(const TimeoutFailure()), 'TE-06');
    });

    test('falls back to TE-07 for a non-Failure error', () {
      expect(teCodeForError('boom'), 'TE-07');
      expect(teCodeForError(null), 'TE-07');
    });
  });
}
