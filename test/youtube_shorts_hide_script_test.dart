import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/youtube/youtube_shorts_hide_script.dart';

void main() {
  test('hides Shorts without collapsing the mixed search results section', () {
    final result = Process.runSync('node', [
      '-e',
      r"""
const assert=require('node:assert/strict'); const vm=require('node:vm');
const node=()=>({hidden:false,getAttribute(){return null;},setAttribute(){},style:{setProperty(name,value){if(name==='display')this.owner.hidden=true;} }});
const section=node(),short=node(),shelf=node(),rich=node(),mixed=node();
for(const n of [section,short,shelf,rich,mixed])n.style.owner=n;
short.closest=s=>s.includes('ytm-item-section-renderer')?section:null;
rich.querySelector=s=>s.includes('/shorts/')?short:null;
mixed.querySelector=s=>s.includes('/shorts/')?short:section;
const document={querySelectorAll:s=>s==='ytm-rich-shelf-renderer, ytd-rich-shelf-renderer, grid-shelf-view-model, ytm-rich-section-renderer'?[rich,mixed]:(s.includes('a[href')?[short]:[shelf]),body:{}};
vm.runInNewContext(SCRIPT,{window:{},document,location:{pathname:'/results'},requestAnimationFrame(){},setTimeout(){},MutationObserver:class{observe(){}}});
assert.equal(short.hidden,true,'Shorts link hidden');
assert.equal(shelf.hidden,true,'Shorts shelf hidden');
assert.equal(section.hidden,false,'regular search results must stay visible');
assert.equal(rich.hidden,true,'dedicated mobile Shorts shelf and header collapse');
assert.equal(mixed.hidden,false,'mixed shelves with regular video links remain');
"""
          .replaceFirst('SCRIPT', jsonEncode(YoutubeShortsHideScript.install))
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
}
