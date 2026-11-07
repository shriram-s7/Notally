import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void navigateToNoteEdit(BuildContext context, {int? noteId, String title = '', String body = ''}) {
  context.push('/note-edit', extra: {
    if (noteId case final id?) 'noteId': id,
    'title': title,
    'body': body,
  });
}

void navigateToHome(BuildContext context) {
  context.go('/');
}

void navigateToSettings(BuildContext context) {
  context.push('/settings');
}
