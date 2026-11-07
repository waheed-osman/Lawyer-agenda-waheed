import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Security {
  /// Set while a system dialog (camera, file picker, share sheet, biometric prompt)
  /// is open so the app does not re-lock when it returns to the foreground.
  static bool suspend = false;

  /// Increment to lock the app immediately.
  static final ValueNotifier<int> lockSignal = ValueNotifier(0);

  static final _auth = LocalAuthentication();

  static Future<T> guard<T>(Future<T> Function() f) async {
    suspend = true;
    try {
      return await f();
    } finally {
      suspend = false;
    }
  }

  static String _hash(String salt, String pw) => sha256.convert(utf8.encode('$salt:$pw')).toString();

  static Future<bool> hasPassword() async {
    final p = await SharedPreferences.getInstance();
    return (p.getString('pw_hash') ?? '').isNotEmpty;
  }

  static Future<void> setPassword(String pw) async {
    final p = await SharedPreferences.getInstance();
    final r = Random.secure();
    final salt = base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
    await p.setString('pw_salt', salt);
    await p.setString('pw_hash', _hash(salt, pw));
  }

  static Future<bool> verify(String pw) async {
    final p = await SharedPreferences.getInstance();
    final salt = p.getString('pw_salt') ?? '';
    return _hash(salt, pw) == (p.getString('pw_hash') ?? '');
  }

  static Future<void> removePassword() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('pw_hash');
    await p.remove('pw_salt');
    await p.setBool('bio', false);
  }

  static Future<bool> biometricEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('bio') ?? false;
  }

  static Future<void> setBiometric(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('bio', v);
  }

  static Future<bool> biometricAvailable() async {
    try {
      return await _auth.canCheckBiometrics && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    return guard(() async {
      try {
        return await _auth.authenticate(
          localizedReason: 'أكّد هويتك لفتح أجندة المحامي',
          options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
        );
      } catch (_) {
        return false;
      }
    });
  }
}
