python << 'PYEOF'
from pathlib import Path
fp = Path("js/chat.js")
c = fp.read_text(encoding="utf-8")

# ═══════════════════════════════════════════
# ۱) متغیرهای جدید
# ═══════════════════════════════════════════
if 'let globalSearchFilter' not in c:
    c = c.replace(
        "let forwardedMessage = null;",
        """let forwardedMessage = null;
let globalSearchFilter = 'all';
let globalSearchResults = [];
let savedMessages = [];"""
    )
    print("✅ متغیرها اضافه شد")

# ═══════════════════════════════════════════
# ۲) در init: setupGlobalSearch و setupSaved
# ═══════════════════════════════════════════
if 'setupGlobalSearch();' not in c:
    c = c.replace(
        "  setupForward();",
        "  setupForward();\n  setupGlobalSearch();\n  setupSaved();\n  loadSavedMessages();"
    )
    print("✅ setupها به init اضافه شد")

# ═══════════════════════════════════════════
# ۳) توابع Global Search + Save
# ═══════════════════════════════════════════
search_save_code = r'''
// ═══════════════════════════════════════════
// 🔍 Global Search
// ═══════════════════════════════════════════
function setupGlobalSearch() {
  const btn = $('globalSearchClose');
  if (btn) btn.onclick = () => $('globalSearchModal').style.display = 'none';

  const modal = $('globalSearchModal');
  if (modal) modal.onclick = (e) => {
    if (e.target.id === 'globalSearchModal') modal.style.display = 'none';
  };

  const input = $('globalSearchInput');
  if (input) {
    let timer;
    input.addEventListener('input', () => {
      clearTimeout(timer);
      timer = setTimeout(() => performGlobalSearch(input.value), 350);
    });
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') modal.style.display = 'none';
    });
  }

  document.querySelectorAll('#searchFilters button').forEach(b => {
    b.onclick = () => {
      document.querySelectorAll('#searchFilters button').forEach(x => x.classList.remove('active'));
      b.classList.add('active');
      globalSearchFilter = b.dataset.filter;
      performGlobalSearch($('globalSearchInput').value);
    };
  });

  // باز کردن با Ctrl+K یا دکمه جستجو در سایدبار
  document.addEventListener('keydown', (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
      e.preventDefault();
      openGlobalSearch();
    }
  });
}

function openGlobalSearch() {
  $('globalSearchModal').style.display = 'flex';
  $('globalSearchInput').value = '';
  $('globalSearchInput').focus();
  globalSearchResults = [];
  renderGlobalResults();
}

async function performGlobalSearch(query) {
  const q = (query || '').trim();
  const results = $('globalResults');

  if (!q) {
    results.innerHTML = '<div class="empty-list" style="padding:40px 20px"><span class="emoji">🔍</span>چیزی برای جستجو بنویس</div>';
    return;
  }

  results.innerHTML = '<div class="loading-state"><div class="spinner"></div></div>';

  try {
    // جستجو در همه پیام‌های کاربر (مکالمات + گروه‌های او)
    let queryBuilder = supabase
      .from('messages')
      .select('*, conversations(user1_id, user2_id), groups(name, avatar_emoji)')
      .ilike('content', '%' + q + '%')
      .order('created_at', { ascending: false })
      .limit(100);

    const { data, error } = await queryBuilder;
    if (error) throw error;

    // فیلتر بر اساس user دسترسی
    const userConvs = new Set(chatList.filter(i => i.conversation).map(i => i.conversation.id));
    const userGroups = new Set(allGroups.map(g => g.id));

    let filtered = (data || []).filter(m => {
      if (m.conversation_id) return userConvs.has(m.conversation_id);
      if (m.group_id) return userGroups.has(m.group_id);
      return false;
    });

    // فیلتر بر اساس نوع
    if (globalSearchFilter !== 'all') {
      if (globalSearchFilter === 'link') {
        filtered = filtered.filter(m => m.content && /https?:\/\//.test(m.content));
      } else if (globalSearchFilter === 'text') {
        filtered = filtered.filter(m => m.content && !m.attachment_url);
      } else {
        filtered = filtered.filter(m => m.attachment_type === globalSearchFilter);
      }
    }

    globalSearchResults = filtered;
    renderGlobalResults(q);
  } catch (e) {
    results.innerHTML = '<div class="empty-list" style="padding:40px 20px"><span class="emoji">⚠️</span>خطا در جستجو</div>';
    console.error(e);
  }
}

function renderGlobalResults(query) {
  const results = $('globalResults');

  if (!globalSearchResults.length) {
    results.innerHTML = '<div class="empty-list" style="padding:40px 20px"><span class="emoji">🔍</span>چیزی پیدا نشد</div>';
    return;
  }

  results.innerHTML = globalSearchResults.map((m, i) => {
    // پیدا کردن منبع
    let sourceName = '?';
    let sourceColor = '#999';
    let isGroup = false;

    if (m.group_id) {
      const g = allGroups.find(x => x.id === m.group_id);
      sourceName = g?.name || 'گروه';
      sourceColor = 'linear-gradient(135deg, #FFB84D, #FF6B9D)';
      isGroup = true;
    } else if (m.conversation_id) {
      const otherId = m.conversations?.user1_id === currentUser.id
        ? m.conversations?.user2_id
        : m.conversations?.user1_id;
      const u = allUsers.find(x => x.id === otherId);
      if (u) {
        sourceName = u.display_name || u.username;
        sourceColor = avatarColor(u.id);
      }
    }

    const sender = allUsers.find(u => u.id === m.sender_id);
    const senderName = m.sender_id === currentUser.id ? 'من' : (sender?.display_name || sender?.username || '?');

    // هایلایت
    const safeText = (m.content || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const regex = new RegExp('(' + query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ')', 'gi');
    const highlighted = m.content
      ? escapeHtml(m.content).replace(regex, '<mark>$1</mark>')
      : '';

    let mediaIcon = '';
    if (m.attachment_type === 'image') mediaIcon = '<div class="global-result-media">📷 عکس</div>';
    else if (m.attachment_type === 'video') mediaIcon = '<div class="global-result-media">🎥 ویدیو</div>';
    else if (m.attachment_type === 'file') mediaIcon = '<div class="global-result-media">📄 ' + escapeHtml(m.attachment_name || 'فایل') + '</div>';
    else if (m.attachment_type === 'voice') mediaIcon = '<div class="global-result-media">🎤 پیام صوتی</div>';

    return '<div class="global-result-item" data-i="' + i + '">' +
      '<div class="global-result-head">' +
        '<div class="avatar" style="background:' + sourceColor + '">' +
          (isGroup ? (m.groups?.avatar_emoji || '👥') : getInitials(sourceName)) +
        '</div>' +
        '<div class="name">' + escapeHtml(sourceName) + ' • ' + escapeHtml(senderName) + '</div>' +
        '<div class="time">' + formatTime(m.created_at) + '</div>' +
      '</div>' +
      (highlighted ? '<div class="global-result-text">' + highlighted + '</div>' : '') +
      mediaIcon +
    '</div>';
  }).join('');

  // کلیک → برو به چت
  results.querySelectorAll('.global-result-item').forEach(el => {
    el.onclick = () => {
      const m = globalSearchResults[+el.dataset.i];
      jumpToMessage(m);
    };
  });
}

async function jumpToMessage(m) {
  $('globalSearchModal').style.display = 'none';

  if (m.group_id) {
    await selectGroup(m.group_id);
  } else if (m.conversation_id) {
    const otherId = m.conversations?.user1_id === currentUser.id
      ? m.conversations?.user2_id
      : m.conversations?.user1_id;
    await selectUser(otherId);
  }

  setTimeout(() => {
    const el = document.querySelector('[data-id="' + m.id + '"]');
    if (el) {
      el.scrollIntoView({ behavior: 'smooth', block: 'center' });
      el.classList.add('highlight');
      setTimeout(() => el.classList.remove('highlight'), 2000);
    } else {
      showToast('پیام در پیام‌های بارگذاری‌شده نبود', 'info');
    }
  }, 800);
}

// ═══════════════════════════════════════════
// 🔖 Save Message
// ═══════════════════════════════════════════
function setupSaved() {
  const btn = $('savedBtn');
  if (!btn) return;

  btn.onclick = () => {
    $('savedModal').style.display = 'flex';
    loadSavedMessages();
  };

  const closeBtn = $('savedClose');
  if (closeBtn) closeBtn.onclick = () => $('savedModal').style.display = 'none';

  const modal = $('savedModal');
  if (modal) modal.onclick = (e) => {
    if (e.target.id === 'savedModal') modal.style.display = 'none';
  };
}

async function loadSavedMessages() {
  const { data, error } = await supabase
    .from('saved_messages')
    .select('*')
    .eq('user_id', currentUser.id)
    .order('saved_at', { ascending: false });

  if (error) { console.error(error); return; }
  savedMessages = data || [];
  renderSavedMessages();
}

function renderSavedMessages() {
  const list = $('savedList');
  if (!list) return;

  if (!savedMessages.length) {
    list.innerHTML = '<div class="empty-list" style="padding:40px 20px"><span class="emoji">🔖</span>هنوز چیزی ذخیره نکرده‌ای</div>';
    return;
  }

  list.innerHTML = savedMessages.map((m, i) => {
    let mediaHtml = '';
    if (m.attachment_url) {
      if (m.attachment_type === 'image') {
        mediaHtml = '<div class="saved-item-media"><img src="' + m.attachment_url + '" loading="lazy"></div>';
      } else if (m.attachment_type === 'video') {
        mediaHtml = '<div class="saved-item-media"><video src="' + m.attachment_url + '" controls preload="metadata"></video></div>';
      } else {
        mediaHtml = '<div class="global-result-media" style="margin-top:6px">📄 ' + escapeHtml(m.attachment_name || 'فایل') + '</div>';
      }
    }

    return '<div class="saved-item">' +
      '<div class="saved-item-head">' +
        '<span class="source">از ' + escapeHtml(m.source_name || 'ناشناس') + '</span>' +
        '<span class="time">' + formatTime(m.saved_at) + '</span>' +
        '<button class="del" data-i="' + i + '" title="حذف">🗑</button>' +
      '</div>' +
      (m.content ? '<div class="saved-item-body">' + escapeHtml(m.content) + '</div>' : '') +
      mediaHtml +
    '</div>';
  }).join('');

  list.querySelectorAll('.del').forEach(b => {
    b.onclick = async () => {
      const m = savedMessages[+b.dataset.i];
      if (!confirm('حذف شود؟')) return;
      await supabase.from('saved_messages').delete().eq('id', m.id);
      await loadSavedMessages();
      showToast('حذف شد', 'success');
    };
  });
}

async function saveMessageToSaved(msg) {
  // پیدا کردن نام منبع
  let sourceName = '';
  if (currentChatType === 'group') {
    sourceName = currentGroup?.name || 'گروه';
  } else if (currentOtherUser) {
    sourceName = currentOtherUser.display_name || currentOtherUser.username;
  }

  const row = {
    user_id: currentUser.id,
    original_message_id: msg.id,
    content: msg.content || '',
    attachment_url: msg.attachment_url,
    attachment_type: msg.attachment_type,
    attachment_name: msg.attachment_name,
    attachment_size: msg.attachment_size,
    source_name: sourceName
  };

  const { error } = await supabase.from('saved_messages').insert(row);
  if (error) { showToast('خطا: ' + error.message, 'error'); return; }
  showToast('ذخیره شد 🔖', 'success');
  await loadSavedMessages();
}
'''

