import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_release_info.dart';
import '../intervention/website_block_store.dart';
import '../youtube/block_keyword_policy.dart';
import '../youtube/content_filter_store.dart';
import 'isle_app_log_service.dart';
import 'isle_install_identity_service.dart';

/// 앱 업데이트 = 데이터 유지 + 스키마만 단계적 보정 (초기화 금지).
class IsleDataMigrationService {
  IsleDataMigrationService._();

  static const dataSchemaVersion = 5;
  static const _schemaKey = 'isle_data_schema_v';
  static const _lastBuildKey = 'isle_last_app_build';

  static Box<String> get _prefs => Hive.box<String>('isle_cache');

  static Future<void> runAfterStoresOpen() async {
    final from = int.tryParse(_prefs.get(_schemaKey) ?? '') ?? 0;

    if (from < 1) await _migrateV1_installLineage();
    if (from < 2) await _migrateV2_sanitizeKeywords();
    if (from < 3) await _migrateV3_sanitizeWebsiteDomains();
    if (from < 4) await _migrateV4_stripBroadYoutubeKeywords();
    if (from < 5) await _migrateV5_postUpdateSurvivalSync();

    final build = AppReleaseInfo.buildNumber;
    final prev = _prefs.get(_lastBuildKey);
    if (prev != null && prev != build) {
      IsleAppLogService.log(
        'App update $prev → $build — local data preserved (migration v$dataSchemaVersion)',
      );
    } else if (from == 0) {
      IsleAppLogService.log('First data migration baseline v$dataSchemaVersion');
    }

    await _prefs.put(_schemaKey, '$dataSchemaVersion');
    await _prefs.put(_lastBuildKey, build);
    await IsleInstallIdentityService.recordLaunch();
  }

  static Future<void> _migrateV1_installLineage() async {
    await IsleInstallIdentityService.recordLaunch();
  }

  static Future<void> _migrateV2_sanitizeKeywords() async {
    await ContentFilterStore.ensureKeywordsSanitized();
  }

  static Future<void> _migrateV3_sanitizeWebsiteDomains() async {
    await WebsiteBlockStore.ensureOpen();
    await WebsiteBlockStore.ensureDomainsSanitized();
  }

  static Future<void> _migrateV4_stripBroadYoutubeKeywords() async {
    final keywords = ContentFilterStore.loadKeywords();
    final clean = BlockKeywordPolicy.sanitizeStoredKeywords(keywords);
    if (clean.length != keywords.length) {
      await ContentFilterStore.saveKeywords(clean);
      IsleAppLogService.log(
        'Migration v4: removed ${keywords.length - clean.length} broad YouTube keywords',
      );
    }
  }

  static Future<void> _migrateV5_postUpdateSurvivalSync() async {
    // Survival/keychain sync는 bootstrapOnLaunch에서 수행.
  }
}
