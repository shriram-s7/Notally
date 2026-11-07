import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/setup_screen.dart';
import '../../features/auth/presentation/screens/lock_screen.dart';
import '../../features/notes/presentation/screens/note_list_screen.dart';
import '../../features/notes/presentation/screens/note_edit_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

class _AuthRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final authRefreshNotifier = _AuthRefreshNotifier();

Page<T> _buildPage<T>(Widget child) {
  return CustomTransitionPage<T>(
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          )),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
  );
}

class AppRouter {
  static GoRouter get router => GoRouter(
    refreshListenable: authRefreshNotifier,
    initialLocation: '/',
    navigatorKey: rootNavigatorKey,
    routes: [
      GoRoute(
        path: '/setup',
        name: 'setup',
        pageBuilder: (context, state) => _buildPage(const SetupScreen()),
      ),
      GoRoute(
        path: '/lock',
        name: 'lock',
        pageBuilder: (context, state) => _buildPage(const LockScreen()),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        pageBuilder: (context, state) => _buildPage(const NoteListScreen()),
      ),
      GoRoute(
        path: '/note-edit',
        name: 'note-edit',
        pageBuilder: (context, state) {
          final noteData = state.extra as Map<String, dynamic>?;
          final noteId = noteData?['noteId'] as int?;
          final noteTitle = noteData?['title'] as String? ?? '';
          final noteBody = noteData?['body'] as String? ?? '';
          return _buildPage(NoteEditScreen(
            noteId: noteId,
            initialTitle: noteTitle,
            initialBody: noteBody,
          ));
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) => _buildPage(const SettingsScreen()),
      ),
    ],
    redirect: (context, state) {
      final container = ProviderScope.containerOf(context);
      final authStatus = container.read(authStateProvider);
      final location = state.uri.path;

      switch (authStatus) {
        case AuthStatus.initializing:
          if (location == '/lock') return null;
          return '/lock';
        case AuthStatus.setup:
          if (location == '/setup' || location == '/lock') return null;
          return '/setup';
        case AuthStatus.locked:
        case AuthStatus.unlocking:
          if (location == '/lock') return null;
          return '/lock';
        case AuthStatus.unlocked:
          if (location == '/setup' || location == '/lock') return '/';
          return null;
      }
    },
  );
}
