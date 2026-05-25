import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/network/error_mapper.dart';

void main() {
  final requestOptions = RequestOptions(path: '/pokemon');

  DioException dioError(DioExceptionType type, {int? statusCode}) =>
      DioException(
        requestOptions: requestOptions,
        type: type,
        response: statusCode == null
            ? null
            : Response<dynamic>(
                requestOptions: requestOptions,
                statusCode: statusCode,
              ),
      );

  group('mapError', () {
    test('connectionError maps to NetworkFailure', () {
      expect(
        mapError(dioError(DioExceptionType.connectionError)),
        isA<NetworkFailure>(),
      );
    });

    test('all three timeout types map to TimeoutFailure', () {
      expect(
        mapError(dioError(DioExceptionType.connectionTimeout)),
        isA<TimeoutFailure>(),
      );
      expect(
        mapError(dioError(DioExceptionType.sendTimeout)),
        isA<TimeoutFailure>(),
      );
      expect(
        mapError(dioError(DioExceptionType.receiveTimeout)),
        isA<TimeoutFailure>(),
      );
    });

    group('badResponse', () {
      test('404 maps to NotFoundFailure', () {
        expect(
          mapError(dioError(DioExceptionType.badResponse, statusCode: 404)),
          isA<NotFoundFailure>(),
        );
      });

      test('429 maps to RateLimitFailure', () {
        expect(
          mapError(dioError(DioExceptionType.badResponse, statusCode: 429)),
          isA<RateLimitFailure>(),
        );
      });

      test('500 and 503 map to ServerFailure', () {
        expect(
          mapError(dioError(DioExceptionType.badResponse, statusCode: 500)),
          isA<ServerFailure>(),
        );
        expect(
          mapError(dioError(DioExceptionType.badResponse, statusCode: 503)),
          isA<ServerFailure>(),
        );
      });

      test('other 4xx (e.g. 418) collapses to a generic ServerFailure', () {
        expect(
          mapError(dioError(DioExceptionType.badResponse, statusCode: 418)),
          isA<ServerFailure>(),
        );
      });

      test('a missing status code falls back to ServerFailure', () {
        expect(
          mapError(dioError(DioExceptionType.badResponse)),
          isA<ServerFailure>(),
        );
      });
    });

    group(
      'catch-all transport types collapse to ServerFailure (not offline)',
      () {
        // cancel / badCertificate / unknown are NOT connectivity loss, so they
        // must not be mislabeled as NetworkFailure ("you're offline").
        test('cancel', () {
          expect(
            mapError(dioError(DioExceptionType.cancel)),
            isA<ServerFailure>(),
          );
        });

        test('badCertificate', () {
          expect(
            mapError(dioError(DioExceptionType.badCertificate)),
            isA<ServerFailure>(),
          );
        });

        test('unknown', () {
          expect(
            mapError(dioError(DioExceptionType.unknown)),
            isA<ServerFailure>(),
          );
        });
      },
    );

    test('a raw FormatException maps to ParsingFailure', () {
      expect(
        mapError(const FormatException('bad json')),
        isA<ParsingFailure>(),
      );
    });

    test('a dio-wrapped FormatException maps to ParsingFailure', () {
      // type defaults to DioExceptionType.unknown; the FormatException in
      // `error` is what drives the ParsingFailure classification.
      final wrapped = DioException(
        requestOptions: requestOptions,
        error: const FormatException('bad json'),
      );
      expect(mapError(wrapped), isA<ParsingFailure>());
    });

    test('an unknown non-transport error maps to ServerFailure', () {
      expect(mapError(Exception('weird')), isA<ServerFailure>());
    });
  });
}
