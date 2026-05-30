import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// VM in-memory executor — a fresh SQLite database held entirely in memory.
QueryExecutor createInMemoryExecutor() => NativeDatabase.memory();
