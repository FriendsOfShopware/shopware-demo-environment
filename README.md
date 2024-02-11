# Shopware Demo Environment

This repository contains a Docker image to run a Shopware 6 environment. It is based on the official Shopware 6 Docker image and adds some demo data to the database.

## Usage

To start the Shopware 6 environment, run the following command:

```bash
docker run \
    --rm \
    # External reachable URL, aka sales channel URL in shopware
    -e APP_URL=http://localhost:8000 \
    -p 8000:8000 \
    ghcr.io/friendsofshopware/shopware-demo-environment:6.5.7
```

[See here for all available images](https://github.com/FriendsOfShopware/shopware-demo-environment/pkgs/container/shopware-demo-environment/versions?filters%5Bversion_type%5D=tagged)

You can additionall set `SHOPWARE_ADMIN_PASSWORD` to set an different admin password.

To install Shopware 6 extensions you will need to set the `EXTENSIONS` environment variable. This variable should be a space separated list of composer packages. For example:

```bash
docker run \
    --rm \
    -e APP_URL=http://localhost:8000 \
    -e EXTENSIONS="frosh/tools" \
    -p 8000:8000 \
    ghcr.io/friendsofshopware/shopware-demo-environment:6.5.7
```

For Shopware Store plugins, you need to pass the `SHOPWARE_PACKAGIST_TOKEN` environment variable generated from a Wildcard environment.

Example:

```bash
docker run \
    --rm \
    -e APP_URL=http://localhost:8000 \
    -e EXTENSIONS="store.shopware.com/froshtools store.shopware.com/froshplatformsharebasket" \
    -e SHOPWARE_PACKAGIST_TOKEN=your-token \
    -p 8000:8000 \
    ghcr.io/friendsofshopware/shopware-demo-environment:6.5.7
```

## Running multiple containers

If you want to run multiple containers, you should deploy a Traefik before the containers. This will allow you to access the containers via different subdomains.

See as example the `compose.yml` file

## Custom Fixtures

You can inject a `fixture.php` to `/var/www/html` to run custom commands on the Shopware DI container to poupulate the database with custom data.

Example:

```bash
docker run \
    --rm \
    -e APP_URL=http://localhost:8000 \
    -e EXTENSIONS="frosh/tools" \
    -v $(pwd)/fixture.php:/var/www/html/fixture.php \
    -p 8000:8000 \
    ghcr.io/friendsofshopware/shopware-demo-environment:6.5.7
```

```php
<?php

$kernel = require '/opt/shopware/boot.php';

var_dump($kernel->getContainer()->get('product.repository')->getDefinition()->getEntityName());
```

and this script is executed on any container start, so you can use it to populate the database with custom data. All DI services are available in this script.

## Thanks to Namespace.so

Thanks to [namespace.so](https://namespace.so) for sponsoring their fast Docker builder with multi arch support. Checkout [namespace.so](https://namespace.so) if you need better GitHub runners or Docker remote builders.
