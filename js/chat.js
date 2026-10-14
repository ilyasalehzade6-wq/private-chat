// js/chat.js
import { supabase } from './supabase-client.js';
import { requireAuth, signOut, getProfile } from './auth.js';
import { showToast, formatTime, escapeHtml, getInitials, avatarColor } from './ui.js';

let currentUser = null;
let currentProfile = null;
let allUsers = [];
let currentConversation = null;
let currentOtherUser = null;
let messagesChannel = null;
let typingChannel = null;
let typingTimer = null;
let pendingAttachment = null; // { file, type, url }

const $ = (id) => document.getElementById(id);
const BUCKET = 'chat-attachments';

// ==================== INIT ====================
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
  });

  sendBtn.onclick = sendMessage;

  // دکمه ضمیمه
  $('attachBtn').onclick = () => $('fileInput').click();
  $('fileInput').onchange = (e) => handleFileSelect(e.target.files[0]);
  $('attachRemove').onclick = clearAttachment;

  // Drag & Drop روی صفحه
  document.addEventListener('dragover', (e) => e.preventDefault());
  document.addEventListener('drop', (e) => {
    e.preventDefault();
    if (e.dataTransfer.files[0] && currentConversation) {
      handleFileSelect(e.dataTransfer.files[0]);
    }
  });

  // Paste عکس
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
}

function updateSendButton() {
  const hasText = $('messageInput').value.trim().length > 0;
  $('sendBtn').disabled = !hasText && !pendingAttachment;
}

// ==================== USERS ====================
async function loadUsers() {
  const { data, error } = await supabase
    .from('profiles').select('*').neq('id', currentUser.id)
    .order('is_online', { ascending: false }).order('display_name');
  if (error) { showToast('خطا در بارگذاری کاربران: ' + error.message, 'error'); return; }
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
    return '<div class="user-item ' + active + '" data-id="' + u.id + '">' +
      '<div class="avatar" style="background:' + avatarColor(u.id) + '">' + getInitials(name) + onlineDot + '</div>' +
      '<div class="info"><h4>' + escapeHtml(name) + '</h4><p>' + (u.is_online ? 'آنلاین' : 'آفلاین') + '</p></div>' +
      '</div>';
  }).join('');

  list.querySelectorAll('.user-item').forEach(el => { el.onclick = () => selectUser(el.dataset.id); });
}

function subscribeProfiles() {
  supabase.channel('profiles-changes')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, () => loadUsers())
    .subscribe();
}

// ==================== SELECT USER ====================
async function selectUser(otherId) {
  if (otherId === currentUser.id) return;
  const other = allUsers.find(u => u.id === otherId);
  if (!other) return;
  currentOtherUser = other;
  clearAttachment();

  const [u1, u2] = [currentUser.id, otherId].sort();
  let { data: conv } = await supabase.from('conversations').select('*')
    .or('and(user1_id.eq.' + u1 + ',user2_id.eq.' + u2 + '),and(user1_id.eq.' + u2 + ',user2_id.eq.' + u1 + ')')
    .maybeSingle();

  if (!conv) {
    const { data: created, error } = await supabase.from('conversations')
      .insert({ user1_id: u1, user2_id: u2 }).select().single();
    if (error) { showToast('خطا در ساخت مکالمه: ' + error.message, 'error'); return; }
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
  setTimeout(() => $('messageInput').focus(), 200);
}

// ==================== MESSAGES ====================
async function loadMessages() {
  if (!currentConversation) return;
  const { data, error } = await supabase.from('messages').select('*')
    .eq('conversation_id', currentConversation.id)
    .order('created_at', { ascending: true }).limit(200);
  if (error) { showToast('خطا در بارگذاری پیام‌ها: ' + error.message, 'error'); return; }
  const area = $('messagesArea');
  area.innerHTML = '';
  if (!data?.length) {
    area.innerHTML = '<div class="empty-chat" style="flex:1"><div class="big-icon">✨</div><p>اولین پیام را بفرست!</p></div>';
    return;
  }
  data.forEach(renderMessage);
  scrollToBottom();
  markAsRead();
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

  let attachHtml = '';
  if (msg.attachment_url) {
    if (msg.attachment_type === 'image') {
      attachHtml = '<div class="attach-image" onclick="window.openLightbox(\'' + msg.attachment_url + '\')"><img src="' + msg.attachment_url + '" loading="lazy" alt=""></div>';
    } else if (msg.attachment_type === 'video') {
      attachHtml = '<div class="attach-video"><video src="' + msg.attachment_url + '" controls preload="metadata"></video></div>';
    } else {
      const sz = msg.attachment_size ? ' (' + formatSize(msg.attachment_size) + ')' : '';
      attachHtml = '<a class="attach-file" href="' + msg.attachment_url + '" target="_blank" download="' + escapeHtml(msg.attachment_name || 'file') + '">' +
        '<div class="attach-file-icon">📄</div>' +
        '<div class="attach-file-info"><div class="name">' + escapeHtml(msg.attachment_name || 'فایل') + '</div><div class="size">' + sz + '</div></div>' +
        '</a>';
    }
  }

  const textHtml = msg.content ? '<div class="bubble-text">' + escapeHtml(msg.content) + '</div>' : '';
  const deleteBtn = isMine ? '<button class="msg-delete" onclick="window.deleteMessage(\'' + msg.id + '\')" title="حذف">🗑</button>' : '';

  div.innerHTML =
    '<div class="msg-avatar" style="background:' + avatarColor(msg.sender_id) + '">' + getInitials(name) + '</div>' +
    '<div class="bubble">' + attachHtml + textHtml +
      '<span class="meta">' + formatTime(msg.created_at) + '</span>' +
      deleteBtn +
    '</div>';

  area.appendChild(div);
}

function formatSize(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  if (bytes < 1024 * 1024 * 1024) return (bytes / 1024 / 1024).toFixed(1) + ' MB';
  return (bytes / 1024 / 1024 / 1024).toFixed(1) + ' GB';
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
      renderMessage(msg);
      scrollToBottom();
      if (msg.sender_id !== currentUser.id) markAsRead();
    })
    .on('postgres_changes', {
      event: 'DELETE', schema: 'public', table: 'messages'
    }, (payload) => {
      const el = document.querySelector('[data-id="' + payload.old.id + '"]');
      if (el) el.remove();
      checkEmpty();
    })
    .on('postgres_changes', {
      event: 'UPDATE', schema: 'public', table: 'messages'
    }, (payload) => {
      // بروزرسانی اگر لازم شد (مثلاً read_at)
    })
    .subscribe();
}

