#!/bin/bash
# ═══════════════════════════════════════════════════════
#  🔧 تنظیم خودکار js/config.js
# ═══════════════════════════════════════════════════════

FP="js/config.js"
BAK="${FP}.bak_$(date +%Y%m%d_%H%M%S)"
cp "$FP" "$BAK"
echo "📦 بکاپ: $BAK"

cat > "$FP" << 'CFG_EOF'
// js/config.js
// ⚠️ این فایل شامل کلید عمومی Supabase است — برای مرورگر امن است
// کلید secret را هرگز اینجا نگذار

export const SUPABASE_URL = 'https://mxvdumsoywlghcnqniju.supabase.co';
export const SUPABASE_ANON_KEY = 'sb_publishable_HBtQd23wzFoHHv9UHrmrfg_a9LDd4fM';

export const APP_NAME = 'پیام‌رسان خصوصی';
CFG_EOF

echo ""
echo "✅ config.js به‌روز شد"
echo ""
echo "📋 محتوای جدید:"
echo "═══════════════════════════════════════════════════════"
cat "$FP"
echo "═══════════════════════════════════════════════════════"

# پاک کردن بکاپ‌های قدیمی (بیشتر از ۳ تا نگه نداریم)
ls -t js/config.js.bak_* 2>/dev/null | tail -n +4 | xargs -r rm
