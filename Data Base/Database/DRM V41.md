# VetoApp Data Requirements Model — DRM V40

## 0. هدف و محدوده

این نسخه، مدل DRM V37 را برای پشته فنی زیر بازنویسی می‌کند:

- PHP 8.3
- Laravel
- MySQL 8.0 / InnoDB
- Redis برای Cache، Rate Limit، Queue و قفل‌های توزیع‌شده
- Telegram Bot API به‌عنوان تنها کانال ارسال OTP

این سند، Data Requirements Model است و جایگزین Migration، Policy و Service Contract
لاراول نیست. قواعدی که به زمان جاری، چند جدول، وضعیت بیرونی، ارسال پیام، صف یا
فرآیند چندمرحله‌ای وابسته‌اند، در Laravel Service/Job/Transaction اجرا می‌شوند.

## 1. قواعد عمومی MySQL

### 1.1 موتور، charset و زمان

- تمام جدول‌ها باید `ENGINE=InnoDB` باشند.
- charset پایگاه داده و جدول‌ها `utf8mb4` و collation پیشنهادی
  `utf8mb4_0900_ai_ci` است.
- همه زمان‌ها در UTC ذخیره می‌شوند.
- نوع زمانی استاندارد `DATETIME(0)` است؛ برای دقت ثانیه از `DATETIME` نیز می‌توان
  استفاده کرد.
- مقدارهای خودکار از `CURRENT_TIMESTAMP` استفاده می‌کنند؛
  `CURRENT_DATETIME` در MySQL معتبر نیست.
- timezone اتصال Laravel باید UTC باشد.

### 1.2 انواع داده

- شناسه‌های داخلی: `BIGINT UNSIGNED` مگر آنکه اندازه موجودیت کوچک باشد.
- شناسه‌های جغرافیایی: `SMALLINT UNSIGNED`.
- Boolean: `TINYINT(1)`.
- UUID باینری: `BINARY(16)`.
- HMAC-SHA-256 و SHA-256: `BINARY(32)`.
- امضای Ed25519: `BINARY(64)`.
- داده رمز‌شده: `VARBINARY(255)` یا `BLOB` بر اساس اندازه.
- داده ساختاریافته ممیزی: `JSON`.
- IP: `VARCHAR(45)`.

### 1.3 قواعد کلید خارجی

تمام Foreign Keyها باید صریحاً این رفتار را داشته باشند:

```sql
ON DELETE RESTRICT ON UPDATE RESTRICT
```

استفاده از `CASCADE`، `SET NULL` و `ON UPDATE CASCADE` ممنوع است، مگر در نسخه
آتی برای یک مورد استثنایی مستند تصویب شود.

### 1.4 قواعدی که عمداً در Laravel اجرا می‌شوند

موارد زیر در سطح Database CHECK زمانی قرار نمی‌گیرند:

- مقایسه با `NOW()` یا `CURRENT_TIMESTAMP`
- انقضای OTP، Draft، Session و Cooldown
- پنجره ۱۵ دقیقه‌ای، TTL دو دقیقه‌ای و فاصله ۶۰ ثانیه‌ای OTP
- محاسبه مدت قفل تصاعدی
- ترتیب انتقال Stateها
- هماهنگی چند جدول در یک فرآیند کسب‌وکار
- بررسی سلسله‌مراتب جغرافیایی
- تک‌بودن رکورد پیش‌فرض
- immutable بودن رکوردها

Laravel باید این قواعد را در Service، Form Request، Policy، Job و Transaction
اجرا کند. Database همچنان قیود پایدار مانند PK، FK، UNIQUE، NOT NULL و برخی
محدودیت‌های ثابت عددی/مقداری را enforce می‌کند.

### 1.5 ایندکس شرطی در MySQL

MySQL ایندکس Partial به شکل `WHERE ...` ندارد. برای enforce کردن uniqueness
شرطی از Stored Generated Column استفاده می‌شود:

```sql
active_user_id BIGINT UNSIGNED
    GENERATED ALWAYS AS (
        CASE WHEN is_active = 1 THEN user_id ELSE NULL END
    ) STORED,
UNIQUE KEY uq_active_user_id (active_user_id)
```

در MySQL، چند مقدار `NULL` در Unique Index مجاز است؛ بنابراین فقط رکوردهای
فعال محدود می‌شوند.

### 1.6 الگوی Laravel

- تمام تغییرات حساس با `DB::transaction()` انجام شوند.
- برای جلوگیری از Race Condition از `lockForUpdate()` استفاده شود.
- برای عملیات توزیع‌شده از Redis lock استفاده شود.
- برای ارسال Telegram از Queue استفاده شود.
- Jobهای ارسال باید idempotent باشند.
- OTP خام، رمز عبور، token و داده حساس در log ثبت نشود.
- عملیات expire/reconcile توسط Scheduler لاراول انجام شود.

## 2. system_admins

### تعریف

هویت جداگانه مدیر سیستم برای مدیریت داده‌های مرجع، پیکربندی و تأیید انتقال‌های
سیستمی. این هویت با user_profiles و user_accounts مشترک نیست.

### ستون‌ها

| ستون | نوع | Null | مقدار پیش‌فرض | توضیح |
|---|---|---:|---|---|
| admin_id | TINYINT UNSIGNED | خیر | — | PK خودافزا |
| admin_uuid | BINARY(16) | خیر | — | UUID غیرقابل تغییر |
| username | VARCHAR(50) | خیر | — | شناسه یکتا |
| password_hash | VARCHAR(255) | خیر | — | Argon2id یا Bcrypt |
| public_key_pem | TEXT | خیر | — | کلید عمومی تأیید امضا |
| is_active | TINYINT(1) | خیر | 1 | وضعیت فعال |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP | UTC |
| updated_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP | UTC |

### قیود و ایندکس‌ها

- `PRIMARY KEY (admin_id)`
- `UNIQUE KEY uq_system_admin_uuid (admin_uuid)`
- `UNIQUE KEY uq_system_admin_username (username)`
- تغییر `is_active` باید در admin_activity_logs ثبت شود.
- حذف فیزیکی ممنوع است.

## 3. admin_activity_logs

دفتر حسابرسی append-only برای تغییرات مدیریتی.

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| log_id | BIGINT UNSIGNED | خیر | PK خودافزا |
| admin_id | TINYINT UNSIGNED | خیر | FK به system_admins |
| action_name | VARCHAR(100) | خیر | نوع عملیات |
| target_table | VARCHAR(64) | خیر | جدول هدف |
| target_id | VARCHAR(128) | بله | شناسه هدف |
| payload_before | JSON | بله | Snapshot قبل |
| payload_after | JSON | بله | Snapshot بعد |
| digital_signature | BINARY(64) | بله | امضای مدیریتی |
| client_ip | VARCHAR(45) | خیر | IP |
| user_agent | VARCHAR(512) | بله | User-Agent |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |

ایندکس‌ها:

- `PRIMARY KEY (log_id)`
- `KEY idx_admin_activity_admin_created (admin_id, created_at)`
- `KEY idx_admin_activity_action_created (action_name, created_at)`
- `KEY idx_admin_activity_target (target_table, target_id)`

Laravel و دسترسی DB باید UPDATE/DELETE این جدول را برای نقش عملیاتی مسدود کنند.

## 4. داده‌های جغرافیایی

### 4.1 countries

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| country_id | SMALLINT UNSIGNED | خیر | PK خودافزا |
| country_code | SMALLINT UNSIGNED | خیر | کد یکتا |
| name_fa | VARCHAR(100) | خیر | نام فارسی |
| is_active | TINYINT(1) | خیر | پیش‌فرض 1 |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |
| updated_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP ON UPDATE |

`PRIMARY KEY (country_id)`, `UNIQUE KEY uq_country_code (country_code)`,
`KEY idx_country_active (is_active)`.

### 4.2 provinces

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| province_id | SMALLINT UNSIGNED | خیر | PK |
| country_id | SMALLINT UNSIGNED | خیر | FK به countries |
| province_code | SMALLINT UNSIGNED | خیر | کد یکتا |
| name_fa | VARCHAR(100) | خیر | نام فارسی |
| is_active | TINYINT(1) | خیر | پیش‌فرض 1 |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |
| updated_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP ON UPDATE |

`UNIQUE KEY uq_province_code (province_code)`,
`KEY idx_province_country_active (country_id, is_active)`.

