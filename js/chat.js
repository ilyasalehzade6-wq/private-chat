// js/chat.js — بازطراحی کامل شبیه روبیکا
import { supabase } from './supabase-client.js';
import { requireAuth, signOut, getProfile } from './auth.js';
import { showToast, formatTime, escapeHtml, getInitials, avatarColor } from './ui.js';
import { compressFile, formatSize as fmtSize } from './compressor.js';

// ═══════════════════ STATE ═══════════════════
let currentUser = null;
let currentProfile = null;
let allUsers = [];
let chatList = [];            // [{otherUser, conversation, lastMessage, lastTime, unread}]
let currentOtherUser = null;
let currentConversation = null;
let currentGroup = null;
let allGroups = [];
let currentChatType = 'private';  // 'private' | 'group'
let currentFilter = 'all';
let allMessages = [];
let reactionsMap = {};
let pendingAttachment = null;
let replyTo = null;
let editingId = null;
let pinnedMsg = null;
let typingTimer = null;
let typingChannel = null;
let messagesChannel = null;
let reactionsChannel = null;
let notificationGranted = false;
let audioCtx = null;
let searchResults = [];
let searchIndex = 0;
let draftTimers = {};           // { chatId: timer }
let forwardedMessage = null;    // پیام در حال فوروارد

// Voice recording
let mediaRecorder = null;
let audioChunks = [];
let voiceTimer = null;
let voiceSeconds = 0;
let voiceStream = null;

const $ = (id) => document.getElementById(id);
const BUCKET = 'chat-attachments';

const EMOJI_CATEGORIES = {
  '😊': ['😀','😃','😄','😁','😆','😅','🤣','😂','🙂','🙃','😉','😊','😇','🥰','😍','🤩','😘','😗','😚','😙','🥲','😋','😛','😜','🤪','😝','🤑','🤗','🤭','🤫','🤔','🤐','🤨','😐','😑','😶','😏','😒','🙄','😬','🤥','😌','😔','😪','🤤','😴','😷','🤒','🤕','🤢','🤮','🤧','🥵','🥶','😵','🤯','🤠','🥳','😎','🤓','🧐','😕','😟','🙁','😮','😯','😲','😳','🥺','😦','😧','😨','😰','😥','😢','😭','😱','😖','😣','😞','😓','😩','😫','🥱','😤','😡','😠'],
  '❤️': ['❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔','❣️','💕','💞','💓','💗','💖','💘','💝','💟','♥️','💋','💌','👨‍❤️‍👨','👩‍❤️‍👩','💑','💏'],
  '👍': ['👍','👎','👌','✌️','🤞','🤟','🤘','🤙','👈','👉','👆','👇','☝️','✋','🤚','🖐️','🖖','👋','🤝','🙏','✊','👊','🤛','🤜','👏','🙌','👐','🤲','💪','🦾'],
  '🎉': ['🎉','🎊','🎈','🎁','🎀','🎂','🍰','🧁','🍾','🥂','🍻','🥳','✨','⭐','🌟','💫','⚡','🔥','💥','🎆','🎇'],
  '🍔': ['🍔','🍕','🍟','🌭','🥪','🌮','🌯','🥙','🧆','🥚','🍳','🥘','🍲','🥣','🥗','🍿','🧈','🧂','🥫','🍱','🍘','🍙','🍚','🍛','🍜','🍝','🍠','🍢','🍣','🍤','🍥','🥮','🍡','🥟','🥠','🥡'],
  '⚽': ['⚽','🏀','🏈','⚾','🥎','🎾','🏐','🏉','🥏','🎱','🪀','🏓','🏸','🏒','🏑','🥍','🏏','🪃','🥅','⛳','🪁','🏹','🎣','🤿','🥊','🥋','🎽','🛹','🛼','🛷','⛸️','🥌','🎿','⛷️','🏂'],
  '🚗': ['🚗','🚕','🚙','🚌','🚎','🏎️','🚓','🚑','🚒','🚐','🛻','🚚','🚛','🚜','🦯','🦽','🦼','🛴','🚲','🛵','🏍️','🛺','🚨','🚔','🚍','🚘','🚖','🚡','🚠','🚟','🚃','🚋','🚞','🚝','🚄','🚅','🚈','🚂','🚆','🚇','🚊','🚉','✈️','🛫','🛬','🛩️','💺','🛰️','🚀','🛸'],
  '💡': ['💡','🔦','🕯️','🪔','🧯','🛢️','💸','💵','💴','💶','💷','💰','💳','💎','⚖️','🪜','🧰','🪛','🔧','🔨','⚒️','🛠️','⛏️','🪚','🔩','⚙️','🪤','🧱','⛓️','🧲','🔫','💣','🧨','🪓','🔪','🗡️','⚔️','🛡️','🚬','⚰️','🪦','⚱️','🏺','🔮','📿','🧿']
};

// ═══════════════════ INIT ═══════════════════
async function init() {
  currentUser = await requireAuth();
  if (!currentUser) return;

  const { data: profile } = await getProfile(currentUser.id);
  currentProfile = profile;
  $('myName').textContent = profile?.display_name || profile?.username || 'من';
  renderMyAvatar();

  await supabase.from('profiles').update({ is_online: true, last_seen: new Date().toISOString() }).eq('id', currentUser.id);

  // heartbeat آخرین بازدید
  setInterval(() => {
    if (document.visibilityState === 'visible') {
      supabase.from('profiles').update({ last_seen: new Date().toISOString(), is_online: true }).eq('id', currentUser.id);
    }
  }, 30000);

  window.addEventListener('beforeunload', () => {
    supabase.from('profiles').update({ is_online: false, last_seen: new Date().toISOString() }).eq('id', currentUser.id);
  });

  await loadAllUsers();
  await loadGroups();
  await loadChatList();
  subscribeProfiles();
  subscribeAllMessages();

  setupUI();
  setupTheme();
  setupTabs();
  setupComposer();
  setupEmoji();
  setupSheets();
  setupContextMenuClose();
  setupProfileModal();
  setupSearch();
  setupGroups();
  setupForward();
  renderChatList();
  subscribeGroups();
  setupVoice();
  setupScrollBottom();

  // اعلان
  if ('Notification' in window && Notification.permission === 'granted') {
    notificationGranted = true;
  }
}


// ═══════════════════════════════════════════
// 📝 Draft خودکار
// ═══════════════════════════════════════════
function draftKey() {
  if (currentChatType === 'group' && currentGroup) return 'draft_group_' + currentGroup.id;
  if (currentConversation) return 'draft_conv_' + currentConversation.id;
  return null;
}

function saveDraft(text) {
  const key = draftKey();
  if (!key) return;
  if (text && text.trim()) localStorage.setItem(key, text);
  else localStorage.removeItem(key);
}

function loadDraft() {
  const key = draftKey();
  if (!key) return '';
  return localStorage.getItem(key) || '';
}

function hasDraft(chatId, kind) {
  const key = kind === 'group' ? 'draft_group_' + chatId : 'draft_conv_' + chatId;
  const v = localStorage.getItem(key);
  return v && v.trim() ? v : null;
}

// ═══════════════════ UI BINDINGS ═══════════════════
function setupUI() {
  $('backBtn').onclick = () => {
    $('sidebar').classList.remove('hidden');
    document.body.classList.remove('in-chat');
  };

  $('myAvatarBtn').onclick = openProfileModal;
  $('newChatBtn').onclick = () => {
    $('sidebar').classList.remove('hidden');
  };
  $('fab').onclick = () => {
    $('sidebar').classList.remove('hidden');
    $('searchInput').focus();
  };
  $('menuBtn').onclick = (e) => {
    showMenu(e, [
      { icon: '👤', label: 'پروفایل من', action: openProfileModal },
      { icon: '🌙', label: 'تغییر تم', action: toggleTheme },
      { icon: '🚪', label: 'خروج', action: doLogout, danger: true }
    ]);
  };

  $('chatInfoBtn').onclick = () => showToast('اطلاعات کاربر به‌زودی');
  $('callVoiceBtn').onclick = () => showToast('تماس صوتی به‌زودی 🔜');
  $('callVideoBtn').onclick = () => showToast('تماس تصویری به‌زودی 🔜');
  $('chatMenuBtn').onclick = (e) => {
    const isMuted = currentChatType === 'group'
      ? currentGroup?.muted
      : currentConversation?.muted;
    showMenu(e, [
      { icon: '🔍', label: 'جستجو', action: () => toggleSearchBar(true) },
      { icon: '📌', label: 'پیام‌های پین', action: () => pinnedMsg && scrollToMessage(pinnedMsg.id) },
      { icon: '🔕', label: isMuted ? 'صدادار کردن' : 'بی‌صدا کردن', action: toggleMute },
      { icon: '🗑', label: 'حذف گفتگو', action: () => showToast('به‌زودی'), danger: true }
    ]);
  };

  $('logoutBtn')?.addEventListener('click', doLogout);
}

