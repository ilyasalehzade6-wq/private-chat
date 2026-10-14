// js/chat.js
import { supabase } from './supabase-client.js';
import { requireAuth, signOut, getProfile } from './auth.js';
import { showToast, formatTime, escapeHtml, getInitials, avatarColor } from './ui.js';
import { compressFile, formatSize as fmtSize } from './compressor.js';

let currentUser = null;
let currentProfile = null;
let allUsers = [];
let currentConversation = null;
let currentOtherUser = null;
let messagesChannel = null;
let reactionsChannel = null;
let typingChannel = null;
let typingTimer = null;
let pendingAttachment = null;
let replyTo = null;
let editingId = null;
let allMessages = [];
let reactionsMap = {};
let pinnedMsg = null;
let unreadCounts = {};       // { userId: count }
let lastNotifications = {};  // جلوگیری از spam
let notificationGranted = false;
let audioCtx = null;

const $ = (id) => document.getElementById(id);
const BUCKET = 'chat-attachments';
const EMOJIS = ['❤️', '😂', '👍', '😮', '😢', '🔥'];

// ═══════════════════════════════════════════
// INIT
// ═══════════════════════════════════════════
async function init() {
  currentUser = await requireAuth();
  if (!currentUser) return;

  const { data: profile } = await getProfile(currentUser.id);
  currentProfile = profile;
  $('myName').textContent = profile?.display_name || profile?.username || 'من';

  await supabase.from('profiles').update({ is_online: true }).eq('id', currentUser.id);
  window.addEventListener('beforeunload', () => {
    supabase.from('profiles').update({ is_online: false }).eq('id', currentUser.id);
  });

  await loadUsers();
  await loadUnreadCounts();
  subscribeProfiles();

  $('searchInput').addEventListener('input', (e) => renderUsers(e.target.value));

  $('logoutBtn').onclick = async () => {
    await supabase.from('profiles').update({ is_online: false }).eq('id', currentUser.id);
    await signOut();
    window.location.href = './index.html';
  };

  if (localStorage.getItem('chat_theme') === 'dark') {
    document.body.classList.add('dark');
    $('themeBtn').textContent = '☀️';
  }
  $('themeBtn').onclick = () => {
    document.body.classList.toggle('dark');
    const isDark = document.body.classList.contains('dark');
    $('themeBtn').textContent = isDark ? '☀️' : '🌙';
    localStorage.setItem('chat_theme', isDark ? 'dark' : 'light');
  };

  $('backBtn').onclick = () => $('sidebar').classList.remove('hidden');

  // Composer
  const input = $('messageInput');
  const sendBtn = $('sendBtn');

  input.addEventListener('input', () => {
    input.style.height = 'auto';
    input.style.height = Math.min(input.scrollHeight, 140) + 'px';
    updateSendButton();
    broadcastTyping();
  });

  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
    if (e.key === 'Escape' && editingId) {
      cancelEdit();
    }
  });

  sendBtn.onclick = sendMessage;

  // Attachment
  $('attachBtn').onclick = () => $('fileInput').click();
  $('fileInput').onchange = (e) => {
    const f = e.target.files[0];
    if (f) handleFileSelect(f);
    e.target.value = '';
  };
  $('attachRemove').onclick = clearAttachment;

  // Reply close
  $('replyClose').onclick = () => { replyTo = null; renderReplyPreview(); };

  // Edit close
  $('editClose').onclick = () => cancelEdit();

  // Search
  $('searchToggle').onclick = () => toggleSearch();
  $('chatSearchClose').onclick = () => toggleSearch(false);
  $('chatSearchInput').addEventListener('input', (e) => performSearch(e.target.value));

  // Pin banner close
  $('pinClose').onclick = () => { $('pinnedBanner').style.display = 'none'; };

  // Drag & Drop
  document.addEventListener('dragover', (e) => e.preventDefault());
  document.addEventListener('drop', (e) => {
    e.preventDefault();
    if (e.dataTransfer.files[0] && currentConversation) {
      handleFileSelect(e.dataTransfer.files[0]);
    }
  });

  // Paste image
  document.addEventListener('paste', (e) => {
    const items = e.clipboardData?.items;
    if (!items) return;
    for (const it of items) {
      if (it.type?.startsWith('image/')) {
        const f = it.getAsFile();
        if (f) handleFileSelect(f);
        e.preventDefault();
        return;
      }
    }
  });

  // Lightbox
  $('lightboxClose').onclick = () => $('lightbox').classList.remove('show');
  $('lightbox').onclick = (e) => { if (e.target.id === 'lightbox') $('lightbox').classList.remove('show'); };


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

  // Global click to close reaction pickers
  document.addEventListener('click', (e) => {
    if (!e.target.closest('.reaction-picker') && !e.target.closest('.msg-action-react')) {
      document.querySelectorAll('.reaction-picker').forEach(p => p.remove());
    }
  });
}

