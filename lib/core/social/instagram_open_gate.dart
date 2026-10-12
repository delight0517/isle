import '../explorer/explorer_site.dart';
import '../guard/isle_block_boundary.dart';

/// Instagram 전용 — [IsleBlockBoundary]의 instagram 표면 래퍼
class InstagramOpenGate {
  InstagramOpenGate._();

  static String? denyDedicatedTab({String? url, bool dmOnly = false}) =>
      IsleBlockBoundary.denyEntry(
        site: ExplorerSite.instagram,
        url: url,
      );

  static bool shouldApplyScheduleDomainShield({String? url}) =>
      IsleBlockBoundary.appliesScheduleDomainShield(ExplorerSite.custom, url: url);
}