async function doLogout() {
  if (!confirm('خارج می‌شوی؟')) return;
  await supabase.from('profiles').update({ is_online: false, last_seen: new Date().toISOString() }).eq('id', currentUser.id);
  await signOut();
  window.location.href = './index.html';
}

function renderMyAvatar() {
  const av = $('myAvatar');
  if (currentProfile?.avatar_url) {
    av.innerHTML = '<img src="' + currentProfile.avatar_url + '" alt="">';
    av.style.background = 'transparent';
  } else {
    av.textContent = getInitials(currentProfile?.display_name || currentProfile?.username || '?');
    av.style.background = 'var(--gradient)';
  }
}

// ═══════════════════ THEME ═══════════════════
function setupTheme() {
  const saved = localStorage.getItem('chat_theme');
  if (saved === 'dark') {
    document.body.classList.add('dark');
    $('themeBtn').textContent = '☀️';
  } else if (!saved) {
    const h = new Date().getHours();
    if (h >= 19 || h < 7) {
      document.body.classList.add('dark');
      $('themeBtn').textContent = '☀️';
    }
  }
  $('themeBtn').onclick = toggleTheme;
}

function toggleTheme() {
  document.body.classList.toggle('dark');
  const isDark = document.body.classList.contains('dark');
  $('themeBtn').textContent = isDark ? '☀️' : '🌙';
  localStorage.setItem('chat_theme', isDark ? 'dark' : 'light');
}

// ═══════════════════ TABS ═══════════════════
function setupTabs() {
  document.querySelectorAll('#chatTabs button').forEach(btn => {
    btn.onclick = () => {
      document.querySelectorAll('#chatTabs button').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      currentFilter = btn.dataset.tab;
      renderChatList();
    };
  });
}

// ═══════════════════ LOAD DATA ═══════════════════
async function loadAllUsers() {
  const { data, error } = await supabase
    .from('profiles').select('*').neq('id', currentUser.id);
  if (error) return;
  allUsers = data || [];
}


async function loadGroups() {
  const { data, error } = await supabase
    .from('group_members')
    .select('group_id, groups(*)')
    .eq('user_id', currentUser.id);
  if (error) { console.warn(error); return; }
  allGroups = (data || []).map(m => m.groups).filter(Boolean);
}

async function loadChatList() {
  const list = $('chatList');
  list.innerHTML = '<div class="loading-state"><div class="spinner"></div><p>در حال بارگذاری...</p></div>';

  // مکالمات خصوصی
  const { data: convs, error } = await supabase
    .from('conversations')
    .select('*')
    .or('user1_id.eq.' + currentUser.id + ',user2_id.eq.' + currentUser.id)
    .order('last_message_at', { ascending: false, nullsFirst: false });

  if (error) { list.innerHTML = '<div class="empty-list"><span class="emoji">⚠️</span>خطا</div>'; return; }

  const items = [];

  // ─── خصوصی ───
  for (const conv of (convs || [])) {
    const otherId = conv.user1_id === currentUser.id ? conv.user2_id : conv.user1_id;
    const other = allUsers.find(u => u.id === otherId);
    if (!other) continue;

    const { data: last } = await supabase
      .from('messages').select('*').eq('conversation_id', conv.id)
      .order('created_at', { ascending: false }).limit(1).maybeSingle();

    const { count } = await supabase
      .from('messages').select('*', { count: 'exact', head: true })
      .eq('conversation_id', conv.id)
      .neq('sender_id', currentUser.id).is('read_at', null);

    items.push({
      kind: 'private',
      id: conv.id,
      otherUser: other,
      conversation: conv,
      lastMessage: last,
      unread: count || 0,
      updatedAt: last?.created_at || conv.last_message_at || conv.created_at
    });
  }

  // کاربران بدون مکالمه
  for (const u of allUsers) {
    if (!items.find(i => i.kind === 'private' && i.otherUser.id === u.id)) {
      items.push({
        kind: 'private',
        id: 'user-' + u.id,
        otherUser: u,
        conversation: null,
        lastMessage: null,
        unread: 0,
        updatedAt: null
      });
    }
  }

  // ─── گروه‌ها ───
  for (const g of allGroups) {
    const { data: last } = await supabase
      .from('messages').select('*').eq('group_id', g.id)
      .order('created_at', { ascending: false }).limit(1).maybeSingle();

    const { count } = await supabase
      .from('messages').select('*', { count: 'exact', head: true })
      .eq('group_id', g.id)
      .neq('sender_id', currentUser.id).is('read_at', null);

    items.push({
      kind: 'group',
      id: g.id,
      group: g,
      lastMessage: last,
      unread: count || 0,
      updatedAt: last?.created_at || g.created_at
    });
  }

  // مرتب‌سازی
  items.sort((a, b) => {
    const at = a.updatedAt ? new Date(a.updatedAt).getTime() : 0;
    const bt = b.updatedAt ? new Date(b.updatedAt).getTime() : 0;
    return bt - at;
  });

  chatList = items;
  renderChatList();
  updateUnreadTabBadge();
}


function renderChatList() {
  const list = $('chatList');
  const q = ($('searchInput').value || '').trim().toLowerCase();

  let items = chatList.slice();

  if (currentFilter === 'unread') items = items.filter(i => i.unread > 0);
  else if (currentFilter === 'online') items = items.filter(i => i.kind === 'private' && i.otherUser.is_online);
  else if (currentFilter === 'groups') items = items.filter(i => i.kind === 'group');

  if (q) {
    items = items.filter(i => {
      if (i.kind === 'group') return (i.group.name || '').toLowerCase().includes(q);
      const n = (i.otherUser.display_name || i.otherUser.username || '').toLowerCase();
      return n.includes(q);
    });
  }

  if (!items.length) {
    list.innerHTML = '<div class="empty-list"><span class="emoji">' + (q ? '🔍' : '💬') + '</span>' + (q ? 'چیزی پیدا نشد' : 'هنوز گفتگویی نداری') + '</div>';
    return;
  }

  list.innerHTML = items.map(item => {
    const isGroup = item.kind === 'group';

    let name, initial, color, avHtml, avStyle, onlineDot, extraClass, active;

    if (isGroup) {
      name = item.group.name;
      initial = item.group.avatar_emoji || '👥';
      color = 'linear-gradient(135deg, #FFB84D, #FF6B9D)';
      avHtml = item.group.avatar_url ? '<img src="' + item.group.avatar_url + '">' : initial;
      avStyle = item.group.avatar_url ? 'transparent' : color;
      onlineDot = '';
      extraClass = 'group-item';
      active = currentGroup?.id === item.group.id ? 'active' : '';
    } else {
      name = item.otherUser.display_name || item.otherUser.username;
      initial = getInitials(name);
      color = avatarColor(item.otherUser.id);
      avHtml = item.otherUser.avatar_url ? '<div class="avatar-img"><img src="' + item.otherUser.avatar_url + '"></div>' : initial;
      avStyle = item.otherUser.avatar_url ? 'transparent' : color;
      onlineDot = item.otherUser.is_online ? '<span class="online-dot"></span>' : '';
      extraClass = '';
      active = currentOtherUser?.id === item.otherUser.id && currentChatType === 'private' ? 'active' : '';
    }

    const unreadBadge = item.unread > 0 ? '<span class="unread-badge">' + (item.unread > 99 ? '99+' : item.unread) + '</span>' : '';

    let preview = 'شروع گفتگو...';
    let time = '';
    let tick = '';
    let isDraft = false;

    // چک draft
    const draftText = hasDraft(item.kind === 'group' ? item.group.id : item.conversation?.id, item.kind);
    if (draftText) {
      preview = draftText;
      isDraft = true;
    } else if (item.lastMessage) {
      const m = item.lastMessage;
      let body = m.content;
      if (!body) {
        if (m.attachment_type === 'image') body = '📷 عکس';
        else if (m.attachment_type === 'video') body = '🎥 ویدیو';
        else if (m.attachment_type === 'voice') body = '🎤 پیام صوتی';
        else body = '📄 فایل';
      }

      if (isGroup && m.sender_id !== currentUser.id) {
        const sender = allUsers.find(u => u.id === m.sender_id);
        const sName = sender?.display_name || sender?.username || '';
        if (sName && m.content) {
          preview = sName + ': ' + m.content.substring(0, 40);
        } else {
          preview = body.substring(0, 55);
        }
      } else {
        preview = body.substring(0, 55);
      }

      time = formatTime(m.created_at);

      if (m.sender_id === currentUser.id) {
        tick = m.read_at ? '<span class="tick read">✓✓</span>' : '<span class="tick">✓✓</span>';
      }
    }

    const previewClass = isDraft ? 'preview draft' : (item.unread > 0 ? 'preview unread' : 'preview');
    const dataId = isGroup ? 'group:' + item.group.id : 'user:' + item.otherUser.id;

    return '<div class="chat-item ' + extraClass + ' ' + active + '" data-id="' + dataId + '">' +
      '<div class="avatar" style="background:' + avStyle + '">' + avHtml + onlineDot + unreadBadge + '</div>' +
      '<div class="body">' +
        '<div class="row1">' +
          '<div class="name">' + escapeHtml(name) + '</div>' +
          '<div class="meta">' +
            ((isGroup ? item.group.muted : item.conversation?.muted) ? '<span class="mute-icon">🔕</span>' : '') +
            '<span>' + time + '</span>' +
          '</div>' +
        '</div>' +
        '<div class="row2"><div class="' + previewClass + '">' + tick + escapeHtml(preview) + '</div></div>' +
      '</div>' +
    '</div>';
  }).join('');

  list.querySelectorAll('.chat-item').forEach(el => {
    el.onclick = () => {
      const id = el.dataset.id;
      if (id.startsWith('group:')) {
        selectGroup(id.substring(6));
      } else {
        selectUser(id.substring(5));
      }
    };
  });
}


