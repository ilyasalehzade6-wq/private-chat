python << 'PYEOF'
from pathlib import Path
fp = Path("chat.html")
c = fp.read_text(encoding="utf-8")

# ۱) تب گروه‌ها
old = '<button data-tab="online">آنلاین</button>'
new = '<button data-tab="online">آنلاین</button>\n      <button data-tab="groups">👥 گروه‌ها</button>'
if 'data-tab="groups"' not in c:
    c = c.replace(old, new)
    print("✅ تب گروه‌ها اضافه شد")

# ۲) مودال ساخت گروه (قبل از lightbox)
if 'createGroupModal' not in c:
    old = '<div class="lightbox" id="lightbox">'
    new = '''<div class="modal-bg" id="createGroupModal" style="display:none">
  <div class="modal">
    <div class="modal-head">
      <h3>👥 گروه جدید</h3>
      <button id="createGroupClose">✕</button>
    </div>
    <div class="modal-body">
      <div class="group-avatar-picker">
        <div class="group-avatar-preview" id="groupAvatarPreview">👥</div>
        <div class="emoji-row" id="groupEmojiRow">
          <button class="active" data-emoji="👥">👥</button>
          <button data-emoji="🎉">🎉</button>
          <button data-emoji="🎮">🎮</button>
          <button data-emoji="💼">💼</button>
          <button data-emoji="❤️">❤️</button>
          <button data-emoji="⚽">⚽</button>
          <button data-emoji="🎵">🎵</button>
          <button data-emoji="🍕">🍕</button>
        </div>
      </div>
      <div class="form-group">
        <label>نام گروه</label>
        <input type="text" id="groupNameInput" placeholder="مثلاً: دوستان" maxlength="50">
      </div>
      <div class="form-group">
        <label>اعضا</label>
        <div class="member-picker" id="memberPicker"></div>
      </div>
      <button class="btn-primary" id="createGroupBtn">ساخت گروه</button>
    </div>
  </div>
</div>

<div class="lightbox" id="lightbox">'''
    c = c.replace(old, new)
    print("✅ مودال ساخت گروه اضافه شد")

# ۳) دکمه گروه جدید در هدر سایدبار
if 'id="newGroupBtn"' not in c:
    old = '<button class="icon-btn" id="themeBtn" title="تم">🌙</button>'
    new = '<button class="icon-btn" id="newGroupBtn" title="گروه جدید">👥</button>\n      <button class="icon-btn" id="themeBtn" title="تم">🌙</button>'
    c = c.replace(old, new)
    print("✅ دکمه گروه جدید اضافه شد")

fp.write_text(c, encoding="utf-8")
print("✅ chat.html آپدیت شد")
PYEOF
