import '../data/database.dart';

abstract class NotesRepository {
  Future<List<Note>> getAllNotes();
  Future<Note> getNoteById(int id);
  Future<Note> createNote({String title, String body});
  Future<Note> updateNote(int id, {String? title, String? body});
  Future<void> deleteNote(int id);
  Future<List<Note>> searchNotes(String query);
}
