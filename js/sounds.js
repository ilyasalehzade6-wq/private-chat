// js/sounds.js — صداهای پیام
let _audioCtx = null;
function _getAudioCtx() {
  if (!_audioCtx) {
    try { _audioCtx = new (window.AudioContext || window.webkitAudioContext)(); } catch(e) { return null; }
  }
  return _audioCtx;
}

export function playMsgSound() {
  const ctx = _getAudioCtx();
  if (!ctx) return;
  try {
    const o = ctx.createOscillator();
    const g = ctx.createGain();
    o.connect(g); g.connect(ctx.destination);
    o.frequency.setValueAtTime(880, ctx.currentTime);
    o.frequency.setValueAtTime(660, ctx.currentTime + 0.08);
    g.gain.setValueAtTime(0.12, ctx.currentTime);
    g.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.25);
    o.start(ctx.currentTime);
    o.stop(ctx.currentTime + 0.25);
  } catch (e) {}
}

export function playSendSound() {
  const ctx = _getAudioCtx();
  if (!ctx) return;
  try {
    const o = ctx.createOscillator();
    const g = ctx.createGain();
    o.connect(g); g.connect(ctx.destination);
    o.frequency.setValueAtTime(440, ctx.currentTime);
    o.frequency.setValueAtTime(880, ctx.currentTime + 0.08);
    g.gain.setValueAtTime(0.06, ctx.currentTime);
    g.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.18);
    o.start(ctx.currentTime);
    o.stop(ctx.currentTime + 0.18);
  } catch (e) {}
}
