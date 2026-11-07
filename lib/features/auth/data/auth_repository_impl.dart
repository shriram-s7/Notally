import 'dart:convert';
import 'dart:typed_data';
import 'package:local_auth/local_auth.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/security_utils.dart';
import '../domain/auth_repository.dart';
import 'crypto_service.dart';
import 'secure_storage_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final CryptoService _cryptoService;
  final SecureStorageService _secureStorage;
  final LocalAuthentication _localAuth;

  Uint8List? _databaseKey;

  AuthRepositoryImpl({
    required CryptoService cryptoService,
    required SecureStorageService secureStorage,
    LocalAuthentication? localAuth,
  })  : _cryptoService = cryptoService,
        _secureStorage = secureStorage,
        _localAuth = localAuth ?? LocalAuthentication();

  @override
  Future<bool> hasMasterPassword() async {
    final hash = await _secureStorage.read(AppConstants.keyMasterPasswordHash);
    return hash != null && hash.isNotEmpty;
  }

  @override
  Future<void> createMasterPassword(String password) async {
    final salt = SecurityUtils.generateSalt(AppConstants.saltLength);
    final hash = await _cryptoService.hashPassword(password, salt: salt);

    final dbKey = SecurityUtils.generateSecureKey(AppConstants.dbKeyLength);

    await _secureStorage.write(
      AppConstants.keyMasterPasswordHash,
      base64Encode(hash),
    );
    await _secureStorage.writeBytes(
      AppConstants.keyMasterPasswordSalt,
      salt,
    );
    await _secureStorage.writeBytes(
      AppConstants.keyDatabaseKey,
      dbKey,
    );

    _databaseKey = Uint8List.fromList(dbKey);
  }

  @override
  Future<bool> verifyPassword(String password) async {
    final storedHashB64 = await _secureStorage.read(AppConstants.keyMasterPasswordHash);
    if (storedHashB64 == null) return false;

    final salt = await _secureStorage.readBytes(AppConstants.keyMasterPasswordSalt);
    if (salt == null) return false;

    final storedHash = base64Decode(storedHashB64);
    final valid = await _cryptoService.verifyPassword(
      password: password,
      salt: salt,
      expectedHash: storedHash,
    );

    if (valid && _databaseKey == null) {
      final dbKeyBytes = await _secureStorage.readBytes(AppConstants.keyDatabaseKey);
      if (dbKeyBytes != null) {
        _databaseKey = Uint8List.fromList(dbKeyBytes);
      }
    }

    return valid;
  }

  @override
  Future<bool> changeMasterPassword(String oldPassword, String newPassword) async {
    final verified = await verifyPassword(oldPassword);
    if (!verified) return false;

    final newSalt = SecurityUtils.generateSalt(AppConstants.saltLength);
    final newHash = await _cryptoService.hashPassword(newPassword, salt: newSalt);

    await _secureStorage.write(
      AppConstants.keyMasterPasswordHash,
      base64Encode(newHash),
    );
    await _secureStorage.writeBytes(
      AppConstants.keyMasterPasswordSalt,
      newSalt,
    );

    return true;
  }

  @override
  Future<Uint8List> getDatabaseKey() async {
    if (_databaseKey != null) return _databaseKey!;

    final dbKeyBytes = await _secureStorage.readBytes(AppConstants.keyDatabaseKey);
    if (dbKeyBytes == null) {
      throw StateError('Database key not available');
    }

    _databaseKey = Uint8List.fromList(dbKeyBytes);
    return _databaseKey!;
  }

  @override
  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isBiometricEnabled() async => true;

  @override
  Future<void> setBiometricEnabled(bool enabled) async {
    await _secureStorage.write(
      AppConstants.keyBiometricEnabled,
      enabled.toString(),
    );
  }

  @override
  Future<bool> authenticateWithBiometrics() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock Notally',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (authenticated && _databaseKey == null) {
        final dbKeyBytes = await _secureStorage.readBytes(AppConstants.keyDatabaseKey);
        if (dbKeyBytes != null) {
          _databaseKey = Uint8List.fromList(dbKeyBytes);
        }
        return _databaseKey != null;
      }
      return authenticated;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticateWithPassword(String password) async {
    final storedHashB64 = await _secureStorage.read(AppConstants.keyMasterPasswordHash);
    if (storedHashB64 == null) return false;

    final salt = await _secureStorage.readBytes(AppConstants.keyMasterPasswordSalt);
    if (salt == null) return false;

    final storedHash = base64Decode(storedHashB64);
    final valid = await _cryptoService.verifyPassword(
      password: password,
      salt: salt,
      expectedHash: storedHash,
    );

    if (valid && _databaseKey == null) {
      final dbKeyBytes = await _secureStorage.readBytes(AppConstants.keyDatabaseKey);
      if (dbKeyBytes != null) {
        _databaseKey = Uint8List.fromList(dbKeyBytes);
      }
    }

    return valid;
  }

  @override
  Future<int> getFailedAttempts() async {
    final value = await _secureStorage.read(AppConstants.keyFailedAttempts);
    if (value == null) return 0;
    return int.tryParse(value) ?? 0;
  }

  @override
  Future<void> incrementFailedAttempts() async {
    final current = await getFailedAttempts();
    await _secureStorage.write(
      AppConstants.keyFailedAttempts,
      (current + 1).toString(),
    );
  }

  @override
  Future<void> resetFailedAttempts() async {
    await _secureStorage.delete(AppConstants.keyFailedAttempts);
    await _secureStorage.delete(AppConstants.keyLockoutUntil);
  }

  @override
  Future<int> getLockoutDuration() async {
    final attempts = await getFailedAttempts();
    if (attempts < AppConstants.maxFailedAttempts) return 0;
    final multiplier = attempts - AppConstants.maxFailedAttempts + 1;
    return AppConstants.lockoutDurationSeconds * multiplier;
  }

  @override
  Future<DateTime?> getLockoutUntil() async {
    final value = await _secureStorage.read(AppConstants.keyLockoutUntil);
    if (value == null) return null;
    final ms = int.tryParse(value);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<void> setLockoutUntil(DateTime until) async {
    await _secureStorage.write(
      AppConstants.keyLockoutUntil,
      until.millisecondsSinceEpoch.toString(),
    );
  }

  @override
  void lock() {
    if (_databaseKey != null) {
      _databaseKey!.fillRange(0, _databaseKey!.length, 0);
      _databaseKey = null;
    }
  }
}
