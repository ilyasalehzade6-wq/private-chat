python << 'PYEOF'
from pathlib import Path
fp = Path("js/chat.js")
c = fp.read_text(encoding="utf-8")

# ۱) متغیرها
if 'let currentWallpaper' not in c:
    c = c.replace(
        "let savedMessages = [];",
        """let savedMessages = [];
let currentWallpaper = null;
const LINK_REGEX = /(https?:\\/\\/[^\\s<>]+)/gi;"""
    )
    print("✅ متغیرها اضافه شد")

# ۲) setupWallpaper به init
if 'setupWallpaper();' not in c:
    c = c.replace(
        "  setupSaved();",
        "  setupSaved();\n  setupWallpaper();"
    )
    print("✅ setupWallpaper به init اضافه شد")

# ۳) در showMessageMenu: گزینه Wallpaper
old_menu = "      { icon: '🔕', label: isMuted ? 'صدادار کردن' : 'بی‌صدا کردن', action: toggleMute },"
new_menu = """      { icon: '🔕', label: isMuted ? 'صدادار کردن' : 'بی‌صدا کردن', action: toggleMute },
      { icon: '🎨', label: 'والپیپر', action: openWallpaperModal },"""

if old_menu in c and 'openWallpaperModal' not in c:
    c = c.replace(old_menu, new_menu)
    print("✅ Wallpaper به منو اضافه شد")

