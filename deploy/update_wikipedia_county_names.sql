-- County display-name updates based on the Persian Wikipedia list
-- (https://fa.wikipedia.org/wiki/شهرستان‌های_ایران).
-- Idempotent: updates existing rows only; county IDs and child relations remain intact.
START TRANSACTION;

UPDATE counties c JOIN provinces p ON p.province_id = c.province_id
SET c.name_fa = 'بوئین میاندشت', c.updated_at = NOW()
WHERE p.name_fa = 'اصفهان' AND c.name_fa IN ('بویین میاندشت', 'بو یین و میاندشت');

UPDATE counties c JOIN provinces p ON p.province_id = c.province_id
SET c.name_fa = 'نائین', c.updated_at = NOW()
WHERE p.name_fa = 'اصفهان' AND c.name_fa = 'نایین';

UPDATE counties c JOIN provinces p ON p.province_id = c.province_id
SET c.name_fa = 'قائنات', c.updated_at = NOW()
WHERE p.name_fa = 'خراسان جنوبی' AND c.name_fa = 'قاینات';

UPDATE counties c JOIN provinces p ON p.province_id = c.province_id
SET c.name_fa = 'چابهار', c.updated_at = NOW()
WHERE p.name_fa IN ('سیستان و بلوچستان', 'سیستان وبلوچستان')
  AND c.name_fa IN ('چاهبهار', 'چاه بهار');

UPDATE counties c JOIN provinces p ON p.province_id = c.province_id
SET c.name_fa = 'بوئین زهرا', c.updated_at = NOW()
WHERE p.name_fa = 'قزوین' AND c.name_fa = 'بویین زهرا';

UPDATE counties c JOIN provinces p ON p.province_id = c.province_id
SET c.name_fa = 'دوره', c.updated_at = NOW()
WHERE p.name_fa = 'لرستان' AND c.name_fa = 'چگنی';

UPDATE counties c JOIN provinces p ON p.province_id = c.province_id
SET c.name_fa = 'قائمشهر', c.updated_at = NOW()
WHERE p.name_fa = 'مازندران' AND c.name_fa IN ('قایمشهر', 'قایم شهر');

UPDATE counties c JOIN provinces p ON p.province_id = c.province_id
SET c.name_fa = 'میاندرود', c.updated_at = NOW()
WHERE p.name_fa = 'مازندران' AND c.name_fa = 'میاندورود';

UPDATE counties c JOIN provinces p ON p.province_id = c.province_id
SET c.name_fa = 'ارزوئیه', c.updated_at = NOW()
WHERE p.name_fa = 'کرمان' AND c.name_fa = 'ارزوییه';

UPDATE counties c JOIN provinces p ON p.province_id = c.province_id
SET c.name_fa = 'بهمئی', c.updated_at = NOW()
WHERE p.name_fa IN ('کهگیلویه و بویراحمد', 'کهگیلویه وبویراحمد')
  AND c.name_fa = 'بهمیی';

UPDATE counties c JOIN provinces p ON p.province_id = c.province_id
SET c.name_fa = 'علی‌آباد', c.updated_at = NOW()
WHERE p.name_fa = 'گلستان' AND c.name_fa IN ('علیابادکتول', 'علی آباد کتول', 'علی‌آباد کتول');

UPDATE counties c JOIN provinces p ON p.province_id = c.province_id
SET c.name_fa = 'تالش', c.updated_at = NOW()
WHERE p.name_fa = 'گیلان' AND c.name_fa = 'طوالش';

COMMIT;
