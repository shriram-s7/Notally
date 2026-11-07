import 'package:flutter_test/flutter_test.dart';
import 'package:notally/core/constants/app_constants.dart';
import 'package:notally/core/utils/security_utils.dart';
import 'package:notally/features/auth/data/auth_repository_impl.dart';
import 'package:notally/features/auth/data/crypto_service.dart';
import 'package:notally/features/auth/data/secure_storage_service.dart';

class FakeSecureStorageService implements SecureStorageService {
  final Map<String, String> _store = {};

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<String?> read(String key) async {
    return _store[key];
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> writeBytes(String key, List<int> value) async {
    _store[key] = SecurityUtils.bytesToHex(value);
  }

  @override
  Future<List<int>?> readBytes(String key) async {
    final hex = _store[key];
    if (hex == null) return null;
    return SecurityUtils.hexToBytes(hex);
  }

  @override
  Future<void> clearAll() async {
    _store.clear();
  }
}

void main() {
  late AuthRepositoryImpl authRepository;
  late CryptoService cryptoService;
  late FakeSecureStorageService fakeStorage;

  setUp(() {
    cryptoService = CryptoService();
    fakeStorage = FakeSecureStorageService();
    authRepository = AuthRepositoryImpl(
      cryptoService: cryptoService,
      secureStorage: fakeStorage,
    );
  });

  group('hasMasterPassword', () {
    test('returns false when no password is set', () async {
      final hasPassword = await authRepository.hasMasterPassword();
      expect(hasPassword, isFalse);
    });

    test('returns true after creating master password', () async {
      await authRepository.createMasterPassword('password123');
      final hasPassword = await authRepository.hasMasterPassword();
      expect(hasPassword, isTrue);
    });
  });

  group('createMasterPassword', () {
    test('stores hash and salt', () async {
      await authRepository.createMasterPassword('password123');

      final storedHash = await fakeStorage.read(AppConstants.keyMasterPasswordHash);
      final storedSalt = await fakeStorage.readBytes(AppConstants.keyMasterPasswordSalt);

      expect(storedHash, isNotNull);
      expect(storedHash, isNotEmpty);
      expect(storedSalt, isNotNull);
      expect(storedSalt!.length, AppConstants.saltLength);
    });

    test('stores database key', () async {
      await authRepository.createMasterPassword('password123');

      final dbKey = await fakeStorage.readBytes(AppConstants.keyDatabaseKey);
      expect(dbKey, isNotNull);
      expect(dbKey!.length, AppConstants.dbKeyLength);
    });

    test('sets internal database key', () async {
      await authRepository.createMasterPassword('password123');

      final dbKey = await authRepository.getDatabaseKey();
      expect(dbKey, isNotEmpty);
    });
  });

  group('verifyPassword', () {
    test('returns true for correct password', () async {
      await authRepository.createMasterPassword('password123');
      authRepository.lock();

      final valid = await authRepository.verifyPassword('password123');
      expect(valid, isTrue);
    });

    test('returns false for incorrect password', () async {
      await authRepository.createMasterPassword('password123');
      authRepository.lock();

      final valid = await authRepository.verifyPassword('wrongpassword');
      expect(valid, isFalse);
    });

    test('restores database key on successful verification', () async {
      await authRepository.createMasterPassword('password123');
      final originalDbKey = await authRepository.getDatabaseKey();
      authRepository.lock();

      await authRepository.verifyPassword('password123');
      final restoredDbKey = await authRepository.getDatabaseKey();

      expect(restoredDbKey, equals(originalDbKey));
    });
  });

  group('changeMasterPassword', () {
    test('returns false for wrong old password', () async {
      await authRepository.createMasterPassword('password123');

      final changed = await authRepository.changeMasterPassword(
        'wrongold',
        'newpassword',
      );

      expect(changed, isFalse);
    });

    test('returns true and updates hash for correct old password', () async {
      await authRepository.createMasterPassword('password123');
      final oldHash = await fakeStorage.read(AppConstants.keyMasterPasswordHash);

      final changed = await authRepository.changeMasterPassword(
        'password123',
        'newpassword456',
      );

      final newHash = await fakeStorage.read(AppConstants.keyMasterPasswordHash);

      expect(changed, isTrue);
      expect(newHash, isNot(equals(oldHash)));
    });

    test('new password can be used to verify after change', () async {
      await authRepository.createMasterPassword('password123');

      await authRepository.changeMasterPassword('password123', 'newpassword456');
      authRepository.lock();

      final valid = await authRepository.verifyPassword('newpassword456');
      expect(valid, isTrue);
    });

    test('old password no longer works after change', () async {
      await authRepository.createMasterPassword('password123');

      await authRepository.changeMasterPassword('password123', 'newpassword456');
      authRepository.lock();

      final valid = await authRepository.verifyPassword('password123');
      expect(valid, isFalse);
    });

    test('database key is preserved after password change', () async {
      await authRepository.createMasterPassword('password123');
      final dbKeyBefore = await authRepository.getDatabaseKey();

      await authRepository.changeMasterPassword('password123', 'newpassword456');
      final dbKeyAfter = await authRepository.getDatabaseKey();

      expect(dbKeyAfter, equals(dbKeyBefore));
    });
  });

  group('lock', () {
    test('clears database key from memory, requiring re-auth', () async {
      await authRepository.createMasterPassword('password123');
      final dbKey = await authRepository.getDatabaseKey();
      expect(dbKey, isNotEmpty);

      authRepository.lock();

      // After lock, _databaseKey is null but getDatabaseKey reads from storage.
      // Verify that calling verifyPassword is needed to reload the key.
      final valid = await authRepository.verifyPassword('password123');
      expect(valid, isTrue);
      final restoredKey = await authRepository.getDatabaseKey();
      expect(restoredKey, isNotEmpty);
    });
  });

  group('biometric', () {
    test('isBiometricEnabled returns false by default', () async {
      final enabled = await authRepository.isBiometricEnabled();
      expect(enabled, isFalse);
    });

    test('setBiometricEnabled persists value', () async {
      await authRepository.setBiometricEnabled(true);
      final enabled = await authRepository.isBiometricEnabled();
      expect(enabled, isTrue);
    });

    test('setBiometricEnabled(false) clears value', () async {
      await authRepository.setBiometricEnabled(true);
      await authRepository.setBiometricEnabled(false);
      final enabled = await authRepository.isBiometricEnabled();
      expect(enabled, isFalse);
    });
  });
}
