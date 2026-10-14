python << 'PYEOF'
from pathlib import Path
fp = Path("js/chat.js")
c = fp.read_text(encoding="utf-8")

# ۱. اضافه کردن متغیرهای جدید بعد از let pinnedMsg = null;
c = c.replace(
    "let pinnedMsg = null;",
    """let pinnedMsg = null;
let unreadCounts = {};       // { userId: count }
let lastNotifications = {};  // جلوگیری از spam
let notificationGranted = false;
let audioCtx = null;"""
)

# ۲. اضافه کردن UI bindings در init - بعد از "init();"  نمی‌شود، اضافه می‌کنیم قبل از init();
extra_ui = """
  // ─── دکمه‌های بسته ۲ ───
  $('profileBtn').onclick = () => openProfileModal();
  $('profileClose').onclick = () => $('profileModal').classList.remove('show');
  $('profileCancelBtn').onclick = () => $('profileModal').classList.remove('show');
  $('profileModal').onclick = (e) => { if (e.target.id === 'profileModal') $('profileModal').classList.remove('show'); };
  $('profileSaveBtn').onclick = saveProfile;
  $('avatarInput').onchange = (e) => {
    const f = e.target.files[0];
    if (f) uploadAvatarPreview(f);
  };

  // درخواست اعلان (بار اول)
  initNotifications();

  // حالت خودکار بر اساس ساعت
  applyAutoTheme();
"""
c = c.replace("  // Global click to close reaction pickers", extra_ui + "\n  // Global click to close reaction pickers")

