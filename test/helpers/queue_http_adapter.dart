import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A fake [HttpClientAdapter] that replays a queue of responders, one per call.
///
/// When the queue is exhausted it repeats the last responder. A responder may
/// return a [ResponseBody] or throw (e.g. a [DioException] for a connection
/// error) so interceptor retry logic can be exercised deterministically.
class QueueHttpAdapter implements HttpClientAdapter {
  /// Creates a [QueueHttpAdapter] from an ordered list of [responders].
  QueueHttpAdapter(this.responders);

  /// The ordered responders; the last is reused once the queue is exhausted.
  final List<ResponseBody Function(RequestOptions options)> responders;

  /// The number of times [fetch] has been invoked.
  int callCount = 0;

  /// The options of the most recent request (for asserting path/query).
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    final index = callCount < responders.length
        ? callCount
        : responders.length - 1;
    callCount++;
    return responders[index](options);
  }

  @override
  void close({bool force = false}) {}
}

/// A 200 response carrying [body] as JSON.
ResponseBody jsonOk(String body) => ResponseBody.fromString(
  body,
  200,
  headers: const {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

/// A response with [statusCode], an empty body, and optional [headers].
ResponseBody status(int statusCode, {Map<String, List<String>>? headers}) =>
    ResponseBody.fromString('', statusCode, headers: headers);
