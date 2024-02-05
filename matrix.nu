mut data = {
    fail-fast: false,
    matrix: {
        include: []
    }
}

def version_compare [a, b] {
    let versions = [$a, $b]
    if ($versions | sort -r | first) == $a {
        return true
    } else {
        return false
    }
}

let versions = http get https://raw.githubusercontent.com/FriendsOfShopware/shopware-static-data/main/data/php-version.json | items {|key, value|
    {phpVersion: $value, shopwareVersion: ($key | str downcase)}
} | filter {|item|
    version_compare $item.shopwareVersion "6.5.6"
}

$data.matrix.include = $versions;

$data | to json