function updateSendButton() {
  const hasText = $('messageInput').value.trim().length > 0;
  $('sendBtn').disabled = !hasText && !pendingAttachment && !editingId;
}

// ═══════════════════════════════════════════
// USERS
// ═══════════════════════════════════════════
async function loadUsers() {
  const { data, error } = await supabase
    .from('profiles').select('*').neq('id', currentUser.id)
    .order('is_online', { ascending: false }).order('display_name');
  if (error) { showToast('خطا: ' + error.message, 'error'); return; }
  allUsers = data || [];
  renderUsers();
}

function renderUsers(filter = '') {
  const list = $('userList');
  const q = filter.trim().toLowerCase();
  const filtered = q
    ? allUsers.filter(u => (u.username || '').toLowerCase().includes(q) || (u.display_name || '').toLowerCase().includes(q))
    : allUsers;

  if (!filtered.length) {
    list.innerHTML = '<div style="text-align:center;padding:30px;color:var(--muted);font-size:13px">' + (q ? 'کاربری پیدا نشد' : 'هنوز کاربر دیگری ثبت‌نام نکرده') + '</div>';
    return;
  }

  list.innerHTML = filtered.map(u => {
    const name = u.display_name || u.username;
    const onlineDot = u.is_online ? '<span class="online-dot"></span>' : '';
    const active = currentOtherUser?.id === u.id ? 'active' : '';
    const unread = unreadCounts[u.id] || 0;
    const unreadBadge = unread > 0 ? '<span class="unread-badge">' + (unread > 99 ? '99+' : unread) + '</span>' : '';
    const avatarContent = u.avatar_url
      ? '<img src="' + u.avatar_url + '" alt="" style="width:100%;height:100%;object-fit:cover;border-radius:50%">'
      : getInitials(name);
    return '<div class="user-item ' + active + '" data-id="' + u.id + '">' +
      '<div class="avatar" style="background:' + (u.avatar_url ? 'transparent' : avatarColor(u.id)) + '">' + avatarContent + onlineDot + unreadBadge + '</div>' +
      '<div class="info"><h4>' + escapeHtml(name) + '</h4><p>' + (u.is_online ? 'آنلاین' : 'آفلاین') + '</p></div>' +
      '</div>';
  }).join('');

  list.querySelectorAll('.user-item').forEach(el => {
    el.onclick = () => selectUser(el.dataset.id);
  });
}

function subscribeProfiles() {
  supabase.channel('profiles-changes')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, () => loadUsers())
    .subscribe();
}

// ═══════════════════════════════════════════
// SELECT USER
// ═══════════════════════════════════════════
async function selectUser(otherId) {
  if (otherId === currentUser.id) return;
  const other = allUsers.find(u => u.id === otherId);
  if (!other) return;
  currentOtherUser = other;
  clearAttachment();
  replyTo = null;
  cancelEdit();
  renderReplyPreview();

  const [u1, u2] = [currentUser.id, otherId].sort();
  let { data: conv } = await supabase.from('conversations').select('*')
    .or('and(user1_id.eq.' + u1 + ',user2_id.eq.' + u2 + '),and(user1_id.eq.' + u2 + ',user2_id.eq.' + u1 + ')')
    .maybeSingle();

  if (!conv) {
    const { data: created, error } = await supabase.from('conversations')
      .insert({ user1_id: u1, user2_id: u2 }).select().single();
    if (error) { showToast('خطا: ' + error.message, 'error'); return; }
    conv = created;
  }
  currentConversation = conv;

  const name = other.display_name || other.username;
  $('chatName').textContent = name;
  $('chatStatus').textContent = other.is_online ? 'آنلاین' : 'آفلاین';
  const av = $('chatAvatar');
  av.textContent = getInitials(name);
  av.style.background = avatarColor(other.id);
  $('chatHeader').style.display = 'flex';
  $('composer').style.display = 'flex';
  $('sidebar').classList.add('hidden');
  renderUsers();

  await loadMessages();
  subscribeMessages();
  subscribeReactions();
  setTimeout(() => $('messageInput').focus(), 200);
}