function checkEmpty() {
  const area = $('messagesArea');
  if (!area.querySelector('.message')) {
    area.innerHTML = '<div class="empty-chat" style="flex:1"><div class="big-icon">✨</div><p>اولین پیام را بفرست!</p></div>';
  }
}

// ==================== FILE HANDLING ====================
function handleFileSelect(file) {
  if (!file) return;
  if (!currentConversation) { showToast('اول یک گفتگو را انتخاب کن', 'error'); return; }
  const maxSize = 25 * 1024 * 1024; // ۲۵ مگابایت
  if (file.size > maxSize) {
    showToast('حجم فایل بیش از ۲۵ مگابایت است', 'error');
    return;
  }

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
  if (!pendingAttachment) {
    wrap.style.display = 'none';
    return;
  }

  const { file, type } = pendingAttachment;
  content.innerHTML = '';

  if (type === 'image') {
    const url = URL.createObjectURL(file);
    const img = document.createElement('img');
    img.src = url;
    img.style.maxHeight = '80px';
    img.style.borderRadius = '8px';
    content.appendChild(img);
  } else if (type === 'video') {
    const icon = document.createElement('div');
    icon.className = 'attach-icon';
    icon.textContent = '🎥';
    content.appendChild(icon);
  } else {
    const icon = document.createElement('div');
    icon.className = 'attach-icon';
    icon.textContent = '📄';
    content.appendChild(icon);
  }

  info.textContent = file.name + ' • ' + formatSize(file.size);
  wrap.style.display = 'flex';
}

function clearAttachment() {
  if (pendingAttachment?.previewUrl) URL.revokeObjectURL(pendingAttachment.previewUrl);
  pendingAttachment = null;
  $('attachmentPreview').style.display = 'none';
  $('fileInput').value = '';
  updateSendButton();
}

async function uploadAttachment() {
  if (!pendingAttachment) return null;
  const { file } = pendingAttachment;
  const ts = Date.now();
  const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, '_');
  const path = currentUser.id + '/' + currentConversation.id + '/' + ts + '-' + safeName;

  const { data, error } = await supabase.storage
    .from(BUCKET)
    .upload(path, file, {
      cacheControl: '3600',
      upsert: false,
      contentType: file.type
    });

  if (error) throw error;

  const { data: pub } = supabase.storage.from(BUCKET).getPublicUrl(path);
  return {
    url: pub.publicUrl,
    type: pendingAttachment.type,
    name: file.name,
    size: file.size,
    path: path
  };
}

// ==================== SEND ====================
async function sendMessage() {
  const input = $('messageInput');
  const content = input.value.trim();
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

    const { error } = await supabase.from('messages').insert(row);
    if (error) throw error;

    input.value = '';
    input.style.height = '46px';
    clearAttachment();
  } catch (err) {
    showToast('خطا در ارسال: ' + err.message, 'error');
    console.error(err);
  } finally {
    sendBtn.textContent = '📤';
    updateSendButton();
  }
}

// ==================== DELETE ====================
window.deleteMessage = async function(messageId) {
  if (!confirm('این پیام حذف شود؟')) return;
  const { error } = await supabase.from('messages').delete().eq('id', messageId);
  if (error) { showToast('خطا: ' + error.message, 'error'); return; }
  const el = document.querySelector('[data-id="' + messageId + '"]');
  if (el) el.remove();
  checkEmpty();
  showToast('پیام حذف شد', 'success');
};

// ==================== LIGHTBOX ====================
window.openLightbox = function(url) {
  $('lightboxImg').src = url;
  $('lightbox').classList.add('show');
};

// ==================== MISC ====================
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

init();
