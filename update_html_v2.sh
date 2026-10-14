python << 'PYEOF'
from pathlib import Path
import re

fp = Path("chat.html")
c = fp.read_text(encoding="utf-8")

# ۱. اضافه کردن دکمه‌های search و pin به header
old_header = '''    <div class="chat-header" id="chatHeader" style="display:none">
      <button class="icon-btn back-btn" id="backBtn">←</button>
      <div class="avatar" id="chatAvatar"></div>
      <div class="info">
        <h3 id="chatName"></h3>
        <p id="chatStatus"></p>
      </div>
    </div>'''

new_header = '''    <div class="chat-header" id="chatHeader" style="display:none">
      <button class="icon-btn back-btn" id="backBtn">←</button>
      <div class="avatar" id="chatAvatar"></div>
      <div class="info">
        <h3 id="chatName"></h3>
        <p id="chatStatus"></p>
      </div>
      <button class="icon-btn" id="searchToggle" title="جستجو">🔍</button>
      <button class="icon-btn" id="pinToggle" title="پیام‌های پین‌شده">📌</button>
    </div>

    <div class="chat-search-bar" id="chatSearchBar" style="display:none">
      <input type="text" id="chatSearchInput" placeholder="جستجو در پیام‌ها...">
      <span class="search-count" id="searchCount"></span>
      <button class="icon-btn-sm" id="chatSearchClose">✕</button>
    </div>

    <div class="pinned-banner" id="pinnedBanner" style="display:none">
      <div class="pin-icon">📌</div>
      <div class="pin-body">
        <div class="pin-label">پیام پین‌شده</div>
        <div class="pin-text" id="pinnedText"></div>
      </div>
      <button class="pin-close" id="pinClose">✕</button>
    </div>'''

c = c.replace(old_header, new_header)

# ۲. اضافه کردن reply preview قبل از composer
old_attach = '''    <div class="attachment-preview" id="attachmentPreview" style="display:none">'''

new_reply = '''    <div class="reply-preview" id="replyPreview" style="display:none">
      <div class="reply-inner">
        <div class="reply-label">↩ پاسخ به <span id="replyName"></span></div>
        <div class="reply-text" id="replyText"></div>
      </div>
      <button class="reply-close" id="replyClose">✕</button>
    </div>

    <div class="edit-banner" id="editBanner" style="display:none">
      <div class="edit-inner">
        <div class="edit-label">✏️ ویرایش پیام</div>
        <div class="edit-text" id="editText"></div>
      </div>
      <button class="edit-close" id="editClose">✕</button>
    </div>

    <div class="attachment-preview" id="attachmentPreview" style="display:none">'''

c = c.replace(old_attach, new_reply)

fp.write_text(c, encoding="utf-8")
print("✅ chat.html به‌روز شد")
PYEOF
