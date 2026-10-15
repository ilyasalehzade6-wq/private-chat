#!/bin/bash

echo "🎨 اضافه کردن قابلیت‌های روبیکا..."
echo ""

# ═══════════════════════════════════════════════════════
# ۱) HTML: FAB + نوار تاریخ + تب‌بار موبایل
# ═══════════════════════════════════════════════════════
python << 'PYEOF'
from pathlib import Path

fp = Path("chat.html")
c = fp.read_text(encoding="utf-8")

# ─── FAB (دکمه شناور) ───
if 'fab-new-chat' not in c:
    old = '<div class="toast" id="toast"></div>'
    new = '''<button class="fab-new-chat" id="fabNewChat" title="چت جدید">✏️</button>

<div class="toast" id="toast"></div>'''
    c = c.replace(old, new)

# ─── نوار تاریخ بالای لیست پیام‌ها ───
if 'date-separator' not in c:
    # اضافه کردن CSS برای date separator در style.css
    pass

# ─── تب‌بار موبایل پایین ───
if 'mobile-tabbar' not in c:
    old = '''<div class="toast" id="toast"></div>'''
    new = '''<nav class="mobile-tabbar" id="mobileTabbar">
  <button data-tab="chats" class="active">
    <span class="icon">💬</span>
    <span class="label">چت‌ها</span>
  </button>
  <button data-tab="contacts">
    <span class="icon">👥</span>
    <span class="label">مخاطبین</span>
  </button>
  <button data-tab="profile">
    <span class="icon">👤</span>
    <span class="label">من</span>
  </button>
</nav>

<div class="toast" id="toast"></div>'''
    c = c.replace(old, new)

fp.write_text(c, encoding="utf-8")
print("✅ chat.html آپدیت شد")
PYEOF

# ═══════════════════════════════════════════════════════
# ۲) CSS: استایل‌های اضافه
# ═══════════════════════════════════════════════════════
cat >> css/style.css << 'CSS_EOF'

/* ═══════════════════════════════════════════
   🎨 قابلیت‌های اضافی روبیکا
   ═══════════════════════════════════════════ */

/* ─── FAB (دکمه شناور پیام جدید) ─── */
.fab-new-chat {
  position: fixed;
  bottom: 30px;
  left: 30px;
  width: 60px;
  height: 60px;
  border-radius: 20px;
  border: none;
  background: var(--gradient);
  color: #fff;
  font-size: 26px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 12px 30px -8px rgba(123, 79, 224, 0.55);
  transition: all .25s cubic-bezier(.34,1.56,.64,1);
  z-index: 100;
  display: none;
}

.fab-new-chat.show {
  display: flex;
}

.fab-new-chat:hover {
  transform: translateY(-3px) scale(1.05);
  box-shadow: 0 18px 40px -8px rgba(123, 79, 224, 0.65);
}

.fab-new-chat:active {
  transform: scale(.95);
}

/* ─── نوار تاریخ (Date Separator) ─── */
.date-separator {
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 16px 0 8px;
  position: relative;
}

.date-separator span {
  padding: 5px 14px;
  background: rgba(123, 79, 224, 0.1);
  color: var(--primary);
  font-size: 11.5px;
  font-weight: 700;
  border-radius: 12px;
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  border: 1px solid rgba(123, 79, 224, 0.15);
  z-index: 1;
}

body.dark .date-separator span {
  background: rgba(123, 79, 224, 0.2);
  border-color: rgba(123, 79, 224, 0.3);
  color: var(--primary-light);
}

/* ─── تب‌بار موبایل پایین ─── */
.mobile-tabbar {
  display: none;
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: var(--card);
  border-top: 1px solid var(--border);
  z-index: 200;
  box-shadow: 0 -4px 20px rgba(31, 44, 61, 0.08);
  padding-bottom: env(safe-area-inset-bottom);
}

.mobile-tabbar button {
  flex: 1;
  padding: 10px 4px 8px;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  font-family: inherit;
  cursor: pointer;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 3px;
  transition: color .2s;
  position: relative;
}

.mobile-tabbar button .icon {
  font-size: 22px;
  line-height: 1;
}

.mobile-tabbar button .label {
  font-size: 11px;
  font-weight: 700;
}

