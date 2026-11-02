{{flutter_js}}
{{flutter_build_config}}
window.addEventListener('flutter-first-frame', () => {
  window.safeFlutterReady = true;
  document.getElementById('boot-error').hidden = true;
}, {once:true});
_flutter.loader.load({
  config: {hostElement: document.getElementById('flutter-host'), canvasKitBaseUrl:'canvaskit/', canvasKitVariant:'full'},
  onEntrypointLoaded: async function(engineInitializer) {
    const runner = await engineInitializer.initializeEngine({hostElement:document.getElementById('flutter-host'),canvasKitBaseUrl:'canvaskit/',canvasKitVariant:'full'});
    await runner.runApp();

  }
}).catch(() => {document.getElementById('boot-error').hidden = false;});
