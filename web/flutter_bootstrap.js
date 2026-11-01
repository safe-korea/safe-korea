{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  config: {hostElement: document.getElementById('flutter-host'), canvasKitBaseUrl:'canvaskit/', canvasKitVariant:'full'},
  onEntrypointLoaded: async function(engineInitializer) {
    const runner = await engineInitializer.initializeEngine({hostElement:document.getElementById('flutter-host'),canvasKitBaseUrl:'canvaskit/',canvasKitVariant:'full'});
    await runner.runApp();
    window.safeFlutterReady = true;
    document.getElementById('boot-error').hidden = true;
  }
}).catch(() => {document.getElementById('boot-error').hidden = false;});
