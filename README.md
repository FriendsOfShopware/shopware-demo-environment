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
    ghcr.io/friendsofshopware/shopware-demo-environment:6.5.7.4
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
    ghcr.io/friendsofshopware/shopware-demo-environment:6.5.7.4
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
    ghcr.io/friendsofshopware/shopware-demo-environment:6.5.7.4
```
