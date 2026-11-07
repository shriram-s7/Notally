import 'package:flutter_test/flutter_test.dart';
import 'package:notally/features/auth/data/crypto_service.dart';

void main() {
  late CryptoService cryptoService;

  setUp(() {
    cryptoService = CryptoService();
  });

  group('hashPassword', () {
    test('returns 32-byte hash', () async {
      final salt = List<int>.generate(16, (i) => i);
      final hash = await cryptoService.hashPassword('password123', salt: salt);

      expect(hash, isNotNull);
      expect(hash.length, 32);
    });

    test('same password and salt produce same hash', () async {
      final salt = List<int>.generate(16, (i) => i);
      final hash1 = await cryptoService.hashPassword('password123', salt: salt);
      final hash2 = await cryptoService.hashPassword('password123', salt: salt);

      expect(hash1, equals(hash2));
    });

    test('different passwords produce different hashes', () async {
      final salt = List<int>.generate(16, (i) => i);
      final hash1 = await cryptoService.hashPassword('password123', salt: salt);
      final hash2 = await cryptoService.hashPassword('password456', salt: salt);

      expect(hash1, isNot(equals(hash2)));
    });

    test('different salts produce different hashes', () async {
      final salt1 = List<int>.generate(16, (i) => i);
      final salt2 = List<int>.generate(16, (i) => i + 16);
      final hash1 = await cryptoService.hashPassword('password123', salt: salt1);
      final hash2 = await cryptoService.hashPassword('password123', salt: salt2);

      expect(hash1, isNot(equals(hash2)));
    });
  });

  group('verifyPassword', () {
    test('returns true for correct password', () async {
      final salt = List<int>.generate(16, (i) => i);
      final hash = await cryptoService.hashPassword('password123', salt: salt);

      final valid = await cryptoService.verifyPassword(
        password: 'password123',
        salt: salt,
        expectedHash: hash,
      );

      expect(valid, isTrue);
    });

    test('returns false for incorrect password', () async {
      final salt = List<int>.generate(16, (i) => i);
      final hash = await cryptoService.hashPassword('password123', salt: salt);

      final valid = await cryptoService.verifyPassword(
        password: 'wrongpassword',
        salt: salt,
        expectedHash: hash,
      );

      expect(valid, isFalse);
    });

    test('returns false for wrong salt', () async {
      final salt1 = List<int>.generate(16, (i) => i);
      final salt2 = List<int>.generate(16, (i) => i + 16);
      final hash = await cryptoService.hashPassword('password123', salt: salt1);

      final valid = await cryptoService.verifyPassword(
        password: 'password123',
        salt: salt2,
        expectedHash: hash,
      );

      expect(valid, isFalse);
    });

    test('returns false for truncated hash', () async {
      final salt = List<int>.generate(16, (i) => i);
      final hash = await cryptoService.hashPassword('password123', salt: salt);
      final truncatedHash = hash.sublist(0, 16);

      final valid = await cryptoService.verifyPassword(
        password: 'password123',
        salt: salt,
        expectedHash: truncatedHash,
      );

      expect(valid, isFalse);
    });
  });
}
