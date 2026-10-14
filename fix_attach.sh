python << 'PYEOF'
from pathlib import Path

# ═══════════════════════════════════════════
# ۱) تغییر chat.html — تبدیل button به label
# ═══════════════════════════════════════════
fp = Path("chat.html")
c = fp.read_text(encoding="utf-8")

old = '''    <div class="composer" id="composer" style="display:none">
      <input type="file" id="fileInput" style="display:none" accept="image/*,video/*,.pdf,.doc,.docx,.zip,.rar,.txt">
      <button class="attach-btn" id="attachBtn" title="پیوست فایل">📎</button>
      <textarea id="messageInput" placeholder="پیامت را بنویس..." rows="1"></textarea>
      <button class="send-btn" id="sendBtn" disabled>📤</button>
    </div>'''

new = '''    <div class="composer" id="composer" style="display:none">
      <label class="attach-btn" for="fileInput" title="پیوست فایل">
        📎
        <input type="file" id="fileInput" accept="image/*,video/*,.pdf,.doc,.docx,.zip,.rar,.txt">
      </label>
      <textarea id="messageInput" placeholder="پیامت را بنویس..." rows="1"></textarea>
      <button class="send-btn" id="sendBtn" disabled>📤</button>
    </div>'''

if old in c:
    c = c.replace(old, new)
    fp.write_text(c, encoding="utf-8")
    print("✅ chat.html اصلاح شد")
else:
    print("⚠️ الگو پیدا نشد — دنبال label دستی می‌گردیم")
    # تلاش جایگزینی ساده‌تر
    if '<button class="attach-btn"' in c:
        c = c.replace(
            '<button class="attach-btn" id="attachBtn" title="پیوست فایل">📎</button>',
            '<label class="attach-btn" for="fileInput" title="پیوست فایل">📎</label>'
        )
        # انتقال input از داخل composer به جای مناسب
        c = c.replace(
            '<input type="file" id="fileInput" style="display:none" accept="image/*,video/*,.pdf,.doc,.docx,.zip,.rar,.txt">\n      ',
            ''
        )
        fp.write_text(c, encoding="utf-8")
        print("✅ با روش جایگزین اصلاح شد")
    else:
        print("❌ الگو پیدا نشد — لطفاً محتوای composer را دستی چک کن")


# ═══════════════════════════════════════════
# ۲) اصلاح chat.js — حذف onclick قدیمی
# ═══════════════════════════════════════════
jp = Path("js/chat.js")
j = jp.read_text(encoding="utf-8")

old_lines = [
    "  $('attachBtn').onclick = () => $('fileInput').click();\n",
    "  $('fileInput').onchange = (e) => handleFileSelect(e.target.files[0]);\n",
]

for old_line in old_lines:
    if old_line in j:
        j = j.replace(old_line, "")
        print(f"✅ حذف شد: {old_line.strip()[:40]}...")

# اضافه کردن listener جدید برای input
new_binding = """  // پیوست فایل - با input مستقیم
  const fi = $('fileInput');
  if (fi) {
    fi.addEventListener('change', (e) => {
      const f = e.target.files[0];
      if (f) handleFileSelect(f);
      e.target.value = '';  // ریست تا بشه دوباره همون فایل رو انتخاب کرد
    });
  }

  $('attachRemove').onclick = clearAttachment;
"""

# جای attachRemove قدیمی
old_bind = "  $('attachRemove').onclick = clearAttachment;\n"
if old_bind in j:
    j = j.replace(old_bind, new_binding)
    print("✅ listener جدید اضافه شد")
else:
    print("⚠️ الگوی listener قدیمی پیدا نشد")

jp.write_text(j, encoding="utf-8")
print("✅ chat.js اصلاح شد")

PYEOF