function updateUnreadTabBadge() {
  const total = chatList.reduce((sum, i) => sum + (i.unread || 0), 0);
  const badge = $('unreadTabBadge');
  if (total > 0) {
    badge.textContent = total > 99 ? '99+' : total;
    badge.style.display = 'inline-block';
  } else {
    badge.style.display = 'none';
  }
}

// ═══════════════════ SELECT USER ═══════════════════
async function selectUser(otherId) {
  if (otherId === currentUser.id) return;
  const other = allUsers.find(u => u.id === otherId);
  if (!other) return;

  currentOtherUser = other;
  currentGroup = null;
  currentChatType = 'private';
  clearAttachment();
  replyTo = null;
  cancelEdit();

  // پیدا یا ساخت مکالمه
  const [u1, u2] = [currentUser.id, otherId].sort();
  let { data: conv } = await supabase.from('conversations').select('*')
    .or('and(user1_id.eq.' + u1 + ',user2_id.eq.' + u2 + '),and(user1_id.eq.' + u2 + ',user2_id.eq.' + u1 + ')')
    .maybeSingle();

  if (!conv) {
    const { data: created, error } = await supabase.from('conversations')
      .insert({ user1_id: u1, user2_id: u2 }).select().single();
    if (error) { showToast('خطا: ' + error.message, 'error'); return; }
    conv = created;
    // اضافه به لیست
    if (!chatList.find(i => i.otherUser.id === otherId)) {
      chatList.unshift({ otherUser: other, conversation: conv, lastMessage: null, unread: 0 });
    } else {
      const it = chatList.find(i => i.otherUser.id === otherId);
      it.conversation = conv;
    }
  }

  currentConversation = conv;

  // هدر
  const name = other.display_name || other.username;
  $('chatName').textContent = name;
  updateChatStatus();
  const av = $('chatAvatar');
  av.textContent = other.avatar_url ? '' : getInitials(name);
  av.innerHTML = other.avatar_url ? '<img src="' + other.avatar_url + '" alt="">' : getInitials(name);
  av.style.background = other.avatar_url ? 'transparent' : avatarColor(other.id);

  $('chatEmpty').style.display = 'none';
  $('chatActive').style.display = 'flex';
  $('sidebar').classList.add('hidden');
  document.body.classList.add('in-chat');

  renderChatList();
  await loadMessages();
  subscribeMessages();
  subscribeReactions();

  // بارگذاری draft
  $('messageInput').value = loadDraft();
  $('messageInput').style.height = 'auto';
  $('messageInput').style.height = Math.min($('messageInput').scrollHeight, 120) + 'px';
  updateSendButton();

  setTimeout(() => $('messageInput').focus(), 200);
}

function updateChatStatus() {
  if (currentChatType === 'group' && currentGroup) {
    $('chatStatus').textContent = 'گروه';
    $('chatStatus').classList.remove('online', 'typing');
    return;
  }
  if (!currentOtherUser) return;
  const el = $('chatStatus');
  if (currentOtherUser.is_online) {
    el.textContent = 'آنلاین';
    el.classList.add('online');
  } else {
    el.classList.remove('online', 'typing');
    if (currentOtherUser.last_seen) {
      const diff = (Date.now() - new Date(currentOtherUser.last_seen)) / 1000;
      if (diff < 60) el.textContent = 'آخرین بازدید لحظاتی پیش';
      else if (diff < 3600) el.textContent = 'آخرین بازدید ' + Math.floor(diff/60) + ' دقیقه پیش';
      else if (diff < 86400) el.textContent = 'آخرین بازدید ' + Math.floor(diff/3600) + ' ساعت پیش';
      else el.textContent = 'آخرین بازدید ' + formatTime(currentOtherUser.last_seen);
    } else {
      el.textContent = 'آفلاین';
    }
  }
}


// ═══════════════════ MESSAGES ═══════════════════
async function loadMessages() {
  const isGroup = currentChatType === 'group';
  if (!isGroup && !currentConversation) return;
  if (isGroup && !currentGroup) return;

  let query = supabase.from('messages').select('*');
  if (isGroup) query = query.eq('group_id', currentGroup.id);
  else query = query.eq('conversation_id', currentConversation.id);

  const { data, error } = await query.order('created_at', { ascending: true }).limit(300);
  if (error) { showToast('خطا: ' + error.message, 'error'); return; }

  allMessages = data || [];

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
  scrollToBottom(false);
  markAsRead();
  updatePinnedBanner();
}

function renderAllMessages() {
  const area = $('messagesArea');
  area.innerHTML = '';
  if (!allMessages.length) {
    area.innerHTML = '<div class="empty-chat"><div class="empty-art">✨</div><p>اولین پیام را بفرست!</p></div>';
    return;
  }

  let prevMsg = null;
  for (const m of allMessages) {
    if (shouldShowDate(m, prevMsg)) {
      const sep = document.createElement('div');
      sep.className = 'date-separator';
      sep.innerHTML = '<span>' + formatDateSeparator(m.created_at) + '</span>';
      area.appendChild(sep);
    }
    renderMessage(m, prevMsg);
    prevMsg = m;
  }
}

function shouldShowDate(cur, prev) {
  if (!prev) return true;
  return new Date(cur.created_at).toDateString() !== new Date(prev.created_at).toDateString();
}

function formatDateSeparator(dateStr) {
  const d = new Date(dateStr);
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const msgDay = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const diffDays = Math.floor((today - msgDay) / 86400000);

  if (diffDays === 0) return 'امروز';
  if (diffDays === 1) return 'دیروز';
  if (diffDays < 7) {
    const days = ['یکشنبه','دوشنبه','سه‌شنبه','چهارشنبه','پنجشنبه','جمعه','شنبه'];
    return days[d.getDay()];
  }
  try {
    return new Intl.DateTimeFormat('fa-IR', { year: 'numeric', month: 'long', day: 'numeric' }).format(d);
  } catch { return d.toLocaleDateString('fa-IR'); }
}


// ═══════════════════════════════════════════
// 😊 Big Emoji
// ═══════════════════════════════════════════
function isBigEmoji(text) {
  if (!text || text.length > 20) return false;
  // فقط ایموجی و فاصله
  const cleaned = text.replace(/[\s\u200d\ufe0f]/g, '');
  if (!cleaned) return false;
  // الگوی ایموجی (Unicode property)
  const emojiRegex = /^(?:\p{Extended_Pictographic}|\p{Emoji_Component})+$/u;
  try {
    return emojiRegex.test(cleaned) && [...cleaned].length <= 3;
  } catch {
    return false;
  }
}

