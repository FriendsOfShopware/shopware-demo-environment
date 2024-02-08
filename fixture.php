<?php

$kernel = require '/opt/shopware/boot.php';

var_dump($kernel->getContainer()->get('product.repository')->getDefinition()->getEntityName());
