python << 'PYEOF'
from pathlib import Path
fp = Path("chat.html")
c = fp.read_text(encoding="utf-8")

# مودال Wallpaper
if 'wallpaperModal' not in c:
    old = '<div class="modal-bg" id="savedModal"'
    new = '''<div class="modal-bg" id="wallpaperModal" style="display:none">
  <div class="modal">
    <div class="modal-head">
      <h3>🎨 والپیپر</h3>
      <button id="wallpaperClose">✕</button>
    </div>
    <div class="modal-body">
      <div class="wallpaper-section">
        <div class="wallpaper-label">رنگ ساده</div>
        <div class="color-grid" id="wpColorGrid"></div>
      </div>
      <div class="wallpaper-section">
        <div class="wallpaper-label">گرادیان</div>
        <div class="gradient-grid" id="wpGradientGrid"></div>
      </div>
      <div class="wallpaper-section">
        <div class="wallpaper-label">الگو</div>
        <div class="pattern-grid" id="wpPatternGrid"></div>
      </div>
      <div class="wallpaper-section">
        <div class="wallpaper-label">تصویر خودت</div>
        <label class="btn-upload-wallpaper">
          <input type="file" id="wallpaperUpload" accept="image/*">
          📷 انتخاب تصویر
        </label>
      </div>
      <button class="btn-secondary" id="wallpaperReset" style="margin-top:16px">
        🗑 حذف والپیپر
      </button>
    </div>
  </div>
</div>

<div class="modal-bg" id="savedModal"'''
    c = c.replace(old, new)
    print("✅ مودال Wallpaper اضافه شد")

fp.write_text(c, encoding="utf-8")
print("✅ chat.html آپدیت شد")
PYEOF