### 4.3 counties

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| county_id | SMALLINT UNSIGNED | خیر | PK |
| province_id | SMALLINT UNSIGNED | خیر | FK به provinces |
| county_code | SMALLINT UNSIGNED | خیر | کد یکتا |
| name_fa | VARCHAR(100) | خیر | نام فارسی |
| is_active | TINYINT(1) | خیر | پیش‌فرض 1 |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |
| updated_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP ON UPDATE |

`UNIQUE KEY uq_county_code (county_code)`,
`KEY idx_county_province_active (province_id, is_active)`.

### 4.4 settlements

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| settlement_id | SMALLINT UNSIGNED | خیر | PK |
| county_id | SMALLINT UNSIGNED | خیر | FK به counties |
| settlement_code | SMALLINT UNSIGNED | خیر | کد یکتا |
| name_fa | VARCHAR(100) | خیر | نام فارسی |
| is_active | TINYINT(1) | خیر | پیش‌فرض 1 |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |
| updated_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP ON UPDATE |

`UNIQUE KEY uq_settlement_code (settlement_code)`,
`KEY idx_settlement_county_active (county_id, is_active)`.

تمام FKهای جغرافیایی `RESTRICT/RESTRICT` هستند. فعال‌بودن مؤثر هر رکورد با
بررسی ancestorها در Laravel محاسبه می‌شود و در ستون جداگانه ذخیره نمی‌شود.

### 4.5 geographic_level_lookups

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| geographic_level_code | TINYINT UNSIGNED | خیر | PK |
| geographic_level_title | VARCHAR(100) | خیر | عنوان |
| hierarchy_rank | TINYINT UNSIGNED | خیر | رتبه سلسله‌مراتب |
| lock_order | TINYINT UNSIGNED | خیر | ترتیب قفل |
| is_active | TINYINT(1) | خیر | وضعیت |
| created_at | DATETIME(0) | خیر | زمان ایجاد |
| updated_at | DATETIME(0) | خیر | زمان تغییر |

ایندکس: `UNIQUE KEY uq_geo_level_hierarchy_rank (hierarchy_rank)`.

Seed:

| code | title | hierarchy_rank | lock_order |
|---:|---|---:|---:|
| 1 | countries | 1 | 4 |
| 2 | provinces | 2 | 3 |
| 3 | counties | 3 | 2 |
| 4 | settlements | 4 | 1 |

## 5. otps

### تعریف

OTP کوتاه‌عمر فقط برای ثبت‌نام اولیه و بازیابی رمز عبور است. OTP برای Login یا
MFA استفاده نمی‌شود؛ ورود عادی با سازوکارهای احراز هویت تعریف‌شده در
`user_accounts` و `auth_sessions` انجام می‌شود. OTP خام
هرگز ذخیره نمی‌شود.
شماره موبایل قبل از استفاده به E.164 نرمال و سپس HMAC و رمز می‌شود.

### ستون‌ها

| ستون | نوع | Null | پیش‌فرض | توضیح |
|---|---|---:|---|---|
| otp_id | BIGINT UNSIGNED | خیر | AUTO_INCREMENT | PK |
| mobile_hash | BINARY(32) | خیر | — | HMAC شماره نرمال‌شده |
| mobile_encrypted | VARBINARY(255) | خیر | — | AES-256-GCM |
| purpose | VARCHAR(25) | خیر | — | FK به otp_purpose_lookup |
| otp_nonce | BINARY(16) | خیر | — | Nonce تصادفی |
| code_hash | BINARY(32) | خیر | — | HMAC کد و context |
| state | VARCHAR(15) | خیر | Issued | FK به otp_state_lookup |
| issued_at | DATETIME(0) | خیر | — | UTC |
| expires_at | DATETIME(0) | خیر | — | UTC؛ برابر issued_at + 2 دقیقه |
| verified_at | DATETIME(0) | بله | NULL | UTC |
| failed_at | DATETIME(0) | بله | NULL | UTC |
| attempt_count | TINYINT UNSIGNED | خیر | 0 | تعداد تلاش |
| max_attempt_count | TINYINT UNSIGNED | خیر | 3 | سقف تلاش |
| delivery_channel | VARCHAR(20) | خیر | telegram_bot | کانال ارسال |
| registration_draft_id | BIGINT UNSIGNED | بله | NULL | FK در registration |
| user_id | BIGINT UNSIGNED | بله | NULL | FK فقط در password_reset |
| otp_throttle_window_id | BIGINT UNSIGNED | خیر | — | FK به پنجره محدودیت |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP | UTC |
| updated_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP ON UPDATE | UTC |

### مقادیر Lookup

`otp_state_lookup`:

- Issued
- Verified
- Expired
- Failed

`otp_purpose_lookup`:

- registration
- password_reset

`delivery_channel`:

- telegram_bot

### Hash کد

```text
code_hash = HMAC-SHA256(
    otp_code || purpose || mobile_hash || otp_nonce,
    OTP_SERVER_SECRET
)
```

### قیود پایدار

- `PRIMARY KEY (otp_id)`
- FKها با `RESTRICT/RESTRICT`
- `CHECK (attempt_count <= max_attempt_count)`
- `CHECK (max_attempt_count > 0)`
- `CHECK (expires_at IS NOT NULL)`
- `CHECK (delivery_channel = 'telegram_bot')`
- `KEY idx_otp_mobile_purpose_state (mobile_hash, purpose, state)`
- `KEY idx_otp_registration_draft (registration_draft_id)`
- `KEY idx_otp_user (user_id)`
- `KEY idx_otp_throttle_window (otp_throttle_window_id)`
- `KEY idx_otp_expiry_state (state, expires_at)`

TTL دقیق دو دقیقه، فعال‌بودن فقط یک OTP، مقایسه با زمان جاری و تغییر State در Laravel
و Transaction انجام می‌شوند. برای جلوگیری از تکرار، هنگام صدور OTP قبلی با
`lockForUpdate()` منقضی و سپس رکورد جدید ایجاد می‌شود.

## 6. otp_throttle_windows

پنجره مستقل کنترل سوءاستفاده برای هر `mobile_hash`.

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| otp_throttle_window_id | BIGINT UNSIGNED | خیر | PK |
| mobile_hash | BINARY(32) | خیر | HMAC موبایل |
| mobile_encrypted | VARBINARY(255) | خیر | AES-256-GCM |
| window_started_at | DATETIME(0) | خیر | UTC |
| window_ends_at | DATETIME(0) | خیر | UTC |
| send_count | TINYINT UNSIGNED | خیر | پیش‌فرض 0 |
| verify_failed_count | TINYINT UNSIGNED | خیر | پیش‌فرض 0 |
| state | VARCHAR(15) | خیر | FK |
| penalty_tier | TINYINT UNSIGNED | خیر | پیش‌فرض 0 |
| last_sent_at | DATETIME(0) | بله | NULL |
| throttled_until | DATETIME(0) | بله | NULL |
| blocked_until | DATETIME(0) | بله | NULL |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |
| updated_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP ON UPDATE |

Lookup حالت‌ها:

- Open
- Throttled
- Blocked
- Expired

قیود:

- `PRIMARY KEY (otp_throttle_window_id)`
- `KEY idx_otp_throttle_mobile_state (mobile_hash, state)`
- `KEY idx_otp_throttle_until (throttled_until, blocked_until)`
- `KEY idx_otp_throttle_window_end (window_ends_at)`
- `CHECK (send_count >= 0)`
- `CHECK (verify_failed_count >= 0)`

مقادیر ۱۵ دقیقه، ۳ ارسال، ۶۰ ثانیه فاصله، ۵ خطا و penalty tier در Laravel
و Redis/Transaction اعمال می‌شوند. تغییر پنجره به Blocked و Failed کردن OTPهای
فعال باید در یک Transaction انجام شود.

## 7. integration_inbox_entries

دفتر ورودی immutable برای Telegram Webhook و رویدادهای سیستمی.

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| inbox_entry_id | BIGINT UNSIGNED | خیر | PK |
| channel | VARCHAR(32) | خیر | telegram/system |
| external_message_id | VARCHAR(64) | بله | شناسه بیرونی |
| correlation_hash | BINARY(32) | بله | شناسه تطبیق غیرقابل برگشت |
| payload | JSON | خیر | Payload خام؛ حذف فیزیکی پس از 7 روز |
| processed_status | VARCHAR(20) | خیر | Pending/Processed/Failed/Ignored |
| received_at | DATETIME(0) | خیر | زمان دریافت |
| processed_at | DATETIME(0) | بله | زمان پردازش |
| created_at | DATETIME(0) | خیر | زمان ایجاد |
| updated_at | DATETIME(0) | خیر | زمان تغییر وضعیت |

