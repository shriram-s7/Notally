class AppConstants {
  AppConstants._();

  static const String appName = 'Notally';
  static const String appVersion = '1.0.0';
  static const String dbName = 'notally.db';

  static const String keyMasterPasswordHash = 'master_password_hash';
  static const String keyMasterPasswordSalt = 'master_password_salt';
  static const String keyDatabaseKey = 'database_key';
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyFailedAttempts = 'failed_attempts';
  static const String keyLockoutUntil = 'lockout_until';
  static const String keyKeepUnlockedDuration = 'keep_unlocked_duration';
  static const String keyKeepUnlockedUntil = 'keep_unlocked_until';

  static const int minPasswordLength = 8;

  static const int argonMemoryCost = 65536;
  static const int argonParallelism = 4;
  static const int argonIterations = 10;
  static const int argonHashLength = 32;
  static const int saltLength = 32;
  static const int dbKeyLength = 32;

  static const int maxFailedAttempts = 5;
  static const int lockoutDurationSeconds = 30;
  static const int lockoutMultiplier = 2;

  static const Duration autoSaveDelay = Duration(milliseconds: 800);
  static const Duration clipboardClearDelay = Duration(seconds: 30);
  static const Duration inactivityCheckInterval = Duration(seconds: 5);


}