# ۴) توابع Wallpaper + Link Preview
wallpaper_code = r'''
// ═══════════════════════════════════════════
// 🎨 Wallpaper
// ═══════════════════════════════════════════
const WP_COLORS = [
  '#EFE7DE', '#F0F2F5', '#E8F4F8', '#FEF3E2', '#F5E6E8',
  '#E0F2E9', '#F3E8FF', '#FFE4E1', '#1E293B', '#0F172A',
  '#111827', '#1F2937', '#374151', '#7C3AED', '#0891B2'
];

const WP_GRADIENTS = [
  'linear-gradient(135deg, #667EEA, #764BA2)',
  'linear-gradient(135deg, #F093FB, #F5576C)',
  'linear-gradient(135deg, #4FACFE, #00F2FE)',
  'linear-gradient(135deg, #43E97B, #38F9D7)',
  'linear-gradient(135deg, #FA709A, #FEE140)',
  'linear-gradient(135deg, #30CFD0, #330867)',
  'linear-gradient(135deg, #A8EDEA, #FED6E3)',
  'linear-gradient(135deg, #FF9A9E, #FECFEF)',
  'linear-gradient(135deg, #FBC2EB, #A6C1EE)',
  'linear-gradient(135deg, #0F2027, #203A43, #2C5364)'
];

const WP_PATTERNS = [
  'radial-gradient(circle, rgba(123,79,224,.08) 1px, transparent 1px)',
  'repeating-linear-gradient(45deg, rgba(123,79,224,.05), rgba(123,79,224,.05) 10px, transparent 10px, transparent 20px)',
  'repeating-linear-gradient(-45deg, rgba(0,212,168,.05), rgba(0,212,168,.05) 10px, transparent 10px, transparent 20px)',
  'linear-gradient(90deg, rgba(255,184,77,.05) 50%, transparent 50%)',
  'radial-gradient(circle at 25% 25%, rgba(123,79,224,.08), transparent 50%)'
];

const WP_PATTERN_SIZES = ['20px 20px', 'auto', 'auto', '20px 20px', 'auto'];

function setupWallpaper() {
  const closeBtn = $('wallpaperClose');
  if (closeBtn) closeBtn.onclick = () => $('wallpaperModal').style.display = 'none';

  const modal = $('wallpaperModal');
  if (modal) modal.onclick = (e) => {
    if (e.target.id === 'wallpaperModal') modal.style.display = 'none';
  };

  const resetBtn = $('wallpaperReset');
  if (resetBtn) resetBtn.onclick = () => setWallpaper(null);

  const upload = $('wallpaperUpload');
  if (upload) upload.onchange = async (e) => {
    const f = e.target.files[0];
    if (f) await uploadWallpaper(f);
    e.target.value = '';
  };

  renderWallpaperGrids();
}

function renderWallpaperGrids() {
  const colorGrid = $('wpColorGrid');
  const gradGrid = $('wpGradientGrid');
  const patternGrid = $('wpPatternGrid');
  if (!colorGrid || !gradGrid || !patternGrid) return;

  colorGrid.innerHTML = WP_COLORS.map((c, i) =>
    '<div class="wp-item" data-type="color" data-val="' + c + '" style="background:' + c + '"></div>'
  ).join('');

  gradGrid.innerHTML = WP_GRADIENTS.map((g, i) =>
    '<div class="wp-item" data-type="gradient" data-val="' + i + '" style="background:' + g + '"></div>'
  ).join('');

  patternGrid.innerHTML = WP_PATTERNS.map((p, i) =>
    '<div class="wp-item" data-type="pattern" data-val="' + i + '" style="background:' + p + '; background-size:' + WP_PATTERN_SIZES[i] + '; background-color: var(--bg-chat)"></div>'
  ).join('');

  [colorGrid, gradGrid, patternGrid].forEach(grid => {
    grid.querySelectorAll('.wp-item').forEach(el => {
      el.onclick = () => {
        const type = el.dataset.type;
        const val = el.dataset.val;
        let wp;
        if (type === 'color') wp = 'color:' + val;
        else if (type === 'gradient') wp = 'gradient:' + val;
        else if (type === 'pattern') wp = 'pattern:' + val;
        setWallpaper(wp);
      };
    });
  });

  highlightCurrentWallpaper();
}

function highlightCurrentWallpaper() {
  document.querySelectorAll('.wp-item').forEach(el => el.classList.remove('active'));
  if (!currentWallpaper) return;
  const [type, val] = currentWallpaper.split(':');
  document.querySelectorAll('.wp-item').forEach(el => {
    if (el.dataset.type === type && el.dataset.val === val) el.classList.add('active');
  });
}

function openWallpaperModal() {
  $('wallpaperModal').style.display = 'flex';
  highlightCurrentWallpaper();
}

function applyWallpaper(wp) {
  const area = $('messagesArea');
  if (!area) return;

  if (!wp) {
    area.classList.remove('has-wallpaper');
    area.style.background = '';
    area.style.backgroundImage = '';
    area.style.backgroundSize = '';
    return;
  }

  const [type, val] = wp.split(':');
  if (type === 'color') {
    area.classList.add('has-wallpaper');
    area.style.background = val;
    area.style.backgroundImage = 'none';
  } else if (type === 'gradient') {
    area.classList.add('has-wallpaper');
    area.style.background = WP_GRADIENTS[+val];
    area.style.backgroundImage = WP_GRADIENTS[+val];
  } else if (type === 'pattern') {
    area.classList.add('has-wallpaper');
    area.style.background = 'var(--bg-chat)';
    area.style.backgroundImage = WP_PATTERNS[+val];
    area.style.backgroundSize = WP_PATTERN_SIZES[+val];
  } else if (type === 'image') {
    area.classList.add('has-wallpaper');
    area.style.background = 'var(--bg-chat)';
    area.style.backgroundImage = 'url("' + val + '")';
    area.style.backgroundSize = 'cover';
    area.style.backgroundPosition = 'center';
  }
}

async function setWallpaper(wp) {
  currentWallpaper = wp;
  applyWallpaper(wp);
  highlightCurrentWallpaper();

  try {
    if (currentChatType === 'group' && currentGroup) {
      await supabase.from('groups').update({ wallpaper: wp }).eq('id', currentGroup.id);
      currentGroup.wallpaper = wp;
    } else if (currentConversation) {
      await supabase.from('conversations').update({ wallpaper: wp }).eq('id', currentConversation.id);
      currentConversation.wallpaper = wp;
    }
    showToast('والپیپر ذخیره شد', 'success');
  } catch (e) {
    showToast('خطا: ' + e.message, 'error');
  }
}

async function uploadWallpaper(file) {
  try {
    const ts = Date.now();
    const safe = file.name.replace(/[^a-zA-Z0-9._-]/g, '_');
    const path = currentUser.id + '/' + ts + '-' + safe;
    const { error } = await supabase.storage.from('wallpapers').upload(path, file, {
      cacheControl: '3600', contentType: file.type
    });
    if (error) throw error;
    const { data: pub } = supabase.storage.from('wallpapers').getPublicUrl(path);
    await setWallpaper('image:' + pub.publicUrl);
  } catch (e) {
    showToast('خطا: ' + e.message, 'error');
  }
}

// ═══════════════════════════════════════════
// 🔗 Link Preview
// ═══════════════════════════════════════════
function extractFirstUrl(text) {
  if (!text) return null;
  const match = text.match(LINK_REGEX);
  return match ? match[0] : null;
}

async function fetchLinkMetadata(url) {
  try {
    // استفاده از سرویس Microlink (رایگان، بدون API key)
    const resp = await fetch('https://api.microlink.io/?url=' + encodeURIComponent(url));
    if (!resp.ok) return null;
    const json = await resp.json();
    if (json.status !== 'success') return null;
    const d = json.data || {};
    return {
      title: d.title || '',
      description: d.description || '',
      image: d.image?.url || d.logo?.url || '',
      url: url
    };
  } catch (e) {
    return null;
  }
}

function renderLinkPreviewHtml(msg) {
  if (!msg.link_url) return '';
  const hasImage = msg.link_image;
  const hasTitle = msg.link_title;
  const hasDesc = msg.link_description;
  if (!hasImage && !hasTitle && !hasDesc) return '';

  let host = '';
  try { host = new URL(msg.link_url).hostname.replace(/^www\./, ''); } catch {}

  return '<a class="link-preview" href="' + escapeHtml(msg.link_url) + '" target="_blank" rel="noopener">' +
    (hasImage ? '<img class="link-preview-image" src="' + escapeHtml(msg.link_image) + '" loading="lazy" onerror="this.style.display=\'none\'">' : '') +
    '<div class="link-preview-body">' +
      (hasTitle ? '<div class="link-preview-title">' + escapeHtml(msg.link_title) + '</div>' : '') +
      (hasDesc ? '<div class="link-preview-desc">' + escapeHtml(msg.link_description) + '</div>' : '') +
      (host ? '<div class="link-preview-host">' + escapeHtml(host) + '</div>' : '') +
    '</div>' +
  '</a>';
}

// تبدیل لینک‌های متن به قابل کلیک
function linkifyText(text) {
  const escaped = escapeHtml(text);
  return escaped.replace(LINK_REGEX, (url) => {
    return '<a href="' + url + '" target="_blank" rel="noopener">' + url + '</a>';
  });
}
'''

