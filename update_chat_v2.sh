python << 'PYEOF'
from pathlib import Path
fp = Path("chat.html")
c = fp.read_text(encoding="utf-8")

# ۱. manifest
if '<link rel="manifest"' not in c:
    c = c.replace(
        '<link rel="stylesheet" href="./css/style.css">',
        '<link rel="manifest" href="./manifest.json">\n<link rel="stylesheet" href="./css/style.css">'
    )

# ۲. اضافه کردن دکمه پروفایل به sidebar header
if 'id="profileBtn"' not in c:
    old = '''      <button class="icon-btn" id="themeBtn" title="تغییر تم">🌙</button>
      <button class="icon-btn" id="logoutBtn" title="خروج">🚪</button>'''
    new = '''      <button class="icon-btn" id="profileBtn" title="پروفایل">👤</button>
      <button class="icon-btn" id="themeBtn" title="تغییر تم">🌙</button>
      <button class="icon-btn" id="logoutBtn" title="خروج">🚪</button>'''
    c = c.replace(old, new)

# ۳. مودال ویرایش پروفایل قبل از lightbox
if 'profileModal' not in c:
    old = '<div class="lightbox" id="lightbox">'
    new = '''<div class="modal-bg" id="profileModal">
  <div class="modal">
    <div class="modal-head">
      <h3>👤 ویرایش پروفایل</h3>
      <button id="profileClose">✕</button>
    </div>
    <div class="modal-body">
      <div class="profile-avatar-edit">
        <div class="avatar-preview-lg" id="avatarPreviewLg">👤</div>
        <label class="btn-upload-avatar" for="avatarInput">
          <input type="file" id="avatarInput" accept="image/*">
          📷 تغییر عکس
        </label>
      </div>
      <div class="form-group" style="margin-top:18px">
        <label>نام نمایشی</label>
        <input type="text" id="profileDisplayName" placeholder="نام کامل شما">
      </div>
      <div class="form-group">
        <label>نام کاربری</label>
        <input type="text" id="profileUsername" placeholder="username" disabled>
      </div>
      <div class="modal-actions">
        <button class="btn-secondary" id="profileCancelBtn">لغو</button>
        <button class="btn-primary" id="profileSaveBtn">ذخیره تغییرات</button>
      </div>
    </div>
  </div>
</div>

<div class="lightbox" id="lightbox">'''
    c = c.replace(old, new)

# ۴. ثبت SW
if 'navigator.serviceWorker' not in c:
    c = c.replace(
        '</script>\n</body>',
        """// ثبت Service Worker
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch(() => {});
  });
}
</script>
</body>"""
    )

fp.write_text(c, encoding="utf-8")
print("✅ chat.html آپدیت شد")
PYEOF
