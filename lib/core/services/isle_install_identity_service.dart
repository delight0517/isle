import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_release_info.dart';
import 'isle_app_log_service.dart';

/// 재설치 vs 업데이트 구분 — install id는 Keychain에만 남음.
class IsleInstallIdentityService {
  IsleInstallIdentityService._();

  static const _installIdKey = 'isle_install_id_v1';
  static const _lastBuildKey = 'isle_install_last_build_v1';

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> recordLaunch() async {
    try {
      var id = await _storage.read(key: _installIdKey);
      if (id == null || id.isEmpty) {
        id = _newId();
        await _storage.write(key: _installIdKey, value: id);
        IsleAppLogService.log('Install identity: new $id');
      }
      await _storage.write(
        key: _lastBuildKey,
        value: AppReleaseInfo.buildNumber,
      );
    } catch (e) {
      IsleAppLogService.log('Install identity record failed: $e', level: IsleLogLevel.warn);
    }
  }

  static Future<bool> hadPriorInstallOnDevice() async {
    try {
      final id = await _storage.read(key: _installIdKey);
      return id != null && id.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> priorBuildOnDevice() async {
    try {
      return await _storage.read(key: _lastBuildKey);
    } catch (_) {
      return null;
    }
  }

  static String _newId() {
    final r = Random.secure();
    final n = r.nextInt(1 << 32);
    return '${DateTime.now().toUtc().millisecondsSinceEpoch}-$n';
  }
}
