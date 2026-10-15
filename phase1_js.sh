python << 'PYEOF'
from pathlib import Path
fp = Path("js/chat.js")
c = fp.read_text(encoding="utf-8")

# ═══════════════════════════════════════════
# ۱) متغیرهای جدید
# ═══════════════════════════════════════════
if 'let draftTimers' not in c:
    c = c.replace(
        "let searchIndex = 0;",
        """let searchIndex = 0;
let draftTimers = {};           // { chatId: timer }
let forwardedMessage = null;    // پیام در حال فوروارد"""
    )
    print("✅ متغیرها اضافه شد")

# ═══════════════════════════════════════════
# ۲) Draft خودکار
# ═══════════════════════════════════════════
draft_funcs = r'''
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
'''

if 'function draftKey()' not in c:
    c = c.replace("// ═══════════════════ UI BINDINGS", draft_funcs + "\n// ═══════════════════ UI BINDINGS")
    print("✅ Draft functions اضافه شد")

# ═══════════════════════════════════════════
# ۳) در setupComposer: ذخیره‌ی draft
# ═══════════════════════════════════════════
old_input = """  input.addEventListener('input', () => {
    input.style.height = 'auto';
    input.style.height = Math.min(input.scrollHeight, 120) + 'px';
    updateSendButton();
    broadcastTyping();
    toggleVoiceBtn();
  });"""

new_input = """  input.addEventListener('input', () => {
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
  });"""

if old_input in c:
    c = c.replace(old_input, new_input)
    print("✅ Draft در input اضافه شد")

# ═══════════════════════════════════════════
# ۴) در selectUser و selectGroup: بارگذاری draft
# ═══════════════════════════════════════════
old_user_focus = "  setTimeout(() => $('messageInput').focus(), 200);"
new_user_focus = """  // بارگذاری draft
  $('messageInput').value = loadDraft();
  $('messageInput').style.height = 'auto';
  $('messageInput').style.height = Math.min($('messageInput').scrollHeight, 120) + 'px';
  updateSendButton();

  setTimeout(() => $('messageInput').focus(), 200);"""

# در selectUser
if old_user_focus in c and 'بارگذاری draft' not in c:
    c = c.replace(old_user_focus, new_user_focus)
    print("✅ Draft در selectUser اضافه شد")

# در selectGroup (بعد از position خودش)
old_group_focus = "  setTimeout(() => $('messageInput').focus(), 200);\n}"
# جایگزین در selectGroup
if c.count(old_user_focus) > 1:
    # فقط یک بار اضافه شد در selectUser، دومی را برای گروه
    pass

# ═══════════════════════════════════════════
# ۵) پاک کردن draft بعد از ارسال
# ═══════════════════════════════════════════
old_clear = """    input.value = '';
    input.style.height = '40px';
    clearAttachment();
    replyTo = null;
    renderReplyPreview();
    playSendSound();
    requestNotifPermission();"""

new_clear = """    input.value = '';
    input.style.height = '40px';
    clearAttachment();
    replyTo = null;
    renderReplyPreview();
    saveDraft('');  // پاک کردن draft
    playSendSound();
    requestNotifPermission();"""

if old_clear in c:
    c = c.replace(old_clear, new_clear)
    print("✅ پاک کردن draft بعد از ارسال اضافه شد")

# ═══════════════════════════════════════════
# ۶) نمایش draft در لیست چت
# ═══════════════════════════════════════════
old_preview = """    let preview = 'شروع گفتگو...';
    let time = '';
    let tick = '';

    if (item.lastMessage) {"""

new_preview = """    let preview = 'شروع گفتگو...';
    let time = '';
    let tick = '';
    let isDraft = false;

    // چک draft
    const draftText = hasDraft(item.kind === 'group' ? item.group.id : item.conversation?.id, item.kind);
    if (draftText) {
      preview = draftText;
      isDraft = true;
    } else if (item.lastMessage) {"""

