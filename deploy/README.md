# بستهٔ استقرار تولیدی VetoApp

این بسته، API لاراول داخل `app/` را مستقل از پروژهٔ Flutter و پروژهٔ دمو build می‌کند. Dockerfile فقط پوشهٔ `app/` را به image PHP منتقل می‌کند؛ بنابراین مسیر بیرونی `VetoAppDemo` در build سرور هیچ نقشی ندارد.

## پیش‌نیاز سرور

- Docker Engine و Docker Compose Plugin
- سه hostname واقعی که رکوردهای DNS آن‌ها به IP سرور اشاره کنند: `vetoapp.net`، `www.vetoapp.net` و `api.vetoapp.net`
- باز بودن فقط پورت‌های 80 و 443 در فایروال عمومی
- یک مسیر پایدار و ترجیحاً رمزگذاری‌شده برای `BACKUP_PATH`

## راه‌اندازی نخستین

1. فایل `deploy/.env.production` را ویرایش کنید. مقدارهای `CHANGE_ME`، `APP_DOMAIN=api.vetoapp.net`، `APP_URL=https://api.vetoapp.net`، `WORDPRESS_DOMAIN=vetoapp.net`، `WORDPRESS_WWW_DOMAIN=www.vetoapp.net`، `WORDPRESS_URL=https://vetoapp.net`، `CERTBOT_EMAIL` و integration secretها باید واقعی باشند. متغیرهای WordPress را از `ورد پرس/deployment/env.wordpress.production.example` در محیط توسعه یا از `/opt/vetoapp-wordpress/deployment/env.wordpress.production.example` روی سرور به این فایل منتقل کنید. `DB_PASSWORD` باید با `MYSQL_PASSWORD` و `REDIS_PASSWORD` با `VALKEY_PASSWORD` دقیقاً یکسان باشد. credentials مربوط به WordPress نباید با MySQL یا Laravel مشترک باشند. اگر Flutter Web روی دامنه‌ای جدا اجرا می‌شود، فقط originهای دقیق آن را در `CORS_ALLOWED_ORIGINS` وارد کنید.
2. کلید برنامه را تولید کنید و مقدار خروجی را در `APP_KEY` قرار دهید:

   ```bash
   cd deploy
   docker compose --env-file .env.production -f compose.production.yaml run --rm --no-deps app php artisan key:generate --show
   ```

3. برای نصب اولیهٔ داده‌های مرجع، release را با seed اجرا کنید:

   ```bash
   bash deploy/scripts/release.sh --seed --monitoring
   ```

   در deployهای بعدی، `--seed` را فقط وقتی اجرا کنید که عمداً می‌خواهید داده‌های مرجع idempotent به‌روز شوند. `ProductionSeeder` کاربر آزمایشی `DatabaseSeeder` را وارد نمی‌کند.

4. WordPress و قالب اختصاصی را نصب کنید. این کار کاربر مدیر و صفحه‌های اولیه را فقط در database جداگانهٔ WordPress می‌سازد:

   ```bash
   bash deploy/scripts/setup-wordpress.sh
   ```

5. پس از آن‌که DNS هر سه hostname و پورت 80 در دسترس شد، گواهی TLS را بگیرید:

   ```bash
   bash deploy/scripts/init-ssl.sh
   ```

6. سلامت انتهابه‌انتها را بررسی کنید:

   ```bash
   bash deploy/scripts/healthcheck.sh
   ```

## سرویس‌ها

- `nginx`: تنها سرویس منتشرشده روی پورت‌های 80 و 443؛ `vetoapp.net` را به WordPress و `api.vetoapp.net` را به Laravel می‌فرستد. ابتدا HTTP و پس از صدور هر دو گواهی HTTPS با redirect خودکار فعال می‌شود.
- `app`: PHP-FPM زیر Supervisor.
- `queue`: Laravel queue worker زیر Supervisor؛ برای افزایش ظرفیت می‌توان آن را scale کرد.
- `scheduler`: `schedule:work` زیر Supervisor.
- `mysql` و `valkey`: فقط در شبکهٔ Docker و بدون port binding روی میزبان.
- `wordpress` و `wordpress-db`: PHP-FPM و MariaDB جداگانه برای سایت معرفی. هیچ‌کدام port binding عمومی ندارند.
- `wordpress-cli` و `wordpress-theme-sync`: ابزارهای profile `ops` برای نصب نخست و انتشار قالب؛ سرویس دائمی نیستند.
- `backup`: dump سازگار MySQL، checksum، retention و متریک آخرین موفقیت.
- `wordpress-backup`: archive جداگانهٔ database WordPress و `wp-content/uploads` با checksum و encryption اختیاری.
- profile `monitoring`: Prometheus، blackbox probe و node exporter. Prometheus فقط روی `127.0.0.1:${PROMETHEUS_PORT}` گوش می‌دهد.

