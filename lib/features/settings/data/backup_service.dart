import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/security_utils.dart';
import '../../notes/data/database.dart';
import '../../notes/presentation/providers/notes_providers.dart';

class BackupService {
  final Ref _ref;

  BackupService(this._ref);

  /// Core encryption logic - serializes, derives key, and encrypts the notes list.
  Future<String> encryptData(List<Note> notes, String password) async {
    // 1. Serialize all notes to JSON
    final jsonList = notes.map((note) => note.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    final clearTextBytes = utf8.encode(jsonString);

    // 2. Generate 16-byte random salt and 12-byte random nonce
    final salt = SecurityUtils.generateSalt(16);
    final nonce = SecurityUtils.generateSalt(12);

    // 3. Derive 256-bit key using Argon2id
    final argon = Argon2id(
      parallelism: 4,
      memory: 65536,
      iterations: 10,
      hashLength: 32,
    );
    final secretKey = await argon.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final derivedKeyBytes = await secretKey.extractBytes();

    // 4. Encrypt using AES-256-GCM
    final aesGcm = AesGcm.with256bits();
    final secretBox = await aesGcm.encrypt(
      clearTextBytes,
      secretKey: SecretKey(derivedKeyBytes),
      nonce: nonce,
    );

    final authTag = secretBox.mac.bytes;
    final ciphertext = secretBox.cipherText;

    // 5. Build base64 payload: salt + nonce + authTag + ciphertext
    final payloadBytes = BytesBuilder();
    payloadBytes.add(salt);
    payloadBytes.add(nonce);
    payloadBytes.add(authTag);
    payloadBytes.add(ciphertext);

    final payloadBase64 = base64Encode(payloadBytes.takeBytes());

    // 6. Build unencrypted header
    final header = {
      "version": 1,
      "kdf": "Argon2id",
      "iterations": 10,
      "memory": 65536,
      "parallelism": 4,
    };
    final headerLine = jsonEncode(header);
    return "$headerLine\n$payloadBase64";
  }

  /// Core decryption logic - parses file content, derives key, decrypts, and deserializes.
  Future<List<Note>> decryptData(String fileContent, String password) async {
    // Normalize line endings (\r\n → \n) and split into lines
    final lines = fileContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    if (lines.length < 2) {
      throw const FormatException('Backup file is corrupted or not a valid backup file.');
    }

    // Header is always the first line — trim whitespace for safety
    final headerLine = lines[0].trim();
    // Payload is everything after line 0, joined (handles any line-wrapped base64)
    final payloadBase64 = lines.sublist(1).join('').trim();

    if (headerLine.isEmpty || payloadBase64.isEmpty) {
      throw const FormatException('Backup file is corrupted or not a valid backup file.');
    }

    // 1. Parse header
    Map<String, dynamic> header;
    try {
      header = jsonDecode(headerLine) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('Backup file is corrupted or not a valid backup file.');
    }

    final version = header['version'];
    final kdf = header['kdf'];
    final iterations = header['iterations'] as int?;
    final memory = header['memory'] as int?;
    final parallelism = header['parallelism'] as int?;

    if (version != 1 || kdf != 'Argon2id' || iterations == null || memory == null || parallelism == null) {
      throw const FormatException('Backup file is corrupted or not a valid backup file.');
    }

    // 2. Decode base64 payload
    Uint8List payloadBytes;
    try {
      payloadBytes = base64Decode(payloadBase64);
    } catch (_) {
      throw const FormatException('Backup file is corrupted or not a valid backup file.');
    }

    // Must be at least salt (16) + nonce (12) + authTag (16) = 44 bytes
    if (payloadBytes.length < 44) {
      throw const FormatException('Backup file is corrupted or not a valid backup file.');
    }

    final salt = payloadBytes.sublist(0, 16);
    final nonce = payloadBytes.sublist(16, 28);
    final authTag = payloadBytes.sublist(28, 44);
    final ciphertext = payloadBytes.sublist(44);

    // 3. Derive key using the params stored in the header
    final argon = Argon2id(
      parallelism: parallelism,
      memory: memory,
      iterations: iterations,
      hashLength: 32,
    );
    
    final secretKey = await argon.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final derivedKeyBytes = await secretKey.extractBytes();

    // 4. Decrypt — wrong password causes authentication tag mismatch
    final aesGcm = AesGcm.with256bits();
    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(authTag),
    );

    List<int> decryptedBytes;
    try {
      decryptedBytes = await aesGcm.decrypt(
        secretBox,
        secretKey: SecretKey(derivedKeyBytes),
      );
    } catch (_) {
      throw const FormatException('Incorrect backup password. Please check your backup password and try again.');
    }

    // 5. Parse JSON
    try {
      final decryptedString = utf8.decode(decryptedBytes);
      final List<dynamic> jsonList = jsonDecode(decryptedString) as List<dynamic>;
      return jsonList.map((item) => Note.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      throw const FormatException('Backup data is corrupted and could not be restored.');
    }
  }


  Future<void> exportBackup(String password) async {
    final db = await _ref.read(databaseProvider.future);
    final notes = await db.getAllNotesForBackup();

    final fileContent = await encryptData(notes, password);

    // Write to temp directory and share
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final dateStr = DateTime.now().toLocal().toString().split(' ')[0];
    final file = File(p.join(tempDir.path, 'notally_backup_$timestamp.enc'));
    
    try {
      await file.writeAsString(fileContent);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/octet-stream')],
          subject: 'Notally Encrypted Backup - $dateStr',
          text: 'Encrypted backup attached. You will need your BACKUP PASSWORD (not your app-unlock password) to restore this. Do not forward this email or share the attachment.',
        ),
      );
    } finally {
      // Clean up the temp file
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<List<Note>?> importBackup(String password) async {
    // 1. Pick file
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) {
      return null; // User cancelled
    }

    final file = File(result.files.single.path!);
    final fileContent = await file.readAsString();

    return decryptData(fileContent, password);
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref);
});
