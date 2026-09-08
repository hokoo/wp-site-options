<?php

declare(strict_types=1);

namespace Hokoo\WpSiteOptions\Tests\Unit;

use PHPUnit\Framework\TestCase;

final class HarnessSmokeTest extends TestCase
{
    public function testDevelopmentHarnessIsSeparatedFromPluginRuntime(): void
    {
        $projectRoot = (string) constant('WP_SITE_OPTIONS_TEST_ROOT');
        $pluginEntryPoint = $projectRoot . '/plugin-dir/wp-site-options.php';

        self::assertDirectoryExists($projectRoot . '/vendor');
        self::assertTrue(function_exists('Brain\\Monkey\\setUp'));
        self::assertFileExists($pluginEntryPoint);
        self::assertFileDoesNotExist($projectRoot . '/plugin-dir/vendor/autoload.php');

        $pluginSource = file_get_contents($pluginEntryPoint);

        self::assertIsString($pluginSource);
        self::assertStringNotContainsString('vendor/autoload.php', $pluginSource);
    }
}