ایندکس‌ها:

- `PRIMARY KEY (inbox_entry_id)`
- `UNIQUE KEY uq_inbox_channel_external_id (channel, external_message_id)`
- `KEY idx_inbox_correlation_status (correlation_hash, processed_status)`
- `KEY idx_inbox_status_received (processed_status, received_at)`

فقط `processed_status`, `processed_at` و در صورت نیاز `updated_at` تغییرپذیر
هستند. مقدار `payload` حداکثر ۷ روز نگهداری و سپس به‌صورت فیزیکی حذف می‌شود.
Metadata رکورد، شامل کانال، شناسه پیام، وضعیت پردازش و زمان دریافت، برای
حسابرسی باقی می‌ماند. Laravel Scheduler باید Job حذف فیزیکی Payloadهای منقضی
را اجرا کند.

## 8. national_id_area_eligibilities

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| national_id_prefix_3 | SMALLINT UNSIGNED | خیر | PK |
| first_range_from | SMALLINT UNSIGNED | خیر | ابتدای محدوده اول |
| first_range_to | SMALLINT UNSIGNED | خیر | انتهای محدوده اول |
| second_range_from | SMALLINT UNSIGNED | خیر | ابتدای محدوده دوم |
| second_range_to | SMALLINT UNSIGNED | خیر | انتهای محدوده دوم |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |
| updated_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP ON UPDATE |

قیود پایدار:

- `PRIMARY KEY (national_id_prefix_3)`
- `CHECK (first_range_from <= first_range_to)`
- `CHECK (second_range_from <= second_range_to)`
- `CHECK (first_range_to <= 999)`
- `CHECK (second_range_to <= 999)`

بررسی صلاحیت در Laravel انجام می‌شود.

## 9. registration_drafts

### Lookupها

`registration_draft_state_lookup`:

- Initiated
- Completed
- Expired

`registration_draft_step_lookup`:

- Mobile_Verification
- National_ID_Verification
- Geographic_Selection
- Password_Selection
- Biometric_Setup
- Final_Review

`Biometric_Setup` بخشی از مسیر احراز هویت سامانه است. محدودیت این نسخه فقط این
است که OTP تلگرام در Login استفاده نمی‌شود.

فقط یک State و Step به‌عنوان default مجاز است؛ این قاعده با seed migration و
Service مدیریت می‌شود و به trigger وابسته نیست.

### ستون‌های registration_drafts

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| registration_draft_id | BIGINT UNSIGNED | خیر | PK |
| state_code | VARCHAR(15) | خیر | FK |
| step_code | VARCHAR(30) | خیر | FK |
| idempotency_key | VARCHAR(80) | خیر | یکتا |
| mobile_hash | BINARY(32) | خیر | HMAC موبایل |
| mobile_encrypted | VARBINARY(255) | بله | AES-256-GCM |
| national_id_hash | BINARY(32) | بله | HMAC شناسه |
| national_id_encrypted | VARBINARY(255) | بله | رمز‌شده |
| key_version | SMALLINT UNSIGNED | بله | نسخه کلید |
| settlement_id | SMALLINT UNSIGNED | بله | FK به settlements |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |
| updated_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP ON UPDATE |
| expires_at | DATETIME(0) | خیر | زمان انقضا |
| completed_at | DATETIME(0) | بله | زمان تکمیل |
| active_mobile_hash | BINARY(32) GENERATED ALWAYS AS (CASE WHEN state_code = 'Initiated' THEN mobile_hash ELSE NULL END) STORED | بله | uniqueness شرطی |
| active_national_id_hash | BINARY(32) GENERATED ALWAYS AS (CASE WHEN state_code = 'Initiated' AND step_code <> 'Mobile_Verification' THEN national_id_hash ELSE NULL END) STORED | بله | uniqueness شرطی |

ایندکس‌ها:

- `PRIMARY KEY (registration_draft_id)`
- `UNIQUE KEY uq_registration_draft_idempotency (idempotency_key)`
- `UNIQUE KEY uq_registration_draft_active_mobile (active_mobile_hash)`
- `UNIQUE KEY uq_registration_draft_active_national_id (active_national_id_hash)`
- `KEY idx_registration_draft_state_expiry (state_code, expires_at)`
- `KEY idx_registration_draft_mobile_hash (mobile_hash)`
- `KEY idx_registration_draft_settlement (settlement_id)`

قواعد زمانی، ترتیب Step، اجباری‌شدن National ID/settlements، completion و
cryptographic erasure در Laravel Transaction اجرا می‌شوند.

## 10. user_profiles

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| user_id | BIGINT UNSIGNED | خیر | PK و FK مشترک با user_accounts |
| mobile_hash | BINARY(32) | بله | یکتا، در closure تهی می‌شود |
| mobile_encrypted | VARBINARY(255) | بله | AES-256-GCM |
| national_id_hash | BINARY(32) | بله | یکتا |
| national_id_encrypted | VARBINARY(255) | بله | AES-256-GCM |
| settlement_id | SMALLINT UNSIGNED | خیر | FK |
| county_id | SMALLINT UNSIGNED | خیر | FK denormalized |
| province_id | SMALLINT UNSIGNED | خیر | FK denormalized |
| country_id | SMALLINT UNSIGNED | خیر | FK denormalized |
| is_active | TINYINT(1) | خیر | پیش‌فرض 1 |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |
| geo_updated_at | DATETIME(0) | خیر | توسط Service |
| initial_geo_selected_at | DATETIME(0) | خیر | زمان ثبت اولیه |

ایندکس‌ها:

- `PRIMARY KEY (user_id)`
- `UNIQUE KEY uq_user_profile_mobile_hash (mobile_hash)`
- `UNIQUE KEY uq_user_profile_national_id_hash (national_id_hash)`
- `KEY idx_user_profile_country_province_county (country_id, province_id, county_id)`
- `KEY idx_user_profile_settlement_active (settlement_id, is_active)`

فعال‌بودن هویت، سازگاری parentهای جغرافیایی، invalidation Session و closure
در یک Transaction لاراول انجام می‌شوند.

## 11. user_geo_change_logs

دفتر immutable تغییر جغرافیایی.

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| geo_change_log_id | BIGINT UNSIGNED | خیر | PK |
| user_id | BIGINT UNSIGNED | خیر | FK |
| old_settlement_id | SMALLINT UNSIGNED | خیر | FK |
| new_settlement_id | SMALLINT UNSIGNED | خیر | FK |
| old_county_id | SMALLINT UNSIGNED | خیر | FK |
| new_county_id | SMALLINT UNSIGNED | خیر | FK |
| old_province_id | SMALLINT UNSIGNED | خیر | FK |
| new_province_id | SMALLINT UNSIGNED | خیر | FK |
| old_country_id | SMALLINT UNSIGNED | خیر | FK |
| new_country_id | SMALLINT UNSIGNED | خیر | FK |
| change_source | VARCHAR(20) | خیر | User/Admin/System |
| policy_id | SMALLINT UNSIGNED | بله | FK |
| bypass_reason | VARCHAR(255) | بله | دلیل bypass |
| changed_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |

ایندکس‌ها:

- `PRIMARY KEY (geo_change_log_id)`
- `KEY idx_geo_change_user_changed (user_id, changed_at)`
- `KEY idx_geo_change_new_geo (new_country_id, new_province_id, new_county_id, new_settlement_id)`

No-op، cooldown، bypass و append-only بودن با Laravel/DB privileges مدیریت
می‌شوند.

## 12. geo_cooldown_policies

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| policy_id | SMALLINT UNSIGNED | خیر | PK |
| policy_code | VARCHAR(50) | خیر | یکتا |
| policy_name | VARCHAR(150) | خیر | نام |
| description | VARCHAR(500) | بله | توضیح |
| policy_stage | TINYINT UNSIGNED | خیر | مرحله 1 تا 4 |
| max_changes_allowed | TINYINT UNSIGNED | بله | در این مدل استفاده نمی‌شود |
| window_days | SMALLINT UNSIGNED | بله | در این مدل استفاده نمی‌شود |
| cooldown_days | SMALLINT UNSIGNED | خیر | مثبت |
| is_active | TINYINT(1) | خیر | وضعیت |
| effective_from | DATETIME(0) | خیر | شروع |
| effective_to | DATETIME(0) | بله | پایان |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |
| updated_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP ON UPDATE |

