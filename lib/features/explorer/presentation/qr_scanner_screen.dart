import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/navigation/link_router.dart';
import '../../../core/platform/platform_block_intent.dart';
import '../../../core/safety/content_safety_guard.dart';
import '../../../shared/widgets/isle_sheet.dart';

/// QR → LinkRouter → Safe Browser (Safari로 튕기지 않음)
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _sheetOpen = false;
  String? _lastHandled;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_sheetOpen || !mounted) return;
    final value = capture.barcodes
        .map((b) => b.rawValue?.trim())
        .whereType<String>()
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (value.isEmpty || value == _lastHandled) return;

    _lastHandled = value;
    await _controller.stop();
    if (!mounted) return;

    if (LinkRouter.isNonHttpAppLink(value)) {
      final uri = LinkRouter.resolveAppLaunchUri(value);
      if (uri != null) {
        await _showAppHandoffSheet(raw: value, uri: uri, allowInApp: false);
        return;
      }
    }

    if (LinkRouter.isHttpUrl(value) || LinkRouter.normalizeHttpUrl(value) != null) {
      final normalized = LinkRouter.normalizeHttpUrl(value) ?? value.trim();
      if (LinkRouter.prefersNativeAppLaunch(normalized)) {
        await _showAppHandoffSheet(
          raw: normalized,
          uri: Uri.parse(normalized),
          allowInApp: true,
        );
        return;
      }
      await _showUrlSheet(value);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR에 웹 주소가 없어요. 텍스트만 담긴 코드예요.')),
    );
    _lastHandled = null;
    await _controller.start();
  }

  Future<void> _showUrlSheet(String raw) async {
    final normalized = LinkRouter.normalizeHttpUrl(raw) ?? raw.trim();
    final safety = ContentSafetyGuard.matchUrl(normalized);

    _sheetOpen = true;
    final open = await showIsleModalSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('QR에서 링크를 찾았어요', style: IsleText.subtitle()),
            const SizedBox(height: 12),
            SelectableText(
              normalized,
              style: IsleText.body().copyWith(fontSize: 14),
            ),
            if (safety != null) ...[
              const SizedBox(height: 12),
              Text(
                safety.snackMessage,
                style: IsleText.caption(color: IsleColors.danger),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: safety != null ? null : () => Navigator.pop(ctx, true),
              child: const Text('앱 안에서 열기'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
          ],
        ),
      ),
    );
    _sheetOpen = false;
    if (!mounted) return;

    if (open == true) {
      final route = LinkRouter.safeBrowserRoute(raw);
      if (route != null) {
        context.push(route);
        return;
      }
    }

    _lastHandled = null;
    await _controller.start();
  }

  Future<void> _showAppHandoffSheet({
    required String raw,
    required Uri uri,
    required bool allowInApp,
  }) async {
    _sheetOpen = true;
    final action = await showIsleModalSheet<_AppHandoffAction>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('앱 링크예요', style: IsleText.subtitle()),
            const SizedBox(height: 8),
            Text(
              allowInApp
                  ? '결제·메신저 앱으로 열거나 Isle 안전 브라우저에서 볼 수 있어요.'
                  : '웹 주소가 아니라 다른 앱을 여는 링크입니다.',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            const SizedBox(height: 12),
            SelectableText(raw, style: IsleText.body().copyWith(fontSize: 14)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, _AppHandoffAction.nativeApp),
              child: const Text('해당 앱에서 열기'),
            ),
            if (allowInApp) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, _AppHandoffAction.inApp),
                child: const Text('Isle에서 열기'),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _AppHandoffAction.cancel),
              child: const Text('취소'),
            ),
          ],
        ),
      ),
    );
    _sheetOpen = false;
    if (!mounted) return;

    switch (action) {
      case _AppHandoffAction.nativeApp:
        final ok = await LinkRouter.launchNativeApp(uri);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이 링크를 열 앱을 찾지 못했어요. 앱이 설치돼 있는지 확인해 주세요.')),
          );
          _lastHandled = null;
          await _controller.start();
          return;
        }
        if (mounted) context.pop();
      case _AppHandoffAction.inApp:
        final route = LinkRouter.safeBrowserRoute(raw);
        if (route != null) {
          context.push(route);
          return;
        }
        _lastHandled = null;
        await _controller.start();
      case _AppHandoffAction.cancel:
      case null:
        _lastHandled = null;
        await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('QR로 열기'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
            Positioned(
              left: 24,
              right: 24,
              top: MediaQuery.paddingOf(context).top + 72,
              child: Text(
                PlatformBlockCopy.qrScannerHint,
                textAlign: TextAlign.center,
                style: IsleText.caption(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AppHandoffAction { nativeApp, inApp, cancel }
