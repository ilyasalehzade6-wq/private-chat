# 💬 پیام‌رسان خصوصی

پیام‌رسان ساده و امن برای چت خصوصی با Supabase.

## قابلیت‌ها
- ثبت‌نام و ورود با ایمیل
- چت لحظه‌ای
- نشانگر آنلاین
- در حال تایپ
- حالت تاریک/روشن
- ریسپانسیو

## راه‌اندازی
1. در Supabase برو به SQL Editor و محتوای `supabase-setup.sql` را اجرا کن
2. در Authentication → Providers → Email گزینه Confirm email را خاموش کن
3. از Settings → API Keys مقدار URL و anon key را در `js/config.js` بگذار
4. با `python -m http.server 8000` اجرا کن
