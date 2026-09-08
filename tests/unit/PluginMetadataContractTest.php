<?php

declare(strict_types=1);

namespace Hokoo\WpSiteOptions\Tests\Unit;

use PHPUnit\Framework\TestCase;

final class PluginMetadataContractTest extends TestCase
{
    public function testPluginAndReadmeMetadataMeetTheReleaseBaseline(): void
    {
        $root = (string) constant('WP_SITE_OPTIONS_TEST_ROOT') . '/plugin-dir';
        $header = file_get_contents($root . '/wp-site-options.php');
        $readme = file_get_contents($root . '/readme.txt');

        self::assertIsString($header);
        self::assertIsString($readme);
        self::assertStringContainsString('Plugin Name: WP Site Options', $header);
        self::assertStringContainsString('License: GPLv2 or later', $header);
        self::assertStringContainsString('License URI: https://www.gnu.org/licenses/gpl-2.0.html', $header);
        self::assertStringContainsString('Text Domain: wp-site-options', $header);
        self::assertStringContainsString('Tested up to: 7.1', $readme);

        self::assertMatchesRegularExpression('/\R\R([^\r\n]+)\R\R== Description ==/', $readme);
        preg_match('/\R\R([^\r\n]+)\R\R== Description ==/', $readme, $matches);
        self::assertLessThanOrEqual(150, strlen(trim($matches[1])));
    }

    public function testEveryDirectlyCallablePhpFileHasAValidPhpOpenTagAndGuard(): void
    {
        $root = (string) constant('WP_SITE_OPTIONS_TEST_ROOT') . '/plugin-dir';
        $classes = file_get_contents($root . '/inc/classes.php');
        $rootIndex = file_get_contents($root . '/index.php');
        $incIndex = file_get_contents($root . '/inc/index.php');

        self::assertIsString($classes);
        self::assertStringContainsString("defined( 'ABSPATH' )", $classes);
        self::assertStringStartsWith("<?php\n", (string) $rootIndex);
        self::assertStringStartsWith("<?php\n", (string) $incIndex);
    }
}
