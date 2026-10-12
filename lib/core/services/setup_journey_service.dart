import 'package:hive_flutter/hive_flutter.dart';

import '../library/personal_library_store.dart';
import 'isle_survival_backup_service.dart';
import 'isle_user_defaults.dart';
/// 첫 사용·피드 셋업 진행도 — 로컬 Hive만 사용
class SetupJourneyService {
  SetupJourneyService._();

  static Box<String> get _box => Hive.box<String>('isle_cache');
  static const _stepPrefix = 'isle_setup_step_';

  static bool isStepDone(String stepId) => _box.get('$_stepPrefix$stepId') == 'true';

  static Future<void> markStepDone(String stepId) =>
      _box.put('$_stepPrefix$stepId', 'true');

  static bool get hasRealLibraryContent => PersonalLibraryStore.loadEntries().isNotEmpty;

  static int get completedCount {
    var n = 0;
    for (final id in _allStepIds) {
      if (stepDone(id)) n++;
    }
    return n;
  }

  static const _allStepIds = [
    'tour',
    'icloud_backup',
    'interests',
    'system_apps_lock',
    'browser_youtube_tracking',
    'import_content',
    'youtube_focus',
    'first_archive',
  ];

  static int get totalSteps => _allStepIds.length;

  static double get progress =>
      totalSteps == 0 ? 0 : completedCount / totalSteps;

  static bool get isSetupComplete =>
      hasRealLibraryContent && isStepDone('tour') && isStepDone('import_content');

  /// 피드에 샘플 카드 대신 셋업 여정을 강조할지
  static bool get shouldHighlightSetup =>
      !isSetupComplete || !hasRealLibraryContent;

  static bool stepDone(String id) {
    if (id == 'import_content') {
      return isStepDone(id) || hasRealLibraryContent;
    }
    if (id == 'icloud_backup') {
      return isStepDone(id) ||
          IsleUserDefaults.survivalBackupGuideDismissed ||
          !IsleSurvivalBackupService.needsIcloudFolderPrompt();
    }
    return isStepDone(id);
  }
}
