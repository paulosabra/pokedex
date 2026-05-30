import 'package:drift/drift.dart';

import 'in_memory_database_native.dart'
    if (dart.library.js_interop) 'in_memory_database_web.dart';

/// A fresh in-memory [QueryExecutor] for the E2E `AppDatabase`, implemented per
/// platform via conditional import: `NativeDatabase.memory()` on the VM, and an
/// in-memory `WasmDatabase` (loading the committed `sqlite3.wasm`) on the web.
///
/// The split exists because drift's native (`dart:ffi`) and wasm backends are
/// different libraries; the web E2E (`flutter drive` on headless Chrome) cannot
/// compile `package:drift/native.dart`.
QueryExecutor inMemoryExecutor() => createInMemoryExecutor();
