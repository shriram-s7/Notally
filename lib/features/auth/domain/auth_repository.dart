import 'dart:typed_data';

abstract class AuthRepository {
  Future<bool> hasMasterPassword();
  Future<void> createMasterPassword(String password);
  Future<bool> verifyPassword(String password);
  Future<bool> changeMasterPassword(String oldPassword, String newPassword);
  Future<Uint8List> getDatabaseKey();

  Future<bool> isBiometricAvailable();
  Future<bool> isBiometricEnabled();
  Future<void> setBiometricEnabled(bool enabled);
  Future<bool> authenticateWithBiometrics();
  Future<bool> authenticateWithPassword(String password);

  Future<int> getFailedAttempts();
  Future<void> incrementFailedAttempts();
  Future<void> resetFailedAttempts();
  Future<int> getLockoutDuration();
  Future<DateTime?> getLockoutUntil();
  Future<void> setLockoutUntil(DateTime until);

  void lock();
}