`PRIMARY KEY (policy_id)`, `KEY idx_geo_policy_code (policy_code)`,
`UNIQUE KEY uq_geo_policy_code_stage (policy_code, policy_stage)`,
`KEY idx_geo_policy_active_effective (is_active, effective_from, effective_to)`.

فقط یک خانواده Policy فعال در هر زمان با Policy Activation Service و Transaction
انتخاب می‌شود؛ چهار ردیف Stage همان خانواده می‌توانند هم‌زمان فعال باشند.
uniqueness چندبازه‌ای زمانی در MySQL به‌صورت مستقیم enforce نمی‌شود.

## 13. national_id_cooldown_ledgers

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| national_id_hash | BINARY(32) | خیر | PK |
| closure_count | TINYINT UNSIGNED | خیر | پیش‌فرض 1 |
| policy_id | SMALLINT UNSIGNED | خیر | FK |
| cooldown_hours | INT UNSIGNED | خیر | مقدار snapshot |
| cooldown_until | DATETIME(0) | خیر | زمان پایان |
| last_closed_at | DATETIME(0) | خیر | زمان آخرین closure |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |
| updated_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP ON UPDATE |

ایندکس‌ها:

- `PRIMARY KEY (national_id_hash)`
- `KEY idx_national_cooldown_until (cooldown_until)`
- `KEY idx_national_cooldown_policy (policy_id)`

محاسبه cooldown و بررسی زمان فقط در Laravel انجام می‌شود.

## 14. account_closure_penalty_policies

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| policy_id | SMALLINT UNSIGNED | خیر | PK |
| policy_family_code | VARCHAR(50) | خیر | خانواده |
| policy_code | VARCHAR(50) | خیر | کد خانواده Policy |
| policy_name | VARCHAR(150) | خیر | نام |
| description | VARCHAR(500) | بله | توضیح |
| penalty_stage | TINYINT UNSIGNED | خیر | مرحله |
| penalty_hours | INT UNSIGNED | خیر | مثبت |
| trigger_scope | VARCHAR(50) | خیر | account_closure |
| is_active | TINYINT(1) | خیر | وضعیت |
| effective_from | DATETIME(0) | خیر | شروع |
| effective_to | DATETIME(0) | بله | پایان |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |
| updated_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP ON UPDATE |

ایندکس‌ها:

- `PRIMARY KEY (policy_id)`
- `KEY idx_closure_policy_code (policy_code)`
- `UNIQUE KEY uq_closure_policy_family_code_stage (policy_family_code, policy_code, penalty_stage)`
- `KEY idx_closure_policy_active_effective (is_active, effective_from, effective_to)`

## 15. active_user_counters

چهار جدول زیر ساختار یکسان دارند:

- country_active_user_counters
- province_active_user_counters
- county_active_user_counters
- settlement_active_user_counters

### ساختار

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| `<level>_id` | SMALLINT UNSIGNED | خیر | PK و FK مشترک |
| active_user_count | BIGINT UNSIGNED | خیر | پیش‌فرض 0 |
| updated_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP ON UPDATE |

هر جدول یک `PRIMARY KEY` روی شناسه سطح و یک FK با `RESTRICT/RESTRICT` دارد.

قوانین افزایش/کاهش شمارنده با Update اتمیک و شرط عدم منفی‌شدن انجام می‌شوند:

```sql
UPDATE settlement_active_user_counters
SET active_user_count = active_user_count - :amount
WHERE settlement_id = :id
  AND active_user_count >= :amount;
```

ایندکس اضافی روی `active_user_count` فقط در صورتی ایجاد شود که Query واقعی
به sort/filter روی آن نیاز داشته باشد؛ PK برای lookup سطح کافی است.

## 16. user_accounts

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| user_id | BIGINT UNSIGNED | خیر | PK و FK به user_profiles |
| password_hash | VARCHAR(255) | بله | Argon2id |
| account_status | VARCHAR(15) | خیر | Active/Locked/Closed |
| mfa_required | TINYINT(1) | خیر | پیش‌فرض 0 |
| failed_login_count | TINYINT UNSIGNED | خیر | پیش‌فرض 0 |
| lockout_count | INT UNSIGNED | خیر | پیش‌فرض 0 |
| last_failed_login_at | DATETIME(0) | بله | NULL |
| last_locked_at | DATETIME(0) | بله | NULL |
| locked_until | DATETIME(0) | بله | NULL |
| password_reset_completed_at | DATETIME(0) | بله | NULL |
| password_changed_at | DATETIME(0) | بله | NULL |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |
| updated_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP ON UPDATE |

ایندکس: `KEY idx_user_account_status_lock (account_status, locked_until)`.

مقادیر status با Lookup table یا Laravel Enum کنترل شوند. آزادشدن Lock و
محاسبه زمان آن در Laravel انجام می‌شود.

## 17. security_policies

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| policy_id | TINYINT UNSIGNED | خیر | PK |
| is_active | TINYINT(1) | خیر | پیش‌فرض 0 |
| active_marker | TINYINT GENERATED ALWAYS AS (CASE WHEN is_active = 1 THEN 1 ELSE NULL END) STORED | بله | uniqueness فعال |
| max_failed_attempts | TINYINT UNSIGNED | خیر | پیش‌فرض 5 |
| base_lockout_seconds | INT UNSIGNED | خیر | پیش‌فرض 900 |
| progressive_factor | DECIMAL(3,1) | خیر | پیش‌فرض 2.0 |
| max_lockout_seconds | INT UNSIGNED | خیر | پیش‌فرض 86400 |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |
| updated_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP ON UPDATE |

ایندکس‌ها:

- `PRIMARY KEY (policy_id)`
- `UNIQUE KEY uq_security_policy_active (active_marker)`
- `CHECK (max_failed_attempts > 0)`
- `CHECK (base_lockout_seconds > 0)`
- `CHECK (progressive_factor >= 1.0)`
- `CHECK (max_lockout_seconds >= base_lockout_seconds)`

فعال‌سازی Policy با Transaction انجام می‌شود تا همواره فقط یک رکورد فعال باشد.

## 18. user_login_audit_logs

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| log_id | BIGINT UNSIGNED | خیر | PK |
| user_id | BIGINT UNSIGNED | خیر | FK به user_accounts |
| attempted_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |
| login_status | VARCHAR(15) | خیر | Success/Failed |
| failure_reason | VARCHAR(50) | بله | دلیل شکست |
| ip_address | VARCHAR(45) | خیر | IP |
| user_agent | VARCHAR(512) | خیر | User-Agent |

قیود:

- `PRIMARY KEY (log_id)`
- `CHECK (login_status IN ('Success', 'Failed'))`
- `CHECK ((login_status = 'Success' AND failure_reason IS NULL) OR (login_status = 'Failed' AND failure_reason IS NOT NULL))`
- `KEY idx_login_audit_user_time (user_id, attempted_at)`
- `KEY idx_login_audit_ip_time (ip_address, attempted_at)`

رکورد append-only است و دسترسی UPDATE/DELETE باید در سطح کاربر DB محدود شود.

## 19. user_biometric_credentials

این جدول بخشی از مدل احراز هویت سامانه است. با این حال OTP تلگرام به این
جدول یا به جریان Login متصل نیست و فقط در ثبت‌نام اولیه و فراموشی رمز عبور
استفاده می‌شود.

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| biometric_credential_id | BIGINT UNSIGNED | خیر | PK |
| user_id | BIGINT UNSIGNED | خیر | FK |
| credential_id | VARBINARY(255) | بله | Unique |
| device_identifier | VARCHAR(128) | بله | شناسه دستگاه |
| device_model | VARCHAR(100) | بله | مدل |
| aaguid | BINARY(16) | بله | AAGUID |
| public_key | BLOB | بله | کلید عمومی |
| public_key_sha256 | BINARY(32) | بله | Hash |
| key_algorithm | VARCHAR(15) | بله | ES256/RS256/Ed25519 |
| is_active | TINYINT(1) | خیر | پیش‌فرض 0 |
| is_default | TINYINT(1) | خیر | پیش‌فرض 0 |
| sign_count | INT UNSIGNED | خیر | پیش‌فرض 0 |
| active_user_id | BIGINT UNSIGNED GENERATED ALWAYS AS (CASE WHEN is_active = 1 THEN user_id ELSE NULL END) STORED | بله | uniqueness فعال |
| default_user_id | BIGINT UNSIGNED GENERATED ALWAYS AS (CASE WHEN is_default = 1 THEN user_id ELSE NULL END) STORED | بله | uniqueness پیش‌فرض |
| last_used_at | DATETIME(0) | بله | NULL |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |
| updated_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP ON UPDATE |
| is_anonymized | TINYINT(1) | خیر | پیش‌فرض 0 |
| anonymized_at | DATETIME(0) | بله | NULL |

