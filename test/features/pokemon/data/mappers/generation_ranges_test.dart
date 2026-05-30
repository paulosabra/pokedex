import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/features/pokemon/data/mappers/generation_ranges.dart';

void main() {
  group('generationForId', () {
    test('maps each generation boundary correctly (RN-15)', () {
      expect(generationForId(1), 1);
      expect(generationForId(151), 1);
      expect(generationForId(152), 2);
      expect(generationForId(251), 2);
      expect(generationForId(252), 3);
      expect(generationForId(386), 3);
      expect(generationForId(387), 4);
      expect(generationForId(493), 4);
      expect(generationForId(494), 5);
      expect(generationForId(649), 5);
      expect(generationForId(650), 6);
      expect(generationForId(721), 6);
      expect(generationForId(722), 7);
      expect(generationForId(809), 7);
      expect(generationForId(810), 8);
      expect(generationForId(905), 8);
      expect(generationForId(906), 9);
      expect(generationForId(1025), 9);
    });

    test('out-of-range ids fall back to kUnknownGenerationId', () {
      expect(generationForId(0), kUnknownGenerationId);
      expect(generationForId(10000), kUnknownGenerationId);
      expect(kUnknownGenerationId, 0);
    });
  });
}
