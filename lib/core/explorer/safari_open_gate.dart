import '../explorer/explorer_site.dart';
import '../guard/isle_block_boundary.dart';

/// 인앱 Safari(custom) — [IsleBlockBoundary]의 safari 표면 래퍼
class SafariOpenGate {
  SafariOpenGate._();

  static String? denyNavigation(String url) =>
      IsleBlockBoundary.denyNavigation(site: ExplorerSite.custom, url: url);

  static String? denyEntry({String? url}) =>
      IsleBlockBoundary.denyEntry(site: ExplorerSite.custom, url: url);

  static bool shouldApplyScheduleDomainShield(String url) =>
      IsleBlockBoundary.appliesScheduleDomainShield(ExplorerSite.custom, url: url);
}
