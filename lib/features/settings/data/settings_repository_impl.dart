import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  static const _keyLastActivity = 'last_activity';

  @override
  Future<void> updateLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastActivity, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Future<DateTime?> getLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_keyLastActivity);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<void> setKeepUnlockedDuration(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyKeepUnlockedDuration, seconds);
  }

  @override
  Future<int> getKeepUnlockedDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConstants.keyKeepUnlockedDuration) ?? 0;
  }

  @override
  Future<void> setKeepUnlockedUntil(DateTime until) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      AppConstants.keyKeepUnlockedUntil,
      until.millisecondsSinceEpoch,
    );
  }

  @override
  Future<DateTime?> getKeepUnlockedUntil() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(AppConstants.keyKeepUnlockedUntil);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<void> clearKeepUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyKeepUnlockedDuration);
    await prefs.remove(AppConstants.keyKeepUnlockedUntil);
  }
}
