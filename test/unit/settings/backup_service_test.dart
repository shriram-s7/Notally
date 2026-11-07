import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notally/features/notes/data/database.dart';
import 'package:notally/features/settings/data/backup_service.dart';

void main() {
  late ProviderContainer container;
  late BackupService backupService;

  setUp(() {
    container = ProviderContainer();
    backupService = container.read(backupServiceProvider);
  });

  tearDown(() {
    container.dispose();
  });

  // Create mock notes data to test with
  final testNotes = [
    NotesTableData(
      id: 1,
      title: 'Test Note 1',
      body: 'Body of note 1',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      isDeleted: false,
    ),
    NotesTableData(
      id: 2,
      title: 'Test Note 2',
      body: 'Body of note 2 (deleted)',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      isDeleted: true,
      deletedAt: DateTime.now().millisecondsSinceEpoch,
    ),
  ];

  const testPassword = 'secure_master_password';

  group('BackupService Crypto Round-Trip', () {
    test('Encrypt and decrypt round-trip produces exact original notes', () async {
      final encryptedContent = await backupService.encryptData(testNotes, testPassword);
      
      expect(encryptedContent, isNotNull);
      expect(encryptedContent, isNotEmpty);
      expect(encryptedContent.contains('\n'), isTrue);

      final decryptedNotes = await backupService.decryptData(encryptedContent, testPassword);

      expect(decryptedNotes, isNotNull);
      expect(decryptedNotes.length, equals(testNotes.length));
      
      // Verify first note
      expect(decryptedNotes[0].id, equals(testNotes[0].id));
      expect(decryptedNotes[0].title, equals(testNotes[0].title));
      expect(decryptedNotes[0].body, equals(testNotes[0].body));
      expect(decryptedNotes[0].isDeleted, equals(testNotes[0].isDeleted));

      // Verify second note
      expect(decryptedNotes[1].id, equals(testNotes[1].id));
      expect(decryptedNotes[1].title, equals(testNotes[1].title));
      expect(decryptedNotes[1].body, equals(testNotes[1].body));
      expect(decryptedNotes[1].isDeleted, equals(testNotes[1].isDeleted));
      expect(decryptedNotes[1].deletedAt, equals(testNotes[1].deletedAt));
    });

    test('Decrypting with wrong password throws FormatException with correct message', () async {
      final encryptedContent = await backupService.encryptData(testNotes, testPassword);

      expect(
        () => backupService.decryptData(encryptedContent, 'wrong_password'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Incorrect backup password. Please check your backup password and try again.'),
        )),
      );
    });

    test('Decrypting corrupted ciphertext throws FormatException (MAC check fails)', () async {
      final encryptedContent = await backupService.encryptData(testNotes, testPassword);
      final lines = encryptedContent.split('\n');
      final header = lines[0];
      final payloadBase64 = lines[1];

      final payloadBytes = base64Decode(payloadBase64);
      // Corrupt a byte in the ciphertext region (any byte after salt 16 + nonce 12 + authTag 16 = 44)
      payloadBytes[payloadBytes.length - 1] ^= 0xFF;

      final corruptedPayloadB64 = base64Encode(payloadBytes);
      final corruptedContent = '$header\n$corruptedPayloadB64';

      expect(
        () => backupService.decryptData(corruptedContent, testPassword),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Incorrect backup password. Please check your backup password and try again.'),
        )),
      );
    });

    test('Decrypting corrupted auth tag/MAC throws FormatException (MAC check fails)', () async {
      final encryptedContent = await backupService.encryptData(testNotes, testPassword);
      final lines = encryptedContent.split('\n');
      final header = lines[0];
      final payloadBase64 = lines[1];

      final payloadBytes = base64Decode(payloadBase64);
      // Corrupt a byte in the MAC region (bytes 28 to 44)
      payloadBytes[32] ^= 0xFF;

      final corruptedPayloadB64 = base64Encode(payloadBytes);
      final corruptedContent = '$header\n$corruptedPayloadB64';

      expect(
        () => backupService.decryptData(corruptedContent, testPassword),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Incorrect backup password. Please check your backup password and try again.'),
        )),
      );
    });

    test('Decrypting truncated payload throws FormatException', () async {
      final encryptedContent = await backupService.encryptData(testNotes, testPassword);
      final lines = encryptedContent.split('\n');
      final header = lines[0];
      final payloadBase64 = lines[1];

      final payloadBytes = base64Decode(payloadBase64);
      // Truncate payload bytes (e.g. keep only first 30 bytes, less than 44 bytes needed)
      final truncatedBytes = payloadBytes.sublist(0, 30);

      final truncatedPayloadB64 = base64Encode(truncatedBytes);
      final truncatedContent = '$header\n$truncatedPayloadB64';

      expect(
        () => backupService.decryptData(truncatedContent, testPassword),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Backup file is corrupted or not a valid backup file.'),
        )),
      );
    });
  });
}
