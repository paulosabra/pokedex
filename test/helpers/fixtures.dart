import 'dart:io';

/// Raw PokéAPI payloads captured once with `curl` (T06), under
/// `test/fixtures/`.
String fixture(String name) =>
    File('test/fixtures/$name.json').readAsStringSync();
