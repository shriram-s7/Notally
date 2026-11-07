import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../data/notes_repository_impl.dart';
import '../../domain/notes_repository.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  final authState = ref.watch(authStateProvider);
  if (authState != AuthStatus.unlocked) {
    throw StateError('Not authenticated');
  }
  final authRepo = ref.read(authRepositoryProvider);
  final key = await authRepo.getDatabaseKey();
  return AppDatabase.create(key);
});

final notesRepositoryProvider = FutureProvider<NotesRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return NotesRepositoryImpl(db);
});

class NotesNotifier extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() async {
    final repo = await ref.watch(notesRepositoryProvider.future);
    return repo.getAllNotes();
  }

  Future<Note> createNote({String title = '', String body = ''}) async {
    final repo = await ref.read(notesRepositoryProvider.future);
    final note = await repo.createNote(title: title, body: body);
    state = AsyncValue.data([note, ...?state.valueOrNull]);
    return note;
  }

  Future<void> deleteNote(int id) async {
    final repo = await ref.read(notesRepositoryProvider.future);
    await repo.deleteNote(id);
    state = AsyncValue.data(
      state.valueOrNull?.where((n) => n.id != id).toList() ?? [],
    );
  }

  Future<Note> saveNote(int id, {String? title, String? body}) async {
    final repo = await ref.read(notesRepositoryProvider.future);
    final note = await repo.updateNote(id, title: title, body: body);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data([
        for (final n in current)
          if (n.id == id) note else n,
      ]);
    }
    return note;
  }
}

final notesProvider = AsyncNotifierProvider<NotesNotifier, List<Note>>(
  () => NotesNotifier(),
);

final noteProvider = FutureProvider.family<Note, int>((ref, id) async {
  final repo = await ref.watch(notesRepositoryProvider.future);
  return repo.getNoteById(id);
});

class SearchNotesNotifier extends StateNotifier<AsyncValue<List<Note>>> {
  final Ref _ref;
  String _query = '';
  Timer? _debounceTimer;
  int _requestId = 0;

  SearchNotesNotifier(this._ref) : super(const AsyncValue.data([]));

  String get query => _query;

  void search(String query) {
    _query = query;
    _debounceTimer?.cancel();
    if (query.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    final id = ++_requestId;
    try {
      final repo = await _ref.read(notesRepositoryProvider.future);
      final results = await repo.searchNotes(query);
      if (id == _requestId) {
        state = AsyncValue.data(results);
      }
    } catch (e, st) {
      if (id == _requestId) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  void clear() {
    _query = '';
    _requestId++;
    _debounceTimer?.cancel();
    state = const AsyncValue.data([]);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final searchNotesProvider =
    StateNotifierProvider<SearchNotesNotifier, AsyncValue<List<Note>>>((ref) {
  return SearchNotesNotifier(ref);
});
