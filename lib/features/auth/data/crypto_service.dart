import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import '../../../core/constants/app_constants.dart';

class CryptoService {
  Future<List<int>> hashPassword(String password, {required List<int> salt}) async {
    final algorithm = Argon2id(
      parallelism: AppConstants.argonParallelism,
      memory: AppConstants.argonMemoryCost,
      iterations: AppConstants.argonIterations,
      hashLength: AppConstants.argonHashLength,
    );

    final secretKey = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    return secretKey.extractBytes();
  }

  Future<bool> verifyPassword({
    required String password,
    required List<int> salt,
    required List<int> expectedHash,
  }) async {
    final actualHash = await hashPassword(password, salt: salt);
    if (actualHash.length != expectedHash.length) return false;
    var result = 0;
    for (var i = 0; i < actualHash.length; i++) {
      result |= actualHash[i] ^ expectedHash[i];
    }
    return result == 0;
  }
}
