#!/usr/bin/env sh

set -e
set -x

/usr/bin/mysqld --basedir=/usr --datadir=/var/lib/mysql --plugin-dir=/usr/lib/mysql/plugin --user=mysql &

while ! mysqladmin ping --silent; do
    sleep 1
done

if [[ -n $APP_URL ]]; then
  mysql -proot shopware -e "UPDATE sales_channel_domain set url = '${APP_URL}'"
fi

if [[ ! -z $SHOPWARE_ADMIN_PASSWORD ]]; then
  ./bin/console user:change-password admin -n --password=$SHOPWARE_ADMIN_PASSWORD
fi

if [[  ! -z "$EXTENSIONS" ]]; then
    if [[ ! -z "$SHOPWARE_PACKAGIST_TOKEN" ]]; then
        composer config repositories.shopware-packages '{"type": "composer", "url": "https://packages.shopware.com"}'
        composer config bearer.packages.shopware.com "$SHOPWARE_PACKAGIST_TOKEN"
    fi

    composer req $EXTENSIONS

    php bin/console plugin:refresh

    list_with_plugins=$(php bin/console plugin:list --json | jq 'map(select(.installedAt == null)) | .[].name' -r)

    for plugin in $list_with_plugins; do
        php bin/console plugin:install --activate "$plugin"
    done
fi

if [[ -f /var/www/html/fixture.php ]]; then
    php -derror_reporting=E_ALL /var/www/html/fixture.php
fi

/usr/bin/supervisord -c /etc/supervisord.conf