## عملیات روزمره

```bash
# deploy عادی (migration خودکار، بدون seed)
bash deploy/scripts/release.sh

# افزایش workerها روی همان سرور
cd deploy
docker compose --env-file .env.production -f compose.production.yaml up -d --scale queue=2

# وضعیت و logها
docker compose --env-file .env.production -f compose.production.yaml ps
docker compose --env-file .env.production -f compose.production.yaml logs -f app queue nginx
```

## پشتیبان‌گیری و بازیابی

کانتینر backup بلافاصله پس از start و سپس با فاصلهٔ `BACKUP_INTERVAL_SECONDS` یک dump می‌سازد. `BACKUP_PATH` را روی storage پایدار، رمزگذاری‌شده و خارج از دیسک اصلی سرویس تنظیم کنید. برای رمزگذاری خود فایل dump نیز `BACKUP_ENCRYPTION_PASSPHRASE` را تنظیم کنید و آن را در secret manager نگه دارید.

WordPress نیز همین الگو را با `WORDPRESS_BACKUP_PATH`، `WORDPRESS_BACKUP_INTERVAL_SECONDS` و `WORDPRESS_BACKUP_ENCRYPTION_PASSPHRASE` دارد. archive آن شامل database و `wp-content/uploads` است، نه secrets موجود در `wp-config.php`.

برای بازیابی، ابتدا integrity فایل را بررسی و سپس در یک پنجرهٔ نگهداری import کنید. هرگز `migrate:fresh` را روی production اجرا نکنید.

```bash
sha256sum -c vetoapp-YYYYMMDDTHHMMSSZ.sql.gz.sha256
gzip -dc vetoapp-YYYYMMDDTHHMMSSZ.sql.gz | docker compose --env-file .env.production -f compose.production.yaml exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysql -u"$MYSQL_USER" "$MYSQL_DATABASE"'
```

اگر archive با passphrase رمزگذاری شده است، ابتدا آن را با همان passphrase decrypt کنید و سپس import را انجام دهید.

## تمدید SSL

اسکریپت `renew-ssl.sh` همهٔ گواهی‌های موجود (API و WordPress) را تمدید و Nginx را reload می‌کند. روی سرور، دو فایل `cfg/systemd/` را با مسیر واقعی پروژه (در نمونه `/opt/vetoapp`) در `/etc/systemd/system/` کپی کنید و timer را فعال کنید:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now vetoapp-certbot-renew.timer
```

## نکات امنیتی

- `deploy/.env.production` در Git نادیده گرفته می‌شود و نباید secret واقعی در آن commit شود.
- MySQL، MariaDB WordPress، Valkey و Prometheus را مستقیماً روی اینترنت منتشر نکنید.
- WordPress فقط به `wordpress-db`، volume خودش و قالب bundled دسترسی دارد. آن را به MySQL اصلی، Valkey، Telegram secrets یا `APP_KEY` متصل نکنید.
- `DISALLOW_FILE_EDIT` و `DISALLOW_FILE_MODS` در config تولیدی WordPress فعال‌اند؛ قالب از راه build/release به‌روزرسانی می‌شود، نه با نصب افزونه یا ویرایش فایل در پنل.
- profile مانیتورینگ برای `node-exporter` mountهای read-only از `/proc`، `/sys` و filesystem میزبان می‌گیرد؛ فقط روی سروری فعالش کنید که سیاست امنیتی آن را تأیید کرده است.
- پس از خرید سرور، image tagهای پایهٔ Compose را به digestهای تأییدشدهٔ سازمانی pin کنید.
- Alertهای Prometheus به‌صورت rule آماده‌اند؛ برای اعلان عملیاتی، Prometheus را به Alertmanager یا سرویس مانیتورینگ مورد تأییدتان متصل کنید.
