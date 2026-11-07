import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import '../../data/database.dart' show Note;

class NoteItem extends StatelessWidget {
  final Note note;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final String? searchQuery;
  final int index;

  const NoteItem({
    super.key,
    required this.note,
    this.onTap,
    this.onDelete,
    this.searchQuery,
    this.index = 0,
  });

  static String _extractPlainText(String body) {
    if (body.isEmpty) return '';
    try {
      final decoded = jsonDecode(body);
      if (decoded is List) {
        return decoded
            .map((op) => op['insert'] is String ? op['insert'] as String : '')
            .join()
            .trim();
      }
    } catch (_) {}
    return body
        .replaceAll(RegExp(r'\*\*|__'), '')
        .replaceAll(RegExp(r'<<C:#[0-9A-Fa-f]{6}>>'), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cleanBody = _extractPlainText(note.body);

    return Semantics(
      label: 'Note: ${note.title.isNotEmpty ? note.title : "Untitled"}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onDelete != null && note.id != 0
              ? () => _showDeleteDialog(context, onDelete!)
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.title.isNotEmpty)
                  _HighlightedText(
                    text: note.title,
                    searchQuery: searchQuery,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 18.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                  ),
                if (cleanBody.isNotEmpty) ...[
                  if (note.title.isNotEmpty) const SizedBox(height: 4),
                  _HighlightedText(
                    text: cleanBody,
                    searchQuery: searchQuery,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 8,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _formatDate(note.updatedAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays < 1) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      switch (date.weekday) {
        case DateTime.monday: return 'Mon';
        case DateTime.tuesday: return 'Tue';
        case DateTime.wednesday: return 'Wed';
        case DateTime.thursday: return 'Thu';
        case DateTime.friday: return 'Fri';
        case DateTime.saturday: return 'Sat';
        case DateTime.sunday: return 'Sun';
        default: return 'Unknown';
      }
    } else {
      return '${date.month}/${date.day}';
    }
  }

  void _showDeleteDialog(BuildContext context, VoidCallback onDelete) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.of(ctx).pop();
              onDelete();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final String? searchQuery;
  final TextStyle? style;
  final int maxLines;

  const _HighlightedText({
    required this.text,
    this.searchQuery,
    this.style,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (searchQuery == null || searchQuery!.isEmpty) {
      return AutoSizeText(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        minFontSize: 10,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = searchQuery!.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + searchQuery!.length),
        style: const TextStyle(
          backgroundColor: Color(0x559E8CFA),
          fontWeight: FontWeight.bold,
        ),
      ));
      start = index + searchQuery!.length;
    }

    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style,
        children: spans,
      ),
    );
  }
}