function renderMessage(msg, prevMsg) {
  const area = $('messagesArea');
  const empty = area.querySelector('.empty-chat');
  if (empty) empty.remove();

  const isMine = msg.sender_id === currentUser.id;
  const isGroup = currentChatType === 'group';
  let sender = isMine ? currentProfile : currentOtherUser;
  if (isGroup && !isMine) {
    sender = allUsers.find(u => u.id === msg.sender_id) || { username: 'کاربر' };
  }
  const name = sender?.display_name || sender?.username || '?';

  const div = document.createElement('div');
  div.className = 'message ' + (isMine ? 'mine' : 'theirs');
  if (msg.content && isBigEmoji(msg.content) && !msg.attachment_url) {
    div.classList.add('big-emoji');
  }
  div.dataset.id = msg.id;

  // Reply
  let replyHtml = '';
  if (msg.reply_to_id) {
    const orig = allMessages.find(m => m.id === msg.reply_to_id);
    if (orig) {
      const oSender = orig.sender_id === currentUser.id ? currentProfile : currentOtherUser;
      const oName = oSender?.display_name || oSender?.username || '?';
      const oText = orig.content || (orig.attachment_type === 'image' ? '📷 عکس' : orig.attachment_type === 'video' ? '🎥 ویدیو' : '📄 فایل');
      replyHtml = '<div class="reply-quote" data-target="' + orig.id + '">' +
        '<div class="rq-name">' + escapeHtml(oName) + '</div>' +
        '<div class="rq-text">' + escapeHtml(oText.substring(0, 80)) + '</div>' +
      '</div>';
    }
  }

  // Attachment
  let attachHtml = '';
  if (msg.attachment_url) {
    if (msg.attachment_type === 'image') {
      attachHtml = '<div class="attach-image"><img src="' + msg.attachment_url + '" loading="lazy" alt=""></div>';
    } else if (msg.attachment_type === 'video') {
      attachHtml = '<div class="attach-video"><video src="' + msg.attachment_url + '" controls preload="metadata"></video></div>';
    } else if (msg.attachment_type === 'voice') {
      const dur = msg.attachment_size || 0; // برای voice از size استفاده می‌کنیم برای مدت
      attachHtml = '<div class="attach-voice">' +
        '<button class="voice-play" data-src="' + msg.attachment_url + '">▶</button>' +
        '<div class="voice-wave-mini"><span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span></div>' +
        '<span class="voice-dur">' + formatDuration(dur) + '</span>' +
      '</div>';
    } else {
      const sz = msg.attachment_size ? ' (' + fmtSize(msg.attachment_size) + ')' : '';
      attachHtml = '<a class="attach-file" href="' + msg.attachment_url + '" target="_blank" download="' + escapeHtml(msg.attachment_name || 'file') + '">' +
        '<div class="attach-file-icon">📄</div>' +
        '<div class="attach-file-info"><div class="name">' + escapeHtml(msg.attachment_name || 'فایل') + '</div><div class="size">' + sz + '</div></div>' +
      '</a>';
    }
  }

  const forwardedHtml = msg.forwarded_from
    ? '<div class="forwarded-badge">➡️ فوروارد شده از ' + escapeHtml(msg.forwarded_from_name || 'کاربر') + '</div>'
    : '';
  const textHtml = msg.content ? '<span class="msg-text">' + escapeHtml(msg.content) + '</span>' : '';
  const editedHtml = msg.edited_at ? ' <span class="edited-mark">(ویرایش‌شده)</span>' : '';

  // Tick
  let tickHtml = '';
  if (isMine) {
    tickHtml = msg.read_at ? '<span class="tick read">✓✓</span>' : '<span class="tick">✓✓</span>';
  }

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
      '<button class="reaction-chip ' + (info.mine ? 'mine' : '') + '" data-emoji="' + emoji + '">' +
        emoji + '<span>' + info.count + '</span></button>'
    ).join('') + '</div>';
  }

  const senderNameHtml = (isGroup && !isMine)
    ? '<div class="sender-name">' + escapeHtml(name) + '</div>'
    : '';

  div.innerHTML =
    '<div class="bubble">' + senderNameHtml + forwardedHtml + replyHtml + attachHtml + textHtml +
      '<span class="meta">' + editedHtml + formatTime(msg.created_at) + tickHtml + '</span>' +
    '</div>' +
    reactionsHtml;

  // رویدادها
  const bubble = div.querySelector('.bubble');
  bubble.addEventListener('contextmenu', (e) => { e.preventDefault(); showMessageMenu(e, msg); });
  bubble.addEventListener('click', (e) => {
    if (e.target.closest('.attach-image')) {
      openLightbox(msg.attachment_url);
      return;
    }
    if (e.target.closest('.voice-play')) {
      playVoice(e.target.closest('.voice-play'));
      return;
    }
    if (e.target.closest('.reply-quote')) {
      scrollToMessage(msg.reply_to_id);
      return;
    }
  });

  div.querySelectorAll('.reaction-chip').forEach(chip => {
    chip.addEventListener('click', (e) => {
      e.stopPropagation();
      toggleReaction(msg.id, chip.dataset.emoji);
    });
  });

  area.appendChild(div);
}

function formatDuration(sec) {
  sec = parseInt(sec) || 0;
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  return m + ':' + String(s).padStart(2, '0');
}

// ═══════════════════ REALTIME ═══════════════════
function subscribeMessages() {
  if (messagesChannel) supabase.removeChannel(messagesChannel);
  const isGroup = currentChatType === 'group';
  const filterField = isGroup ? 'group_id' : 'conversation_id';
  const filterValue = isGroup ? currentGroup.id : currentConversation.id;

  messagesChannel = supabase.channel('msg-' + filterField + '-' + filterValue)
    .on('postgres_changes', {
      event: 'INSERT', schema: 'public', table: 'messages',
      filter: filterField + '=eq.' + filterValue
    }, (payload) => {
      const msg = payload.new;
      if (document.querySelector('[data-id="' + msg.id + '"]')) return;
      const prev = allMessages[allMessages.length - 1];
      allMessages.push(msg);

      if (shouldShowDate(msg, prev)) {
        const sep = document.createElement('div');
        sep.className = 'date-separator';
        sep.innerHTML = '<span>' + formatDateSeparator(msg.created_at) + '</span>';
        $('messagesArea').appendChild(sep);
      }

      renderMessage(msg, prev);
      scrollToBottom(true);

      if (msg.sender_id !== currentUser.id) {
        markAsRead();
        if (!isGroup || !document.hasFocus()) playMsgSound();
        notifyNewMessage(msg);
      }
      updatePinnedBanner();
      updateChatListPreview(msg);
    })
    .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'messages' }, (payload) => {
      const el = document.querySelector('[data-id="' + payload.old.id + '"]');
      if (el) el.remove();
      allMessages = allMessages.filter(m => m.id !== payload.old.id);
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

function subscribeAllMessages() {
  supabase.channel('all-msgs')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages' }, async (payload) => {
      const msg = payload.new;
      // اگر پیام مربوط به مکالمه فعلی است، رد کن (subscribeMessages گرفته)
      if (currentConversation && msg.conversation_id === currentConversation.id) return;
      // به‌روز لیست
      await loadChatList();
      // msg.group_id یا conversation_id
      // اعلان اگر مال من نیست
      if (msg.sender_id !== currentUser.id) {
        notifyNewMessage(msg);
        playMsgSound();
      }
    })
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'messages' }, () => {
      // tick خوانده‌شدن را آپدیت کن
      if (currentConversation) {
        allMessages.forEach(async (m, i) => {
          const { data } = await supabase.from('messages').select('read_at').eq('id', m.id).single();
          if (data && data.read_at !== m.read_at) {
            m.read_at = data.read_at;
            const el = document.querySelector('[data-id="' + m.id + '"]');
            if (el) el.remove();
            renderMessage(m);
          }
        });
      }
    })
    .subscribe();
}

function subscribeReactions() {
  if (reactionsChannel) supabase.removeChannel(reactionsChannel);

  const isGroup = currentChatType === 'group';
  const ctxField = isGroup ? 'group_id' : 'conversation_id';
  const ctxValue = isGroup ? currentGroup?.id : currentConversation?.id;

  if (!ctxValue) return;

  reactionsChannel = supabase.channel('rxns-' + ctxField + '-' + ctxValue)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'reactions' }, async (payload) => {
      const r = payload.new || payload.old;
      if (!r || !r.message_id) return;

      // فقط اگر پیام در چت فعلی است
      const isOurMessage = allMessages.some(m => m.id === r.message_id);
      if (!isOurMessage) return;

      const { data } = await supabase.from('reactions').select('*').eq('message_id', r.message_id);
      reactionsMap[r.message_id] = data || [];
      const el = document.querySelector('[data-id="' + r.message_id + '"]');
      if (el) el.remove();
      const msg = allMessages.find(m => m.id === r.message_id);
      if (msg) renderMessage(msg);
    })
    .subscribe();
}

function subscribeProfiles() {
  supabase.channel('profiles-live')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, async () => {
      await loadAllUsers();
      await loadChatList();
      if (currentOtherUser) {
        currentOtherUser = allUsers.find(u => u.id === currentOtherUser.id) || currentOtherUser;
        updateChatStatus();
      }
    })
    .subscribe();
}

