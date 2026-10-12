import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/explorer/explorer_site.dart';
import 'package:isle/core/guard/isle_block_boundary.dart';

void main() {
  test('youtube dedicated never applies schedule domain layer', () {
    final s = IsleBlockBoundary.surfaceFor(site: ExplorerSite.youtube);
    expect(s, IsleAppSurface.youtubeDedicated);
    expect(
      IsleBlockBoundary.appliesLayer(s, BlockLayer.scheduleDomain),
      isFalse,
    );
    expect(
      IsleBlockBoundary.appliesLayer(s, BlockLayer.scheduleTarget),
      isTrue,
    );
    expect(
      IsleBlockBoundary.appliesScheduleDomainShield(ExplorerSite.youtube),
      isFalse,
    );
  });

  test('youtube in safari applies schedule domain', () {
    final s = IsleBlockBoundary.surfaceFor(
      site: ExplorerSite.custom,
      url: 'https://m.youtube.com',
    );
    expect(s, IsleAppSurface.youtubeInSafari);
    expect(
      IsleBlockBoundary.appliesLayer(s, BlockLayer.scheduleDomain),
      isTrue,
    );
    expect(
      IsleBlockBoundary.appliesScheduleDomainShield(
        ExplorerSite.custom,
        url: 'https://example.com',
      ),
      isTrue,
    );
  });

  test('instagram dedicated has watch limit not safari escape', () {
    final s = IsleBlockBoundary.surfaceFor(site: ExplorerSite.instagram);
    expect(IsleBlockBoundary.appliesLayer(s, BlockLayer.watchLimit), isTrue);
    expect(IsleBlockBoundary.appliesLayer(s, BlockLayer.safariEscape), isFalse);
  });

  test('surfaces are distinct for same host in different explorers', () {
    final dedicated = IsleBlockBoundary.surfaceFor(site: ExplorerSite.youtube);
    final inSafari = IsleBlockBoundary.surfaceFor(
      site: ExplorerSite.custom,
      url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    );
    expect(dedicated, isNot(equals(inSafari)));
    expect(
      IsleBlockBoundary.appliesLayer(dedicated, BlockLayer.scheduleDomain),
      isFalse,
    );
    expect(
      IsleBlockBoundary.appliesLayer(inSafari, BlockLayer.scheduleDomain),
      isTrue,
    );
  });
}
