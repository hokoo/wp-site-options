<?php

declare(strict_types=1);

namespace Hokoo\WpSiteOptions\Tests\Unit;

use Brain\Monkey;
use Brain\Monkey\Actions;
use Brain\Monkey\Filters;
use Brain\Monkey\Functions;
use Mockery;
use PHPUnit\Framework\TestCase;

/**
 * @see docs/source-provenance.md#field-declaration-schema
 * @see docs/source-provenance.md#wordpress-hooks-exposed-by-the-plugin
 */
final class SettingsRegistrationContractTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        Monkey\setUp();
    }

    protected function tearDown(): void
    {
        unset($GLOBALS['wpto']);
        Monkey\tearDown();
        parent::tearDown();
    }

    public function testSettingsPageRegistrationPreservesSchemaNamesHooksAndArguments(): void
    {
        $GLOBALS['wpto'] = (object) [
            'plugin_options_name' => 'wpto_options',
            'text_domain' => 'consumer-theme',
            'fields' => [
                'general' => [
                    ['General settings', '<p>Consumer-defined <em>description</em></p>'],
                    [
                        'title' => ['text', 'Site title'],
                        'gallery' => ['gallery', 'Hero gallery'],
                    ],
                ],
            ],
        ];

        $registeredSettings = [];
        $registeredSections = [];
        $registeredFields = [];

        Functions\stubTranslationFunctions();
        Functions\when('register_setting')->alias(
            static function (...$args) use (&$registeredSettings): bool {
                $registeredSettings[] = $args;

                return true;
            }
        );
        Functions\when('add_settings_section')->alias(
            static function (...$args) use (&$registeredSections): bool {
                $registeredSections[] = $args;

                return true;
            }
        );
        Functions\when('add_settings_field')->alias(
            static function (...$args) use (&$registeredFields): bool {
                $registeredFields[] = $args;

                return true;
            }
        );

        Actions\expectAdded('admin_init')
            ->once()
            ->with('wpto_menu_init', 50);

        require_once (string) constant('WP_SITE_OPTIONS_TEST_ROOT') . '/plugin-dir/inc/settings.php';

        Filters\expectAdded('wpto_settings_header__general')
            ->once()
            ->with(
                Mockery::on(
                    static function ($callback): bool {
                        return $callback instanceof \Closure
                            && $callback('Fallback', 'general') === 'General settings';
                    }
                ),
                5,
                2
            );
        Filters\expectAdded('wpto_setting_section_before')
            ->once()
            ->with(
                Mockery::on(
                    static function ($callback): bool {
                        return $callback instanceof \Closure
                            && $callback('', 'wpto_setting_section__general')
                            === '<p>Consumer-defined <em>description</em></p>';
                    }
                ),
                5,
                2
            );
        Filters\expectApplied('wpto_settings_header__general')
            ->once()
            ->with('Site settings', 'general')
            ->andReturn('General settings');
        Actions\expectDone('wpto_before')->once()->withNoArgs();
        Actions\expectDone('wpto_after')->once()->withNoArgs();

        wpto_menu_init();

        self::assertSame(
            [[
                'reading',
                'wpto_options',
                ['sanitize_callback' => 'wpto_sanitize_options'],
            ]],
            $registeredSettings
        );
        self::assertSame(
            [[
                'wpto_setting_section__general',
                'General settings',
                'wpto_setting_section_before',
                'reading',
            ]],
            $registeredSections
        );
        self::assertSame(
            [
                [
                    'general-title',
                    'Site title',
                    'wpto_echo_field',
                    'reading',
                    'wpto_setting_section__general',
                    [
                        'cat' => 'general',
                        'fullname' => 'general-title',
                        'name' => 'wpto_options[general][title]',
                        'slug' => 'title',
                    ],
                ],
                [
                    'general-gallery',
                    'Hero gallery',
                    'wpto_echo_field',
                    'reading',
                    'wpto_setting_section__general',
                    [
                        'cat' => 'general',
                        'fullname' => 'general-gallery',
                        'name' => 'wpto_options[general][gallery]',
                        'slug' => 'gallery',
                    ],
                ],
            ],
            $registeredFields
        );

        Filters\expectApplied('wpto_setting_section_before')
            ->once()
            ->with('', 'wpto_setting_section__general')
            ->andReturn('<p>Consumer-defined <em>description</em></p>');

        ob_start();
        wpto_setting_section_before(['id' => 'wpto_setting_section__general']);
        $description = (string) ob_get_clean();

        self::assertSame('<p>Consumer-defined <em>description</em></p>', $description);
    }
}
