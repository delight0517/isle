import 'dart:io' show Platform;

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/isle_external_launch_guard.dart';

/// 인스타·페이스북 공유 (스토리/피드는 OS 공유 시트 → 인스타 선택)
class SocialShareService {
  SocialShareService._();

  static Future<void> shareToInstagramStory({String? imagePath, String? text}) async {
    if (imagePath != null && imagePath.isNotEmpty) {
      await Share.shareXFiles(
        [XFile(imagePath)],
        text: text,
        subject: 'Isle → Instagram',
      );
      return;
    }
    if (text != null && text.isNotEmpty) {
      await Share.share(text, subject: 'Isle');
    }
  }

  static Future<void> openInstagramProfile(String handle) async {
    final h = handle.replaceAll('@', '').trim();
    final app = Uri.parse('instagram://user?username=$h');
    final web = Uri.parse('https://www.instagram.com/$h/');
    if (await canLaunchUrl(app)) {
      await IsleExternalLaunchGuard.launchAllowed(app.toString());
    } else {
      await IsleExternalLaunchGuard.launchAllowed(web.toString());
    }
  }

  /// 언팔로우는 인스타 앱/웹 프로필에서 사용자가 직접 수행
  static Future<void> openInstagramUnfollow(String handle) async {
    await openInstagramProfile(handle);
  }

  static Future<void> openFacebookProfile(String pathOrId) async {
    final id = pathOrId.trim();
    final web = Uri.parse('https://m.facebook.com/$id');
    if (Platform.isAndroid) {
      final app = Uri.parse('fb://facewebmodal/f?href=${Uri.encodeComponent(web.toString())}');
      if (await canLaunchUrl(app)) {
        await IsleExternalLaunchGuard.launchAllowed(app.toString());
        return;
      }
    }
    await IsleExternalLaunchGuard.launchAllowed(web.toString());
  }

  static Future<void> sharePostCaption(String caption, {String? mediaPath}) async {
    if (mediaPath != null && mediaPath.isNotEmpty) {
      await Share.shareXFiles([XFile(mediaPath)], text: caption);
    } else {
      await Share.share(caption);
    }
  }
}
