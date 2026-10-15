#!/bin/bash
echo "🎨 شروع بازطراحی کامل..."
echo ""

# ═══════════════════════════════════════════════════════
# ۱) chat.html — ساختار کامل روبیکا
# ═══════════════════════════════════════════════════════
cat > chat.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<meta name="theme-color" content="#7B4FE0">
<title>پیام‌رسان</title>
<link href="https://cdn.jsdelivr.net/gh/rastikerdar/vazirmatn@v33.003/Vazirmatn-font-face.css" rel="stylesheet">
<link rel="manifest" href="./manifest.json">
<link rel="stylesheet" href="./css/style.css">
</head>
<body>

<div class="chat-app">

  <!-- ═══════════ SIDEBAR ═══════════ -->
  <aside class="sidebar" id="sidebar">

    <!-- Header -->
    <div class="sidebar-header">
      <div class="sidebar-avatar" id="myAvatarBtn">
        <div class="avatar" id="myAvatar">👤</div>
      </div>
      <div class="info">
        <h3 id="myName">...</h3>
        <p id="myStatus">آنلاین</p>
      </div>
      <button class="icon-btn" id="newChatBtn" title="چت جدید">✏️</button>
      <button class="icon-btn" id="themeBtn" title="تم">🌙</button>
      <button class="icon-btn" id="menuBtn" title="منو">⋮</button>
    </div>

    <!-- Tabs -->
    <div class="tabs" id="chatTabs">
      <button class="active" data-tab="all">همه</button>
      <button data-tab="unread">خوانده‌نشده <span class="tab-badge" id="unreadTabBadge" style="display:none">0</span></button>
      <button data-tab="online">آنلاین</button>
    </div>

    <!-- Search -->
    <div class="search-box">
      <input type="text" id="searchInput" placeholder="جستجو...">
    </div>

    <!-- Chat list -->
    <div class="chat-list" id="chatList">
      <div class="loading-state">
        <div class="spinner"></div>
        <p>در حال بارگذاری...</p>
      </div>
    </div>

    <!-- FAB -->
    <button class="fab" id="fab" title="چت جدید">✏️</button>
  </aside>

  <!-- ═══════════ CHAT AREA ═══════════ -->
  <main class="chat-area" id="chatArea">

    <!-- Empty state -->
    <div class="chat-empty" id="chatEmpty">
      <div class="empty-art">💬</div>
      <h2>به پیام‌رسان خوش آمدی</h2>
      <p>یک گفتگو از لیست انتخاب کن یا یک چت جدید شروع کن</p>
    </div>

    <!-- Active chat -->
    <div class="chat-active" id="chatActive" style="display:none">

      <!-- Header -->
      <div class="chat-header">
        <button class="icon-btn back-btn" id="backBtn">←</button>
        <div class="avatar" id="chatAvatar"></div>
        <div class="info" id="chatInfoBtn">
          <h3 id="chatName"></h3>
          <p id="chatStatus"></p>
        </div>
        <button class="icon-btn" id="callVoiceBtn" title="تماس صوتی">📞</button>
        <button class="icon-btn" id="callVideoBtn" title="تماس تصویری">📹</button>
        <button class="icon-btn" id="chatMenuBtn" title="منو">⋮</button>
      </div>

      <!-- Pinned banner -->
      <div class="pinned-banner" id="pinnedBanner" style="display:none">
        <div class="pin-bar"></div>
        <div class="pin-body" id="pinBody">
          <div class="pin-label">📌 پیام پین‌شده</div>
          <div class="pin-text" id="pinnedText"></div>
        </div>
        <button class="pin-close" id="pinClose">✕</button>
      </div>

      <!-- Search bar -->
      <div class="search-bar" id="searchBar" style="display:none">
        <button class="icon-btn-sm" id="searchClose">✕</button>
        <input type="text" id="searchInputChat" placeholder="جستجو در این گفتگو...">
        <span class="search-count" id="searchCount"></span>
        <button class="icon-btn-sm" id="searchPrev">↑</button>
        <button class="icon-btn-sm" id="searchNext">↓</button>
      </div>

      <!-- Messages -->
      <div class="messages-area" id="messagesArea">
        <div class="empty-chat">
          <div class="empty-art">✨</div>
          <p>اولین پیام را بفرست!</p>
        </div>
      </div>

      <!-- Scroll to bottom -->
      <button class="scroll-bottom" id="scrollBottom" style="display:none">↓</button>

      <!-- Typing -->
      <div class="typing-row" id="typingRow" style="display:none">
        <div class="typing-dots">
          <span></span><span></span><span></span>
        </div>
        <span id="typingText">در حال نوشتن...</span>
      </div>

      <!-- Reply preview -->
      <div class="reply-preview" id="replyPreview" style="display:none">
        <div class="preview-bar"></div>
        <div class="preview-body">
          <div class="preview-label">↩️ پاسخ به <span id="replyName"></span></div>
          <div class="preview-text" id="replyText"></div>
        </div>
        <button class="preview-close" id="replyClose">✕</button>
      </div>

      <!-- Edit preview -->
      <div class="reply-preview edit" id="editPreview" style="display:none">
        <div class="preview-bar"></div>
        <div class="preview-body">
          <div class="preview-label">✏️ ویرایش پیام</div>
          <div class="preview-text" id="editText"></div>
        </div>
        <button class="preview-close" id="editClose">✕</button>
      </div>

      <!-- Attachment preview -->
      <div class="attach-preview" id="attachPreview" style="display:none">
        <div class="attach-preview-body" id="attachPreviewBody"></div>
        <div class="attach-info" id="attachInfo"></div>
        <button class="preview-close" id="attachClose">✕</button>
      </div>

      <!-- Composer -->
      <div class="composer" id="composer">
        <button class="composer-btn" id="attachBtn" title="پیوست">📎</button>
        <div class="input-wrap">
          <textarea id="messageInput" placeholder="پیام..." rows="1"></textarea>
        </div>
        <button class="composer-btn" id="emojiBtn" title="ایموجی">😊</button>
        <button class="composer-btn voice" id="voiceBtn" title="ضبط صدا" style="display:none">🎤</button>
        <button class="send-btn" id="sendBtn" title="ارسال" disabled>
          <span class="send-icon">➤</span>
        </button>
      </div>

      <!-- Voice recording -->
      <div class="voice-recording" id="voiceRecording" style="display:none">
        <button class="voice-cancel" id="voiceCancel">✕</button>
        <div class="voice-wave">
          <span></span><span></span><span></span><span></span><span></span>
          <span></span><span></span><span></span><span></span><span></span>
        </div>
        <div class="voice-time" id="voiceTime">00:00</div>
        <button class="voice-send" id="voiceSend">➤</button>
      </div>

    </div>
  </main>
