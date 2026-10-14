python << 'PYEOF'
from pathlib import Path

fp = Path("chat.html")
c = fp.read_text(encoding="utf-8")

# ۱. اضافه کردن دکمه ضمیمه به composer
old_composer = '''    <div class="composer" id="composer" style="display:none">
      <textarea id="messageInput" placeholder="پیامت را بنویس..." rows="1"></textarea>
      <button class="send-btn" id="sendBtn" disabled>📤</button>
    </div>'''

new_composer = '''    <div class="attachment-preview" id="attachmentPreview" style="display:none">
      <div class="attachment-preview-inner">
        <div id="attachPreviewContent"></div>
        <div class="attachment-info" id="attachInfo"></div>
      </div>
      <button class="attach-remove" id="attachRemove" title="حذف ضمیمه">✕</button>
    </div>

    <div class="composer" id="composer" style="display:none">
      <input type="file" id="fileInput" style="display:none" accept="image/*,video/*,.pdf,.doc,.docx,.zip,.rar,.txt">
      <button class="attach-btn" id="attachBtn" title="پیوست فایل">📎</button>
      <textarea id="messageInput" placeholder="پیامت را بنویس..." rows="1"></textarea>
      <button class="send-btn" id="sendBtn" disabled>📤</button>
    </div>'''

c = c.replace(old_composer, new_composer)

# ۲. اضافه کردن Lightbox قبل از toast
old_toast = '<div class="toast" id="toast"></div>'
new_toast = '''<div class="lightbox" id="lightbox">
  <button class="lightbox-close" id="lightboxClose">✕</button>
  <img id="lightboxImg" src="" alt="">
</div>

<div class="toast" id="toast"></div>'''

c = c.replace(old_toast, new_toast)

fp.write_text(c, encoding="utf-8")
print("✅ chat.html به‌روز شد")
PYEOF
