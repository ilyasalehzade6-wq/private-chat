python << 'PYEOF'
from pathlib import Path
fp = Path("js/chat.js")
c = fp.read_text(encoding="utf-8")

# ─── ۱) متغیرهای جدید ───
if 'currentGroup' not in c:
    c = c.replace(
        "let currentConversation = null;",
        """let currentConversation = null;
let currentGroup = null;
let allGroups = [];
let currentChatType = 'private';  // 'private' | 'group'"""
    )
    print("✅ متغیرها اضافه شد")

# ─── ۲) تابع loadGroups ───
if 'async function loadGroups' not in c:
    loadgroups_fn = r'''
async function loadGroups() {
  const { data, error } = await supabase
    .from('group_members')
    .select('group_id, groups(*)')
    .eq('user_id', currentUser.id);
  if (error) { console.warn(error); return; }
  allGroups = (data || []).map(m => m.groups).filter(Boolean);
}

'''
    c = c.replace("async function loadChatList()", loadgroups_fn + "async function loadChatList()")
    print("✅ loadGroups اضافه شد")

# ─── ۳) در init: صدا زدن loadGroups ───
if 'await loadGroups();' not in c:
    c = c.replace(
        "  await loadAllUsers();\n  await loadChatList();",
        "  await loadAllUsers();\n  await loadGroups();\n  await loadChatList();"
    )
    print("✅ loadGroups به init اضافه شد")

# ─── ۴) بازنویسی loadChatList برای شامل شدن گروه‌ها ───
old_load = c[c.find("async function loadChatList()"):]
old_load = old_load[:old_load.find("\nfunction renderChatList")]

new_load = '''async function loadChatList() {
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

'''

c = c.replace(old_load, new_load)
print("✅ loadChatList بازنویسی شد")

# ─── ۵) بازنویسی renderChatList ───
old_render = c[c.find("function renderChatList()"):]
old_render = old_render[:old_render.find("\nfunction updateUnreadTabBadge")]

new_render = '''function renderChatList() {
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

    if (item.lastMessage) {
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

    const previewClass = item.unread > 0 ? 'preview unread' : 'preview';
    const dataId = isGroup ? 'group:' + item.group.id : 'user:' + item.otherUser.id;

    return '<div class="chat-item ' + extraClass + ' ' + active + '" data-id="' + dataId + '">' +
      '<div class="avatar" style="background:' + avStyle + '">' + avHtml + onlineDot + unreadBadge + '</div>' +
      '<div class="body">' +
        '<div class="row1">' +
          '<div class="name">' + escapeHtml(name) + '</div>' +
          '<div class="meta"><span>' + time + '</span></div>' +
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

'''

c = c.replace(old_render, new_render)
print("✅ renderChatList بازنویسی شد")

# ─── ۶) در init: راه‌اندازی گروه ───
if 'setupGroups();' not in c:
    c = c.replace(
        "  setupSearch();",
        "  setupSearch();\n  setupGroups();\n  subscribeGroups();"
    )
    print("✅ setupGroups به init اضافه شد")

# ─── ۷) اضافه کردن توابع گروه قبل از init(); ───
if 'async function selectGroup' not in c:
    group_funcs = r'''
// ═══════════════════════════════════════════
// 👥 گروه چت
// ═══════════════════════════════════════════
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
    const { data: group, error: gErr } = await supabase
      .from('groups')
      .insert({ name, avatar_emoji: emoji, created_by: currentUser.id })
      .select()
      .single();
    if (gErr) throw gErr;

    const members = [
      { group_id: group.id, user_id: currentUser.id, role: 'admin' },
      ...selected.map(uid => ({ group_id: group.id, user_id: uid, role: 'member' }))
    ];
    const { error: mErr } = await supabase.from('group_members').insert(members);
    if (mErr) throw mErr;

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

'''
    c = c.replace("init();", group_funcs + "init();")
    print("✅ توابع گروه اضافه شد")

# ─── ۸) بازنویسی loadMessages برای پشتیبانی از گروه ───
old_lm_start = c.find("async function loadMessages()")
old_lm_end = c.find("\nfunction renderAllMessages")
if old_lm_start > 0 and old_lm_end > 0:
    old_lm = c[old_lm_start:old_lm_end]
    new_lm = '''async function loadMessages() {
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
'''
    c = c.replace(old_lm, new_lm)
    print("✅ loadMessages بازنویسی شد")

# ─── ۹) بازنویسی subscribeMessages ───
old_sm_start = c.find("function subscribeMessages()")
old_sm_end = c.find("\nfunction subscribeAllMessages")
if old_sm_start > 0 and old_sm_end > 0:
    old_sm = c[old_sm_start:old_sm_end]
    new_sm = '''function subscribeMessages() {
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
'''
    c = c.replace(old_sm, new_sm)
    print("✅ subscribeMessages بازنویسی شد")

# ─── ۱۰) sendMessage: شامل group_id ───
old_send = """    const row = {
      conversation_id: currentConversation.id,
      sender_id: currentUser.id,
      content: content || ''
    };"""
new_send = """    const row = {
      sender_id: currentUser.id,
      content: content || ''
    };
    if (currentChatType === 'group') row.group_id = currentGroup.id;
    else row.conversation_id = currentConversation.id;"""