function updateChatListPreview(msg) {
  const item = chatList.find(i => i.conversation?.id === msg.conversation_id);
  if (item) {
    item.lastMessage = msg;
    if (msg.sender_id !== currentUser.id) item.unread = (item.unread || 0) + 1;
  }
  chatList.sort((a, b) => {
    const at = a.lastMessage?.created_at ? new Date(a.lastMessage.created_at) : 0;
    const bt = b.lastMessage?.created_at ? new Date(b.lastMessage.created_at) : 0;
    return bt - at;
  });
  renderChatList();
  updateUnreadTabBadge();
}

// ═══════════════════ SEND ═══════════════════
function setupComposer() {
  const input = $('messageInput');
  const sendBtn = $('sendBtn');

  input.addEventListener('input', () => {
    input.style.height = 'auto';
    input.style.height = Math.min(input.scrollHeight, 120) + 'px';
    updateSendButton();
    broadcastTyping();
    toggleVoiceBtn();
    // ذخیره‌ی draft
    clearTimeout(draftTimers._current);
    draftTimers._current = setTimeout(() => {
      saveDraft(input.value);
    }, 400);
  });

  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
    if (e.key === 'Escape' && editingId) cancelEdit();
  });

  sendBtn.onclick = sendMessage;
}

function toggleVoiceBtn() {
  const input = $('messageInput');
  const voiceBtn = $('voiceBtn');
  if (input.value.trim()) {
    voiceBtn.style.display = 'none';
  } else {
    voiceBtn.style.display = 'flex';
  }
}

function updateSendButton() {
  const input = $('messageInput');
  const hasText = input.value.trim().length > 0;
  $('sendBtn').disabled = !hasText && !pendingAttachment && !editingId;
  toggleVoiceBtn();
}

async function sendMessage() {
  const input = $('messageInput');
  const content = input.value.trim();

  if (editingId) {
    if (!content) return;
    const { error } = await supabase.from('messages')
      .update({ content, edited_at: new Date().toISOString() })
      .eq('id', editingId);
    if (error) { showToast('خطا: ' + error.message, 'error'); return; }
    cancelEdit();
    showToast('ویرایش شد ✅', 'success');
    return;
  }

  if ((!content && !pendingAttachment)) return;
  if (currentChatType === 'group' && !currentGroup) return;
  if (currentChatType === 'private' && !currentConversation) return;
  const sendBtn = $('sendBtn');
  sendBtn.disabled = true;

  try {
    let attach = null;
    if (pendingAttachment) {
      attach = await uploadAttachment();
    }

    const row = {
      sender_id: currentUser.id,
      content: content || ''
    };
    if (currentChatType === 'group') row.group_id = currentGroup.id;
    else row.conversation_id = currentConversation.id;
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
    input.style.height = '40px';
    clearAttachment();
    replyTo = null;
    renderReplyPreview();
    saveDraft('');  // پاک کردن draft
    playSendSound();
    requestNotifPermission();
  } catch (err) {
    showToast('خطا: ' + err.message, 'error');
  } finally {
    updateSendButton();
  }
}

// ═══════════════════ REPLY / EDIT ═══════════════════
function renderReplyPreview() {
  const el = $('replyPreview');
  if (!replyTo) { el.style.display = 'none'; return; }
  const sender = replyTo.sender_id === currentUser.id ? currentProfile : currentOtherUser;
  $('replyName').textContent = sender?.display_name || sender?.username || '?';
  const text = replyTo.content || (replyTo.attachment_type === 'image' ? '📷 عکس' : replyTo.attachment_type === 'video' ? '🎥 ویدیو' : '📄 فایل');
  $('replyText').textContent = text.substring(0, 100);
  el.style.display = 'flex';
  $('messageInput').focus();
}

function cancelEdit() {
  editingId = null;
  $('messageInput').value = '';
  $('messageInput').style.height = '40px';
  $('editPreview').style.display = 'none';
  updateSendButton();
}

$('replyClose') && ($('replyClose').onclick = () => { replyTo = null; renderReplyPreview(); });
$('editClose') && ($('editClose').onclick = cancelEdit);
$('attachClose') && ($('attachClose').onclick = clearAttachment);

// ═══════════════════ ATTACHMENTS ═══════════════════
function setupSheets() {
  $('attachBtn').onclick = () => { $('attachSheet').style.display = 'flex'; };
  $('attachSheet').onclick = (e) => {
    if (e.target.id === 'attachSheet') $('attachSheet').style.display = 'none';
  };

  document.querySelectorAll('.sheet-grid button').forEach(btn => {
    btn.onclick = () => {
      const type = btn.dataset.type;
      $('attachSheet').style.display = 'none';
      if (type === 'gallery') $('galleryInput').click();
      else if (type === 'camera') $('cameraInput').click();
      else if (type === 'file') $('fileInput').click();
      else if (type === 'video') $('fileInput').click();
      else showToast('به‌زودی', 'info');
    };
  });

  $('galleryInput').onchange = (e) => {
    const f = e.target.files[0];
    if (f) handleFileSelect(f);
    e.target.value = '';
  };
  $('cameraInput').onchange = (e) => {
    const f = e.target.files[0];
    if (f) handleFileSelect(f);
    e.target.value = '';
  };
  $('fileInput').onchange = (e) => {
    const f = e.target.files[0];
    if (f) handleFileSelect(f);
    e.target.value = '';
  };

  // Drag & Drop
  document.addEventListener('dragover', (e) => e.preventDefault());
  document.addEventListener('drop', (e) => {
    e.preventDefault();
    if (e.dataTransfer.files[0] && currentConversation) handleFileSelect(e.dataTransfer.files[0]);
  });

  // Paste
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
}

function handleFileSelect(file) {
  if (!file || !currentConversation) return;
  let type = 'file';
  if (file.type.startsWith('image/')) type = 'image';
  else if (file.type.startsWith('video/')) type = 'video';
  else if (file.type.startsWith('audio/')) type = 'voice';

  pendingAttachment = { file, type };
  renderAttachPreview();
  updateSendButton();
}

function renderAttachPreview() {
  const wrap = $('attachPreview');
  const body = $('attachPreviewBody');
  const info = $('attachInfo');
  if (!pendingAttachment) { wrap.style.display = 'none'; return; }
  const { file, type } = pendingAttachment;
  body.innerHTML = '';
  if (type === 'image') {
    const img = document.createElement('img');
    img.src = URL.createObjectURL(file);
    body.appendChild(img);
  } else if (type === 'video') body.textContent = '🎥';
  else if (type === 'voice') body.textContent = '🎤';
  else body.textContent = '📄';
  info.textContent = file.name + ' • ' + fmtSize(file.size);
  wrap.style.display = 'flex';
}

function clearAttachment() {
  pendingAttachment = null;
  $('attachPreview').style.display = 'none';
  updateSendButton();
}

async function uploadAttachment() {
  if (!pendingAttachment) return null;
  const { file, type } = pendingAttachment;
  let finalFile = file;

  try {
    const result = await compressFile(file, (s) => $('typingText') && ($('typingText').textContent = s), () => {});
    finalFile = result.file;
    if (result.compressed) {
      const saved = result.originalSize - result.newSize;
      const pct = Math.round((saved / result.originalSize) * 100);
      showToast('فشرده شد: ' + fmtSize(result.originalSize) + ' → ' + fmtSize(result.newSize) + ' (−' + pct + '%)', 'success');
    }
  } catch (e) { /* ادامه با فایل اصلی */ }

  const ts = Date.now();
  const safeName = finalFile.name.replace(/[^a-zA-Z0-9._-]/g, '_');
  const ctxId = currentChatType === 'group' ? currentGroup.id : currentConversation.id;
  const path = currentUser.id + '/' + ctxId + '/' + ts + '-' + safeName;

  const { error } = await supabase.storage.from(BUCKET).upload(path, finalFile, {
    cacheControl: '3600', upsert: false, contentType: finalFile.type
  });
  if (error) throw error;

  const { data: pub } = supabase.storage.from(BUCKET).getPublicUrl(path);
  return { url: pub.publicUrl, type, name: finalFile.name, size: finalFile.size, path };
}

// ═══════════════════ EMOJI ═══════════════════
function setupEmoji() {
  const picker = $('emojiPicker');
  const tabs = $('emojiTabs');
  const grid = $('emojiGrid');

  tabs.innerHTML = Object.keys(EMOJI_CATEGORIES).map((cat, i) =>
    '<button data-cat="' + i + '"' + (i === 0 ? ' class="active"' : '') + '>' + cat + '</button>'
  ).join('');

  function renderEmojis(catIdx) {
    const cat = Object.values(EMOJI_CATEGORIES)[catIdx];
    grid.innerHTML = cat.map(e => '<button>' + e + '</button>').join('');
    grid.querySelectorAll('button').forEach(b => {
      b.onclick = () => {
        const input = $('messageInput');
        input.value += b.textContent;
        input.focus();
        updateSendButton();
      };
    });
  }

  renderEmojis(0);
  tabs.querySelectorAll('button').forEach(b => {
    b.onclick = () => {
      tabs.querySelectorAll('button').forEach(x => x.classList.remove('active'));
      b.classList.add('active');
      renderEmojis(+b.dataset.cat);
    };
  });

  $('emojiBtn').onclick = (e) => {
    e.stopPropagation();
    picker.style.display = picker.style.display === 'none' ? 'flex' : 'none';
  };

  document.addEventListener('click', (e) => {
    if (!e.target.closest('#emojiPicker') && !e.target.closest('#emojiBtn')) {
      picker.style.display = 'none';
    }
  });
}

