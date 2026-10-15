python << 'PYEOF'
from pathlib import Path
fp = Path("js/chat.js")
c = fp.read_text(encoding="utf-8")

# پیدا کردن تابع subscribeReactions و بازنویسی
start = c.find("function subscribeReactions()")
if start < 0:
    print("❌ تابع پیدا نشد")
else:
    # پیدا کردن انتهای تابع (اولین \n}\n بعد از start)
    depth = 0
    i = start
    started = False
    while i < len(c):
        if c[i] == '{':
            depth += 1
            started = True
        elif c[i] == '}':
            depth -= 1
            if started and depth == 0:
                end = i + 1
                break
        i += 1

    old_fn = c[start:end]

    new_fn = '''function subscribeReactions() {
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
}'''

    c = c.replace(old_fn, new_fn)
    fp.write_text(c, encoding="utf-8")
    print("✅ subscribeReactions فیکس شد")

PYEOF
