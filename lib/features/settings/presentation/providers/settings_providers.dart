import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/settings_repository_impl.dart';
import '../../domain/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl();
});
