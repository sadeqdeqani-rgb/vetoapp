#!/usr/bin/env bash
set -Eeuo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-$HOME/vetoapp-telegram-test/deploy}"
COMPOSE_FILE="${COMPOSE_FILE:-compose.telegram-test.yaml}"
ENV_FILE="${ENV_FILE:-.env.telegram-test}"
EXPECTED_DB="${EXPECTED_DB:-vetoapp_telegram_test}"

cd "$DEPLOY_DIR"
[[ -f "$COMPOSE_FILE" && -f "$ENV_FILE" ]] || {
  echo "خطا: فایل Compose یا env پیدا نشد: $DEPLOY_DIR" >&2
  exit 1
}
compose=(sudo docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE")

actual_db="$("${compose[@]}" exec -T mysql sh -lc 'printf %s "$MYSQL_DATABASE"')"
if [[ "$actual_db" != "$EXPECTED_DB" ]]; then
  echo "توقف: دیتابیس کانتینر '$actual_db' است؛ انتظار '$EXPECTED_DB' بود. هیچ تغییری انجام نشد." >&2
  exit 1
fi

# Check schema before producing a dump or attempting updates.
"${compose[@]}" exec -T mysql sh -lc \
  'mysql --default-character-set=utf8mb4 -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" -N -e "SELECT county_id FROM counties LIMIT 0; SELECT province_id FROM provinces LIMIT 0;"' >/dev/null

stamp="$(date +%Y%m%d-%H%M%S)"
backup="$HOME/vetoapp-counties-before-update-$stamp.sql"
echo "پشتیبان دیتابیس پیش از تغییر: $backup"
"${compose[@]}" exec -T mysql sh -lc \
  'exec mysqldump --default-character-set=utf8mb4 --single-transaction -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' > "$backup"
[[ -s "$backup" ]] || { echo "خطا: فایل پشتیبان خالی است؛ تغییری انجام نشد." >&2; exit 1; }
chmod 600 "$backup"

"${compose[@]}" exec -T mysql sh -lc \
  'exec mysql --default-character-set=utf8mb4 -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' <<'SQL'
START TRANSACTION;
UPDATE counties c JOIN provinces p ON p.province_id=c.province_id SET c.name_fa='بوئین میاندشت',c.updated_at=NOW() WHERE p.name_fa='اصفهان' AND c.name_fa IN ('بویین میاندشت','بو یین و میاندشت');
UPDATE counties c JOIN provinces p ON p.province_id=c.province_id SET c.name_fa='نائین',c.updated_at=NOW() WHERE p.name_fa='اصفهان' AND c.name_fa='نایین';
UPDATE counties c JOIN provinces p ON p.province_id=c.province_id SET c.name_fa='قائنات',c.updated_at=NOW() WHERE p.name_fa='خراسان جنوبی' AND c.name_fa='قاینات';
UPDATE counties c JOIN provinces p ON p.province_id=c.province_id SET c.name_fa='چابهار',c.updated_at=NOW() WHERE p.name_fa IN ('سیستان و بلوچستان','سیستان وبلوچستان') AND c.name_fa IN ('چاهبهار','چاه بهار');
UPDATE counties c JOIN provinces p ON p.province_id=c.province_id SET c.name_fa='بوئین زهرا',c.updated_at=NOW() WHERE p.name_fa='قزوین' AND c.name_fa='بویین زهرا';
UPDATE counties c JOIN provinces p ON p.province_id=c.province_id SET c.name_fa='دوره',c.updated_at=NOW() WHERE p.name_fa='لرستان' AND c.name_fa='چگنی';
UPDATE counties c JOIN provinces p ON p.province_id=c.province_id SET c.name_fa='قائمشهر',c.updated_at=NOW() WHERE p.name_fa='مازندران' AND c.name_fa IN ('قایمشهر','قایم شهر');
UPDATE counties c JOIN provinces p ON p.province_id=c.province_id SET c.name_fa='میاندرود',c.updated_at=NOW() WHERE p.name_fa='مازندران' AND c.name_fa='میاندورود';
UPDATE counties c JOIN provinces p ON p.province_id=c.province_id SET c.name_fa='ارزوئیه',c.updated_at=NOW() WHERE p.name_fa='کرمان' AND c.name_fa='ارزوییه';
UPDATE counties c JOIN provinces p ON p.province_id=c.province_id SET c.name_fa='بهمئی',c.updated_at=NOW() WHERE p.name_fa IN ('کهگیلویه و بویراحمد','کهگیلویه وبویراحمد') AND c.name_fa='بهمیی';
UPDATE counties c JOIN provinces p ON p.province_id=c.province_id SET c.name_fa='علی‌آباد',c.updated_at=NOW() WHERE p.name_fa='گلستان' AND c.name_fa IN ('علیابادکتول','علی آباد کتول','علی‌آباد کتول');
UPDATE counties c JOIN provinces p ON p.province_id=c.province_id SET c.name_fa='تالش',c.updated_at=NOW() WHERE p.name_fa='گیلان' AND c.name_fa='طوالش';
COMMIT;
SQL

echo "کنترل نتیجه:"
"${compose[@]}" exec -T mysql sh -lc \
  'mysql --default-character-set=utf8mb4 -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" -N -e "SELECT CONCAT(\"county_count=\",COUNT(*)) FROM counties; SELECT CONCAT(p.name_fa,\" / \",c.name_fa) FROM counties c JOIN provinces p ON p.province_id=c.province_id WHERE c.name_fa IN (\"بوئین میاندشت\",\"نائین\",\"قائنات\",\"چابهار\",\"بوئین زهرا\",\"دوره\",\"قائمشهر\",\"میاندرود\",\"ارزوئیه\",\"بهمئی\",\"علی‌آباد\",\"تالش\") ORDER BY p.name_fa,c.name_fa;"'
echo "تمام شد. اگر لازم شد بازگردانی کنید: sudo docker compose --env-file $ENV_FILE -f $COMPOSE_FILE exec -T mysql sh -lc 'exec mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" \"\$MYSQL_DATABASE\"' < \"$backup\""