</div>

<!-- ═══════════ BOTTOM SHEET (Attachment) ═══════════ -->
<div class="sheet-bg" id="attachSheet" style="display:none">
  <div class="sheet">
    <div class="sheet-handle"></div>
    <div class="sheet-grid">
      <button data-type="gallery">
        <div class="sheet-icon" style="background: linear-gradient(135deg, #7B4FE0, #9E7AFF)">🖼️</div>
        <span>گالری</span>
      </button>
      <button data-type="camera">
        <div class="sheet-icon" style="background: linear-gradient(135deg, #FF6B6B, #FF8E8E)">📷</div>
        <span>دوربین</span>
      </button>
      <button data-type="file">
        <div class="sheet-icon" style="background: linear-gradient(135deg, #4ECDC4, #44A08D)">📄</div>
        <span>فایل</span>
      </button>
      <button data-type="video">
        <div class="sheet-icon" style="background: linear-gradient(135deg, #FFB84D, #FFA726)">🎥</div>
        <span>ویدیو</span>
      </button>
      <button data-type="location">
        <div class="sheet-icon" style="background: linear-gradient(135deg, #FF6B9D, #C44569)">📍</div>
        <span>موقعیت</span>
      </button>
      <button data-type="contact">
        <div class="sheet-icon" style="background: linear-gradient(135deg, #667EEA, #764BA2)">👤</div>
        <span>مخاطب</span>
      </button>
    </div>
  </div>
</div>

<!-- ═══════════ EMOJI PICKER ═══════════ -->
<div class="emoji-picker" id="emojiPicker" style="display:none">
  <div class="emoji-tabs" id="emojiTabs"></div>
  <div class="emoji-grid" id="emojiGrid"></div>
</div>

<!-- ═══════════ CONTEXT MENU ═══════════ -->
<div class="context-menu" id="contextMenu" style="display:none"></div>

<!-- ═══════════ PROFILE MODAL ═══════════ -->
<div class="modal-bg" id="profileModal" style="display:none">
  <div class="modal">
    <div class="modal-head">
      <h3>پروفایل من</h3>
      <button id="profileClose">✕</button>
    </div>
    <div class="modal-body">
      <div class="profile-avatar-wrap">
        <div class="avatar-preview" id="avatarPreview">👤</div>
        <label class="btn-upload">
          <input type="file" id="avatarInput" accept="image/*">
          📷 تغییر عکس
        </label>
      </div>
      <div class="form-group">
        <label>نام نمایشی</label>
        <input type="text" id="profileDisplayName" placeholder="نام شما">
      </div>
      <div class="form-group">
        <label>نام کاربری</label>
        <input type="text" id="profileUsername" disabled>
      </div>
      <button class="btn-primary" id="profileSave">ذخیره تغییرات</button>
    </div>
  </div>
</div>

<!-- ═══════════ LIGHTBOX ═══════════ -->
<div class="lightbox" id="lightbox">
  <button class="lightbox-close" id="lightboxClose">✕</button>
  <img id="lightboxImg" src="" alt="">
</div>

<!-- ═══════════ TOAST ═══════════ -->
<div class="toast" id="toast"></div>

<!-- Hidden file inputs -->
<input type="file" id="fileInput" accept="image/*,video/*,.pdf,.doc,.docx,.zip,.rar,.txt,.mp3,.mp4" style="display:none">
<input type="file" id="galleryInput" accept="image/*,video/*" style="display:none" multiple>
<input type="file" id="cameraInput" accept="image/*" capture="environment" style="display:none">

<script type="module" src="./js/chat.js"></script>
<script>
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch(() => {});
  });
}
</script>
</body>
</html>
HTML_EOF

echo "✅ chat.html ساخته شد"

# ═══════════════════════════════════════════════════════
# ۲) style.css — تم کامل روبیکا
# ═══════════════════════════════════════════════════════
cat > css/style.css << 'CSS_EOF'
/* ═══════════════════════════════════════════════════════
   🎨 پیام‌رسان — تم روبیکا
   ═══════════════════════════════════════════════════════ */

* { box-sizing: border-box; margin: 0; padding: 0; }