.mobile-tabbar button.active {
  color: var(--primary);
}

.mobile-tabbar button.active::before {
  content: "";
  position: absolute;
  top: 0;
  left: 30%;
  right: 30%;
  height: 3px;
  background: var(--gradient);
  border-radius: 0 0 4px 4px;
}

/* ─── تب‌بار سایدبار: فیلتر فعال ─── */
.rubika-tabs button {
  position: relative;
}

/* ─── حالت جستجو در سایدبار (نمایش نتایج) ─── */
.user-item.hidden-filter {
  display: none;
}

/* ─── Empty filter state ─── */
.filter-empty {
  padding: 40px 20px;
  text-align: center;
  color: var(--text-secondary);
  font-size: 13.5px;
  line-height: 1.8;
}

.filter-empty .emoji {
  font-size: 48px;
  display: block;
  margin-bottom: 12px;
  opacity: .4;
}

/* ─── Online/offline در هدر چت ─── */
.chat-header .info p.online::before {
  content: "●";
  color: var(--online);
  margin-left: 5px;
  font-size: 8px;
  vertical-align: middle;
}

/* ─── انیمیشن برای کاربر فعال در لیست ─── */
.user-item.active .avatar {
  box-shadow: 0 0 0 3px rgba(123, 79, 224, 0.25);
}

/* ─── Unread-only badge در تب فیلتر ─── */
.rubika-tabs button .tab-badge {
  position: absolute;
  top: 6px;
  right: calc(50% - 22px);
  background: var(--danger);
  color: #fff;
  font-size: 9.5px;
  font-weight: 800;
  min-width: 16px;
  height: 16px;
  padding: 0 4px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  line-height: 1;
}

/* ─── موبایل ─── */
@media (max-width: 768px) {
  .mobile-tabbar {
    display: flex;
  }

  .chat-app {
    padding-bottom: 62px;
  }

  .fab-new-chat {
    bottom: 80px;
    left: 20px;
    width: 54px;
    height: 54px;
    font-size: 22px;
  }

  /* وقتی داخل چت هستیم، tabbar را مخفی کن */
  body.in-chat .mobile-tabbar {
    display: none;
  }

  body.in-chat .chat-app {
    padding-bottom: 0;
  }

  body.in-chat .fab-new-chat {
    display: none !important;
  }

  /* تب‌بار بالای سایدبار در موبایل کمی جمع‌تر */
  .rubika-tabs {
    padding: 0 8px;
  }

  .rubika-tabs button {
    font-size: 12px;
    padding: 10px 6px;
  }
}
CSS_EOF

echo "✅ style.css آپدیت شد"

# ═══════════════════════════════════════════════════════
# ۳) JS: توابع فیلتر، FAB، نوار تاریخ، تب‌بار موبایل
# ═══════════════════════════════════════════════════════
python << 'PYEOF'
from pathlib import Path

fp = Path("js/chat.js")
c = fp.read_text(encoding="utf-8")

# ─── متغیرهای جدید ───
if 'currentFilter' not in c:
    c = c.replace(
        "let pinnedMsg = null;",
        """let pinnedMsg = null;
let currentFilter = 'all';  // all | unread | online"""
    )

