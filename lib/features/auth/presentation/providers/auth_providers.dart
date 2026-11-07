import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../data/auth_repository_impl.dart';
import '../../data/crypto_service.dart';
import '../../data/secure_storage_service.dart';
import '../../domain/auth_repository.dart';

enum AuthStatus { initializing, setup, locked, unlocking, unlocked }

final manualLockTriggeredProvider = StateProvider<bool>((ref) => false);

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return CryptoService();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final crypto = ref.watch(cryptoServiceProvider);
  final storage = ref.watch(secureStorageServiceProvider);
  return AuthRepositoryImpl(cryptoService: crypto, secureStorage: storage);
});

final keepUnlockedDurationProvider = StateProvider<int>((ref) => 0);

final keepUnlockedActiveProvider = StateProvider<bool>((ref) => false);

class AuthNotifier extends StateNotifier<AuthStatus> {
  final Ref _ref;
  Timer? keepUnlockedTimer;
  int keepUnlockedDuration = 0;

  AuthNotifier(this._ref) : super(AuthStatus.initializing);

  Future<void> initialize() async {
    final repo = _ref.read(authRepositoryProvider);
    final hasPassword = await repo.hasMasterPassword();
    if (!hasPassword) {
      state = AuthStatus.setup;
      return;
    }

    final settingsRepo = _ref.read(settingsRepositoryProvider);
    final until = await settingsRepo.getKeepUnlockedUntil();
    if (until != null && DateTime.now().isBefore(until)) {
      state = AuthStatus.unlocked;
      keepUnlockedDuration = await settingsRepo.getKeepUnlockedDuration();
      _ref.read(keepUnlockedDurationProvider.notifier).state = keepUnlockedDuration;
      _startKeepUnlockedTimer(until);
      try {
        await repo.getDatabaseKey();
      } catch (_) {}
      return;
    }

    if (until != null) {
      await settingsRepo.clearKeepUnlocked();
    }

    state = AuthStatus.locked;
  }

  Future<bool> createPassword(String password) async {
    try {
      final repo = _ref.read(authRepositoryProvider);
      await repo.createMasterPassword(password);
      state = AuthStatus.locked;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> unlockWithPassword(String password) async {
    if (state == AuthStatus.unlocking) return false;
    state = AuthStatus.unlocking;
    try {
      final repo = _ref.read(authRepositoryProvider);
      final valid = await repo.verifyPassword(password);
      if (valid) {
        state = AuthStatus.unlocked;
        return true;
      }
      state = AuthStatus.locked;
      return false;
    } catch (e) {
      state = AuthStatus.locked;
      return false;
    }
  }

  Future<bool> unlockWithBiometrics() async {
    if (state == AuthStatus.unlocking) return false;
    state = AuthStatus.unlocking;
    try {
      final repo = _ref.read(authRepositoryProvider);
      final success = await repo.authenticateWithBiometrics();
      if (success) {
        state = AuthStatus.unlocked;
        return true;
      }
      state = AuthStatus.locked;
      return false;
    } catch (e) {
      state = AuthStatus.locked;
      return false;
    }
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      final repo = _ref.read(authRepositoryProvider);
      return repo.changeMasterPassword(oldPassword, newPassword);
    } catch (e) {
      return false;
    }
  }

  Future<void> enableKeepUnlocked(int seconds) async {
    if (seconds <= 0) {
      await _disableKeepUnlocked();
      return;
    }

    final settingsRepo = _ref.read(settingsRepositoryProvider);
    final until = DateTime.now().add(Duration(seconds: seconds));

    keepUnlockedDuration = seconds;
    _ref.read(keepUnlockedDurationProvider.notifier).state = seconds;
    _ref.read(keepUnlockedActiveProvider.notifier).state = true;
    await settingsRepo.setKeepUnlockedDuration(seconds);
    await settingsRepo.setKeepUnlockedUntil(until);

    _startKeepUnlockedTimer(until);
  }

  void _startKeepUnlockedTimer(DateTime until) {
    keepUnlockedTimer?.cancel();
    final remaining = until.difference(DateTime.now());
    if (remaining.isNegative) {
      lock();
      return;
    }

    keepUnlockedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (DateTime.now().isAfter(until)) {
        keepUnlockedTimer?.cancel();
        keepUnlockedTimer = null;
        keepUnlockedDuration = 0;
        _ref.read(keepUnlockedDurationProvider.notifier).state = 0;
        _ref.read(keepUnlockedActiveProvider.notifier).state = false;
        unawaited(_clearKeepUnlockedStorage());
        lock();
      }
    });
  }

  Future<void> _disableKeepUnlocked() async {
    keepUnlockedTimer?.cancel();
    keepUnlockedTimer = null;
    keepUnlockedDuration = 0;
    _ref.read(keepUnlockedDurationProvider.notifier).state = 0;
    _ref.read(keepUnlockedActiveProvider.notifier).state = false;
    final settingsRepo = _ref.read(settingsRepositoryProvider);
    await settingsRepo.clearKeepUnlocked();
  }

  Future<void> _clearKeepUnlockedStorage() async {
    final settingsRepo = _ref.read(settingsRepositoryProvider);
    await settingsRepo.clearKeepUnlocked();
  }

  Future<void> checkKeepUnlockedExpiry() async {
    if (keepUnlockedTimer == null) return;
    final settingsRepo = _ref.read(settingsRepositoryProvider);
    final until = await settingsRepo.getKeepUnlockedUntil();
    if (until == null || DateTime.now().isAfter(until)) {
      lock();
    }
  }

  void lock() {
    keepUnlockedTimer?.cancel();
    keepUnlockedTimer = null;
    keepUnlockedDuration = 0;
    _ref.read(keepUnlockedDurationProvider.notifier).state = 0;
    _ref.read(keepUnlockedActiveProvider.notifier).state = false;
    unawaited(_clearKeepUnlockedStorage());
    final repo = _ref.read(authRepositoryProvider);
    repo.lock();
    state = AuthStatus.locked;
  }

  void resetToSetup() {
    keepUnlockedTimer?.cancel();
    keepUnlockedTimer = null;
    keepUnlockedDuration = 0;
    _ref.read(keepUnlockedDurationProvider.notifier).state = 0;
    _ref.read(keepUnlockedActiveProvider.notifier).state = false;
    state = AuthStatus.setup;
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthStatus>((ref) {
  return AuthNotifier(ref);
});
