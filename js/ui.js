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
