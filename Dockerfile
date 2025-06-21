# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv
FROM friendsofshopware/shopware-cli:latest-php-8.3 AS creation
ARG SHOPWARE_VERSION=6.5.8.2

RUN <<EOF
    set -e
    export COMPOSER_ALLOW_SUPERUSER=1
    shopware-cli project create /shop ${SHOPWARE_VERSION}
    shopware-cli project ci /shop
    composer -d /shop require "swag/demo-data:*"
EOF

COPY --chmod=555 <<EOF /shop/config/packages/override.yaml
parameters:
    env(TRUSTED_PROXIES): ''

framework:
    trusted_proxies: '%env(TRUSTED_PROXIES)%'
    secrets:
        enabled: false
    mailer:
        message_bus: 'messenger.default_bus'

shopware:
    auto_update:
        enabled: false
    store:
        frw: false
    cart:
      compress: false
    cache:
        cache_compression: true
        cache_compression_method: 'zstd'
    mail:
        update_mail_variables_on_send: false
    increment:
        user_activity:
            type: 'array'
        message_queue:
            type: 'array'
    admin_worker:
        enable_admin_worker: false
        enable_queue_stats_worker: false
        enable_notification_worker: false


monolog:
    handlers:
        main:
            level: error
            buffer_size: 30
        business_event_handler_buffer:
            level: error
EOF

FROM ghcr.io/shyim/wolfi-php/nginx:8.3

COPY --from=creation /shop /var/www/html

ENV DATABASE_URL=mysql://root:root@localhost/shopware \
    LOCK_DSN=flock \
    PHP_MEMORY_LIMIT=512M \
    COMPOSER_ROOT_VERSION=1.0.0 \
    TRUSTED_PROXIES=REMOTE_ADDR \
    SHOPWARE_CACHE_ID=docker \
    PHP_OPCACHE_FILE_OVERRIDE=1 \
    SQL_SET_DEFAULT_SESSION_VARIABLES=0 \
    DATABASE_PERSISTENT_CONNECTION=1 \
    APP_URL_CHECK_DISABLED=1 \
    APP_URL=http://localhost:8000

COPY --from=composer/composer:2-bin /composer /usr/bin/composer

USER root

RUN <<EOF
    set -e

    apk add --no-cache \
        php-8.3 \
        php-8.3-fileinfo \
        php-8.3-openssl \
        php-8.3-ctype \
        php-8.3-curl \
        php-8.3-xml \
        php-8.3-dom \
        php-8.3-phar \
        php-8.3-simplexml \
        php-8.3-xmlreader \
        php-8.3-xmlwriter \
        php-8.3-bcmath \
        php-8.3-iconv \
        php-8.3-mbstring \
        php-8.3-gd \
        php-8.3-intl \
        php-8.3-pdo \
        php-8.3-pdo_mysql \
        php-8.3-mysqlnd \
        php-8.3-pcntl \
        php-8.3-sockets \
        php-8.3-bz2 \
        php-8.3-gmp \
        php-8.3-soap \
        php-8.3-zip \
        php-8.3-sodium \
        php-8.3-opcache \
        php-8.3-zstd \
        openssl-config \
        mariadb \
        mariadb-client \
        jq
EOF

RUN <<EOF
    set -e
    set -x
    mkdir -p /var/tmp /run/mysqld
    mariadb-install-db --datadir=/var/lib/mariadb --user=root

    mariadbd --basedir=/usr --datadir=/var/lib/mariadb --plugin-dir=/usr/lib/mariadb/plugin --user=root &

    i=1
    while [ $i -le 10 ]; do
        if mariadb-admin ping; then
            echo "Successfully connected to MariaDB on attempt $i!"
            break
        else
            echo "Attempt $i failed. Retrying in 5 seconds..."
            sleep 5
        fi
        i=$((i + 1))
    done

    if [ $i -gt 10 ]; then
        echo "Failed to connect to MariaDB after 10 attempts."
        exit 1
    fi

    mariadb-admin --user=root password 'root'
    php bin/console system:install --create-database --force
    mariadb -proot shopware -e "DELETE FROM sales_channel WHERE id = 0x98432def39fc4624b33213a56b8c944d"
    php bin/console user:create "admin" --admin --password="shopware" -n
    php bin/console sales-channel:create:storefront --name=Storefront --url="http://localhost/shop/public"
    php bin/console theme:change --all Storefront
    php bin/console plugin:refresh
    php -derror_reporting=E_ALL bin/console plugin:install --activate SwagPlatformDemoData
    mariadb -proot -e "SET GLOBAL innodb_fast_shutdown=0"
    mariadb -proot shopware -e "INSERT INTO system_config (id, configuration_key, configuration_value, sales_channel_id, created_at, updated_at) VALUES (0xb3ae4d7111114377af9480c4a0911111, 'core.frw.completedAt', '{\"_value\": \"2019-10-07T10:46:23+00:00\"}', NULL, '2019-10-07 10:46:23.169', NULL);"
    rm -rf var/cache/* /var/tmp/*
    php bin/console
    chown -R www-data:www-data /var/www/html /var/lib/mariadb/ /var/tmp /run/mysqld/
    echo "worker: /forever.sh php /var/www/html/bin/console messenger:consume --all --memory-limit=512M --time-limit=60" | tee -a /etc/Procfile
    echo "scheduled-task: /forever.sh php /var/www/html/bin/console scheduled-task:run --memory-limit=512M --time-limit=60" | tee -a /etc/Procfile
EOF

USER www-data

COPY --link rootfs/ /

STOPSIGNAL SIGKILL

ENTRYPOINT ["/entrypoint.sh"]
