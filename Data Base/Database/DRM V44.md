# VetoApp Data Requirements Model — DRM V44

## دامنه و تصمیم‌های این بازنگری

این نسخه بر پایهٔ DRM V43 و با افزودن قرارداد استقرار فرایندمحور برای شاردینگ افقی بازنگری شده است. schema محلی بخشی از جداول فرایند را در یک MySQL پیاده‌سازی کرده، اما مسیریابی چندشاردی و تضمین هم‌مکانی فیزیکی هنوز اجرا نشده‌اند. این سند مرز میان الزام‌های طراحی پیش از دادهٔ عملیاتی و زیرساختی را که می‌توان هنگام نیاز ظرفیت راه‌اندازی کرد مشخص می‌کند؛ به‌تنهایی مجوز اجرای migration یا تغییر دیتابیس نیست.

- **جداسازی هویت و انتخاب:** توکن یک‌بارمصرف رأی به هویت احراز‌شده تعلق دارد و در دامنهٔ هویت نگهداری می‌شود. سرور آن را هنگام ثبت رأی اعتبارسنجی و مصرف می‌کند؛ اما جدول صندوق رأی هیچ token ID/hash، شناسهٔ کاربر، کلید هویت، کلید idempotency هویتی یا FK به جدول‌های هویتی ندارد. رکورد مشارکت هویتی نیز به ردیف صندوق یا انتخاب وصل نمی‌شود. بنابراین اتصال پایدار و مستقیم هویت به گزینهٔ انتخاب‌شده در مدل رابطه‌ای ذخیره نمی‌شود؛ این روش محرمانگی رمزنگاری‌شده یا مقاومت در برابر هم‌بستگی لاگ‌ها/تراکنش‌های ممتاز را تضمین نمی‌کند.
- **کلیدهای idempotency:** کلید ارسال رأی فقط در دامنهٔ صندوق است و با کلید صدور توکن یا شناسه‌های هویتی مشترک نیست. همان کلید و همان payload رسید قبلی را برمی‌گرداند؛ همان کلید با payload متفاوت رد می‌شود. هیچ شناسهٔ مشترکی برای اتصال رکورد مشارکت به رأی ذخیره نمی‌شود.
- **ریسک پذیرفته‌شده:** زمان دقیق و حوزهٔ جغرافیایی دقیق حفظ می‌شوند و برای کاهش هم‌بستگی گرد، تأخیر یا دسته‌بندی نمی‌شوند. مدیر دارای دسترسی به تراکنش‌ها، binlogها یا لاگ‌های برنامه ممکن است با تطبیق زمان/جغرافیا مشارکت را به رأی نزدیک کند؛ این خطر طبق تصمیم محصول پذیرفته شده است. این مدل ادعای ناشناس‌بودن رمزنگاری‌شده یا مقاومت در برابر مدیر/سرور ممتاز ندارد.
- **واجدشرایط بودن:** در لحظهٔ ثبت رأی، حوزهٔ جغرافیایی مؤثر کاربر باید از طریق زنجیرهٔ والدهای جغرافیایی درون حوزهٔ هدف فرایند قرار بگیرد؛ شناسه‌های دو سطح متفاوت الزاماً برابر نیستند. وضعیت فرایند و بازهٔ مجاز رأی نیز باید همان لحظه معتبر باشد.
- **گزینه‌های رأی:** همه‌پرسی از YES/NO و استیضاح از REMOVE/KEEP استفاده می‌کند. انتخابات گزینهٔ نامزدِ canonical دارد؛ نام، نام خانوادگی و نام پدر هنگام تعریف گزینه به شکل متن آزاد دریافت، در سرور نرمال و پیش از بازشدن رأی‌گیری تثبیت می‌شود. رأی فقط کلید گزینه را ثبت می‌کند.
- **نصاب حمایت:** شمارندهٔ آسنکرون `ProcessGeographicCounter` تنها معیار runtime برای رسیدن به نصاب است. پردازش رویداد شمارنده و انتقال وضعیت سریالی، اتمیک و idempotent است. دفتر immutable حمایت منبع ممیزی و بازسازی است، نه معیار موازی تصمیم نصاب. تأخیر شمارنده می‌تواند انتقال را عقب بیندازد و این رفتار پذیرفته‌شده است.
- **وضعیت‌ها و چرخهٔ فرایند:** فهرست وضعیت‌ها و معنای هر وضعیت، همان موجودیت‌های ۲۱ و ۲۵ در DRM V42 است و از فهرست متفاوت TAD جایگزین نمی‌شود. انتقال‌ها تابع ProcessTransitionRule هستند.
- **انتشار نتایج و راستی‌آزمایی:** خروجی‌های تجمیعی در فاصلهٔ قابل تنظیم (پیش‌فرض ۱۰ دقیقه) تازه می‌شوند؛ زمان انتشار به زمان ثبت رأی دست نمی‌زند. checkpoint امضاشدهٔ Merkle، اندازهٔ درخت، آخرین sequence، نسخهٔ الگوریتم و اثبات‌های inclusion/consistency برای بررسی مستقل منتشر می‌شوند. checkpointهای قبلی immutable می‌مانند. زیرسامانهٔ جداگانهٔ اعتراض/پروندهٔ شکایت در این نسخه تعریف نمی‌شود.
- **رویدادها:** Kafka بخشی از وابستگی الزامی نیست. MySQL مرجع رکوردهای رأی و outbox است؛ پردازش پس‌زمینه با صف جاری انجام می‌شود و امکان تغییر broker در آینده خارج از قرارداد schema است.
- **کلید جغرافیایی:** نوع FKها باید عیناً با schema جاری منطبق باشد؛ در schema جاری `settlement_id` از نوع `INT UNSIGNED` است. شناسهٔ چندریختی `geographic_id` باید ظرفیت کافی برای تمام سطوح داشته باشد.
- **دقت زمان رأی:** زمان‌های مؤثر در ترتیب و هش رأی، شامل `VoterParticipation.participated_at` و `BallotBoxEntry.recorded_at`، از نوع `DATETIME(3)` و UTC هستند تا با قالب ثابت سه رقم اعشار در Encoding V1 سازگار بمانند. زمان‌های عملیاتی خارج از payload هش می‌توانند دقت معمول داشته باشند.

## معماری استقرار و شاردینگ افقی

### تصمیم معماری

- **واحد جانمایی:** هر `Process`، یعنی هر همه‌پرسی، انتخابات یا استیضاح، یک واحد مستقل جانمایی است. `process_id` کلید مسیریابی شارد است؛ کشور، استان، زمان، نوع فرایند یا هویت شرکت‌کننده کلید شارد نیستند.
- **اصل هم‌مکانی:** همهٔ داده‌های عملیاتی همان فرایند که برای صحت، اتمیک‌بودن، زنجیره یا مرکل به هم وابسته‌اند روی یک شارد قرار می‌گیرند. این مجموعه شامل `Process` و وضعیت‌های آن، snapshot جمعیت و سیاست، گزینه‌ها، `SupportParticipation`، `VoteToken`، `VoterParticipation`، `BallotBoxEntry`، رسیدهای همان فرایند و ردیف‌های جزئیاتشان، `ProcessSequenceAllocator`، `ProcessChainHead`، `ProcessMerkleTree`، `ProcessGeographicCounter` و `ProcessProjectionOutboxEvent` است.
- **تراکنش رأی:** اعتبارسنجی و مصرف توکنِ محدود به فرایند، درج مشارکت، ثبت برگ رأی، صدور رسید، افزایش توالی و درج رویداد outbox در همان شارد و یک تراکنش اتمیک انجام می‌شود. تراکنش نوشتن رأی حق ندارد هم‌زمان روی شارد هویت یا شارد فرایند دیگری بنویسد.
- **شناسهٔ جهانی فرایند:** `process_id` باید در کل سامانه یکتا باشد و از شمارندهٔ محلی هر MySQL تولید نشود. رجیستری کنترل‌پلین شناسه را تخصیص می‌دهد و پیش از ساخت فرایند، یک جانمایی یکتا برای آن ثبت می‌کند.
- **رجیستری جانمایی:** `ShardCatalog` فهرست منطقی شاردها و وضعیت عملیاتی آن‌ها را در کنترل‌پلین نگه می‌دارد. `ProcessShardPlacement` نگاشت قطعی `process_id → shard_id` و وضعیت ساخت/فعال‌بودن آن را نگه می‌دارد. اطلاعات محرمانهٔ اتصال، گذرواژه و endpoint مستقیم داخل این جداول ذخیره نمی‌شود؛ مسیریاب آن‌ها را از پیکربندی امن زیرساخت می‌گیرد. درخواست فقط پس از فعال‌شدن جانمایی به کاربر نمایش داده می‌شود.
- **رکوردهای فرزند:** هر جدول عملیاتیِ فرایند باید `process_id` را داشته باشد یا از والد مستقیم خود در همان شارد قابل ردیابی باشد. برای جانمایی و FK محلی روشن، به `digital_receipt_support_details` و `digital_receipt_vote_details` نیز `process_id` افزوده می‌شود و FKهای مرکب تضمین می‌کنند رسید و برگ رأی به همان فرایند تعلق دارند. قیدهای یکتاییِ retry و توکن نیز در دامنهٔ فرایند تعریف می‌شوند؛ مانند `(process_id, ballot_submission_idempotency_key)` و `(process_id, token_hash)`.
- **شناسه‌های جهانی و FKها:** کلیدهای خارجی فقط در محدودهٔ همان MySQL shard معتبرند؛ FK از شارد فرایند به جداول حساب/پروفایلِ مرکزی مجاز نیست. `created_by_user_id` و `beneficiary_user_account_id` در شارد فرایند شناسه‌های منطقیِ صادرشده از سامانهٔ هویت‌اند و اعتبارشان در لایهٔ سرویس بررسی می‌شود. lookupها و جداول ثابت جغرافیا باید نسخه‌دار و در شاردهای فرایند در دسترس باشند یا اعتبارسنجی‌شان پیش از تراکنش انجام شود. دادهٔ حساس هویتی در شارد فرایند تکثیر نمی‌شود.
- **رسید عمومی:** رسید مرجع و دادهٔ اثبات آن در شارد فرایند می‌مانند. درخواست صحت‌سنجی عمومی باید `process_id` را همراه شمارهٔ رسید بگیرد تا مستقیم به همان شارد مسیریابی شود؛ اگر رابط عمومی فقط شمارهٔ رسید بگیرد، یک locator مرکزیِ حداقلی می‌تواند `receipt_number → process_id` را نگه دارد، اما payload رأی، رسید کامل یا برگ رأی را در آن کپی نمی‌کند.
- **پردازش‌های ناهمگام:** `ProcessProjectionOutboxEvent` در شارد منبع و همراه نوشتن اصلی ثبت می‌شود. Workerها کار را بر اساس `process_id` گروه‌بندی و به همان شارد route می‌کنند. تحویل اعلان به صندوق ورودی کاربران می‌تواند در زیرسامانهٔ جداگانه انجام شود و عضوی از تراکنش رأی نیست.
- **جابه‌جایی فرایند:** جانمایی فرایند پس از فعال‌شدن ثابت است. جابه‌جایی مجاز فقط به‌صورت رویهٔ کنترل‌شده است: توقف نوشتن، انتقال مجموعهٔ کامل، بازاعتبارسنجی آخرین sequence/hash و checkpointهای امضاشده، ثبت سابقهٔ جانمایی، و سپس cutover یکتای مسیریاب. فرایند فعال هرگز هم‌زمان روی دو شارد نوشته نمی‌شود.
- **محدودیت مقیاس هر فرایند:** این قرارداد چندین فرایند را بین شاردها توزیع می‌کند، ولی بار یک فرایند واحد را بین چند شارد تقسیم نمی‌کند. زنجیرهٔ ترتیبی هر فرایند روی یک شارد سریال می‌شود. اگر یک فرایند واحد به توان نوشتن بیش از یک شارد نیاز داشته باشد، باید پیش از آن طراحی جداگانه‌ای برای زیرصندوق‌ها/زنجیره‌های موازی و تجمیع Merkle تصویب شود؛ این قابلیت جزو این DRM نیست.

### چه چیزهایی پیش از دادهٔ واقعی رأی باید آماده باشد

1. ثبت `ShardCatalog` و `ProcessShardPlacement` در کنترل‌پلین، تخصیص جهانی `process_id` و قانون اینکه هیچ فرایندی بدون placement یکتا ساخته یا منتشر نشود.
2. تعریف جدول‌های فرایندی با `process_id` به‌عنوان کلید route؛ اضافه‌کردن `process_id` به جزئیات رسید و اصلاح قیدهای یکتایی/FK تا روابط داخلی همان فرایند را enforce کنند.
3. جداسازی FKهای بین شارد فرایند و حساب/پروفایل مرکزی؛ تعیین روش دسترسی به lookup و جغرافیای نسخه‌دار در هر شارد.
4. طراحی endpointها و جست‌وجوها برای route شدن با `process_id`؛ از جمله صحت‌سنجی عمومی رسید و عملیات مدیریتی/پشتیبانی.
5. نگه‌داشتن تراکنش نوشتن حمایت و رأی در یک شارد و مشخص‌کردن outbox برای کارهای ناهمگام.
6. پیش از فعال‌کردن رأی واقعی، اجرای اعتبارسنجی یکپارچه در محیط چندشاردیِ staging، شامل restart، retry، خطای میانهٔ تراکنش، بازیابی chain head و بازتولید Merkle.

### چه چیزهایی را می‌توان تا زمان نیاز ظرفیت به تعویق انداخت

- افزودن MySQLهای shard واقعی، replica، proxy/router، failover، مانیتورینگ، پشتیبان‌گیری و رویهٔ عملیاتی resharding.
- تعیین تعداد اولیهٔ shardها و انتقال دادهٔ موجود؛ تا آن زمان می‌توان placement واحد `primary` داشت و همان route contract را اجرا کرد.
- جابه‌جایی فرایندهای قدیمی برای توازن ظرفیت؛ این کار بعداً ممکن است، ولی باید از پروتکل مهاجرت و verification بالا استفاده کند.