// ═══════════════════════════════════════════
// MESSAGES
// ═══════════════════════════════════════════
async function loadMessages() {
  if (!currentConversation) return;
  const { data, error } = await supabase.from('messages').select('*')
    .eq('conversation_id', currentConversation.id)
    .order('created_at', { ascending: true }).limit(300);
  if (error) { showToast('خطا: ' + error.message, 'error'); return; }

  allMessages = data || [];

  // بارگذاری واکنش‌ها
  const ids = allMessages.map(m => m.id);
  reactionsMap = {};
  if (ids.length) {
    const { data: rxns } = await supabase.from('reactions').select('*').in('message_id', ids);
    (rxns || []).forEach(r => {
      if (!reactionsMap[r.message_id]) reactionsMap[r.message_id] = [];
      reactionsMap[r.message_id].push(r);
    });
  }

  renderAllMessages();
  scrollToBottom();
  markAsRead();
  updatePinnedBanner();
}

function renderAllMessages() {
  const area = $('messagesArea');
  area.innerHTML = '';
  if (!allMessages.length) {
    area.innerHTML = '<div class="empty-chat" style="flex:1"><div class="big-icon">✨</div><p>اولین پیام را بفرست!</p></div>';
    return;
  }
  allMessages.forEach(m => renderMessage(m));
}

function getMessageById(id) {
  return allMessages.find(m => m.id === id);
}

function renderMessage(msg) {
  const area = $('messagesArea');
  const empty = area.querySelector('.empty-chat');
  if (empty) empty.remove();

  const isMine = msg.sender_id === currentUser.id;
  const sender = isMine ? currentProfile : currentOtherUser;
  const name = sender?.display_name || sender?.username || '?';

  const div = document.createElement('div');
  div.className = 'message ' + (isMine ? 'mine' : 'theirs');
  div.dataset.id = msg.id;
  if (msg.pinned_at) div.classList.add('pinned');

  // Reply quote
  let replyHtml = '';
  if (msg.reply_to_id) {
    const orig = getMessageById(msg.reply_to_id);
    if (orig) {
      const origSender = orig.sender_id === currentUser.id ? currentProfile : currentOtherUser;
      const origName = origSender?.display_name || origSender?.username || '?';
      const origText = orig.content || (orig.attachment_type === 'image' ? '📷 عکس' : orig.attachment_type === 'video' ? '🎥 فیلم' : '📄 فایل');
      replyHtml = '<div class="reply-quote" onclick="window.scrollToMessage(\'' + orig.id + '\')">' +
        '<div class="rq-name">' + escapeHtml(origName) + '</div>' +
        '<div class="rq-text">' + escapeHtml(origText.substring(0, 80)) + '</div>' +
        '</div>';
    }
  }

  // Attachment
  let attachHtml = '';
  if (msg.attachment_url) {
    if (msg.attachment_type === 'image') {
      attachHtml = '<div class="attach-image" onclick="window.openLightbox(\'' + msg.attachment_url + '\')"><img src="' + msg.attachment_url + '" loading="lazy" alt=""></div>';
    } else if (msg.attachment_type === 'video') {
      attachHtml = '<div class="attach-video"><video src="' + msg.attachment_url + '" controls preload="metadata"></video></div>';
    } else {
      const sz = msg.attachment_size ? ' (' + fmtSize(msg.attachment_size) + ')' : '';
      attachHtml = '<a class="attach-file" href="' + msg.attachment_url + '" target="_blank" download="' + escapeHtml(msg.attachment_name || 'file') + '">' +
        '<div class="attach-file-icon">📄</div>' +
        '<div class="attach-file-info"><div class="name">' + escapeHtml(msg.attachment_name || 'فایل') + '</div><div class="size">' + sz + '</div></div>' +
        '</a>';
    }
  }

  const textHtml = msg.content ? '<div class="bubble-text">' + escapeHtml(msg.content) + '</div>' : '';
  const editedHtml = msg.edited_at ? '<span class="edited-mark">(ویرایش‌شده)</span>' : '';

  // Reactions
  const reactions = reactionsMap[msg.id] || [];
  const grouped = {};
  reactions.forEach(r => {
    if (!grouped[r.emoji]) grouped[r.emoji] = { count: 0, mine: false };
    grouped[r.emoji].count++;
    if (r.user_id === currentUser.id) grouped[r.emoji].mine = true;
  });
  let reactionsHtml = '';
  if (Object.keys(grouped).length) {
    reactionsHtml = '<div class="reactions-row">' + Object.entries(grouped).map(([emoji, info]) =>
      '<button class="reaction-chip ' + (info.mine ? 'mine' : '') + '" onclick="window.toggleReaction(\'' + msg.id + '\',\'' + emoji + '\')">' +
      emoji + '<span>' + info.count + '</span></button>'
    ).join('') + '</div>';
  }

  // Actions
  const actions = [];
  actions.push('<button class="msg-action" onclick="window.startReply(\'' + msg.id + '\')" title="پاسخ">↩️</button>');
  actions.push('<button class="msg-action msg-action-react" onclick="window.showReactionPicker(event, \'' + msg.id + '\')" title="واکنش">😊</button>');
  actions.push('<button class="msg-action" onclick="window.copyMessage(\'' + msg.id + '\')" title="کپی">📋</button>');
  actions.push('<button class="msg-action" onclick="window.togglePin(\'' + msg.id + '\')" title="پین">📌</button>');
  if (isMine) {
    actions.push('<button class="msg-action" onclick="window.startEdit(\'' + msg.id + '\')" title="ویرایش">✏️</button>');
    actions.push('<button class="msg-action danger" onclick="window.deleteMessage(\'' + msg.id + '\')" title="حذف">🗑</button>');
  }

  div.innerHTML =
    '<div class="msg-avatar" style="background:' + avatarColor(msg.sender_id) + '">' + getInitials(name) + '</div>' +
    '<div class="bubble">' + replyHtml + attachHtml + textHtml +
      '<span class="meta">' + formatTime(msg.created_at) + editedHtml + '</span>' +
      '<div class="msg-actions">' + actions.join('') + '</div>' +
    '</div>' +
    reactionsHtml;

  area.appendChild(div);
}