if 'function setupGlobalSearch' not in c:
    c = c.replace("// ═══════════════════ MISC", search_save_code + "\n// ═══════════════════ MISC")
    print("✅ توابع Global Search + Save اضافه شد")

# ═══════════════════════════════════════════
# ۴) اضافه کردن ذخیره به منوی context پیام
# ═══════════════════════════════════════════
old_menu = "    { icon: '➡️', label: 'فوروارد', action: () => openForwardModal(msg) },"
new_menu = """    { icon: '➡️', label: 'فوروارد', action: () => openForwardModal(msg) },
    { icon: '🔖', label: 'ذخیره', action: () => saveMessageToSaved(msg) },"""

if old_menu in c and 'label: \'ذخیره\'' not in c:
    c = c.replace(old_menu, new_menu)
    print("✅ Save به منو اضافه شد")

# ═══════════════════════════════════════════
# ۵) دکمه Global Search در هدر سایدبار
# ═══════════════════════════════════════════
# جستجوی سایدبار که قبلاً فقط کاربران را جستجو می‌کرد، الان دکمه Ctrl+K
# در input سایدبار، اگر Enter بزنی → global search
old_search_input = "$('searchInput').addEventListener('input', () => renderChatList());"
new_search_input = """$('searchInput').addEventListener('input', () => renderChatList());
  $('searchInput').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      const q = e.target.value.trim();
      if (q) {
        openGlobalSearch();
        setTimeout(() => {
          $('globalSearchInput').value = q;
          performGlobalSearch(q);
        }, 100);
      }
    }
  });"""

