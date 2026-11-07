import 'package:drift/drift.dart';
import '../domain/notes_repository.dart';
import 'database.dart';

class NotesRepositoryImpl implements NotesRepository {
  final AppDatabase _db;

  NotesRepositoryImpl(this._db);

  @override
  Future<List<Note>> getAllNotes() => _db.getAllNotes();

  @override
  Future<Note> getNoteById(int id) => _db.getNoteById(id);

  @override
  Future<Note> createNote({String title = '', String body = ''}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await _db.insertNote(
      NotesTableCompanion(
        title: Value(title),
        body: Value(body),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    return _db.getNoteById(id);
  }

  @override
  Future<Note> updateNote(
    int id, {
    String? title,
    String? body,
  }) async {
    final existing = await _db.getNoteById(id);
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.updateNote(
      NotesTableCompanion(
        id: Value(id),
        title: Value(title ?? existing.title),
        body: Value(body ?? existing.body),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(now),
        isDeleted: Value(existing.isDeleted),
        deletedAt: Value(existing.deletedAt),
      ),
    );

    return _db.getNoteById(id);
  }

  @override
  Future<void> deleteNote(int id) async {
    await _db.markAsDeleted(id);
  }

  @override
  Future<List<Note>> searchNotes(String query) {
    return _db.searchNotes(query);
  }
}
