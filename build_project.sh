#!/bin/bash
# ═══════════════════════════════════════════════════════
#  🚀 ساخت خودکار پروژه پیام‌رسان خصوصی
# ═══════════════════════════════════════════════════════

set -e
echo "🏗️  شروع ساخت پروژه..."
echo ""

# ساخت پوشه‌ها
mkdir -p css js
echo "📁 پوشه‌ها ساخته شد"

# ═══════════════════════════════════════════════════════
# ۱) index.html
# ═══════════════════════════════════════════════════════
cat > index.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ورود — پیام‌رسان خصوصی</title>
<link rel="stylesheet" href="./css/style.css">
</head>
<body>
<div class="auth-page">
  <div class="auth-card">
    <div class="auth-logo">💬</div>
    <h1>پیام‌رسان خصوصی</h1>
    <p class="sub">برای خودت و دوستت — امن و سریع</p>

    <div class="auth-tabs">
      <button id="tabLogin" class="active">ورود</button>
      <button id="tabSignup">ثبت‌نام</button>
    </div>

    <div id="errorBox" class="error-box"></div>
    <div id="successBox" class="success-box"></div>

    <form id="loginForm">
      <div class="form-group">
        <label>ایمیل</label>
        <input type="email" id="loginEmail" required placeholder="you@example.com">
      </div>
      <div class="form-group">
        <label>رمز عبور</label>
        <input type="password" id="loginPassword" required placeholder="••••••••">
      </div>
      <button type="submit" id="loginBtn" class="btn-primary">ورود</button>
    </form>

    <form id="signupForm" style="display:none">
      <div class="form-group">
        <label>نام کاربری (انگلیسی)</label>
        <input type="text" id="signupUsername" required placeholder="ali_reza" pattern="[a-zA-Z0-9_]{3,20}">
      </div>
      <div class="form-group">
        <label>نام نمایشی</label>
        <input type="text" id="signupDisplayName" required placeholder="علی رضایی">
      </div>
      <div class="form-group">
        <label>ایمیل</label>
        <input type="email" id="signupEmail" required placeholder="you@example.com">
      </div>
      <div class="form-group">
        <label>رمز عبور (حداقل ۶ کاراکتر)</label>
        <input type="password" id="signupPassword" required minlength="6" placeholder="••••••••">
      </div>
      <button type="submit" id="signupBtn" class="btn-primary">ساخت حساب</button>
    </form>
  </div>
</div>

<div class="toast" id="toast"></div>

<script type="module">
import { signIn, signUp, redirectIfLoggedIn } from './js/auth.js';
import { showToast, showError, hideError, setLoading } from './js/ui.js';

redirectIfLoggedIn();

const tabLogin = document.getElementById('tabLogin');
const tabSignup = document.getElementById('tabSignup');
const loginForm = document.getElementById('loginForm');
const signupForm = document.getElementById('signupForm');
const errorBox = document.getElementById('errorBox');
const successBox = document.getElementById('successBox');

tabLogin.onclick = () => {
  tabLogin.classList.add('active');
  tabSignup.classList.remove('active');
  loginForm.style.display = 'block';
  signupForm.style.display = 'none';
  hideError(errorBox); hideError(successBox);
};

tabSignup.onclick = () => {
  tabSignup.classList.add('active');
  tabLogin.classList.remove('active');
  signupForm.style.display = 'block';
  loginForm.style.display = 'none';
  hideError(errorBox); hideError(successBox);
};

loginForm.onsubmit = async (e) => {
  e.preventDefault();
  hideError(errorBox);
  const btn = document.getElementById('loginBtn');
  setLoading(btn, true, 'در حال ورود...');
  const email = document.getElementById('loginEmail').value.trim();
  const password = document.getElementById('loginPassword').value;
  const { error } = await signIn(email, password);
  if (error) {
    showError(errorBox, 'خطا در ورود: ' + error.message);
    setLoading(btn, false);
    return;
  }
  showToast('خوش آمدی!', 'success');
  setTimeout(() => window.location.href = './chat.html', 400);
};

