import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3/open.dart' as open_lib;
import '../../../core/utils/security_utils.dart';
import 'tables.dart';

part 'database.g.dart';

typedef Note = NotesTableData;

@DriftDatabase(tables: [NotesTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_notes_title ON notes_table(title)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_notes_body ON notes_table(body)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_notes_updated_at ON notes_table(updated_at)',
      );
    },
  );

  Future<List<Note>> getAllNotes() {
    return (select(notesTable)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)])
        ).get();
  }

  Future<List<Note>> getAllNotesForBackup() {
    return select(notesTable).get();
  }

  Future<void> restoreBackup(List<Note> notes) async {
    await transaction(() async {
      await delete(notesTable).go();
      for (final note in notes) {
        await into(notesTable).insertOnConflictUpdate(note);
      }
    });
  }

  Future<Note> getNoteById(int id) {
    return (select(notesTable)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<int> insertNote(NotesTableCompanion note) {
    return into(notesTable).insert(note);
  }

  Future<bool> updateNote(NotesTableCompanion note) {
    return update(notesTable).replace(note);
  }

  Future<int> markAsDeleted(int id) {
    return (update(notesTable)..where((t) => t.id.equals(id))).write(
      NotesTableCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<int> deletePermanently(int id) {
    return (delete(notesTable)..where((t) => t.id.equals(id))).go();
  }

  Future<List<Note>> searchNotes(String query) {
    final pattern = '%${_escapeLike(query.toLowerCase())}%';
    return (select(notesTable)
          ..where((t) => t.isDeleted.equals(false))
          ..where((t) =>
            t.title.lower().like(pattern) | t.body.lower().like(pattern))
          ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)])
        ).get();
  }

  static String _escapeLike(String value) {
    return value.replaceAll('%', '\\%').replaceAll('_', '\\_');
  }

  static Future<AppDatabase> create(Uint8List encryptionKey) async {
    await _initializeSqlCipher();

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'notally.db');

    final keyHex = SecurityUtils.bytesToHex(encryptionKey);

    final db = sqlite3.open(dbPath);
    db.execute("PRAGMA key = \"x'$keyHex'\"");
    db.execute('PRAGMA cipher_hmac_algorithm = HMAC_SHA512');
    db.execute('PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA512');
    db.execute('PRAGMA cipher_page_size = 4096');

    return AppDatabase(NativeDatabase.opened(db));
  }

  static Future<void> _initializeSqlCipher() async {
    if (Platform.isAndroid) {
      open_lib.open.overrideFor(
        open_lib.OperatingSystem.android,
        openCipherOnAndroid,
      );
    }
  }
}