if old_send in c:
    c = c.replace(old_send, new_send)
    print("✅ sendMessage آپدیت شد")

# ─── ۱۱) شرط sendMessage: currentChatType ───
old_cond = "if ((!content && !pendingAttachment) || !currentConversation) return;"
new_cond = "if ((!content && !pendingAttachment)) return;\n  if (currentChatType === 'group' && !currentGroup) return;\n  if (currentChatType === 'private' && !currentConversation) return;"
if old_cond in c:
    c = c.replace(old_cond, new_cond)
    print("✅ شرط send آپدیت شد")

# ─── ۱۲) uploadAttachment: مسیر برای گروه ───
old_path = "const path = currentUser.id + '/' + currentConversation.id + '/' + ts + '-' + safeName;"
new_path = """const ctxId = currentChatType === 'group' ? currentGroup.id : currentConversation.id;
  const path = currentUser.id + '/' + ctxId + '/' + ts + '-' + safeName;"""
if old_path in c:
    c = c.replace(old_path, new_path)
    print("✅ uploadAttachment آپدیت شد")

# ─── ۱۳) renderMessage: نمایش نام فرستنده در گروه ───
old_sender = """  const isMine = msg.sender_id === currentUser.id;
  const sender = isMine ? currentProfile : currentOtherUser;
  const name = sender?.display_name || sender?.username || '?';

  const div = document.createElement('div');"""
new_sender = """  const isMine = msg.sender_id === currentUser.id;
  const isGroup = currentChatType === 'group';
  let sender = isMine ? currentProfile : currentOtherUser;
  if (isGroup && !isMine) {
    sender = allUsers.find(u => u.id === msg.sender_id) || { username: 'کاربر' };
  }
  const name = sender?.display_name || sender?.username || '?';

  const div = document.createElement('div');"""
if old_sender in c:
    c = c.replace(old_sender, new_sender)
    print("✅ renderMessage (sender) آپدیت شد")

# اضافه کردن نام فرستنده در HTML پیام
old_html_start = "  div.innerHTML =\n    '<div class=\"bubble\">' + replyHtml + attachHtml + textHtml +"
new_html_start = """  const senderNameHtml = (isGroup && !isMine)
    ? '<div class="sender-name">' + escapeHtml(name) + '</div>'
    : '';

  div.innerHTML =
    '<div class="bubble">' + senderNameHtml + replyHtml + attachHtml + textHtml +"""
if old_html_start in c:
    c = c.replace(old_html_start, new_html_start)
    print("✅ renderMessage (HTML) آپدیت شد")

# ─── ۱۴) markAsRead: پشتیبانی از گروه ───
old_mar = c[c.find("async function markAsRead()"):]
old_mar = old_mar[:old_mar.find("\nfunction broadcastTyping")]

new_mar = '''async function markAsRead() {
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

'''
c = c.replace(old_mar, new_mar)
print("✅ markAsRead آپدیت شد")

# ─── ۱۵) updateChatStatus: پشتیبانی گروه ───
old_ucs = c[c.find("function updateChatStatus()"):]
old_ucs = old_ucs[:old_ucs.find("\n// ═══════════════════ MESSAGES")]

new_ucs = '''function updateChatStatus() {
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

'''
c = c.replace(old_ucs, new_ucs)
print("✅ updateChatStatus آپدیت شد")

# ─── ۱۶) در selectUser: currentChatType رو private کن ───
if "currentChatType = 'private';" not in c.split("async function selectUser")[1][:500]:
    c = c.replace(
        "  currentOtherUser = other;\n  clearAttachment();",
        "  currentOtherUser = other;\n  currentGroup = null;\n  currentChatType = 'private';\n  clearAttachment();"
    )
    print("✅ selectUser آپدیت شد")

# ─── ۱۷) subscribeAllMessages: پیش‌نمایش گروه ───
old_sub = c.find("function subscribeAllMessages()")
if old_sub > 0:
    old_sub_end = c.find("\nfunction subscribeReactions")
    old_sub_block = c[old_sub:old_sub_end]
    # فقط loadChatList رو صدا بزن (بدون کد اضافه)
    if "msg.group_id" not in old_sub_block:
        old_sub_block_new = old_sub_block.replace(
            "      await loadChatList();",
            "      await loadChatList();\n      // msg.group_id یا conversation_id"
        )
        c = c.replace(old_sub_block, old_sub_block_new)
        print("✅ subscribeAllMessages آپدیت شد")

# ─── ۱۸) در broadcastTyping: پشتیبانی از گروه ───
old_bt = c[c.find("function broadcastTyping()"):]
old_bt = old_bt[:old_bt.find("\n// ═══════════════════ INIT")] if "// ═══════════════════ INIT" in old_bt else old_bt[:old_bt.find("\n\nfunction")]

new_bt = '''function broadcastTyping() {
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

'''
c = c.replace(old_bt, new_bt)
print("✅ broadcastTyping آپدیت شد")

fp.write_text(c, encoding="utf-8")
print("")
print("✅ chat.js آپدیت کامل شد")

PYEOF