این تعویق به معنی موکول‌کردن شاردینگ فیزیکی است، نه موکول‌کردن قرارداد schema و تراکنش. پارتیشن‌بندی native جدول‌های InnoDB جایگزین این معماری نیست و با FKهای این مدل سازگار نیست؛ مرجع فنی MySQL 8.4 این محدودیت را برای جدول‌های InnoDB پارتیشن‌شده تصریح می‌کند ([Foreign Key Constraints](https://dev.mysql.com/doc/refman/8.4/en/create-table-foreign-keys.html)). همچنین پیش از اولین فرایند پرترافیک باید ظرفیت نوشتن یک شارد برای یک فرایند واحد جداگانه سنجیده شود؛ اضافه‌کردن شاردهای بیشتر، محدودیت همان فرایند را برطرف نمی‌کند.

## یادداشت امنیتی

توکن یک‌بارمصرف باید تصادفی و غیرقابل حدس، فقط به‌صورت hash سمت سرور ذخیره‌شده، محدود به یک فرایند و زمان رأی‌گیری، و در برابر replay یک‌بارمصرف باشد. اعتبارسنجی توکن، ثبت مشارکت هویتی، درج رأی، تولید رسید، افزایش زنجیره و ثبت outbox باید در یک تراکنش اتمیک انجام شوند. این اتمیک‌بودن از ثبت نیمه‌کاره جلوگیری می‌کند، اما چون داده‌های دو حوزه در یک تراکنش سرور پردازش می‌شوند به‌تنهایی جداسازی رمزنگاری‌شده ایجاد نمی‌کند. در طرح حاضر امضای کور لازم نیست؛ زیرا پیوند مستقیم و پایدار رکورد هویت به گزینهٔ رأی از مدل رابطه‌ای حذف شده و ریسک هم‌بستگی زمانی/جغرافیایی و لاگ ممتاز پذیرفته شده است.

---

**# 1. Country**

**## 1.1. Definition**

Country root entity for the geographic hierarchy. All Province, County,
and Settlement records descend from it.

A Country is operationally valid only when is_active = 1.

**## 1.2. Attributes**

| **Attribute** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| country_id | SMALLINT UNSIGNED | No | AUTO_INCREMENT | Surrogate primary key. |
| country_code | SMALLINT UNSIGNED | No | — | Unique official country code within system scope. |
| name_fa | VARCHAR(100) | No | — | Persian country name. |
| is_active | TINYINT(1) | No | 1 | Operational status. |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | UTC creation DATETIME. |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | UTC last-update DATETIME. |

**## 1.3. Constraints and Rules**

- country_id is the primary key.

- country_code is NOT NULL and unique.

- name_fa is NOT NULL.

- Physical deletion is prohibited.

- Lifecycle is controlled through is_active.

- is_active = 1 means operationally valid; 0 means inactive.

- Any is_active change must be recorded in an audit table.

- All DATETIMEs are stored in UTC.

- created_at is assigned automatically on insert.

- updated_at is maintained automatically by the database.

**## 1.4. Relationships**

- One-to-Many -\> Province

**## 1.5. Indexes**

- pk_countries (country_id)

- uq_country_code (country_code)

- idx_country_is_active (is_active)

**# 2. Province**

**## 2.1. Definition**

Province is the intermediate administrative layer between Country and
County.

A Province is operationally valid only when it and its parent Country
are active.

**## 2.2. Attributes**

| **Attribute** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| province_id | SMALLINT UNSIGNED | No | AUTO_INCREMENT | Surrogate primary key. |
| country_id | SMALLINT UNSIGNED | No | — | FK to Country. |
| province_code | SMALLINT UNSIGNED | No | — | Unique official provincial code within system scope. |
| name_fa | VARCHAR(100) | No | — | Persian province name. |
| is_active | TINYINT(1) | No | 1 | Operational status. |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | UTC creation DATETIME. |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | UTC last-update DATETIME. |

**## 2.3. Constraints and Rules**

- province_id is the primary key.

- country_id is NOT NULL and references countries.country_id.

- province_code is NOT NULL and unique.

- name_fa is NOT NULL.

- Physical deletion is prohibited.

- Lifecycle is controlled through is_active.

- is_active = 1 means operationally valid; 0 means inactive.

- A Province is valid only if both Province and parent Country are
  active.

- Any is_active change must be recorded in an audit table.

- Inactivation propagates downward to all descendant County and
  Settlement records.

- Automatic propagation applies only to deactivation.

- Reactivation must be explicit and controlled.

- All DATETIMEs are stored in UTC.

- created_at is assigned automatically on insert.

- updated_at is maintained automatically by the database.

**## 2.4. Relationships**

- Many-to-One -\> Country

- One-to-Many -\> County

**## 2.5. Indexes**

- pk_provinces (province_id)

- idx_province_country_id (country_id)

- uq_province_code (province_code)

- idx_province_is_active (is_active)

**# 3. County**

**## 3.1. Definition**

County is the administrative unit below Province and above Settlement.

A County is operationally valid only when it, its parent Province, and
its parent Country are active.

**## 3.2. Attributes**

| **Attribute** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| county_id | SMALLINT UNSIGNED | No | AUTO_INCREMENT | Surrogate primary key. |
| province_id | SMALLINT UNSIGNED | No | — | FK to Province. |
| county_code | SMALLINT UNSIGNED | No | — | Unique official county code within system scope. |
| name_fa | VARCHAR(100) | No | — | Persian county name. |
| is_active | TINYINT(1) | No | 1 | Operational status. |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | UTC creation DATETIME. |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | UTC last-update DATETIME. |

**## 3.3. Constraints and Rules**

- county_id is the primary key.

- province_id is NOT NULL and references provinces.province_id.

- county_code is NOT NULL and unique.

- name_fa is NOT NULL.

- Physical deletion is prohibited.

- Lifecycle is controlled through is_active.

- is_active = 1 means operationally valid; 0 means inactive.

- A County is valid only if County, parent Province, and parent Country
  are active.

- Any is_active change must be recorded in an audit table.

- Inactivation propagates downward to all descendant Settlement records.

- Automatic propagation applies only to deactivation.

- Reactivation must be explicit and controlled.

- All DATETIMEs are stored in UTC.

- created_at is assigned automatically on insert.

- updated_at is maintained automatically by the database.

**## 3.4. Relationships**

- Many-to-One -\> Province

- One-to-Many -\> Settlement

**## 3.5. Indexes**

- pk_counties (county_id)

- idx_county_province_id (province_id)

- uq_county_code (county_code)

- idx_county_is_active (is_active)

**# 4. Settlement**

**## 4.1. Definition**

Settlement is the lowest geographic level in the hierarchy.

A Settlement is operationally valid only when it, its parent County, its
parent Province, and its parent Country are active.

**## 4.2. Attributes**

| **Attribute** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| settlement_id | INT UNSIGNED | No | AUTO_INCREMENT | Surrogate primary key. |
| county_id | SMALLINT UNSIGNED | No | — | FK to County. |
| name_fa | VARCHAR(100) | No | — | Persian settlement name. |
| settlement_code | SMALLINT UNSIGNED | No | — | Unique official settlement code within system scope. |
| is_active | TINYINT(1) | No | 1 | Operational status. |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | UTC creation DATETIME. |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | UTC last-update DATETIME. |

**## 4.3. Constraints and Rules**

- settlement_id is the primary key.

- county_id is NOT NULL and references counties.county_id.

- name_fa is NOT NULL.

- settlement_code is NOT NULL and unique.

- Physical deletion is prohibited.

- Lifecycle is controlled through is_active.

- is_active = 1 means operationally valid; 0 means inactive.

- A Settlement is valid only if Settlement, parent County, parent
  Province, and parent Country are active.

- Any is_active change must be recorded in an audit table.

- All DATETIMEs are stored in UTC.

- created_at is assigned automatically on insert.

- updated_at is maintained automatically by the database.

**## 4.4. Relationships**

- Many-to-One -\> County

- Operational References -\> UserProfile, SupportRecord,
  EligibilitySnapshot, and other geography-dependent operational logs

**## 4.5. Indexes**

- pk_settlements (settlement_id)

- idx_settlement_county_id (county_id)

- uq_settlement_code (settlement_code)

- idx_settlement_is_active (is_active)

**## Cross-cutting policy**

- All four entities use the same lifecycle model: is_active instead of
  physical deletion.

- is_active represents the direct operational status of the entity
  itself; effective operational validity is determined dynamically by
  evaluating the entity together with all of its ancestors in the
  hierarchy.

- All is_active transitions are audited.

- Deactivation applies only to the targeted entity record and does not
  physically RESTRICT to descendant rows.

- Reactivation is never automatic and must be performed explicitly.

- Integrity: All foreign key relationships follow the RESTRICT policy;
  physical deletion or code changes are not allowed.

- Logic: The “operational validity” state of an entity is a dynamic
  value and must not be stored in the database; it is the state of the
  is_active function of the entity itself and all entities higher in the
  hierarchy.

- All DATETIMEs are UTC and DB-managed.

- country_code/province_code/county_code/settlement_code and name_fa
  remain the stable naming set across the hierarchy.

**# Entity 5: OTP**

**## 5.1. Definition**

The OTP entity represents a short-lived One-Time Password token
generated for user authentication, registration, or password reset
actions. It enforces a strict purpose-bound relationship using either a
registration draft or an existing user account.

**## 5.2. Attributes**

| **Column** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| otp_id | BIGINT UNSIGNED AUTO_INCREMENT | No | — | Primary key of the OTP record. |
| mobile_hash | BINARY(32) | No | — | HMAC-SHA-256 hash of the normalized mobile number used for secure lookup and OTP binding context. |
| mobile_encrypted | VARBINARY(255) | No | — | AES-256-GCM encrypted normalized mobile number for controlled recovery or display. |
| purpose | VARCHAR(25) | No | — | Business purpose of the OTP. Foreign key referencing otp_purpose_lookup.purpose_code. |
| otp_nonce | BINARY(16) | No | — | Cryptographically secure random nonce generated per OTP issuance and used in code_hash derivation. |
| code_hash | BINARY(32) | No | — | Context-bound HMAC-SHA-256 digest of the OTP code using server-side secret and issuance context. Raw OTP must never be stored. |
| state | VARCHAR(15) | No | ‘Issued’ | Current lifecycle state. Foreign key referencing otp_state_lookup.state_code. |
| issued_at | DATETIME | No | — | UTC DATETIME of OTP issuance. |
| expires_at | DATETIME | No | — | UTC DATETIME after which the OTP becomes invalid. |
| verified_at | DATETIME | Yes | NULL | UTC DATETIME set only when the OTP is successfully verified. |
| failed_at | DATETIME | Yes | NULL | UTC DATETIME set only when the OTP transitions to Failed. |
| attempt_count | TINYINT UNSIGNED | No | 0 | Number of verification attempts made against this OTP. |
| max_attempt_count | TINYINT UNSIGNED | No | 3 | Maximum number of allowed verification attempts before failure. |
| delivery_channel | VARCHAR(15) | No | ‘telegram’ | Delivery channel used for OTP transmission. Allowed values: telegram, sms, voice. |
| registration_draft_id | BIGINT UNSIGNED | Yes | NULL | Optional foreign key to RegistrationDraft.registration_draft_id. Required when purpose = 'registration'. |
| account_id | BIGINT UNSIGNED | Yes | NULL | Optional foreign key to UserAccount.account_id. Required when purpose = 'password_reset'. |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | UTC DATETIME of record creation. |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | UTC DATETIME of last update. |

**### 5.2.1. Lookup Table: otp_state_lookup**

| **Attribute** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| state_code | VARCHAR(15) | No | PK | Unique state code. |
| state_name | VARCHAR(100) | No | — | Human-readable state name. |
| is_active | TINYINT(1) | No | 1 | Indicates whether the lookup row is active. |
| display_order | INT | No | 0 | Presentation order. |

- Seed values: Issued, Verified, Expired, Failed

**### 5.2.2. Lookup Table: otp_purpose_lookup**

| **Attribute** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| purpose_code | VARCHAR(25) | No | PK | Unique purpose code. |
| purpose_name | VARCHAR(100) | No | — | Human-readable purpose name. |
| is_active | TINYINT(1) | No | 1 | Indicates whether the lookup row is active. |
| display_order | INT | No | 0 | Presentation order. |

- Seed values: registration, password_reset

**###** **5.3. Constraints and Rules**

- Mobile numbers must be normalized before hashing and encryption.

- Raw OTP values must never be stored.

- code_hash must be derived using HMAC-SHA-256 over:

  - otp_code

  - purpose

  - mobile_hash

  - otp_nonce

- purpose must reference otp_purpose_lookup(purpose_code).

- state must reference otp_state_lookup(state_code).

- delivery_channel must be limited to telegram, sms, and voice.

- expires_at must be greater than issued_at.

- attempt_count must never exceed max_attempt_count.

- verified_at must be NULL unless state = ‘Verified’.

- failed_at must be NULL unless state = ‘Failed’.

- Purpose-based integrity:

  - If purpose = 'registration', then registration_draft_id must be NOT
    NULL and account_id must be NULL.

  - If purpose = 'password_reset', then account_id must be NOT NULL and
    registration_draft_id must be NULL.

- Single Active OTP Constraint: For each mobile_hash + purpose, at most
  one active OTP may exist in Issued state with expires_at \> NOW. Any
  previous active OTP for the same mobile_hash + purpose must be
  invalidated (transitioned to Expired) before issuing a new one.

- Atomic Block Invalidation: Any transition of the corresponding
  OTPThrottleWindow for a mobile_hash to the Blocked state must
  atomically transition all associated active OTP records (where state =
  ‘Issued’) to state = ‘Failed’ and set failed_at = CURRENT_TIMESTAMP.

- Referential Integrity Policy: All OTP foreign keys MUST enforce ON
  UPDATE RESTRICT and ON DELETE RESTRICT to preserve the audit trail and
  prevent orphaned OTP records. - purpose -\>
  otp_purpose_lookup(purpose_code) (RESTRICT/RESTRICT) - state -\>
  otp_state_lookup(state_code) (RESTRICT/RESTRICT) -
  registration_draft_id -\> registration_draft(registration_draft_id)
  (RESTRICT/RESTRICT) - account_id -\> user_account(user_id)
  (RESTRICT/RESTRICT)

**### 5.3.1. State Transitions**

| **From State** | **To State** | **Trigger Condition** |
|:--:|:--:|:--:|
| Issued | Verified | Successful matching of code_hash and CURRENT_TIMESTAMP\<= expires_at. |
| Issued | Expired | CURRENT_TIMESTAMP\> expires_at OR invalidation due to new OTP issuance for the same mobile_hash + purpose. |
| Issued | Failed | attempt_count reaches max_attempt_count OR corresponding OTPThrottleWindow transitions to ‘Blocked’. |
| Verified | None | Terminal state. |
| Expired | None | Terminal state. |
| Failed | None | Terminal state. |

**## 5.4. Relationships**

- RegistrationDraft: Many-to-One via registration_draft_id referencing
  RegistrationDraft.registration_draft_id .(nullable, required if
  purpose = ‘registration’).

- UserAccount: Many-to-One via account_id referencing
  UserAccount.account_id (nullable, required if purpose =
  ‘password_reset’).

- OTP State Lookup: Many-to-One via state referencing
  otp_state_lookup.state_code.

- OTP Purpose Lookup: Many-to-One via purpose referencing
  otp_purpose_lookup.purpose_code.

**## 5.5. Indexes**

- PRIMARY KEY (otp_id)

- INDEX idx_otp_lookup (mobile_hash, purpose, state)

- INDEX idx_otp_registration_draft (registration_draft_id) WHERE
  registration_draft_id IS NOT NULL

- INDEX idx_otp_account (account_id) WHERE account_id IS NOT NULL

**## 5.6. DDL Notes**

- Implement check constraints for delivery_channel to strictly enforce
  the allowed channel values.

**# Entity 6: OTPThrottleWindow**

**## 6.1. Definition**

OTPThrottleWindow is a security enforcement entity operating
independently to track, monitor, and restrict rate requests and
validation failures associated with specific mobile numbers. It serves
as the primary barrier against brute-force attempts and SMS/Telegram
gateway resource exhaustion.

**## 6.2. Attributes**

| **Column** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| otp_throttle_window_id | BIGINT UNSIGNED AUTO_INCREMENT | No | — | Physical primary key. |
| mobile_hash | BINARY(32) | No | — | HMAC-SHA-256 hash of the E.164 normalized mobile number. |
| mobile_encrypted | VARBINARY(255) | No | — | AES-256-GCM encrypted mobile number for recovery/auditing. |
| window_started_at | DATETIME | No | — | Start DATETIME of the current tracking window (UTC). |
| window_ends_at | DATETIME | No | — | End DATETIME of the current tracking window (UTC). Set to 15 minutes after start. |
| send_count | TINYINT UNSIGNED | No | 0 | Number of OTP tokens dispatched within this window. |
| verify_failed_count | TINYINT UNSIGNED | No | 0 | Cumulative failed validation attempts across all tokens inside this window. |
| state | VARCHAR(15) | No | — | Window state. Foreign key referencing otp_throttle_window_state_lookup.state_code. |
| penalty_tier | TINYINT UNSIGNED | No | 0 | Tracking tier for progressive blocking penalty: 0 (none), 1 (15m), 2 (30m), 3 (60m). |
| last_sent_at | DATETIME | No | — | UTC DATETIME of the last sent OTP request to enforce inter-request intervals. |
| throttled_until | DATETIME | Yes | NULL | Cooldown expiration DATETIME for temporary throttling (UTC). |
| blocked_until | DATETIME | Yes | NULL | Penalty expiration DATETIME for severe blocking (UTC). |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | Physical record creation DATETIME. |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Last update DATETIME. |

**### 6.2.1. Lookup Table: otp_throttle_window_state_lookup**

| **Attribute** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| state_code | VARCHAR(15) | No | PK | Unique state code. |
| state_name | VARCHAR(100) | No | — | Human-readable state name. |
| is_active | TINYINT(1) | No | 1 | Indicates whether the lookup row is active. |
| display_order | INT | No | 0 | Presentation order. |

- Seed values: Open, Throttled, Blocked, Expired

**## 6.3. Constraints and Rules**

**### 6.3.1. Policy Constraints & Values**

- Window Duration: Every new window defaults to exactly 15 minutes (900
  seconds).

- Window Duration: window_ends_at must be set to window_started_at +
  INTERVAL 15 MINUTE at the moment of record creation.

- Cumulative Failure Limit: Maximum of 5 cumulative verification
  failures allowed across all active tokens within a single window.
  Reaching 5 failures instantly transitions the state to Blocked.

- Max Dispatches: Maximum of 3 dispatches allowed within a single
  window. Exceeding 3 dispatches transitions the state to Throttled.

- Inter-Request Cooldown: A minimum of 60 seconds must elapse between
  two consecutive OTP requests for the same mobile_hash. Requests
  submitted before CURRENT_TIMESTAMP\>= last_sent_at + 60 seconds must
  be rejected.

- Progressive Penalty: When transitioning to Blocked, the penalty_tier
  increments by 1 (up to a maximum of 3). The blocked_until is
  calculated based on the new tier:

  - Tier 1: blocked_until = CURRENT_TIMESTAMP+ 15 minutes

  - Tier 2: blocked_until = CURRENT_TIMESTAMP+ 30 minutes

  - Tier 3: blocked_until = CURRENT_TIMESTAMP+ 60 minutes

- If a user triggers another block within a 24-hour cool-off period, the
  penalty_tier increments. If the cool-off period passes without a new
  block, the penalty_tier resets to 0.

**### 6.3.2. State Dependency Controls**

- If state = 'Open' → throttled_until and blocked_until must be NULL.

- If state = 'Throttled' → throttled_until must be NOT NULL and
  blocked_until must be NULL.

- If state = 'Blocked' → blocked_until must be NOT NULL and
  throttled_until must be NULL.

- If state = 'Expired' → Window counters are no longer active, lock
  states are resolved.

**### 6.3.3. State Transitions**

- Initial State: Open

- Terminal State: Expired

- Allowed Transitions:

  - Open → Throttled (when send_count \> 3 within the current window)

  - Open → Blocked (when verify_failed_count \>= 5 within the current
    window)

  - Open → Expired (automatically when current UTC time exceeds
    window_ends_at)

  - Throttled → Blocked (if a new validation failure occurs during a
    temporary throttle window)

  - Throttled → Expired (when current time exceeds throttled_until)

  - Blocked → Expired (when current time exceeds blocked_until)

**## 6.4. Relationships**

- To keep OTP data logically separable from user profiles, this entity does not contain a physical foreign key to profile tables. This is a domain boundary only and does not itself implement physical sharding. Horizontal routing is governed by the shard placement contract in the DRM V44 architecture section. Verification mapping occurs logically in the application layer using the mobile_hash.

- OTP Throttle Window State Lookup: Many-to-One via state referencing
  otp_throttle_window_state_lookup.state_code (ON DELETE RESTRICT ON
  UPDATE RESTRICT).

**## 6.5. Indexes**

- PRIMARY KEY (otp_throttle_window_id)

- UNIQUE KEY uq_throttle_active_lookup (mobile_hash, state,
  window_ends_at)

- INDEX idx_throttle_limits (throttled_until, blocked_until)

**## 6.6. DDL Notes**

- The last_sent_at column must be updated atomically to prevent race
  conditions during concurrent user requests.

**# Entity 7: IntegrationInboxEntry**

**## 7.1. Definition**

The IntegrationInboxEntry serves as an immutable, low-dependency audit
ledger for incoming external messaging events (e.g., Telegram Webhook
updates, SMS callback receipts).

**## 7.2. Attributes**

| **Column** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| inbox_entry_id | BIGINT UNSIGNED AUTO_INCREMENT | No | — | Primary key. |
| channel | VARCHAR(32) | No | — | Integration medium. Enum: ‘telegram’, ‘sms’, ‘system’. |
| external_message_id | VARCHAR(64) | Yes | NULL | The identifier sent by the external service provider. |
| correlation_hash | BINARY(32) | Yes | NULL | HMAC-SHA-256 hash containing a unique, non-reversible combination of transaction identifiers (e.g., combining the OTP’s nonce and lookup values). Used for matching incoming events without storing plaintext user identities. |
| payload | JSON | No | — | The raw, unparsed webhook or API callback data. |
| processed_status | VARCHAR(20) | No | ‘Pending’ | Processing status. Foreign key referencing integration_inbox_status_lookup.status_code. |
| received_at | DATETIME | No | — | UTC DATETIME when the incoming record was stored. |
| processed_at | DATETIME | Yes | NULL | UTC DATETIME when the record was processed and actioned. |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | UTC DATETIME of record creation. |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | UTC DATETIME of last update. |

**## 7.2.1. Lookup Table: integration_inbox_status_lookup**

| **Attribute** | **Type** | **Nullable** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| status_code | VARCHAR(20) | No | PK | Unique status code. |
| status_name | VARCHAR(100) | No | — | Human-readable status name. |
| is_active | TINYINT(1) | No | 1 | Indicates whether the lookup row is active. |
| display_order | INT | No | 0 | Presentation order. |

- Seed values: Pending, Processed, Failed, Ignored

**## 7.3. Constraints and Rules**

1.  Immutability: Once written, channel, external_message_id,
    correlation_hash, payload, and received_at must never be modified.
    Only processed_status and processed_at are eligible for single-state
    transitions.

2.  Correlation Matching: The application layer must compute the hash of
    incoming parameters matching the OTP setup to populate
    correlation_hash for resolution against the active OTP nonce
    context.

3.  No Direct User Reference: No physical foreign keys or direct
    plaintext references to UserAccount or UserProfile are allowed.

4.  Payload Encryption: To comply with privacy standards, if the payload
    JSON contains identifiable data, it must be encrypted at rest using
    the system’s master key, or the retention period must be strictly
    limited to 7 days before automated pruning

**### 7.3.1. State Transitions**

| **From State** | **To State** | **Trigger Condition** |
|:--:|:--:|:--:|
| Pending | Processed | Webhook successfully matched, validated, and related action completed. |
| Pending | Failed | Processing failed due to validation errors or internal handler failure. |
| Pending | Ignored | Message judged irrelevant or duplicated. |

**##7.4. Relationships**

- Processed Status Lookup: Many-to-One via processed_status referencing
  integration_inbox_status_lookup.status_code.

**## 7.5. Indexes**

- PRIMARY KEY (inbox_entry_id)

- INDEX idx_inbox_correlation (correlation_hash, processed_status)

- INDEX idx_inbox_received (received_at)

**## 7.6. DDL Notes**

- JSON data validation must be performed at the application ingestion
  level.

**# 8. RegistrationDraft**

**## 8.1. Supporting Lookup Entities**

**### 8.1.1. RegistrationDraftStateLookup**

**#### 8.1.1.1. Definition**

A static lookup table that defines the valid lifecycle states of a
registration draft. It establishes the terminal and active boundaries of
the onboarding process.

**#### 8.1.1.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| **state_code** | VARCHAR(15) | No |  | Unique state code (e.g., ‘Initiated’, ‘Verified’, ‘Completed’, ‘Expired’). Primary Key. |
| **state_name** | VARCHAR(100) | No |  | Human-readable name of the state. |
| **is_active** | TINYINT(1) | No | 1 | Determines if this state can currently be applied to new transitions. |
| **is_default** | TINYINT(1) | No | 0 | Indicates the default state when a draft is created. Exactly one row must be 1 (‘Initiated’). |
| **display_order** | INT UNSIGNED | No |  | Sequence order for UI/Reporting. |

**#### 8.1.1.3. Constraints & Business Rules**

- **Single Default:** An application-level or database trigger
  constraint must enforce that exactly one record has is_default = 1.

**#### 8.1.1.4. Relationships**

- **One-to-Many with RegistrationDraft:**

  - RegistrationDraftStateLookup.state_code is referenced by
    RegistrationDraft.state_code.

**#### 8.1.1.5. Indexes**

- **Primary Key:** PRIMARY KEY (state_code)

- **Unique Constraints:** UNIQUE KEY uq_state_display_order
  (display_order)

**### 8.1.2. RegistrationDraftStepLookup**

**#### 8.1.2.1. Definition**

A static lookup table that represents the individual sequential steps
(wizard steps) within the active registration workflow.

**#### 8.1.2.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| **step_code** | VARCHAR(30) | No |  | Unique step identifier (e.g., ‘Mobile_Verification’, ‘National_ID_Verification’, ‘Geographic_Selection’, ‘Password_Selection’, ‘Biometric_Setup’, ‘Final_Review’). Primary Key. |
| **step_name** | VARCHAR(100) | No |  | Human-readable step name. |
| **is_active** | TINYINT(1) | No | 1 | Indicates if the step is currently enabled in the workflow. |
| **is_default** | TINYINT(1) | No | 0 | Indicates the default entry step for new drafts. Exactly one row must be 1 (‘Mobile_Verification’). |
| **display_order** | INT UNSIGNED | No |  | Operational flow sequence order. |

**#### 8.1.2.3. Constraints & Business Rules**

- **Single Default:** An application-level or database trigger
  constraint must enforce that exactly one record has is_default = 1.

**#### 8.1.2.4. Relationships**

- **One-to-Many with RegistrationDraft:**

  - RegistrationDraftStepLookup.step_code is referenced by
    RegistrationDraft.step_code.

**#### 8.1.2.5. Indexes**

- **Primary Key:** PRIMARY KEY (step_code)

- **Unique Constraints:** UNIQUE KEY uq_step_display_order
  (display_order)

**## 8.2. Main RegistrationDraft**

**### 8.2.1. Definition**

Represents a temporary, stateful container for the user registration and
onboarding workflow. It enforces a strict 30-minute lifecycle and
ensures that sensitive data (Mobile/National ID) is protected via
encryption and cryptographic hashing. This entity serves as the “Source
of Truth” during the onboarding process before the atomic creation of a
permanent UserProfile and UserAccount.

**### 8.2.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| **registration_draft_id** | BIGINT UNSIGNED | No | *Identity* | Internal surrogate primary key. |
| **state_code** | VARCHAR(15) | No |  | Reference to RegistrationDraftStateLookup. |
| **step_code** | VARCHAR(30) | No |  | Reference to RegistrationDraftStepLookup. |
| **idempotency_key** | VARCHAR(80) | No |  | Unique token to prevent duplicate request processing. |
| **mobile_hash** | BINARY(32) | No |  | **HMAC-SHA-256** hash of the normalized E.164 mobile number. |
| **mobile_encrypted** | VARBINARY(255) | Yes | NULL | **AES-256-GCM** encrypted E.164 mobile number. |
| **national_id_hash** | BINARY(32) | Yes | NULL | **HMAC-SHA-256** hash of the National ID. Required from National_ID_Verification step. |
| **national_id_encrypted** | VARBINARY(255) | Yes | NULL | **AES-256-GCM** encrypted National ID. |
| **key_version** | SMALLINT UNSIGNED | Yes | NULL | Envelope encryption key version. |
| **settlement_id** | SMALLINT UNSIGNED | Yes | NULL | Geographic endpoint anchor. Required from Geographic_Selection step onwards. |
| **created_at** | DATETIME | No | CURRENT_TIMESTAMP | Record creation DATETIME(UTC). |
| **updated_at** | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Last modification DATETIME (UTC). Auto-updates on edit in MySQL. |
| **expires_at** | DATETIME | No |  | Expiration DATETIME (created_at + 30 minutes). |
| **completed_at** | DATETIME | Yes | NULL | DATETIME when the draft was successfully completed. |
| **active_mobile_hash** | BINARY(32) | Yes | *STORED GENERATED* | Stored Generated Column: IF(state_code IN ('Initiated', 'Verified'), mobile_hash, NULL). Enforces one active draft per mobile. |
| **active_national_id_hash** | BINARY(32) | Yes | *STORED GENERATED* | Stored Generated Column: IF(state_code IN ('Initiated', 'Verified') AND step_code NOT IN ('Mobile_Verification'), national_id_hash, NULL). Enforces one active draft per National ID. |

**### 8.2.3. Constraints & Business Rules**

1.  **Data Normalization & Encryption Standards:**

    - **Mobile Normalization:** Prior to hashing and encryption, the
      mobile number must be normalized to the E.164 format (e.g.,
      +989121234567).

    - **Cryptographic Hashing:** mobile_hash and national_id_hash use
      HMAC-SHA-256 to verify unique identity drafts without decrypting
      data.

    - **Data Wipe Rule:** Once the transaction shifts state_code to
      Completed, all encrypted data (mobile_encrypted,
      national_id_encrypted) and key_version must be set to NULL
      (cryptographic erasure).

2.  **Lifecycle & Expiry Rules:**

    - **Lifespan:** A draft is valid for exactly 30 minutes.
      Database-level constraints must enforce:

- CHECK (expires_at = (created_at + INTERVAL 30 MINUTE))

  - **Terminal State Integrity:** Once a draft transitions to Completed
    or Expired, it is immutable.

- CHECK ( (state_code = 'Completed' AND completed_at IS NOT NULL) OR
  (state_code != 'Completed' AND completed_at IS NULL) )

3.  **Step-Based Validation Rules (Not-Null Transitions):**

    - **National ID Mandatoriness:** From the step
      National_ID_Verification and all subsequent steps, the national
      identity cryptographic data must not be empty.

- CHECK ( (step_code IN ('Mobile_Verification') OR (national_id_hash IS
  NOT NULL AND national_id_encrypted IS NOT NULL AND key_version IS NOT
  NULL)) )

  - **Geographic Mandatoriness:** From the step Geographic_Selection and
    all subsequent steps, the geographic root identifier must not be
    empty.

- CHECK ( (step_code IN ('Mobile_Verification',
  'National_ID_Verification') OR settlement_id IS NOT NULL) )

4.  **Geographic Integrity:**

    - The settlement_id acts as the root geographic anchor. The Country,
      Province, and County are strictly derived and validated from this
      point.

> **5. Identity and Cooldown Gatekeeping Rule:**
>
> To minimize resources and prevent system abuse, the registration API
> must actively block progression during the following steps without
> persisting a rejected database state (the draft remains in its current
> state until natural expiration):
>
> o **Mobile Verification Step:**
>
> After normalizing the mobile number and computing mobile_hash, the
> system must verify that no active UserProfile exists with the same
> mobile_hash. If an active profile exists, the current interactive
> request must stop immediately and return the appropriate business
> response. The draft remains in its current state and may naturally
> expire according to its lifecycle rules.
>
> o **National ID Verification Step:**
>
> After normalizing the National ID and computing national_id_hash, and
> before invoking expensive external verification services, the system
> must verify: i. no active UserProfile exists with the same
> national_id_hash; and ii. no NationalIdCooldownLedger record exists
> for which CURRENT_TIMESTAMP \< cooldown_until. If either condition
> fails, the current interactive request must stop immediately and
> return the appropriate business response. No new lifecycle state is
> created. The draft remains in its current state and may naturally
> expire. c. Final Atomic Completion Check: The final transaction that
> creates UserProfile and UserAccount must repeat the mobile uniqueness,
> National ID uniqueness, and National ID cooldown checks to prevent
> race conditions.

**### 8.2.4. Relationships**

- **Many-to-One with RegistrationDraftStateLookup:**

  - RegistrationDraft.state_code references
    RegistrationDraftStateLookup.state_code

  - *On Update: Restrict \| On Delete: Restrict*

- **Many-to-One with RegistrationDraftStepLookup:**

  - RegistrationDraft.step_code references
    RegistrationDraftStepLookup.step_code

  - *On Update: Restrict \| On Delete: Restrict*

- **Many-to-One with Settlement:**

  - RegistrationDraft.settlement_id references Settlement.settlement_id

  - *On Update: Restrict \| On Delete: Restrict*

**### 8.2.5. Indexes**

- **Primary Key:**

  - PRIMARY KEY (registration_draft_id)

- **Unique Constraints:**

  - UNIQUE KEY uq_registration_drafts_idempotency (idempotency_key)

  - UNIQUE KEY uq_active_draft_per_mobile (active_mobile_hash) *(MySQL
    8.0 ignores NULL values, permitting multiple completed/expired
    drafts but restricting active duplicates).*

  - UNIQUE KEY uq_active_draft_per_national_id (active_national_id_hash)
    *(Enforces a single active registration draft per National ID
    starting from the National_ID_Verification step).*

- **Performance Indexes:**

  - INDEX idx_registration_drafts_expires (expires_at, state_code)

  - INDEX idx_registration_drafts_mobile_hash (mobile_hash)

**# 9. UserProfile**

**## 9.1. Definition**

UserProfile is the authoritative identity profile of a registered user
in VetoApp. It stores the user’s core identity anchors, protected mobile
and national-ID identifiers, active status, and enforced geographic
scope.

The entity uses a shared primary key with UserAccount to guarantee a
strict one-to-one identity/account structure. The user’s final geography
is anchored at the Settlement level, while parent geographic references
are stored for consistency checks, filtering, quorum calculation, and
geo-scoped process execution.

**## 9.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| **user_id** | BIGINT UNSIGNED | No | — | Shared Primary Key. Also references the corresponding UserAccount.user_id in a strict 1:1 identity/account model. |
| **mobile_hash** | BINARY(32) | Yes | NULL | HMAC-SHA-256 unique identifier hash of the normalized E.164 mobile number. Nullified upon voluntary account closure to release the unique constraint. |
| **mobile_encrypted** | VARBINARY(255) | Yes | NULL | AES-256-GCM encrypted mobile phone number (E.164 format) for system communication and account recovery. Protected via Envelope Encryption. Nullified upon voluntary account closure. |
| **national_id_hash** | BINARY(32) | Yes | NULL | HMAC-SHA-256 unique identifier hash of the user’s national identity card number to prevent duplicate active profiles. Nullified upon voluntary account closure. |
| **national_id_encrypted** | VARBINARY(255) | Yes | NULL | AES-256-GCM encrypted National ID card number for recovery or administrative verification. Protected via Envelope Encryption. Nullified upon voluntary account closure. |
| **settlement_id** | SMALLINT UNSIGNED | No | — | Final and authoritative geographic leaf node assigned to the user. References Settlement.settlement_id. |
| **county_id** | SMALLINT UNSIGNED | No | — | Materialized parent county identifier derived from the selected settlement_id. Stored for query efficiency and must remain hierarchy-consistent. |
| **province_id** | SMALLINT UNSIGNED | No | — | Materialized parent province identifier derived from the selected settlement_id. Stored for query efficiency and must remain hierarchy-consistent. |
| **country_id** | SMALLINT UNSIGNED | No | — | Materialized parent country identifier derived from the selected settlement_id. Stored for query efficiency and must remain hierarchy-consistent. |
| **is_active** | TINYINT(1) | No | 1 | Global active status of the user identity. If set to 0, all active authentication sessions associated with the user must be invalidated atomically by application/service transaction orchestration. |
| **created_at** | DATETIME | No | CURRENT_TIMESTAMP | UTC DATETIME indicating profile creation time. |
| **geo_updated_at** | DATETIME | No | CURRENT_TIMESTAMP | geo_updated_at must be updated only when a geographic reassignment is successfully accepted. It must not use ON UPDATE CURRENT_TIMESTAMP. |
| **initial_geo_selected_at** | DATETIME | No | CURRENT_TIMESTAMP | UTC DATETIME indicating the first successful geographic selection during registration completion. On first creation, it must equal created_at and geo_updated_at. |

**## 9.3. Constraints & Business Rules**

1.  **Shared Primary Key Model:**

user_id is the primary key of UserProfile and participates in a strict
shared-primary-key one-to-one relationship with UserAccount.

A profile cannot exist without its corresponding account identity chain,
and a second profile for the same user is structurally impossible.

2.  **Anonymous External Interaction Boundary:**

Direct usage of user_id in those domains is prohibited by architecture.

3.  **Identity Uniqueness Enforcements (Sybil Protection):**

    - mobile_hash must be globally unique across all profiles when
      present (not NULL). Multiple active accounts cannot share the same
      mobile identifier.

    - national_id_hash must be globally unique across all profiles when
      present (not NULL). Each physical person is restricted to a single
      active registered profile.

4.  **Active Profile Identity Integrity (CHECK Constraint):**

To guarantee that active users always have verified identity records,
the database must enforce the following rule using a MySQL 8.0 CHECK
constraint:

CONSTRAINT chk_user_profile_active_identity CHECK (is_active = 0 OR
(mobile_hash IS NOT NULL AND mobile_encrypted IS NOT NULL AND
national_id_hash IS NOT NULL AND national_id_encrypted IS NOT NULL))

5.  **Voluntary Closure Anonymization & Cooldown Flow:**

> When a user voluntarily closes their account, the application must
> execute one atomic transaction that:
>
> a\. Reads the current national_id_hash from UserProfile.
>
> b\. Inserts or updates NationalIdCooldownLedger using that
> national_id_hash and applies the progressive cooldown rule.
>
> c\. Sets UserProfile.is_active = 0.
>
> d\. Sets UserAccount.account_status = 'Closed'.
>
> e\. Nullifies the identity fields in UserProfile:
>
> mobile_hash = NULL,
>
> mobile_encrypted = NULL,
>
> national_id_hash = NULL,
>
> national_id_encrypted = NULL.
>
> f\. Invalidates all active AuthSession records belonging to the user.
>
> The transaction must commit only if all steps succeed. If any step
> fails, the entire transaction must roll back.

6.  **Cryptographic Protection of Identity Fields:**

    - Plain-text mobile numbers and national IDs must never be stored in
      database fields. They must be encrypted (mobile_encrypted,
      national_id_encrypted) utilizing an approved cryptographic key
      management service (KMS) or dynamic envelope encryption using
      AES-256-GCM.

    - Identity hashes (mobile_hash, national_id_hash) must use a strong,
      peppered HMAC-SHA-256 configuration to prevent dictionary attacks
      on stored hashes.

7.  **Geographic Leaf Authority Rule:**

settlement_id is the authoritative user geography anchor.

The user’s final location is always defined at the Settlement level, not
at province, county, or country level alone.

8.  **Strict Geographic Hierarchy Enforcement:**

country_id, province_id, and county_id are required denormalized parent
references derived from settlement_id.

They must always match the actual geographic hierarchy of the referenced
settlement.

Any insert or update that causes hierarchy mismatch must be rejected.

10. **Non-Nullable Geography Rule:**

settlement_id, county_id, province_id, and country_id are all mandatory
and must never be NULL.

The system does not permit partially assigned geographic identity for
registered users.

> **11.Dynamic Geographic Cooldown Rule:**

User-initiated geographic reassignment after initial registration is
restricted by the active GeoCooldownPolicy. The cooldown duration must
not be hard-coded in UserProfile. Before accepting a geographic
reassignment, the system must evaluate the applicable policy using the
current geographic state and the accepted change history in
UserGeoChangeLog. If the reassignment is accepted, the system must
update the geographic fields in UserProfile, update geo_updated_at, and
insert an immutable UserGeoChangeLog record in the same atomic
transaction.

12. **Administrative/System Bypass Rule:**

> The active geographic cooldown policy may be bypassed only by
> explicitly authorized administrative or trusted system operations. A
> bypass must never be available to ordinary user-originated requests.
> Every bypass must be recorded in UserGeoChangeLog with: -
> change_source = 'Admin' or 'System'; and - bypass_reason IS NOT NULL.

13. **Initial Geographic DATETIME Rule:**

On first successful user registration completion,
initial_geo_selected_at, geo_updated_at, and created_at must all be set
consistently within the same atomic completion transaction.

14. **Session Invalidation Consistency Rule:**

Any transition of is_active from 1 to 0 must trigger atomic invalidation
of all active AuthSession records belonging to the same user.

This must be coordinated transactionally at the service/application
layer, or through a controlled database-backed consistency mechanism, so
that no valid session survives deactivation.

> **15.Geographic Change Logging Rule:**

UserProfile stores the current authoritative geographic assignment only.
Every accepted geographic reassignment must be recorded as an immutable
row in UserGeoChangeLog. The UserProfile update and the UserGeoChangeLog
insertion must occur in the same atomic transaction.

16. **UTC DATETIME Rule:**

All DATETIME fields in this entity must be stored in UTC using MySQL 8.0
DATETIME.

**## 9.4. Relationships**

- **One-to-One with UserAccount:**

  - UserProfile.user_id ↔ UserAccount.user_id

  - Implemented using a **shared primary key** pattern.

- **Many-to-One with Settlement:**

  - UserProfile.settlement_id → Settlement.settlement_id

- **Many-to-One with County:**

  - UserProfile.county_id → County.county_id

- **Many-to-One with Province:**

  - UserProfile.province_id → Province.province_id

- **Many-to-One with Country:**

  - UserProfile.country_id → Country.country_id

- **One-to-Many logical relation with AuthSession:**

  - A single user profile may own multiple authentication sessions
    through the shared user identity.

  - On deactivation, all such sessions must be invalidated atomically.

**## 9.5. Indexes**

- **Primary Key:**

  - PRIMARY KEY (user_id)

- **Unique Constraints:**

  - UNIQUE KEY uq_user_profile_mobile_hash (mobile_hash)

  - UNIQUE KEY uq_user_profile_national_id_hash (national_id_hash)

- **Foreign Key / Join Performance Indexes:**

  - INDEX idx_user_profile_settlement_id (settlement_id)

  - INDEX idx_user_profile_county_id (county_id)

  - INDEX idx_user_profile_province_id (province_id)

  - INDEX idx_user_profile_country_id (country_id)

- **Composite Geography Query Indexes:**

  - INDEX idx_user_profile_geo_chain (country_id, province_id,
    county_id, settlement_id)

  - INDEX idx_user_profile_settlement_active (settlement_id, is_active)

**## 9.6. Final Architectural Notes**

1.  **Duplicate and Abuse Prevention:**

The combinations of unique national_id_hash and mobile_hash secure the
platform against Sybil attacks and ensure that each physical citizen can
only participate with one logical account.

2.  **Redundant Geography Storage:**

Although derivable from settlement_id, storing county_id, province_id,
and country_id directly improves filtering, aggregation, quorum
calculations, and geo-scoped process execution performance.

3.  **Atomic Setup:**

The creation of UserProfile and its hashes/encrypted fields happens in a
single MySQL transaction along with the creation of the UserAccount
using their shared primary key.

**# 10.UserGeoChangeLog**

**## 10.1.Definition**

An immutable audit ledger that records every accepted geographic
reassignment of a registered user. It supports dynamic geographic
cooldown enforcement, administrative review, abuse detection, and
historical traceability.

**## 10.2.Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| geo_change_log_id | BIGINT UNSIGNED | No | Identity | Internal surrogate primary key. |
| user_id | BIGINT UNSIGNED | No | — | References the user whose geographic assignment was changed. FK to UserProfile. |
| old_settlement_id | INT UNSIGNED | No | — | Previous settlement before the accepted change. |
| new_settlement_id | INT UNSIGNED | No | — | New settlement after the accepted change. |
| old_county_id | SMALLINT UNSIGNED | No | — | Previous derived county identifier. |
| new_county_id | SMALLINT UNSIGNED | No | — | New derived county identifier. |
| old_province_id | SMALLINT UNSIGNED | No | — | Previous derived province identifier. |
| new_province_id | SMALLINT UNSIGNED | No | — | New derived province identifier. |
| old_country_id | SMALLINT UNSIGNED | No | — | Previous derived country identifier. |
| new_country_id | SMALLINT UNSIGNED | No | — | New derived country identifier. |
| change_source | VARCHAR(20) | No | — | Source of the change: User, Admin, System. |
| policy_id | SMALLINT UNSIGNED | Yes | NULL | Optional reference to the dynamic geographic cooldown policy applied. |
| bypass_reason | VARCHAR(255) | Yes | NULL | Required only when cooldown was bypassed by authorized admin/system flow. |
| changed_at | DATETIME | No | CURRENT_TIMESTAMP | UTC DATETIME when the geographic change was accepted. |

**## 10.3.Constraints & Business Rules**

1.  **Immutable Ledger Rule:** Records in UserGeoChangeLog must be
    append-only. Updates and deletes are prohibited.

2.  **No-Op Change Rejection:** The system must reject geographic
    changes where old_settlement_id = new_settlement_id.

3.  **Bypass Governance Rule:** If change_source is Admin or System and
    the normal cooldown is bypassed, a non-null bypass_reason must be
    provided.

4.  **Atomic Update Rule:** Updating UserProfile geographic fields and
    inserting the corresponding UserGeoChangeLog row must occur within
    the same database transaction.

5.  **UTC DATETIME Rule:** All DATETIME fields must store values in UTC.

**## 10.4.Relationships**

- Many-to-One with UserProfile:

  - UserGeoChangeLog.user_id references UserProfile.user_id

  - ON UPDATE RESTRICT ON DELETE RESTRICT

- Many-to-One with Settlement:

  - old_settlement_id, new_settlement_id reference
    Settlement.settlement_id

  - ON UPDATE RESTRICT ON DELETE RESTRICT

**## 10.5.Indexes**

- PRIMARY KEY (geo_change_log_id)

- INDEX idx_user_geo_change_user_changed (user_id, changed_at)

- INDEX idx_user_geo_change_new_geo (new_country_id, new_province_id,
  new_county_id, new_settlement_id)

**# 11.GeoCooldownPolicy**

**## 11.1.Definition**

GeoCooldownPolicy defines the versioned enforcement rules that control
how frequently a user may change their geographic assignment in VetoApp.
It is the authoritative policy entity for geographic reassignment
cooldowns and replaces hardcoded or application-only rule logic.

*\#* **11.2.Attributes**

| **Attribute** | **Type** | **Null** | **Key** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|:--:|
| policy_id | SMALLINT UNSIGNED | No | PK | Auto-increment | Unique identifier of the policy row. |
| policy_code | VARCHAR(50) | No | UQ | — | Stable machine-readable policy code. |
| policy_name | VARCHAR(150) | No | — | — | Human-readable policy name. |
| description | VARCHAR(500) | Yes | — | NULL | Optional explanatory text. |
| max_changes_allowed | TINYINT UNSIGNED | No | — | — | Maximum allowed geographic changes within the evaluation window. |
| window_days | SMALLINT UNSIGNED | No | — | — | Rolling or fixed window size in days. |
| cooldown_days | SMALLINT UNSIGNED | No | — | — | Enforced cooldown duration in days after threshold violation. |
| is_active | TINYINT(1) | No | — | 1 | Indicates whether this policy version is currently active. |
| effective_from | DATETIME | No | — | — | UTC timestamp from which the policy becomes effective. |
| effective_to | DATETIME | Yes | — | NULL | UTC timestamp at which the policy stops being effective. |
| created_at | DATETIME | No | — | CURRENT_TIMESTAMP | Row creation timestamp in UTC. |
| updated_at | DATETIME | No | — | CURRENT_TIMESTAMP | Last update timestamp in UTC. |

*\##* **11.3.Constraints & Business Rules**

- policy_code must be unique.

- max_changes_allowed must be greater than zero.

- window_days must be greater than zero.

- cooldown_days must be greater than zero.

- effective_to must be greater than effective_from when present.

- Only one active policy version should be used for evaluation at any
  given time.

- The policy must be evaluated synchronously with UserGeoChangeLog
  before accepting a geographic reassignment.

- Policy rows are immutable in meaning after activation; if business
  rules change, a new version should be inserted instead of overwriting
  the old one.

- Deletion must be restricted if any historical log or enforcement
  reference exists.

*\##* **11.4.Relationships**

- One GeoCooldownPolicy may be referenced by many UserGeoChangeLog rows.

- Each UserGeoChangeLog row may optionally store the policy used during
  evaluation.

- GeoCooldownPolicy is read by the enforcement path and must not be
  modified by transactional acceptance logic.

*\#* **11.5.Indexes**

- PRIMARY KEY (policy_id)

- UNIQUE KEY uq_geo_cooldown_policy_code (policy_code)

- KEY idx_geo_cooldown_policy_active (is_active, effective_from,
  effective_to)

**# 12.NationalIdCooldownLedger**

**## 12.1.Definition**

NationalIdCooldownLedger is a privacy-preserving immutable ledger that
tracks progressive re-registration penalties for voluntarily closed
accounts using only the cryptographic hash of the National ID. The
applied cooldown duration is resolved from AccountClosurePenaltyPolicy
at enforcement time to prevent hardcoded penalty logic and support
policy versioning.

**## 12.2.Attributes**

| **Attribute** | **Type** | **Null** | **Key** | **Default** | **Description** |
|----|----|----|----|----|----|
| national_id_hash | BINARY(32) | No | PK | — | HMAC-SHA-256 hash of the normalized National ID. |
| closure_count | TINYINT UNSIGNED | No | — | 1 | Number of voluntary closures recorded for this National ID. |
| policy_id | SMALLINT UNSIGNED | No | FK | — | References the applied AccountClosurePenaltyPolicy version used for this ledger row. |
| cooldown_days | SMALLINT UNSIGNED | No | — | — | Cooldown duration resolved from the referenced policy. |
| cooldown_until | DATETIME | No | — | — | UTC datetime until which re-registration is blocked. |
| last_closed_at | DATETIME | No | — | CURRENT_TIMESTAMP | UTC datetime of the latest voluntary account closure. |
| created_at | DATETIME | No | — | CURRENT_TIMESTAMP | UTC datetime when this ledger row was first created. |
| updated_at | DATETIME | No | — | CURRENT_TIMESTAMP | UTC datetime of the latest ledger update. |

**## 12.3.Constraints & Business Rules**

- Plain-text National ID must never be stored in this table.

- national_id_hash must be unique and immutable.

- policy_id must reference an active AccountClosurePenaltyPolicy row at
  the time of enforcement.

- closure_count must increment atomically on each voluntary closure.

- cooldown_days must be derived from the referenced policy, not
  hardcoded in application logic.

- cooldown_until must be calculated as last_closed_at + INTERVAL
  cooldown_days DAY.

- Re-registration is allowed only when CURRENT_TIMESTAMP \>=
  cooldown_until.

- The closure transaction must lock the relevant ledger row before
  updating it.

- If no row exists, insert-or-update must be atomic to prevent duplicate
  concurrent processing.

- Updating this ledger must occur in the same transaction as closing the
  account/profile.

- All DATETIME fields must be stored in UTC.

**## 12.4.Relationships**

- Each NationalIdCooldownLedger row must reference exactly one
  AccountClosurePenaltyPolicy.

- One AccountClosurePenaltyPolicy may govern many
  NationalIdCooldownLedger rows.

- The policy relation preserves auditability of which penalty rule was
  applied at closure time.

- The ledger may also be evaluated by registration gatekeeping logic
  before allowing re-entry.

**## 12.5.Indexes**

- PRIMARY KEY (national_id_hash)

- KEY idx_national_id_cooldown_until (cooldown_until)

- KEY idx_national_id_policy_id (policy_id)

**# 13.AccountClosurePenaltyPolicy**

**## 13.1.Definition**

AccountClosurePenaltyPolicy defines the versioned cooldown and penalty
rules applied when a user closes an account and later attempts to
re-register or re-enter an identity-linked workflow. It is the
authoritative policy entity for progressive penalties such as 30, 60,
90, and 180 days.

**## 13.2.Attributes**

| **Attribute** | **Type** | **Null** | **Key** | **Default** | **Description** |
|----|----|----|----|----|----|
| policy_id | SMALLINT UNSIGNED | No | PK | Auto-increment | Unique identifier of the policy row. |
| policy_code | VARCHAR(50) | No | UQ | — | Stable machine-readable policy code. |
| policy_name | VARCHAR(150) | No | — | — | Human-readable policy name. |
| description | VARCHAR(500) | Yes | — | NULL | Optional policy description. |
| penalty_stage | TINYINT UNSIGNED | No | — | — | Progressive stage number for the penalty scheme. |
| penalty_days | SMALLINT UNSIGNED | No | — | — | Cooldown duration in days for this stage. |
| trigger_scope | VARCHAR(50) | No | — | — | Scope that activates the penalty, fixed to account closure. |
| is_active | TINYINT(1) | No | — | 1 | Indicates whether this policy version is currently active. |
| effective_from | DATETIME | No | — | — | UTC timestamp from which the policy becomes effective. |
| effective_to | DATETIME | Yes | — | NULL | UTC timestamp at which the policy stops being effective. |
| created_at | DATETIME | No | — | CURRENT_TIMESTAMP | Row creation timestamp in UTC. |
| updated_at | DATETIME | No | — | CURRENT_TIMESTAMP | Last update timestamp in UTC. |

**## 13.3.Constraints & Business Rules**

- policy_code must be unique.

- penalty_stage must be unique within the policy family.

- penalty_days must be a positive value.

- trigger_scope must be fixed to the account-closure use case.

- effective_to must be greater than effective_from when present.

- Only the active policy version may be used for real-time enforcement.

- Enforcement must be checked synchronously during registration and
  re-registration.

- Historical policy rows must remain intact for auditability and dispute
  tracing.

**## 13.4.Relationships**

- One AccountClosurePenaltyPolicy may govern many
  NationalIdCooldownLedger entries.

- One ledger entry must reference the policy version used during
  evaluation.

- The policy is read by enforcement logic and should not be mutated by
  ledger writes.

- The policy supports versioning across progressive penalty schemes.

**## 13.5.Indexes**

- PRIMARY KEY (policy_id)

- UNIQUE KEY uq_account_closure_penalty_policy_code (policy_code)

- UNIQUE KEY uq_account_closure_penalty_stage (penalty_stage)

- KEY idx_account_closure_penalty_active (is_active, effective_from,
  effective_to)

**# 14. GeographicActiveUserCounter (Logical Counter Family)**

The logical geographic active-user count is implemented by four physical counter tables, matching the current Laravel/MySQL schema. It is not one polymorphic table. The API/service layer may expose a common logical view over these tables.

| Physical table | Geography key type | Counter columns |
|---|---|---|
| country_active_user_counters | country_id SMALLINT UNSIGNED PK/FK | active_user_count BIGINT UNSIGNED, updated_at DATETIME |
| province_active_user_counters | province_id SMALLINT UNSIGNED PK/FK | active_user_count BIGINT UNSIGNED, updated_at DATETIME |
| county_active_user_counters | county_id SMALLINT UNSIGNED PK/FK | active_user_count BIGINT UNSIGNED, updated_at DATETIME |
| settlement_active_user_counters | settlement_id INT UNSIGNED PK/FK | active_user_count BIGINT UNSIGNED, updated_at DATETIME |

Each physical key references the matching geography table with exact type/sign compatibility. Counts are nonnegative, initialized for every geography row, and updated atomically with account activation, closure, or geography change. Lock updates bottom-up: Settlement, County, Province, Country. Each affected counter update occurs in the same transaction as the user-profile/account state change. A shared read endpoint may union the four physical sources, but the database must not pretend the polymorphic `(level,id)` pair is a direct composite FK. Lookup level codes are numeric 1–4 as defined in GeographicLevelLookup.

**# 15. UserAccount**

**## 15.1. Definition**

The UserAccount entity manages the authentication credentials, account
lock states, and operational statuses for voters. It does not store any
demographic, geographic, or identity-revealing data (which reside
strictly in UserProfile). Instead, it is linked to UserProfile via a
Shared Primary Key (user_id), ensuring a strict $`1:1`$relationship
while decoupling authentication metadata from personal identity.

**## 15.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| **user_id** | BIGINT UNSIGNED | No | — | Primary key and foreign key referencing UserProfile.user_id in a strict 1:1 shared-primary-key relationship. |
| **password_hash** | VARCHAR(255) | No | — | Argon2id secure cryptographic hash of the user’s password. |
| **account_status** | VARCHAR(15) | No | ‘Active’ | The operational status of the account. Allowed: ‘Active’, ‘Locked’, ‘Closed’. |
| **mfa_required** | TINYINT(1) | No | 0 | Multi-Factor Authentication requirement flag. |
| **failed_login_count** | TINYINT UNSIGNED | No | 0 | Running count of consecutive failed login attempts since the last successful login. |
| **last_failed_login_at** | DATETIME | Yes | NULL | UTC DATETIME of the last failed login attempt. |
| **locked_until** | DATETIME | Yes | NULL | UTC DATETIME indicating the end of a temporary security lockout window. |
| **password_reset_completed_at** | DATETIME | Yes | NULL | UTC DATETIME of the last completed password reset event. |
| **password_changed_at** | DATETIME | Yes | NULL | UTC DATETIME of the last voluntary password modification. |
| **created_at** | DATETIME | No | CURRENT_TIMESTAMP | UTC DATETIME of account creation. |
| **updated_at** | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | UTC DATETIME of the last record update. |

**## 15.3. Constraints & Business Rules**

1.  **Shared Primary Key & Referential Integrity:**user_id must serve as
    both the Primary Key and the Foreign Key referencing
    UserProfile.user_id. Direct deletes on UserProfile must RESTRICT to
    UserAccount (ON DELETE RESTRICT).

2.  **Valid Account Status (CHECK Constraint):**Must enforce that
    account_status is restricted to valid states:CONSTRAINT
    chk_user_account_status CHECK (account_status IN ('Active',
    'Locked', 'Closed')).

3.  **Lockout Coherency (CHECK Constraint):**If the account status is
    marked as ‘Locked’, the expiration DATETIME must not be
    null:CONSTRAINT chk_lockout_coherency CHECK (account_status !=
    'Locked' OR locked_until IS NOT NULL).

4.  **Temporal Lockout Expiration:**A temporary lock is operationally
    valid only while locked_until \> CURRENT_TIMESTAMP. If locked_until
    \<= CURRENT_TIMESTAMP, the lock is considered expired. On the first
    successful login attempt after expiration:

    - account_status must transition back to 'Active'.

    - failed_login_count must be reset to 0.

    - locked_until must be set to NULL.

5.  **Lockout Trigger & Scaling Policy:**When failed_login_count reaches
    the threshold defined by the active SecurityPolicy (e.g., 5
    attempts):

    - account_status must be set to 'Locked'.

    - last_failed_login_at must be set to CURRENT_TIMESTAMP.

    - locked_until must be calculated and set as CURRENT_TIMESTAMP +
      INTERVAL LOCK_DURATION SECOND based on the active policy rules
      (with potential progressive scaling for subsequent lockouts).

6.  **Account Lifecycle Finality (Closed State):**

> Transitioning account_status to 'Closed' is permanent and
> irreversible. A Closed account must never transition back to Active or
> Locked.
>
> The Closed transition must be executed as part of the atomic voluntary
> account closure flow, including NationalIdCooldownLedger update,
> UserProfile anonymization, and AuthSession invalidation.

**## 15.4. Relationships**

• One-to-One with UserProfile (Dependent Relation):

UserAccount.user_id (PK/FK) references UserProfile.user_id (PK) in a
shared primary key pattern.

On Update: Restrict \| On Delete: Restrict.

**## 15.5. Indexes**

- **PRIMARY KEY:** user_id

- **INDEX:** idx_user_account_status on (account_status, locked_until)
  to optimize login state verification.

**# 16. SecurityPolicy**

**## 16.1. Definition**

The SecurityPolicy entity defines global or tenant-level configurations
for authentication security, including maximum login failures, lockout
cooling-off periods, and progressive lockout penalty rules. This
decouples dynamic security configurations from hardcoded application
logic.

**## 16.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| **policy_id** | TINYINT UNSIGNED | No | — | Primary Key. Auto-incremented policy identifier. |
| **is_active** | TINYINT(1) | No | 0 | Flag indicating if this policy is the currently active system rule. |
| **max_failed_attempts** | TINYINT UNSIGNED | No | 5 | Max consecutive failed login attempts allowed before trigger-locking the account. |
| **base_lockout_seconds** | INT UNSIGNED | No | 900 | Base duration (in seconds) for the first lockout penalty (Default: 15 minutes). |
| **progressive_factor** | DECIMAL(3,1) | No | 2.0 | Multiplier applied to the lockout duration for consecutive lockouts within a window. |
| **max_lockout_seconds** | INT UNSIGNED | No | 86400 | The ceiling duration for progressive lockouts (Default: 24 hours). |
| **created_at** | DATETIME | No | CURRENT_TIMESTAMP | UTC DATETIME when this policy version was registered. |
| **updated_at** | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | UTC DATETIME of the last policy metadata modification. |

**## 16.3. Constraints & Business Rules**

1.  **Single Active Policy Constraint:**Only a single policy record can
    be active (is_active = 1) in the database at any given time. This is
    enforced at the database level using a generated virtual column and
    a unique index:is_active_1 TINYINT GENERATED ALWAYS AS (CASE WHEN
    is_active = 1 THEN 1 ELSE NULL END) STORED with a UNIQUE INDEX on
    is_active_1.

2.  **Numeric Safety Bounds (CHECK Constraints):**

    - CONSTRAINT chk_policy_max_failed CHECK (max_failed_attempts \> 0)

    - CONSTRAINT chk_policy_base_lockout CHECK (base_lockout_seconds \>
      0)

    - CONSTRAINT chk_policy_progressive_factor CHECK (progressive_factor
      \>= 1.0)

    - CONSTRAINT chk_policy_max_lockout CHECK (max_lockout_seconds \>=
      base_lockout_seconds)

3.  **Immutability of Active Policies:**An active policy record must
    ideally be read-only to guarantee trace stability. Modifications
    must be implemented by creating a new policy draft and shifting the
    is_active flag.

**## 16.4. Relationships**

- *None direct.* This table acts as a global singleton configuration
  state accessed by the application layer during user login operations.

**## 16.5. Indexes**

- **PRIMARY KEY:** policy_id.

- **UNIQUE INDEX:** idx_unique_active_policy on (is_active_1) to
  physically enforce that only one row contains is_active = 1.

**# 17. UserLoginAuditLog**

**## 17.1. Definition**

The UserLoginAuditLog entity captures all successful and unsuccessful
authentication attempts. By storing client IP addresses, user agents,
and failure reasons in this specialized append-only table, it provides a
comprehensive forensic trail for anomaly detection (such as brute force
or credential stuffing) without bloating the operational UserAccount
table.

**## 17.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| **log_id** | BIGINT UNSIGNED | No | — | Primary Key. Auto-incrementing identifier. |
| **user_id** | BIGINT UNSIGNED | No | — | Foreign Key referencing UserAccount.user_id. |
| **attempted_at** | DATETIME | No | CURRENT_TIMESTAMP | UTC DATETIME of the login attempt. |
| **login_status** | VARCHAR(15) | No | — | Outcome of the authentication attempt. Allowed: ‘Success’, ‘Failed’. |
| **failure_reason** | VARCHAR(50) | Yes | NULL | Details if failed. Allowed: ‘InvalidPassword’, ‘AccountLocked’, etc. |
| **ip_address** | VARCHAR(45) | No | — | Client IP address (supports IPv4 and IPv6 notations). |
| **user_agent** | VARCHAR(512) | No | — | Raw User-Agent string from the client header. |

**## 17.3. Constraints & Business Rules**

1.  **Append-Only Enforcement:**This entity must be strictly write-once.
    The database configuration, triggers, or application-level
    privileges must prevent UPDATE and DELETE queries on this table.

2.  **Login Outcome Validity (CHECK Constraints):**

    - CONSTRAINT chk_audit_login_status CHECK (login_status IN
      ('Success', 'Failed'))

    - CONSTRAINT chk_audit_failure_coherency CHECK ((login_status =
      'Failed' AND failure_reason IS NOT NULL) OR (login_status =
      'Success' AND failure_reason IS NULL))

3.  **RESTRICT Deletion Policy:**If a user account is deleted
    voluntarily or closed completely, the associated login logs must be
    deleted:ON DELETE RESTRICT is set on the foreign key targeting
    UserAccount.

**## 17.4. Relationships**

- UserLoginAuditLog.user_id ➡️ UserAccount.user_id (N:1 Relationship,
  Foreign Key constraint with ON DELETE RESTRICT / ON UPDATE RESTRICT).

**## 17.5. Indexes**

- **PRIMARY KEY:** log_id.

- **INDEX:** idx_audit_user_attempts on (user_id, attempted_at) to
  support rapid lockout threshold scans and brute force checks.

- **INDEX:** idx_audit_ip_attempts on (ip_address, attempted_at) to
  detect network-wide distributed brute force attacks.

**# 18. UserBiometricCredential**

**## 18.1. Definition**

UserBiometricCredential stores public-key authentication material and
cryptographic identifiers for biometric-backed FIDO/WebAuthn
authentication. The database acts strictly as a public-key signature
verifier. No raw biometric samples, biometric images, or biometric
feature templates are ever transmitted to or stored in the database.

A user profile may register multiple biometric credentials across
multiple devices. However, at any given time, **only one credential may
remain active** for a user. When a new biometric credential is
activated, all previously active credentials of the same user must be
automatically deactivated. In the current policy, the active credential
is also treated as the default credential.

**## 18.2. Attributes**

| **Column** | **Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| **biometric_credential_id** | BIGINT UNSIGNED AUTO_INCREMENT | No | — | Physical primary key. |
| **user_id** | BIGINT UNSIGNED | No | — | Foreign key referencing UserProfile.user_id (Shared PK pattern). |
| **credential_id** | VARBINARY(255) | No | — | Hardware identifier returned during credential registration. |
| **device_identifier** | VARCHAR(128) | Yes | NULL | Device tracking code. |
| **device_model** | VARCHAR(100) | Yes | NULL | Device hardware model. |
| **aaguid** | BINARY(16) | Yes | NULL | Authenticator Attestation GUID identifying device make. |
| **public_key** | BLOB | No | — | Public key used to verify user-generated signatures. |
| **public_key_sha256** | BINARY(32) | No | — | SHA-256 hash of the public key for indexing and fast lookup. |
| **key_algorithm** | VARCHAR(15) | No | — | Cryptographic algorithm. Allowed: ‘ES256’, ‘RS256’, ‘Ed25519’. |
| **is_active** | TINYINT(1) | No | 0 | Active key flag. |
| **is_default** | TINYINT(1) | No | 0 | Indicates if this is the default fallback biometric device. |
| **sign_count** | INT UNSIGNED | No | 0 | Anti-replay and cloning prevention counter. |
| **active_user_id** | BIGINT UNSIGNED GENERATED ALWAYS AS (CASE WHEN is_active = 1 THEN user_id ELSE NULL END) STORED | Yes | — | Generated column used to enforce that only one active credential may exist per user. |
| **default_user_id** | BIGINT UNSIGNED GENERATED ALWAYS AS (CASE WHEN is_default = 1 THEN user_id ELSE NULL END) STORED | Yes | — | Generated column enforcing a single default biometric device per user. |
| **last_used_at** | DATETIME | Yes | NULL | Last successful biometric login DATETIME. |
| **created_at** | DATETIME | No | CURRENT_TIMESTAMP | Record creation DATETIME (UTC). |
| **updated_at** | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Auto-updated using ON UPDATE CURRENT_TIMESTAMP. |

**## 18.3. Constraints and Security Rules**

1.  **Zero Biometric Storage Policy:**Storing raw biological features or
    custom templates is strictly prohibited. The system acts solely as a
    public-key validation registry verifying asymmetrical signatures.

2.  **One Active Key Limit:** A user profile may have at most one active
    biometric credential at any given time. This constraint is
    physically enforced at the database level by a UNIQUE index on the
    generated column active_user_id.

3.  **One Default Key Limit:** A user profile may have at most one
    default biometric credential at any given time. This constraint is
    physically enforced at the database level by a UNIQUE index on the
    generated column default_user_id.

4.  **Active/Default Alignment Rule:** Under the current biometric
    policy, the active credential must also be the default credential.
    Credential activation must atomically deactivate all previously
    active/default credentials of the same user and promote the new
    credential as both active and default.

5.  **Key Algorithm Restriction:**The key_algorithm attribute shall be
    restricted to the supported biometric key algorithms:CONSTRAINT
    chk_biometric_key_algorithm CHECK (key_algorithm IN ('ES256',
    'RS256', 'Ed25519')).

6.  **Anti-Replay Counter Checks:**During assertion, the incoming
    signature counter from the client must be strictly greater than the
    stored sign_count unless both values are zero. The database updates
    sign_count atomically on successful login.

**## 18.4. Relationships**

- UserProfile: Many-to-One referencing user_id (ON DELETE RESTRICT ON
  UPDATE RESTRICT).

**## 18.5. Indexes**

- **PRIMARY KEY:** (biometric_credential_id)

- **UNIQUE KEY:** uq_biometric_credential_id on (credential_id)

- **UNIQUE KEY:** uq_biometric_one_active_per_user on (active_user_id)

- **UNIQUE KEY:** uq_biometric_one_default_per_user on (default_user_id)

- **INDEX:** idx_biometric_user_active_lookup on (user_id, is_active)

- **INDEX:** idx_biometric_pubkey_hash on (public_key_sha256)

- **INDEX:** idx_biometric_device_tracing on (device_identifier)

**# 19. AuthSession**

**## 19.1. Definition**

AuthSession represents authentication sessions issued to users after
successful identity and credential validation. It stores both active and
terminal sessions until archival. Each user may have at most one
persisted session in Active state at any time. The entity governs
issuance, absolute expiration, inactivity-based termination, revocation,
and optional explicit logout. To support forensic auditability and
session hijacking detection, each session records client IP address and
User-Agent. Terminal sessions are periodically transferred to
auth_session_archives based on terminated_at, which is the authoritative
UTC DATETIME at which the session ceased to be valid.

**## 19.2. Attributes**

| **Column** | **Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| auth_session_id | BIGINT UNSIGNED AUTO_INCREMENT | No | — | Physical primary key. |
| session_uuid | BINARY(16) | No | — | UUID v7 stored in binary form for API-layer session identification and token representation. |
| user_id | BIGINT UNSIGNED | No | — | FK referencing UserProfile.user_id. |
| authentication_method | VARCHAR(20) | No | — | Initial authentication method. Allowed values: 'Password', 'Biometric'. |
| state | VARCHAR(20) | No | 'Active' | Persisted session state. FK referencing auth_session_state_lookup.state_code. |
| active_user_id | BIGINT UNSIGNED GENERATED ALWAYS AS (CASE WHEN state = 'Active' THEN user_id ELSE NULL END) STORED | Yes | — | Generated enforcement column used only to guarantee that each user has at most one persisted Active session. |
| ip_address | VARCHAR(45) | No | — | Client IPv4 or IPv6 address captured for forensic audit. |
| user_agent | VARCHAR(512) | No | — | Client User-Agent string captured for audit and hijacking analysis; not a trusted standalone device identifier. |
| issued_at | DATETIME | No | CURRENT_TIMESTAMP | UTC DATETIME at which the session was issued. |
| last_activity_at | DATETIME | No | CURRENT_TIMESTAMP | UTC DATETIME of the most recent successfully authenticated user interaction; initialized at issuance and updated only while the session remains Active. |
| expires_at | DATETIME | No | — | Absolute UTC expiration DATETIME representing the maximum permitted lifetime of the session. |
| terminated_at | DATETIME | Yes | NULL | Effective UTC DATETIME at which the session ceased to be valid; NULL while the session is Active. |
| revoked_at | DATETIME | Yes | NULL | UTC DATETIME of forced revocation; populated only when state = 'Revoked' and terminal_reason = 'force_revocation'. |
| logged_out_at | DATETIME | Yes | NULL | UTC DATETIME of explicit logout; reserved for trusted internal operations or a future logout API because the current frontend does not expose logout. |
| terminal_reason | VARCHAR(30) | Yes | NULL | Reason for terminal transition. Allowed non-NULL values: 'inactivity_timeout', 'force_revocation', 'manual_logout', 'expired'. |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | UTC insertion DATETIME. |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | UTC DATETIME of the most recent persisted change. |

**### 19.2.1. Lookup Table: auth_session_state_lookup**

| **Attribute** | **Data Type** | **Null** | **Key** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| state_code | VARCHAR(20) | No | PK | Unique session state code. |
| state_name | VARCHAR(100) | No | — | Human-readable session state name. |
| is_active | TINYINT(1) | No | — | Indicates whether the lookup code is enabled for use; not whether an individual session is active. |
| display_order | INT | No | — | Presentation order. |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | UTC insertion DATETIME. |
| updated_at | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | UTC DATETIME of the most recent row update. |

**Seed values:**

- Active / Expired / Revoked/ LoggedOut

**### 19.3. Constraints and Rules**

**### 19.3.1. Domain Constraints**

- **Authentication Method Restriction:**

CONSTRAINT chk_auth_session_authentication_method CHECK
(authentication_method IN ('Password', 'Biometric'))

- **Absolute Expiration Timeline:**

CONSTRAINT chk_auth_session_expiry_timeline CHECK (expires_at \>
issued_at)

- **Last Activity Timeline:**

CONSTRAINT chk_auth_session_last_activity_timeline CHECK
(last_activity_at \>= issued_at AND last_activity_at \<= expires_at)

- **Terminal Reason Allowed Values:**

CONSTRAINT chk_auth_session_terminal_reason CHECK (terminal_reason IS
NULL OR terminal_reason IN ('inactivity_timeout', 'force_revocation',
'manual_logout', 'expired'))

- **Session State and Terminal-Metadata Consistency:**

CONSTRAINT chk_auth_session_terminal_state CHECK ((state = 'Active' AND
terminal_reason IS NULL AND terminated_at IS NULL AND revoked_at IS NULL
AND logged_out_at IS NULL ) OR ( state = 'Expired' AND terminal_reason
IN ('expired', 'inactivity_timeout')

AND terminated_at IS NOT NULL AND revoked_at IS NULL AND logged_out_at
IS NULL ) OR ( state = 'Revoked' AND terminal_reason =
'force_revocation' AND terminated_at IS NOT NULL AND revoked_at IS NOT
NULL AND logged_out_at IS NULL AND revoked_at = terminated_at ) OR (
state = 'LoggedOut' AND terminal_reason = 'manual_logout' AND
terminated_at IS NOT NULL AND revoked_at IS NULL AND logged_out_at IS
NOT NULL AND logged_out_at = terminated_at ) )

- **General Termination Timeline:**

CONSTRAINT chk_auth_session_terminated_at_timeline CHECK (terminated_at
IS NULL OR ( terminated_at \>= issued_at AND terminated_at \<=
expires_at AND terminated_at \>= last_activity_at ) )

- **Revocation Timeline:**

CONSTRAINT chk_auth_session_revoked_at_timeline CHECK ( revoked_at IS
NULL OR (revoked_at \>= issued_at AND revoked_at \<= expires_at) )

- **Explicit Logout Timeline:**

CONSTRAINT chk_auth_session_logged_out_at_timeline CHECK ( logged_out_at
IS NULL OR (logged_out_at \>= issued_at AND logged_out_at \<=
expires_at) )

**### 19.3.2. Immutability & Lifecycle Rules**

- auth_session_id, session_uuid, user_id, issued_at, and
  authentication_method are immutable after creation.

- last_activity_at must be initialized to issued_at when the session is
  created and must never be NULL.

- A user may have at most one session whose persisted state is Active.
  This invariant is enforced at the database level through
  active_user_id and UNIQUE KEY uq_auth_session_active_user.

- Before issuing a new session, the transaction service must lock and
  evaluate any existing Active session of the same user. If it is no
  longer valid due to absolute expiration or inactivity, it must first
  be transitioned to terminal state. If business rules permit
  replacement of a still-valid session, the previous session must first
  be atomically transitioned to Revoked with terminal_reason =
  'force_revocation'.

- Once a session enters Expired, Revoked, or LoggedOut, it must never
  transition back to Active. A new authentication event must create a
  new AuthSession record.

- expires_at is the source of truth for absolute maximum session
  lifetime. The application must treat the session as invalid whenever
  CURRENT_TIMESTAMP \>= expires_at, even if state has not yet been
  asynchronously updated.

- An Active session must be treated as invalid when CURRENT_TIMESTAMP
  \>= last_activity_at + INTERVAL 15 MINUTE, provided it has not already
  reached expires_at.

- When inactivity termination is persisted, the session must be updated
  to state = 'Expired', terminal_reason = 'inactivity_timeout', and
  terminated_at = last_activity_at + INTERVAL 15 MINUTE; revoked_at and
  logged_out_at must remain NULL.

- An \`Active\` session must be considered invalid once
  \`CURRENT_TIMESTAMP \>= last_activity_at + INTERVAL 15 MINUTE\`,
  unless it has already reached \`expires_at\` earlier.
  \`last_activity_at\` may be updated only by a successfully
  authenticated request, action, or server-accepted heartbeat
  attributable to that same session. Therefore, if the user has left the
  application environment and no qualifying session activity is recorded
  for 15 consecutive minutes, the session must be terminated as
  \`Expired\` with \`terminal_reason = 'inactivity_timeout'\` and
  \`terminated_at = last_activity_at + INTERVAL 15 MINUTE\`. During this
  transition, \`revoked_at\` and \`logged_out_at\` must remain NULL. The
  absence of an explicit logout capability in the current frontend does
  not extend session validity beyond this inactivity threshold.

- Only a user-initiated request or a server-accepted heartbeat generated
  while the client is in an active foreground page-interaction state may
  advance \`last_activity_at\`. Any heartbeat produced while the client
  is backgrounded, hidden, suspended, detached, or otherwise
  non-interactive shall be ignored for session-liveness purposes.
  Consequently, if no qualifying interactive activity is recorded for 15
  consecutive minutes after the user exits the application environment,
  the session must be marked \`Expired\` with \`terminal_reason =
  'inactivity_timeout'\` and \`terminated_at = last_activity_at +
  INTERVAL 15 MINUTE\`.

- When absolute expiration is persisted, the session must be updated to
  state = 'Expired', terminal_reason = 'expired', and terminated_at =
  expires_at.

- last_activity_at may be refreshed only after a successfully
  authenticated request and only if the session is still valid and still
  Active.

- Session validation, inactivity evaluation, expiration evaluation, and
  last_activity_at refresh must be concurrency-safe and atomic at the
  transaction or conditional-update level.

- A background worker may reconcile stale persisted Active sessions into
  Expired, but this worker is only a reconciliation mechanism; every
  authenticated API request must independently enforce expiration and
  inactivity timeout.

- The current frontend does not expose logout. Therefore, LoggedOut,
  logged_out_at, and terminal_reason = 'manual_logout' are reserved for
  trusted internal operations or a future explicit logout API.

- Administrative revocation, security-triggered invalidation, or
  replacement by a newly issued session must transition the previous
  session to Revoked with terminal_reason = 'force_revocation',
  revoked_at = effective revocation DATETIME, and terminated_at =
  revoked_at.

**### 19.3.3. Archival Policy**

Sessions in a terminal state whose terminated_at is older than 6 months
must be transferred from AuthSession to auth_session_archives through a
controlled archival process. terminated_at is the authoritative archival
reference; expires_at must not be used as a substitute because a session
may terminate earlier due to inactivity, revocation, or explicit logout.
Only sessions in Expired, Revoked, or LoggedOut state with non-NULL
terminated_at are eligible for archival. Active sessions must never be
archived.

**## 19.4. Relationships**

- **UserProfile:** Many AuthSession records belong to one UserProfile
  through AuthSession.user_id → UserProfile.user_id (ON DELETE RESTRICT
  ON UPDATE RESTRICT).

- **Auth Session State Lookup:** Many AuthSession records reference one
  auth_session_state_lookup row through AuthSession.state →
  auth_session_state_lookup.state_code (ON DELETE RESTRICT ON UPDATE
  RESTRICT).

- **Generated Enforcement Column:** active_user_id is a generated
  enforcement column only; it does not create an independent
  relationship and must not have a separate foreign key.

**## 19.5. Indexes**

- PRIMARY KEY (auth_session_id)

- UNIQUE KEY uq_auth_session_uuid (session_uuid)

- UNIQUE KEY uq_auth_session_active_user (active_user_id)

- INDEX idx_auth_session_user_state (user_id, state)

- INDEX idx_auth_session_state_expiry (state, expires_at)

- INDEX idx_auth_session_state_activity (state, last_activity_at)

- INDEX idx_auth_session_user_activity (user_id, last_activity_at)

- INDEX idx_auth_session_archival_lookup (state, terminated_at)

**# 20. SystemState**

**## 20.1. Definition**

SystemState is a singleton governing entity that stores the global
operational status of the platform. It contains exactly one persistent
row and enforces sequential, non-reversible (monotonic) transitions
between states 1 and 7 to control system-wide capability activation. To
prevent redundant data states, the system’s live active user count is
dynamically referenced from CountryActiveUserCounter using a physical
Foreign Key (country_id), allowing real-time comparison against the
activation threshold.

**## 20.2. Attributes**

<table style="width:100%;">
<colgroup>
<col style="width: 20%" />
<col style="width: 9%" />
<col style="width: 3%" />
<col style="width: 20%" />
<col style="width: 4%" />
<col style="width: 41%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;"><strong>Attribute</strong></th>
<th style="text-align: center;"><strong>Data Type</strong></th>
<th style="text-align: center;"><strong>Null</strong></th>
<th style="text-align: center;"><strong>Default</strong></th>
<th style="text-align: center;"><strong>Key Role</strong></th>
<th style="text-align: center;"><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>system_state_id</strong></td>
<td style="text-align: center;">TINYINT UNSIGNED</td>
<td style="text-align: center;">No</td>
<td style="text-align: center;">1</td>
<td style="text-align: center;">PK</td>
<td style="text-align: center;">Singleton primary key. Must always equal
1.</td>
</tr>
<tr>
<td style="text-align: center;"><strong>state_value</strong></td>
<td style="text-align: center;">TINYINT UNSIGNED</td>
<td style="text-align: center;">No</td>
<td style="text-align: center;">—</td>
<td style="text-align: center;">FK</td>
<td style="text-align: center;">Current system state (1 to 7).
References system_state_lookup.state_code.</td>
</tr>
<tr>
<td
style="text-align: center;"><strong>geographic_level_code</strong></td>
<td style="text-align: center;">SMALL UNSIGNED</td>
<td style="text-align: center;">No</td>
<td style="text-align: center;">1</td>
<td style="text-align: center;">FK</td>
<td style="text-align: center;">References
<strong>GeographicActiveUserCounter</strong>.
<strong>geographic_level_code</strong> to link the system state with the
root country counter</td>
</tr>
<tr>
<td style="text-align: center;"><strong>geographic_id</strong></td>
<td style="text-align: center;">TINYINT UNSIGNED</td>
<td style="text-align: center;">No</td>
<td style="text-align: center;">1</td>
<td style="text-align: center;">FK</td>
<td style="text-align: center;"><p>References
<strong>GeographicActiveUserCounter</strong>.<strong>geographic_id</strong></p>
<p>to link the system state with the root country counter.</p></td>
</tr>
<tr>
<td
style="text-align: center;"><strong>activation_user_threshold</strong></td>
<td style="text-align: center;">BIGINT UNSIGNED</td>
<td style="text-align: center;">No</td>
<td style="text-align: center;">44000000</td>
<td style="text-align: center;">—</td>
<td style="text-align: center;">Minimum user threshold for state 1 to 2
transition. Default: 44,000,000.</td>
</tr>
<tr>
<td
style="text-align: center;"><strong>breathing_period_hours</strong></td>
<td style="text-align: center;">INT UNSIGNED</td>
<td style="text-align: center;">No</td>
<td style="text-align: center;">24</td>
<td style="text-align: center;">—</td>
<td style="text-align: center;">Cooling interval before state 1 to 2
transition can occur. Default: 24.</td>
</tr>
<tr>
<td
style="text-align: center;"><strong>threshold_reached_at</strong></td>
<td style="text-align: center;">DATETIME</td>
<td style="text-align: center;">Yes</td>
<td style="text-align: center;">NULL</td>
<td style="text-align: center;">—</td>
<td style="text-align: center;">UTC DATETIME when the country’s active
user count first met the activation threshold.</td>
</tr>
<tr>
<td style="text-align: center;"><strong>state_changed_at</strong></td>
<td style="text-align: center;">DATETIME</td>
<td style="text-align: center;">No</td>
<td style="text-align: center;">—</td>
<td style="text-align: center;">—</td>
<td style="text-align: center;">UTC DATETIME of the last state
transition.</td>
</tr>
<tr>
<td style="text-align: center;"><strong>changed_by_user_id</strong></td>
<td style="text-align: center;">BIGINT UNSIGNED</td>
<td style="text-align: center;">Yes</td>
<td style="text-align: center;">NULL</td>
<td style="text-align: center;">FK</td>
<td style="text-align: center;">Reference to the administrator’s
identity (UserProfile.user_id) who authorized the manual
transition.</td>
</tr>
<tr>
<td style="text-align: center;"><strong>created_at</strong></td>
<td style="text-align: center;">DATETIME</td>
<td style="text-align: center;">No</td>
<td style="text-align: center;">CURRENT_TIMESTAMP</td>
<td style="text-align: center;">—</td>
<td style="text-align: center;">Record creation DATETIME (UTC).</td>
</tr>
<tr>
<td style="text-align: center;"><strong>updated_at</strong></td>
<td style="text-align: center;">DATETIME</td>
<td style="text-align: center;">No</td>
<td style="text-align: center;">CURRENT_TIMESTAMP ON UPDATE
CURRENT_TIMESTAMP</td>
<td style="text-align: center;">—</td>
<td style="text-align: center;">Last modification DATETIME (UTC).</td>
</tr>
</tbody>
</table>

**### 20.2.1. Lookup Table: system_state_lookup**

| **Attribute** | **Data Type** | **Null** | **Key** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| **state_code** | TINYINT UNSIGNED | No | PK | Unique state identifier (1 to 7). |
| **state_name** | VARCHAR(100) | No | — | Persian name representing the current system operational phase. |
| **description** | VARCHAR(255) | Yes | — | Detailed operational rules and permissions enforced during this phase. |

**Seed Values for system_state_lookup:**

- 1: <span dir="rtl"></span>Activation phase, waiting for initial
  threshold

- 2: Referendum ready state

- 3: First Presidential Election

- 4: First Provincial/State Elections

- 5: First County/Governorship Elections

- 6: First Municipal Elections

- 7: System completely deployed/finalized

**## 20.3. Constraints and Business Rules**

**### 20.3.1. Database Constraints**

- **Singleton Enforcement:**CONSTRAINT chk_system_state_singleton CHECK
  (system_state_id = 1)Ensures that no more than one record can exist in
  this table, enforcing the singleton pattern at the physical engine
  level.

- **State Boundaries:**Referential integrity via Foreign Key to
  system_state_lookup implicitly restricts state_value to values 1
  through 7.

- **Administrator Requirement:**CONSTRAINT chk_admin_required_for_manual
  CHECK (state_value = 1 OR (state_value \> 1 AND changed_by_user_id IS
  NOT NULL))Ensures that any state transition beyond Phase 1 must
  register the authorizing administrator’s user_id.

**### 20.3.2. Lifecycle & Transition Logic**

- **Monotonic Sequence Rule:** State transitions must strictly move
  forward (for example, 1 -\> 2 -\> 3). Because MySQL CHECK constraints
  cannot compare OLD and NEW row versions, backward transitions must be
  prevented in a BEFORE UPDATE trigger or in the application layer
  within the same transaction.

- **State 1 ➡️ 2 Semi-Automatic Transition:**

  - The transition is blocked unless
    CountryActiveUserCounter.active_user_count (associated via
    country_id) is $`\geq`$activation_user_threshold.

  - When the count first crosses the threshold, the database updates
    threshold_reached_at to the current UTC DATETIME.

  - If the count falls below the threshold before the transition is
    finalized, threshold_reached_at must be reset to NULL.

  - Transition from 1 to 2 is only authorized when CURRENT_TIMESTAMP \>=
    threshold_reached_at + INTERVAL breathing_period_hours HOUR.

- **State 2 to 7 Manual Transitions:**Transitions from State 2 onwards
  are manual operations that require an explicit cryptographic/digital
  signature check of the administrator at the application tier. The
  database records the administrator’s primary identity in
  changed_by_user_id.

**## 20.4. Relationships**

- CountryActiveUserCounter: Many-to-One referencing country_id (ON
  DELETE RESTRICT ON UPDATE RESTRICT).

- system_state_lookup: Many-to-One referencing state_value
  $`\rightarrow`$system_state_lookup.state_code (ON DELETE RESTRICT ON
  UPDATE RESTRICT).

- UserProfile: Many-to-One referencing changed_by_user_id -\>
  UserProfile.user_id (ON DELETE RESTRICT ON UPDATE RESTRICT).

**## 20.5. Indexes**

- **PRIMARY KEY:** (system_state_id)

- **INDEX:** idx_system_state_value on (state_value)

- **INDEX:** idx_system_state_country on (country_id)

- **INDEX:** idx_system_state_admin on (changed_by_user_id)

**# 21. ProcessStateLookup**

Authoritative controlled registry of process lifecycle states.

| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| state_code | VARCHAR(50) | No | PK | Immutable case-sensitive machine code. |
| state_title | VARCHAR(100) | No | — | Display title. |
| is_terminal | TINYINT(1) | No | — | Terminal state flag. |
| is_active | TINYINT(1) | No | — | Available for governed transitions. |
| display_order | INT UNSIGNED | No | — | UI ordering. |
| created_at / updated_at | DATETIME | No | — | UTC timestamps. |

Canonical states: Supporting, Waiting, VoteCasting, Publishing, Finalized, Failed, Terminated. The source listed seven states while saying eight; this revision corrects the count to seven. Finalized, Failed, and Terminated are terminal. Seed and update through controlled migrations/governance only. Index active, terminal and display order.

**# 22. GeographicLevelLookup**

Controlled numeric vocabulary for geography levels, matching the live lookup schema.

| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| geographic_level_code | TINYINT UNSIGNED | No | PK | Stable code: 1 Country, 2 Province, 3 County, 4 Settlement. |
| geographic_level_title | VARCHAR(100) | No | — | Human-readable title. |
| hierarchy_rank | TINYINT UNSIGNED | No | UQ | Broad-to-narrow rank, 1–4. |
| lock_order | TINYINT UNSIGNED | No | — | Operational lock ordering; Settlement=1 through Country=4. |
| is_active | TINYINT(1) | No | — | Available for new processes. |
| created_at / updated_at | DATETIME | No | — | UTC timestamps. |

The numeric code is the database identifier; English labels are not stored as keys. Codes are immutable. A user's active Settlement qualifies for a target when its parent chain contains that target at the requested level. Seed rows: `(1, Country, 1, 4)`, `(2, Province, 2, 3)`, `(3, County, 3, 2)`, `(4, Settlement, 4, 1)`. Indexes: PK(code), unique(rank), index(active).

**# 23. Process**

Process is one referendum, election, or impeachment workflow, with a controlled type and exactly one target geography. It is also the indivisible shard-placement unit; a control-plane ProcessShardPlacement entry routes the globally unique process_id to exactly one shard.

| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| process_id | BIGINT UNSIGNED | No | PK | Globally unique ID allocated through the control-plane placement registry; never generated by an independent per-shard AUTO_INCREMENT. |
| process_type_code | VARCHAR(50) | No | FK | Referendum, Election, Impeachment. |
| target_geographic_level_code | TINYINT UNSIGNED | No | FK | Numeric geography-level code. |
| target_geographic_id | BIGINT UNSIGNED | No | — | Node ID in the selected geography table. |
| title | VARCHAR(255) | No | — | Title. |
| created_by_user_id | BIGINT UNSIGNED | No | FK | Creator. |
| voting_opens_at | DATETIME | No | — | UTC instant when voting may begin. |
| voting_closes_at | DATETIME | No | — | UTC close; must be after opening. |
| ballot_schema_id | VARCHAR(80) | No | — | Immutable ballot contract identifier. |
| ballot_schema_version | SMALLINT UNSIGNED | No | — | Immutable schema version frozen before VoteCasting. |
| canonical_encoding_version | SMALLINT UNSIGNED | No | 1 | Deterministic binary encoding version. |
| vote_token_ttl_seconds | SMALLINT UNSIGNED | No | 300 | Configurable short token lifetime, bounded to 120–600 seconds and no later than voting close. |
| result_publication_interval_seconds | INT UNSIGNED | No | 600 | Configurable aggregate-result refresh cadence; does not delay vote acceptance. |
| created_at / updated_at | DATETIME | No | — | UTC timestamps. |

The target is polymorphic and validated against the table selected by level. Process type, target, ballot schema, and canonical encoding version become immutable before VoteCasting. A VoteToken may be issued only in active VoteCasting state and while `voting_opens_at <= server_now < voting_closes_at`. Token expiry is shorter than or equal to the voting window. Eligibility means the active Settlement in the user's profile chain descends from the target node. At submission, the server validates the token and revalidates state, window, and target geography inside the atomic transaction. Result aggregates refresh at the configured interval; this policy never delays token issuance or vote commits. Indexes: type, target scope, creator, and voting window.

**# 24. ProcessListView (VIEW)**

Read-only view of Process and its current active ProcessState interval (`current_state_completed_at IS NULL`).

| Projected column | Type | Source |
|---|---|---|
| process_id | BIGINT UNSIGNED | Process |
| process_type_code | VARCHAR(50) | Process |
| target_geographic_level_code | TINYINT UNSIGNED | Process |
| target_geographic_id | BIGINT UNSIGNED | Process |
| title | VARCHAR(255) | Process |
| voting_opens_at / voting_closes_at | DATETIME | Process |
| created_at | DATETIME | Process |
| current_state_code | VARCHAR(50) | active ProcessState |
| current_state_started_at | DATETIME | active ProcessState |

Writes go to base tables. ProcessState must enforce at most one active row per process using a generated column plus unique index. A standard MySQL view has no indexes; index its base tables.

**# 25. ProcessState**

**## 25.1. Definition**

ProcessState represents the authoritative, time-bound runtime state
intervals of a Process. It tracks when a process enters a specific state
and when it completes that state, ensuring that exactly one state
interval is active at any given moment.

**## 25.2. Attributes**

<table>
<colgroup>
<col style="width: 22%" />
<col style="width: 11%" />
<col style="width: 3%" />
<col style="width: 21%" />
<col style="width: 7%" />
<col style="width: 34%" />
</colgroup>
<thead>
<tr>
<th style="text-align: center;"><strong>Attribute</strong></th>
<th style="text-align: center;"><strong>Data Type</strong></th>
<th style="text-align: center;"><strong>Null</strong></th>
<th style="text-align: center;"><strong>Default</strong></th>
<th style="text-align: center;"><strong>Key</strong></th>
<th style="text-align: center;"><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: center;"><strong>process_state_id</strong></td>
<td style="text-align: center;">BIGINT UNSIGNED</td>
<td style="text-align: center;">No</td>
<td style="text-align: center;">—</td>
<td style="text-align: center;">PK</td>
<td style="text-align: center;">Unique identifier for the process state
record.</td>
</tr>
<tr>
<td style="text-align: center;"><strong>process_id</strong></td>
<td style="text-align: center;">BIGINT UNSIGNED</td>
<td style="text-align: center;">No</td>
<td style="text-align: center;">—</td>
<td style="text-align: center;">FK</td>
<td style="text-align: center;">Owning process. Multiple rows exist over
time; at most one active row is allowed.</td>
</tr>
<tr>
<td style="text-align: center;"><strong>current_state_code</strong></td>
<td style="text-align: center;">VARCHAR(50)</td>
<td style="text-align: center;">No</td>
<td style="text-align: center;">—</td>
<td style="text-align: center;">FK</td>
<td style="text-align: center;">Current authoritative state code for
this state interval.</td>
</tr>
<tr>
<td
style="text-align: center;"><strong>current_state_started_at</strong></td>
<td style="text-align: center;">DATETIME</td>
<td style="text-align: center;">No</td>
<td style="text-align: center;">—</td>
<td style="text-align: center;">—</td>
<td style="text-align: center;">UTC DATETIME when this state interval
began.</td>
</tr>
<tr>
<td
style="text-align: center;"><strong>current_state_completed_at</strong></td>
<td style="text-align: center;">DATETIME</td>
<td style="text-align: center;">Yes</td>
<td style="text-align: center;">NULL</td>
<td style="text-align: center;">—</td>
<td style="text-align: center;">UTC DATETIME when this state interval
ended. NULL means the interval is currently active.</td>
</tr>
<tr>
<td style="text-align: center;"><strong>active_process_id</strong></td>
<td style="text-align: center;"><p>BIGINT UNSIGNED</p>
<p>generated</p></td>
<td style="text-align: center;">Yes</td>
<td style="text-align: center;">—</td>
<td style="text-align: center;">UQ (via unique index)</td>
<td style="text-align: center;">active_process_id BIGINT UNSIGNED
GENERATED ALWAYS AS (IF(current_state_completed_at IS NULL, process_id,
NULL)) STORED</td>
</tr>
<tr>
<td style="text-align: center;"><strong>created_at</strong></td>
<td style="text-align: center;">DATETIME</td>
<td style="text-align: center;">No</td>
<td style="text-align: center;">CURRENT_TIMESTAMP</td>
<td style="text-align: center;">—</td>
<td style="text-align: center;">UTC creation DATETIME.</td>
</tr>
<tr>
<td style="text-align: center;"><strong>updated_at</strong></td>
<td style="text-align: center;">DATETIME</td>
<td style="text-align: center;">No</td>
<td style="text-align: center;">CURRENT_TIMESTAMP ON UPDATE
CURRENT_TIMESTAMP</td>
<td style="text-align: center;">—</td>
<td style="text-align: center;">UTC last update DATETIME.</td>
</tr>
</tbody>
</table>

**Generated Column Rule (MySQL)**

active_process_id is generated as:

IF(current_state_completed_at IS NULL, process_id, NULL)

**## 25.3. Constraints and Business Rules**

- **PRIMARY KEY (process_state_id)**

- process_id is NOT NULL and must reference Process(process_id).

- current_state_code is NOT NULL and must reference
  ProcessStateLookup(state_code).

- current_state_started_at is NOT NULL and stored in UTC.

- current_state_completed_at is nullable; NULL means the row is the
  active current state.

- **Uniqueness of active state (core rule):** for any given process_id,
  there must be at most one row where current_state_completed_at IS
  NULL. This must be enforced at the database level using:

  - active_process_id generated column

  - and a UNIQUE INDEX on active_process_id

- **Atomic transition:** any transition must be executed atomically in
  one transaction:

  1.  lock the current active row for the process using SELECT ... FOR
      UPDATE

  2.  set its current_state_completed_at = UTC current DATETIME

  3.  insert the next row with current_state_started_at equal to that
      completion DATETIME and current_state_completed_at = NULL

- ProcessState must not include:

  - subject_entity_type

  - subject_entity_id

  - process_started_at

  - process_completed_at

- ProcessState must not store separate transition history tables or
  duplicate transition-trace structures here; completed rows plus the
  audit system cover traceability.

- ProcessListView.current_state_code must be derived from the active
  ProcessState row where current_state_completed_at IS NULL.

**## 25.4. Relationships**

- ProcessState.process_id → Process.process_id

- ProcessState.current_state_code → ProcessStateLookup.state_code

**## 25.5. Indexes**

- **PRIMARY KEY** (process_state_id)

- **INDEX** (process_id)

- **INDEX** (current_state_code)

- **INDEX** (process_id, current_state_started_at)

- **UNIQUE INDEX** uq_process_state_active_process (active_process_id)

**### 25.1.6. DDL Notes**

- All temporal fields must use DATETIME in UTC.

- active_process_id must be implemented as a STORED generated column in
  MySQL to support the UNIQUE index used for enforcing one active row
  per process.

- MySQL UNIQUE indexes allow multiple NULL values; this is intentionally
  leveraged so completed rows produce active_process_id = NULL and do
  not collide, while duplicate active rows do collide.

- No foreign key exists from Process to an individual ProcessState row;
  current-state projection is derived through ProcessListView.

- process_id follows the current canonical BIGINT UNSIGNED design of the
  Process entity.

**# 26. ProcessTypeLookup**

**## 26.1. Definition**

ProcessTypeLookup is the authoritative controlled vocabulary for
**process types** in VetoApp.

It defines the allowed set of process categories (e.g., Referendum,
Election, Impeachment) and is referenced by Process.process_type_code to
prevent free-text types and ensure consistent validation, filtering, and
reporting.

**## 26.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Key** | **Description** |
|:--:|:--:|:--:|:--:|:--:|:--:|
| **process_type_code** | VARCHAR(50) | No | — | PK | Canonical, immutable type code used by FKs (case-sensitive by convention). |
| **title** | VARCHAR(100) | No | — | — | Human-readable English title. |
| **is_active** | TINYINT(1) | No | 1 | — | Whether this type is selectable for new processes. |
| **created_at** | DATETIME | No | CURRENT_TIMESTAMP | — | UTC creation DATETIME. |
| **updated_at** | DATETIME | No | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | — | UTC last update DATETIME. |

**## 26.3. Constraints & Business Rules**

- **Primary key:** process_type_code (immutable; must not be updated
  in-place).

- **English-only titles:** title must be stored in English (enforced by
  application/admin policy; DB-level enforcement optional).

- **Activation rule:** only rows with is_active = 1 may be used for new
  Process rows (enforced in application logic or via trigger).

- **Time standard:** Time standard: created_at and updated_at must be
  stored as UTC DATETIME (no TIMESTAMP).

- **No ENUMs:** process types must not be implemented as ENUM; this
  lookup table is the sole authority.

- **Uniqueness:**

  - process_type_code is unique by PK.

  - title must be unique to avoid ambiguous UI labels.

**## 26.4. Relationships**

- Referenced by: Process.process_type_code →
  ProcessTypeLookup.process_type_code

**## 26.5. Indexes**

- **PRIMARY KEY** (process_type_code)

- **UNIQUE INDEX** uq_process_type_title (title)

- **INDEX** idx_process_type_is_active (is_active)

**Seed Data (Required)**

| **process_type_code** |  **title**  | **is_active** |
|:---------------------:|:-----------:|:-------------:|
|      Referendum       | Referendum  |       1       |
|       Election        |  Election   |       1       |
|      Impeachment      | Impeachment |       1       |

**# 27. ProcessTransitionRule (Policy Binding + Versioning)**

Defines versioned process-state transitions and optionally binds a support-threshold policy.

For a gated transition, `P` is the immutable `ProcessPopulationSnapshot.frozen_population_total`; `r` and the floor are from `SupportThresholdPolicyLookup`; `S` is read exclusively from the ProcessGeographicCounter row with `counter_type=SUPPORT` and `ballot_choice_key=ALL` after applying its outbox event. `required = GREATEST(CEILING(P * r / 1,000,000), min_support_count)` and the gate opens when the updated counter is at least `required`.

A support commit emits its immutable outbox event in the same transaction as the support ledger record. A per-process ordered consumer applies each event exactly once. In a single transaction it locks the counter and active ProcessState, increments the counter, evaluates the new count, and performs the transition if the threshold is reached. Duplicate delivery cannot increment or transition twice. Support attempts that begin after the state leaves Supporting are rejected under the same state lock. Reaching the ledger count alone does not trigger the transition until projection catches up; this is intentional. Reconciliation rebuilds the projection and uses the same coordinator rather than a second threshold source.

Retain the source's active-version and unambiguous-transition constraints: one active version per rule key, one active rule per `(process_type_code, from_state_code, event_code)`, and threshold-policy nullability consistent with `requires_support_threshold`.

| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| process_transition_rule_id | BIGINT UNSIGNED | No | PK | Rule version row. |
| process_type_code | VARCHAR(50) | No | FK | Process type. |
| from_state_code | VARCHAR(50) | No | FK | Source process state. |
| to_state_code | VARCHAR(50) | No | FK | Destination process state. |
| event_code | VARCHAR(60) | No | — | Stable event that requests the transition. |
| rule_version | SMALLINT UNSIGNED | No | UQ with rule key | Monotonic version for the rule key. |
| requires_support_threshold | TINYINT(1) | No | — | Whether transition is gated by support count. |
| support_threshold_policy_code | VARCHAR(50) | Yes | FK | Required iff requires_support_threshold=1. |
| is_active | TINYINT(1) | No | 1 | Whether this version is currently selected. |
| active_rule_marker | TINYINT UNSIGNED GENERATED STORED | Yes | UQ with rule key | 1 while active, otherwise NULL. |
| effective_from / effective_to | DATETIME | No / Yes | — | UTC validity interval. |
| created_at / updated_at | DATETIME | No | — | UTC maintenance timestamps. |

Unique `(process_type_code, from_state_code, event_code, rule_version)` preserves versions. A generated active marker and unique `(process_type_code, from_state_code, event_code, active_rule_marker)` enforce at most one active version for a transition key. Exact transition rows and event codes are deliberately not seeded until the process workflow is approved.

**# 28. SupportThresholdPolicyLookup**

Reusable policy parameters for support thresholds; no runtime count is stored here.

| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| support_threshold_policy_code | VARCHAR(50) | No | PK | Stable policy code. |
| policy_name | VARCHAR(120) | No | — | Human-readable title. |
| threshold_rate_ppm | INT UNSIGNED | No | — | Rate from 1 to 1,000,000 PPM. |
| rounding_mode_code | VARCHAR(30) | No | — | Supported deterministic rounding rule, normally CEIL. |
| min_support_count | BIGINT UNSIGNED | No | 0 | Optional required minimum. |
| is_active | TINYINT(1) | No | 1 | New-rule eligibility. |
| created_at / updated_at | DATETIME | No | — | UTC timestamps. |

Runtime evaluation uses `P = ProcessPopulationSnapshot.frozen_population_total` and `S = ProcessGeographicCounter.counter_value` for the matching process/target support aggregate with `counter_type=SUPPORT` and `ballot_choice_key=ALL`. `S` is read after applying the current ordered outbox event; no query of SupportParticipation may act as a second runtime threshold source. `required = GREATEST(CEILING(P * threshold_rate_ppm / 1,000,000), min_support_count)`. Policy and snapshot values are fixed for the process lifecycle. Indexes: PK(code), index(active).

**# 29. ProcessPopulationSnapshot**

**## 29.1. Definition**

Stores the **frozen target population baseline** for a process, captured
**once** at the moment the process enters Supporting.

This snapshot is **immutable** and is the sole population input used for
support threshold evaluation during the Supporting lifecycle.

**## 29.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| process_id | BIGINT UNSIGNED | No | — | Primary Key. FK ➜ Process(process_id). |
| frozen_population_total | BIGINT UNSIGNED | No | — | Captured from the matching physical geographic active-user counter for the process target scope. |
| captured_at | DATETIME | No | CURRENT_TIMESTAMP | UTC capture time (seconds precision). |

**## 29.3. Constraints & Business Rules**

1.  **One Snapshot Per Process (1:1)**

    - Enforced by PRIMARY KEY (process_id).

2.  **Immutability**

    - After insert, frozen_population_total and captured_at MUST NOT be
      updated.

3.  **Capture Moment & Source**

    - Insert exactly once on transition into Supporting.

    - Capture source:

- Process.target_geographic_level_code

- Process.target_geographic_id

- read from the matching physical geographic active-user counter table selected by the numeric level code and geography ID.

4.  **Strong Consistency**

    - The transition into Supporting and inserting this snapshot must be
      executed in the **same transaction**, so a process cannot be in
      Supporting without a snapshot.

**## 29.4. Relationships**

- process_id -\> Process(process_id) (ON DELETE RESTRICT ON UPDATE
  RESTRICT).

**## 29.5. Indexes**

- PRIMARY KEY (process_id)

**# 30. SupportParticipation**

**## 30.1. Definition**

SupportParticipation is the immutable ledger recording each successful
support action for a process. It captures the support event, the
participant’s stable identity key derived upstream using HMAC-SHA-256,
and a static snapshot of the participant’s geographic hierarchy at the
time of participation to enable high-performance reporting and
aggregation without joining the user profile.

Uniqueness is enforced per process on (process_id,
supporter_identity_key) to prevent duplicate support by the same
real-world individual, even across account deletion and re-registration.

A committed support participation is independent of the current
lifecycle status of the related UserProfile or UserAccount. Later
activation, deactivation, suspension, deletion, or re-registration of an
account does not invalidate, alter, or remove the immutable support
fact.

**## 30.2. Attributes**

| **Column** | **Type** | **Nullable** | **Key Role** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| support_participation_id | BIGINT UNSIGNED | No | PK | Primary key. |
| process_id | BIGINT UNSIGNED | No | FK | Reference to the owning Process. |
| process_type_code | VARCHAR(50) | No | FK | Process type code snapshot at participation time. References ProcessTypeLookup.process_type_code. |
| supporter_identity_key | BINARY(32) | No | Logical Key | Stable identity key derived upstream via HMAC-SHA-256 over normalized national identity data. |
| idempotency_key | BINARY(32) | No | Unique Key | Exactly-once submission key for network retries and replay prevention. |
| participated_at | DATETIME | No | Audit | UTC DATETIME when the support action was successfully committed. |
| country_id | SMALLINT UNSIGNED | No | FK | Geographic snapshot: participant’s country at participation time. |
| province_id | SMALLINT UNSIGNED | No | FK | Geographic snapshot: participant’s province at participation time. |
| county_id | SMALLINT UNSIGNED | No | FK | Geographic snapshot: participant’s county at participation time. |
| settlement_id | INT UNSIGNED | No | FK | Geographic snapshot: participant’s settlement at participation time. |

**## 30.3. Constraints & Business Rules**

- **Primary Key:**

  - support_participation_id.

- **Actual RDBMS Foreign Keys:**

  - process_id references Process(process_id) (ON DELETE RESTRICT ON
    UPDATE RESTRICT).

  - process_type_code references ProcessTypeLookup(process_type_code)
    (ON DELETE RESTRICT ON UPDATE RESTRICT).

  - country_id references Country(country_id) (ON DELETE RESTRICT ON
    UPDATE RESTRICT).

  - province_id references Province(province_id) (ON DELETE RESTRICT ON
    UPDATE RESTRICT).

  - county_id references County(county_id) (ON DELETE RESTRICT ON UPDATE
    RESTRICT).

  - settlement_id references Settlement(settlement_id) (ON DELETE
    RESTRICT ON UPDATE RESTRICT).

- **Logical Associations (No RDBMS FK):**

  - supporter_identity_key is a privacy-preserving logical identity key; it is not a direct account FK.

  - A hard foreign key is intentionally omitted to preserve independence
    from account and profile lifecycle changes.

- **Uniqueness Constraints:**

  - UNIQUE (process_id, supporter_identity_key) strictly prohibits
    duplicate support by the same real-world individual within the same
    process.

  - UNIQUE (idempotency_key) guarantees idempotent exactly-once
    processing for client retries and replay prevention.

- **Immutability:**

  - This entity is an immutable ledger fact.

  - It must not contain lifecycle flags such as is_active, nor mutable
    audit columns such as updated_at.

  - Since participated_at already captures the event time, a separate
    created_at column is unnecessary and must be omitted.

- **Geographic Snapshot Integrity Rule:**

  - The four geographic snapshot IDs must form one valid strict
    hierarchy: Settlement → County → Province → Country.

  - The captured hierarchy must reflect the participant’s effective
    registered geography at participated_at.

  - The geographic snapshot fields are immutable and must not be
    recalculated from later profile changes.

- **Support Finality Rule:**

  - A successfully committed SupportParticipation is final and remains
    valid independently of subsequent UserProfile or UserAccount status
    changes.

  - SupportParticipation is the immutable audit/rebuild source. Runtime support-threshold decisions use only the ordered asynchronous ProcessGeographicCounter projection as specified in entities 27 and 34.

  - A process may enter Vote Casting only after its applicable
    support-stage requirements have been satisfied and the process has
    not entered the Failed state.

- **Source of Truth Rule:**

  - This entity is the system source of truth for support participation
    events.

- **Atomic Receipt Rule:**

  - SupportParticipation and the corresponding DigitalReceipt with
    receipt_type_code = 'SUPPORT' must be inserted atomically. Its
    support_idempotency_key equals SupportParticipation.idempotency_key;
    this rule applies only to SUPPORT and never to VOTE.

  - If either insert fails, the transaction must roll back.

- **Time Standard:**

  - All DATETIMEs must be stored strictly in UTC using DATETIME .

**## 30.4. Relationships**

- **Process 1 — N SupportParticipation (Actual RDBMS FK):** Each support
  participation record belongs to exactly one process.

- **ProcessTypeLookup 1 — N SupportParticipation (Actual RDBMS FK):**
  Each record stores a process type snapshot to support direct
  partitioning and aggregation.

- **Country 1 — N SupportParticipation (Actual RDBMS FK):** Each
  participation snapshots the participant’s country.

- **Province 1 — N SupportParticipation (Actual RDBMS FK):** Each
  participation snapshots the participant’s province.

- **County 1 — N SupportParticipation (Actual RDBMS FK):** Each
  participation snapshots the participant’s county.

- **Settlement 1 — N SupportParticipation (Actual RDBMS FK):** Each
  participation snapshots the participant’s settlement.

- **UserProfile 1 — N SupportParticipation (Logical Association):**
  Linked logically via supporter_identity_key.

- **SupportParticipation 1 — 1 DigitalReceipt (Logical Transactional
  Association):** Each successful support participation must produce
  exactly one DigitalReceipt with receipt_type_code = 'SUPPORT', logically
  paired via the same idempotency_key within the same committed
  transaction.

- **SupportParticipation 1 — N ProcessGeographicCounter (Derived
  Projection Contribution):** A committed support participation may
  contribute to multiple derived support-counter rows across configured
  geographic aggregation levels.

**## 30.5. Indexes**

- PRIMARY KEY (support_participation_id)

- UNIQUE KEY uq_support_once (process_id, supporter_identity_key)

- UNIQUE KEY uq_support_idempotency (idempotency_key)

- INDEX idx_support_process_time (process_id, participated_at)

- INDEX idx_support_geo_hierarchy (process_id, country_id, province_id,
  county_id, settlement_id)

- INDEX idx_support_type_process (process_type_code, process_id)

**# 31. DigitalReceipt**

### Definition

Immutable signed proof of SUPPORT or VOTE. SUPPORT receipts may be account-owned. VOTE receipts are bearer-verifiable and never linked to a user account or identity key.

| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| digital_receipt_id | BIGINT UNSIGNED | No | PK | Internal ID. |
| process_id | BIGINT UNSIGNED | No | FK | Process context. |
| beneficiary_user_account_id | BIGINT UNSIGNED | Yes | FK | SUPPORT only; NULL for VOTE. |
| participant_identity_key | BINARY(32) | Yes | — | SUPPORT only; NULL for VOTE. |
| support_idempotency_key | BINARY(32) | Yes | UQ | SUPPORT pairing only; NULL for VOTE. |
| receipt_type_code | VARCHAR(30) | No | FK | SUPPORT or VOTE. |
| process_type_code | VARCHAR(50) | No | FK | Process-type snapshot. |
| event_title_snapshot | VARCHAR(255) | No | — | Display snapshot. |
| receipt_number | BINARY(32) | No | UQ | Random, nonsequential bearer lookup secret, not derived from identity/ballot keys. |
| payload_version | SMALLINT UNSIGNED | No | — | Canonical payload version. |
| receipt_hash | BINARY(32) | No | — | Hash of canonical signed payload. |
| signature_value | VARBINARY(512) | No | — | Signature over receipt_hash using receipt-only key. |
| key_id | VARCHAR(100) | No | — | Signing key version. |
| issued_at | DATETIME(3) | No | — | Exact UTC commit time at millisecond precision; never privacy-rounded or delayed. |

For VOTE, ownership, identity, and support idempotency columns must all be NULL (CHECK plus application validation). VOTE canonical payload version 2 contains receipt_number, process, sequence number, canonical ballot-choice key and display-label snapshot, ballot commitment, timestamp, payload version and key ID, but no voter identity, account, VoteToken identifier/hash, or ballot-submission idempotency key. Version 1 remains verifiable without the two choice fields for backward compatibility. The receipt number is a bearer capability; there is no account-based “My Vote Receipts” lookup. “Identity-unlinked” here means no persistent relational join to the voter; exact timestamp/geography and privileged application/database logs may still allow correlation. Support receipt ownership/idempotency behavior remains separate. Receipt signature bytes are excluded from ballot chain input to avoid circular hashing. Index receipt number unique, nullable support key unique, process/time, and account/time for SUPPORT retrieval.

`receipt_type_code` references the auxiliary controlled lookup `receipt_type_lookups`, seeded with SUPPORT and VOTE. This supporting lookup was omitted from the numbered entity list; no other receipt type is accepted.

**# 32. DigitalReceiptSupportDetail**

**## 32.1. Definition**

DigitalReceiptSupportDetail stores the immutable, type-specific detail
for a SUPPORT digital receipt.

Given the minimal support semantics, this table is intentionally small
and exists mainly to enforce subtype normalization and future
extensibility without changing the DigitalReceipt envelope.

**## 32.2. Attributes**

| **Attribute** | **Data Type** | **Null** | **Default** | **Key** | **Description** |
|:--:|:--:|:--:|:--:|:--:|:--:|
| digital_receipt_id | BIGINT UNSIGNED | No | — | PK, FK | References DigitalReceipt.digital_receipt_id. One-to-one detail row for SUPPORT. |
| support_payload_version | SMALLINT UNSIGNED | No | 1 | — | Version of the support-detail canonical fields included in receipt canonical payload. |
| support_note_snapshot | VARCHAR(255) | Yes | NULL | — | Optional immutable human-readable support note/label (if applicable). Must be server-derived (not required; keep NULL if unused). |
| created_at | DATETIME | No | CURRENT_TIMESTAMP | — | UTC insert timestamp (audit only; record is immutable). |

**## 32.3. Constraints & Business Rules**

- **Subtype rule:** A DigitalReceipt with receipt_type_code='SUPPORT'
  must have exactly one DigitalReceiptSupportDetail row.

- **Immutability:** No UPDATE / DELETE. Insert-only.

- **FK policy:** ON DELETE RESTRICT ON UPDATE RESTRICT (no cascade).

- **Payload binding:** Any non-null column here must be included in the
  canonical payload (per support_payload_version) so changes would
  invalidate receipt_hash/signature.

- **No ENUMs.**

**## 32.4. Relationships**

- DigitalReceiptSupportDetail.digital_receipt_id →
  DigitalReceipt.digital_receipt_id

  - ON DELETE RESTRICT

  - ON UPDATE RESTRICT

**## 32.5. Indexes**

- PRIMARY KEY (digital_receipt_id)

**# 33. DigitalReceiptVoteDetail**

One-to-one signed disclosure for an identity-unlinked bearer vote receipt.

| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| digital_receipt_id | BIGINT UNSIGNED | No | PK, FK | Receipt envelope. |
| ballot_box_entry_id | BIGINT UNSIGNED | No | UQ, FK | Identity-unlinked ballot proved by the receipt. |
| vote_payload_version | SMALLINT UNSIGNED | No | — | Detail serialization version. |
| ballot_choice_key_snapshot | VARCHAR(80) | No | — | Frozen canonical option key. |
| ballot_choice_label_snapshot | VARCHAR(255) | No | — | Frozen display label. |
| ballot_commitment | BINARY(32) | No | — | BallotBoxEntry.current_hash. |
| created_at | DATETIME | No | — | Exact UTC time. |

Every VOTE receipt has exactly one detail; SUPPORT has none. Choice and label must match the immutable process option and be covered by the receipt signature. No voter/account/issuance/idempotency field is permitted. The FK links only to BallotBoxEntry; no identity-side participation/token FK is allowed.

**# 34. ProcessGeographicCounter**

Asynchronous, idempotent aggregate projection by process, metric, geography and ballot option. Immutable ledgers/events are its audit/rebuild source; by decision, this projection is the only runtime source for support-threshold decisions.

| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| process_geographic_counter_id | BIGINT UNSIGNED | No | PK | Counter ID. |
| process_id | BIGINT UNSIGNED | No | FK | Process. |
| counter_type | VARCHAR(40) | No | — | Canonical metric. |
| geographic_level_code | TINYINT UNSIGNED | No | FK | Controlled geography level. |
| geographic_id | BIGINT UNSIGNED | No | — | Polymorphic node ID; validated by level. |
| ballot_choice_key | VARCHAR(80) | No | — | ALL for aggregate, otherwise canonical option key. |
| counter_value | BIGINT UNSIGNED | No | — | Projected aggregate. |
| last_reconciled_at | DATETIME | Yes | — | UTC reconciliation time. |

Process type is obtained by joining Process, avoiding a duplicated type value that could disagree. Scope uniqueness is `(process_id, counter_type, geographic_level_code, geographic_id, ballot_choice_key)`. Events apply once via a durable processed-event identity and atomic increment. Support counts derive from SupportParticipation events; actual vote-participation and choice counts from BallotBoxEntry. Counter changes happen after source commit. Threshold consumer locks counter and active state, increments/evaluates/transitions atomically. Lag delays activation; ledger counts never act as an alternate runtime criterion. Rebuilds are controlled, idempotent, and coordinated so partial projections are not treated as current. Freshness/lag must be observable.

**# 35. VoteToken**

Identity-domain record for a single-use authorization to cast one vote in one process. It is an ordinary random bearer token, not a blind credential. The raw token is returned once and MUST NOT be stored in plaintext or recoverable encrypted form. Only SHA-256(raw token) is stored. The server generates at least 256 bits of cryptographically secure random token material.

| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| vote_token_id | BIGINT UNSIGNED | No | PK | Internal identity-domain row ID; never copied to ballot/receipt. |
| process_id | BIGINT UNSIGNED | No | FK | Process for which token is valid. |
| participant_identity_key | BINARY(32) | No | — | Stable HMAC identity key confined to identity domain. |
| token_hash | BINARY(32) | No | UQ | SHA-256 of the raw high-entropy token; lookup/validation only. |
| token_state_code | VARCHAR(20) | No | FK | ISSUED, USED, REVOKED, or EXPIRED. |
| issued_at | DATETIME(6) | No | — | Exact server UTC issuance time. |
| expires_at | DATETIME(6) | No | — | Explicit expiry, no later than voting_closes_at. |
| consumed_at | DATETIME(6) | Yes | — | Set atomically when a vote commits. |
| revoked_at | DATETIME(6) | Yes | — | Set when an unconsumed token is invalidated. |
| issuance_idempotency_key | BINARY(32) | No | UQ | Retry key for this issuance request only. |
| active_process_id | BIGINT UNSIGNED GENERATED STORED | Yes | UQ with active_identity_key | `CASE WHEN token_state_code='ISSUED' THEN process_id ELSE NULL END`. |
| active_identity_key | BINARY(32) GENERATED STORED | Yes | UQ with active_process_id | `CASE WHEN token_state_code='ISSUED' THEN participant_identity_key ELSE NULL END`. |

A unique `(active_process_id, active_identity_key)` constraint permits at most one ISSUED token per identity/process. Before issuance, the transaction locks the identity/process scope and changes any ISSUED token with `expires_at <= server_now` to EXPIRED; the state transition updates both generated columns and frees the unique slot. Validity is determined by all of: matching token hash, state=ISSUED, `server_now < expires_at`, process VoteCasting state, open voting window, and eligibility. Expiry is the half-open boundary `server_now >= expires_at`; effective expiry is `MIN(issued_at + configured_token_ttl, voting_closes_at)`. The TTL is stored in `Process.vote_token_ttl_seconds`, defaults to five minutes, and is constrained to 120–600 seconds.

A consumed, revoked, or expired token is never revived, extended, or reused. A replacement may be issued only after the old token has become invalid and no VoterParticipation exists for that identity/process. Reissue invalidates any prior unconsumed token before creating the new token, under a locked process/identity issuance operation and rate limits. Same issuance idempotency key never creates a second token; because only the hash is stored, if the client lost the raw token it must explicitly revoke/expire the unusable token and request a fresh issuance with a new idempotency key. No recoverable token ciphertext is retained. No token ID/hash or issuance key is copied into BallotBoxEntry, DigitalReceipt, chain input, or publication artifacts.

**# 36. VoterParticipation**

Identity-domain immutable record that an identity cast a vote in a process. It confirms turnout and enforces one participation per identity/process, but stores no selected option and has no FK or shared identifier to a ballot or receipt.

| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| voter_participation_id | BIGINT UNSIGNED | No | PK | Identity-side participation row. |
| process_id | BIGINT UNSIGNED | No | FK | Process. |
| participant_identity_key | BINARY(32) | No | UQ with process | Stable HMAC identity key. |
| participated_at | DATETIME(3) | No | — | Exact UTC commit time at millisecond precision; same transaction timestamp as the ballot commit. |
| country_id | SMALLINT UNSIGNED | No | FK | Geography snapshot. |
| province_id | SMALLINT UNSIGNED | No | FK | Geography snapshot. |
| county_id | SMALLINT UNSIGNED | No | FK | Geography snapshot. |
| settlement_id | INT UNSIGNED | No | FK | Geography snapshot; matches current schema. |

Unique `(process_id, participant_identity_key)` prevents duplicate participation. This entity contains no VoteToken ID/hash, ballot ID, receipt ID, sequence number, choice, or ballot idempotency key. It is inserted in the same transaction as token consumption and ballot commit, but no relational key connects it to the ballot. Exact time/geography correlation remains an accepted operational risk. Indexes: process/time and process/geography.

**# 37. BallotBoxEntry**

Immutable identity-unlinked ballot ledger record. It contains the canonical option, an independent ballot-only idempotency key, geography snapshots, and per-process hash-chain data; it has no direct/stable voter identifier or relational join to identity-side ledgers.

| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| ballot_box_entry_id | BIGINT UNSIGNED | No | PK | Ballot row ID. |
| process_id | BIGINT UNSIGNED | No | FK | Process. |
| sequence_no | BIGINT UNSIGNED | No | UQ per process | Committed order. |
| previous_hash | BINARY(32) | No | — | Previous chain hash or genesis value. |
| current_hash | BINARY(32) | No | UQ per process | Versioned chain hash. |
| ballot_option_key | VARCHAR(80) | No | FK | Frozen option for this process. |
| canonical_vote_payload | VARBINARY(512) | No | — | Canonical TLV envelope of the schema-valid selection; no arbitrary client text. |
| ballot_submission_idempotency_key | BINARY(32) | No | UQ | Retry key only for this identity-unlinked ballot submission. |
| recorded_at | DATETIME(3) | No | — | Exact UTC commit time at millisecond precision; serialized as exactly three fractional digits. |
| country_id | SMALLINT UNSIGNED | No | FK | Immutable geography snapshot. |
| province_id | SMALLINT UNSIGNED | No | FK | Immutable geography snapshot. |
| county_id | SMALLINT UNSIGNED | No | FK | Immutable geography snapshot. |
| settlement_id | INT UNSIGNED | No | FK | Matches canonical settlements key type. |

Unique constraints: `(process_id, sequence_no)`, `(process_id, current_hash)`, and ballot submission idempotency key. The key is a random, high-entropy bearer retry secret independent of token/identity keys; it must be delivered to and retained by the client for retry. Check for an existing matching idempotency key before token-consumption validation; a retry with the same key and same process/option returns the existing receipt without advancing the sequence, while a different payload is rejected. The key must not be logged or copied into identity-side tables. Never add account/national ID/mobile/participant identity/VoteToken ID/token hash/identity idempotency key or FK to VoterParticipation. For a new submission, the vote service validates the one-time token, process, expiry, active VoteCasting state/window, and target geography within the atomic transaction.

Canonical vote serialization is defined by Encoding V1: every field is `Tag (1 byte) || Length (4-byte unsigned big-endian) || Value`; fields are ascending by tag; unknown tags, missing required tags, duplicate non-repeated tags, invalid types, and invalid schema values are rejected. Unsigned/signed integers use 8-byte big-endian/two's-complement form; booleans are one byte (00/01); text is UTF-8 NFC without BOM; enums are their NFC normative symbols; binary is raw bytes; timestamps are RFC 3339 UTC text with exactly 3 fractional digits when present; NULL is forbidden and absent optional fields are omitted. Array ordering is defined by the frozen ballot schema. The required selection envelope tags are 0x01 encoding version, 0x02 process_id/context, 0x03 ballot_schema_id, 0x04 ballot_schema_version, and 0x05 canonical selection. The selection is only the canonical option key (YES/NO, REMOVE/KEEP, or candidate option key); labels and candidate free text are frozen in ProcessBallotOption and are not submitted as vote choices.

The versioned canonical chain input uses Encoding V1 TLV with these ascending, unique tags: `0x01` hash/chain encoding version (unsigned integer), `0x02` process_id, `0x03` sequence_no (unsigned integers), `0x04` previous_hash (32 raw bytes), `0x05` canonical_vote_payload (raw canonical selection-envelope bytes), `0x06` country_id, `0x07` province_id, `0x08` county_id, `0x09` settlement_id (unsigned integers), and `0x0A` recorded_at (RFC 3339 UTC with exactly three fractional digits). The chain hash is SHA-256 over domain prefix `0x02` followed by this TLV byte sequence; the algorithm identifier is `SHA-256-TLV1-DOMAIN02`, frozen by `hash_version`. It excludes token/identity fields, client metadata, receipt number, ballot idempotency key, and `DigitalReceipt.receipt_hash` (which would create a circular dependency). The receipt is signed after `current_hash` exists and includes that commitment; receipt signing does not alter the chain. Merkle leaves remain ordered BallotBoxEntry.current_hash values. Insert, allocator advancement, and outbox event commit atomically under the locked ProcessSequenceAllocator.

**# 38. ProcessSequenceAllocator**

**## 38.1. Definition**

ProcessSequenceAllocator is a narrow operational concurrency-control
entity that maintains the live append state of a process-specific ballot
hash chain. Its sole purpose is to serialize append operations, allocate
the next gap-free sequence number, and expose the current committed tail
hash required to compute the next chain entry atomically.

This entity is not the immutable transaction ledger and must not be
treated as a final audit artifact. It is a mutable append-state helper
used only during the active chain-building lifecycle of a process.

**## 38.2. Attributes**

| **Attribute** | **Data Type** | **Nullability** | **Key Role** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| process_id | BIGINT UNSIGNED | No | Primary Key / Foreign Key | Reference to the parent Process. |
| next_sequence_no | BIGINT UNSIGNED | No | Operational State | Next sequence number to be allocated for the next committed append. |
| last_hash | BINARY(32) | No | Operational State | Current committed tail hash of the process ballot hash chain. |
| hash_version | VARCHAR(50) | No | Operational Policy Snapshot | Active chain-hash algorithm / canonical chain serialization version used for append computation. |
| last_appended_at | DATETIME(6) | No | Operational TIMESTAMP(6) | UTC DATETIME of the most recent successful committed append reflected in this allocator row. |

**## 38.3. Constraints & Business Rules**

- **Primary Key:** process_id.

- **Actual RDBMS Foreign Key:**

  - process_id references Process(process_id) (ON DELETE RESTRICT ON
    UPDATE RESTRICT).

- **Purpose Limitation Rule:**

  - This entity is an operational append-state primitive only.

  - It is not the system source of truth for transaction history.

  - The immutable BallotBoxEntry ledger remains the authoritative source
    of truth for ballot-chain history.

- **Locking Rule:**

  - In the append pipeline, this row must be acquired using SELECT ...
    FOR UPDATE or an equivalent row-level locking strategy within a
    single database transaction.

- **Canonical Lock Order Rule:**

  - All vote-commit transactions must acquire locks in one globally
    fixed order to reduce deadlock risk:

1. Process row;

2. VoteToken row;

3. ProcessSequenceAllocator row;

4. Insert VoterParticipation and BallotBoxEntry, then create the receipt and outbox row.

- First, resolve a retry by its ballot-only idempotency key; if an identical ballot already committed, return its existing receipt. For a new submission, lock Process, VoteToken, then ProcessSequenceAllocator in that globally fixed order, and revalidate process state/window, token ownership/hash/expiry/state, ballot schema, and geographic eligibility within the transaction. The authenticated account context is used only to locate/validate the token and is never persisted on the ballot. The token hash and identity key must not be copied into ballot or receipt data.

- Retry handling reuses the same ballot_submission_idempotency_key only in the ballot domain. It never reuses or stores the VoteToken issuance_idempotency_key in BallotBoxEntry or receipt data.

- **Append Preconditions Rule:**

  - The locked Process row must be in a state that permits voting.

  - The submitted VoteToken hash must match a token whose state is ISSUED and whose expiry is in the future for this process. The authenticated request must be authorized to use that token. Set token state to USED and consumed_at, insert the identity-side VoterParticipation, insert the ballot, create the signed bearer receipt, advance the sequence allocator, and insert the projection outbox event in one database transaction. Roll back all effects if any step fails. No token/identity identifier is persisted in ballot, receipt detail, chain input, or outbox payload.

  - The allocator row must exist, be initialized with the approved
    genesis state where applicable, and use the active permitted
    hash_version.

- **Gap-Free Allocation Rule:**

  - next_sequence_no must increase by exactly 1 for each successfully
    committed append.

  - Rolled-back transactions must not advance committed allocator state.

- **Tail Consistency Rule:**

  - After every committed vote-append transaction, last_hash must equal
    the current_hash of the BallotBoxEntry whose sequence_no equals
    next_sequence_no - 1 for the same process_id.

  - This invariant must be established by the same transaction that
    inserts BallotBoxEntry and updates ProcessSequenceAllocator.

- **Genesis Initialization Rule:**

  - The allocator row must be created exactly once when the process
    becomes chain-append-capable.

  - Bootstrap values must be deterministic and standardized:

- next_sequence_no = 1

- last_hash = \<GENESIS_HASH_CONSTANT\>

  - The genesis constant must be fixed per hash_version and documented
    in the chain specification.

  - For `SHA-256-TLV1-DOMAIN02`, `GENESIS_HASH_CONSTANT` is the 32-byte
    value with hexadecimal encoding
    `7ccce824e27b9c71eac9c6024bed6b1c2e20a339d650b617b7450b38e7d5cfc6`
    (SHA-256 of the UTF-8 domain string
    `vetoapp-chain-genesis|SHA-256-TLV1-DOMAIN02`).

  - The genesis constant must resolve to a 32-byte value compatible with
    BINARY(32).

- **Hash Version Stability Rule:**

  - hash_version must remain stable for the entire uninterrupted append
    lifecycle of a process.

  - Mixed hash versions within a single process chain are prohibited
    unless a formally versioned migration policy explicitly exists.

- **Hot-Row Minimization Rule:**

  - This row must remain physically narrow and operationally minimal to
    reduce lock contention and transaction duration.

  - No nonessential business columns may be added to this entity.

- **Mutation Scope Rule:**

  - Only the append transaction pipeline may update this table.

  - No analytical, reporting, or asynchronous repair process may mutate
    allocator state directly.

- **DATETIME Rule:**

  - last_appended_at represents the server-side common vote-commit
    timestamp of the most recent successful committed append.

**## 38.4. Relationships**

- **Process 1 — 1 ProcessSequenceAllocator (Actual RDBMS FK):** Each
  append-capable process owns exactly one live allocator row during its
  active chain-building lifecycle.

**## 38.5. Indexes**

- PRIMARY KEY (process_id)

**# 39. ProcessChainHead**

**## 39.1. Definition**

ProcessChainHead is the finalized, frozen checkpoint of a process ballot
chain. It stores the terminal committed sequence state and final tail
hash after the process reaches formal closure or finalization.

This entity is the authoritative end-of-chain evidence artifact for
verification, publication, reconciliation, and downstream integrity
attestation. Unlike ProcessSequenceAllocator, it is not used for append
concurrency control and exists only to persist the finalized chain
state.

**## 39.2. Attributes**

| **Attribute** | **Data Type** | **Nullability** | **Key Role** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| process_id | BIGINT UNSIGNED | No | Primary Key / Foreign Key | Reference to the parent Process. |
| last_sequence_no | BIGINT UNSIGNED | No | Final State | Final committed sequence number in the process chain. |
| last_hash | BINARY(32) | No | Final State | Final committed tail hash of the process chain. |
| hash_version | VARCHAR(50) | No | Final Policy Snapshot | Chain-hash algorithm / canonical chain serialization version used by the finalized chain. |
| finalized_at | DATETIME(6) | No | Finalization TIMESTAMP(6) | UTC DATETIME(6) when the chain-head checkpoint was formally finalized. |

**## 39.3. Constraints & Business Rules**

- **Primary Key:** process_id.

- **Actual RDBMS Foreign Key:**

  - process_id references Process(process_id) (ON DELETE RESTRICT ON
    UPDATE RESTRICT).

- **Finalization-State Rule:**

  - This entity may be inserted only when the process is in a formally
    permitted finalization state according to the active process-state
    and transition policy.

  - A process without any committed BallotBoxEntry must not be
    finalized.

  - A process that has accepted ballots enters Publishing, atomically stops further appends and freezes ProcessChainHead, then generates and publishes the FINAL ProcessMerkleTree checkpoint. It may enter Finalized only after that checkpoint verifies against the frozen chain head; or

- it enters the Failed state without any voting activity and does not
  create ProcessChainHead or ProcessMerkleTree records.

- **Single-Checkpoint Rule:**

  - At most one chain-head record may exist per process.

- **Chain Consistency Rule:**

  - last_hash must equal the current_hash of the immutable ledger entry
    whose sequence_no = last_sequence_no within the same process_id.

- **Allocator Consistency Rule:**

  - At finalization time, the chain head must match the live allocator
    state exactly:

- last_sequence_no = ProcessSequenceAllocator.next_sequence_no - 1

- last_hash = ProcessSequenceAllocator.last_hash

- hash_version = ProcessSequenceAllocator.hash_version

- **Finalization Atomicity Rule:**

  - Process finalization must lock the Process row and
    ProcessSequenceAllocator row using the canonical lock protocol.

  - Transition into Publishing, the ProcessChainHead insert, and the rule prohibiting further ballot appends must commit atomically.

  - After this closure transaction commits, no new BallotBoxEntry may be appended. The FINAL Merkle checkpoint is then built from the frozen head; transition Publishing → Finalized is allowed only after its signed checkpoint is persisted and verified.

- **Frozen Checkpoint Rule:**

  - After successful persistence, this record is immutable under normal
    operation.

  - Re-finalization with different values is strictly prohibited.

  - If idempotent retry logic is required, it may only reproduce the
    exact same persisted values.

- **Authoritative Final Tail Rule:**

  - After process finalization, this entity becomes the authoritative
    frozen tail-state artifact for external verification and
    publication.

- **No Lifecycle Flags Rule:**

  - This entity must not contain mutable lifecycle columns such as
    updated_at, is_active, or soft-delete markers.

- **DATETIME Rule:**

  - finalized_at is a formal business event DATETIME, not a mutable
    record-maintenance DATETIME(6).

**## 39.4. Relationships**

- **Process 1 — 0…1 ProcessChainHead (Actual RDBMS FK):** A process that
  successfully completes Vote Casting may have exactly one frozen
  chain-head checkpoint.

- **ProcessSequenceAllocator 1 — 0…1 ProcessChainHead (Logical
  Finalization Dependency):** The finalized chain-head is derived from
  the allocator’s committed append state at the moment of closure.

**## 39.5. Indexes**

- PRIMARY KEY (process_id)

**# 40. ProcessMerkleTree**

Append-only history of signed Merkle tree heads published for a process. Each row is one immutable checkpoint over the exact BallotBoxEntry prefix through `last_sequence_no`; interim checkpoints support periodic result publication and the final checkpoint covers ProcessChainHead. Prior checkpoints are never overwritten or deleted.

| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| merkle_tree_id | BIGINT UNSIGNED | No | PK | Checkpoint row ID. |
| process_id | BIGINT UNSIGNED | No | FK | Process. |
| checkpoint_no | BIGINT UNSIGNED | No | UQ with process | Monotonic publication order. |
| previous_checkpoint_id | BIGINT UNSIGNED | Yes | FK | Immediately previous checkpoint for this process. |
| supersedes_checkpoint_id | BIGINT UNSIGNED | Yes | FK | Prior artifact explicitly corrected by a CORRECTION checkpoint; otherwise NULL. |
| correction_reason | VARCHAR(500) | Yes | — | Required for CORRECTION; NULL for PERIODIC/FINAL. |
| checkpoint_kind | VARCHAR(20) | No | — | PERIODIC, FINAL, or CORRECTION. |
| root_hash | BINARY(32) | No | — | Merkle root over committed chain leaves through last_sequence_no. |
| tree_version | VARCHAR(50) | No | — | Exact Merkle construction version. |
| canonical_encoding_version | SMALLINT UNSIGNED | No | — | Ballot/hash serialization version. |
| leaf_count | BIGINT UNSIGNED | No | — | Tree size. |
| last_sequence_no | BIGINT UNSIGNED | No | — | Highest vote sequence committed in this prefix. |
| source_outbox_watermark | BIGINT UNSIGNED | No | — | Highest fully applied process projection event represented by the published aggregate result. |
| signature_value | VARBINARY(512) | No | — | Signature over canonical tree-head payload. |
| signing_key_id | VARCHAR(100) | No | — | Key identifier resolved through the retained public-key manifest. |
| generated_at | DATETIME(6) | No | — | Exact UTC checkpoint generation time. |
| published_at | DATETIME(6) | No | — | UTC time checkpoint became publicly retrievable. |

The signed tree-head payload is deterministic and includes domain tag, process_id, checkpoint_no, root_hash, leaf_count, last_sequence_no, tree_version, canonical_encoding_version, source_outbox_watermark, generated_at, signing_key_id, and previous checkpoint identifier. The private signing key is held outside MySQL in the controlled key-management boundary. The corresponding public-key manifest is versioned and retained so third parties can verify old signatures after rotation. Signing keys are domain-separated from receipt signing keys.

Aggregate result views refresh at `Process.result_publication_interval_seconds` (default 600 seconds). A periodic checkpoint is created at that cadence only when the committed ballot prefix advances and the result projection is complete through the declared watermark. Per-process outbox projection is ordered; the watermark is the highest event ID such that every event for that process up to that ID is processed. The aggregate shown with the checkpoint is read only through this watermark. These background steps never delay vote acceptance. The final checkpoint is generated after ProcessChainHead is frozen. A CORRECTION is a new row with a higher checkpoint_no and a recorded correction reason, supersedes_checkpoint_id, actor, and timestamp in the existing governed admin activity audit; it never updates or deletes the prior artifact. A same-size corrected tree must be explicitly marked CORRECTION and linked to the checkpoint it supersedes; it is not represented as an ordinary append-only consistency step. A CORRECTION does not itself adjudicate a complaint; it records an operationally authorized publication correction.

Merkle V1 follows the RFC 9162 Merkle Tree Hash shape so inclusion and append-only consistency proofs have a deterministic, interoperable construction: leaves in ascending sequence order are `SHA-256(0x00 || BallotBoxEntry.current_hash)`; for a subtree with more than one leaf, split at the largest power of two strictly smaller than its leaf count and hash `SHA-256(0x01 || left_subtree_root || right_subtree_root)`. A one-leaf subtree root is its leaf hash; for zero leaves, the root is `SHA-256(empty byte string)`. No ballot-level token, identity, receipt, or idempotency data is included in the tree input. An inclusion proof for a ballot is computed from the retained immutable BallotBoxEntry prefix and returned with the selected signed checkpoint. A consistency proof between two append-only checkpoints is computed from their ordered leaf prefixes using the RFC 9162 proof construction. Proof bytes need not be stored as rows because they are deterministic from the retained ledger and tree version; they must remain publicly obtainable and independently verifiable. The public tree version is `RFC9162-SHA256-CHAINHASH-V1`; the verifier must implement the stated zero-leaf rule exactly.

Only aggregate result views are refreshed during VoteCasting, at the configured interval. The complete ballot archive and final verification dataset become public after the process closes and its final checkpoint is published. Publication of individual choices is explicit in this transparency policy; exact UTC timestamps and geography are not rounded or delayed.

Constraints: unique `(process_id, checkpoint_no)`; previous and superseded checkpoints must belong to the same process; previous checkpoint has lower checkpoint_no; `leaf_count = last_sequence_no` for gap-free prefixes; every checkpoint is immutable; correction_reason and supersedes_checkpoint_id are required iff checkpoint_kind=CORRECTION; the FINAL checkpoint matches ProcessChainHead. Index `(process_id, published_at)` and `(process_id, leaf_count)`. `ProcessMerkleTree` is a publication-history table, not a challenge/appeal case ledger. No challenge, evidence-submission, or dispute-workflow entities are defined in this DRM.

**# 41. Notification**

**## 41.1. Definition**

Notification is the authoritative “Master Record” of a business event
that requires communication. It defines **what** is being announced and
**why**, serving as the source template for both individual in-app inbox
items (UserNotification) and outbound deliveries (NotificationDispatch).

**## 41.2. Attributes**

| **Attribute** | **Type** | **Null** | **Key** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| notification_id | BIGINT UNSIGNED | No | PK | Surrogate primary key. |
| process_id | BIGINT UNSIGNED | No | FK | The process context this notification belongs to. |
| notification_type | VARCHAR(50) | No | — | Category (e.g., PROCESS_FINALIZED, SECURITY_ALERT). |
| audience_scope | VARCHAR(50) | No | — | Target scope: PUBLIC, PARTICIPANTS, TARGETED_USERS. |
| source_entity_type | VARCHAR(50) | Yes | — | Polymorphic type (e.g., DigitalReceipt, Process). |
| source_entity_id | BIGINT UNSIGNED | Yes | — | ID of the triggering entity. |
| title_template_key | VARCHAR(100) | No | — | Localization key for the title. |
| body_template_key | VARCHAR(100) | No | — | Localization key for the body. |
| payload_snapshot | JSON | Yes | — | Immutable data required for template rendering. |
| priority | VARCHAR(20) | No | — | HIGH, NORMAL, LOW. |
| state | VARCHAR(30) | No | — | DRAFT, READY, CANCELLED. |
| created_at | DATETIME | No | — | UTC creation timestamp. |

**## 41.3. Constraints & Business Rules**

- **Immutability:** payload_snapshot and template keys are immutable
  after the state becomes READY.

- **Source Pair:** source_entity_type and source_entity_id must be both
  NULL or both populated.

- **Process Binding:** Every notification must be linked to a valid
  process_id.

- **No ENUMs:** Use VARCHAR with application-level validation.

**# 42. NotificationDispatch**

**## 42.1. Definition**

NotificationDispatch tracks the technical delivery of a Notification
through external channels (Telegram, SMS, Push). It manages retries,
failures, and idempotency for outbound transport.

**## 41.2. Attributes**

| **Attribute** | **Type** | **Null** | **Key** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| notification_dispatch_id | BIGINT UNSIGNED | No | PK | Surrogate primary key. |
| notification_id | BIGINT UNSIGNED | No | FK | Reference to the master Notification. |
| user_profile_id | BIGINT UNSIGNED | Yes | FK | Target user (NULL for public broadcasts). |
| channel_type | VARCHAR(50) | No | — | TELEGRAM, SMS, PUSH_NOTIFICATION. |
| idempotency_key | BINARY(32) | No | UQ | Prevents duplicate sends for the same event/channel. |
| state | VARCHAR(30) | No | — | PENDING, SENT, FAILED, RETRYING. |
| attempt_count | TINYINT UNSIGNED | No | — | Number of delivery attempts. |
| last_error | VARCHAR(500) | Yes | — | Last error message from the provider. |
| sent_at | DATETIME | Yes | — | Final success timestamp. |
| created_at | DATETIME | No | — | UTC creation timestamp. |

**## 42.3. Constraints & Business Rules**

- **Idempotency:** Unique constraint on (notification_id,
  user_profile_id, channel_type) via idempotency_key.

- **Ownership:** Bound to user_profile_id for targeted delivery.

- **Strict FKs:** ON DELETE RESTRICT ON UPDATE RESTRICT.

**# 43. UserNotification**

**## 43.1. Definition**

UserNotification represents the **In-App Inbox** instance of a
notification for a specific user. It tracks whether the user has seen or
read the message. It references the master Notification to avoid data
duplication.

**## 43.2. Attributes**

| **Attribute** | **Type** | **Null** | **Key** | **Description** |
|:--:|:--:|:--:|:--:|:--:|
| user_notification_id | BIGINT UNSIGNED | No | PK | Surrogate primary key. |
| user_profile_id | BIGINT UNSIGNED | No | FK | **Owner Profile** (The inbox this belongs to). |
| notification_id | BIGINT UNSIGNED | No | FK | Reference to the Master Notification. |
| is_archived | TINYINT(1) | No | — | Whether the user hid this from their active inbox. |
| read_at | DATETIME | Yes | — | UTC timestamp of first read. (NULL = Unread). |
| created_at | DATETIME | No | — | UTC creation timestamp. |

**## 43.3. Constraints & Business Rules**

- **One-Way Read State:** read_at can transition from NULL to a
  timestamp exactly once. It cannot be reset to NULL.

- **Profile Binding:** Bound permanently to user_profile_id (replaces
  the old account_instance_id).

- **Uniqueness:** A user should only receive one inbox entry per
  notification_id. Unique key: (user_profile_id, notification_id).

- **Data Integrity:** To render the inbox, the system joins
  UserNotification with Notification to get templates and payloads.

**## 43.4. Indexes**

- PRIMARY KEY (user_notification_id)

- UNIQUE (user_profile_id, notification_id)

- INDEX (user_profile_id, read_at, created_at): Optimized for “Show
  Unread First” inbox queries.

- INDEX (user_profile_id, created_at DESC): Standard inbox sorting.

**# 44. NationalIdAreaEligibility**

**## 44.1. Definition**

\`NationalIdAreaEligibility\` is a reference table used by the
application during the registration workflow to evaluate age eligibility
based on national ID segments.

Each row represents one first-three-digit national ID prefix. During
registration, the application extracts the first three digits and the
second three digits from the submitted national ID before storing only
the hashed and encrypted national ID values in \`RegistrationDraft\`.
The first segment is used to load the corresponding row from this table.
The second segment is evaluated in the application layer against two
allowed ranges defined in the row.

If the second segment falls within either allowed range, the applicant
may continue registration. Otherwise, the applicant is evaluated as not
satisfying the age eligibility requirement.

**## 44.2. Attributes**

\- \`national_id_prefix_3\` — first three digits of the national ID;
stored as \`SMALLINT UNSIGNED\`; primary key.

\- \`first_range_from\` — lower bound of the first allowed range for the
second three-digit segment; stored as \`SMALLINT UNSIGNED\`.

\- \`first_range_to\` — upper bound of the first allowed range for the
second three-digit segment; stored as \`SMALLINT UNSIGNED\`.

\- \`second_range_from\` — lower bound of the second allowed range for
the second three-digit segment; stored as \`SMALLINT UNSIGNED\`.

\- \`second_range_to\` — upper bound of the second allowed range for the
second three-digit segment; stored as \`SMALLINT UNSIGNED\`.

\- \`created_at\` — record creation timestamp.

\- \`updated_at\` — record last update timestamp.

**## 44.3. Constraints & Business Rules**

\- \`national_id_prefix_3\` is the primary key.

\- There is no separate surrogate identifier for this table.

\- All prefix and range boundary columns use \`SMALLINT UNSIGNED\`.

\- Each row defines two allowed ranges for the second three-digit
national ID segment.

\- The table has no foreign keys in the current model.

\- The table does not enforce registration eligibility at the database
level.

\- Registration eligibility is evaluated in the application layer before
national ID hash/encryption persistence.

\- \`RegistrationDraft\` stores only the hashed and encrypted national
ID values, not the extracted prefix or second segment.

\- If the second segment falls within either allowed range for the
matching prefix, registration may continue.

\- If no matching prefix row exists, or if the second segment falls
outside both ranges, the applicant is evaluated as age-ineligible.

\- Administrative seeding/update control may be introduced later if an
Admin/Operator entity is added.

**## 44.4. Relationships**

None in the current model.

**## 44.5. Indexes**

\- \`PRIMARY KEY (national_id_prefix_3)\`


**# 45. ProcessBallotOption**

Canonical process-specific ballot options. The complete set is frozen before VoteCasting.

| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| process_ballot_option_id | BIGINT UNSIGNED | No | PK | Option ID. |
| process_id | BIGINT UNSIGNED | No | FK | Owning process. |
| option_key | VARCHAR(80) | No | UQ with process | Stable key stored in ballot payload. |
| option_type_code | VARCHAR(30) | No | — | YES_NO, REMOVE_KEEP, CANDIDATE. |
| display_label | VARCHAR(255) | No | — | Frozen label. |
| candidate_given_name | VARCHAR(100) | Yes | — | Candidate free text, server-normalized. |
| candidate_family_name | VARCHAR(120) | Yes | — | Candidate free text, server-normalized. |
| candidate_father_name | VARCHAR(100) | Yes | — | Candidate free text, server-normalized. |
| is_active | TINYINT(1) | No | 1 | Selectable before voting opens. |
| created_at | DATETIME | No | — | UTC. |

Referendum options are YES/NO; impeachment options REMOVE/KEEP; election options identify candidates using normalized name, family name and father's name. The ballot stores the option key, never user-supplied display text. Validate option type against process type; freeze options on entry to VoteCasting. Enforce `UNIQUE(process_id, option_key)` and reference the option using a composite `(process_id, option_key)` FK.

**# 46. ProcessProjectionOutboxEvent**

Durable event source for asynchronous ProcessGeographicCounter updates and downstream process notifications. A source support or ballot commit inserts its projection event atomically with the source ledger transaction. Event payload is immutable; delivery state is maintained separately or changed only through controlled processing metadata.

| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| process_projection_outbox_event_id | BIGINT UNSIGNED | No | PK | Event ID. |
| process_id | BIGINT UNSIGNED | No | FK | Process. |
| event_type_code | VARCHAR(40) | No | — | SUPPORT_COMMITTED or BALLOT_COMMITTED. |
| source_record_id | BIGINT UNSIGNED | No | — | Source ledger row ID. |
| event_key | BINARY(32) | No | UQ | Domain-separated digest of event type and source record identity; not an identity or client idempotency key. |
| payload | JSON | No | — | Process, counter metric, geography snapshot, and option key; never participant identity, account, receipt locator, or voter-side idempotency key. |
| created_at | DATETIME | No | — | Exact UTC creation time. |
| processed_at | DATETIME | Yes | — | UTC application time; NULL while pending. |
| attempts | SMALLINT UNSIGNED | No | 0 | Delivery attempts. |

Unique `(event_type_code, source_record_id)` and `event_key`; indexes `(processed_at, process_projection_outbox_event_id)` and `(process_id, process_projection_outbox_event_id)`. Workers lock/claim events and atomically mark them processed with the counter increment and threshold-state transition. Reprocessing a committed event cannot increment twice. For threshold increments, event order is not semantically significant; however, result-publication watermark advancement is per-process and contiguous. A worker may publish watermark N only after every event for that process through N has been applied. Workers partition/claim work by process and use idempotent event identity; per-process state/counter rows are locked so concurrent application and threshold transition serialize. Failed delivery remains retryable. Rebuild events are idempotent and must not masquerade as new support/vote facts.

**# 47. VoteTokenStateLookup**

Controlled token lifecycle vocabulary.

| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| token_state_code | VARCHAR(20) | No | PK | Stable code: ISSUED, USED, REVOKED, EXPIRED. |
| title | VARCHAR(100) | No | — | Display label. |
| is_terminal | TINYINT(1) | No | — | Terminal-state indicator. |
| created_at | DATETIME | No | — | UTC seed timestamp. |

Expiry validity is always checked against `expires_at` and server UTC even if a background worker has not yet materialized the EXPIRED state. Transitions are monotonic: ISSUED may become USED, REVOKED, or EXPIRED; terminal states do not transition back to ISSUED. Rows are seeded and changed only through governed migrations.


**# 48. ShardCatalog**

Control-plane catalogue of logical process-data shards. It contains routing identifiers and operational state only; connection endpoints, credentials, and secrets are supplied by protected infrastructure configuration.

| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| shard_id | VARCHAR(50) | No | PK | Stable logical routing identifier. |
| shard_state_code | VARCHAR(20) | No | — | PROVISIONING, ONLINE, DRAINING, OFFLINE. |
| schema_version | VARCHAR(50) | No | — | Process-schema compatibility level. |
| created_at | DATETIME(6) | No | — | UTC catalogue creation time. |
| updated_at | DATETIME(6) | No | — | UTC state-change time. |

ShardCatalog is stored in the unsharded control plane. Application credentials may discover an allowed shard through the routing service, but SQL credentials and endpoints are not returned to clients. A shard is eligible for new placements only while ONLINE and schema-compatible.

**# 49. ProcessShardPlacement**

Authoritative control-plane mapping from each globally unique process ID to exactly one process-data shard. It allocates process IDs globally and routes reads/writes; it contains no support ledger, ballot, receipt payload, identity data, chain hash, or Merkle leaf.

| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| process_id | BIGINT UNSIGNED | No | PK, AUTO_INCREMENT | Globally allocated by this single control-plane sequence, reused as the route key on every process-scoped table. It is never independently auto-incremented inside process shards. |
| shard_id | VARCHAR(50) | No | FK | Current assigned ShardCatalog entry. |
| placement_state_code | VARCHAR(20) | No | — | CREATING, ACTIVE, MIGRATING, FAILED. Only ACTIVE placements are exposed for normal reads/writes. |
| placement_version | SMALLINT UNSIGNED | No | — | Monotonic placement generation. |
| assigned_at | DATETIME(6) | No | — | UTC initial assignment time. |
| activated_at | DATETIME(6) | Yes | — | UTC time process became routable. |
| updated_at | DATETIME(6) | No | — | UTC latest placement-state change. |

Process creation uses a retryable control-plane workflow: allocate process_id and placement in CREATING, create the process and its local records on the assigned shard, then mark the placement ACTIVE. A process is not listed or accepted for support/voting before activation. The local shard's Process.process_id is supplied by this allocator and is not a shard-local auto-increment.

ProcessShardPlacement is an unsharded directory. Shards do not use a cross-server RDBMS foreign key to this table; application routing resolves placement before opening the process transaction. The process row and all process-scoped child rows stay local to that shard.

**# 50. ProcessShardPlacementHistory**

Append-only event trail for initial placement and any controlled process migration. Each state transition is a separate row; history rows are never updated or deleted. It makes a routing change visible and provides the verification evidence required before cutover.

| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| placement_history_id | BIGINT UNSIGNED | No | PK | History row ID. |
| process_id | BIGINT UNSIGNED | No | INDEX | Globally unique process ID. |
| placement_version | SMALLINT UNSIGNED | No | INDEX with process | Placement generation. |
| placement_event_no | SMALLINT UNSIGNED | No | UQ with process/version | Monotonic event number within one placement operation. |
| source_shard_id | VARCHAR(50) | Yes | — | Previous shard; NULL on first placement. |
| destination_shard_id | VARCHAR(50) | No | — | New assigned shard. |
| operation_event_code | VARCHAR(30) | No | — | PLACEMENT_PREPARED, DATA_COPIED, CHAIN_VERIFIED, MERKLE_VERIFIED, CUTOVER, ABORTED. |
| verified_last_sequence_no | BIGINT UNSIGNED | Yes | — | Chain boundary verified before cutover. |
| verified_last_hash | BINARY(32) | Yes | — | Chain head verified before cutover. |
| verified_merkle_checkpoint_no | BIGINT UNSIGNED | Yes | — | Latest signed checkpoint verified before cutover, when one exists. |
| created_at | DATETIME(6) | No | — | UTC operation start. |
| completed_at | DATETIME(6) | Yes | — | UTC completion/abort time. |

Unique `(process_id, placement_version, placement_event_no)`. A move cannot activate until source writes are fenced and chain/Merkle verification succeeds. The current mapping switches once; concurrent writes to source and destination are prohibited. A failed move leaves the prior ACTIVE placement authoritative.
