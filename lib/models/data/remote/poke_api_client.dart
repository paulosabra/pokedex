import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/logging/loggers.dart';
import 'endpoints.dart';

typedef JsonMap = Map<String, Object?>;

/// TS-12: bodies above this size are decoded off the UI isolate.
const isolateDecodeThreshold = 64 * 1024;

bool shouldDecodeInIsolate(int byteLength) =>
    byteLength > isolateDecodeThreshold;

/// Decodes a UTF-8 JSON body (RFC 8259), in an isolate when it is large.
Future<Object?> decodeJsonBody(List<int> bytes) {
  Object? decode() => jsonDecode(utf8.decode(bytes));
  return shouldDecodeInIsolate(bytes.length)
      ? Isolate.run(decode)
      : Future.sync(decode);
}

/// The only network I/O point: maps transport errors and HTTP statuses to
/// [AppFailure] (PRD §10.2) and never throws.
class PokeApiClient {
  PokeApiClient({
    required http.Client httpClient,
    Uri? baseUrl,
    this._timeout = const Duration(seconds: 10),
  }) : _http = httpClient,
       _baseUrl = baseUrl ?? Endpoints.baseUrl;

  /// PRD §11.4: at most this much of a body reaches the logs.
  static const logSnippetLength = 200;

  static final _log = Logger(LoggerNames.api);

  final http.Client _http;
  final Uri _baseUrl;
  final Duration _timeout;
  var _lastReq = 0;

  Future<Result<JsonMap>> fetchIndex() => _get(Endpoints.index);

  Future<Result<JsonMap>> fetchPokemon(int id) => _get(Endpoints.pokemon(id));

  Future<Result<JsonMap>> fetchSpecies(int id) => _get(Endpoints.species(id));

  Future<Result<JsonMap>> _get(String path) async {
    final req = ++_lastReq;
    final call = 'GET /$path';
    final stopwatch = Stopwatch()..start();
    String tags() => '{ms=${stopwatch.elapsedMilliseconds}, req=$req}';

    Result<JsonMap> fail(
      AppFailure failure,
      Level level,
      String detail, [
      Object? error,
      StackTrace? stackTrace,
    ]) {
      _log.log(
        level,
        '${failure.runtimeType} on $call$detail ${tags()}',
        error,
        stackTrace,
      );
      return Err(failure);
    }

    _log.fine('$call {req=$req}');
    try {
      final response = await _http
          .get(_baseUrl.resolve(path))
          .timeout(_timeout);
      final status = response.statusCode;
      switch (status) {
        case >= 200 && < 300:
          break;
        case 404:
          return fail(const NotFoundFailure(), Level.WARNING, ' → $status');
        case 429:
          return fail(const RateLimitFailure(), Level.WARNING, ' → $status');
        default:
          return fail(ServerFailure(status), Level.SEVERE, ' → $status');
      }

      final Object? json;
      try {
        json = await decodeJsonBody(response.bodyBytes);
      } on FormatException catch (e, st) {
        return fail(
          ParsingFailure(cause: e, stackTrace: st),
          Level.SEVERE,
          ' → $status ${_snippet(response.bodyBytes)}',
          e,
          st,
        );
      }
      if (json is! JsonMap) {
        final cause = FormatException(
          'Expected a JSON object, got ${json.runtimeType}',
        );
        return fail(
          ParsingFailure(cause: cause),
          Level.SEVERE,
          ' → $status ${_snippet(response.bodyBytes)}',
          cause,
        );
      }
      _log.fine('$call → $status ${tags()}');
      return Ok(json);
    } on TimeoutException catch (e, st) {
      return fail(
        TimeoutFailure(cause: e, stackTrace: st),
        Level.WARNING,
        '',
        e,
        st,
      );
    } on SocketException catch (e, st) {
      return fail(
        NetworkFailure(cause: e, stackTrace: st),
        Level.WARNING,
        '',
        e,
        st,
      );
    } on http.ClientException catch (e, st) {
      return fail(
        NetworkFailure(cause: e, stackTrace: st),
        Level.WARNING,
        '',
        e,
        st,
      );
    } catch (e, st) {
      return fail(
        UnexpectedFailure(cause: e, stackTrace: st),
        Level.SEVERE,
        '',
        e,
        st,
      );
    }
  }

  static String _snippet(List<int> bytes) {
    final body = utf8.decode(bytes, allowMalformed: true);
    final snippet = body.length <= logSnippetLength
        ? body
        : body.substring(0, logSnippetLength);
    return 'body="$snippet"';
  }
}
