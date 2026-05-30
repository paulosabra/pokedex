import 'dart:convert';
import 'dart:io';

/// Reads a raw fixture file from `test/fixtures/`.
String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

/// Reads and decodes a JSON-object fixture into a map.
Map<String, dynamic> fixtureJson(String name) =>
    jsonDecode(fixture(name)) as Map<String, dynamic>;

/// Reads and decodes a top-level JSON-array fixture into a list.
List<dynamic> fixtureJsonArray(String name) =>
    jsonDecode(fixture(name)) as List<dynamic>;
