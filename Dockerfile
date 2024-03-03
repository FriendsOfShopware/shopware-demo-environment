ARG PHP_VERSION=8.3
FROM friendsofshopware/shopware-cli:latest-php-${PHP_VERSION} as creation
ARG SHOPWARE_VERSION=6.5.8.2

RUN <<EOF
    set -e
    shopware-cli project create /shop ${SHOPWARE_VERSION}
    shopware-cli project ci /shop
    COMPOSER_ALLOW_SUPERUSER=1 composer -d /shop require "swag/demo-data:*"
EOF

COPY --chmod=555 <<EOF /shop/config/packages/override.yaml
parameters:
    env(TRUSTED_PROXIES): ''

framework:
    trusted_proxies: '%env(TRUSTED_PROXIES)%'

shopware:
    auto_update:
        enabled: false
    store:
        frw: false
EOF

FROM shopware/docker-base:${PHP_VERSION}-caddy

COPY --from=creation /shop /var/www/html

ENV DATABASE_URL=mysql://root:root@localhost/shopware

COPY --from=composer/composer:2-bin /composer /usr/bin/composer

USER root

RUN <<EOF
    set -e
    apk add --no-cache mariadb mariadb-client
    mysql_install_db --datadir=/var/lib/mysql --user=www-data
    mkdir /run/mysqld/ && chown -R www-data /run/mysqld/
EOF

COPY --chmod=555 <<EOF /usr/local/etc/php/conf.d/mysql-fix.ini
pdo_mysql.default_socket=/run/mysqld/mysqld.sock
mysqli.default_socket=/run/mysqld/mysqld.sock
EOF

COPY --chmod=555 <<EOF /usr/local/etc/php/conf.d/99-opcache-dev.ini
opcache.enable_file_override=0
EOF

RUN <<EOF
    set -e
    /usr/bin/mysqld --basedir=/usr --datadir=/var/lib/mysql --plugin-dir=/usr/lib/mysql/plugin --user=www-data &
    sleep 2
    mysqladmin --user=root password 'root'
    php bin/console system:install --create-database --force
    mysql -proot shopware -e "DELETE FROM sales_channel WHERE id = 0x98432def39fc4624b33213a56b8c944d"
    php bin/console user:create "admin" --admin --password="shopware" -n
    php bin/console sales-channel:create:storefront --name=Storefront --url="http://localhost/shop/public"
    php bin/console theme:change --all Storefront
    php bin/console plugin:refresh
    php bin/console plugin:install --activate SwagPlatformDemoData
    mysql -proot -e "SET GLOBAL innodb_fast_shutdown=0"
    mysql -proot shopware -e "INSERT INTO system_config (id, configuration_key, configuration_value, sales_channel_id, created_at, updated_at) VALUES (0xb3ae4d7111114377af9480c4a0911111, 'core.frw.completedAt', '{\"_value\": \"2019-10-07T10:46:23+00:00\"}', NULL, '2019-10-07 10:46:23.169', NULL);"
    chown -R www-data:www-data /var/www/html /var/lib/mysql/ /tmp/composer
EOF

USER www-data

COPY --link rootfs/ /

STOPSIGNAL SIGKILL

ENTRYPOINT ["/entrypoint.sh"]