if old_preview in c:
    c = c.replace(old_preview, new_preview)
    print("✅ preview draft اضافه شد")

# اضافه کردن کلاس draft
old_preview_class = "const previewClass = item.unread > 0 ? 'preview unread' : 'preview';"
new_preview_class = "const previewClass = isDraft ? 'preview draft' : (item.unread > 0 ? 'preview unread' : 'preview');"

if old_preview_class in c:
    c = c.replace(old_preview_class, new_preview_class)
    print("✅ preview class آپدیت شد")

# ═══════════════════════════════════════════
# ۷) Big Emoji
# ═══════════════════════════════════════════
big_emoji_func = r'''
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
'''

if 'function isBigEmoji' not in c:
    c = c.replace("function renderMessage(msg, prevMsg)", big_emoji_func + "\nfunction renderMessage(msg, prevMsg)")
    print("✅ isBigEmoji اضافه شد")

# اعمال در renderMessage
old_div_class = """  const div = document.createElement('div');
  div.className = 'message ' + (isMine ? 'mine' : 'theirs');
  div.dataset.id = msg.id;"""

new_div_class = """  const div = document.createElement('div');
  div.className = 'message ' + (isMine ? 'mine' : 'theirs');
  if (msg.content && isBigEmoji(msg.content) && !msg.attachment_url) {
    div.classList.add('big-emoji');
  }
  div.dataset.id = msg.id;"""

if old_div_class in c:
    c = c.replace(old_div_class, new_div_class)
    print("✅ Big emoji در renderMessage اضافه شد")

# ═══════════════════════════════════════════
# ۸) Forward
# ═══════════════════════════════════════════
forward_funcs = r'''
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
'''

if 'async function doForward' not in c:
    c = c.replace("// ═══════════════════ MISC", forward_funcs + "\n// ═══════════════════ MISC")
    print("✅ Forward functions اضافه شد")

# ═══════════════════════════════════════════
# ۹) در showMessageMenu: تغییر فوروارد واقعی
# ═══════════════════════════════════════════
old_forward_menu = "{ icon: '➡️', label: 'فوروارد', action: () => showToast('به‌زودی') },"
new_forward_menu = "{ icon: '➡️', label: 'فوروارد', action: () => openForwardModal(msg) },"

if old_forward_menu in c:
    c = c.replace(old_forward_menu, new_forward_menu)
    print("✅ Forward menu آپدیت شد")

# ═══════════════════════════════════════════
# ۱۰) نمایش forwarded badge در پیام
# ═══════════════════════════════════════════
old_text_html = "const textHtml = msg.content ? '<span class=\"msg-text\">' + escapeHtml(msg.content) + '</span>' : '';"
new_text_html = """const forwardedHtml = msg.forwarded_from
    ? '<div class="forwarded-badge">➡️ فوروارد شده از ' + escapeHtml(msg.forwarded_from_name || 'کاربر') + '</div>'
    : '';
  const textHtml = msg.content ? '<span class="msg-text">' + escapeHtml(msg.content) + '</span>' : '';"""

if old_text_html in c:
    c = c.replace(old_text_html, new_text_html)
    print("✅ Forwarded badge اضافه شد")

# درج در HTML پیام
old_inner = "'<div class=\"bubble\">' + senderNameHtml + replyHtml + attachHtml + textHtml +"
new_inner = "'<div class=\"bubble\">' + senderNameHtml + forwardedHtml + replyHtml + attachHtml + textHtml +"

if old_inner in c:
    c = c.replace(old_inner, new_inner)
    print("✅ درج forwarded در bubble")

# ═══════════════════════════════════════════
# ۱۱) Mute در context menu
# ═══════════════════════════════════════════
old_chat_menu = """  $('chatMenuBtn').onclick = (e) => {
    showMenu(e, [
      { icon: '🔍', label: 'جستجو', action: () => toggleSearchBar(true) },
      { icon: '📌', label: 'پیام‌های پین', action: () => pinnedMsg && scrollToMessage(pinnedMsg.id) },
      { icon: '🗑', label: 'حذف گفتگو', action: () => showToast('به‌زودی'), danger: true }
    ]);
  };"""

