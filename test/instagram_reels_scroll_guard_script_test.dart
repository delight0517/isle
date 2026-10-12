import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/social/instagram_reels_scroll_guard_script.dart';

void main() {
  test('counts distinct visible videos, preserves the guard after continue',
      () {
    final script = InstagramReelsScrollGuardScript.install(threshold: 3);
    final result = Process.runSync('node', [
      '-e',
      r"""
const assert = require('node:assert/strict');
const vm = require('node:vm');
const nodes = new Map(); let onPlay; let paused = 0;
const document = {
  getElementById: id => nodes.get(id),
  querySelectorAll: () => [{pause(){paused++;}}],
  addEventListener: (name, fn) => {if(name === 'play') onPlay = fn;},
  createElement: () => ({style:{}, children:[], appendChild(x){this.children.push(x);}, remove(){nodes.delete(this.id);}}),
  body: {appendChild(x){nodes.set(x.id,x);}}
};
vm.runInNewContext(SCRIPT, {window:{innerWidth:400,innerHeight:800}, document, Set, WeakSet, setInterval, clearInterval});
const video = (src, top=0) => ({tagName:'VIDEO',currentSrc:src,getBoundingClientRect:()=>({width:300,height:300,top,bottom:top+300,left:0,right:300})});
const first = video('first');
for(let i=0;i<30;i++) onPlay({target:first});
assert.equal(nodes.size,0,'replays must not count');
for(let i=0;i<10;i++) onPlay({target:video('hidden'+i,900)});
assert.equal(nodes.size,0,'offscreen videos must not count');
onPlay({target:video('second')}); onPlay({target:video('third')});
assert.equal(nodes.size,1,'three visible videos must trigger');
onPlay({target:video('fourth')}); assert.ok(paused>0);
nodes.get('isle-ig-nudge').children[1].onclick();
for(let i=0;i<20;i++) onPlay({target:video('third')});
assert.equal(nodes.size,0,'continue must not recount the same source');
onPlay({target:video('fourth')}); onPlay({target:video('fifth')}); onPlay({target:video('sixth')});
assert.equal(nodes.size,1,'new distinct videos still trigger after continue');
"""
          .replaceFirst('SCRIPT', jsonEncode(script))
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
}