function updateMessageInDOM(msg) {
  const old = document.querySelector('[data-id="' + msg.id + '"]');
  if (old) old.remove();
  const idx = allMessages.findIndex(m => m.id === msg.id);
  if (idx >= 0) allMessages[idx] = msg;
  renderMessage(msg);
  // preserve order: easiest is re-render all
  renderAllMessages();
  scrollToBottom();
}

function subscribeMessages() {
  if (messagesChannel) supabase.removeChannel(messagesChannel);
  messagesChannel = supabase.channel('messages-' + currentConversation.id)
    .on('postgres_changes', {
      event: 'INSERT', schema: 'public', table: 'messages',
      filter: 'conversation_id=eq.' + currentConversation.id
    }, (payload) => {
      const msg = payload.new;
      if (document.querySelector('[data-id="' + msg.id + '"]')) return;
      allMessages.push(msg);
      renderMessage(msg);
      scrollToBottom();
      if (msg.sender_id !== currentUser.id) {
          markAsRead();
          loadUnreadCounts().then(renderUsers);
          playMsgSound();
          const senderName = currentOtherUser?.display_name || currentOtherUser?.username || 'پیام جدید';
          notifyNewMessage(msg, senderName);
        }
      updatePinnedBanner();
    })
    .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'messages' }, (payload) => {
      const el = document.querySelector('[data-id="' + payload.old.id + '"]');
      if (el) el.remove();
      allMessages = allMessages.filter(m => m.id !== payload.old.id);
      if (pinnedMsg?.id === payload.old.id) { pinnedMsg = null; updatePinnedBanner(); }
      checkEmpty();
    })
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'messages' }, (payload) => {
      const msg = payload.new;
      const idx = allMessages.findIndex(m => m.id === msg.id);
      if (idx >= 0) allMessages[idx] = msg;
      const el = document.querySelector('[data-id="' + msg.id + '"]');
      if (el) el.remove();
      renderMessage(msg);
      updatePinnedBanner();
    })
    .subscribe();
}

function subscribeReactions() {
  if (reactionsChannel) supabase.removeChannel(reactionsChannel);
  reactionsChannel = supabase.channel('reactions-changes')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'reactions' }, (payload) => {
      const r = payload.new || payload.old;
      if (!r) return;
      const msg = allMessages.find(m => m.id === r.message_id);
      if (!msg) return;
      // reload reactions for this message
      refreshReactionsFor(r.message_id);
    })
    .subscribe();
}

