import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/youtube/youtube_playback_error_probe.dart';

void main() {
  test('prepares existing and SPA videos for inline playback without playing',
      () {
    final result = Process.runSync('node', [
      '-e',
      r"""
const assert=require('node:assert/strict'); const vm=require('node:vm');
let observer, played=0;
const video=()=>({attrs:new Set(),hasAttribute(k){return this.attrs.has(k);},setAttribute(k){this.attrs.add(k);},play(){played++;}});
const videos=[video()];
vm.runInNewContext(SCRIPT,{window:{},document:{querySelectorAll:()=>videos,querySelector:()=>null,documentElement:{}},location:{pathname:'/results'},MutationObserver:class{constructor(fn){observer=fn;}observe(){}},setInterval(){}});
assert.ok(videos[0].attrs.has('playsinline'));
videos.push(video());observer();assert.ok(videos[1].attrs.has('webkit-playsinline'));
assert.equal(played,0,'inline setup must preserve user playback choice');
"""
          .replaceFirst('SCRIPT', jsonEncode(YoutubePlaybackErrorProbe.build()))
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
}