if 'function setupWallpaper' not in c:
    c = c.replace("// ═══════════════════ MISC", wallpaper_code + "\n// ═══════════════════ MISC")
    print("✅ توابع Wallpaper + Link Preview اضافه شد")

# ۵) در selectUser: بارگذاری wallpaper
if 'applyWallpaper(currentConversation?.wallpaper' not in c:
    old_focus = "  setTimeout(() => $('messageInput').focus(), 200);"
    new_focus = """  // بارگذاری wallpaper
  currentWallpaper = currentConversation?.wallpaper || null;
  applyWallpaper(currentWallpaper);

  setTimeout(() => $('messageInput').focus(), 200);"""
    # برای selectUser (اولین occurrence)
    if old_focus in c:
        c = c.replace(old_focus, new_focus, 1)
        print("✅ Wallpaper در selectUser اضافه شد")

# در selectGroup
if 'applyWallpaper(currentGroup?.wallpaper' not in c:
    old_focus2 = "  setTimeout(() => $('messageInput').focus(), 200);"
    new_focus2 = """  // بارگذاری wallpaper
  currentWallpaper = currentGroup?.wallpaper || null;
  applyWallpaper(currentWallpaper);

  setTimeout(() => $('messageInput').focus(), 200);"""
    if old_focus2 in c:
        c = c.replace(old_focus2, new_focus2, 1)
        print("✅ Wallpaper در selectGroup اضافه شد")

# ۶) در sendMessage: استخراج link preview
if 'extractFirstUrl(content)' not in c:
    old_row = """    if (currentChatType === 'group') row.group_id = currentGroup.id;
    else row.conversation_id = currentConversation.id;"""
    new_row = """    if (currentChatType === 'group') row.group_id = currentGroup.id;
    else row.conversation_id = currentConversation.id;

    // استخراج لینک
    if (content) {
      const url = extractFirstUrl(content);
      if (url) {
        row.link_url = url;
        // fetch metadata به صورت غیرمسدودکننده
        fetchLinkMetadata(url).then(meta => {
          if (meta) {
            supabase.from('messages')
              .update({
                link_title: meta.title,
                link_description: meta.description,
                link_image: meta.image
              })
              .eq('id', insertedId)
              .then(() => {});
          }
        }).catch(() => {});
      }
    }"""

    if old_row in c:
        c = c.replace(old_row, new_row)
        print("✅ Link extraction در sendMessage اضافه شد")

# ۷) در renderMessage: نمایش link preview
if 'renderLinkPreviewHtml(msg)' not in c:
    old_bubble = "'<div class=\"bubble\">' + senderNameHtml + forwardedHtml + replyHtml + attachHtml + textHtml +"
    new_bubble = "'<div class=\"bubble\">' + senderNameHtml + forwardedHtml + replyHtml + attachHtml + renderLinkPreviewHtml(msg) + textHtml +"

    if old_bubble in c:
        c = c.replace(old_bubble, new_bubble)
        print("✅ Link preview در bubble اضافه شد")

# لینکیفای متن پیام
if 'linkifyText(msg.content)' not in c:
    old_text = "const textHtml = msg.content ? '<span class=\"msg-text\">' + escapeHtml(msg.content) + '</span>' : '';"
    new_text = "const textHtml = msg.content ? '<span class=\"msg-text\">' + linkifyText(msg.content) + '</span>' : '';"
    if old_text in c:
        c = c.replace(old_text, new_text)
        print("✅ linkify متن اضافه شد")

fp.write_text(c, encoding="utf-8")
print("✅ chat.js آپدیت شد")

# چک
c2 = fp.read_text(encoding="utf-8")
print("\n📋 تعداد:")
print(f"  setupWallpaper: {c2.count('function setupWallpaper')}")
print(f"  extractFirstUrl: {c2.count('function extractFirstUrl')}")
print(f"  fetchLinkMetadata: {c2.count('function fetchLinkMetadata')}")
PYEOF