// ═══════════════════ MESSAGE MENU ═══════════════════
function showMessageMenu(e, msg) {
  const isMine = msg.sender_id === currentUser.id;
  const items = [
    { icon: '↩️', label: 'پاسخ', action: () => { replyTo = msg; renderReplyPreview(); } },
    { icon: '😊', label: 'واکنش', action: () => showReactionPickerFor(msg) },
    { icon: '📋', label: 'کپی', action: () => copyMsg(msg) },
    { icon: '📌', label: msg.pinned_at ? 'برداشتن پین' : 'پین', action: () => togglePin(msg) }
  ];
  if (isMine && msg.content) items.push({ icon: '✏️', label: 'ویرایش', action: () => startEdit(msg) });
  items.push({ icon: '➡️', label: 'فوروارد', action: () => showToast('به‌زودی') });
  if (isMine) items.push({ icon: '🗑', label: 'حذف', action: () => deleteMsg(msg), danger: true });

  showMenu(e, items);
}

function showMenu(e, items) {
  const menu = $('contextMenu');
  menu.innerHTML = items.map((it, i) =>
    '<button data-i="' + i + '"' + (it.danger ? ' class="danger"' : '') + '>' +
      '<span class="emoji">' + it.icon + '</span>' + it.label +
    '</button>'
  ).join('');
  menu.style.display = 'block';

  const rect = menu.getBoundingClientRect();
  let x = e.clientX, y = e.clientY;
  if (x + rect.width > window.innerWidth - 10) x = window.innerWidth - rect.width - 10;
  if (y + rect.height > window.innerHeight - 10) y = window.innerHeight - rect.height - 10;
  menu.style.left = x + 'px';
  menu.style.top = y + 'px';

  menu.querySelectorAll('button').forEach(b => {
    b.onclick = () => {
      menu.style.display = 'none';
      items[+b.dataset.i].action();
    };
  });
}

function setupContextMenuClose() {
  document.addEventListener('click', (e) => {
    if (!e.target.closest('#contextMenu')) {
      $('contextMenu').style.display = 'none';
    }
  });
}

function showReactionPickerFor(msg) {
  const emojis = ['❤️', '😂', '👍', '😮', '😢', '🔥'];
  showToast('روی ایموجی بزن', 'info');
  // ساخت picker موقت
  const picker = document.createElement('div');
  picker.className = 'reaction-picker';
  picker.style.cssText = 'position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);z-index:9999';
  picker.innerHTML = emojis.map(e => '<button>' + e + '</button>').join('');
  document.body.appendChild(picker);
  picker.querySelectorAll('button').forEach(b => {
    b.onclick = () => { toggleReaction(msg.id, b.textContent); picker.remove(); };
  });
  setTimeout(() => document.addEventListener('click', function h(ev) {
    if (!picker.contains(ev.target)) { picker.remove(); document.removeEventListener('click', h); }
  }), 100);
}

async function toggleReaction(messageId, emoji) {
  const mine = (reactionsMap[messageId] || []).find(r => r.user_id === currentUser.id && r.emoji === emoji);
  if (mine) {
    await supabase.from('reactions').delete().eq('id', mine.id);
  } else {
    const others = (reactionsMap[messageId] || []).filter(r => r.user_id === currentUser.id);
    for (const r of others) await supabase.from('reactions').delete().eq('id', r.id);
    await supabase.from('reactions').insert({ message_id: messageId, user_id: currentUser.id, emoji });
  }
}

function startEdit(msg) {
  editingId = msg.id;
  $('messageInput').value = msg.content || '';
  $('messageInput').focus();
  $('editText').textContent = (msg.content || '').substring(0, 100);
  $('editPreview').style.display = 'flex';
  replyTo = null;
  renderReplyPreview();
  updateSendButton();
}

function copyMsg(msg) {
  const text = msg.content || msg.attachment_url || '';
  navigator.clipboard.writeText(text).then(() => showToast('کپی شد 📋', 'success'))
    .catch(() => showToast('کپی نشد', 'error'));
}

async function togglePin(msg) {
  const newVal = msg.pinned_at ? null : new Date().toISOString();
  const { error } = await supabase.from('messages').update({ pinned_at: newVal }).eq('id', msg.id);
  if (error) { showToast('خطا: ' + error.message, 'error'); return; }
  showToast(newVal ? 'پین شد 📌' : 'از پین خارج شد', 'success');
}

async function deleteMsg(msg) {
  if (!confirm('این پیام حذف شود؟')) return;
  const { error } = await supabase.from('messages').delete().eq('id', msg.id);
  if (error) { showToast('خطا: ' + error.message, 'error'); return; }
  showToast('حذف شد', 'success');
}

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
  $('pinBody').onclick = () => scrollToMessage(pinnedMsg.id);
}

$('pinClose') && ($('pinClose').onclick = () => $('pinnedBanner').style.display = 'none');

// ═══════════════════ SEARCH ═══════════════════
function setupSearch() {
  $('searchInput').addEventListener('input', () => renderChatList());
  $('searchInputChat').addEventListener('input', (e) => performSearch(e.target.value));
  $('searchClose').onclick = () => toggleSearchBar(false);
  $('searchPrev').onclick = () => navigateSearch(-1);
  $('searchNext').onclick = () => navigateSearch(1);
}

function toggleSearchBar(show) {
  $('searchBar').style.display = show ? 'flex' : 'none';
  if (show) { $('searchInputChat').focus(); }
  else {
    $('searchInputChat').value = '';
    $('searchCount').textContent = '';
    searchResults = [];
    document.querySelectorAll('.message.highlight').forEach(el => el.classList.remove('highlight'));
  }
}

