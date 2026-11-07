import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/database.dart' show Note;
import '../providers/notes_providers.dart';
import '../widgets/note_item.dart';

class NoteListScreen extends ConsumerStatefulWidget {
  const NoteListScreen({super.key});

  @override
  ConsumerState<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends ConsumerState<NoteListScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showFab = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scrollController.offset <= _scrollController.position.maxScrollExtent - 100;
    if (show != _showFab) {
      setState(() => _showFab = show);
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        ref.read(searchNotesProvider.notifier).clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);
    final searchAsync = ref.watch(searchNotesProvider);
    final theme = Theme.of(context);
    final isSearchActive = _isSearching && _searchController.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  border: InputBorder.none,
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                onChanged: (query) {
                  ref.read(searchNotesProvider.notifier).search(query);
                  setState(() {});
                },
              )
            : Semantics(
                header: true,
                child: Text(
                  'Notally',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(_isSearching ? Icons.close : Icons.search, key: ValueKey(_isSearching)),
            ),
            onPressed: _toggleSearch,
            tooltip: _isSearching ? 'Close search' : 'Search',
          ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/settings'),
              tooltip: 'Settings',
            ),
        ],
      ),
      body: isSearchActive
          ? searchAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error: $err', style: theme.textTheme.bodyMedium),
              ),
              data: (results) => _buildNoteList(notes: results, theme: theme, isSearch: true),
            )
          : notesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error: $err', style: theme.textTheme.bodyMedium),
              ),
              data: (notes) => _buildNoteList(notes: notes, theme: theme),
            ),
      floatingActionButton: _showFab
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/note-edit'),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('New Note'),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            )
          : null,
    );
  }

  Widget _buildNoteList({
    required List<Note> notes,
    required ThemeData theme,
    bool isSearch = false,
  }) {
    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearch ? Icons.search_off : Icons.note_add,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              isSearch ? 'No matching notes' : 'No notes yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearch
                  ? 'Try a different search term'
                  : 'Tap the + button to create a new note',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final searchQuery = isSearch ? _searchController.text : null;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      physics: const ClampingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return NoteItem(
          note: note,
          searchQuery: searchQuery,
          index: index,
          onTap: () => context.push('/note-edit', extra: {
            'noteId': note.id,
            'title': note.title,
            'body': note.body,
          }),
          onDelete: () async {
            final notifier = ref.read(notesProvider.notifier);
            await notifier.deleteNote(note.id);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: const Text('Note deleted'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      ref.read(notesProvider.notifier).createNote(
                        title: note.title,
                        body: note.body,
                      );
                    },
                  ),
                ),
              );
          },
        );
      },
    );
  }
}