# ─── تابع فیلتر ───
filter_funcs = r'''

// ═══════════════════════════════════════════
// 🎨 فیلتر تب‌بار سایدبار
// ═══════════════════════════════════════════
function setupFilterTabs() {
  document.querySelectorAll('.rubika-tabs button').forEach(btn => {
    btn.onclick = () => {
      document.querySelectorAll('.rubika-tabs button').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      currentFilter = btn.dataset.tab;
      renderUsers($('searchInput').value);
    };
  });
}

function applyFilter(users) {
  if (currentFilter === 'online') {
    return users.filter(u => u.is_online);
  }
  if (currentFilter === 'unread') {
    return users.filter(u => (unreadCounts[u.id] || 0) > 0);
  }
  return users;
}

function updateFilterBadge() {
  const unreadBtn = document.querySelector('.rubika-tabs button[data-tab="unread"]');
  if (!unreadBtn) return;
  const total = Object.values(unreadCounts).reduce((a, b) => a + b, 0);
  let badge = unreadBtn.querySelector('.tab-badge');
  if (total > 0) {
    if (!badge) {
      badge = document.createElement('span');
      badge.className = 'tab-badge';
      unreadBtn.appendChild(badge);
    }
    badge.textContent = total > 99 ? '99+' : total;
  } else if (badge) {
    badge.remove();
  }
}

// ═══════════════════════════════════════════
// 🎨 نوار تاریخ بین پیام‌ها
// ═══════════════════════════════════════════
function shouldShowDate(currentMsg, prevMsg) {
  if (!prevMsg) return true;
  const d1 = new Date(currentMsg.created_at);
  const d2 = new Date(prevMsg.created_at);
  return d1.toDateString() !== d2.toDateString();
}

function formatDateSeparator(dateStr) {
  const d = new Date(dateStr);
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);
  const msgDay = new Date(d.getFullYear(), d.getMonth(), d.getDate());

  if (msgDay.getTime() === today.getTime()) return 'امروز';
  if (msgDay.getTime() === yesterday.getTime()) return 'دیروز';

  // محاسبه اختلاف روزها
  const diffDays = Math.floor((today - msgDay) / (1000 * 60 * 60 * 24));
  if (diffDays < 7) {
    const days = ['یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه'];
    return days[d.getDay()];
  }

  const months = ['فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
                  'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'];
  // تبدیل میلادی به شمسی (تقریبی - از Intl استفاده می‌کنیم)
  try {
    return new Intl.DateTimeFormat('fa-IR', {
      year: 'numeric', month: 'long', day: 'numeric'
    }).format(d);
  } catch (e) {
    return d.toLocaleDateString('fa-IR');
  }
}

// ═══════════════════════════════════════════
// 🎨 FAB (دکمه شناور)
// ═══════════════════════════════════════════
function setupFAB() {
  const fab = $('fabNewChat');
  if (!fab) return;
  fab.onclick = () => {
    // اسکرول به لیست کاربران
    $('sidebar').classList.remove('hidden');
    setTimeout(() => {
      const firstUser = document.querySelector('.user-item');
      if (firstUser) firstUser.click();
    }, 200);
  };
}

// ═══════════════════════════════════════════
// 🎨 تب‌بار موبایل
// ═══════════════════════════════════════════
function setupMobileTabbar() {
  const tabbar = $('mobileTabbar');
  if (!tabbar) return;

  tabbar.querySelectorAll('button').forEach(btn => {
    btn.onclick = () => {
      tabbar.querySelectorAll('button').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const tab = btn.dataset.tab;

      if (tab === 'chats' || tab === 'contacts') {
        $('sidebar').classList.remove('hidden');
        document.body.classList.remove('in-chat');
      } else if (tab === 'profile') {
        openProfileModal();
      }
    };
  });
}

// ─── تغییر وضعیت in-chat ───
function setInChat(inChat) {
  if (inChat) {
    document.body.classList.add('in-chat');
  } else {
    document.body.classList.remove('in-chat');
  }
}

'''

# اضافه کردن توابع قبل از init()
if 'setupFilterTabs' not in c:
    c = c.replace("init();", filter_funcs + "init();")

# ─── در init: صدا زدن setupها ───
init_additions = """
  // 🎨 setup‌های روبیکا
  setupFilterTabs();
  setupFAB();
  setupMobileTabbar();
"""
if 'setupFilterTabs();' in c and 'setupFilterTabs();\n  setupFAB();' not in c.split("async function init()")[1].split("}")[0] if 'async function init()' in c else False:
    pass

# جای مناسب: بعد از applyAutoTheme();
if 'setupFilterTabs();' not in c.split("applyAutoTheme();")[1][:500] if 'applyAutoTheme();' in c else False:
    c = c.replace(
        "  // حالت خودکار بر اساس ساعت\n  applyAutoTheme();",
        "  // حالت خودکار بر اساس ساعت\n  applyAutoTheme();\n\n  // 🎨 setup‌های روبیکا\n  setupFilterTabs();\n  setupFAB();\n  setupMobileTabbar();"
    )

# ─── در renderUsers: اعمال فیلتر ───
old_filter = """  const filtered = q
    ? allUsers.filter(u => (u.username || '').toLowerCase().includes(q) || (u.display_name || '').toLowerCase().includes(q))
    : allUsers;"""

