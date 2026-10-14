python << 'PYEOF'
from pathlib import Path
fp = Path("index.html")
c = fp.read_text(encoding="utf-8")

if '<link rel="manifest"' not in c:
    c = c.replace(
        '<link rel="stylesheet" href="./css/style.css">',
        '<link rel="manifest" href="./manifest.json">\n<link rel="stylesheet" href="./css/style.css">'
    )

if 'navigator.serviceWorker' not in c:
    # ثبت SW قبل از بسته شدن اسکریپت
    c = c.replace(
        '</script>\n</body>',
        """// ثبت Service Worker برای PWA
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch(() => {});
  });
}
</script>
</body>"""
    )

fp.write_text(c, encoding="utf-8")
print("✅ index.html آپدیت شد")
PYEOF
