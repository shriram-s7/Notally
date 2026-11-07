import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/main_app_widget.dart';
import 'core/utils/app_startup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStartup.initialize();
  runApp(const ProviderScope(child: MainApp()));
}
