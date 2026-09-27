#!/bin/sh
set -eu

: "${APP_DOMAIN:?APP_DOMAIN is required}"
: "${WORDPRESS_DOMAIN:?WORDPRESS_DOMAIN is required}"
: "${WORDPRESS_WWW_DOMAIN:?WORDPRESS_WWW_DOMAIN is required}"

api_certificate="/etc/letsencrypt/live/${APP_DOMAIN}/fullchain.pem"
wordpress_certificate="/etc/letsencrypt/live/${WORDPRESS_DOMAIN}/fullchain.pem"
template="/etc/nginx/vetoapp-templates/http.conf.template"

if [ -f "$api_certificate" ] && [ -f "$wordpress_certificate" ]; then
  template="/etc/nginx/vetoapp-templates/https.conf.template"
fi

envsubst '${APP_DOMAIN} ${WORDPRESS_DOMAIN} ${WORDPRESS_WWW_DOMAIN}' < "$template" > /etc/nginx/conf.d/default.conf

exec nginx -g 'daemon off;'