signupForm.onsubmit = async (e) => {
  e.preventDefault();
  hideError(errorBox); hideError(successBox);
  const btn = document.getElementById('signupBtn');
  setLoading(btn, true, 'در حال ساخت...');
  const username = document.getElementById('signupUsername').value.trim();
  const displayName = document.getElementById('signupDisplayName').value.trim();
  const email = document.getElementById('signupEmail').value.trim();
  const password = document.getElementById('signupPassword').value;
  const { error } = await signUp({ email, password, username, displayName });
  if (error) {
    showError(errorBox, 'خطا در ثبت‌نام: ' + error.message);
    setLoading(btn, false);
    return;
  }
  successBox.textContent = '✅ حساب ساخته شد! حالا می‌توانی وارد شوی.';
  successBox.style.display = 'block';
  setLoading(btn, false);
  showToast('ثبت‌نام موفق!', 'success');
  setTimeout(() => {
    tabLogin.click();
    document.getElementById('loginEmail').value = email;
  }, 1500);
};
</script>
</body>
</html>
HTML_EOF
echo "✅ index.html"

# ═══════════════════════════════════════════════════════
# ۲) chat.html
# ═══════════════════════════════════════════════════════
cat > chat.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>چت — پیام‌رسان خصوصی</title>
<link rel="stylesheet" href="./css/style.css">
</head>
<body>
<div class="chat-app">
  <aside class="sidebar" id="sidebar">
    <div class="sidebar-header">
      <div class="logo">💬</div>
      <div class="info">
        <h3 id="myName">...</h3>
        <p id="myStatus">آنلاین</p>
      </div>
      <button class="icon-btn" id="themeBtn" title="تغییر تم">🌙</button>
      <button class="icon-btn" id="logoutBtn" title="خروج">🚪</button>
    </div>
    <div class="search-box">
      <input type="text" id="searchInput" placeholder="🔍 جستجوی کاربر...">
    </div>
    <div class="user-list" id="userList">
      <div style="text-align:center;padding:30px;color:var(--muted);font-size:13px">
        در حال بارگذاری کاربران...
      </div>
    </div>
  </aside>

  <main class="chat-area">
    <div class="chat-header" id="chatHeader" style="display:none">
      <button class="icon-btn back-btn" id="backBtn">←</button>
      <div class="avatar" id="chatAvatar"></div>
      <div class="info">
        <h3 id="chatName"></h3>
        <p id="chatStatus"></p>
      </div>
    </div>

    <div class="messages-area" id="messagesArea">
      <div class="empty-chat">
        <div class="big-icon">💬</div>
        <p>یک کاربر را از لیست انتخاب کن تا چت شروع شود</p>
      </div>
    </div>

    <div class="typing-indicator" id="typingIndicator"></div>

    <div class="composer" id="composer" style="display:none">
      <textarea id="messageInput" placeholder="پیامت را بنویس..." rows="1"></textarea>
      <button class="send-btn" id="sendBtn" disabled>📤</button>
    </div>
  </main>
</div>

<div class="toast" id="toast"></div>
<script type="module" src="./js/chat.js"></script>
</body>
</html>
HTML_EOF
echo "✅ chat.html"

