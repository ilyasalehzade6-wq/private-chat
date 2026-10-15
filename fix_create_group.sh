python << 'PYEOF'
from pathlib import Path
fp = Path("js/chat.js")
c = fp.read_text(encoding="utf-8")

old = '''  try {
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
'''

new = '''  try {
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
'''

if old in c:
    c = c.replace(old, new)
    fp.write_text(c, encoding="utf-8")
    print("✅ createGroup دو مرحله‌ای شد")
else:
    print("⚠️ الگو پیدا نشد — بررسی دستی")
PYEOF
