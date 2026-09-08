<?php

declare(strict_types=1);

namespace Hokoo\WpSiteOptions\Tests\Unit;

use Brain\Monkey;
use Brain\Monkey\Actions;
use Brain\Monkey\Filters;
use Brain\Monkey\Functions;
use PHPUnit\Framework\TestCase;

/**
 * @see docs/source-provenance.md#bootstrap-and-global-state
 * @see docs/source-provenance.md#wordpress-hooks-exposed-by-the-plugin
 */
final class BootstrapContractTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        Monkey\setUp();
    }

    protected function tearDown(): void
    {
        Monkey\tearDown();
        parent::tearDown();
    }

    /**
     * @runInSeparateProcess
     * @preserveGlobalState disabled
     */
    public function testEntrypointCreatesLegacyGlobalsAndRegistersBootstrapHooks(): void
    {
        $theme = new class {
            public function get(string $key): string
            {
                TestCase::assertSame('TextDomain', $key);

                return 'consumer-theme';
            }
        };

        Functions\when('plugin_dir_url')->justReturn('https://example.test/wp-content/plugins/wp-site-options/');
        Functions\when('wp_get_theme')->justReturn($theme);
        Functions\when('get_option')->justReturn(['general' => ['title' => 'Stored']]);

        Filters\expectAdded('wpto_getoption')
            ->once()
            ->with('wpto_getoption', 10, 3);
        Actions\expectAdded('admin_init')
            ->once()
            ->with('wpto_menu_init', 50);
        Actions\expectAdded('admin_footer')
            ->once()
            ->with('wpto_media_load', 100);

        global $wpto, $wpto_path, $wpto_url;

        require (string) constant('WP_SITE_OPTIONS_TEST_ROOT') . '/plugin-dir/wp-site-options.php';

        self::assertInstanceOf(\wpto\Theme_options::class, $wpto);
        self::assertSame('wpto_options', $wpto->plugin_options_name);
        self::assertSame('wpto_settings', $wpto->plugin_settings_name);
        self::assertSame('consumer-theme', $wpto->text_domain);
        self::assertSame(['general' => ['title' => 'Stored']], $wpto->options);
        self::assertNull($wpto->fields);
        self::assertSame(
            'https://example.test/wp-content/plugins/wp-site-options',
            $wpto_url
        );
        self::assertSame(
            (string) constant('WP_SITE_OPTIONS_TEST_ROOT') . '/plugin-dir',
            $wpto_path
        );

        foreach (
            [
                'wpto_getoption',
                'wpto_menu_init',
                'wpto_setting_section_before',
                'wpto_echo_attrs',
                'wpto_echo_field',
                'wpto_media_modal',
                'wpto_media_load',
            ] as $callable
        ) {
            self::assertTrue(function_exists($callable), $callable . ' must remain public.');
        }
    }
}
