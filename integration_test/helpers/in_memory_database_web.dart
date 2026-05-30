import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

/// Web in-memory executor: load the committed `sqlite3.wasm`, register an
/// in-memory VFS, and open a worker-less in-memory database.
///
/// No persistence and no `SharedArrayBuffer`, so it runs identically under
/// `flutter drive`'s web-server (which doesn't emit COOP/COEP) and keeps the
/// E2E deterministic — there is no cross-test IndexedDB/OPFS state to leak.
QueryExecutor createInMemoryExecutor() => LazyDatabase(() async {
  final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  sqlite3.registerVirtualFileSystem(InMemoryFileSystem(), makeDefault: true);
  return WasmDatabase.inMemory(sqlite3);
});
