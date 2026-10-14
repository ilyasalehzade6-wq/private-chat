python << 'PYEOF'
from pathlib import Path
import re

fp = Path("js/chat.js")
c = fp.read_text(encoding="utf-8")

# ═══════════════════════════════════════════
# ۱) hook اعلان/صدا در subscribeMessages
# ═══════════════════════════════════════════
# روش منعطف: پیدا کردن INSERT handler در subscribeMessages
pattern = re.compile(
    r"(\.on\('postgres_changes',\s*\{[^}]*event:\s*'INSERT'[^}]*\},\s*\(payload\)\s*=>\s*\{)"
    r"([\s\S]*?)"
    r"(\n\s*\}\))",
    re.MULTILINE
)

def patch_insert(m):
    before = m.group(1)
    body = m.group(2)
    after = m.group(3)

    # اگر قبلاً patch شده، رد کن
    if 'playMsgSound()' in body:
        return m.group(0)

    # جایگزینی markAsRead تنها با markAsRead + sound + notification
    new_body = body.replace(
        "if (msg.sender_id !== currentUser.id) markAsRead();",
        """if (msg.sender_id !== currentUser.id) {
          markAsRead();
          playMsgSound();
          const senderName = currentOtherUser?.display_name || currentOtherUser?.username || 'پیام جدید';
          notifyNewMessage(msg, senderName);
        }"""
    )
    # اگر الگو نبود، تلاش دوم
    if new_body == body:
        new_body = body.replace(
            "if (msg.sender_id !== currentUser.id) markAsRead()",
            """if (msg.sender_id !== currentUser.id) {
            markAsRead();
            playMsgSound();
            const senderName = currentOtherUser?.display_name || currentOtherUser?.username || 'پیام جدید';
            notifyNewMessage(msg, senderName);
          }"""
        )

    return before + new_body + after

new_c, count = pattern.subn(patch_insert, c, count=1)
if count > 0:
    c = new_c
    print(f"✅ hook اعلان/صدا اضافه شد")
else:
    print("⚠️ الگوی INSERT پیدا نشد، با روش مستقیم تلاش می‌کنیم...")
    # روش مستقیم
    old = "if (msg.sender_id !== currentUser.id) markAsRead();"
    if old in c:
        c = c.replace(old, """if (msg.sender_id !== currentUser.id) {
          markAsRead();
          playMsgSound();
          const senderName = currentOtherUser?.display_name || currentOtherUser?.username || 'پیام جدید';
          notifyNewMessage(msg, senderName);
        }""", 1)
        print("✅ با روش مستقیم patch شد")
    else:
        print("❌ پیدا نشد")

# ═══════════════════════════════════════════
# ۲) hook صدای ارسال در sendMessage
# ═══════════════════════════════════════════
old_send = """    input.value = '';
    input.style.height = '46px';
    clearAttachment();
    replyTo = null;
    renderReplyPreview();
  } catch (err) {"""

new_send = """    input.value = '';
    input.style.height = '46px';
    clearAttachment();
    replyTo = null;
    renderReplyPreview();
    playSendSound();
    requestNotifPermission();
  } catch (err) {"""

if old_send in c:
    c = c.replace(old_send, new_send, 1)
    print("✅ hook صدای ارسال اضافه شد")
else:
    # روش منعطف‌تر
    pattern2 = re.compile(
        r"(clearAttachment\(\);\s*\n\s*replyTo\s*=\s*null;\s*\n\s*renderReplyPreview\(\);)\s*\n\s*(\}\s*catch)"
    )
    if pattern2.search(c):
        c = pattern2.sub(
            r"\1\n    playSendSound();\n    requestNotifPermission();\n  \2",
            c, count=1
        )
        print("✅ hook صدای ارسال با regex اضافه شد")
    else:
        print("⚠️ الگوی sendMessage پیدا نشد")

fp.write_text(c, encoding="utf-8")

# بررسی نهایی
print("")
print("📋 چک:")
c2 = fp.read_text(encoding="utf-8")
print("  - playMsgSound در INSERT:", "✅" if "playMsgSound();" in c2 and "markAsRead();\n          playMsgSound" in c2 else "❌")
print("  - notifyNewMessage در INSERT:", "✅" if "notifyNewMessage(msg, senderName)" in c2 else "❌")
print("  - playSendSound در send:", "✅" if "playSendSound();\n    requestNotifPermission" in c2 else "❌")
PYEOF
