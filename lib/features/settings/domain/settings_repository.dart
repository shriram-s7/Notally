abstract class SettingsRepository {
  Future<void> updateLastActivity();
  Future<DateTime?> getLastActivity();

  Future<void> setKeepUnlockedDuration(int seconds);
  Future<int> getKeepUnlockedDuration();
  Future<void> setKeepUnlockedUntil(DateTime until);
  Future<DateTime?> getKeepUnlockedUntil();
  Future<void> clearKeepUnlocked();
}
