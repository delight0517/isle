import 'isle_survival_backup_service.dart';

/// Hive 저장 후 디바운스 백업 트리거 (재설치 생존)
void isleNotifyLocalDataChanged() {
  IsleSurvivalBackupService.onDataChanged();
}
