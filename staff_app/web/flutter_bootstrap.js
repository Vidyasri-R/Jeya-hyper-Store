{{flutter_js}}
{{flutter_build_config}}

// Show the branded loading screen until the app has started, then remove it.
// No serviceWorkerSettings on purpose: push-sw.js (new-order alerts) is this site's service worker.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    document.getElementById('boot')?.remove();
  },
});