function performSearch(q) {
  document.querySelectorAll('.message.highlight').forEach(el => el.classList.remove('highlight'));
  searchResults = [];
  searchIndex = 0;
  if (!q.trim()) { $('searchCount').textContent = ''; return; }
  const query = q.trim().toLowerCase();
  document.querySelectorAll('.message').forEach(el => {
    const txt = el.querySelector('.msg-text')?.textContent?.toLowerCase() || '';
    if (txt.includes(query)) {
      el.classList.add('highlight');
      searchResults.push(el);
    }
  });
  $('searchCount').textContent = searchResults.length ? '1/' + searchResults.length : 'یافت نشد';
  if (searchResults.length) {
    searchResults[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
  }
}

function navigateSearch(dir) {
  if (!searchResults.length) return;
  searchIndex = (searchIndex + dir + searchResults.length) % searchResults.length;
  searchResults[searchIndex].scrollIntoView({ behavior: 'smooth', block: 'center' });
  $('searchCount').textContent = (searchIndex + 1) + '/' + searchResults.length;
}

function scrollToMessage(id) {
  const el = document.querySelector('[data-id="' + id + '"]');
  if (el) {
    el.scrollIntoView({ behavior: 'smooth', block: 'center' });
    el.classList.add('highlight');
    setTimeout(() => el.classList.remove('highlight'), 1500);
  }
}

// ═══════════════════ VOICE ═══════════════════
function setupVoice() {
  const btn = $('voiceBtn');
  if (!btn) return;

  let isRecording = false;

  btn.onclick = async () => {
    if (!isRecording) {
      try {
        voiceStream = await navigator.mediaDevices.getUserMedia({ audio: true });
        mediaRecorder = new MediaRecorder(voiceStream);
        audioChunks = [];
        mediaRecorder.ondataavailable = (e) => audioChunks.push(e.data);
        mediaRecorder.onstop = async () => {
          const blob = new Blob(audioChunks, { type: 'audio/webm' });
          voiceStream.getTracks().forEach(t => t.stop());
          await sendVoice(blob, voiceSeconds);
        };
        mediaRecorder.start();
        isRecording = true;
        voiceSeconds = 0;
        $('voiceRecording').style.display = 'flex';
        $('composer').style.display = 'none';
        voiceTimer = setInterval(() => {
          voiceSeconds++;
          $('voiceTime').textContent = formatDuration(voiceSeconds);
        }, 1000);
        $('voiceTime').textContent = '0:00';
      } catch (e) {
        showToast('دسترسی به میکروفون رد شد', 'error');
      }
    }
  };

  $('voiceCancel').onclick = () => {
    if (mediaRecorder && isRecording) {
      mediaRecorder.onstop = null;
      mediaRecorder.stop();
      voiceStream.getTracks().forEach(t => t.stop());
    }
    clearInterval(voiceTimer);
    isRecording = false;
    $('voiceRecording').style.display = 'none';
    $('composer').style.display = 'flex';
  };

  $('voiceSend').onclick = () => {
    if (mediaRecorder && isRecording) {
      mediaRecorder.stop();
    }
    clearInterval(voiceTimer);
    isRecording = false;
    $('voiceRecording').style.display = 'none';
    $('composer').style.display = 'flex';
  };
}

async function sendVoice(blob, duration) {
  if (!currentConversation) return;
  const ts = Date.now();
  const path = currentUser.id + '/' + currentConversation.id + '/voice-' + ts + '.webm';
  const file = new File([blob], 'voice.webm', { type: 'audio/webm' });

  const { error } = await supabase.storage.from(BUCKET).upload(path, file, {
    contentType: 'audio/webm'
  });
  if (error) { showToast('خطا: ' + error.message, 'error'); return; }

  const { data: pub } = supabase.storage.from(BUCKET).getPublicUrl(path);
  await supabase.from('messages').insert({
    conversation_id: currentConversation.id,
    sender_id: currentUser.id,
    content: '',
    attachment_url: pub.publicUrl,
    attachment_type: 'voice',
    attachment_size: duration
  });
}

function playVoice(btn) {
  const src = btn.dataset.src;
  const audio = new Audio(src);
  btn.textContent = '⏸';
  audio.play();
  audio.onended = () => { btn.textContent = '▶'; };
}

// ═══════════════════ SCROLL ═══════════════════
function setupScrollBottom() {
  const area = $('messagesArea');
  const btn = $('scrollBottom');
  area.addEventListener('scroll', () => {
    const near = area.scrollHeight - area.scrollTop - area.clientHeight < 200;
    btn.style.display = near ? 'none' : 'flex';
  });
  btn.onclick = () => scrollToBottom(true);
}

function scrollToBottom(smooth) {
  const area = $('messagesArea');
  requestAnimationFrame(() => {
    area.scrollTo({ top: area.scrollHeight, behavior: smooth ? 'smooth' : 'auto' });
  });
}

// ═══════════════════ PROFILE ═══════════════════
function setupProfileModal() {
  $('profileClose').onclick = () => $('profileModal').style.display = 'none';
  $('profileModal').onclick = (e) => { if (e.target.id === 'profileModal') $('profileModal').style.display = 'none'; };
  $('profileSave').onclick = saveProfile;
  $('avatarInput').onchange = (e) => {
    const f = e.target.files[0];
    if (f) previewAvatar(f);
  };
}

let pendingAvatarFile = null;

function openProfileModal() {
  $('profileDisplayName').value = currentProfile?.display_name || '';
  $('profileUsername').value = currentProfile?.username || '';
  const prev = $('avatarPreview');
  if (currentProfile?.avatar_url) {
    prev.innerHTML = '<img src="' + currentProfile.avatar_url + '">';
  } else {
    prev.textContent = getInitials(currentProfile?.display_name || '?');
  }
  $('profileModal').style.display = 'flex';
}

function previewAvatar(file) {
  pendingAvatarFile = file;
  const prev = $('avatarPreview');
  prev.innerHTML = '';
  const img = document.createElement('img');
  img.src = URL.createObjectURL(file);
  prev.appendChild(img);
}

async function saveProfile() {
  const displayName = $('profileDisplayName').value.trim();
  const btn = $('profileSave');
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
    renderMyAvatar();
    pendingAvatarFile = null;
    $('profileModal').style.display = 'none';
    showToast('ذخیره شد ✅', 'success');
    await loadAllUsers();
    await loadChatList();
  } catch (e) {
    showToast('خطا: ' + e.message, 'error');
  } finally {
    btn.disabled = false;
    btn.textContent = 'ذخیره تغییرات';
  }
}

// ═══════════════════ LIGHTBOX ═══════════════════
function openLightbox(url) {
  $('lightboxImg').src = url;
  $('lightbox').classList.add('show');
}
$('lightboxClose') && ($('lightboxClose').onclick = () => $('lightbox').classList.remove('show'));
$('lightbox') && ($('lightbox').onclick = (e) => { if (e.target.id === 'lightbox') $('lightbox').classList.remove('show'); });


// ═══════════════════════════════════════════
// ➡️ Forward
// ═══════════════════════════════════════════
function openForwardModal(msg) {
  forwardedMessage = msg;
  const modal = $('forwardModal');
  modal.style.display = 'flex';
  $('forwardSearch').value = '';
  renderForwardList('');
  setTimeout(() => $('forwardSearch').focus(), 100);
}

function renderForwardList(query) {
  const list = $('forwardList');
  const q = (query || '').trim().toLowerCase();

  const items = [];
  for (const item of chatList) {
    if (item.kind === 'private' && item.conversation) {
      items.push({ type: 'private', label: item.otherUser.display_name || item.otherUser.username, item });
    } else if (item.kind === 'group') {
      items.push({ type: 'group', label: item.group.name, item });
    }
  }

  const filtered = q ? items.filter(i => i.label.toLowerCase().includes(q)) : items;

  if (!filtered.length) {
    list.innerHTML = '<div class="empty-list" style="padding:30px"><span class="emoji">💬</span>چتی پیدا نشد</div>';
    return;
  }

  list.innerHTML = filtered.map((it, i) => {
    if (it.type === 'group') {
      const g = it.item.group;
      return '<div class="forward-item group" data-i="' + i + '">' +
        '<div class="avatar">' + (g.avatar_emoji || '👥') + '</div>' +
        '<div class="name">' + escapeHtml(g.name) + '</div>' +
        '<div class="type-badge">گروه</div>' +
      '</div>';
    } else {
      const u = it.item.otherUser;
      const name = u.display_name || u.username;
      const color = avatarColor(u.id);
      const av = u.avatar_url ? '<img src="' + u.avatar_url + '">' : getInitials(name);
      return '<div class="forward-item" data-i="' + i + '">' +
        '<div class="avatar" style="background:' + (u.avatar_url ? 'transparent' : color) + '">' + av + '</div>' +
        '<div class="name">' + escapeHtml(name) + '</div>' +
      '</div>';
    }
  }).join('');

  list.querySelectorAll('.forward-item').forEach(el => {
    el.onclick = () => {
      const data = filtered[+el.dataset.i];
      doForward(data);
    };
  });
}

async function doForward(target) {
  if (!forwardedMessage) return;
  const msg = forwardedMessage;
  $('forwardModal').style.display = 'none';

  try {
    const row = {
      sender_id: currentUser.id,
      content: msg.content || '',
      forwarded_from: msg.id,
      forwarded_from_name: (() => {
        const s = allUsers.find(u => u.id === msg.sender_id);
        return s ? (s.display_name || s.username) : 'ناشناس';
      })()
    };
    if (msg.attachment_url) {
      row.attachment_url = msg.attachment_url;
      row.attachment_type = msg.attachment_type;
      row.attachment_name = msg.attachment_name;
      row.attachment_size = msg.attachment_size;
    }

    if (target.type === 'group') {
      row.group_id = target.item.group.id;
    } else {
      row.conversation_id = target.item.conversation.id;
    }

    const { error } = await supabase.from('messages').insert(row);
    if (error) throw error;

    showToast('فوروارد شد ✅', 'success');
    await loadChatList();
  } catch (e) {
    showToast('خطا: ' + e.message, 'error');
  } finally {
    forwardedMessage = null;
  }
}


// ═══════════════════════════════════════════
// 🔕 Mute
// ═══════════════════════════════════════════
async function toggleMute() {
  try {
    if (currentChatType === 'group') {
      if (!currentGroup) return;
      const newVal = !currentGroup.muted;
      const { error } = await supabase.from('group_members')
        .update({ muted: newVal })
        .eq('group_id', currentGroup.id)
        .eq('user_id', currentUser.id);
      if (error) throw error;
      currentGroup.muted = newVal;
      const item = chatList.find(i => i.kind === 'group' && i.group?.id === currentGroup.id);
      if (item) item.group.muted = newVal;
    } else {
      if (!currentConversation) return;
      const newVal = !currentConversation.muted;
      const { error } = await supabase.from('conversations')
        .update({ muted: newVal })
        .eq('id', currentConversation.id);
      if (error) throw error;
      currentConversation.muted = newVal;
      const item = chatList.find(i => i.kind === 'private' && i.conversation?.id === currentConversation.id);
      if (item) item.conversation.muted = newVal;
    }
    showToast(currentChatType === 'group' ? 'انجام شد' : 'انجام شد', 'success');
    renderChatList();
  } catch (e) {
    showToast('خطا: ' + e.message, 'error');
  }
}