if old_search_input in c:
    c = c.replace(old_search_input, new_search_input)
    print("✅ Enter در search → Global search")

# ═══════════════════════════════════════════
# ۶) رفرش global search بعد از ارسال
# ═══════════════════════════════════════════
old_finally = """  } finally {
    updateSendButton();
  }
}"""

new_finally = """  } finally {
    updateSendButton();
    // اگر مودال جستجو باز است، نتایج را آپدیت کن
    if ($('globalSearchModal').style.display === 'flex' && $('globalSearchInput').value.trim()) {
      performGlobalSearch($('globalSearchInput').value);
    }
  }
}"""

if old_finally in c and 'performGlobalSearch($(\'globalSearchInput\').value);' not in c:
    c = c.replace(old_finally, new_finally, 1)
    print("✅ رفرش Global search بعد از ارسال")

fp.write_text(c, encoding="utf-8")
print("✅ chat.js آپدیت شد")

# چک نهایی
c2 = fp.read_text(encoding="utf-8")
print("\n📋 تعداد:")
print(f"  setupGlobalSearch: {c2.count('function setupGlobalSearch')}")
print(f"  saveMessageToSaved: {c2.count('function saveMessageToSaved')}")
print(f"  loadSavedMessages: {c2.count('function loadSavedMessages')}")
PYEOF
