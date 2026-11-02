{{flutter_js}}
{{flutter_build_config}}
const bootWatchdog=setTimeout(()=>{if(!window.safeFlutterReady)document.getElementById('boot-error').hidden=false;},45000);
window.addEventListener('flutter-first-frame', () => {
  clearTimeout(bootWatchdog);
  window.safeFlutterReady = true;
  document.getElementById('boot-splash').hidden = true;
  document.getElementById('boot-error').hidden = true;
}, {once:true});
_flutter.loader.load({
  config: {hostElement: document.getElementById('flutter-host'), canvasKitBaseUrl:'canvaskit/', canvasKitVariant:'full'},
  onEntrypointLoaded: async function(engineInitializer) {
    const runner = await engineInitializer.initializeEngine({hostElement:document.getElementById('flutter-host'),canvasKitBaseUrl:'canvaskit/',canvasKitVariant:'full'});
    await runner.runApp();

  }
}).catch(() => {clearTimeout(bootWatchdog);document.getElementById('boot-error').hidden = false;});
