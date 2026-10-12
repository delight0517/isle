import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/services/isle_survival_backup_service.dart';

void main() {
  test('isRestrictedBackupPath detects File Provider Storage', () {
    const path =
        '/private/var/mobile/Containers/Shared/AppGroup/BE0AB88A/File Provider Storage/Backup';
    expect(IsleSurvivalBackupService.isRestrictedBackupPath(path), isTrue);
  });

  test('isRestrictedBackupPath allows normal iCloud Drive path', () {
    const path =
        '/private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/Isle Backup';
    expect(IsleSurvivalBackupService.isRestrictedBackupPath(path), isFalse);
  });
}
