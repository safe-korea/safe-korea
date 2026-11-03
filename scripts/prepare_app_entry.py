"""Package runtime under /app/ so old landing-page caches cannot serve it."""
from pathlib import Path
import re
import shutil
root=Path('build/web')
landing=(root/'index.html').read_text()
match=re.search(r'<base href="([^"]+)"', landing)
if not match: raise ValueError('Flutter base URL missing')
app=root/'app'
if app.exists(): shutil.rmtree(app)  # Generated build output only.
app.mkdir()
for name in ['assets','canvaskit','flutter_bootstrap.js','flutter.js','main.dart.js','version.json','app_entry.js','push-client.js']:
    source=root/name
    if source.exists(): shutil.move(str(source),str(app/name))
shutil.copy2(root/'onboarding.css',app/'onboarding.css')
(app/'icons').mkdir()
shutil.copy2(root/'icons/icon-192.png',app/'icons/icon-192.png')
start=landing.index('    <section id="setup"')
end=landing.index('  </main>',start)
settings=landing[start:end]
html=Path('web/app.html').read_text().replace('$FLUTTER_BASE_HREF',match[1]+'app/')
html=html.replace('<!--APP_SETTINGS-->',settings)
(app/'index.html').write_text(html)
(root/'app.html').unlink(missing_ok=True)

# Stable marketing address bypasses the old root worker's cached app redirect.
intro=root/'intro'
intro.mkdir(exist_ok=True)
marketing=landing.replace('src="onboarding.js"','src="onboarding.js?v=ui-spacing-20261103"').replace('href="onboarding.css"','href="onboarding.css?v=ui-spacing-20261103"')
(intro/'index.html').write_text(marketing)
