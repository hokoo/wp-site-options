<?php

declare(strict_types=1);

$projectRoot = dirname(__DIR__);
$autoloadPath = $projectRoot . '/vendor/autoload.php';

if (!is_file($autoloadPath)) {
    throw new RuntimeException(
        'Composer dependencies are missing. Run "composer install" from the project root.'
    );
}

require $autoloadPath;

if (!defined('WP_SITE_OPTIONS_TEST_ROOT')) {
    define('WP_SITE_OPTIONS_TEST_ROOT', $projectRoot);
}

// Source files use the standard WordPress direct-access guard. Unit tests load
// selected files explicitly and mock the WordPress functions they exercise.
if (!defined('ABSPATH')) {
    define('ABSPATH', $projectRoot . '/plugin-dir/');
}