# ۳. اضافه کردن توابع بسته ۲ در انتهای فایل (قبل از init())
helpers = r'''
// ═══════════════════════════════════════════
// بسته ۲: اعلان‌ها / پروفایل / بج نخوانده / صدا / PWA
// ═══════════════════════════════════════════

// ─── اعلان مرورگر ───
async function initNotifications() {
  if (!('Notification' in window)) return;
  if (Notification.permission === 'granted') { notificationGranted = true; return; }
  if (Notification.permission === 'denied') return;
  // درخواست نده خودکار - فقط وقتی کاربر پیام می‌فرستد یا می‌گیرد
}

async function requestNotifPermission() {
  if (!('Notification' in window)) return false;
  if (Notification.permission === 'granted') { notificationGranted = true; return true; }
  if (Notification.permission === 'denied') return false;
  const p = await Notification.requestPermission();
  notificationGranted = p === 'granted';
  return notificationGranted;
}

function notifyNewMessage(msg, senderName) {
  if (!notificationGranted) return;
  if (document.visibilityState === 'visible' && document.hasFocus()) return;
  if (msg.sender_id === currentUser.id) return;

  // جلوگیری از تکرار
  const key = msg.id;
  if (lastNotifications[key]) return;
  lastNotifications[key] = true;
  setTimeout(() => delete lastNotifications[key], 5000);

  const body = msg.content || (msg.attachment_type === 'image' ? '📷 عکس' : msg.attachment_type === 'video' ? '🎥 فیلم' : '📄 فایل');
  const notif = new Notification(senderName || 'پیام جدید', {
    body: body.substring(0, 100),
    icon: currentOtherUser?.avatar_url || undefined,
    tag: 'msg-' + msg.id,
    silent: false
  });

  notif.onclick = () => { window.focus(); notif.close(); };
}

// ─── صدای پیام ───
function playMsgSound() {
  try {
    if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.connect(gain); gain.connect(audioCtx.destination);
    osc.frequency.setValueAtTime(880, audioCtx.currentTime);
    osc.frequency.setValueAtTime(660, audioCtx.currentTime + 0.08);
    gain.gain.setValueAtTime(0.15, audioCtx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.25);
    osc.start(audioCtx.currentTime);
    osc.stop(audioCtx.currentTime + 0.25);
  } catch (e) {}
}

function playSendSound() {
  try {
    if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.connect(gain); gain.connect(audioCtx.destination);
    osc.frequency.setValueAtTime(440, audioCtx.currentTime);
    osc.frequency.setValueAtTime(880, audioCtx.currentTime + 0.08);
    gain.gain.setValueAtTime(0.08, audioCtx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.18);
    osc.start(audioCtx.currentTime);
    osc.stop(audioCtx.currentTime + 0.18);
  } catch (e) {}
}

// ─── حالت خودکار ───
function applyAutoTheme() {
  // اگر کاربر دستی انتخاب نکرده، بر اساس ساعت تنظیم کن
  if (localStorage.getItem('chat_theme')) return;
  const h = new Date().getHours();
  const isDark = h >= 19 || h < 7;
  if (isDark) {
    document.body.classList.add('dark');
    $('themeBtn').textContent = '☀️';
  }
}

// ─── بج نخوانده ───
async function loadUnreadCounts() {
  try {
    const { data, error } = await supabase
      .from('messages')
      .select('conversation_id, sender_id, created_at');
    if (error) return;

    // برای هر کاربر، تعداد پیام‌های نخوانده (تقریبی)
    const convIds = [...new Set((data || []).map(m => m.conversation_id))];
    const counts = {};
    (data || []).forEach(m => {
      if (m.sender_id !== currentUser.id) {
        counts[m.sender_id] = (counts[m.sender_id] || 0) + 1;
      }
    });
    unreadCounts = counts;
  } catch (e) {}
}

// ─── پروفایل ───
function openProfileModal() {
  $('profileDisplayName').value = currentProfile?.display_name || '';
  $('profileUsername').value = currentProfile?.username || '';
  const prev = $('avatarPreviewLg');
  if (currentProfile?.avatar_url) {
    prev.innerHTML = '';
    const img = document.createElement('img');
    img.src = currentProfile.avatar_url;
    prev.appendChild(img);
  } else {
    prev.textContent = '👤';
  }
  $('profileModal').classList.add('show');
}

let pendingAvatarFile = null;

function uploadAvatarPreview(file) {
  pendingAvatarFile = file;
  const prev = $('avatarPreviewLg');
  prev.innerHTML = '';
  const img = document.createElement('img');
  img.src = URL.createObjectURL(file);
  prev.appendChild(img);
}

async function saveProfile() {
  const displayName = $('profileDisplayName').value.trim();
  const btn = $('profileSaveBtn');
  btn.disabled = true;
  btn.textContent = 'ذخیره...';

  try {
    let avatar_url = currentProfile?.avatar_url;

    if (pendingAvatarFile) {
      const ts = Date.now();
      const safe = pendingAvatarFile.name.replace(/[^a-zA-Z0-9._-]/g, '_');
      const path = currentUser.id + '/avatar-' + ts + '-' + safe;
      const { error: upErr } = await supabase.storage.from('avatars')
        .upload(path, pendingAvatarFile, { upsert: true, contentType: pendingAvatarFile.type });
      if (upErr) throw upErr;
      const { data: pub } = supabase.storage.from('avatars').getPublicUrl(path);
      avatar_url = pub.publicUrl;
    }

    const { error } = await supabase.from('profiles')
      .update({ display_name: displayName, avatar_url })
      .eq('id', currentUser.id);
    if (error) throw error;

    currentProfile.display_name = displayName;
    currentProfile.avatar_url = avatar_url;
    $('myName').textContent = displayName;
    pendingAvatarFile = null;
    $('profileModal').classList.remove('show');
    showToast('پروفایل ذخیره شد ✅', 'success');
  } catch (e) {
    showToast('خطا: ' + e.message, 'error');
  } finally {
    btn.disabled = false;
    btn.textContent = 'ذخیره تغییرات';
  }
}

// ═══════════════════════════════════════════
// هوک‌ها: اتصال به بخش‌های قبلی
// ═══════════════════════════════════════════

'''

c = c.replace("init();", helpers + "init();")

fp.write_text(c, encoding="utf-8")
print("✅ chat.js آپدیت شد (توابع بسته ۲)")

PYEOF