ایندکس‌ها:

- `PRIMARY KEY (biometric_credential_id)`
- `UNIQUE KEY uq_biometric_credential (credential_id)`
- `UNIQUE KEY uq_biometric_active_user (active_user_id)`
- `UNIQUE KEY uq_biometric_default_user (default_user_id)`
- `KEY idx_biometric_user_active (user_id, is_active)`
- `KEY idx_biometric_public_hash (public_key_sha256)`

مقادیر الگوریتم با Lookup یا Laravel Enum کنترل شوند. فعال‌سازی و هم‌ترازکردن
active/default در Transaction انجام می‌شود.

## 20. auth_sessions

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| auth_session_id | BIGINT UNSIGNED | خیر | PK |
| session_uuid | BINARY(16) | خیر | UUID یکتا |
| user_id | BIGINT UNSIGNED | بله | FK؛ برای Guest تهی |
| authentication_method | VARCHAR(20) | خیر | Password/Biometric/Guest |
| state | VARCHAR(20) | خیر | Active/Expired/Revoked/LoggedOut |
| active_user_id | BIGINT UNSIGNED GENERATED ALWAYS AS (CASE WHEN state = 'Active' AND user_id IS NOT NULL THEN user_id ELSE NULL END) STORED | بله | uniqueness فعال |
| ip_address | VARCHAR(45) | خیر | IP |
| user_agent | VARCHAR(512) | خیر | User-Agent |
| issued_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |
| last_activity_at | DATETIME(0) | خیر | زمان فعالیت |
| expires_at | DATETIME(0) | خیر | زمان انقضای مطلق |
| terminated_at | DATETIME(0) | بله | NULL |
| revoked_at | DATETIME(0) | بله | NULL |
| logged_out_at | DATETIME(0) | بله | NULL |
| terminal_reason | VARCHAR(30) | بله | دلیل پایان |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |
| updated_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP ON UPDATE |

ایندکس‌ها:

- `PRIMARY KEY (auth_session_id)`
- `UNIQUE KEY uq_auth_session_uuid (session_uuid)`
- `UNIQUE KEY uq_auth_session_active_user (active_user_id)`
- `KEY idx_auth_session_user_state (user_id, state)`
- `KEY idx_auth_session_state_expiry (state, expires_at)`
- `KEY idx_auth_session_state_activity (state, last_activity_at)`
- `KEY idx_auth_session_archival (state, terminated_at)`

Lookup `auth_session_state_lookup` شامل Active، Expired، Revoked و LoggedOut است.

در نسخه فعلی، OTP تلگرام در Login یا MFA استفاده نمی‌شود. Password، Biometric
و Guest طبق قواعد موجود در چرخه احراز هویت قابل استفاده‌اند. Guest فقط برای
Session موقت قبل از تکمیل ثبت‌نام است. تمام Timeline، انقضا،
inactivity پانزده‌دقیقه‌ای، terminal metadata و انتقال State در Laravel انجام
می‌شود. Database فقط uniqueness، FK و nullability را حفظ می‌کند.

## 21. auth_session_archives

برای نگهداری تاریخی Sessionهای پایان‌یافته، رکوردها پس از حداقل شش ماه از
`auth_sessions` به این جدول منتقل می‌شوند. این انتقال با Job کنترل‌شده Laravel
انجام می‌شود و نباید Session فعال را منتقل کند.

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| archive_id | BIGINT UNSIGNED | خیر | PK |
| auth_session_id | BIGINT UNSIGNED | خیر | شناسه اصلی Session |
| session_uuid | BINARY(16) | خیر | UUID تاریخی |
| user_id | BIGINT UNSIGNED | بله | شناسه کاربر |
| authentication_method | VARCHAR(20) | خیر | روش احراز هویت |
| state | VARCHAR(20) | خیر | Expired/Revoked/LoggedOut |
| ip_address | VARCHAR(45) | خیر | IP |
| user_agent | VARCHAR(512) | خیر | User-Agent |
| issued_at | DATETIME(0) | خیر | زمان صدور |
| last_activity_at | DATETIME(0) | خیر | آخرین فعالیت |
| expires_at | DATETIME(0) | خیر | انقضای مطلق |
| terminated_at | DATETIME(0) | خیر | زمان پایان |
| terminal_reason | VARCHAR(30) | بله | علت پایان |
| archived_at | DATETIME(0) | خیر | زمان انتقال |

ایندکس‌ها:

- `PRIMARY KEY (archive_id)`
- `UNIQUE KEY uq_session_archive_uuid (session_uuid)`
- `KEY idx_session_archive_user_time (user_id, terminated_at)`
- `KEY idx_session_archive_terminated (terminated_at)`

این جدول به‌صورت تاریخی نگهداری می‌شود و FK عملیاتی به user_accounts ندارد تا
آرشیو مستقل از چرخه عمر حساب باقی بماند.

## 22. system_states

### system_states

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| system_state_id | TINYINT UNSIGNED | خیر | PK و باید 1 باشد |
| state_value | TINYINT UNSIGNED | خیر | FK به Lookup |
| root_country_id | SMALLINT UNSIGNED | خیر | FK به CountryCounter |
| activation_user_threshold | BIGINT UNSIGNED | خیر | پیش‌فرض 44000000 |
| breathing_period_hours | INT UNSIGNED | خیر | پیش‌فرض 24 |
| threshold_reached_at | DATETIME(0) | بله | NULL |
| state_changed_at | DATETIME(0) | خیر | زمان تغییر |
| changed_by_admin_id | TINYINT UNSIGNED | بله | FK |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |
| updated_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP ON UPDATE |

### system_state_lookup

| ستون | نوع | Null |
|---|---|---:|
| state_code | TINYINT UNSIGNED | خیر |
| state_name | VARCHAR(100) | خیر |
| description | VARCHAR(255) | بله |

`PRIMARY KEY (state_code)`.

قیود پایدار:

- `CHECK (system_state_id = 1)`
- `CHECK (state_value BETWEEN 1 AND 7)`

ترتیب monotonic، الزام admin، threshold و breathing period در
system_states Service و Transaction اعمال می‌شوند.

## 23. user_telegram_identities

این موجودیت در V37 وجود نداشت و برای بات معمولی ضروری است. هر حساب VetoApp
می‌تواند چند Telegram Identity متصل داشته باشد؛ محدودیتی برای تعداد حساب‌های
تلگرام کاربر اعمال نمی‌شود. هر Telegram Identity فقط به یک حساب VetoApp متصل
می‌شود.

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| telegram_identity_id | BIGINT UNSIGNED | خیر | PK |
| user_id | BIGINT UNSIGNED | بله | FK به user_profiles؛ در ثبت‌نام قبل از ساخت کاربر تهی |
| registration_draft_id | BIGINT UNSIGNED | بله | FK به registration_drafts؛ برای اتصال پیش از تکمیل ثبت‌نام |
| telegram_user_id | BIGINT UNSIGNED | خیر | شناسه کاربر تلگرام |
| chat_id | BIGINT | خیر | شناسه چت برای sendMessage |
| username | VARCHAR(100) | بله | اطلاعات غیرقابل اتکا و قابل تغییر |
| link_status | VARCHAR(15) | خیر | Pending/Linked/Revoked |
| verified_mobile_hash | BINARY(32) | بله | HMAC شماره Contact تأییدشده |
| phone_verified_at | DATETIME(0) | بله | زمان تأیید Contact |
| phone_verification_status | VARCHAR(15) | خیر | Pending/Verified/Revoked |
| linked_at | DATETIME(0) | بله | زمان اتصال |
| last_seen_at | DATETIME(0) | بله | آخرین رویداد |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |
| updated_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP ON UPDATE |

ایندکس‌ها:

