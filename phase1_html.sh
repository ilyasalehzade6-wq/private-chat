python << 'PYEOF'
from pathlib import Path
fp = Path("chat.html")
c = fp.read_text(encoding="utf-8")

# ═══ ۱) مودال فوروارد ═══
if 'forwardModal' not in c:
    old = '<div class="modal-bg" id="profileModal"'
    new = '''<div class="modal-bg" id="forwardModal" style="display:none">
  <div class="modal">
    <div class="modal-head">
      <h3>➡️ فوروارد به...</h3>
      <button id="forwardClose">✕</button>
    </div>
    <div class="modal-body">
      <div class="search-input-wrap">
        <input type="text" id="forwardSearch" placeholder="جستجوی چت...">
      </div>
      <div class="forward-list" id="forwardList"></div>
    </div>
  </div>
</div>

<div class="modal-bg" id="profileModal"'''
    c = c.replace(old, new)
    print("✅ مودال فوروارد اضافه شد")

# ═══ ۲) Sticker / Big emoji برای پیام ═══
# (Big emoji نیازی به HTML جدید ندارد، فقط CSS)

fp.write_text(c, encoding="utf-8")
print("✅ chat.html آپدیت شد")
PYEOF