async function refreshReactionsFor(messageId) {
  const { data } = await supabase.from('reactions').select('*').eq('message_id', messageId);
  reactionsMap[messageId] = data || [];
  const el = document.querySelector('[data-id="' + messageId + '"]');
  if (el) el.remove();
  const msg = allMessages.find(m => m.id === messageId);
  if (msg) renderMessage(msg);
}

function checkEmpty() {
  const area = $('messagesArea');
  if (!area.querySelector('.message')) {
    area.innerHTML = '<div class="empty-chat" style="flex:1"><div class="big-icon">✨</div><p>اولین پیام را بفرست!</p></div>';
  }
}

// ═══════════════════════════════════════════
// REPLY
// ═══════════════════════════════════════════
window.startReply = function(messageId) {
  const msg = getMessageById(messageId);
  if (!msg) return;
  replyTo = msg;
  cancelEdit();
  renderReplyPreview();
  $('messageInput').focus();
};

function renderReplyPreview() {
  const el = $('replyPreview');
  if (!replyTo) { el.style.display = 'none'; return; }
  const sender = replyTo.sender_id === currentUser.id ? currentProfile : currentOtherUser;
  $('replyName').textContent = sender?.display_name || sender?.username || '?';
  const text = replyTo.content || (replyTo.attachment_type === 'image' ? '📷 عکس' : replyTo.attachment_type === 'video' ? '🎥 فیلم' : '📄 فایل');
  $('replyText').textContent = text.substring(0, 100);
  el.style.display = 'flex';
  el.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

// ═══════════════════════════════════════════
// EDIT
// ═══════════════════════════════════════════
window.startEdit = function(messageId) {
  const msg = getMessageById(messageId);
  if (!msg || msg.sender_id !== currentUser.id) return;
  editingId = messageId;
  $('messageInput').value = msg.content || '';
  $('messageInput').focus();
  $('editText').textContent = (msg.content || '').substring(0, 100);
  $('editBanner').style.display = 'flex';
  replyTo = null;
  renderReplyPreview();
  updateSendButton();
};

function cancelEdit() {
  editingId = null;
  $('messageInput').value = '';
  $('editBanner').style.display = 'none';
  updateSendButton();
}

// ═══════════════════════════════════════════
// REACTIONS
// ═══════════════════════════════════════════
window.showReactionPicker = function(evt, messageId) {
  evt.stopPropagation();
  document.querySelectorAll('.reaction-picker').forEach(p => p.remove());

  const picker = document.createElement('div');
  picker.className = 'reaction-picker';
  EMOJIS.forEach(e => {
    const b = document.createElement('button');
    b.textContent = e;
    b.onclick = (ev) => { ev.stopPropagation(); window.toggleReaction(messageId, e); picker.remove(); };
    picker.appendChild(b);
  });

  const bubble = evt.target.closest('.message').querySelector('.bubble');
  bubble.style.position = 'relative';
  bubble.appendChild(picker);
};

window.toggleReaction = async function(messageId, emoji) {
  const existing = (reactionsMap[messageId] || []).find(r => r.user_id === currentUser.id && r.emoji === emoji);
  if (existing) {
    await supabase.from('reactions').delete().eq('id', existing.id);
  } else {
    // حذف واکنش‌های قبلی این کاربر روی این پیام (هر کاربر یک واکنش)
    const mine = (reactionsMap[messageId] || []).filter(r => r.user_id === currentUser.id);
    for (const r of mine) {
      await supabase.from('reactions').delete().eq('id', r.id);
    }
    await supabase.from('reactions').insert({ message_id: messageId, user_id: currentUser.id, emoji });
  }
};

// ═══════════════════════════════════════════
// PIN
// ═══════════════════════════════════════════
window.togglePin = async function(messageId) {
  const msg = getMessageById(messageId);
  if (!msg) return;
  const newVal = msg.pinned_at ? null : new Date().toISOString();
  const { error } = await supabase.from('messages').update({ pinned_at: newVal }).eq('id', messageId);
  if (error) { showToast('خطا: ' + error.message, 'error'); return; }
  showToast(newVal ? 'پین شد 📌' : 'از پین خارج شد', 'success');
};

function updatePinnedBanner() {
  const pins = allMessages.filter(m => m.pinned_at).sort((a, b) => new Date(b.pinned_at) - new Date(a.pinned_at));
  if (!pins.length) {
    $('pinnedBanner').style.display = 'none';
    pinnedMsg = null;
    return;
  }
  pinnedMsg = pins[0];
  $('pinnedText').textContent = (pinnedMsg.content || '📎 ضمیمه').substring(0, 80);
  $('pinnedBanner').style.display = 'flex';
}

// ═══════════════════════════════════════════
// SEARCH
// ═══════════════════════════════════════════
function toggleSearch(forceState) {
  const bar = $('chatSearchBar');
  const isHidden = bar.style.display === 'none' || !bar.style.display;
  const show = forceState === undefined ? isHidden : forceState;
  bar.style.display = show ? 'flex' : 'none';
  if (show) { $('chatSearchInput').focus(); }
  else { $('chatSearchInput').value = ''; $('searchCount').textContent = ''; clearSearchHighlights(); }
}

function performSearch(query) {
  const q = query.trim().toLowerCase();
  clearSearchHighlights();
  if (!q) { $('searchCount').textContent = ''; return; }
  const matches = [];
  document.querySelectorAll('.message').forEach(el => {
    const text = el.querySelector('.bubble-text')?.textContent?.toLowerCase() || '';
    if (text.includes(q)) {
      el.classList.add('search-match');
      matches.push(el);
    }
  });
  $('searchCount').textContent = matches.length ? matches.length + ' نتیجه' : 'یافت نشد';
  if (matches.length) matches[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
}

function clearSearchHighlights() {
  document.querySelectorAll('.search-match').forEach(el => el.classList.remove('search-match'));
}

// ═══════════════════════════════════════════
// FILES
// ═══════════════════════════════════════════
function handleFileSelect(file) {
  if (!file || !currentConversation) return;
  let type = 'file';
  if (file.type.startsWith('image/')) type = 'image';
  else if (file.type.startsWith('video/')) type = 'video';
  pendingAttachment = { file, type };
  renderAttachmentPreview();
  updateSendButton();
}

function renderAttachmentPreview() {
  const wrap = $('attachmentPreview');
  const content = $('attachPreviewContent');
  const info = $('attachInfo');
  if (!pendingAttachment) { wrap.style.display = 'none'; return; }
  const { file, type } = pendingAttachment;
  content.innerHTML = '';
  if (type === 'image') {
    const img = document.createElement('img');
    img.src = URL.createObjectURL(file);
    img.style.maxHeight = '80px';
    img.style.borderRadius = '8px';
    content.appendChild(img);
  } else {
    const icon = document.createElement('div');
    icon.className = 'attach-icon';
    icon.textContent = type === 'video' ? '🎥' : '📄';
    content.appendChild(icon);
  }
  info.textContent = file.name + ' • ' + fmtSize(file.size);
  wrap.style.display = 'flex';
}

function clearAttachment() {
  pendingAttachment = null;
  $('attachmentPreview').style.display = 'none';
  $('fileInput').value = '';
  updateSendButton();
}

async function uploadAttachment() {
  if (!pendingAttachment) return null;
  const { file, type } = pendingAttachment;
  const sendBtn = $('sendBtn');
  const orig = sendBtn.textContent;

  let finalFile = file;
  try {
    const result = await compressFile(file, (s) => { $('typingIndicator').textContent = s; }, (p) => {
      $('typingIndicator').textContent = 'فشرده‌سازی فیلم: ' + p + '%';
    });
    finalFile = result.file;
    if (result.compressed) {
      const saved = result.originalSize - result.newSize;
      const pct = Math.round((saved / result.originalSize) * 100);
      showToast('فشرده شد: ' + fmtSize(result.originalSize) + ' → ' + fmtSize(result.newSize) + ' (−' + pct + '%)', 'success');
    }
  } catch (e) {
    sendBtn.textContent = orig;
    $('typingIndicator').textContent = '';
    throw new Error(e.message || 'فشرده‌سازی شکست خورد');
  }

  $('typingIndicator').textContent = 'در حال آپلود...';

  const ts = Date.now();
  const safeName = finalFile.name.replace(/[^a-zA-Z0-9._-]/g, '_');
  const path = currentUser.id + '/' + currentConversation.id + '/' + ts + '-' + safeName;

  const { error } = await supabase.storage.from(BUCKET).upload(path, finalFile, {
    cacheControl: '3600', upsert: false, contentType: finalFile.type
  });
  if (error) { $('typingIndicator').textContent = ''; throw error; }

  $('typingIndicator').textContent = '';
  const { data: pub } = supabase.storage.from(BUCKET).getPublicUrl(path);
  return {
    url: pub.publicUrl, type, name: finalFile.name, size: finalFile.size, path
  };
}

// ═══════════════════════════════════════════
// SEND / EDIT
// ═══════════════════════════════════════════
async function sendMessage() {
  const input = $('messageInput');
  const content = input.value.trim();

  // EDIT MODE
  if (editingId) {
    if (!content) return;
    const { error } = await supabase.from('messages')
      .update({ content, edited_at: new Date().toISOString() })
      .eq('id', editingId);
    if (error) { showToast('خطا: ' + error.message, 'error'); return; }
    cancelEdit();
    showToast('ویرایش شد', 'success');
    return;
  }

  // SEND MODE
  if ((!content && !pendingAttachment) || !currentConversation) return;
  const sendBtn = $('sendBtn');
  sendBtn.disabled = true;

  try {
    let attach = null;
    if (pendingAttachment) {
      sendBtn.textContent = '⏳';
      attach = await uploadAttachment();
    }

    const row = {
      conversation_id: currentConversation.id,
      sender_id: currentUser.id,
      content: content || ''
    };
    if (attach) {
      row.attachment_url = attach.url;
      row.attachment_type = attach.type;
      row.attachment_name = attach.name;
      row.attachment_size = attach.size;
    }
    if (replyTo) row.reply_to_id = replyTo.id;

    const { error } = await supabase.from('messages').insert(row);
    if (error) throw error;

    input.value = '';
    input.style.height = '46px';
    clearAttachment();
    replyTo = null;
    renderReplyPreview();
    playSendSound();
    requestNotifPermission();
  } catch (err) {
    showToast('خطا در ارسال: ' + err.message, 'error');
  } finally {
    sendBtn.textContent = '📤';
    updateSendButton();
  }
}

// ═══════════════════════════════════════════
// DELETE / COPY / SCROLL
// ═══════════════════════════════════════════
window.deleteMessage = async function(messageId) {
  if (!confirm('این پیام حذف شود؟')) return;
  const { error } = await supabase.from('messages').delete().eq('id', messageId);
  if (error) { showToast('خطا: ' + error.message, 'error'); return; }
  showToast('حذف شد', 'success');
};

window.copyMessage = function(messageId) {
  const msg = getMessageById(messageId);
  if (!msg) return;
  const text = msg.content || msg.attachment_url || '';
  navigator.clipboard.writeText(text).then(() => showToast('کپی شد 📋', 'success'))
    .catch(() => showToast('کپی نشد', 'error'));
};

window.scrollToMessage = function(messageId) {
  const el = document.querySelector('[data-id="' + messageId + '"]');
  if (el) {
    el.scrollIntoView({ behavior: 'smooth', block: 'center' });
    el.classList.add('highlight-flash');
    setTimeout(() => el.classList.remove('highlight-flash'), 1500);
  }
};

// ═══════════════════════════════════════════
// LIGHTBOX
// ═══════════════════════════════════════════
window.openLightbox = function(url) {
  $('lightboxImg').src = url;
  $('lightbox').classList.add('show');
};

// ═══════════════════════════════════════════
// MISC
// ═══════════════════════════════════════════
async function markAsRead() {
  if (!currentConversation) return;
  await supabase.from('messages').update({ read_at: new Date().toISOString() })
    .eq('conversation_id', currentConversation.id)
    .neq('sender_id', currentUser.id).is('read_at', null);
}

function scrollToBottom() {
  const area = $('messagesArea');
  requestAnimationFrame(() => { area.scrollTop = area.scrollHeight; });
}

function broadcastTyping() {
  if (!currentConversation) return;
  if (!typingChannel) {
    typingChannel = supabase.channel('typing-' + currentConversation.id);
    typingChannel.on('broadcast', { event: 'typing' }, ({ payload }) => {
      if (payload.user_id !== currentUser.id) {
        $('typingIndicator').textContent = 'در حال تایپ...';
        clearTimeout(typingTimer);
        typingTimer = setTimeout(() => { $('typingIndicator').textContent = ''; }, 2000);
      }
    }).subscribe();
  }
  typingChannel.send({ type: 'broadcast', event: 'typing', payload: { user_id: currentUser.id } });
}


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

init();
