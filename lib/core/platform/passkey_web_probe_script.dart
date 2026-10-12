/// WebView에서 패스키 API 가용성 탐지 → IslePasskey 채널로 알림
class PasskeyWebProbeScript {
  PasskeyWebProbeScript._();

  static const channelName = 'IslePasskey';

  static const install = '''
(function(){
  if (window.__islePasskeyProbe) return;
  window.__islePasskeyProbe = true;
  var ch = window.IslePasskey;
  if (!ch || !ch.postMessage) return;
  var send = function(m){ try { ch.postMessage(m); } catch(e) {} };
  if (!window.PublicKeyCredential) {
    send('unsupported');
    return;
  }
  var done = false;
  var finish = function(m){
    if (done) return;
    done = true;
    send(m);
  };
  var timer = setTimeout(function(){ finish('timeout'); }, 2800);
  try {
    var p = PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
    if (!p || !p.then) { clearTimeout(timer); finish('unsupported'); return; }
    p.then(function(ok){
      clearTimeout(timer);
      finish(ok ? 'available' : 'unavailable');
    }).catch(function(){ clearTimeout(timer); finish('error'); });
  } catch (e) {
    clearTimeout(timer);
    finish('error');
  }
})();
''';
}
