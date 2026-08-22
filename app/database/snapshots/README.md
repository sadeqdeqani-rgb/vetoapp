# Reference database snapshot

این Snapshot فقط داده‌ها و ساختار جداول مرجع Seedشده را نگهداری می‌کند:

- جغرافیا: کشور، استان، شهرستان و Settlement
- Lookupها
- Policyهای جغرافیایی، بستن حساب و امنیت

جداول کاربران، OTP، Telegram، Session، Webhook، Cache و Queue عمداً در آن قرار ندارند.

برای بازیابی در یک دیتابیس محلی خالی:

```bash
gzip -dc app/database/snapshots/vetoapp_reference_seeded_2026-08-22.sql.gz \
  | docker exec -i vetoapp-mysql \
      mysql -u vetoapp -p vetoapp_local
```

این فایل شامل رمز عبور، Token، شماره موبایل یا اطلاعات شخصی نیست. رمز عبور باید به‌صورت تعاملی وارد شود و هرگز داخل Git ذخیره نشود.
