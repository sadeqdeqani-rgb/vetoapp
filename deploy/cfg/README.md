# CFG

این پوشه تنظیمات عملیاتیِ جدا از کد برنامه را نگه می‌دارد:

- `prometheus/`: پیکربندی health probe، متریک host و هشدار پشتیبان‌گیری.
- `systemd/`: نمونهٔ timer امن برای تمدید TLS بدون دادن Docker socket به Certbot.

فایل‌های این پوشه secret ندارند. همهٔ secretها فقط در `deploy/.env.production` قرار می‌گیرند.
