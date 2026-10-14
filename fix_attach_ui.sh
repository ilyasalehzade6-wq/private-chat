python << 'PYEOF'
from pathlib import Path

# ═══════════════════════════════════════════
# ۱) فیکس HTML — برگرداندن input به بیرون از label
# ═══════════════════════════════════════════
fp = Path("chat.html")
c = fp.read_text(encoding="utf-8")

# حالت‌های ممکن که ممکنه در فایل باشه
old_variants = [
    '''      <label class="attach-btn" for="fileInput" title="پیوست فایل">
        📎
        <input type="file" id="fileInput" accept="image/*,video/*,.pdf,.doc,.docx,.zip,.rar,.txt">
      </label>''',
    '''      <label class="attach-btn" for="fileInput" title="پیوست فایل">📎</label>''',
]

new_html = '''      <input type="file" id="fileInput" style="display:none" accept="image/*,video/*,.pdf,.doc,.docx,.zip,.rar,.txt">
      <button class="attach-btn" id="attachBtn" type="button" title="پیوست فایل">📎</button>'''

replaced = False
for old in old_variants:
    if old in c:
        c = c.replace(old, new_html)
        replaced = True
        print(f"✅ HTML فیکس شد (variant {old_variants.index(old)+1})")
        break

if not replaced:
    print("⚠️ الگو پیدا نشد، تلاش می‌کنیم جایگزینی هوشمند...")
    import re
    # هرچی بین label class="attach-btn" و /label رو پاک کن
    c = re.sub(
        r'<label[^>]*class="attach-btn"[^>]*>.*?</label>',
        new_html,
        c,
        flags=re.DOTALL
    )
    fp.write_text(c, encoding="utf-8")
    print("✅ با regex فیکس شد")

fp.write_text(c, encoding="utf-8")

# ═══════════════════════════════════════════
# ۲) فیکس JS — برگرداندن onclick به button
# ═══════════════════════════════════════════
jp = Path("js/chat.js")
j = jp.read_text(encoding="utf-8")

# حذف listener قدیمی اگه هست
old_listeners = [
    """  // پیوست فایل - با input مستقیم
  const fi = $('fileInput');
  if (fi) {
    fi.addEventListener('change', (e) => {
      const f = e.target.files[0];
      if (f) handleFileSelect(f);
      e.target.value = '';  // ریست تا بشه دوباره همون فایل رو انتخاب کرد
    });
  }

  $('attachRemove').onclick = clearAttachment;
""",
]

new_listeners = """  // پیوست فایل
  $('attachBtn').onclick = () => {
    $('fileInput').click();
  };
  $('fileInput').onchange = (e) => {
    const f = e.target.files[0];
    if (f) handleFileSelect(f);
    e.target.value = '';  // ریست تا بشه دوباره همون فایل رو انتخاب کرد
  };
  $('attachRemove').onclick = clearAttachment;
"""

replaced_js = False
for old in old_listeners:
    if old in j:
        j = j.replace(old, new_listeners)
        replaced_js = True
        print("✅ JS listener فیکس شد")
        break

if not replaced_js:
    # اگه attachBtn.onclick هست، مهم نیست، از قبل درست بوده
    if "$('attachBtn').onclick" not in j:
        # اضافه کن بعد از sendBtn.onclick
        j = j.replace(
            "  sendBtn.onclick = sendMessage;\n",
            "  sendBtn.onclick = sendMessage;\n\n" +
            "  $('attachBtn').onclick = () => $('fileInput').click();\n" +
            "  $('fileInput').onchange = (e) => {\n" +
            "    const f = e.target.files[0];\n" +
            "    if (f) handleFileSelect(f);\n" +
            "    e.target.value = '';\n" +
            "  };\n"
        )
        print("✅ JS listener اضافه شد")

jp.write_text(j, encoding="utf-8")
print("✅ JS فیکس شد")

PYEOF