- `PRIMARY KEY (telegram_identity_id)`
- `UNIQUE KEY uq_telegram_user_id (telegram_user_id)`
- `UNIQUE KEY uq_telegram_chat_id (chat_id)`
- `KEY idx_telegram_user_account (user_id, link_status)`
- `KEY idx_telegram_registration_draft (registration_draft_id, link_status)`
- `KEY idx_telegram_verified_mobile (verified_mobile_hash, phone_verification_status)`
- `KEY idx_telegram_link_status (link_status)`

`telegram_user_id` و `chat_id` یکتا هستند، اما `user_id` یکتا نیست و یک کاربر
VetoApp می‌تواند چند Identity داشته باشد. اتصال حساب فقط با deep-link/state
یک‌بارمصرف و پس از Start کردن ربات انجام شود. username مبنای شناسایی یا
احراز هویت نیست.

برای هر Identity باید در هر لحظه فقط یکی از `Pending`, `Linked`, `Revoked`
فعال باشد. سازگاری `user_id` و `registration_draft_id` و وضعیت
`phone_verification_status` در Laravel انجام می‌شود.

### تأیید شماره از طریق Contact رسمی Telegram

در ثبت‌نام، دریافت OTP بدون تکمیل این مراحل ممنوع است:

1. کاربر شماره را در اپ وارد می‌کند و `mobile_hash` ساخته می‌شود.
2. Backend یک `registration_nonce` کوتاه‌عمر ایجاد می‌کند.
3. کاربر با Deep Link اختصاصی وارد ربات می‌شود و `/start` را ارسال می‌کند.
4. ربات با `request_contact` از کاربر می‌خواهد Contact رسمی خودش را ارسال کند.
5. Backend باید بررسی کند:
   - `contact.user_id` دقیقاً برابر `telegram_user_id` فرستنده باشد؛
   - شماره `contact.phone_number` پس از E.164 normalization با شماره فرم
     برابر باشد؛
   - `registration_nonce` معتبر، استفاده‌نشده و منقضی‌نشده باشد.
6. پس از موفقیت، `verified_mobile_hash` و `phone_verified_at` ثبت و وضعیت
   `phone_verification_status` به `Verified` تغییر می‌کند.
7. سپس OTP دو دقیقه‌ای از همان Identity تأییدشده ارسال می‌شود.

Contact تایپ‌شده، Contact بدون `user_id` منطبق، username و صرفاً chat_id برای
تأیید شماره قابل قبول نیستند.

## 24. otp_delivery_attempts

این جدول برای ثبت وضعیت ارسال خروجی پیشنهاد می‌شود.

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| delivery_attempt_id | BIGINT UNSIGNED | خیر | PK |
| otp_id | BIGINT UNSIGNED | خیر | FK |
| telegram_identity_id | BIGINT UNSIGNED | بله | مقصد Telegram |
| channel | VARCHAR(20) | خیر | فقط telegram_bot |
| provider_message_id | VARCHAR(128) | بله | شناسه سرویس‌دهنده |
| attempt_number | TINYINT UNSIGNED | خیر | شماره تلاش |
| status | VARCHAR(20) | خیر | Queued/Sent/Delivered/Failed |
| failure_code | VARCHAR(64) | بله | کد خطا |
| attempted_at | DATETIME(0) | خیر | زمان تلاش |
| delivered_at | DATETIME(0) | بله | زمان تحویل |
| created_at | DATETIME(0) | خیر | CURRENT_TIMESTAMP |

ایندکس‌ها:

- `PRIMARY KEY (delivery_attempt_id)`
- `KEY idx_delivery_telegram_identity (telegram_identity_id, created_at)`
- `KEY idx_delivery_otp_attempt (otp_id, attempt_number)`
- `KEY idx_delivery_status_created (status, created_at)`
- `UNIQUE KEY uq_delivery_provider_message (channel, provider_message_id)`

`channel` فقط `telegram_bot` است و `telegram_identity_id` باید به
`user_telegram_identities.telegram_identity_id` اشاره کند. مقصد ارسال فقط
Identityای است که `phone_verification_status = 'Verified'` و
`verified_mobile_hash = otps.mobile_hash` داشته باشد.

در ثبت‌نام، OTP فقط به Identity جاری همان `registration_draft` ارسال می‌شود.
در `password_reset`، اگر چند Identity تأییدشده برای همان `mobile_hash` وجود
داشته باشد، OTP برای همه آن Identityها ارسال و برای هرکدام یک
`otp_delivery_attempts` ثبت می‌شود.

## 25. Webhook و Integration Contract

### مسیر پیشنهادی Laravel

```text
POST /api/integrations/telegram/webhook/{secret}
```

Webhook باید:

1. Secret مسیر یا Header را بررسی کند.
2. Payload را بدون تغییر در integration_inbox_entries ثبت کند.
3. Duplicate را با `(channel, external_message_id)` تشخیص دهد.
4. پاسخ سریع HTTP 200 بدهد.
5. پردازش واقعی را به Queue Redis بسپارد.
6. از Payload، OTP خام یا داده حساس را در log معمولی ننویسد.

برای ارسال OTP، Webhook لازم نیست؛ `TelegramSendMessageJob` از Laravel Queue
استفاده می‌کند. Webhook فقط برای `/start`، اتصال حساب، Callback Query و
رویدادهای ورودی Telegram لازم است.

### اجزای اجرایی

- `TelegramWebhookController`
- `TelegramUpdateIngestor`
- `TelegramUpdateProcessor`
- `TelegramSendMessageJob`
- `OtpService`
- `OtpThrottleService`
- `TelegramIdentityLinkService`
- `TelegramContactVerificationService`
- `IntegrationInboxRepository`

## 26. قواعد OTP در Laravel

### صدور

1. شماره به E.164 نرمال شود.
2. `mobile_hash` با pepper سرور ساخته شود.
3. پنجره Throttle با Redis lock یا `lockForUpdate()` خوانده شود.
4. محدودیت ارسال بررسی شود.
5. OTP قبلی همان purpose به Expired تغییر کند.
6. OTP جدید با `random_int()` تولید شود.
7. فقط `code_hash` ذخیره شود.
8. برای registration، Identity جاری Draft و برای password_reset تمام Identityهای
   تأییدشده با همان `mobile_hash` انتخاب شوند.
9. DeliveryAttempt با وضعیت Queued برای هر مقصد ایجاد شود.
10. Jobهای ارسال به Redis Queue سپرده شوند.

### تأیید

1. OTP و پنجره با `lockForUpdate()` خوانده شوند.
2. State، انقضا، attempt count و throttle بررسی شود.
3. HMAC با `hash_equals()` مقایسه شود.
4. در موفقیت State به Verified تغییر کند.
5. در شکست شمارنده‌ها اتمیک افزایش یابند.
6. در عبور از سقف، OTP Failed و پنجره Blocked شود.

### پاسخ API

برای ثبت‌نام، ورود و فراموشی رمز، پیام خطا نباید وجود یا عدم وجود شماره در
سامانه را افشا کند.

## 27. Migration و Seed

- هر جدول Migration مستقل داشته باشد.
- FKها بعد از ایجاد جدول‌های والد اضافه شوند.
- Lookupها با `upsert` seed شوند.
- تغییر policy به‌صورت insert نسخه جدید انجام شود.
- Migrationها از `unsignedBigInteger`، `binary`، `varBinary` و `dateTime`
  لاراول استفاده کنند.
- Raw SQL فقط برای Generated Column، Indexهای اختصاصی MySQL و مواردی که
  Schema Builder پشتیبانی نمی‌کند مجاز است.
- همه Indexها نام صریح و یکتا داشته باشند.
- قبل از اجرای Migration روی Production، `EXPLAIN` برای Queryهای اصلی اجرا شود.

### 27.1 مقدارهای اولیه قطعی

#### security_policies

بر اساس V37، Seed اولیه فعال باید این مقدارها را داشته باشد:

| ستون | مقدار |
|---|---:|
| is_active | 1 |
| max_failed_attempts | 5 |
| base_lockout_seconds | 900 |
| progressive_factor | 2.0 |
| max_lockout_seconds | 86400 |

#### otp_throttle_windows

مقدارهای عملیاتی قطعی:

| سیاست | مقدار |
|---|---:|
| window duration | 15 دقیقه |
| maximum dispatches | 3 |
| inter-request cooldown | 60 ثانیه |
| cumulative verification failures | 5 |
| penalty tier 1 | 15 دقیقه |
| penalty tier 2 | 30 دقیقه |
| penalty tier 3 | 60 دقیقه |