new_filter = """  let baseList = allUsers;
  // اعمال فیلتر تب
  baseList = applyFilter(baseList);
  // اعمال فیلتر جستجو
  const filtered = q
    ? baseList.filter(u => (u.username || '').toLowerCase().includes(q) || (u.display_name || '').toLowerCase().includes(q))
    : baseList;"""

if old_filter in c:
    c = c.replace(old_filter, new_filter)
    print("✅ فیلتر تب به renderUsers اضافه شد")

# ─── در renderAllMessages: نوار تاریخ ───
old_render = """function renderAllMessages() {
  const area = $('messagesArea');
  area.innerHTML = '';
  if (!allMessages.length) {
    area.innerHTML = '<div class="empty-chat" style="flex:1"><div class="big-icon">✨</div><p>اولین پیام را بفرست!</p></div>';
    return;
  }
  allMessages.forEach(m => renderMessage(m));
}"""

new_render = """function renderAllMessages() {
  const area = $('messagesArea');
  area.innerHTML = '';
  if (!allMessages.length) {
    area.innerHTML = '<div class="empty-chat" style="flex:1"><div class="big-icon">✨</div><p>اولین پیام را بفرست!</p></div>';
    return;
  }
  allMessages.forEach((m, i) => {
    const prev = i > 0 ? allMessages[i - 1] : null;
    if (shouldShowDate(m, prev)) {
      const sep = document.createElement('div');
      sep.className = 'date-separator';
      sep.innerHTML = '<span>' + formatDateSeparator(m.created_at) + '</span>';
      area.appendChild(sep);
    }
    renderMessage(m);
  });
}"""

if old_render in c:
    c = c.replace(old_render, new_render)
    print("✅ نوار تاریخ به renderAllMessages اضافه شد")

# ─── در selectUser: setInChat(true) ───
old_select = """  $('chatHeader').style.display = 'flex';
  $('composer').style.display = 'flex';
  $('sidebar').classList.add('hidden');
  renderUsers();"""

new_select = """  $('chatHeader').style.display = 'flex';
  $('composer').style.display = 'flex';
  $('sidebar').classList.add('hidden');
  setInChat(true);
  renderUsers();"""

if old_select in c:
    c = c.replace(old_select, new_select)
    print("✅ setInChat(true) اضافه شد")

# ─── در backBtn: setInChat(false) ───
old_back = "$('backBtn').onclick = () => $('sidebar').classList.remove('hidden');"
new_back = "$('backBtn').onclick = () => { $('sidebar').classList.remove('hidden'); setInChat(false); };"

if old_back in c:
    c = c.replace(old_back, new_back)
    print("✅ setInChat(false) اضافه شد")

# ─── در loadUnreadCounts: آپدیت بج فیلتر ───
old_unread = """    unreadCounts = counts;
  } catch (e) {}
}"""

new_unread = """    unreadCounts = counts;
    updateFilterBadge();
  } catch (e) {}
}"""

if old_unread in c:
    c = c.replace(old_unread, new_unread)
    print("✅ updateFilterBadge اضافه شد")

# ─── نمایش FAB فقط وقتی در چت نیستیم و کاربران هستن ───
old_render_end = """  list.querySelectorAll('.user-item').forEach(el => {
    el.onclick = () => selectUser(el.dataset.id);
  });
}"""

new_render_end = """  list.querySelectorAll('.user-item').forEach(el => {
    el.onclick = () => selectUser(el.dataset.id);
  });

  // FAB را نشان بده اگر کاربران موجود هستند و در حالت چت نیستیم
  const fab = $('fabNewChat');
  if (fab) {
    if (allUsers.length > 0 && !document.body.classList.contains('in-chat')) {
      fab.classList.add('show');
    } else {
      fab.classList.remove('show');
    }
  }
}"""

if old_render_end in c:
    c = c.replace(old_render_end, new_render_end, 1)
    print("✅ FAB show/hide اضافه شد")

fp.write_text(c, encoding="utf-8")
print("✅ chat.js آپدیت شد")
PYEOF

echo ""
echo "═══════════════════════════════════════════════════════"
echo "✅ همه قابلیت‌ها اضافه شد!"
echo "═══════════════════════════════════════════════════════"
