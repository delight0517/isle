import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/social/instagram_media_viewer_script.dart';

void main() {
  test('feed stays nonimmersive and automatic checks respect pause', () {
    final result = Process.runSync('node', [
      '-e',
      r"""
const assert = require('node:assert/strict'); const vm = require('node:vm');
let played=0, clicks=0; const posts=[], timers=[];
const v={paused:true,muted:true,defaultMuted:true,volume:0,hasAttribute:()=>false,removeAttribute(){},play(){played++;return Promise.resolve();},getBoundingClientRect:()=>({width:400,height:500,top:0,bottom:500})};
const window={innerWidth:400,innerHeight:800,IsleIgMedia:{postMessage:x=>posts.push(x)}};
const location={pathname:'/'};
const document={querySelectorAll:()=>[v],querySelector:s=>s==='video'?v:null,addEventListener(){},elementFromPoint:()=>({dispatchEvent(){clicks++;}})};
vm.runInNewContext(SCRIPT,{window,document,location,setTimeout:fn=>timers.push(fn)});
assert.equal(posts.length,0,'normal feed is not a fullscreen viewer');
location.pathname='/reel/test/'; timers.shift()();
assert.deepEqual(posts,['open']);
assert.equal(played,0,'automatic unmute must not resume paused video');
assert.equal(clicks,0,'must not synthesize clicks');
window.__isleIgForceUnmute(true); assert.equal(played,1,'explicit sound action may resume');
"""
          .replaceFirst(
              'SCRIPT', jsonEncode(InstagramMediaViewerScript.install))
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
}