#### OTP

| سیاست | مقدار |
|---|---:|
| TTL | 2 دقیقه |
| maximum attempts per OTP | 3 |
| channel | telegram_bot |
| purposes | registration, password_reset |

#### مقادیر Policyهای جغرافیایی

#### geo_cooldown_policies

در نسخه فعلی فقط یک خانواده Policy فعال وجود دارد و چهار ردیف Stage آن به شکل
زیر است:

| policy_code | policy_stage | cooldown_days | is_active |
|---|---:|---:|---:|
| geo_reassignment_default | 1 | 30 | 1 |
| geo_reassignment_default | 2 | 60 | 1 |
| geo_reassignment_default | 3 | 120 | 1 |
| geo_reassignment_default | 4 | 180 | 1 |

`policy_code` یک خانواده Policy است و مرحله فعلی در Service بر اساس سوابق
`user_geo_change_logs` تعیین می‌شود. چون جدول فعلی برای هر Stage یک ردیف دارد،
قید یکتایی پیشنهادی همچنان `(policy_code, penalty_stage)` است. فقط ردیف
Stage 4 سقف نهایی است و بعد از آن نیز همان 180 روز اعمال می‌شود.

Stage بر اساس تعداد تغییرات ثبت‌شده در `user_geo_change_logs` تعیین می‌شود و
بعد از Stage 4 همان 180 روز تکرار می‌شود. مقدارهای `max_changes_allowed` و
`window_days` در این Policy برای محاسبه Stage استفاده نمی‌شوند و Service باید
Stage را از سابقه تغییرات استخراج کند.

#### account_closure_penalty_policies

در نسخه فعلی فقط یک خانواده Policy فعال با چهار Stage وجود دارد:

| policy_code | penalty_stage | penalty_hours | is_active |
|---|---:|---:|---:|
| account_closure_default | 1 | 24 | 1 |
| account_closure_default | 2 | 48 | 1 |
| account_closure_default | 3 | 96 | 1 |
| account_closure_default | 4 | 194 | 1 |

Stage 4 سقف Policy است؛ تمام دفعات بعدی نیز با مقدار Stage 4، یعنی 194 ساعت،
محاسبه می‌شوند.

## 28. موارد حذف‌شده یا منتقل‌شده نسبت به V37

- `CURRENT_DATETIME` حذف و با `CURRENT_TIMESTAMP` جایگزین شد.
- Partial Indexهای دارای `WHERE` حذف شدند.
- محدودیت‌های وابسته به `CURRENT_TIMESTAMP` از Database حذف و به Laravel منتقل
  شدند.
- Timeline CHECKهای Draft، OTP و Session به Application Service منتقل شدند.
- single-default به Seed/Service منتقل شد.
- Triggerهای کسب‌وکاری الزام‌آور نیستند؛ append-only با DB privilege و Laravel
  Policy محافظت می‌شود.
- ایندکس‌های اضافی روی counterها حذف شدند؛ PK برای lookup کافی است.
- purposeهای `login` و `mfa_verification` حذف شدند؛ OTP فقط برای registration و
  password_reset است.
- کانال‌های Telegram Gateway، SMS و Voice حذف شدند؛ فقط `telegram_bot` باقی
  ماند.
- TTL OTP به‌صورت دقیق 2 دقیقه تعیین شد.
- ورود سامانه با Password/Biometric طبق مدل اصلی باقی ماند؛ فقط OTP تلگرام از
  Login و MFA جدا نگه داشته شد.
- امکان چند Telegram Identity برای یک User VetoApp اضافه شد.
- اتصال Telegram پیش از تکمیل ثبت‌نام با `registration_draft_id` پشتیبانی شد.
- دریافت Contact رسمی Telegram و تطبیق `contact.user_id` و شماره نرمال‌شده با
  شماره ثبت‌نام اجباری شد.
- `verified_mobile_hash` و `phone_verified_at` برای ثبت رابطه شماره و Identity
  اضافه شدند.
- در password_reset، OTP برای همه Identityهای تأییدشده متناظر با شماره ارسال
  می‌شود؛ در registration فقط Identity جاری Draft مقصد است.
- جداول `user_telegram_identities` و `otp_delivery_attempts` اضافه شدند.

## 29. تصمیم‌های نهایی ارتباط Telegram و OTP

- در ثبت‌نام، فقط Identity جاری متصل به همان `registration_draft` مقصد OTP است.
- در فراموشی رمز، همه Identityهای تأییدشده‌ای که `verified_mobile_hash` آن‌ها
  با `otps.mobile_hash` برابر است، مقصد OTP هستند.
- هیچ Identityای بدون Contact رسمی تأییدشده مجاز به دریافت OTP نیست.
- Telegram Gateway، SMS و Voice در این نسخه استفاده نمی‌شوند.

## 30. موجودیت‌های محتوای عمومی سامانه

### 30.1 دامنه و هدف

برای نمایش محتوای عمومی سامانه، سه موجودیت مستقل در نظر گرفته می‌شود:

1. `system_introduction_contents` برای متن معرفی سامانه؛
2. `system_terms_contents` برای متن قوانین و مقررات؛
3. `system_introduction_videos` برای متادیتای فیلم معرفی سامانه.

این موجودیت‌ها به `user_profiles`، `user_accounts` یا موجودیت‌های جغرافیایی
وابسته نیستند و محتوای عمومی سامانه را نگهداری می‌کنند. محتوای تأییدنشده نباید
برای کاربران نمایش داده شود.

### 30.2 قواعد عمومی محتوا

- هر نسخه با `version_number` شناسایی می‌شود.
- برای هر موجودیت، `version_number` یکتا است.
- رکوردهای قبلی حذف یا ویرایش محتوایی نمی‌شوند؛ نسخه جدید باید به‌صورت رکورد
  جدید درج شود.
- فعال‌سازی نسخه و غیرفعال‌سازی نسخه قبلی باید در Laravel Service و Transaction
  انجام شود.
- در هر موجودیت حداکثر یک رکورد فعال مجاز است؛ این قاعده در Service/Policy
  مدیریت می‌شود و به زمان جاری در سطح Database وابسته نیست.
- رکورد فقط زمانی قابل نمایش عمومی است که `is_active = 1` و
  `published_at` مقدار داشته باشد و زمان انتشار آن رسیده باشد.
- زمان‌ها با UTC و نوع `DATETIME(0)` ذخیره می‌شوند.
- حذف فیزیکی نسخه‌های انتشار‌یافته ممنوع است تا سابقه نسخه و حسابرسی حفظ شود.

### 30.3 system_introduction_contents

متن نسخه‌بندی‌شده معرفی سامانه.

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| introduction_content_id | SMALLINT UNSIGNED | خیر | PK خودافزا |
| version_number | INT UNSIGNED | خیر | شماره نسخه یکتا |
| title | VARCHAR(255) | خیر | عنوان محتوای معرفی |
| body_text | LONGTEXT | خیر | متن معرفی سامانه |
| is_active | TINYINT(1) | خیر | وضعیت فعال |
| published_at | DATETIME(0) | بله | زمان انتشار UTC |
| created_at | DATETIME(0) | خیر | زمان ایجاد |
| updated_at | DATETIME(0) | خیر | زمان آخرین تغییر |

قیود و ایندکس‌ها:

- `PRIMARY KEY (introduction_content_id)`
- `UNIQUE KEY uq_system_intro_version (version_number)`
- `KEY idx_system_intro_active_published (is_active, published_at)`
- محتوای متنی باید در Application Layer از نظر طول، قالب و محتوای مجاز
  اعتبارسنجی شود.

### 30.4 system_terms_contents

متن نسخه‌بندی‌شده قوانین و مقررات سامانه.

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| terms_content_id | SMALLINT UNSIGNED | خیر | PK خودافزا |
| version_number | INT UNSIGNED | خیر | شماره نسخه یکتا |
| title | VARCHAR(255) | خیر | عنوان قوانین |
| body_text | LONGTEXT | خیر | متن قوانین و مقررات |
| is_active | TINYINT(1) | خیر | وضعیت فعال |
| published_at | DATETIME(0) | بله | زمان انتشار UTC |
| created_at | DATETIME(0) | خیر | زمان ایجاد |
| updated_at | DATETIME(0) | خیر | زمان آخرین تغییر |

