import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/notes_providers.dart';

class NoteEditScreen extends ConsumerStatefulWidget {
  const NoteEditScreen({
    super.key,
    this.noteId,
    this.initialTitle = '',
    this.initialBody = '',
  });

  final int? noteId;
  final String initialTitle;
  final String initialBody;

  @override
  ConsumerState<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends ConsumerState<NoteEditScreen> {
  final _titleController = TextEditingController();
  late QuillController _quillController;
  final _titleFocusNode = FocusNode();
  final _bodyFocusNode = FocusNode();
  final _scrollController = ScrollController();
  Timer? _autoSaveTimer;
  Timer? _clipboardClearTimer;
  int _currentNoteId = 0;
  bool _isNewNote = false;
  String _lastSavedTitle = '';
  String _lastSavedBody = '';
  bool _isBold = false;
  bool _isUnderline = false;

  @override
  void initState() {
    super.initState();
    _isNewNote = widget.noteId == null;
    _currentNoteId = widget.noteId ?? 0;
    _titleController.text = widget.initialTitle;
    _lastSavedTitle = widget.initialTitle;
    _lastSavedBody = widget.initialBody;

    final doc = _parseBody(widget.initialBody);
    _quillController = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );

    _titleController.addListener(_scheduleAutoSave);
    _quillController.addListener(_scheduleAutoSave);
    _quillController.addListener(_updateFormatState);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isNewNote) {
        _titleFocusNode.requestFocus();
      } else {
        _bodyFocusNode.requestFocus();
      }
    });
  }

  Document _parseBody(String body) {
    if (body.isEmpty) return Document()..insert(0, '');
    try {
      final decoded = jsonDecode(body);
      if (decoded is List) return Document.fromJson(decoded);
    } catch (_) {}
    final cleaned = body
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll(RegExp(r'<<C:#[0-9A-Fa-f]{6}>>'), '');
    return Document()..insert(0, cleaned);
  }

  @override
  void dispose() {
    _titleController.removeListener(_scheduleAutoSave);
    _quillController.removeListener(_scheduleAutoSave);
    _quillController.removeListener(_updateFormatState);
    _titleController.dispose();
    _titleFocusNode.dispose();
    _bodyFocusNode.dispose();
    _scrollController.dispose();
    _quillController.dispose();
    _autoSaveTimer?.cancel();
    _clipboardClearTimer?.cancel();
    super.dispose();
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(AppConstants.autoSaveDelay, _autoSave);
  }

  bool _hasChanges() {
    final body = jsonEncode(_quillController.document.toDelta().toJson());
    return _titleController.text != _lastSavedTitle || body != _lastSavedBody;
  }

  Future<void> _autoSave() async {
    if (!mounted) return;
    if (!_hasChanges()) return;

    final title = _titleController.text;
    final body = jsonEncode(_quillController.document.toDelta().toJson());

    if (_isNewNote && title.isEmpty && _quillController.document.isEmpty()) return;

    try {
      if (_currentNoteId == 0) {
        final newNote = await ref.read(notesProvider.notifier).createNote(
          title: title,
          body: body,
        );
        if (mounted) {
          setState(() {
            _currentNoteId = newNote.id;
            _isNewNote = false;
            _lastSavedTitle = title;
            _lastSavedBody = body;
          });
        }
      } else {
        await ref.read(notesProvider.notifier).saveNote(
          _currentNoteId,
          title: title,
          body: body,
        );
        if (mounted) {
          setState(() {
            _lastSavedTitle = title;
            _lastSavedBody = body;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _clipboardClearTimer?.cancel();
    _clipboardClearTimer = Timer(AppConstants.clipboardClearDelay, () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          await _autoSave();
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: theme.colorScheme.surface,
        appBar: _buildAppBar(context, theme),
        body: _buildBody(context, theme),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: _buildFormattingBar(theme),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ThemeData theme) {
    return AppBar(
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface),
        onPressed: () async {
          await _autoSave();
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.copy, color: theme.colorScheme.onSurface),
          onPressed: () {
            final text = _buildCopyText();
            if (text.isNotEmpty) {
              _copyToClipboard(text);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard. Clears in 30s.'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  String _buildCopyText() {
    final title = _titleController.text.trim();
    final body = _quillController.document.toPlainText().trim();
    if (title.isEmpty && body.isEmpty) return '';
    if (title.isEmpty) return body;
    if (body.isEmpty) return title;
    return '$title\n\n$body';
  }

  Widget _buildBody(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          Semantics(
            header: true,
            child: TextField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
                contentPadding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: QuillEditor.basic(
                controller: _quillController,
                focusNode: _bodyFocusNode,
                scrollController: _scrollController,
                config: QuillEditorConfig(
                  scrollable: true,
                  padding: EdgeInsets.zero,
                  autoFocus: !_isNewNote,
                  expands: true,
                  placeholder: 'Note',
                  customStyles: const DefaultStyles(
                    bold: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateFormatState() {
    final sel = _quillController.selection;
    if (!sel.isValid) return;
    bool boldActive, underlineActive;
    if (sel.isCollapsed) {
      final leaf = _quillController.queryNode(sel.start);
      final docBold = leaf != null && leaf.style.attributes.containsKey('bold');
      final docUnderline = leaf != null && leaf.style.attributes.containsKey('underline');
      final toggleBold = _quillController.toggledStyle.attributes['bold']?.value != null;
      final toggleUnderline = _quillController.toggledStyle.attributes['underline']?.value != null;
      boldActive = docBold || toggleBold;
      underlineActive = docUnderline || toggleUnderline;
    } else {
      final style = _quillController.document.collectStyle(sel.start, sel.end - sel.start);
      boldActive = style.attributes.containsKey('bold');
      underlineActive = style.attributes.containsKey('underline');
    }
    if (boldActive != _isBold || underlineActive != _isUnderline) {
      setState(() {
        _isBold = boldActive;
        _isUnderline = underlineActive;
      });
    }
  }

  void _toggleBold() {
    final sel = _quillController.selection;
    if (!sel.isValid) return;
    if (sel.isCollapsed) {
      final leaf = _quillController.queryNode(sel.start);
      final docHas = leaf != null && leaf.style.attributes.containsKey('bold');
      final toggleHas = _quillController.toggledStyle.attributes['bold']?.value != null;
      if (docHas || toggleHas) {
        _quillController.formatSelection(Attribute.clone(BoldAttribute(), null));
      } else {
        _quillController.formatSelection(BoldAttribute());
      }
    } else {
      final style = _quillController.document.collectStyle(sel.start, sel.end - sel.start);
      if (style.attributes.containsKey('bold')) {
        _quillController.formatSelection(Attribute.clone(BoldAttribute(), null));
      } else {
        _quillController.formatSelection(BoldAttribute());
      }
    }
  }

  void _toggleUnderline() {
    final sel = _quillController.selection;
    if (!sel.isValid) return;
    if (sel.isCollapsed) {
      final leaf = _quillController.queryNode(sel.start);
      final docHas = leaf != null && leaf.style.attributes.containsKey('underline');
      final toggleHas = _quillController.toggledStyle.attributes['underline']?.value != null;
      if (docHas || toggleHas) {
        _quillController.formatSelection(Attribute.clone(UnderlineAttribute(), null));
      } else {
        _quillController.formatSelection(UnderlineAttribute());
      }
    } else {
      final style = _quillController.document.collectStyle(sel.start, sel.end - sel.start);
      if (style.attributes.containsKey('underline')) {
        _quillController.formatSelection(Attribute.clone(UnderlineAttribute(), null));
      } else {
        _quillController.formatSelection(UnderlineAttribute());
      }
    }
  }

  Widget _buildFormattingBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(top: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.12))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.format_bold, size: 20),
            onPressed: _toggleBold,
            tooltip: 'Bold',
            style: IconButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface,
              backgroundColor: _isBold
                  ? theme.colorScheme.onSurface.withOpacity(0.12)
                  : Colors.transparent,
              shape: const CircleBorder(),
              visualDensity: VisualDensity.compact,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.format_underline, size: 20),
            onPressed: _toggleUnderline,
            tooltip: 'Underline',
            style: IconButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface,
              backgroundColor: _isUnderline
                  ? theme.colorScheme.onSurface.withOpacity(0.12)
                  : Colors.transparent,
              shape: const CircleBorder(),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

}
