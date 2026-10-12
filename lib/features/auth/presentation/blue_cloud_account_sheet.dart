import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../../core/block_schedule/pomodoro_night_schedule_sync.dart';
import '../../../core/block_schedule/pomodoro_wake_lock_sync.dart';
import '../../../core/localization/settings_strings.dart';
import '../../../core/platform/blue_cloud_account_service.dart';

Future<void> showBlueCloudAccountSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _BlueCloudAccountSheet(),
    );

class _BlueCloudAccountSheet extends StatefulWidget {
  const _BlueCloudAccountSheet();

  @override
  State<_BlueCloudAccountSheet> createState() => _BlueCloudAccountSheetState();
}

class _BlueCloudAccountSheetState extends State<_BlueCloudAccountSheet> {
  final _account = BlueCloudAccountService();
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _signedInAs;
  String? _messageKey;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadSavedAccount();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _account.close();
    super.dispose();
  }

  Future<void> _loadSavedAccount() async {
    try {
      final username = await _account.username();
      if (!mounted || username == null || username.isEmpty) return;
      setState(() => _signedInAs = username);
      await _syncSchedule();
    } on BlueCloudAccountException catch (error) {
      if (mounted) {
        setState(() => _messageKey = error.code == 'secure_storage'
            ? 'bluecloud_storage_failed'
            : 'bluecloud_unavailable');
      }
    }
  }

  Future<void> _login() async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _messageKey = 'bluecloud_login_failed');
      return;
    }
    setState(() {
      _busy = true;
      _messageKey = null;
    });
    try {
      await _account.login(
        username: _username.text,
        password: _password.text,
      );
      _password.clear();
      final username = await _account.username();
      if (mounted) setState(() => _signedInAs = username);
      await _syncSchedule();
    } on BlueCloudAccountException catch (error) {
      if (mounted) {
        setState(() => _messageKey = switch (error.code) {
              'credentials' => 'bluecloud_login_failed',
              'secure_storage' => 'bluecloud_storage_failed',
              _ => 'bluecloud_network_failed',
            });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _busy = true;
      _messageKey = null;
    });
    try {
      await _account.loginWithGoogle();
      final username = await _account.username();
      if (mounted) setState(() => _signedInAs = username);
      await _syncSchedule();
    } on BlueCloudAccountException catch (error) {
      if (mounted) {
        setState(() => _messageKey = switch (error.code) {
              'google_cancelled' => 'bluecloud_google_cancelled',
              'secure_storage' => 'bluecloud_storage_failed',
              'network' => 'bluecloud_network_failed',
              _ => 'bluecloud_login_failed',
            });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncSchedule() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _messageKey = null;
    });
    try {
      final result =
          await PomodoroNightScheduleSync.syncFromBlueCloud(_account);
      final wakeResult = await PomodoroWakeLockSync.syncFromBlueCloud(_account);
      if (!mounted) return;
      setState(() => _messageKey = switch (wakeResult) {
            PomodoroWakeLockSyncResult.applied => 'bluecloud_wake_lock_applied',
            PomodoroWakeLockSyncResult.endedBySleep => 'bluecloud_sync_applied',
            _ => switch (result) {
                PomodoroNightSyncResult.applied => 'bluecloud_sync_applied',
                PomodoroNightSyncResult.noNightSchedule =>
                  'bluecloud_sync_empty',
                PomodoroNightSyncResult.commitmentLocked =>
                  'bluecloud_sync_locked',
              },
          });
    } on BlueCloudAccountException catch (error) {
      if (mounted) {
        setState(() => _messageKey = switch (error.code) {
              'login_required' => 'bluecloud_login_failed',
              'network' => 'bluecloud_network_failed',
              'secure_storage' => 'bluecloud_storage_failed',
              _ => 'bluecloud_unavailable',
            });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    await _account.logout();
    if (!mounted) return;
    setState(() {
      _signedInAs = null;
      _messageKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = SettingsStrings.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(strings.t('bluecloud_account'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(strings.t('bluecloud_sync_note')),
          const SizedBox(height: 20),
          if (_signedInAs == null) ...[
            if (Platform.isIOS) ...[
              FilledButton.icon(
                onPressed: _busy ? null : _loginWithGoogle,
                icon: const Icon(Icons.login),
                label: Text(strings.t('bluecloud_google_login')),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _username,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: strings.t('bluecloud_username'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: strings.t('bluecloud_password'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _login,
              icon: const Icon(Icons.login),
              label: Text(strings.t('bluecloud_login')),
            ),
          ] else ...[
            Text(strings
                .t('bluecloud_signed_in', args: {'username': _signedInAs!})),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _syncSchedule,
              icon: const Icon(Icons.sync),
              label: Text(strings.t('bluecloud_sync_action')),
            ),
            TextButton(
              onPressed: _busy ? null : _logout,
              child: Text(strings.t('bluecloud_logout')),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_messageKey case final message?) ...[
            const SizedBox(height: 12),
            Text(strings.t(message),
                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ],
        ],
      ),
    );
  }
}