new_chat_menu = """  $('chatMenuBtn').onclick = (e) => {
    const isMuted = currentChatType === 'group'
      ? currentGroup?.muted
      : currentConversation?.muted;
    showMenu(e, [
      { icon: '🔍', label: 'جستجو', action: () => toggleSearchBar(true) },
      { icon: '📌', label: 'پیام‌های پین', action: () => pinnedMsg && scrollToMessage(pinnedMsg.id) },
      { icon: '🔕', label: isMuted ? 'صدادار کردن' : 'بی‌صدا کردن', action: toggleMute },
      { icon: '🗑', label: 'حذف گفتگو', action: () => showToast('به‌زودی'), danger: true }
    ]);
  };"""

if old_chat_menu in c:
    c = c.replace(old_chat_menu, new_chat_menu)
    print("✅ Mute در منو اضافه شد")

# ═══════════════════════════════════════════
# ۱۲) تابع toggleMute
# ═══════════════════════════════════════════
mute_func = r'''
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
'''

if 'async function toggleMute' not in c:
    c = c.replace("// ═══════════════════ MISC", mute_func + "\n// ═══════════════════ MISC")
    print("✅ toggleMute اضافه شد")

# ═══════════════════════════════════════════
# ۱۳) نمایش Mute icon در لیست
# ═══════════════════════════════════════════
old_meta = """'<div class="meta"><span>' + time + '</span></div>' +"""
new_meta = """'<div class="meta">' +
            ((isGroup ? item.group.muted : item.conversation?.muted) ? '<span class="mute-icon">🔕</span>' : '') +
            '<span>' + time + '</span>' +
          '</div>' +"""

if old_meta in c:
    c = c.replace(old_meta, new_meta)
    print("✅ Mute icon در لیست اضافه شد")

# ═══════════════════════════════════════════
# ۱۴) در init: setup فوروارد
# ═══════════════════════════════════════════
old_setup = "  setupGroups();"
new_setup = """  setupGroups();
  setupForward();
  renderChatList();"""

if 'setupForward()' not in c:
    c = c.replace(old_setup, new_setup)
    print("✅ setupForward به init اضافه شد")

# تابع setupForward
setup_forward = r'''
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
'''

if 'function setupForward' not in c:
    c = c.replace("function setupGroups()", setup_forward + "\nfunction setupGroups()")
    print("✅ setupForward اضافه شد")

# ═══════════════════════════════════════════
# ۱۵) در selectUser و selectGroup: نمایش mute در لیست
# ═══════════════════════════════════════════
# این خودکار با renderChatList کار می‌کند

# ═══════════════════════════════════════════
# ۱۶) در selectGroup: بارگذاری draft
# ═══════════════════════════════════════════
if 'currentGroup = group;\n  currentConversation = null;' in c:
    # اضافه کردن load draft
    old_selgroup = "  renderChatList();\n  await loadMessages();\n  subscribeMessages();\n  subscribeReactions();\n  setTimeout(() => $('messageInput').focus(), 200);\n}"
    new_selgroup = """  renderChatList();
  await loadMessages();
  subscribeMessages();
  subscribeReactions();

  // بارگذاری draft
  $('messageInput').value = loadDraft();
  $('messageInput').style.height = 'auto';
  $('messageInput').style.height = Math.min($('messageInput').scrollHeight, 120) + 'px';
  updateSendButton();

  setTimeout(() => $('messageInput').focus(), 200);
}"""

    if old_selgroup in c:
        c = c.replace(old_selgroup, new_selgroup)
        print("✅ Draft در selectGroup اضافه شد")

fp.write_text(c, encoding="utf-8")
print("")
print("✅ JS فاز ۱ گام ۱ اعمال شد")
PYEOF