:root {
  --primary: #7B4FE0;
  --primary-dark: #6438C7;
  --primary-light: #9E7AFF;
  --accent: #00D4A8;
  --gradient: linear-gradient(135deg, #7B4FE0, #9E7AFF);
  --gradient-msg: linear-gradient(135deg, #7B4FE0, #8B5FEF);

  --bg: #F0F2F5;
  --bg-chat: #EDE4D8;
  --bg-chat-dark: #0B141A;
  --card: #FFFFFF;
  --card-hover: #F7F8FA;
  --text: #1F2C3D;
  --text-secondary: #6E7B91;
  --muted: #9BA5B7;
  --border: #E8EAEF;
  --success: #00D4A8;
  --danger: #F44336;
  --warning: #FF9800;
  --online: #00D4A8;

  --shadow-sm: 0 1px 3px rgba(31, 44, 61, 0.06);
  --shadow: 0 4px 12px rgba(31, 44, 61, 0.08);
  --shadow-lg: 0 10px 30px rgba(31, 44, 61, 0.15);
}

body.dark {
  --bg: #0F1419;
  --bg-chat: #0B141A;
  --card: #17212B;
  --card-hover: #1E2A35;
  --text: #F1F5F9;
  --text-secondary: #94A3B8;
  --muted: #64748B;
  --border: #232E3C;
}

html, body {
  height: 100%;
  overflow: hidden;
}

body {
  font-family: Vazirmatn, "Vazir", Tahoma, system-ui, sans-serif;
  background: var(--bg);
  color: var(--text);
  direction: rtl;
  line-height: 1.5;
  -webkit-font-smoothing: antialiased;
}

/* ═══════════════ LAYOUT ═══════════════ */
.chat-app {
  height: 100vh;
  display: grid;
  grid-template-columns: 380px 1fr;
  overflow: hidden;
}

/* ═══════════════ SIDEBAR ═══════════════ */
.sidebar {
  background: var(--card);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  border-left: 1px solid var(--border);
  position: relative;
}

.sidebar-header {
  padding: 12px 16px;
  display: flex;
  align-items: center;
  gap: 10px;
  border-bottom: 1px solid var(--border);
  flex-shrink: 0;
}

.sidebar-avatar {
  width: 42px;
  height: 42px;
  cursor: pointer;
  border-radius: 50%;
  transition: transform .2s;
}
.sidebar-avatar:hover { transform: scale(1.05); }

.sidebar-header .avatar {
  width: 42px;
  height: 42px;
  border-radius: 50%;
  background: var(--gradient);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
  font-weight: 700;
  overflow: hidden;
}
.sidebar-header .avatar img {
  width: 100%; height: 100%; object-fit: cover;
}

.sidebar-header .info { flex: 1; min-width: 0; }
.sidebar-header .info h3 {
  font-size: 15px; font-weight: 700;
  color: var(--text);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.sidebar-header .info p {
  font-size: 11.5px; color: var(--online); margin-top: 1px;
}

.icon-btn {
  width: 38px; height: 38px;
  border-radius: 50%;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 17px;
  transition: all .15s;
  flex-shrink: 0;
}
.icon-btn:hover { background: var(--bg); color: var(--primary); }
.icon-btn:active { transform: scale(.92); }

/* ─── Tabs ─── */
.tabs {
  display: flex;
  padding: 0;
  border-bottom: 1px solid var(--border);
  flex-shrink: 0;
}

.tabs button {
  flex: 1;
  padding: 13px 8px;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  font-family: inherit;
  font-size: 13.5px;
  font-weight: 600;
  cursor: pointer;
  position: relative;
  transition: color .2s;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
}
.tabs button.active { color: var(--primary); font-weight: 700; }
.tabs button.active::after {
  content: "";
  position: absolute;
  bottom: 0;
  left: 15%;
  right: 15%;
  height: 3px;
  background: var(--gradient);
  border-radius: 3px 3px 0 0;
}

.tab-badge {
  background: var(--danger);
  color: #fff;
  font-size: 10px;
  font-weight: 800;
  padding: 2px 6px;
  border-radius: 9px;
  line-height: 1.2;
  min-width: 18px;
  text-align: center;
}

/* ─── Search ─── */
.search-box {
  padding: 8px 12px;
  flex-shrink: 0;
}
.search-box input {
  width: 100%;
  padding: 10px 38px 10px 14px;
  border: none;
  border-radius: 12px;
  background: var(--bg);
  color: var(--text);
  font-family: inherit;
  font-size: 13.5px;
  outline: none;
  background-image: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='%239BA5B7' stroke-width='2.5' stroke-linecap='round'><circle cx='11' cy='11' r='7'/><path d='M21 21l-4-4'/></svg>");
  background-repeat: no-repeat;
  background-position: right 12px center;
  transition: all .15s;
}
.search-box input:focus {
  background-color: var(--card-hover);
  box-shadow: 0 0 0 3px rgba(123, 79, 224, 0.1);
}

/* ─── Chat list ─── */
.chat-list {
  flex: 1;
  overflow-y: auto;
  padding: 4px 0 80px;
}

.chat-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 16px;
  cursor: pointer;
  transition: background .15s;
  position: relative;
  user-select: none;
}
.chat-item:hover { background: var(--card-hover); }
.chat-item.active { background: rgba(123, 79, 224, 0.08); }
.chat-item.active::before {
  content: "";
  position: absolute;
  right: 0;
  top: 12%;
  bottom: 12%;
  width: 3px;
  background: var(--gradient);
  border-radius: 3px 0 0 3px;
}

.chat-item .avatar {
  width: 54px; height: 54px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-weight: 700;
  font-size: 18px;
  flex-shrink: 0;
  position: relative;
  overflow: visible;
}
.chat-item .avatar .avatar-img {
  width: 100%; height: 100%;
  border-radius: 50%;
  object-fit: cover;
  overflow: hidden;
}

.chat-item .avatar .online-dot {
  position: absolute;
  bottom: 1px;
  left: 1px;
  width: 14px;
  height: 14px;
  background: var(--online);
  border: 2.5px solid var(--card);
  border-radius: 50%;
}

.chat-item .avatar .unread-badge {
  position: absolute;
  top: -2px;
  right: -4px;
  background: var(--gradient);
  color: #fff;
  font-size: 11px;
  font-weight: 800;
  min-width: 20px;
  height: 20px;
  padding: 0 6px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 2px solid var(--card);
  box-shadow: 0 2px 6px rgba(123, 79, 224, 0.4);
  z-index: 2;
}

.chat-item .body {
  flex: 1;
  min-width: 0;
  padding-bottom: 2px;
}

.chat-item .row1 {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 6px;
  margin-bottom: 3px;
}

.chat-item .row1 .name {
  font-size: 14.5px;
  font-weight: 700;
  color: var(--text);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  flex: 1;
}

.chat-item .row1 .meta {
  display: flex;
  align-items: center;
  gap: 4px;
  flex-shrink: 0;
  font-size: 11.5px;
  color: var(--text-secondary);
}

.chat-item .row1 .pin-icon,
.chat-item .row1 .mute-icon {
  font-size: 12px;
}

.chat-item .row2 {
  display: flex;
  align-items: center;
  gap: 5px;
}

.chat-item .row2 .preview {
  font-size: 13px;
  color: var(--text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  flex: 1;
}
.chat-item .row2 .preview.unread {
  color: var(--text);
  font-weight: 600;
}
.chat-item .row2 .preview .tick {
  margin-left: 4px;
  font-size: 12px;
  color: var(--primary);
}
.chat-item .row2 .preview .tick.read { color: var(--accent); }

.chat-item.pinned .row1 .pin-icon { display: inline; }
.chat-item:not(.pinned) .row1 .pin-icon { display: none; }

/* FAB */
.fab {
  position: absolute;
  bottom: 20px;
  left: 20px;
  width: 56px;
  height: 56px;
  border-radius: 18px;
  border: none;
  background: var(--gradient);
  color: #fff;
  font-size: 24px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 10px 24px -6px rgba(123, 79, 224, 0.5);
  transition: all .2s cubic-bezier(.34,1.56,.64,1);
  z-index: 50;
}
.fab:hover { transform: translateY(-2px) scale(1.05); }
.fab:active { transform: scale(.92); }

/* Loading */
.loading-state {
  padding: 60px 20px;
  text-align: center;
  color: var(--text-secondary);
  font-size: 13px;
}
.spinner {
  width: 32px; height: 32px;
  border: 3px solid var(--border);
  border-top-color: var(--primary);
  border-radius: 50%;
  animation: spin .8s linear infinite;
  margin: 0 auto 12px;
}
@keyframes spin { to { transform: rotate(360deg); } }

.empty-list {
  padding: 60px 20px;
  text-align: center;
  color: var(--text-secondary);
  font-size: 13.5px;
  line-height: 1.8;
}
.empty-list .emoji {
  font-size: 56px;
  display: block;
  margin-bottom: 12px;
  opacity: .35;
}

/* ═══════════════ CHAT AREA ═══════════════ */
.chat-area {
  background: var(--bg-chat);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  position: relative;
}

body.dark .chat-area { background: var(--bg-chat-dark); }

.chat-empty {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 40px;
  color: var(--text-secondary);
}
.chat-empty .empty-art {
  width: 120px;
  height: 120px;
  border-radius: 36px;
  background: var(--gradient);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 60px;
  margin-bottom: 24px;
  box-shadow: 0 20px 50px -12px rgba(123, 79, 224, 0.5);
}
.chat-empty h2 {
  font-size: 20px;
  color: var(--text);
  margin-bottom: 8px;
  font-weight: 700;
}
.chat-empty p { font-size: 14px; max-width: 300px; line-height: 1.7; }

.chat-active {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

/* ─── Chat header ─── */
.chat-header {
  padding: 10px 16px;
  background: var(--card);
  display: flex;
  align-items: center;
  gap: 10px;
  box-shadow: var(--shadow-sm);
  z-index: 10;
  flex-shrink: 0;
  min-height: 62px;
}

.chat-header .avatar {
  width: 42px; height: 42px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-weight: 700;
  font-size: 16px;
  overflow: hidden;
}
.chat-header .avatar img {
  width: 100%; height: 100%; object-fit: cover;
}

.chat-header .info {
  flex: 1;
  min-width: 0;
  cursor: pointer;
}
.chat-header .info h3 {
  font-size: 15px;
  font-weight: 700;
  color: var(--text);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.chat-header .info p {
  font-size: 12px;
  color: var(--text-secondary);
  margin-top: 1px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.chat-header .info p.online { color: var(--online); }
.chat-header .info p.typing { color: var(--primary); font-style: italic; }

.back-btn { display: none; }

/* ─── Pinned banner ─── */
.pinned-banner {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px 16px;
  background: var(--card);
  border-bottom: 1px solid var(--border);
  flex-shrink: 0;
}
.pin-bar {
  width: 3px;
  height: 32px;
  background: var(--gradient);
  border-radius: 3px;
  flex-shrink: 0;
}
.pin-body { flex: 1; min-width: 0; cursor: pointer; }
.pin-label { font-size: 11px; color: var(--primary); font-weight: 700; }
.pin-text {
  font-size: 12.5px;
  color: var(--text);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  margin-top: 1px;
}
.pin-close {
  width: 30px; height: 30px;
  border-radius: 50%;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  cursor: pointer;
  font-size: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.pin-close:hover { background: var(--bg); color: var(--danger); }

/* ─── Search bar ─── */
.search-bar {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  background: var(--card);
  border-bottom: 1px solid var(--border);
  flex-shrink: 0;
}
.search-bar input {
  flex: 1;
  padding: 8px 12px;
  border: none;
  border-radius: 10px;
  background: var(--bg);
  color: var(--text);
  font-family: inherit;
  font-size: 13.5px;
  outline: none;
}
.search-count { font-size: 12px; color: var(--text-secondary); }
.icon-btn-sm {
  width: 32px; height: 32px;
  border-radius: 50%;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  cursor: pointer;
  font-size: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.icon-btn-sm:hover { background: var(--bg); color: var(--primary); }

/* ─── Messages ─── */
.messages-area {
  flex: 1;
  overflow-y: auto;
  padding: 16px 5% 8px;
  display: flex;
  flex-direction: column;
  gap: 3px;
  position: relative;
  scroll-behavior: smooth;
}

.empty-chat {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: var(--text-secondary);
  gap: 12px;
}
.empty-chat .empty-art {
  width: 90px;
  height: 90px;
  border-radius: 50%;
  background: var(--gradient);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 40px;
  opacity: .9;
}
.empty-chat p { font-size: 14px; }

/* Date separator */
.date-separator {
  display: flex;
  justify-content: center;
  margin: 14px 0 8px;
}
.date-separator span {
  padding: 5px 14px;
  background: rgba(123, 79, 224, 0.12);
  color: var(--primary);
  font-size: 11.5px;
  font-weight: 700;
  border-radius: 12px;
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
}
body.dark .date-separator span {
  background: rgba(123, 79, 224, 0.25);
  color: var(--primary-light);
}

/* ═══════════════ MESSAGE BUBBLES ═══════════════ */
.message {
  display: flex;
  gap: 8px;
  max-width: 68%;
  position: relative;
  animation: msgIn .22s cubic-bezier(.34,1.56,.64,1);
  margin-bottom: 2px;
}
.message.first-in-group { margin-top: 10px; }
.message.last-in-group { margin-bottom: 2px; }

@keyframes msgIn {
  from { opacity: 0; transform: translateY(4px) scale(.97); }
  to { opacity: 1; transform: translateY(0) scale(1); }
}

.message.mine { align-self: flex-start; flex-direction: row-reverse; }
.message.theirs { align-self: flex-end; }

.message .bubble {
  padding: 8px 12px 6px;
  border-radius: 16px;
  font-size: 14.5px;
  line-height: 1.45;
  word-wrap: break-word;
  white-space: pre-wrap;
  position: relative;
  min-width: 80px;
  box-shadow: var(--shadow-sm);
  cursor: default;
  transition: transform .15s;
}
.message .bubble:active { transform: scale(.98); }

.message.mine .bubble {
  background: var(--gradient-msg);
  color: #fff;
  border-bottom-right-radius: 5px;
}
.message.theirs .bubble {
  background: var(--card);
  color: var(--text);
  border-bottom-left-radius: 5px;
}
body.dark .message.theirs .bubble {
  background: #1E2A35;
  color: var(--text);
}

.message .bubble .meta {
  font-size: 10.5px;
  opacity: .75;
  margin-top: 4px;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  float: left;
}
.message.mine .bubble .meta { color: rgba(255,255,255,.85); }
.message .bubble .meta .tick { font-size: 12px; line-height: 1; }
.message .bubble .meta .tick.delivered { opacity: .7; }
.message .bubble .meta .tick.read { color: #4FC3F7; opacity: 1; }

/* Reply quote */
.reply-quote {
  padding: 5px 9px;
  margin-bottom: 5px;
  border-radius: 8px;
  background: rgba(0, 0, 0, 0.08);
  border-right: 3px solid currentColor;
  cursor: pointer;
  overflow: hidden;
}
.message.mine .reply-quote { background: rgba(255, 255, 255, 0.15); }
.rq-name { font-size: 11px; font-weight: 700; margin-bottom: 1px; opacity: .95; }
.rq-text {
  font-size: 12px;
  opacity: .85;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* Forwarded badge */
.forwarded-badge {
  font-size: 11px;
  opacity: .8;
  margin-bottom: 4px;
  font-style: italic;
}

/* Edited mark */
.edited-mark { font-size: 10px; opacity: .75; }

/* Attachments */
.attach-image {
  max-width: 260px;
  margin: -4px -6px 4px;
  border-radius: 12px;
  overflow: hidden;
  cursor: pointer;
}
.attach-image img {
  display: block;
  width: 100%;
  height: auto;
  max-height: 340px;
  object-fit: cover;
}
.attach-video {
  max-width: 300px;
  margin: -4px -6px 4px;
  border-radius: 12px;
  overflow: hidden;
}
.attach-video video {
  display: block;
  width: 100%;
  max-height: 340px;
  background: #000;
}
.attach-file {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 10px;
  background: rgba(0, 0, 0, 0.08);
  border-radius: 10px;
  margin-bottom: 5px;
  text-decoration: none;
  color: inherit;
  min-width: 200px;
  max-width: 280px;
}
.message.mine .attach-file { background: rgba(255, 255, 255, 0.2); color: #fff; }
.attach-file-icon {
  width: 40px; height: 40px;
  border-radius: 10px;
  background: rgba(255,255,255,.2);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  flex-shrink: 0;
}
.message.theirs .attach-file-icon { background: rgba(123,79,224,.12); }
.attach-file-info { min-width: 0; flex: 1; }
.attach-file-info .name {
  font-size: 13px; font-weight: 700;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.attach-file-info .size { font-size: 11px; opacity: .75; margin-top: 2px; }

/* Voice message */
.attach-voice {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 6px 8px;
  min-width: 180px;
}
.voice-play {
  width: 36px; height: 36px;
  border-radius: 50%;
  background: rgba(255,255,255,.25);
  border: none;
  color: inherit;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  flex-shrink: 0;
}
.message.theirs .voice-play { background: rgba(123,79,224,.15); }
.voice-wave-mini {
  flex: 1;
  height: 20px;
  display: flex;
  align-items: center;
  gap: 2px;
}
.voice-wave-mini span {
  flex: 1;
  background: currentColor;
  opacity: .4;
  border-radius: 2px;
  height: 40%;
}
.voice-wave-mini span:nth-child(odd) { height: 70%; }
.voice-wave-mini span:nth-child(3n) { height: 100%; }
.voice-dur { font-size: 11.5px; opacity: .8; }

/* Reactions */
.reactions-row {
  position: absolute;
  bottom: -12px;
  display: flex;
  gap: 3px;
  background: var(--card);
  border-radius: 20px;
  padding: 2px 6px;
  box-shadow: var(--shadow-sm);
  z-index: 3;
}
.message.mine .reactions-row { right: 40px; }
.message.theirs .reactions-row { left: 40px; }
.reaction-chip {
  border: none;
  background: transparent;
  cursor: pointer;
  font-size: 13px;
  padding: 1px 3px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  gap: 3px;
}
.reaction-chip.mine { background: rgba(123,79,224,.15); }
.reaction-chip span { font-size: 10.5px; color: var(--text-secondary); font-weight: 700; }

/* Highlight */
.message.highlight .bubble { animation: flash 1.5s ease; }
@keyframes flash {
  0%, 100% { box-shadow: var(--shadow-sm); }
  50% { box-shadow: 0 0 0 3px var(--warning), 0 0 20px rgba(255,152,0,.5); }
}

/* ═══════════════ COMPOSER ═══════════════ */
.composer {
  display: flex;
  align-items: flex-end;
  gap: 6px;
  padding: 8px 12px;
  background: var(--card);
  flex-shrink: 0;
  box-shadow: 0 -1px 4px rgba(0,0,0,.04);
}

.composer-btn {
  width: 44px; height: 44px;
  border-radius: 50%;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  cursor: pointer;
  font-size: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all .15s;
  flex-shrink: 0;
}
.composer-btn:hover { background: var(--bg); color: var(--primary); }
.composer-btn:active { transform: scale(.92); }

.input-wrap {
  flex: 1;
  background: var(--bg);
  border-radius: 22px;
  padding: 2px;
  transition: box-shadow .15s;
}
.input-wrap:focus-within {
  box-shadow: 0 0 0 3px rgba(123,79,224,.12);
}
.input-wrap textarea {
  width: 100%;
  padding: 11px 16px;
  border: none;
  border-radius: 22px;
  background: transparent;
  color: var(--text);
  font-family: inherit;
  font-size: 14.5px;
  outline: none;
  resize: none;
  max-height: 120px;
  min-height: 40px;
  line-height: 1.4;
  display: block;
}

.send-btn {
  width: 44px; height: 44px;
  border-radius: 50%;
  border: none;
  background: var(--gradient);
  color: #fff;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all .2s cubic-bezier(.34,1.56,.64,1);
  flex-shrink: 0;
  box-shadow: 0 4px 12px -4px rgba(123,79,224,.5);
}
.send-btn:disabled {
  opacity: 0;
  transform: scale(.6);
  pointer-events: none;
}
.send-btn:not(:disabled):hover { transform: scale(1.05); }
.send-btn:not(:disabled):active { transform: scale(.92); }
.send-icon {
  font-size: 18px;
  transform: rotate(-45deg);
  margin-right: -2px;
}

/* ═══════════════ TYPING ═══════════════ */
.typing-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 4px 20px 6px;
  font-size: 12.5px;
  color: var(--primary);
  font-style: italic;
}
.typing-dots {
  display: flex;
  gap: 3px;
}
.typing-dots span {
  width: 6px; height: 6px;
  border-radius: 50%;
  background: var(--primary);
  animation: bounce 1.4s infinite;
}
.typing-dots span:nth-child(2) { animation-delay: .2s; }
.typing-dots span:nth-child(3) { animation-delay: .4s; }
@keyframes bounce {
  0%, 60%, 100% { transform: translateY(0); opacity: .5; }
  30% { transform: translateY(-4px); opacity: 1; }
}

/* ═══════════════ SCROLL BOTTOM ═══════════════ */
.scroll-bottom {
  position: absolute;
  bottom: 90px;
  left: 20px;
  width: 44px; height: 44px;
  border-radius: 50%;
  border: none;
  background: var(--card);
  color: var(--primary);
  font-size: 20px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: var(--shadow);
  z-index: 15;
  animation: popIn .2s ease;
}
@keyframes popIn {
  from { opacity: 0; transform: scale(.5); }
  to { opacity: 1; transform: scale(1); }
}

/* ═══════════════ PREVIEW BARS ═══════════════ */
.reply-preview {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 14px;
  background: var(--card);
  border-top: 1px solid var(--border);
  flex-shrink: 0;
}
.preview-bar {
  width: 3px;
  height: 36px;
  background: var(--primary);
  border-radius: 3px;
  flex-shrink: 0;
}
.reply-preview.edit .preview-bar { background: var(--warning); }
.preview-body { flex: 1; min-width: 0; }
.preview-label { font-size: 11.5px; color: var(--primary); font-weight: 700; }
.reply-preview.edit .preview-label { color: var(--warning); }
.preview-text {
  font-size: 13px;
  color: var(--text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  margin-top: 2px;
}
.preview-close {
  width: 32px; height: 32px;
  border-radius: 50%;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  cursor: pointer;
  font-size: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.preview-close:hover { background: var(--bg); color: var(--danger); }

/* Attach preview */
.attach-preview {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 14px;
  background: var(--card);
  border-top: 1px solid var(--border);
  flex-shrink: 0;
}
.attach-preview-body {
  width: 60px; height: 60px;
  border-radius: 10px;
  background: var(--bg);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 28px;
  overflow: hidden;
  flex-shrink: 0;
}
.attach-preview-body img {
  width: 100%; height: 100%; object-fit: cover;
}
.attach-info {
  flex: 1;
  font-size: 13px;
  color: var(--text);
  font-weight: 600;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* ═══════════════ VOICE RECORDING ═══════════════ */
.voice-recording {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px 14px;
  background: var(--card);
  flex-shrink: 0;
  box-shadow: 0 -1px 4px rgba(0,0,0,.04);
}
.voice-cancel {
  width: 40px; height: 40px;
  border-radius: 50%;
  border: none;
  background: rgba(244,67,54,.12);
  color: var(--danger);
  cursor: pointer;
  font-size: 16px;
}
.voice-wave {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 3px;
  height: 30px;
}
.voice-wave span {
  width: 4px;
  background: var(--primary);
  border-radius: 3px;
  height: 30%;
  animation: wave 1s infinite ease-in-out;
}
.voice-wave span:nth-child(1) { animation-delay: 0s; }
.voice-wave span:nth-child(2) { animation-delay: .1s; }
.voice-wave span:nth-child(3) { animation-delay: .2s; }
.voice-wave span:nth-child(4) { animation-delay: .3s; }
.voice-wave span:nth-child(5) { animation-delay: .4s; }
.voice-wave span:nth-child(6) { animation-delay: .3s; }
.voice-wave span:nth-child(7) { animation-delay: .2s; }
.voice-wave span:nth-child(8) { animation-delay: .1s; }
.voice-wave span:nth-child(9) { animation-delay: .15s; }
.voice-wave span:nth-child(10) { animation-delay: .35s; }
@keyframes wave {
  0%, 100% { height: 30%; }
  50% { height: 100%; }
}
.voice-time {
  font-size: 14px;
  font-weight: 700;
  color: var(--danger);
  font-variant-numeric: tabular-nums;
  min-width: 48px;
  text-align: center;
}
.voice-send {
  width: 44px; height: 44px;
  border-radius: 50%;
  border: none;
  background: var(--gradient);
  color: #fff;
  font-size: 18px;
  cursor: pointer;
  transform: rotate(-45deg);
}

/* ═══════════════ BOTTOM SHEET ═══════════════ */
.sheet-bg {
  position: fixed;
  inset: 0;
  background: rgba(15, 20, 25, 0.5);
  backdrop-filter: blur(4px);
  -webkit-backdrop-filter: blur(4px);
  z-index: 500;
  display: flex;
  align-items: flex-end;
  animation: fadeIn .2s ease;
}
@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }

.sheet {
  width: 100%;
  background: var(--card);
  border-radius: 24px 24px 0 0;
  padding: 8px 0 calc(20px + env(safe-area-inset-bottom));
  animation: slideUp .28s cubic-bezier(.34,1.56,.64,1);
  max-width: 500px;
  margin: 0 auto;
}
@keyframes slideUp {
  from { transform: translateY(100%); }
  to { transform: translateY(0); }
}
.sheet-handle {
  width: 40px;
  height: 4px;
  background: var(--border);
  border-radius: 3px;
  margin: 8px auto 16px;
}
.sheet-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
  padding: 0 16px;
}
.sheet-grid button {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 14px 8px;
  border: none;
  background: transparent;
  color: var(--text);
  font-family: inherit;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  border-radius: 14px;
  transition: background .15s;
}
.sheet-grid button:hover { background: var(--bg); }
.sheet-grid button:active { transform: scale(.95); }
.sheet-icon {
  width: 54px;
  height: 54px;
  border-radius: 18px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 26px;
  color: #fff;
  box-shadow: 0 6px 16px -4px rgba(31,44,61,.3);
}

/* ═══════════════ EMOJI PICKER ═══════════════ */
.emoji-picker {
  position: absolute;
  bottom: 70px;
  right: 12px;
  width: 340px;
  max-width: calc(100vw - 24px);
  background: var(--card);
  border-radius: 18px;
  box-shadow: var(--shadow-lg);
  z-index: 100;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  max-height: 360px;
  animation: popIn .2s ease;
}
.emoji-tabs {
  display: flex;
  overflow-x: auto;
  padding: 6px 8px;
  border-bottom: 1px solid var(--border);
  gap: 4px;
}
.emoji-tabs button {
  padding: 6px 10px;
  border: none;
  background: transparent;
  font-size: 18px;
  cursor: pointer;
  border-radius: 8px;
  flex-shrink: 0;
}
.emoji-tabs button.active { background: rgba(123,79,224,.12); }
.emoji-grid {
  display: grid;
  grid-template-columns: repeat(8, 1fr);
  gap: 2px;
  padding: 10px;
  overflow-y: auto;
  flex: 1;
}
.emoji-grid button {
  padding: 4px;
  border: none;
  background: transparent;
  font-size: 22px;
  cursor: pointer;
  border-radius: 8px;
  transition: background .1s;
}
.emoji-grid button:hover { background: var(--bg); }

/* ═══════════════ CONTEXT MENU ═══════════════ */
.context-menu {
  position: fixed;
  background: var(--card);
  border-radius: 14px;
  box-shadow: var(--shadow-lg);
  z-index: 999;
  overflow: hidden;
  min-width: 180px;
  animation: popIn .15s ease;
}
.context-menu button {
  display: flex;
  align-items: center;
  gap: 12px;
  width: 100%;
  padding: 12px 16px;
  border: none;
  background: transparent;
  color: var(--text);
  font-family: inherit;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  text-align: right;
  transition: background .12s;
}
.context-menu button:hover { background: var(--bg); }
.context-menu button.danger { color: var(--danger); }
.context-menu button .emoji { font-size: 16px; }

/* ═══════════════ MODAL ═══════════════ */
.modal-bg {
  position: fixed;
  inset: 0;
  background: rgba(15,20,25,.6);
  backdrop-filter: blur(6px);
  -webkit-backdrop-filter: blur(6px);
  z-index: 800;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
  animation: fadeIn .2s ease;
}
.modal {
  background: var(--card);
  border-radius: 22px;
  width: 100%;
  max-width: 420px;
  max-height: 88vh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  box-shadow: var(--shadow-lg);
  animation: popIn .25s cubic-bezier(.34,1.56,.64,1);
}
.modal-head {
  padding: 16px 20px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid var(--border);
}
.modal-head h3 { font-size: 16px; font-weight: 700; }
.modal-head button {
  width: 34px; height: 34px;
  border-radius: 50%;
  border: none;
  background: var(--bg);
  color: var(--text-secondary);
  cursor: pointer;
  font-size: 15px;
}
.modal-head button:hover { background: var(--danger); color: #fff; }
.modal-body { padding: 20px; overflow-y: auto; }

.profile-avatar-wrap {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
  margin-bottom: 24px;
}
.avatar-preview {
  width: 110px; height: 110px;
  border-radius: 50%;
  background: var(--gradient);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 44px;
  overflow: hidden;
  border: 4px solid var(--card);
  box-shadow: 0 8px 24px -6px rgba(123,79,224,.4);
}
.avatar-preview img {
  width: 100%; height: 100%; object-fit: cover;
}
.btn-upload {
  padding: 9px 20px;
  border-radius: 12px;
  background: var(--bg);
  color: var(--text);
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  transition: all .15s;
}
.btn-upload:hover { background: rgba(123,79,224,.12); color: var(--primary); }
.btn-upload input { display: none; }

.form-group { margin-bottom: 14px; }
.form-group label {
  display: block;
  font-size: 12.5px;
  font-weight: 700;
  margin-bottom: 6px;
  color: var(--text);
}
.form-group input {
  width: 100%;
  padding: 12px 14px;
  border: 1.5px solid var(--border);
  border-radius: 12px;
  background: var(--bg);
  color: var(--text);
  font-family: inherit;
  font-size: 14px;
  outline: none;
}
.form-group input:focus {
  border-color: var(--primary);
  background: var(--card);
  box-shadow: 0 0 0 3px rgba(123,79,224,.12);
}
.form-group input:disabled { opacity: .6; }

.btn-primary {
  width: 100%;
  padding: 14px;
  border: none;
  border-radius: 14px;
  background: var(--gradient);
  color: #fff;
  font-family: inherit;
  font-size: 15px;
  font-weight: 700;
  cursor: pointer;
  margin-top: 8px;
  box-shadow: 0 8px 20px -6px rgba(123,79,224,.5);
  transition: all .2s;
}
.btn-primary:hover { transform: translateY(-1px); }

/* ═══════════════ LIGHTBOX ═══════════════ */
.lightbox {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,.95);
  display: none;
  align-items: center;
  justify-content: center;
  z-index: 9999;
  padding: 30px;
}
.lightbox.show { display: flex; animation: fadeIn .2s; }
.lightbox img {
  max-width: 95%;
  max-height: 95%;
  border-radius: 12px;
  box-shadow: 0 20px 60px rgba(0,0,0,.5);
}
.lightbox-close {
  position: absolute;
  top: 20px; right: 20px;
  width: 46px; height: 46px;
  border-radius: 50%;
  border: none;
  background: rgba(255,255,255,.15);
  color: #fff;
  font-size: 20px;
  cursor: pointer;
}
.lightbox-close:hover { background: rgba(255,255,255,.3); }

/* ═══════════════ TOAST ═══════════════ */
.toast {
  position: fixed;
  bottom: 30px;
  left: 50%;
  transform: translateX(-50%) translateY(100px);
  background: var(--text);
  color: var(--card);
  padding: 12px 22px;
  border-radius: 14px;
  font-size: 13.5px;
  font-weight: 700;
  box-shadow: var(--shadow-lg);
  z-index: 99999;
  opacity: 0;
  transition: all .3s cubic-bezier(.34,1.56,.64,1);
  pointer-events: none;
  max-width: 90vw;
}
.toast.show { transform: translateX(-50%) translateY(0); opacity: 1; }
.toast.success { background: var(--gradient); color: #fff; }
.toast.error { background: var(--danger); color: #fff; }

/* ═══════════════ MOBILE ═══════════════ */
@media (max-width: 768px) {
  .chat-app { grid-template-columns: 1fr; }

  .sidebar {
    position: absolute;
    inset: 0;
    z-index: 100;
    transition: transform .3s cubic-bezier(.4,0,.2,1);
    border-left: none;
  }
  .sidebar.hidden { transform: translateX(-100%); }

  .message { max-width: 82%; }
  .messages-area { padding: 12px 10px 6px; }
  .back-btn { display: flex; }

  .emoji-picker {
    right: 8px;
    left: 8px;
    width: auto;
  }

  .fab { bottom: 16px; left: 16px; }
}

/* ═══════════════ SCROLLBAR ═══════════════ */
::-webkit-scrollbar { width: 6px; height: 6px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb {
  background: rgba(155,165,183,.4);
  border-radius: 10px;
}
::-webkit-scrollbar-thumb:hover { background: rgba(155,165,183,.6); }
CSS_EOF

echo "✅ style.css ساخته شد"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "✅ مرحله ۱ آماده است"
echo "═══════════════════════════════════════════════════════"
echo "حالا مرحله ۲: فایل chat.js"
