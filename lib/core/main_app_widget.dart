import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import 'router/router.dart';
import 'theme/app_theme.dart';

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> with WidgetsBindingObserver {
  late final ProviderSubscription<AuthStatus> _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = ref.listenManual<AuthStatus>(authStateProvider, (_, _) {
      authRefreshNotifier.notify();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authStateProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final authStatus = ref.read(authStateProvider);
    final notifier = ref.read(authStateProvider.notifier);

    if (state == AppLifecycleState.resumed) {
      if (authStatus != AuthStatus.unlocked) {
        AppRouter.router.go('/lock');
        return;
      }
      if (notifier.keepUnlockedTimer != null) {
        notifier.checkKeepUnlockedExpiry();
      }
      return;
    }

    if (authStatus != AuthStatus.unlocked) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (notifier.keepUnlockedTimer != null) return;
      notifier.lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Notally',
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
