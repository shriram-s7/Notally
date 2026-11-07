import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> read(String key) async {
    return _storage.read(key: key);
  }

  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  Future<void> writeBytes(String key, List<int> value) async {
    await _storage.write(key: key, value: base64Encode(value));
  }

  Future<List<int>?> readBytes(String key) async {
    final value = await _storage.read(key: key);
    if (value == null) return null;
    return base64Decode(value);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
