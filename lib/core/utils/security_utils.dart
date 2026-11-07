import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/foundation.dart';

class SecurityUtils {
  SecurityUtils._();

  static final _random = Random.secure();

  static List<int> generateSalt(int length) {
    return List.generate(length, (_) => _random.nextInt(256));
  }

  static Uint8List generateSecureKey(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  static void copyToClipboardWithClear(String text, Duration clearAfter) {
    Clipboard.setData(ClipboardData(text: text));
    Timer(clearAfter, () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  static bool isDebugMode() {
    return !kDebugMode;
  }

  static bool isRootedDevice() {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) return false;
    if (Platform.isAndroid) {
      try {
        return Process.runSync('su', ['echo', 'test']).exitCode == 0;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  static String bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static List<int> hexToBytes(String hex) {
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}