// ═══════════════════ MISC ═══════════════════
async function markAsRead() {
  const isGroup = currentChatType === 'group';
  let query = supabase.from('messages').update({ read_at: new Date().toISOString() });
  if (isGroup) {
    if (!currentGroup) return;
    query = query.eq('group_id', currentGroup.id);
  } else {
    if (!currentConversation) return;
    query = query.eq('conversation_id', currentConversation.id);
  }
  await query.neq('sender_id', currentUser.id).is('read_at', null);

  const item = chatList.find(i =>
    isGroup ? i.group?.id === currentGroup.id : i.conversation?.id === currentConversation?.id
  );
  if (item) item.unread = 0;
  updateUnreadTabBadge();
}


function broadcastTyping() {
  const isGroup = currentChatType === 'group';
  const ctxId = isGroup ? currentGroup?.id : currentConversation?.id;
  if (!ctxId) return;

  if (!typingChannel || typingChannel._ctxId !== ctxId) {
    if (typingChannel) supabase.removeChannel(typingChannel);
    typingChannel = supabase.channel('typing-' + ctxId);
    typingChannel._ctxId = ctxId;
    typingChannel.on('broadcast', { event: 'typing' }, ({ payload }) => {
      if (payload.user_id !== currentUser.id) {
        $('typingRow').style.display = 'flex';
        if (isGroup) {
          const sender = allUsers.find(u => u.id === payload.user_id);
          const name = sender?.display_name || sender?.username || 'کسی';
          $('typingText').textContent = name + ' در حال نوشتن...';
        } else {
          $('typingText').textContent = 'در حال نوشتن...';
        }
        clearTimeout(typingTimer);
        typingTimer = setTimeout(() => {
          $('typingRow').style.display = 'none';
          if (!isGroup) updateChatStatus();
        }, 2500);
      }
    }).subscribe();
  }
  typingChannel.send({ type: 'broadcast', event: 'typing', payload: { user_id: currentUser.id } });
}



function notifyNewMessage(msg) {
  if (!notificationGranted) return;
  if (document.visibilityState === 'visible' && document.hasFocus()) return;
  const sender = allUsers.find(u => u.id === msg.sender_id);
  const name = sender?.display_name || sender?.username || 'پیام جدید';
  const body = msg.content || (msg.attachment_type === 'image' ? '📷 عکس' : msg.attachment_type === 'video' ? '🎥 ویدیو' : msg.attachment_type === 'voice' ? '🎤 صدا' : '📄 فایل');
  try {
    new Notification(name, { body: body.substring(0, 100), tag: 'msg-' + msg.id, silent: false });
  } catch (e) {}
}

// ═══════════════════ START ═══════════════════

// ═══════════════════════════════════════════
// 👥 گروه چت
// ═══════════════════════════════════════════

function setupForward() {
  $('forwardClose').onclick = () => {
    $('forwardModal').style.display = 'none';
    forwardedMessage = null;
  };
  $('forwardModal').onclick = (e) => {
    if (e.target.id === 'forwardModal') {
      $('forwardModal').style.display = 'none';
      forwardedMessage = null;
    }
  };
  $('forwardSearch').addEventListener('input', (e) => renderForwardList(e.target.value));
}

function setupGroups() {
  $('newGroupBtn').onclick = () => openCreateGroupModal();
  $('createGroupClose').onclick = () => $('createGroupModal').style.display = 'none';
  $('createGroupModal').onclick = (e) => {
    if (e.target.id === 'createGroupModal') $('createGroupModal').style.display = 'none';
  };
  $('createGroupBtn').onclick = createGroup;

  // Emoji picker برای آواتار
  document.querySelectorAll('#groupEmojiRow button').forEach(btn => {
    btn.onclick = () => {
      document.querySelectorAll('#groupEmojiRow button').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      $('groupAvatarPreview').textContent = btn.dataset.emoji;
    };
  });
}

function openCreateGroupModal() {
  if (!allUsers.length) { showToast('کاربر دیگری نیست', 'error'); return; }
  $('groupNameInput').value = '';
  $('groupAvatarPreview').textContent = '👥';
  document.querySelectorAll('#groupEmojiRow button').forEach((b, i) => {
    b.classList.toggle('active', i === 0);
  });

  const picker = $('memberPicker');
  picker.innerHTML = allUsers.map(u => {
    const name = u.display_name || u.username;
    const color = avatarColor(u.id);
    const avHtml = u.avatar_url
      ? '<img src="' + u.avatar_url + '">'
      : getInitials(name);
    return '<div class="member-item" data-id="' + u.id + '">' +
      '<div class="avatar" style="background:' + (u.avatar_url ? 'transparent' : color) + '">' + avHtml + '</div>' +
      '<div class="name">' + escapeHtml(name) + '</div>' +
      '<div class="check">✓</div>' +
    '</div>';
  }).join('');

  picker.querySelectorAll('.member-item').forEach(el => {
    el.onclick = () => el.classList.toggle('selected');
  });

  $('createGroupModal').style.display = 'flex';
}

async function createGroup() {
  const name = $('groupNameInput').value.trim();
  if (!name) { showToast('نام گروه را وارد کن', 'error'); return; }

  const selected = [...document.querySelectorAll('#memberPicker .member-item.selected')]
    .map(el => el.dataset.id);
  if (!selected.length) { showToast('حداقل یک عضو انتخاب کن', 'error'); return; }

  const emoji = $('groupAvatarPreview').textContent || '👥';
  const btn = $('createGroupBtn');
  btn.disabled = true;
  btn.textContent = 'در حال ساخت...';

  try {
    // مرحله ۱: ساخت گروه
    const { data: group, error: gErr } = await supabase
      .from('groups')
      .insert({ name, avatar_emoji: emoji, created_by: currentUser.id })
      .select()
      .single();
    if (gErr) throw gErr;

    // مرحله ۲: اضافه کردن سازنده به‌عنوان ادمین (اول)
    const { error: adminErr } = await supabase.from('group_members').insert({
      group_id: group.id, user_id: currentUser.id, role: 'admin'
    });
    if (adminErr) {
      // پاک‌سازی در صورت خطا
      await supabase.from('groups').delete().eq('id', group.id);
      throw adminErr;
    }

    // مرحله ۳: اضافه کردن بقیه اعضا
    if (selected.length) {
      const members = selected.map(uid => ({
        group_id: group.id, user_id: uid, role: 'member'
      }));
      const { error: mErr } = await supabase.from('group_members').insert(members);
      if (mErr) console.warn('برخی اعضا اضافه نشدند:', mErr);
    }

    await loadGroups();
    await loadChatList();
    $('createGroupModal').style.display = 'none';
    showToast('گروه ساخته شد 🎉', 'success');
    setTimeout(() => selectGroup(group.id), 400);
  } catch (e) {
    showToast('خطا: ' + e.message, 'error');
  } finally {
    btn.disabled = false;
    btn.textContent = 'ساخت گروه';
  }
}

async function selectGroup(groupId) {
  const group = allGroups.find(g => g.id === groupId);
  if (!group) return;

  currentGroup = group;
  currentConversation = null;
  currentOtherUser = null;
  currentChatType = 'group';
  clearAttachment();
  replyTo = null;
  cancelEdit();

  $('chatName').textContent = group.name;
  $('chatStatus').textContent = 'گروه';
  $('chatStatus').classList.remove('online', 'typing');

  const av = $('chatAvatar');
  av.innerHTML = group.avatar_url ? '<img src="' + group.avatar_url + '">' : (group.avatar_emoji || '👥');
  av.style.background = group.avatar_url ? 'transparent' : 'linear-gradient(135deg, #FFB84D, #FF6B9D)';

  $('chatEmpty').style.display = 'none';
  $('chatActive').style.display = 'flex';
  $('sidebar').classList.add('hidden');
  document.body.classList.add('in-chat');

  renderChatList();
  await loadMessages();
  subscribeMessages();
  subscribeReactions();
  // بارگذاری draft
  $('messageInput').value = loadDraft();
  $('messageInput').style.height = 'auto';
  $('messageInput').style.height = Math.min($('messageInput').scrollHeight, 120) + 'px';
  updateSendButton();

  setTimeout(() => $('messageInput').focus(), 200);
}

async function subscribeGroups() {
  supabase.channel('groups-live')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'groups' }, async () => {
      await loadGroups();
      await loadChatList();
    })
    .on('postgres_changes', { event: '*', schema: 'public', table: 'group_members' }, async () => {
      await loadGroups();
      await loadChatList();
    })
    .subscribe();
}

init();
