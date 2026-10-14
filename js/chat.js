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

const $ = (id) => document.getElementById(id);

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
    sendBtn.disabled = !input.value.trim();
    broadcastTyping();
  });

  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  });

  sendBtn.onclick = sendMessage;
}

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
    list.innerHTML = `<div style="text-align:center;padding:30px;color:var(--muted);font-size:13px">${q ? 'کاربری پیدا نشد' : 'هنوز کاربر دیگری ثبت‌نام نکرده'}</div>`;
    return;
  }

  list.innerHTML = filtered.map(u => {
    const name = u.display_name || u.username;
    const onlineDot = u.is_online ? '<span class="online-dot"></span>' : '';
    const active = currentOtherUser?.id === u.id ? 'active' : '';
    return `<div class="user-item ${active}" data-id="${u.id}">
      <div class="avatar" style="background:${avatarColor(u.id)}">${getInitials(name)}${onlineDot}</div>
      <div class="info"><h4>${escapeHtml(name)}</h4><p>${u.is_online ? 'آنلاین' : 'آفلاین'}</p></div>
    </div>`;
  }).join('');

  list.querySelectorAll('.user-item').forEach(el => { el.onclick = () => selectUser(el.dataset.id); });
}

function subscribeProfiles() {
  supabase.channel('profiles-changes')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, () => loadUsers())
    .subscribe();
}

async function selectUser(otherId) {
  if (otherId === currentUser.id) return;
  const other = allUsers.find(u => u.id === otherId);
  if (!other) return;
  currentOtherUser = other;
  const [u1, u2] = [currentUser.id, otherId].sort();

  let { data: conv } = await supabase.from('conversations').select('*')
    .or(`and(user1_id.eq.${u1},user2_id.eq.${u2}),and(user1_id.eq.${u2},user2_id.eq.${u1})`)
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

async function loadMessages() {
  if (!currentConversation) return;
  const { data, error } = await supabase.from('messages').select('*')
    .eq('conversation_id', currentConversation.id)
    .order('created_at', { ascending: true }).limit(200);
  if (error) { showToast('خطا در بارگذاری پیام‌ها: ' + error.message, 'error'); return; }
  const area = $('messagesArea');
  area.innerHTML = '';
  if (!data?.length) {
    area.innerHTML = `<div class="empty-chat" style="flex:1"><div class="big-icon">✨</div><p>اولین پیام را بفرست!</p></div>`;
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
  div.innerHTML = `<div class="msg-avatar" style="background:${avatarColor(msg.sender_id)}">${getInitials(name)}</div>
    <div class="bubble">${escapeHtml(msg.content)}<span class="meta">${formatTime(msg.created_at)}</span></div>`;
  area.appendChild(div);
}

function subscribeMessages() {
  if (messagesChannel) supabase.removeChannel(messagesChannel);
  messagesChannel = supabase.channel('messages-' + currentConversation.id)
    .on('postgres_changes', {
      event: 'INSERT', schema: 'public', table: 'messages',
      filter: `conversation_id=eq.${currentConversation.id}`
    }, (payload) => {
      const msg = payload.new;
      if (document.querySelector(`[data-id="${msg.id}"]`)) return;
      renderMessage(msg);
      scrollToBottom();
      if (msg.sender_id !== currentUser.id) markAsRead();
    }).subscribe();
}

async function sendMessage() {
  const input = $('messageInput');
  const content = input.value.trim();
  if (!content || !currentConversation) return;
  input.value = '';
  input.style.height = '46px';
  $('sendBtn').disabled = true;
  const { error } = await supabase.from('messages').insert({
    conversation_id: currentConversation.id, sender_id: currentUser.id, content
  });
  if (error) {
    showToast('خطا در ارسال: ' + error.message, 'error');
    input.value = content;
    $('sendBtn').disabled = false;
  }
}

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