# ═══════════════════════════════════════════════════════
# ۳) css/style.css
# ═══════════════════════════════════════════════════════
cat > css/style.css << 'CSS_EOF'
* { box-sizing: border-box; margin: 0; padding: 0; }
:root {
  --accent: #6366f1; --accent2: #8b5cf6; --accent3: #ec4899;
  --bg: #f1f5f9; --card: #ffffff; --text: #0f172a; --muted: #64748b;
  --border: #e2e8f0; --success: #10b981; --danger: #ef4444;
  --shadow: 0 10px 30px -12px rgba(15, 23, 42, 0.15);
}
body.dark {
  --bg: #0f172a; --card: #1e293b; --text: #f1f5f9; --muted: #94a3b8; --border: #334155;
}
html, body { height: 100%; }
body {
  font-family: Tahoma, "Segoe UI", system-ui, Arial, sans-serif;
  background: var(--bg); color: var(--text); direction: rtl;
  line-height: 1.6; transition: background .3s, color .3s;
}
.auth-page {
  min-height: 100vh; display: flex; align-items: center; justify-content: center;
  padding: 20px;
  background:
    radial-gradient(circle at 15% 15%, rgba(99,102,241,.25), transparent 40%),
    radial-gradient(circle at 85% 85%, rgba(236,72,153,.2), transparent 40%),
    linear-gradient(135deg, #f8fafc, #eef2ff);
}
body.dark .auth-page {
  background:
    radial-gradient(circle at 15% 15%, rgba(99,102,241,.2), transparent 40%),
    radial-gradient(circle at 85% 85%, rgba(236,72,153,.15), transparent 40%),
    linear-gradient(135deg, #0f172a, #1e1b4b);
}
.auth-card {
  width: 100%; max-width: 440px; background: var(--card);
  border-radius: 24px; padding: 36px 28px;
  box-shadow: var(--shadow); border: 1.5px solid var(--border);
}
.auth-logo {
  width: 72px; height: 72px; border-radius: 20px;
  background: linear-gradient(135deg, var(--accent), var(--accent3));
  display: flex; align-items: center; justify-content: center;
  font-size: 34px; margin: 0 auto 16px;
  box-shadow: 0 15px 35px -10px rgba(99,102,241,.5);
}
.auth-card h1 {
  text-align: center; font-size: 22px; font-weight: 800; margin-bottom: 6px;
  background: linear-gradient(135deg, var(--accent), var(--accent3));
  -webkit-background-clip: text; -webkit-text-fill-color: transparent;
  background-clip: text;
}
.auth-card p.sub { text-align: center; color: var(--muted); font-size: 13.5px; margin-bottom: 24px; }
.auth-tabs {
  display: flex; background: var(--bg); border-radius: 12px;
  padding: 4px; margin-bottom: 22px;
}
.auth-tabs button {
  flex: 1; padding: 10px; border: none; background: transparent;
  border-radius: 9px; cursor: pointer; font-family: inherit;
  font-size: 14px; font-weight: 700; color: var(--muted); transition: all .2s;
}
.auth-tabs button.active {
  background: var(--card); color: var(--accent);
  box-shadow: 0 3px 8px -3px rgba(99,102,241,.4);
}
.form-group { margin-bottom: 14px; }
.form-group label { display: block; font-size: 13px; font-weight: 700; margin-bottom: 6px; }
.form-group input {
  width: 100%; padding: 12px 14px; border: 1.5px solid var(--border);
  border-radius: 12px; background: var(--bg); color: var(--text);
  font-family: inherit; font-size: 14.5px; outline: none; transition: all .2s;
}
.form-group input:focus {
  border-color: var(--accent); background: var(--card);
  box-shadow: 0 0 0 3px rgba(99,102,241,.15);
}
.btn-primary {
  width: 100%; padding: 13px; border: none; border-radius: 12px;
  background: linear-gradient(135deg, var(--accent), var(--accent2));
  color: #fff; font-family: inherit; font-size: 15px; font-weight: 700;
  cursor: pointer; transition: all .2s;
  box-shadow: 0 10px 25px -8px rgba(99,102,241,.6);
}
.btn-primary:hover:not(:disabled) { transform: translateY(-2px); box-shadow: 0 15px 35px -8px rgba(99,102,241,.7); }
.btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.error-box {
  display: none; padding: 10px 14px;
  background: rgba(239,68,68,.1); color: var(--danger);
  border: 1px solid rgba(239,68,68,.3); border-radius: 10px;
  font-size: 13px; margin-bottom: 14px;
}
.success-box {
  display: none; padding: 10px 14px;
  background: rgba(16,185,129,.1); color: var(--success);
  border: 1px solid rgba(16,185,129,.3); border-radius: 10px;
  font-size: 13px; margin-bottom: 14px;
}
.chat-app { height: 100vh; display: grid; grid-template-columns: 320px 1fr; overflow: hidden; }
.sidebar {
  background: var(--card); border-left: 1.5px solid var(--border);
  display: flex; flex-direction: column; overflow: hidden;
}
.sidebar-header {
  padding: 16px 18px; border-bottom: 1.5px solid var(--border);
  display: flex; align-items: center; gap: 10px;
}
.sidebar-header .logo {
  width: 42px; height: 42px; border-radius: 12px;
  background: linear-gradient(135deg, var(--accent), var(--accent3));
  display: flex; align-items: center; justify-content: center;
  font-size: 20px; color: #fff; flex-shrink: 0;
}
.sidebar-header .info { flex: 1; min-width: 0; }
.sidebar-header .info h3 {
  font-size: 14px; font-weight: 800;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.sidebar-header .info p { font-size: 11.5px; color: var(--muted); }
.icon-btn {
  width: 38px; height: 38px; border-radius: 10px;
  border: 1.5px solid var(--border); background: var(--card); color: var(--text);
  cursor: pointer; display: flex; align-items: center; justify-content: center;
  font-size: 16px; transition: all .2s; flex-shrink: 0;
}
.icon-btn:hover { border-color: var(--accent); color: var(--accent); transform: translateY(-1px); }
.search-box { padding: 12px 18px; border-bottom: 1.5px solid var(--border); }
.search-box input {
  width: 100%; padding: 10px 14px; border: 1.5px solid var(--border);
  border-radius: 10px; background: var(--bg); color: var(--text);
  font-family: inherit; font-size: 13.5px; outline: none; transition: all .2s;
}
.search-box input:focus { border-color: var(--accent); background: var(--card); }
.user-list { flex: 1; overflow-y: auto; padding: 8px; }
.user-item {
  display: flex; align-items: center; gap: 12px; padding: 11px 12px;
  border-radius: 12px; cursor: pointer; transition: all .2s; margin-bottom: 3px;
}
.user-item:hover { background: var(--bg); }
.user-item.active {
  background: linear-gradient(135deg, rgba(99,102,241,.1), rgba(139,92,246,.1));
  border: 1.5px solid rgba(99,102,241,.3);
}
.avatar {
  width: 44px; height: 44px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  color: #fff; font-weight: 800; font-size: 15px; flex-shrink: 0; position: relative;
}
.avatar .online-dot {
  position: absolute; bottom: 0; left: 0;
  width: 12px; height: 12px; background: var(--success);
  border: 2px solid var(--card); border-radius: 50%;
}
.user-item .info { flex: 1; min-width: 0; }
.user-item .info h4 {
  font-size: 14px; font-weight: 700;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.user-item .info p {
  font-size: 12px; color: var(--muted);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis; margin-top: 2px;
}
.chat-area { display: flex; flex-direction: column; background: var(--bg); overflow: hidden; }
.chat-header {
  padding: 14px 20px; background: var(--card);
  border-bottom: 1.5px solid var(--border);
  display: flex; align-items: center; gap: 12px;
}
.chat-header .info { flex: 1; min-width: 0; }
.chat-header .info h3 { font-size: 15px; font-weight: 800; }
.chat-header .info p { font-size: 12px; color: var(--muted); }
.messages-area {
  flex: 1; overflow-y: auto; padding: 20px;
  display: flex; flex-direction: column; gap: 10px;
}
.empty-chat {
  flex: 1; display: flex; flex-direction: column;
  align-items: center; justify-content: center;
  color: var(--muted); text-align: center; gap: 12px;
}
.empty-chat .big-icon { font-size: 64px; opacity: .3; }
.message {
  display: flex; gap: 8px; max-width: 70%;
  animation: msgIn .3s cubic-bezier(.34,1.56,.64,1);
}
@keyframes msgIn { from { opacity: 0; transform: translateY(8px) scale(.95); } to { opacity: 1; transform: translateY(0) scale(1); } }
.message.mine { align-self: flex-start; flex-direction: row-reverse; }
.message.theirs { align-self: flex-end; }
.message .bubble {
  padding: 10px 14px; border-radius: 16px; font-size: 14.5px;
  line-height: 1.55; word-wrap: break-word; white-space: pre-wrap;
  position: relative; min-width: 60px;
}
.message.mine .bubble {
  background: linear-gradient(135deg, var(--accent), var(--accent2));
  color: #fff; border-bottom-right-radius: 4px;
}
.message.theirs .bubble {
  background: var(--card); color: var(--text);
  border: 1.5px solid var(--border); border-bottom-left-radius: 4px;
}
.message .meta { font-size: 10.5px; opacity: .7; margin-top: 4px; display: block; text-align: left; }
.msg-avatar {
  width: 34px; height: 34px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  color: #fff; font-weight: 700; font-size: 12px; flex-shrink: 0;
}
.typing-indicator {
  padding: 8px 20px; font-size: 12.5px; color: var(--muted);
  font-style: italic; height: 26px;
}
.composer {
  padding: 14px 20px; background: var(--card);
  border-top: 1.5px solid var(--border);
  display: flex; gap: 10px; align-items: flex-end;
}
.composer textarea {
  flex: 1; padding: 11px 14px; border: 1.5px solid var(--border);
  border-radius: 14px; background: var(--bg); color: var(--text);
  font-family: inherit; font-size: 14.5px; outline: none; resize: none;
  max-height: 140px; min-height: 46px; transition: all .2s; line-height: 1.5;
}
.composer textarea:focus { border-color: var(--accent); background: var(--card); }
.send-btn {
  width: 46px; height: 46px; border-radius: 14px; border: none;
  background: linear-gradient(135deg, var(--accent), var(--accent2));
  color: #fff; font-size: 20px; cursor: pointer; transition: all .2s;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0; box-shadow: 0 8px 20px -6px rgba(99,102,241,.6);
}
.send-btn:hover:not(:disabled) { transform: translateY(-2px); }
.send-btn:disabled { opacity: .5; cursor: not-allowed; }
.toast {
  position: fixed; bottom: 24px; left: 50%;
  transform: translateX(-50%) translateY(80px);
  background: var(--text); color: var(--bg);
  padding: 12px 22px; border-radius: 12px;
  font-size: 13.5px; font-weight: 700;
  box-shadow: 0 15px 40px -10px rgba(0,0,0,.4);
  z-index: 999; opacity: 0;
  transition: all .3s cubic-bezier(.34,1.56,.64,1);
  pointer-events: none; max-width: 90vw;
}
.toast.show { transform: translateX(-50%) translateY(0); opacity: 1; }
.toast.success { background: var(--success); color: #fff; }
.toast.error { background: var(--danger); color: #fff; }
@media (max-width: 768px) {
  .chat-app { grid-template-columns: 1fr; }
  .sidebar { position: absolute; inset: 0; z-index: 10; transition: transform .3s; }
  .sidebar.hidden { transform: translateX(100%); }
  .message { max-width: 85%; }
}
.back-btn { display: none; }
@media (max-width: 768px) { .back-btn { display: flex; } }
::-webkit-scrollbar { width: 8px; height: 8px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: var(--border); border-radius: 10px; }
::-webkit-scrollbar-thumb:hover { background: var(--muted); }
CSS_EOF
echo "✅ css/style.css"

# ═══════════════════════════════════════════════════════
# ۴) js/config.js
# ═══════════════════════════════════════════════════════
cat > js/config.js << 'JS_EOF'
// js/config.js
// ⚠️ این دو مقدار را از داشبورد Supabase بردار:
// Settings → API Keys

export const SUPABASE_URL = 'https://mxvdumsoywlghcnqniju.supabase.co';
export const SUPABASE_ANON_KEY = 'PASTE_YOUR_ANON_KEY_HERE';

export const APP_NAME = 'پیام‌رسان خصوصی';
JS_EOF
echo "✅ js/config.js"

# ═══════════════════════════════════════════════════════
# ۵) js/supabase-client.js
# ═══════════════════════════════════════════════════════
cat > js/supabase-client.js << 'JS_EOF'
// js/supabase-client.js
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from './config.js';

if (SUPABASE_URL.includes('YOUR_') || SUPABASE_ANON_KEY.includes('PASTE_')) {
  console.error('❌ لطفاً مقادیر Supabase را در js/config.js تنظیم کن.');
}

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
  realtime: { params: { eventsPerSecond: 10 } }
});
JS_EOF
echo "✅ js/supabase-client.js"

# ═══════════════════════════════════════════════════════
# ۶) js/auth.js
# ═══════════════════════════════════════════════════════
cat > js/auth.js << 'JS_EOF'
// js/auth.js
import { supabase } from './supabase-client.js';

export async function signUp({ email, password, username, displayName }) {
  const { data, error } = await supabase.auth.signUp({
    email, password,
    options: { data: { username: username.toLowerCase().trim(), display_name: displayName || username } }
  });
  return { data, error };
}

export async function signIn(email, password) {
  return await supabase.auth.signInWithPassword({ email, password });
}

export async function signOut() {
  await supabase.auth.signOut();
}

export async function getCurrentUser() {
  const { data: { user } } = await supabase.auth.getUser();
  return user;
}

export async function getProfile(userId) {
  return await supabase.from('profiles').select('*').eq('id', userId).single();
}

export async function requireAuth() {
  const user = await getCurrentUser();
  if (!user) { window.location.href = './index.html'; return null; }
  return user;
}

export async function redirectIfLoggedIn() {
  const user = await getCurrentUser();
  if (user) window.location.href = './chat.html';
}
JS_EOF
echo "✅ js/auth.js"

# ═══════════════════════════════════════════════════════
# ۷) js/ui.js
# ═══════════════════════════════════════════════════════
cat > js/ui.js << 'JS_EOF'
// js/ui.js
export function showToast(message, type = 'info') {
  const toast = document.getElementById('toast');
  if (!toast) return;
  toast.textContent = message;
  toast.className = `toast show ${type}`;
  clearTimeout(toast._timer);
  toast._timer = setTimeout(() => toast.classList.remove('show'), 3000);
}

export function showError(el, message) { if (el) { el.textContent = message; el.style.display = 'block'; } }
export function hideError(el) { if (el) el.style.display = 'none'; }

export function setLoading(btn, loading, textLoading = 'لطفاً صبر کنید...') {
  if (!btn) return;
  if (loading) { btn._originalText = btn.textContent; btn.disabled = true; btn.textContent = textLoading; }
  else { btn.disabled = false; btn.textContent = btn._originalText || btn.textContent; }
}

export function formatTime(dateStr) {
  const d = new Date(dateStr);
  const now = new Date();
  const diff = (now - d) / 1000;
  if (diff < 60) return 'الان';
  if (diff < 3600) return Math.floor(diff / 60) + ' دقیقه پیش';
  const isToday = d.toDateString() === now.toDateString();
  const hh = String(d.getHours()).padStart(2, '0');
  const mm = String(d.getMinutes()).padStart(2, '0');
  if (isToday) return `${hh}:${mm}`;
  const yesterday = new Date(now); yesterday.setDate(now.getDate() - 1);
  if (d.toDateString() === yesterday.toDateString()) return `دیروز ${hh}:${mm}`;
  return `${d.getFullYear()}/${String(d.getMonth()+1).padStart(2,'0')}/${String(d.getDate()).padStart(2,'0')}`;
}

export function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

export function getInitials(name) {
  if (!name) return '?';
  return name.trim().split(/\s+/).map(w => w[0]).slice(0, 2).join('').toUpperCase();
}

export function avatarColor(seed) {
  const colors = ['#6366f1','#ec4899','#10b981','#f59e0b','#8b5cf6','#ef4444','#06b6d4','#84cc16'];
  let hash = 0;
  for (const c of seed) hash = (hash * 31 + c.charCodeAt(0)) | 0;
  return colors[Math.abs(hash) % colors.length];
}
JS_EOF
echo "✅ js/ui.js"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "✅ فایل‌های اصلی ساخته شدند"
echo "═══════════════════════════════════════════════════════"
