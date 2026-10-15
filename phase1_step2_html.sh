python << 'PYEOF'
from pathlib import Path
fp = Path("chat.html")
c = fp.read_text(encoding="utf-8")

# ═══ ۱) دکمه Saved Messages بالای سایدبار ═══
if 'id="savedBtn"' not in c:
    old = '<button class="icon-btn" id="newChatBtn" title="چت جدید">✏️</button>'
    new = '''<button class="icon-btn" id="savedBtn" title="پیام‌های ذخیره‌شده">🔖</button>
      <button class="icon-btn" id="newChatBtn" title="چت جدید">✏️</button>'''
    c = c.replace(old, new)
    print("✅ دکمه Saved اضافه شد")

# ═══ ۲) مودال Global Search ═══
if 'globalSearchModal' not in c:
    old = '<div class="modal-bg" id="forwardModal"'
    new = '''<div class="modal-bg" id="globalSearchModal" style="display:none">
  <div class="modal modal-wide">
    <div class="modal-head">
      <h3>🔍 جستجوی همه‌جانبه</h3>
      <button id="globalSearchClose">✕</button>
    </div>
    <div class="modal-body">
      <div class="search-input-wrap">
        <input type="text" id="globalSearchInput" placeholder="جستجو در همه پیام‌ها..." autocomplete="off">
      </div>
      <div class="filter-chips" id="searchFilters">
        <button class="active" data-filter="all">همه</button>
        <button data-filter="text">متن</button>
        <button data-filter="image">عکس</button>
        <button data-filter="video">ویدیو</button>
        <button data-filter="file">فایل</button>
        <button data-filter="link">لینک</button>
      </div>
      <div class="global-results" id="globalResults">
        <div class="empty-list" style="padding:40px 20px">
          <span class="emoji">🔍</span>
          چیزی برای جستجو بنویس
        </div>
      </div>
    </div>
  </div>
</div>

<div class="modal-bg" id="forwardModal"'''
    c = c.replace(old, new)
    print("✅ Global Search Modal اضافه شد")

# ═══ ۳) مودال Saved Messages ═══
if 'savedModal' not in c:
    old = '<div class="modal-bg" id="globalSearchModal"'
    new = '''<div class="modal-bg" id="savedModal" style="display:none">
  <div class="modal modal-wide">
    <div class="modal-head">
      <h3>🔖 پیام‌های ذخیره‌شده</h3>
      <button id="savedClose">✕</button>
    </div>
    <div class="modal-body">
      <div class="saved-list" id="savedList">
        <div class="empty-list" style="padding:40px 20px">
          <span class="emoji">🔖</span>
          هنوز چیزی ذخیره نکرده‌ای
        </div>
      </div>
    </div>
  </div>
</div>

<div class="modal-bg" id="globalSearchModal"'''
    c = c.replace(old, new)
    print("✅ Saved Modal اضافه شد")

fp.write_text(c, encoding="utf-8")
print("✅ chat.html آپدیت شد")
PYEOF