قیود و ایندکس‌ها:

- `PRIMARY KEY (terms_content_id)`
- `UNIQUE KEY uq_system_terms_version (version_number)`
- `KEY idx_system_terms_active_published (is_active, published_at)`
- پذیرش قوانین توسط کاربر در نسخه‌های بعدی باید با نگهداری
  `terms_content_id` یا `version_number` در موجودیت اختصاصی پذیرش قوانین
  ثبت شود؛ این نسخه هنوز موجودیت پذیرش کاربر را اضافه نمی‌کند.

### 30.5 system_introduction_videos

این جدول خود فایل ویدئو را ذخیره نمی‌کند و فقط اطلاعات دسترسی و نمایش ویدئوی
معرفی را نگهداری می‌کند. فایل باید در Object Storage، CDN یا سرویس رسانه‌ای
معتبر قرار گیرد.

| ستون | نوع | Null | توضیح |
|---|---|---:|---|
| introduction_video_id | SMALLINT UNSIGNED | خیر | PK خودافزا |
| version_number | INT UNSIGNED | خیر | شماره نسخه یکتا |
| title | VARCHAR(255) | خیر | عنوان ویدئو |
| video_url | VARCHAR(2048) | خیر | آدرس اصلی ویدئو |
| poster_url | VARCHAR(2048) | بله | آدرس تصویر پوستر |
| duration_seconds | INT UNSIGNED | بله | مدت ویدئو برحسب ثانیه |
| is_active | TINYINT(1) | خیر | وضعیت فعال |
| published_at | DATETIME(0) | بله | زمان انتشار UTC |
| created_at | DATETIME(0) | خیر | زمان ایجاد |
| updated_at | DATETIME(0) | خیر | زمان آخرین تغییر |

قیود و ایندکس‌ها:

- `PRIMARY KEY (introduction_video_id)`
- `UNIQUE KEY uq_system_intro_video_version (version_number)`
- `KEY idx_system_intro_video_active_published (is_active, published_at)`
- اعتبارسنجی HTTPS، دامنه مجاز، نوع فایل و دسترسی URL در Laravel انجام می‌شود.
- فایل ویدئو، توکن دسترسی یا محتوای باینری در این جدول ذخیره نمی‌شود.

### 30.6 عملیات انتشار محتوا

انتشار یا جایگزینی محتوای فعال باید با Transaction انجام شود:

1. رکورد نسخه جدید درج می‌شود؛
2. نسخه فعال قبلی همان موجودیت غیرفعال می‌شود؛
3. نسخه جدید فعال و در صورت نیاز `published_at` تنظیم می‌شود؛
4. در صورت وجود سامانه حسابرسی مدیریتی، عملیات در
   `admin_activity_logs` ثبت می‌شود.

هیچ‌یک از این عملیات نباید با حذف فیزیکی نسخه‌های قبلی انجام شود.

## 31. متن اولیه پیشنهادی محتوا

این متن‌ها Draft هستند و تا زمان تأیید مالک سامانه نباید به‌عنوان نسخه فعال
Seed شوند.

### 31.1 متن معرفی سامانه

**عنوان:** معرفی سامانه وتواپ

سامانه وتواپ بستری برای مشارکت شهروندان در فرآیندهای مدنی، اجتماعی و
تصمیم‌گیری عمومی است. این سامانه تلاش می‌کند دسترسی کاربران به اطلاعات،
فرآیندها و خدمات مرتبط با مشارکت مدنی را به شکلی شفاف، امن و قابل اعتماد
فراهم کند.

ثبت‌نام در سامانه با استفاده از شماره موبایل و ارتباط تأییدشده تلگرام انجام
می‌شود. پس از تکمیل ثبت‌نام، کاربر می‌تواند با رمز عبور خود وارد سامانه شود و
از قابلیت‌های فعال‌شده متناسب با وضعیت سامانه استفاده کند.

حفاظت از اطلاعات کاربران، رعایت محرمانگی، ثبت رویدادهای حساس و اعتبارسنجی
اطلاعات هویتی و جغرافیایی از اصول اصلی طراحی وتواپ است.

### 31.2 متن قوانین و مقررات

**عنوان:** قوانین و مقررات استفاده از سامانه وتواپ

1. استفاده از سامانه فقط برای شخصی مجاز است که مالک یا استفاده‌کننده مجاز
   شماره موبایل و حساب تلگرام معرفی‌شده باشد.
2. هر کاربر فقط مجاز به ایجاد و استفاده از یک حساب در سامانه وتواپ است.
3. کاربر مسئول صحت اطلاعات واردشده، از جمله شماره موبایل، کد ملی، اطلاعات
   جغرافیایی و رمز عبور است.
4. استفاده از شماره موبایل یا اطلاعات هویتی شخص دیگر، تلاش برای ایجاد حساب
   تکراری، جعل هویت یا دور زدن فرآیندهای اعتبارسنجی ممنوع است.
5. کدهای یک‌بارمصرف فقط برای ثبت‌نام اولیه و بازیابی رمز عبور استفاده می‌شوند
   و برای ورود عادی به سامانه کاربرد ندارند.
6. کاربر موظف است رمز عبور خود را محرمانه نگه دارد و از قراردادن آن در اختیار
   دیگران خودداری کند.
7. استفاده از سامانه برای ایجاد اختلال، ارسال محتوای غیرقانونی، تهدید، توهین،
   فریب کاربران یا دستکاری فرآیندهای سامانه ممنوع است.
8. سامانه می‌تواند در صورت مشاهده رفتار مشکوک، نقض قوانین یا استفاده غیرمجاز،
   فرآیند ثبت‌نام یا دسترسی حساب را مطابق سیاست‌های سامانه محدود یا متوقف کند.
9. تغییر اطلاعات جغرافیایی، بستن حساب و سایر عملیات حساس ممکن است مشمول
   محدودیت‌ها و دوره‌های انتظار تعریف‌شده در سیاست‌های سامانه باشد.
10. ادامه استفاده از سامانه به‌منزله پذیرش نسخه‌ای از قوانین است که هنگام
    استفاده یا تأیید کاربر فعال بوده است.
11. نسخه‌های قبلی قوانین برای اهداف حسابرسی نگهداری می‌شوند و تغییر نسخه جدید،
    متن نسخه‌های قبلی را تغییر نمی‌دهد.
12. هرگونه تغییر اساسی در قوانین از طریق سامانه به اطلاع کاربران خواهد رسید.

### 31.3 مشخصات متن فیلم معرفی

**عنوان:** فیلم معرفی سامانه وتواپ

در این ویدئو، هدف سامانه وتواپ، مراحل ثبت‌نام، نحوه اتصال حساب تلگرام،
تأیید شماره موبایل، انتخاب اطلاعات جغرافیایی و روش ورود به سامانه توضیح داده
می‌شود.

همچنین اصول حفاظت از اطلاعات، استفاده صحیح از حساب کاربری و مهم‌ترین قوانین
استفاده از سامانه به‌صورت خلاصه معرفی خواهد شد.

## 32. موارد اضافه‌شده در V41

- سه موجودیت مستقل برای متن معرفی، قوانین و مقررات، و فیلم معرفی اضافه شد.
- نام جدول‌ها به‌صورت `snake_case` تعیین شد.
- متن‌ها با `LONGTEXT` ذخیره می‌شوند.
- فایل ویدئو خارج از Database و در Object Storage/CDN نگهداری می‌شود.
- برای هر موجودیت نسخه‌گذاری و نگهداری سابقه نسخه‌ها تعریف شد.
- نمایش عمومی فقط برای محتوای فعال و منتشرشده مجاز است.
- فعال‌سازی نسخه جدید و جایگزینی نسخه فعال قبلی به Laravel Service و
  Transaction سپرده شد.
- متن‌های اولیه در این نسخه Draft هستند و هنوز Seed فعال نشده‌اند.

## 33. وضعیت نسخه

- نسخه: DRM V41
- مبنا: DRM V40
- Backend: Laravel / PHP 8.3
- Database: MySQL 8.0 InnoDB
- Cache/Queue/Lock: Redis
- زمان پایگاه داده: UTC
- وضعیت: نهایی از نظر مدل محتوای عمومی و آماده تبدیل به Migration؛ متن‌های
  معرفی و قوانین تا تأیید مالک سامانه Draft باقی می‌مانند.
